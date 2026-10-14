import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/supply_chain/repository.dart';

void main() {
  late AppDatabase db;
  late SupplyChainRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = SupplyChainRepository(db);

    // Seed dummy locations and product
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

  group('SupplyChainRepository - LPN & Lot Management', () {
    test('creates lot with correct status and dates', () async {
      final now = DateTime.now();
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R33-CUP',
        productionDate: now,
        bestBeforeDate: now.add(const Duration(days: 5)),
        expiryDate: now.add(const Duration(days: 7)),
        status: 'approved',
        notes: 'Test harvest batch',
      );

      expect(lot.lotNumber, 'LOT-20261005-R33-CUP');
      expect(lot.status, 'approved');

      final queriedLot = await repo.getLotByNumber('LOT-20261005-R33-CUP');
      expect(queriedLot, isNotNull);
      expect(queriedLot!.productId, 'prod-cup-01');
    });

    test('creates pallet LPN and registers quant on staging location', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R33-CUP',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-M1-20261005-A1B2C3',
        locationId: 'M1-STAGING',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        grossWeightKg: 323.2,
        tareWeightKg: 35.0,
        netWeightKg: 288.2,
      );

      expect(pallet.lpnCode, 'LPN-M1-20261005-A1B2C3');
      expect(pallet.status, 'staged');
      expect(pallet.grossWeightKg, 323.2);
      expect(pallet.netWeightKg, 288.2);

      // Verify LPN can be queried
      final queried = await repo.getLpnByCode('LPN-M1-20261005-A1B2C3');
      expect(queried, isNotNull);
      expect(queried!.locationId, 'M1-STAGING');

      // Verify StockQuants record is registered
      final quants = await db.select(db.stockQuants).get();
      final lpnQuant = quants.firstWhere((q) => q.lpnId == pallet.id);
      expect(lpnQuant.quantity, 72.0);
      expect(lpnQuant.availableQty, 72.0);
      expect(lpnQuant.lotId, lot.id);
    });

    test('retrieves full LPN details with product and lot information', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R33-CUP',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-M1-DETAIL-01',
        locationId: 'M1-STAGING',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        grossWeightKg: 323.2,
        tareWeightKg: 35.0,
        netWeightKg: 288.2,
      );

      final details = await repo.getLpnFullDetails(pallet.lpnCode);
      expect(details, isNotNull);
      expect(details!['product_name'], 'Cup Mushroom 4kg');
      expect(details['lot_number'], 'LOT-20261005-R33-CUP');
      expect(details['total_quantity'], 72.0);
      expect(details['uom'], 'box');
      expect(details['net_weight'], 288.2);
      expect(details['status'], 'staged');
    });

    test('relocates pallet with forklift, updates quants, lpns and records stock_moves', () async {
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R33-CUP',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-M1-MOVE-01',
        locationId: 'M1-STAGING',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        grossWeightKg: 323.2,
        tareWeightKg: 35.0,
        netWeightKg: 288.2,
      );

      // Perform relocation via Forklift
      await repo.movePalletLpn(
        lpnCode: pallet.lpnCode,
        destLocationId: 'WH1-COLD-A01-R01-L1',
        transportType: 'FL-01 (Toyota Reach Truck)',
      );

      // 1. Verify StockLpns updated
      final updatedPallet = await repo.getLpnByCode(pallet.lpnCode);
      expect(updatedPallet, isNotNull);
      expect(updatedPallet!.locationId, 'WH1-COLD-A01-R01-L1');
      expect(updatedPallet.status, 'stored');

      // 2. Verify StockQuants updated
      final quants = await (db.select(db.stockQuants)
            ..where((tbl) => tbl.lpnId.equals(pallet.id)))
          .get();
      expect(quants.isNotEmpty, isTrue);
      expect(quants.first.locationId, 'WH1-COLD-A01-R01-L1');

      // 3. Verify StockMoves recorded
      final moves = await (db.select(db.stockMoves)
            ..where((tbl) => tbl.lpnId.equals(pallet.id)))
          .get();
      expect(moves.length, 1);
      final move = moves.first;
      expect(move.sourceLocationId, 'M1-STAGING');
      expect(move.destLocationId, 'WH1-COLD-A01-R01-L1');
      expect(move.quantity, 72.0);
      expect(move.status, 'done');
      expect(move.transportType, 'FL-01 (Toyota Reach Truck)');

      // 4. Verify getRecentPalletMoves
      final recentMoves = await repo.getRecentPalletMoves();
      expect(recentMoves.isNotEmpty, isTrue);
      expect(recentMoves.first['lpn_code'], pallet.lpnCode);
      expect(recentMoves.first['source'], 'M1-STAGING');
      expect(recentMoves.first['dest'], 'WH1-COLD-A01-R01-L1');
    });

    test('seeds and retrieves default warehouse locations', () async {
      final locs = await repo.getAvailableLocations();
      expect(locs.isNotEmpty, isTrue);

      final codes = locs.map((l) => l.code).toSet();
      expect(codes.contains('M1-STAGING'), isTrue);
      expect(codes.contains('WH1-COLD-GATE'), isTrue);
      expect(codes.contains('WH1-COLD-A01-R01-L1'), isTrue);
      expect(codes.contains('WH1-QUARANTINE'), isTrue);
    });
  });
}
