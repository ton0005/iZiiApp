import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../supply_chain/repository.dart';
import '../models/qc_cycle_count_models.dart';

/// Quality Control (QC) Gate Service
/// Enforces industrial cold-chain and produce quality criteria before releasing lots to FEFO outbound.
class QcInspectionService {
  final AppDatabase _db;

  QcInspectionService([AppDatabase? db, SupplyChainRepository? supplyRepo])
      : _db = db ?? AppDatabase();

  /// Evaluate QC criteria based on industrial cold-chain standards (e.g. Costa Mushrooms)
  static Map<String, dynamic> evaluateCriteria({
    required double productTemperature,
    required String surfaceMoisture,
    required String discolorationGrade,
    required String veilOpening,
    required String packagingIntegrity,
  }) {
    final issues = <String>[];
    bool tempCompliant = true;
    bool qualityCompliant = true;

    // 1. Cold-chain core temperature check: 1.0°C - 4.5°C
    if (productTemperature > 4.5) {
      issues.add('Nhiệt độ lõi sản phẩm quá cao (${productTemperature.toStringAsFixed(1)}°C > 4.5°C). Nguy cơ vi sinh và mềm nhũn.');
      tempCompliant = false;
    } else if (productTemperature < 0.5) {
      issues.add('Nhiệt độ quá thấp (${productTemperature.toStringAsFixed(1)}°C < 0.5°C). Nguy cơ bỏng lạnh (freeze damage).');
      tempCompliant = false;
    }

    // 2. Surface moisture
    if (surfaceMoisture == 'excess') {
      issues.add('Bề mặt nấm ướt đọng giọt (Excess Moisture). Nguy cơ thối hỏng nhanh.');
      qualityCompliant = false;
    }

    // 3. Discoloration & Blemishes
    if (discolorationGrade == 'severe' || discolorationGrade == 'spotted') {
      issues.add('Đổi màu / đốm nâu nghiêm trọng ($discolorationGrade). Không đạt tiêu chuẩn loại 1.');
      qualityCompliant = false;
    }

    // 4. Packaging integrity
    if (packagingIntegrity == 'torn' || packagingIntegrity == 'contaminated') {
      issues.add('Thùng hàng bị rách hoặc nhiễm bẩn ngoại quan ($packagingIntegrity).');
      qualityCompliant = false;
    }

    final passed = tempCompliant && qualityCompliant;
    final recommendedStatus = passed
        ? 'approved'
        : (!tempCompliant && productTemperature > 7.0
            ? 'blocked'
            : (qualityCompliant ? 'hold' : 'blocked'));

    return {
      'passed': passed,
      'tempCompliant': tempCompliant,
      'qualityCompliant': qualityCompliant,
      'recommendedStatus': recommendedStatus,
      'issues': issues,
    };
  }

  /// Get all lots currently waiting in quarantine or hold status
  Future<List<Map<String, dynamic>>> getQuarantineLots() async {
    final lots = await (_db.select(_db.stockLots)
          ..where((tbl) => tbl.status.equals('quarantine') | tbl.status.equals('hold'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();

    final results = <Map<String, dynamic>>[];

    for (final lot in lots) {
      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(lot.productId)))
          .getSingleOrNull();

      // Find associated LPN(s)
      final contents = await (_db.select(_db.stockLpnContents)
            ..where((tbl) => tbl.lotId.equals(lot.id)))
          .get();

      StockLpn? pallet;
      if (contents.isNotEmpty) {
        pallet = await (_db.select(_db.stockLpns)
              ..where((tbl) => tbl.id.equals(contents.first.lpnId)))
            .getSingleOrNull();
      }

      results.add({
        'lot': lot,
        'product': prod,
        'pallet': pallet,
        'quantity': contents.fold(0.0, (sum, c) => sum + c.quantity),
        'uom': contents.isNotEmpty ? contents.first.uomId : 'box',
      });
    }

    return results;
  }

  /// Submit QC Gate inspection result, updating lot and LPN statuses
  Future<StockLot> submitInspection(QcInspectionResult inspection) async {
    final lot = await (_db.select(_db.stockLots)
          ..where((tbl) => tbl.id.equals(inspection.lotId)))
        .getSingleOrNull();

    if (lot == null) {
      throw ArgumentError('StockLot not found: ${inspection.lotId}');
    }

    final newStatus = inspection.status; // 'approved', 'blocked', 'hold'
    final qcAuditNote = '[QC ${inspection.inspectedAt.toIso8601String().substring(0, 16)}]: '
        'Status=${newStatus.toUpperCase()} by ${inspection.inspectedBy}. '
        'Temp=${inspection.productTemperature}°C, Moisture=${inspection.surfaceMoisture}, '
        'Grade=${inspection.discolorationGrade}. Note: ${inspection.notes ?? "None"}';

    final updatedNotes = lot.notes == null || lot.notes!.isEmpty
        ? qcAuditNote
        : '${lot.notes}\n$qcAuditNote';

    // 1. Update lot in local database
    await (_db.update(_db.stockLots)..where((tbl) => tbl.id.equals(lot.id))).write(
      StockLotsCompanion(
        status: Value(newStatus),
        notes: Value(updatedNotes),
      ),
    );

    // 2. Queue sync mutation for postgres
    SyncService().queueMutation('stock_lots', 'update', {
      'id': lot.id,
      'status': newStatus,
      'notes': updatedNotes,
    });

    // 3. If lot is BLOCKED and attached to a pallet LPN, flag pallet and move to Quarantine location
    if (newStatus == 'blocked' && inspection.lpnId != null) {
      final pallet = await (_db.select(_db.stockLpns)
            ..where((tbl) => tbl.id.equals(inspection.lpnId!)))
          .getSingleOrNull();

      if (pallet != null) {
        // Relocate pallet to Quarantine bay
        const quarantineLoc = 'WH1-QUARANTINE';
        await (_db.update(_db.stockLpns)..where((tbl) => tbl.id.equals(pallet.id))).write(
          const StockLpnsCompanion(
            locationId: Value(quarantineLoc),
            status: Value('staged'),
          ),
        );

        // Record stock move
        final moveId = const Uuid().v4();
        await _db.into(_db.stockMoves).insert(StockMovesCompanion.insert(
          id: moveId,
          productId: lot.productId,
          lotId: Value(lot.id),
          lpnId: Value(pallet.id),
          sourceLocationId: pallet.locationId,
          destLocationId: quarantineLoc,
          quantity: 1.0,
          status: const Value('done'),
          transportType: const Value('forklift'),
        ));

        SyncService().queueMutation('stock_lpns', 'update', {
          'id': pallet.id,
          'location_id': quarantineLoc,
        });

        SyncService().queueMutation('stock_moves', 'insert', {
          'id': moveId,
          'product_id': lot.productId,
          'lot_id': lot.id,
          'lpn_id': pallet.id,
          'source_location_id': pallet.locationId,
          'dest_location_id': quarantineLoc,
          'quantity': 1.0,
          'status': 'done',
        });
      }
    }

    // 4. Log QC event in AutomationEvents table for traceability
    try {
      final eventId = const Uuid().v4();
      await _db.into(_db.automationEvents).insert(AutomationEventsCompanion.insert(
        id: eventId,
        ruleId: 'QC_GATE_RULE',
        locationId: Value(inspection.lpnCode ?? 'GATE-INBOUND'),
        triggeringReadingId: Value(inspection.id),
        triggeringValue: Value(inspection.productTemperature),
        status: Value(newStatus == 'approved' ? 'executed' : 'failed'),
        resultRecordType: const Value('stock_lots'),
        resultRecordId: Value(lot.id),
        errorMessage: Value(inspection.passed ? null : inspection.notes),
        acknowledgedBy: Value(inspection.inspectedBy),
        acknowledgedAt: Value(inspection.inspectedAt),
      ));
    } catch (_) {
      // Continue safely if automation event table logging is non-blocking
    }

    return (_db.select(_db.stockLots)..where((tbl) => tbl.id.equals(lot.id))).getSingle();
  }
}
