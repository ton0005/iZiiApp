import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/supply_chain/repository.dart';
import 'package:izii_app/modules/warehouse_automation/services/harvest_wms_hook_service.dart';

void main() {
  late AppDatabase db;
  late SupplyChainRepository repo;
  late HarvestWmsHookService hookService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = SupplyChainRepository(db);
    hookService = HarvestWmsHookService(db, repo);

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

  group('HarvestWmsHookService Tests', () {
    test('converts MES harvest completion into WMS Inbound Picking and Lot', () async {
      final planDate = DateTime(2026, 10, 5);

      final result = await hookService.convertHarvestYieldToWmsInbound(
        planId: 'PLAN_20261005_M1',
        planDate: planDate,
        zoneId: 'M1',
        roomCode: 'Room 33',
        grade: 'Cup',
        pickedBoxes: 288,
        productId: 'prod-cup-01',
        notes: 'Harvest shift A handover to Packhouse conveyor',
      );

      expect(result['picking_id'], isNotEmpty);
      expect(result['lot_number'], 'LOT-20261005-R33-CUP');
      expect(result['source_location'], 'M1-STAGING');
      expect(result['dest_location'], 'WH1-COLD-GATE');
      expect(result['picked_boxes'], 288);

      // Verify StockLots record in DB
      final lot = await repo.getLotByNumber('LOT-20261005-R33-CUP');
      expect(lot, isNotNull);
      expect(lot!.status, 'approved');
      expect(lot.bestBeforeDate, planDate.add(const Duration(days: 5)));
      expect(lot.expiryDate, planDate.add(const Duration(days: 7)));

      // Verify StockPickings record in DB
      final pickings = await db.select(db.stockPickings).get();
      expect(pickings.length, 1);
      final pick = pickings.first;
      expect(pick.pickingType, 'incoming_harvest');
      expect(pick.originDocument, 'HARVEST-PLAN_20261005_M1');
      expect(pick.sourceLocationId, 'M1-STAGING');
      expect(pick.destLocationId, 'WH1-COLD-GATE');
      expect(pick.status, 'confirmed');

      // Verify StockPickingLines record in DB
      final lines = await db.select(db.stockPickingLines).get();
      expect(lines.length, 1);
      final line = lines.first;
      expect(line.productId, 'prod-cup-01');
      expect(line.demandQty, 288.0);
      expect(line.doneQty, 288.0);
      expect(line.uomId, 'box');
      expect(line.lotId, lot.id);
    });
  });
}
