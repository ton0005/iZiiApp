import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/supply_chain/repository.dart';
import 'package:izii_app/modules/warehouse_automation/models/conveyor_models.dart';
import 'package:izii_app/modules/warehouse_automation/services/central_conveyor_service.dart';

void main() {
  late AppDatabase db;
  late SupplyChainRepository repo;
  late CentralConveyorService conveyorService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = SupplyChainRepository(db);
    conveyorService = CentralConveyorService(db, repo);

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
    conveyorService.dispose();
    await db.close();
  });

  group('CentralConveyorService Telemetry & Palletization Tests', () {
    test('processes clean carton through Metal Detector, Vision, and Check-Weigher', () async {
      final box = await conveyorService.processCartonOnConveyor(
        productSku: 'MUSH-CUP-4KG',
        productName: 'Cup Mushroom 4kg',
        expectedGrade: 'Cup',
        roomCode: 'R33',
        lotNumber: 'LOT-20261005-R33-CUP',
      );

      expect(box.status, BoxStatus.palletized);
      expect(box.metalCheck, isNotNull);
      expect(box.metalCheck!.hasMetal, isFalse);
      expect(box.metalCheck!.isPassed, isTrue);

      expect(box.visionCheck, isNotNull);
      expect(box.visionCheck!.isPassed, isTrue);
      expect(box.visionCheck!.detectedGrade, 'Cup');
      expect(box.visionCheck!.capDiameterMm, greaterThanOrEqualTo(45.0));

      expect(box.weigherResult, isNotNull);
      expect(box.weigherResult!.isWithinTolerance, isTrue);
      expect(box.weigherResult!.netWeightKg, closeTo(4.0, 0.1));

      // Verify SensorReadings record was written to DB
      final readings = await db.select(db.sensorReadings).get();
      expect(readings.isNotEmpty, isTrue);
      final weightReading = readings.firstWhere((r) => r.metric == 'weight_kg');
      expect(weightReading.unit, 'kg');
      expect(weightReading.value, closeTo(4.0, 0.1));

      expect(conveyorService.currentPalletBoxCount, 1);
    });

    test('diverts contaminated carton at Metal Detector', () async {
      final box = await conveyorService.processCartonOnConveyor(
        productSku: 'MUSH-CUP-4KG',
        productName: 'Cup Mushroom 4kg',
        expectedGrade: 'Cup',
        roomCode: 'R33',
        lotNumber: 'LOT-20261005-R33-CUP',
        simulateMetalContamination: true,
      );

      expect(box.status, BoxStatus.divertedMetal);
      expect(box.metalCheck!.hasMetal, isTrue);
      expect(box.metalCheck!.isPassed, isFalse);
      expect(conveyorService.metalRejectCount, 1);

      // Box was rejected, should NOT be accumulated on pallet
      expect(conveyorService.currentPalletBoxCount, 0);
    });

    test('diverts defective carton at AI Vision inspection', () async {
      final box = await conveyorService.processCartonOnConveyor(
        productSku: 'MUSH-CUP-4KG',
        productName: 'Cup Mushroom 4kg',
        expectedGrade: 'Cup',
        roomCode: 'R33',
        lotNumber: 'LOT-20261005-R33-CUP',
        simulateVisionDefect: true,
      );

      expect(box.status, BoxStatus.divertedVision);
      expect(box.visionCheck!.isPassed, isFalse);
      expect(conveyorService.visionRejectCount, 1);
      expect(conveyorService.currentPalletBoxCount, 0);
    });

    test('accumulates 72 cartons and mints Pallet LPN with accurate weight sum', () async {
      for (int i = 0; i < 72; i++) {
        await conveyorService.processCartonOnConveyor(
          productSku: 'MUSH-CUP-4KG',
          productName: 'Cup Mushroom 4kg',
          expectedGrade: 'Cup',
          roomCode: 'R33',
          lotNumber: 'LOT-20261005-R33-CUP',
        );
      }

      expect(conveyorService.currentPalletBoxCount, 72);

      // Finalize pallet
      final pallet = await conveyorService.finalizePalletAtCentralStation(
        plant: 'M1',
        customLotNumber: 'LOT-20261005-R33-CUP',
      );

      expect(pallet, isNotNull);
      expect(pallet!.status, 'staged');
      expect(pallet.locationId, 'M1-STAGING');

      // 72 boxes * ~4.0kg net = ~288.0 kg net
      expect(pallet.netWeightKg, closeTo(288.0, 3.0));
      // Gross = Net + 35.0 kg timber pallet tare
      expect(pallet.grossWeightKg, closeTo(288.0 + 35.0, 3.0));
      expect(pallet.tareWeightKg, 35.0);

      // Accumulator is reset
      expect(conveyorService.currentPalletBoxCount, 0);
    });

    test('verifies pallet at airlock weighbridge and triggers door opening upon weight match', () async {
      // Create a test pallet
      final lot = await repo.createLot(
        productId: 'prod-cup-01',
        lotNumber: 'LOT-20261005-R33-CUP',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      );

      final pallet = await repo.createPalletLpn(
        lpnCode: 'LPN-M1-WEIGH-01',
        locationId: 'M1-STAGING',
        productId: 'prod-cup-01',
        lotId: lot.id,
        quantity: 72,
        uomId: 'box',
        grossWeightKg: 323.2,
        tareWeightKg: 35.0,
        netWeightKg: 288.2,
      );

      // 1. In-floor scale test with matching weight (323.5 kg, variance ~0.09% <= 1.5%)
      final passResult = await conveyorService.verifyPalletAtGateWeighbridge(
        lpnCode: pallet.lpnCode,
        scaleMeasuredGrossKg: 323.5,
      );

      expect(passResult.isDoorOpened, isTrue);
      expect(passResult.differencePct, lessThan(1.5));
      expect(passResult.validationMessage, contains('TẢI TRỌNG HỢP LỆ'));

      // Verify automation event was created for door trigger
      final autoEvents = await db.select(db.automationEvents).get();
      expect(autoEvents.isNotEmpty, isTrue);
      final doorEvent = autoEvents.firstWhere((e) => e.ruleId == 'RULE-DOOR-AUTO-OPEN-01');
      expect(doorEvent.status, 'executed');

      // 2. In-floor scale test with mismatched weight (345.0 kg, variance > 6%)
      final failResult = await conveyorService.verifyPalletAtGateWeighbridge(
        lpnCode: pallet.lpnCode,
        scaleMeasuredGrossKg: 345.0,
      );

      expect(failResult.isDoorOpened, isFalse);
      expect(failResult.differencePct, greaterThan(1.5));
      expect(failResult.validationMessage, contains('CẢNH BÁO LỆCH TẢI TRỌNG'));
    });
  });
}
