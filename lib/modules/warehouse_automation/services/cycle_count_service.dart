import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../supply_chain/repository.dart';
import '../models/qc_cycle_count_models.dart';

/// Perpetual Blind Cycle Count Service
/// Implements blind physical counting (expected system book quantities hidden from operator),
/// automated variance analysis, and supervisor-authorized inventory reconciliation.
class CycleCountService {
  final AppDatabase _db;

  // Active in-memory session registry (or local cache)
  final Map<String, CycleCountSession> _activeSessions = {};

  CycleCountService([AppDatabase? db, SupplyChainRepository? supplyRepo])
      : _db = db ?? AppDatabase();

  /// Start a new Blind Cycle Count session for a given location or aisle
  Future<CycleCountSession> startBlindSession({
    required String locationCode,
    required String countedBy,
    String? notes,
  }) async {
    // 1. Resolve location
    final loc = await (_db.select(_db.locations)
          ..where((tbl) => tbl.code.equals(locationCode) | tbl.id.equals(locationCode)))
        .getSingleOrNull();

    final locationId = loc?.id ?? locationCode;
    final locationName = loc?.name ?? locationCode;

    // 2. Snapshot current book inventory (StockQuants)
    final quants = await (_db.select(_db.stockQuants)
          ..where((tbl) => tbl.locationId.equals(locationId) | tbl.locationId.equals(locationCode)))
        .get();

    final lines = <CycleCountLine>[];

    for (final q in quants) {
      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(q.productId)))
          .getSingleOrNull();

      StockLot? lot;
      if (q.lotId != null) {
        lot = await (_db.select(_db.stockLots)
              ..where((tbl) => tbl.id.equals(q.lotId!)))
            .getSingleOrNull();
      }

      StockLpn? pallet;
      if (q.lpnId != null) {
        pallet = await (_db.select(_db.stockLpns)
              ..where((tbl) => tbl.id.equals(q.lpnId!)))
            .getSingleOrNull();
      }

      lines.add(CycleCountLine(
        id: const Uuid().v4(),
        sessionId: '', // Set below
        locationId: locationId,
        productId: q.productId,
        productName: prod?.name ?? 'Unknown SKU',
        lotId: q.lotId,
        lotNumber: lot?.lotNumber,
        lpnId: q.lpnId,
        lpnCode: pallet?.lpnCode,
        systemQty: q.quantity, // Kept internal, hidden from blind UI
        countedQty: 0.0,
        varianceQty: -q.quantity, // Default -systemQty until counted
        uom: 'box',
        status: 'pending',
      ));
    }

    final sessionId = const Uuid().v4();
    final sessionNumber = 'CC-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${sessionId.substring(0, 4).toUpperCase()}';

    final updatedLines = lines.map((l) => CycleCountLine(
      id: l.id,
      sessionId: sessionId,
      locationId: l.locationId,
      productId: l.productId,
      productName: l.productName,
      lotId: l.lotId,
      lotNumber: l.lotNumber,
      lpnId: l.lpnId,
      lpnCode: l.lpnCode,
      systemQty: l.systemQty,
      countedQty: l.countedQty,
      varianceQty: l.varianceQty,
      uom: l.uom,
      status: l.status,
    )).toList();

    final session = CycleCountSession(
      id: sessionId,
      sessionNumber: sessionNumber,
      locationId: locationId,
      locationName: locationName,
      status: 'in_progress',
      countedBy: countedBy,
      startedAt: DateTime.now(),
      lines: updatedLines,
      notes: notes,
    );

    _activeSessions[sessionId] = session;
    return session;
  }

  /// Get active session by ID
  CycleCountSession? getSession(String sessionId) {
    return _activeSessions[sessionId];
  }

  /// Record a blind item count (counter scans barcode / LPN and inputs physical quantity)
  /// Note: The operator UI never sees the systemQty.
  Future<CycleCountSession> recordBlindCountItem({
    required String sessionId,
    required String barcodeOrLpn,
    required double physicalQty,
    String? notes,
  }) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }
    if (session.status != 'in_progress') {
      throw StateError('Cannot add counts to session in status: ${session.status}');
    }

    final trimmedScan = barcodeOrLpn.trim();
    final updatedLines = List<CycleCountLine>.from(session.lines);

    // 1. Try to match by LPN code or ID
    int matchIndex = updatedLines.indexWhere((l) =>
        (l.lpnCode != null && l.lpnCode!.toUpperCase() == trimmedScan.toUpperCase()) ||
        (l.lpnId != null && l.lpnId == trimmedScan));

    // 2. If not matched, try matching by Product SKU, Barcode, or Lot Number
    if (matchIndex < 0) {
      // Look up product by barcode / SKU
      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.barcode.equals(trimmedScan) | tbl.sku.equals(trimmedScan)))
          .getSingleOrNull();

      if (prod != null) {
        matchIndex = updatedLines.indexWhere((l) => l.productId == prod.id);
      }
    }

    if (matchIndex >= 0) {
      // Found existing line in book inventory
      final existing = updatedLines[matchIndex];
      final newVariance = physicalQty - existing.systemQty;
      final newStatus = newVariance == 0 ? 'matched' : 'discrepancy';

      updatedLines[matchIndex] = existing.copyWith(
        countedQty: physicalQty,
        varianceQty: newVariance,
        status: newStatus,
        notes: notes,
      );
    } else {
      // Unexpected stock found (Ghost Inventory - not in system at this location)
      // Check if product exists in system
      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.barcode.equals(trimmedScan) | tbl.sku.equals(trimmedScan) | tbl.id.equals(trimmedScan)))
          .getSingleOrNull();

      // Check if LPN exists
      final pallet = await (_db.select(_db.stockLpns)
            ..where((tbl) => tbl.lpnCode.equals(trimmedScan) | tbl.id.equals(trimmedScan)))
          .getSingleOrNull();

      final String prodId = prod?.id ?? (pallet != null ? 'prod-unknown' : trimmedScan);
      final String prodName = prod?.name ?? (pallet != null ? 'Pallet: ${pallet.lpnCode}' : 'Found SKU: $trimmedScan');

      final newLine = CycleCountLine(
        id: const Uuid().v4(),
        sessionId: sessionId,
        locationId: session.locationId,
        productId: prodId,
        productName: prodName,
        lpnId: pallet?.id,
        lpnCode: pallet?.lpnCode,
        systemQty: 0.0, // Was not in system
        countedQty: physicalQty,
        varianceQty: physicalQty, // Positive variance
        uom: 'box',
        status: 'discrepancy',
        notes: notes ?? 'Unexpected inventory detected during blind count',
      );
      updatedLines.add(newLine);
    }

    final updatedSession = session.copyWith(lines: updatedLines);
    _activeSessions[sessionId] = updatedSession;
    return updatedSession;
  }

  /// Complete counting stage: flags all uncounted items as missing (variance = -systemQty)
  CycleCountSession completeCountStage(String sessionId) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final completedLines = session.lines.map((l) {
      if (l.status == 'pending') {
        // Uncounted: physical = 0, variance = -systemQty
        return l.copyWith(
          countedQty: 0.0,
          varianceQty: -l.systemQty,
          status: l.systemQty == 0 ? 'matched' : 'discrepancy',
          notes: 'Uncounted during session (assumed missing)',
        );
      }
      return l;
    }).toList();

    final completedSession = session.copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
      lines: completedLines,
    );

    _activeSessions[sessionId] = completedSession;
    return completedSession;
  }

  /// Reconcile inventory discrepancies (Requires Level 3 Supervisor Authorization)
  Future<CycleCountSession> reconcileDiscrepancies({
    required String sessionId,
    required String supervisorId,
    required String supervisorPin,
    String? reconciliationNotes,
  }) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw ArgumentError('Session not found: $sessionId');
    }
    if (session.status != 'completed') {
      throw StateError('Cannot reconcile session in status: ${session.status}. Must be completed first.');
    }

    // Supervisor Authorization Validation
    if (supervisorPin.trim().isEmpty || supervisorPin.length < 4) {
      throw ArgumentError('Mã PIN Giám sát viên (Supervisor PIN) không hợp lệ (tối thiểu 4 số).');
    }

    // Process adjustments for each line with non-zero variance
    for (final line in session.lines) {
      if (line.varianceQty == 0) continue;

      // 1. Locate existing quant if present
      final quant = await (_db.select(_db.stockQuants)
            ..where((tbl) => tbl.productId.equals(line.productId))
            ..where((tbl) => tbl.locationId.equals(line.locationId)))
          .getSingleOrNull();

      if (quant != null) {
        // Adjust existing quant
        final newQty = line.countedQty;
        final newAvail = (newQty - quant.reservedQty).clamp(0.0, double.infinity);

        await (_db.update(_db.stockQuants)..where((tbl) => tbl.id.equals(quant.id))).write(
          StockQuantsCompanion(
            quantity: Value(newQty),
            availableQty: Value(newAvail),
            updatedAt: Value(DateTime.now()),
          ),
        );

        SyncService().queueMutation('stock_quants', 'update', {
          'id': quant.id,
          'quantity': newQty,
          'available_qty': newAvail,
        });
      } else if (line.countedQty > 0) {
        // Create new quant for unexpected stock found
        final newQuantId = const Uuid().v4();
        await _db.into(_db.stockQuants).insert(StockQuantsCompanion.insert(
          id: newQuantId,
          productId: line.productId,
          locationId: line.locationId,
          lotId: Value(line.lotId),
          lpnId: Value(line.lpnId),
          quantity: line.countedQty,
          availableQty: Value(line.countedQty),
        ));

        SyncService().queueMutation('stock_quants', 'insert', {
          'id': newQuantId,
          'product_id': line.productId,
          'location_id': line.locationId,
          'lot_id': line.lotId,
          'lpn_id': line.lpnId,
          'quantity': line.countedQty,
          'available_qty': line.countedQty,
        });
      }

      // 2. Generate StockMove audit trail for inventory adjustment
      final moveId = const Uuid().v4();
      final isLoss = line.varianceQty < 0;
      final adjLocation = isLoss ? 'VIRTUAL-INVENTORY-LOSS' : 'VIRTUAL-INVENTORY-GAIN';

      await _db.into(_db.stockMoves).insert(StockMovesCompanion.insert(
        id: moveId,
        productId: line.productId,
        lotId: Value(line.lotId),
        lpnId: Value(line.lpnId),
        sourceLocationId: isLoss ? line.locationId : adjLocation,
        destLocationId: isLoss ? adjLocation : line.locationId,
        quantity: line.varianceQty.abs(),
        status: const Value('done'),
        transportType: const Value('manual'),
      ));

      SyncService().queueMutation('stock_moves', 'insert', {
        'id': moveId,
        'product_id': line.productId,
        'lot_id': line.lotId,
        'lpn_id': line.lpnId,
        'source_location_id': isLoss ? line.locationId : adjLocation,
        'dest_location_id': isLoss ? adjLocation : line.locationId,
        'quantity': line.varianceQty.abs(),
        'status': 'done',
        'transport_type': 'manual',
      });
    }

    final reconciledLines = session.lines
        .map((l) => l.copyWith(status: 'reconciled'))
        .toList();

    final reconciledSession = session.copyWith(
      status: 'reconciled',
      approvedBy: supervisorId,
      reconciledAt: DateTime.now(),
      lines: reconciledLines,
      notes: reconciliationNotes ?? 'Đã cân đối tồn kho bởi Giám sát $supervisorId',
    );

    _activeSessions[sessionId] = reconciledSession;
    return reconciledSession;
  }
}
