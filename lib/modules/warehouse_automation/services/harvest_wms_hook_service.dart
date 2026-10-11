import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../supply_chain/repository.dart';

class HarvestWmsHookService {
  final AppDatabase _db;
  final SupplyChainRepository _supplyRepo;

  HarvestWmsHookService([AppDatabase? database, SupplyChainRepository? repo])
      : _db = database ?? AppDatabase(),
        _supplyRepo = repo ?? SupplyChainRepository(database);

  /// Automatically converts finalized Harvest Plan yield into WMS Inbound Pickings and Lots
  Future<Map<String, dynamic>> convertHarvestYieldToWmsInbound({
    required String planId,
    required DateTime planDate,
    required String zoneId, // M1 or M2
    required String roomCode, // e.g. R33, Room 33
    required String grade, // Button, Cup, Flat
    required int pickedBoxes,
    String? productId,
    String? notes,
  }) async {
    final cleanRoom = roomCode.toUpperCase().replaceAll('ROOM', 'R').replaceAll(' ', '');
    final dateStr =
        '${planDate.year}${planDate.month.toString().padLeft(2, '0')}${planDate.day.toString().padLeft(2, '0')}';
    final lotNumber = 'LOT-$dateStr-$cleanRoom-${grade.toUpperCase()}';

    // 1. Resolve or verify product
    String prodId = productId ?? '';
    if (prodId.isEmpty) {
      final allProducts = await _supplyRepo.getAllProducts();
      final match = allProducts.where((p) =>
          p.name.toUpperCase().contains(grade.toUpperCase()) ||
          p.sku.toUpperCase().contains(grade.toUpperCase())).firstOrNull;
      if (match != null) {
        prodId = match.id;
      } else {
        // Fallback: use first available or default mushroom SKU
        prodId = allProducts.isNotEmpty ? allProducts.first.id : 'prod-mush-$grade';
      }
    }

    // 2. Automated Lot Numbering with Shelf-Life Calculation (2-4°C standard)
    // Mushrooms: Best Before +5 days, Expiry Date +7 days
    final bestBefore = planDate.add(const Duration(days: 5));
    final expiryDate = planDate.add(const Duration(days: 7));

    final lot = await _supplyRepo.createLot(
      productId: prodId,
      lotNumber: lotNumber,
      productionDate: planDate,
      bestBeforeDate: bestBefore,
      expiryDate: expiryDate,
      status: 'approved',
      notes: notes ?? 'Thu hoạch từ phòng $cleanRoom ($zoneId), sản lượng: $pickedBoxes thùng $grade',
    );

    // 3. Create Inbound Transfer Order (StockPickings: incoming_harvest)
    final pickingId = const Uuid().v4();
    final pickingCode = 'IN-HARVEST-$dateStr-$cleanRoom';
    final sourceLoc = '$zoneId-STAGING';
    const destLoc = 'WH1-COLD-GATE';

    await _db.into(_db.stockPickings).insertOnConflictUpdate(
          StockPickingsCompanion.insert(
            id: pickingId,
            code: pickingCode,
            pickingType: 'incoming_harvest',
            originDocument: Value('HARVEST-$planId'),
            sourceLocationId: Value(sourceLoc),
            destLocationId: const Value(destLoc),
            scheduledDate: Value(planDate),
            completedDate: Value(DateTime.now()),
            status: const Value('confirmed'),
            priority: const Value('high'),
            notes: Value('Tự động sinh từ Kế hoạch thu hoạch $planId cho $cleanRoom'),
          ),
        );

    // 4. Create StockPickingLine
    final lineId = const Uuid().v4();
    await _db.into(_db.stockPickingLines).insertOnConflictUpdate(
          StockPickingLinesCompanion.insert(
            id: lineId,
            pickingId: pickingId,
            productId: prodId,
            lotId: Value(lot.id),
            sourceLocationId: sourceLoc,
            destLocationId: destLoc,
            demandQty: Value(pickedBoxes.toDouble()),
            reservedQty: const Value(0.0),
            doneQty: Value(pickedBoxes.toDouble()),
            uomId: 'box',
            status: const Value('confirmed'),
          ),
        );

    // 5. Enqueue Outbox sync mutations
    SyncService().queueMutation('stock_pickings', 'insert', {
      'id': pickingId,
      'code': pickingCode,
      'picking_type': 'incoming_harvest',
      'origin_document': 'HARVEST-$planId',
      'source_location_id': sourceLoc,
      'dest_location_id': destLoc,
      'status': 'confirmed',
      'priority': 'high',
    });

    SyncService().queueMutation('stock_picking_lines', 'insert', {
      'id': lineId,
      'picking_id': pickingId,
      'product_id': prodId,
      'lot_id': lot.id,
      'source_location_id': sourceLoc,
      'dest_location_id': destLoc,
      'demand_qty': pickedBoxes.toDouble(),
      'done_qty': pickedBoxes.toDouble(),
      'uom_id': 'box',
      'status': 'confirmed',
    });

    return {
      'picking_id': pickingId,
      'picking_code': pickingCode,
      'lot_id': lot.id,
      'lot_number': lot.lotNumber,
      'product_id': prodId,
      'source_location': sourceLoc,
      'dest_location': destLoc,
      'picked_boxes': pickedBoxes,
      'best_before': bestBefore,
      'expiry_date': expiryDate,
    };
  }
}
