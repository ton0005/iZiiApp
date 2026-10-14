import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../models/wave_audit_models.dart';

/// Packout Scale Verification & Gross-Weight Audit Service
/// Validates digital scale readings at dock staging against theoretical BOM weight.
/// If variance exceeds ±1.5%, an audible alarm triggers and halts manifest generation.
class PackoutWeightAuditService {
  final AppDatabase _db;

  PackoutWeightAuditService([AppDatabase? db]) : _db = db ?? AppDatabase();

  /// Calculate theoretical BOM weight for an assembled Pallet LPN
  Future<Map<String, dynamic>> calculateTheoreticalBom(String lpnCode) async {
    final pallet = await (_db.select(_db.stockLpns)
          ..where((tbl) => tbl.lpnCode.equals(lpnCode) | tbl.id.equals(lpnCode)))
        .getSingleOrNull();

    if (pallet == null) {
      throw ArgumentError('Không tìm thấy pallet LPN: $lpnCode');
    }

    final contents = await (_db.select(_db.stockLpnContents)
          ..where((tbl) => tbl.lpnId.equals(pallet.id)))
        .get();

    double totalCartons = 0.0;
    String productId = 'UNKNOWN';
    String productName = 'Mặt hàng chưa xác định';
    const double netKgPerCarton = 4.0; // Default standard mushroom box net kg
    double boxTareKg = 0.45; // Default carton tare kg
    final double palletTareKg = pallet.tareWeightKg != null && pallet.tareWeightKg! > 0
        ? pallet.tareWeightKg!
        : 35.0; // Standard AS 4068 pallet tare

    if (contents.isNotEmpty) {
      totalCartons = contents.fold(0.0, (sum, c) => sum + c.quantity);
      productId = contents.first.productId;

      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(productId)))
          .getSingleOrNull();
      if (prod != null) {
        productName = prod.name;
      }

      // Check packaging metadata if present
      if (pallet.packagingId != null) {
        final pkg = await (_db.select(_db.productPackagings)
              ..where((tbl) => tbl.id.equals(pallet.packagingId!)))
            .getSingleOrNull();
        if (pkg != null && pkg.tareWeightKg != null && pkg.tareWeightKg! > 0) {
          boxTareKg = pkg.tareWeightKg!;
        }
      }
    } else if (pallet.netWeightKg != null && pallet.netWeightKg! > 0) {
      totalCartons = pallet.netWeightKg! / 4.0;
    }

    final double totalNetWeightKg = totalCartons * netKgPerCarton;
    final double totalBoxTareKg = totalCartons * boxTareKg;
    final double theoreticalGrossKg = palletTareKg + totalBoxTareKg + totalNetWeightKg;

    return {
      'pallet': pallet,
      'productId': productId,
      'productName': productName,
      'cartonCount': totalCartons,
      'palletTareKg': palletTareKg,
      'cartonTareKg': boxTareKg,
      'totalBoxTareKg': totalBoxTareKg,
      'productNetKg': totalNetWeightKg,
      'theoreticalGrossKg': theoreticalGrossKg,
    };
  }

  /// Perform digital scale audit at dock staging area
  Future<PackoutWeightAuditResult> auditPalletWeight({
    required String lpnCode,
    required double actualGrossKg,
    required String auditedBy,
    double maxAllowedVariancePercentage = 1.5,
  }) async {
    final bom = await calculateTheoreticalBom(lpnCode);
    final pallet = bom['pallet'] as StockLpn;
    final double theoreticalGrossKg = bom['theoreticalGrossKg'] as double;
    final double cartonCount = bom['cartonCount'] as double;

    final double varianceKg = actualGrossKg - theoreticalGrossKg;
    final double variancePercentage = theoreticalGrossKg > 0
        ? (varianceKg / theoreticalGrossKg) * 100.0
        : 0.0;

    final bool isPassed = variancePercentage.abs() <= maxAllowedVariancePercentage;
    final auditId = const Uuid().v4();

    String? manifestCode;
    String status;
    String? anomalyMessage;

    if (isPassed) {
      status = 'verified';
      manifestCode = 'MANIFEST-PASS-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${auditId.substring(0, 6).toUpperCase()}';

      // Update Pallet with verified weight
      await (_db.update(_db.stockLpns)..where((tbl) => tbl.id.equals(pallet.id))).write(
        StockLpnsCompanion(
          grossWeightKg: Value(actualGrossKg),
          status: const Value('staged'),
        ),
      );

      SyncService().queueMutation('stock_lpns', 'update', {
        'id': pallet.id,
        'gross_weight_kg': actualGrossKg,
        'status': 'staged',
      });
    } else {
      status = 'alarm_triggered';
      final isOverweight = variancePercentage > 0;
      anomalyMessage = isOverweight
          ? 'CẢNH BÁO DƯ TẢI (+${variancePercentage.toStringAsFixed(2)}% > ±$maxAllowedVariancePercentage%): '
              'Thực tế thừa ${varianceKg.toStringAsFixed(1)} kg. Nguy cơ đọng nước quá mức hoặc xếp nhầm thừa thùng hàng!'
          : 'CẢNH BÁO THIẾU TẢI (${variancePercentage.toStringAsFixed(2)}% < -±$maxAllowedVariancePercentage%): '
              'Thực tế thiếu ${varianceKg.abs().toStringAsFixed(1)} kg. Nguy cơ thiếu thùng nấm trên pallet hoặc đóng thiếu định lượng!';

      // Log critical security alarm event in AutomationEvents table
      try {
        await _db.into(_db.automationEvents).insert(AutomationEventsCompanion.insert(
          id: const Uuid().v4(),
          ruleId: 'DOCK_SCALE_WEIGHT_AUDIT_RULE',
          locationId: Value(pallet.locationId),
          triggeringReadingId: Value(lpnCode),
          triggeringValue: Value(variancePercentage),
          status: const Value('failed'),
          resultRecordType: const Value('stock_lpns'),
          resultRecordId: Value(pallet.id),
          errorMessage: Value(anomalyMessage),
          acknowledgedBy: Value(auditedBy),
          acknowledgedAt: Value(DateTime.now()),
        ));
      } catch (_) {
        // Non-blocking safety
      }
    }

    return PackoutWeightAuditResult(
      id: auditId,
      lpnId: pallet.id,
      lpnCode: pallet.lpnCode,
      productId: bom['productId'] as String,
      productName: bom['productName'] as String,
      cartonCount: cartonCount,
      palletTareKg: bom['palletTareKg'] as double,
      cartonTareKg: bom['cartonTareKg'] as double,
      productNetKg: bom['productNetKg'] as double,
      theoreticalGrossKg: theoreticalGrossKg,
      actualGrossKg: actualGrossKg,
      varianceKg: varianceKg,
      variancePercentage: variancePercentage,
      maxAllowedVariancePercentage: maxAllowedVariancePercentage,
      isPassed: isPassed,
      status: status,
      anomalyMessage: anomalyMessage,
      auditedBy: auditedBy,
      auditedAt: DateTime.now(),
      manifestAuthorizationCode: manifestCode,
    );
  }
}
