import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../models/wave_audit_models.dart';

/// Wave Picking Engine & Pick-Path Optimizer
/// Consolidates multiple delivery orders into a single wave and orders pick tasks
/// along an optimized S-shape (serpentine) path without backtracking.
class WavePickingService {
  final AppDatabase _db;
  final Map<String, StockWave> _activeWaves = {};

  WavePickingService([AppDatabase? db]) : _db = db ?? AppDatabase();

  /// Parse aisle, bay, and level numbers from location code or path
  /// e.g. 'WH1-COLD-A01-R03-L2' -> {aisle: 'A01', aisleIndex: 1, bay: 3, level: 2}
  static Map<String, dynamic> parseLocationCoords(String code) {
    String aisle = 'A01';
    int aisleIndex = 1;
    int bay = 1;
    int level = 1;

    final upper = code.toUpperCase();
    final parts = upper.split('-');

    for (final part in parts) {
      if (part.startsWith('A') && part.length >= 2) {
        final numPart = int.tryParse(part.substring(1));
        if (numPart != null) {
          aisle = part;
          aisleIndex = numPart;
        }
      } else if ((part.startsWith('R') || part.startsWith('B')) && part.length >= 2) {
        final numPart = int.tryParse(part.substring(1));
        if (numPart != null) {
          bay = numPart;
        }
      } else if (part.startsWith('L') && part.length >= 2) {
        final numPart = int.tryParse(part.substring(1));
        if (numPart != null) {
          level = numPart;
        }
      }
    }

    return {
      'aisle': aisle,
      'aisleIndex': aisleIndex,
      'bay': bay,
      'level': level,
    };
  }

  /// Optimize picking path using S-shape (serpentine) aisle routing heuristic.
  /// Odd aisles: Ascending bay order (Bay 01 -> Bay 10)
  /// Even aisles: Descending bay order (Bay 10 -> Bay 01)
  /// Within bay: Level ascending (Floor L1 -> L2 -> L3)
  static List<WavePickItem> optimizePickPath(List<WavePickItem> items) {
    final sorted = List<WavePickItem>.from(items);

    sorted.sort((a, b) {
      final aCoords = parseLocationCoords(a.locationCode);
      final bCoords = parseLocationCoords(b.locationCode);

      final int aAisle = aCoords['aisleIndex'] as int;
      final int bAisle = bCoords['aisleIndex'] as int;

      // 1. Sort by Aisle sequence
      if (aAisle != bAisle) {
        return aAisle.compareTo(bAisle);
      }

      // 2. S-shape direction:
      // Odd aisles: Ascending bay order
      // Even aisles: Descending bay order
      final bool isOddAisle = aAisle % 2 != 0;
      final int aBay = aCoords['bay'] as int;
      final int bBay = bCoords['bay'] as int;

      if (aBay != bBay) {
        return isOddAisle ? aBay.compareTo(bBay) : bBay.compareTo(aBay);
      }

      // 3. Within same bay: bottom-up level order
      final int aLevel = aCoords['level'] as int;
      final int bLevel = bCoords['level'] as int;
      return aLevel.compareTo(bLevel);
    });

    // Re-index sequences along the continuous S-curve
    final sequenced = <WavePickItem>[];
    for (int i = 0; i < sorted.length; i++) {
      sequenced.add(sorted[i].copyWith(sequence: i + 1));
    }
    return sequenced;
  }

  /// Consolidate multiple sales delivery pickings into a single picking wave
  Future<StockWave> createWave({
    required List<String> pickingIds,
    required String dispatchWindow,
    required String carrier,
    String destinationDock = 'DOCK-01-COLD',
    String? assignedDriver,
  }) async {
    if (pickingIds.isEmpty) {
      throw ArgumentError('Danh sách đơn hàng (pickingIds) không được rỗng.');
    }

    // 1. Fetch pickings
    final pickings = await (_db.select(_db.stockPickings)
          ..where((tbl) => tbl.id.isIn(pickingIds)))
        .get();

    if (pickings.isEmpty) {
      throw ArgumentError('Không tìm thấy phiếu xuất kho hợp lệ.');
    }

    // 2. Fetch all lines for these pickings
    final lines = await (_db.select(_db.stockPickingLines)
          ..where((tbl) => tbl.pickingId.isIn(pickingIds)))
        .get();

    // 3. Aggregate pick tasks by location, product, and lot
    final Map<String, List<StockPickingLine>> grouped = {};
    for (final line in lines) {
      final key = '${line.sourceLocationId}__${line.productId}__${line.lotId ?? "NO_LOT"}__${line.lpnId ?? "NO_LPN"}';
      grouped.putIfAbsent(key, () => []).add(line);
    }

    final waveId = const Uuid().v4();
    final waveNumber = 'WAVE-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${waveId.substring(0, 4).toUpperCase()}';

    final unoptimizedItems = <WavePickItem>[];

    for (final entry in grouped.entries) {
      final groupLines = entry.value;
      final firstLine = groupLines.first;

      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(firstLine.productId)))
          .getSingleOrNull();

      StockLot? lot;
      if (firstLine.lotId != null) {
        lot = await (_db.select(_db.stockLots)
              ..where((tbl) => tbl.id.equals(firstLine.lotId!)))
            .getSingleOrNull();
      }

      StockLpn? pallet;
      if (firstLine.lpnId != null) {
        pallet = await (_db.select(_db.stockLpns)
              ..where((tbl) => tbl.id.equals(firstLine.lpnId!)))
            .getSingleOrNull();
      }

      final loc = await (_db.select(_db.locations)
            ..where((tbl) => tbl.id.equals(firstLine.sourceLocationId) | tbl.code.equals(firstLine.sourceLocationId)))
          .getSingleOrNull();

      final locCode = loc?.code ?? firstLine.sourceLocationId;
      final coords = parseLocationCoords(locCode);

      final allocations = <OrderAllocation>[];
      double totalAggregatedQty = 0.0;

      for (final l in groupLines) {
        final picking = pickings.firstWhere((p) => p.id == l.pickingId);
        final qty = l.demandQty > 0 ? l.demandQty : 1.0;
        totalAggregatedQty += qty;

        allocations.add(OrderAllocation(
          pickingId: l.pickingId,
          orderCode: picking.originDocument ?? picking.code,
          customerName: picking.notes ?? 'Khách hàng B2B',
          quantity: qty,
          uom: l.uomId,
        ));
      }

      unoptimizedItems.add(WavePickItem(
        id: const Uuid().v4(),
        waveId: waveId,
        sequence: 0,
        locationCode: locCode,
        locationName: loc?.name ?? locCode,
        aisle: coords['aisle'] as String,
        bay: coords['bay'] as int,
        level: coords['level'] as int,
        productId: firstLine.productId,
        productName: prod?.name ?? 'Sản phẩm nấm',
        lotId: lot?.id,
        lotNumber: lot?.lotNumber,
        lpnId: pallet?.id,
        lpnCode: pallet?.lpnCode,
        aggregatedQty: totalAggregatedQty,
        pickedQty: 0.0,
        uom: firstLine.uomId,
        allocations: allocations,
      ));
    }

    // 4. Optimize S-shape route
    final optimizedItems = optimizePickPath(unoptimizedItems);
    final totalDemand = optimizedItems.fold(0.0, (sum, i) => sum + i.aggregatedQty);

    final wave = StockWave(
      id: waveId,
      waveNumber: waveNumber,
      dispatchWindow: dispatchWindow,
      carrier: carrier,
      destinationDock: destinationDock,
      status: 'released',
      pickingIds: pickingIds,
      totalOrders: pickings.length,
      totalDemandQty: totalDemand,
      totalPickedQty: 0.0,
      assignedDriver: assignedDriver ?? 'DRIVER-FORKLIFT-01',
      createdAt: DateTime.now(),
      items: optimizedItems,
    );

    // 5. Update StockPickings with waveId and assigned status
    for (final p in pickings) {
      await (_db.update(_db.stockPickings)..where((tbl) => tbl.id.equals(p.id))).write(
        StockPickingsCompanion(
          waveId: Value(waveId),
          status: const Value('assigned'),
        ),
      );

      SyncService().queueMutation('stock_pickings', 'update', {
        'id': p.id,
        'wave_id': waveId,
        'status': 'assigned',
      });
    }

    _activeWaves[waveId] = wave;
    return wave;
  }

  /// Get active wave by ID
  StockWave? getWave(String waveId) => _activeWaves[waveId];

  /// Get all active waves
  List<StockWave> getAllWaves() => _activeWaves.values.toList();

  /// Confirm a picking step along the S-shape route
  Future<StockWave> confirmPickItem({
    required String waveId,
    required String itemId,
    required double quantity,
    required String driverId,
  }) async {
    final wave = _activeWaves[waveId];
    if (wave == null) {
      throw ArgumentError('Wave not found: $waveId');
    }

    final itemIndex = wave.items.indexWhere((i) => i.id == itemId);
    if (itemIndex < 0) {
      throw ArgumentError('Wave item not found: $itemId');
    }

    final item = wave.items[itemIndex];
    final updatedItem = item.copyWith(
      pickedQty: quantity,
      isPicked: true,
    );

    final updatedItems = List<WavePickItem>.from(wave.items);
    updatedItems[itemIndex] = updatedItem;

    final newTotalPicked = updatedItems.fold(0.0, (sum, i) => sum + i.pickedQty);
    final allPicked = updatedItems.every((i) => i.isPicked);

    final updatedWave = wave.copyWith(
      items: updatedItems,
      totalPickedQty: newTotalPicked,
      status: allPicked ? 'completed' : 'in_progress',
      completedAt: allPicked ? DateTime.now() : null,
    );

    // If completely picked, transfer items to staging dock and mark pickings as completed
    if (allPicked) {
      for (final it in updatedItems) {
        final moveId = const Uuid().v4();
        await _db.into(_db.stockMoves).insert(StockMovesCompanion.insert(
          id: moveId,
          productId: it.productId,
          lotId: Value(it.lotId),
          lpnId: Value(it.lpnId),
          sourceLocationId: it.locationCode,
          destLocationId: wave.destinationDock,
          quantity: it.pickedQty,
          status: const Value('done'),
          transportType: const Value('forklift'),
        ));

        SyncService().queueMutation('stock_moves', 'insert', {
          'id': moveId,
          'product_id': it.productId,
          'lot_id': it.lotId,
          'lpn_id': it.lpnId,
          'source_location_id': it.locationCode,
          'dest_location_id': wave.destinationDock,
          'quantity': it.pickedQty,
          'status': 'done',
        });
      }

      for (final pId in wave.pickingIds) {
        await (_db.update(_db.stockPickings)..where((tbl) => tbl.id.equals(pId))).write(
          StockPickingsCompanion(
            status: const Value('done'),
            completedDate: Value(DateTime.now()),
          ),
        );

        SyncService().queueMutation('stock_pickings', 'update', {
          'id': pId,
          'status': 'done',
          'completed_date': DateTime.now().toIso8601String(),
        });
      }
    }

    _activeWaves[waveId] = updatedWave;
    return updatedWave;
  }
}
