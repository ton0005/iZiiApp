import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../models/putaway_fefo_models.dart';

class FefoAllocationEngine {
  final AppDatabase _db;

  FefoAllocationEngine([AppDatabase? database])
      : _db = database ?? AppDatabase();

  /// Performs deterministic First-Expired, First-Out (FEFO) stock allocation and reservation
  Future<FefoAllocationResult> allocateStockFefo({
    required String productId,
    required double requestedQty,
    bool executeReservation = true,
  }) async {
    final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(productId))).getSingleOrNull();
    final productName = product?.name ?? 'Sản phẩm $productId';

    if (requestedQty <= 0) {
      return FefoAllocationResult(
        productId: productId,
        productName: productName,
        requestedQuantity: requestedQty,
        allocatedQuantity: 0.0,
        unfulfilledQuantity: 0.0,
        isFullyAllocated: true,
        lines: const [],
        summaryNotes: 'Số lượng yêu cầu bằng 0.',
      );
    }

    // 1. Fetch all candidate quants with available quantity
    final quants = await (_db.select(_db.stockQuants)
          ..where((tbl) => tbl.productId.equals(productId) & tbl.availableQty.isBiggerThanValue(0.0)))
        .get();

    // Filter out staging and quarantine locations
    final eligibleQuants = quants.where((q) =>
        !q.locationId.contains('STAGING') &&
        !q.locationId.contains('QUARANTINE')).toList();

    // 2. Fetch associated Lots and filter only approved lots
    final candidatePairs = <({StockQuant quant, StockLot lot})>[];
    for (final q in eligibleQuants) {
      if (q.lotId != null) {
        final lot = await (_db.select(_db.stockLots)..where((tbl) => tbl.id.equals(q.lotId!))).getSingleOrNull();
        if (lot != null && lot.status == 'approved') {
          candidatePairs.add((quant: q, lot: lot));
        }
      }
    }

    // 3. Deterministic FEFO Ordering:
    //    Primary: Expiry Date ASC
    //    Secondary: Best Before Date ASC
    //    Tertiary: Available Quantity ASC (clears partial bins first)
    candidatePairs.sort((a, b) {
      final cmpExpiry = a.lot.expiryDate.compareTo(b.lot.expiryDate);
      if (cmpExpiry != 0) return cmpExpiry;

      final aBb = a.lot.bestBeforeDate ?? a.lot.expiryDate;
      final bBb = b.lot.bestBeforeDate ?? b.lot.expiryDate;
      final cmpBb = aBb.compareTo(bBb);
      if (cmpBb != 0) return cmpBb;

      return a.quant.availableQty.compareTo(b.quant.availableQty);
    });

    // 4. Allocate and optionally execute atomic reservation
    double remainingDemand = requestedQty;
    double totalAllocated = 0.0;
    final allocatedLines = <FefoAllocationLine>[];
    DateTime? earliestExpiry;

    for (final pair in candidatePairs) {
      if (remainingDemand <= 0) break;

      final quant = pair.quant;
      final lot = pair.lot;
      final available = quant.availableQty;

      final takeQty = available <= remainingDemand ? available : remainingDemand;

      if (executeReservation) {
        final newReserved = quant.reservedQty + takeQty;
        final newAvailable = quant.availableQty - takeQty;

        await (_db.update(_db.stockQuants)..where((tbl) => tbl.id.equals(quant.id))).write(
          StockQuantsCompanion(
            reservedQty: Value(newReserved),
            availableQty: Value(newAvailable),
            updatedAt: Value(DateTime.now()),
          ),
        );

        SyncService().queueMutation('stock_quants', 'update', {
          'id': quant.id,
          'reserved_qty': newReserved,
          'available_qty': newAvailable,
        });
      }

      // Lookup LPN Code
      String? lpnCode;
      if (quant.lpnId != null) {
        final pallet = await (_db.select(_db.stockLpns)..where((tbl) => tbl.id.equals(quant.lpnId!))).getSingleOrNull();
        lpnCode = pallet?.lpnCode;
      }

      // Lookup Location Name
      final loc = await (_db.select(_db.locations)
            ..where((tbl) => tbl.code.equals(quant.locationId) | tbl.id.equals(quant.locationId)))
          .getSingleOrNull();

      final now = DateTime.now();
      final daysUntilExpiry = lot.expiryDate.difference(now).inDays;

      allocatedLines.add(FefoAllocationLine(
        quantId: quant.id,
        lpnId: quant.lpnId,
        lpnCode: lpnCode,
        locationCode: quant.locationId,
        locationName: loc?.name ?? quant.locationId,
        lotId: lot.id,
        lotNumber: lot.lotNumber,
        expiryDate: lot.expiryDate,
        daysUntilExpiry: daysUntilExpiry,
        allocatedQty: takeQty,
        uom: 'box',
      ));

      earliestExpiry ??= lot.expiryDate;
      totalAllocated += takeQty;
      remainingDemand -= takeQty;
    }

    final isFullyAllocated = remainingDemand <= 0.001;
    final unfulfilled = remainingDemand > 0 ? remainingDemand : 0.0;

    final summary = isFullyAllocated
        ? 'Phân bổ FEFO thành công 100%: $totalAllocated / $requestedQty thùng. '
            'Lô xuất sớm nhất hết hạn ngày: ${earliestExpiry != null ? "${earliestExpiry.day}/${earliestExpiry.month}/${earliestExpiry.year}" : "N/A"}.'
        : 'CẢNH BÁO THIẾU TỒN KHO: Chỉ phân bổ được $totalAllocated / $requestedQty thùng '
            '(Còn thiếu $unfulfilled thùng chưa có hàng approved).';

    return FefoAllocationResult(
      productId: productId,
      productName: productName,
      requestedQuantity: requestedQty,
      allocatedQuantity: totalAllocated,
      unfulfilledQuantity: unfulfilled,
      isFullyAllocated: isFullyAllocated,
      lines: allocatedLines,
      earliestExpiry: earliestExpiry,
      summaryNotes: summary,
    );
  }
}
