import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/supply_chain/repository.dart';
import 'package:izii_app/modules/warehouse_automation/services/directed_putaway_engine.dart';
import 'package:izii_app/modules/warehouse_automation/services/fefo_allocation_engine.dart';

void main() {
  late AppDatabase db;
  late SupplyChainRepository repo;
  late DirectedPutawayEngine putawayEngine;
  late FefoAllocationEngine fefoEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = SupplyChainRepository(db);
    putawayEngine = DirectedPutawayEngine(db, repo);
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

  group('3D Directed Putaway Engine Tests', () {
    test('recommends Level 1 floor position for heavy pallet (323.2 kg)', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R33-CUP',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-HEAVY-01',
        locationId: 'M1-STAGING',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        grossWeightKg: 323.2,
        tareWeightKg: 35.0,
        netWeightKg: 288.2,
      );

      final rec = await putawayEngine.calculateOptimalPutaway(pallet.lpnCode);

      expect(rec, isNotNull);
      // Heavy pallet must be directed to a Level 1 floor bin
      expect(rec!.targetLocation.code.endsWith('-L1'), isTrue);
      expect(rec.palletGrossWeightKg, 323.2);
      expect(rec.slotReason, contains('Tầng 1'));
      expect(rec.score, greaterThan(100.0));
    });

    test('prefers Fast-Moving bay A02 when available', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R33-CUP',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-FAST-01',
        locationId: 'M1-STAGING',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        grossWeightKg: 310.0,
        tareWeightKg: 35.0,
        netWeightKg: 275.0,
      );

      final rec = await putawayEngine.calculateOptimalPutaway(pallet.lpnCode);

      expect(rec, isNotNull);
      // Fast-moving bay A02 level 1 has highest composite score
      expect(rec!.targetLocation.code, 'WH1-COLD-A02-R01-L1');
      expect(rec.slotReason, contains('Fast-Moving'));
    });
  });

  group('Automated Outbound FEFO Allocation Engine Tests', () {
    test('allocates stock strictly by earliest expiry date and excludes quarantine lots', () async {
      final now = DateTime.now();

      // Lot 1: Expiring in 4 days (Oldest approved batch -> Must be picked first)
      final lot1 = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261001-R33-CUP',
        expiryDate: now.add(const Duration(days: 4)),
        status: 'approved',
      );

      // Lot 2: Expiring in 8 days (Fresher approved batch -> Picked second)
      final lot2 = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R34-CUP',
        expiryDate: now.add(const Duration(days: 8)),
        status: 'approved',
      );

      // Lot 3: Expiring in 2 days but in QUARANTINE -> MUST BE SKIPPED
      final lot3Quarantine = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20260929-R30-CUP',
        expiryDate: now.add(const Duration(days: 2)),
        status: 'quarantine',
      );

      // Create Pallet LPNs stored in racks
      final pallet1 = await repo.createPalletLpn(
        lpnCode: 'LPN-PALLET-01',
        locationId: 'WH1-COLD-A01-R01-L1',
        productId: 'prod-cup-01',
        lotId: lot1.id,
        quantity: 50,
        uomId: 'box',
      );

      final pallet2 = await repo.createPalletLpn(
        lpnCode: 'LPN-PALLET-02',
        locationId: 'WH1-COLD-A02-R01-L1',
        productId: 'prod-cup-01',
        lotId: lot2.id,
        quantity: 100,
        uomId: 'box',
      );

      await repo.createPalletLpn(
        lpnCode: 'LPN-PALLET-03-QC',
        locationId: 'WH1-QUARANTINE',
        productId: 'prod-cup-01',
        lotId: lot3Quarantine.id,
        quantity: 72,
        uomId: 'box',
      );

      // Mark pallets as stored in racks
      await repo.movePalletLpn(lpnCode: pallet1.lpnCode, destLocationId: 'WH1-COLD-A01-R01-L1');
      await repo.movePalletLpn(lpnCode: pallet2.lpnCode, destLocationId: 'WH1-COLD-A02-R01-L1');

      // Request 80 boxes outbound
      final result = await fefoEngine.allocateStockFefo(
        productId: 'prod-cup-01',
        requestedQty: 80.0,
        executeReservation: true,
      );

      expect(result.isFullyAllocated, isTrue);
      expect(result.allocatedQuantity, 80.0);
      expect(result.lines.length, 2);

      // First pick MUST be Lot 1 (Expiring in 4 days): all 50 boxes
      final pick1 = result.lines[0];
      expect(pick1.lotNumber, 'LOT-20261001-R33-CUP');
      expect(pick1.allocatedQty, 50.0);
      expect(pick1.locationCode, 'WH1-COLD-A01-R01-L1');

      // Second pick MUST be Lot 2 (Expiring in 8 days): remaining 30 boxes
      final pick2 = result.lines[1];
      expect(pick2.lotNumber, 'LOT-20261005-R34-CUP');
      expect(pick2.allocatedQty, 30.0);
      expect(pick2.locationCode, 'WH1-COLD-A02-R01-L1');

      // Lot 3 in quarantine was NOT picked
      expect(result.lines.any((l) => l.lotNumber == 'LOT-20260929-R30-CUP'), isFalse);

      // Verify StockQuants reservation in DB
      final quants = await db.select(db.stockQuants).get();
      final quant1 = quants.firstWhere((q) => q.lotId == lot1.id);
      expect(quant1.reservedQty, 50.0);
      expect(quant1.availableQty, 0.0); // Completely consumed

      final quant2 = quants.firstWhere((q) => q.lotId == lot2.id);
      expect(quant2.reservedQty, 30.0);
      expect(quant2.availableQty, 70.0); // 100 - 30 = 70 available
    });
  });
}
