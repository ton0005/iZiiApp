import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/supply_chain/repository.dart';
import 'package:izii_app/modules/warehouse_automation/models/qc_cycle_count_models.dart';
import 'package:izii_app/modules/warehouse_automation/services/qc_inspection_service.dart';
import 'package:izii_app/modules/warehouse_automation/services/cycle_count_service.dart';
import 'package:izii_app/modules/warehouse_automation/services/fefo_allocation_engine.dart';

void main() {
  late AppDatabase db;
  late SupplyChainRepository repo;
  late QcInspectionService qcService;
  late CycleCountService countService;
  late FefoAllocationEngine fefoEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = SupplyChainRepository(db);
    qcService = QcInspectionService(db, repo);
    countService = CycleCountService(db, repo);
    fefoEngine = FefoAllocationEngine(db);

    // Seed product
    await repo.addProductWithStock(
      id: 'prod-cup-01',
      sku: 'MUSH-CUP-4KG',
      name: 'Cup Mushroom 4kg',
      price: 24.0,
      cost: 16.0,
      stock: 0,
      barcode: '9312345000017',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Quality Control Gate (QC) Tests', () {
    test('evaluateCriteria returns correct compliance results', () {
      // 1. Passing criteria
      final passResult = QcInspectionService.evaluateCriteria(
        productTemperature: 3.2,
        surfaceMoisture: 'normal',
        discolorationGrade: 'clean_white',
        veilOpening: 'closed',
        packagingIntegrity: 'intact',
      );
      expect(passResult['passed'], isTrue);
      expect(passResult['recommendedStatus'], 'approved');

      // 2. High temperature violation (> 4.5°C)
      final hotResult = QcInspectionService.evaluateCriteria(
        productTemperature: 5.8,
        surfaceMoisture: 'normal',
        discolorationGrade: 'clean_white',
        veilOpening: 'closed',
        packagingIntegrity: 'intact',
      );
      expect(hotResult['passed'], isFalse);
      expect(hotResult['tempCompliant'], isFalse);
      expect(hotResult['issues'], isNotEmpty);

      // 3. Excess moisture violation
      final wetResult = QcInspectionService.evaluateCriteria(
        productTemperature: 3.0,
        surfaceMoisture: 'excess',
        discolorationGrade: 'clean_white',
        veilOpening: 'closed',
        packagingIntegrity: 'intact',
      );
      expect(wetResult['passed'], isFalse);
      expect(wetResult['qualityCompliant'], isFalse);
    });

    test('fresh harvest lot in quarantine is blocked from FEFO then unlocked on QC approval', () async {
      // 1. Create fresh harvest lot in QUARANTINE status
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-HARVEST-20261005-01',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'quarantine',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-HARVEST-01',
        locationId: 'WH1-COLD-A01-L1',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
      );

      // 2. Verify lot appears in quarantine queue
      final queue = await qcService.getQuarantineLots();
      expect(queue.any((q) => (q['lot'] as StockLot).id == lot.id), isTrue);

      // 3. Attempt FEFO allocation: MUST FAIL / BE UNFULFILLED because lot is in quarantine
      final unallocated = await fefoEngine.allocateStockFefo(
        productId: 'prod-cup-01',
        requestedQty: 72,
      );
      expect(unallocated.isFullyAllocated, isFalse);
      expect(unallocated.allocatedQuantity, 0.0);
      expect(unallocated.unfulfilledQuantity, 72.0);

      // 4. Submit QC Inspection PASS (Approve)
      final inspection = QcInspectionResult(
        id: 'insp-01',
        lotId: lot.id,
        lotNumber: lot.lotNumber,
        productId: lot.productId,
        productName: 'Cup Mushroom 4kg',
        lpnId: pallet.id,
        lpnCode: pallet.lpnCode,
        productTemperature: 2.9,
        surfaceMoisture: 'normal',
        discolorationGrade: 'clean_white',
        veilOpening: 'closed',
        packagingIntegrity: 'intact',
        status: 'approved',
        inspectedBy: 'QC-OFFICER-01',
        inspectedAt: DateTime.now(),
        passed: true,
      );

      final updatedLot = await qcService.submitInspection(inspection);
      expect(updatedLot.status, 'approved');
      expect(updatedLot.notes, contains('QC-OFFICER-01'));

      // 5. Verify FEFO allocation now SUCCEEDS immediately
      final allocResult = await fefoEngine.allocateStockFefo(
        productId: 'prod-cup-01',
        requestedQty: 72,
        executeReservation: true,
      );

      expect(allocResult.isFullyAllocated, isTrue);
      expect(allocResult.lines.first.lotNumber, lot.lotNumber);
    });

    test('failing QC inspection sets status to blocked and relocates pallet to WH1-QUARANTINE', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-FAIL-01',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'quarantine',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-REJECT-01',
        locationId: 'M1-STAGING',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
      );

      final inspection = QcInspectionResult(
        id: 'insp-fail-01',
        lotId: lot.id,
        lotNumber: lot.lotNumber,
        productId: lot.productId,
        productName: 'Cup Mushroom 4kg',
        lpnId: pallet.id,
        lpnCode: pallet.lpnCode,
        productTemperature: 8.5, // Extreme temperature
        surfaceMoisture: 'excess',
        discolorationGrade: 'severe',
        veilOpening: 'flat_open',
        packagingIntegrity: 'torn',
        status: 'blocked',
        notes: 'Nhiệt độ đứt gãy 8.5°C, rách bao bì, nấm nở bung.',
        inspectedBy: 'QC-SUPERVISOR',
        inspectedAt: DateTime.now(),
        passed: false,
      );

      final rejectedLot = await qcService.submitInspection(inspection);
      expect(rejectedLot.status, 'blocked');

      // Verify pallet relocated to WH1-QUARANTINE
      final movedPallet = await repo.getLpnByCode(pallet.lpnCode);
      expect(movedPallet?.locationId, 'WH1-QUARANTINE');

      // Verify audit stock move recorded
      final moves = await repo.getRecentPalletMoves();
      expect(moves.any((m) => m['dest'] == 'WH1-QUARANTINE'), isTrue);
    });
  });

  group('Perpetual Blind Cycle Count Tests', () {
    test('creates blind count session and hides expected book inventory in blind mode', () async {
      // 1. Seed stock quant at location WH1-COLD-A01-L1
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-CC-01',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-CC-01',
        locationId: 'WH1-COLD-A01-L1',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
      );

      // 2. Start blind cycle count session
      final session = await countService.startBlindSession(
        locationCode: 'WH1-COLD-A01-L1',
        countedBy: 'TECH-BOB',
      );

      expect(session.status, 'in_progress');
      expect(session.lines.length, 1);
      expect(session.lines.first.lpnCode, 'LPN-CC-01');
      expect(session.lines.first.lpnId, pallet.id);

      // In blind mode serialization, systemQty MUST BE NULL / MASKED
      final blindJson = session.toJson(maskSystemQty: true);
      final lineJson = (blindJson['lines'] as List).first as Map<String, dynamic>;
      expect(lineJson['system_qty'], isNull);
      expect(lineJson['variance_qty'], isNull);
    });

    test('detects physical variance and reconciles inventory with supervisor authorization', () async {
      // 1. Initial inventory: 72 boxes
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-CC-02',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-CC-02',
        locationId: 'WH1-COLD-A01-L1',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
      );

      // 2. Start session
      final session = await countService.startBlindSession(
        locationCode: 'WH1-COLD-A01-L1',
        countedBy: 'TECH-BOB',
      );

      // 3. Counter records physical count of 70 boxes (2 boxes shortage)
      final counted = await countService.recordBlindCountItem(
        sessionId: session.id,
        barcodeOrLpn: pallet.lpnCode,
        physicalQty: 70.0,
      );

      expect(counted.lines.first.countedQty, 70.0);
      expect(counted.lines.first.varianceQty, -2.0);
      expect(counted.lines.first.status, 'discrepancy');

      // 4. Complete count stage
      final completed = countService.completeCountStage(session.id);
      expect(completed.status, 'completed');
      expect(completed.discrepancyLines, 1);
      expect(completed.netVarianceQty, -2.0);

      // 5. Supervisor rejects reconciliation if PIN is invalid (< 4 digits)
      expect(
        () async => await countService.reconcileDiscrepancies(
          sessionId: completed.id,
          supervisorId: 'MGR-01',
          supervisorPin: '12',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 6. Supervisor approves reconciliation with valid PIN
      final reconciled = await countService.reconcileDiscrepancies(
        sessionId: completed.id,
        supervisorId: 'MGR-SUPERVISOR',
        supervisorPin: '8888',
        reconciliationNotes: '2 thùng hư hỏng trong quá trình vận chuyển đã huỷ.',
      );

      expect(reconciled.status, 'reconciled');
      expect(reconciled.approvedBy, 'MGR-SUPERVISOR');

      // 7. Verify StockQuants quantity is updated to 70.0
      final quants = await (db.select(db.stockQuants)
            ..where((tbl) => tbl.locationId.equals('WH1-COLD-A01-L1')))
          .get();
      expect(quants.first.quantity, 70.0);
      expect(quants.first.availableQty, 70.0);

      // 8. Verify adjustment StockMove was recorded to VIRTUAL-INVENTORY-LOSS
      final moves = await (db.select(db.stockMoves)
            ..where((tbl) => tbl.destLocationId.equals('VIRTUAL-INVENTORY-LOSS')))
          .get();
      expect(moves.length, 1);
      expect(moves.first.quantity, 2.0);
      expect(moves.first.transportType, 'manual');
    });

    test('detects unexpected ghost inventory found during count and adds new quant on reconcile', () async {
      // Start empty session at location
      final session = await countService.startBlindSession(
        locationCode: 'WH1-COLD-A02-L1',
        countedBy: 'TECH-BOB',
      );

      // Counter finds unrecorded SKU (barcode: 9312345000017) with 15 boxes
      final counted = await countService.recordBlindCountItem(
        sessionId: session.id,
        barcodeOrLpn: '9312345000017',
        physicalQty: 15.0,
      );

      expect(counted.lines.length, 1);
      expect(counted.lines.first.systemQty, 0.0);
      expect(counted.lines.first.countedQty, 15.0);
      expect(counted.lines.first.varianceQty, 15.0);

      final completed = countService.completeCountStage(session.id);
      final reconciled = await countService.reconcileDiscrepancies(
        sessionId: completed.id,
        supervisorId: 'MGR-01',
        supervisorPin: '8888',
      );

      expect(reconciled.status, 'reconciled');

      // Verify new quant created for found inventory
      final quants = await (db.select(db.stockQuants)
            ..where((tbl) => tbl.locationId.equals('WH1-COLD-A02-L1')))
          .get();
      expect(quants.length, 1);
      expect(quants.first.quantity, 15.0);
    });
  });
}
