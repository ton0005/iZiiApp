import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/supply_chain/repository.dart';
import 'package:izii_app/modules/warehouse_automation/models/wave_audit_models.dart';
import 'package:izii_app/modules/warehouse_automation/services/wave_picking_service.dart';
import 'package:izii_app/modules/warehouse_automation/services/packout_weight_audit_service.dart';

void main() {
  late AppDatabase db;
  late SupplyChainRepository repo;
  late WavePickingService waveService;
  late PackoutWeightAuditService auditService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = SupplyChainRepository(db);
    waveService = WavePickingService(db);
    auditService = PackoutWeightAuditService(db);

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

  group('Wave Picking Engine & Pick-Path Optimizer Tests', () {
    test('parseLocationCoords parses aisle, bay, and level correctly', () {
      final c1 = WavePickingService.parseLocationCoords('WH1-COLD-A01-R03-L2');
      expect(c1['aisle'], 'A01');
      expect(c1['aisleIndex'], 1);
      expect(c1['bay'], 3);
      expect(c1['level'], 2);

      final c2 = WavePickingService.parseLocationCoords('WH1-COLD-A02-R10-L1');
      expect(c2['aisle'], 'A02');
      expect(c2['aisleIndex'], 2);
      expect(c2['bay'], 10);
      expect(c2['level'], 1);
    });

    test('optimizePickPath sorts pick tasks in continuous S-shape serpentine route', () {
      final items = [
        const WavePickItem(
          id: 'i1',
          waveId: 'w1',
          sequence: 0,
          locationCode: 'WH1-COLD-A01-R05-L1',
          locationName: 'Bay 5',
          aisle: 'A01',
          bay: 5,
          level: 1,
          productId: 'prod-cup-01',
          productName: 'Cup 4kg',
          aggregatedQty: 10,
        ),
        const WavePickItem(
          id: 'i2',
          waveId: 'w1',
          sequence: 0,
          locationCode: 'WH1-COLD-A01-R01-L1',
          locationName: 'Bay 1',
          aisle: 'A01',
          bay: 1,
          level: 1,
          productId: 'prod-cup-01',
          productName: 'Cup 4kg',
          aggregatedQty: 10,
        ),
        const WavePickItem(
          id: 'i3',
          waveId: 'w1',
          sequence: 0,
          locationCode: 'WH1-COLD-A02-R02-L1',
          locationName: 'Bay 2',
          aisle: 'A02',
          bay: 2,
          level: 1,
          productId: 'prod-cup-01',
          productName: 'Cup 4kg',
          aggregatedQty: 10,
        ),
        const WavePickItem(
          id: 'i4',
          waveId: 'w1',
          sequence: 0,
          locationCode: 'WH1-COLD-A02-R08-L1',
          locationName: 'Bay 8',
          aisle: 'A02',
          bay: 8,
          level: 1,
          productId: 'prod-cup-01',
          productName: 'Cup 4kg',
          aggregatedQty: 10,
        ),
        const WavePickItem(
          id: 'i5',
          waveId: 'w1',
          sequence: 0,
          locationCode: 'WH1-COLD-A03-R04-L1',
          locationName: 'Bay 4',
          aisle: 'A03',
          bay: 4,
          level: 1,
          productId: 'prod-cup-01',
          productName: 'Cup 4kg',
          aggregatedQty: 10,
        ),
      ];

      final optimized = WavePickingService.optimizePickPath(items);

      // Verify continuous S-shape order:
      // Aisle 1 (odd) ascending: Bay 1 -> Bay 5
      expect(optimized[0].locationCode, 'WH1-COLD-A01-R01-L1');
      expect(optimized[0].sequence, 1);
      expect(optimized[1].locationCode, 'WH1-COLD-A01-R05-L1');
      expect(optimized[1].sequence, 2);

      // Aisle 2 (even) descending: Bay 8 -> Bay 2 (smooth curve to next aisle)
      expect(optimized[2].locationCode, 'WH1-COLD-A02-R08-L1');
      expect(optimized[2].sequence, 3);
      expect(optimized[3].locationCode, 'WH1-COLD-A02-R02-L1');
      expect(optimized[3].sequence, 4);

      // Aisle 3 (odd) ascending: Bay 4
      expect(optimized[4].locationCode, 'WH1-COLD-A03-R04-L1');
      expect(optimized[4].sequence, 5);
    });

    test('consolidates multiple delivery orders into single wave with aggregated pick tasks', () async {
      // 1. Create 2 sales pickings bound for same dispatch window
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-WAVE-01',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
      );

      const p1 = 'pick-so-01';
      const p2 = 'pick-so-02';

      await db.into(db.stockPickings).insert(StockPickingsCompanion.insert(
        id: p1,
        code: 'OUT-2026-W1',
        pickingType: 'outbound_sales',
        originDocument: const Value('SO-WOOLWORTHS-01'),
        status: const Value('waiting'),
        notes: const Value('Woolworths Mulgrave DC'),
      ));

      await db.into(db.stockPickings).insert(StockPickingsCompanion.insert(
        id: p2,
        code: 'OUT-2026-W2',
        pickingType: 'outbound_sales',
        originDocument: const Value('SO-COLES-02'),
        status: const Value('waiting'),
        notes: const Value('Coles Truganina DC'),
      ));

      // Same location & product for both orders (24 boxes + 48 boxes = 72 boxes)
      await db.into(db.stockPickingLines).insert(StockPickingLinesCompanion.insert(
        id: 'line-w1',
        pickingId: p1,
        productId: 'prod-cup-01',
        lotId: Value(lot.id),
        sourceLocationId: 'WH1-COLD-A01-R02-L1',
        destLocationId: 'DOCK-01-COLD',
        demandQty: const Value(24.0),
        uomId: 'box',
      ));

      await db.into(db.stockPickingLines).insert(StockPickingLinesCompanion.insert(
        id: 'line-w2',
        pickingId: p2,
        productId: 'prod-cup-01',
        lotId: Value(lot.id),
        sourceLocationId: 'WH1-COLD-A01-R02-L1',
        destLocationId: 'DOCK-01-COLD',
        demandQty: const Value(48.0),
        uomId: 'box',
      ));

      // 2. Create Wave
      final wave = await waveService.createWave(
        pickingIds: [p1, p2],
        dispatchWindow: 'Morning 08:00 - 10:00',
        carrier: 'Linfox Cold-Chain Transport',
        destinationDock: 'DOCK-01-COLD',
      );

      expect(wave.totalOrders, 2);
      expect(wave.totalDemandQty, 72.0);
      expect(wave.items.length, 1); // Aggregated into 1 pick task!
      expect(wave.items.first.aggregatedQty, 72.0);
      expect(wave.items.first.allocations.length, 2);

      // Verify StockPickings updated with waveId and status = assigned
      final updatedP1 = await (db.select(db.stockPickings)..where((tbl) => tbl.id.equals(p1))).getSingle();
      expect(updatedP1.waveId, wave.id);
      expect(updatedP1.status, 'assigned');

      // 3. Confirm pick execution
      final pickedWave = await waveService.confirmPickItem(
        waveId: wave.id,
        itemId: wave.items.first.id,
        quantity: 72.0,
        driverId: 'DRIVER-FORKLIFT-01',
      );

      expect(pickedWave.isCompleted, isTrue);
      expect(pickedWave.status, 'completed');

      // Verify moves created to destination dock
      final moves = await (db.select(db.stockMoves)..where((tbl) => tbl.destLocationId.equals('DOCK-01-COLD'))).get();
      expect(moves.length, 1);
      expect(moves.first.quantity, 72.0);
    });
  });

  group('Packout Scale Verification Station Tests', () {
    test('calculates accurate theoretical BOM weight for 72-box pallet', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-AUDIT-01',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-AUDIT-72',
        locationId: 'DOCK-01-COLD',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        tareWeightKg: 35.0, // AS 4068 pallet tare
      );

      final bom = await auditService.calculateTheoreticalBom(pallet.lpnCode);

      // Theoretical:
      // Pallet tare: 35kg
      // 72 boxes * 0.45kg carton tare = 32.4kg
      // 72 boxes * 4kg net = 288kg
      // Total theoretical gross = 35 + 32.4 + 288 = 355.4kg
      expect(bom['cartonCount'], 72.0);
      expect(bom['palletTareKg'], 35.0);
      expect(bom['totalBoxTareKg'], 32.4);
      expect(bom['productNetKg'], 288.0);
      expect(bom['theoreticalGrossKg'], 355.4);
    });

    test('audit passes when actual scale weight is within ±1.5% tolerance', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-AUDIT-02',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-PASS-01',
        locationId: 'DOCK-01-COLD',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        tareWeightKg: 35.0,
      );

      // Theoretical is 355.4 kg. Scale reads 356.2 kg (Variance = +0.8kg = +0.23% <= 1.5%)
      final audit = await auditService.auditPalletWeight(
        lpnCode: pallet.lpnCode,
        actualGrossKg: 356.2,
        auditedBy: 'AUDITOR-JOHN',
      );

      expect(audit.isPassed, isTrue);
      expect(audit.status, 'verified');
      expect(audit.variancePercentage.abs(), lessThanOrEqualTo(1.5));
      expect(audit.manifestAuthorizationCode, isNotNull);
      expect(audit.manifestAuthorizationCode, startsWith('MANIFEST-PASS-'));
    });

    test('audit fails and triggers anomaly alarm when weight exceeds +1.5% (Overweight / Excess moisture)', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-AUDIT-03',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-OVER-01',
        locationId: 'DOCK-01-COLD',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        tareWeightKg: 35.0,
      );

      // Theoretical is 355.4 kg. Scale reads 367.0 kg (Variance = +11.6kg = +3.26% > 1.5%)
      final audit = await auditService.auditPalletWeight(
        lpnCode: pallet.lpnCode,
        actualGrossKg: 367.0,
        auditedBy: 'AUDITOR-JOHN',
      );

      expect(audit.isPassed, isFalse);
      expect(audit.status, 'alarm_triggered');
      expect(audit.variancePercentage, greaterThan(1.5));
      expect(audit.manifestAuthorizationCode, isNull);
      expect(audit.anomalyMessage, contains('CẢNH BÁO DƯ TẢI'));

      // Check alarm recorded in automationEvents
      final events = await (db.select(db.automationEvents)..where((tbl) => tbl.ruleId.equals('DOCK_SCALE_WEIGHT_AUDIT_RULE'))).get();
      expect(events.length, 1);
      expect(events.first.status, 'failed');
    });

    test('audit fails when weight is under -1.5% (Underfilled / Missing carton)', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-AUDIT-04',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-UNDER-01',
        locationId: 'DOCK-01-COLD',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        tareWeightKg: 35.0,
      );

      // Theoretical is 355.4 kg. Scale reads 340.0 kg (Variance = -15.4kg = -4.33% < -1.5%)
      final audit = await auditService.auditPalletWeight(
        lpnCode: pallet.lpnCode,
        actualGrossKg: 340.0,
        auditedBy: 'AUDITOR-JOHN',
      );

      expect(audit.isPassed, isFalse);
      expect(audit.status, 'alarm_triggered');
      expect(audit.variancePercentage, lessThan(-1.5));
      expect(audit.anomalyMessage, contains('CẢNH BÁO THIẾU TẢI'));
    });
  });
}
