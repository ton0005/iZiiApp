import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/supply_chain/repository.dart';
import 'package:izii_app/modules/warehouse_automation/services/cold_chain_telemetry_service.dart';
import 'package:izii_app/modules/warehouse_automation/services/electronic_pod_service.dart';

void main() {
  late AppDatabase db;
  late SupplyChainRepository supplyRepo;
  late ColdChainTelemetryService telemetryService;
  late ElectronicPodService podService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    supplyRepo = SupplyChainRepository(db);
    telemetryService = ColdChainTelemetryService(db);
    podService = ElectronicPodService(db);

    // Seed product
    await supplyRepo.addProductWithStock(
      id: 'prod-cup-01',
      sku: 'MUSH-CUP-4KG',
      name: 'Cup Mushroom 4kg',
      price: 24.0,
      cost: 16.0,
      stock: 100,
      barcode: '9312345000017',
    );
  });

  tearDown(() async {
    telemetryService.dispose();
    await db.close();
  });

  group('Cold-Chain Telemetry & MKT Haynes Equation Tests', () {
    test('checkPreTripBattery enforces Risk #4 requirement (> 20%)', () {
      final failCheck = telemetryService.checkPreTripBattery(18.0);
      expect(failCheck['passed'], isFalse);
      expect((failCheck['message'] as String).contains('CẢNH BÁO PIN YẾU'), isTrue);

      final passCheck = telemetryService.checkPreTripBattery(85.0);
      expect(passCheck['passed'], isTrue);
      expect((passCheck['message'] as String).contains('đạt chuẩn xuất phát'), isTrue);
    });

    test('calculateMeanKineticTemperature returns identical value for constant temperatures', () {
      final temps = [3.0, 3.0, 3.0, 3.0];
      final mkt = ColdChainTelemetryService.calculateMeanKineticTemperature(temps);
      expect(mkt, 3.0);
    });

    test('calculateMeanKineticTemperature gives higher exponential weight to excursion spikes', () {
      // 3 normal readings at 2.0°C and 1 spike at 8.0°C
      final temps = [2.0, 2.0, 2.0, 8.0];
      final arithmeticMean = temps.reduce((a, b) => a + b) / temps.length; // 3.5°C
      final mkt = ColdChainTelemetryService.calculateMeanKineticTemperature(temps);

      // In Haynes equation, MKT must be strictly greater than the arithmetic mean
      expect(mkt, greaterThan(arithmeticMean));
      expect(mkt, greaterThanOrEqualTo(3.9));
      expect(mkt, closeTo(3.96, 0.05));
    });

    test('startTrip registers device and records readings in Drift database', () async {
      final trip = await telemetryService.startTrip(
        tripId: 'TRIP-TEST-001',
        deliveryId: 'DELIV-TEST-01',
        vehiclePlate: 'VIC-TEST-123',
        trailerId: 'TRL-01',
        loggerDeviceId: 'DEV-BLE-001',
        loggerName: 'Reefer Logger 1',
        batteryLevel: 95.0,
      );

      expect(trip.status, 'active');
      expect(trip.preTripBatteryCheckPassed, isTrue);

      // Verify device recorded in IotDevices
      final device = await (db.select(db.iotDevices)
            ..where((tbl) => tbl.devEui.equals('DEV-BLE-001')))
          .getSingle();
      expect(device.name, 'Reefer Logger 1');
      expect(device.batteryLevel, 95.0);

      // Record a normal reading
      final reading = await telemetryService.recordReading(
        temperatureC: 2.8,
        humidityPct: 92.0,
        batteryPct: 94.0,
      );

      expect(reading.isExcursion, isFalse);

      // Verify recorded in SensorReadings
      final readingsInDb = await (db.select(db.sensorReadings)
            ..where((tbl) => tbl.deviceId.equals('DEV-BLE-001')))
          .get();
      expect(readingsInDb.length, greaterThanOrEqualTo(1));
      expect(readingsInDb.any((r) => r.metric == 'temperature' && r.value == 2.8), isTrue);
    });

    test('recordReading triggers critical alarm and logs AutomationEvent on excursion (>5°C)', () async {
      await telemetryService.startTrip(
        tripId: 'TRIP-TEST-002',
        deliveryId: 'DELIV-TEST-02',
        vehiclePlate: 'VIC-TEST-456',
        trailerId: 'TRL-02',
        loggerDeviceId: 'DEV-BLE-002',
        loggerName: 'Reefer Logger 2',
        batteryLevel: 80.0,
      );

      String? emittedAlarm;
      final sub = telemetryService.alarmStream.listen((msg) {
        emittedAlarm = msg;
      });

      // Record severe excursion reading
      await telemetryService.recordReading(
        temperatureC: 7.4,
        humidityPct: 88.0,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emittedAlarm, isNotNull);
      expect(emittedAlarm!.contains('CẢNH BÁO NHIỆT ĐỘ VƯỢT MỨC'), isTrue);

      // Verify automationEvents entry
      final events = await (db.select(db.automationEvents)
            ..where((tbl) => tbl.ruleId.equals('COLD_CHAIN_REEFER_EXCURSION_ALARM')))
          .get();
      expect(events.length, 1);
      expect(events.first.triggeringValue, 7.4);
      expect(events.first.status, 'failed');

      // Verify trip status became alarm_triggered
      expect(telemetryService.activeTrip?.status, 'alarm_triggered');
      expect(telemetryService.activeTrip?.isCompliant, isFalse);
    });

    test('generateComplianceCertificate outputs complete HACCP summary', () async {
      await telemetryService.startTrip(
        tripId: 'TRIP-CERT-01',
        vehiclePlate: 'VIC-REEFER-999',
        trailerId: 'TRL-COLD-99',
        loggerDeviceId: 'DEV-BLE-99',
        loggerName: 'Logger 99',
        batteryLevel: 90.0,
      );

      await telemetryService.recordReading(temperatureC: 2.5);
      await telemetryService.recordReading(temperatureC: 3.1);
      await telemetryService.recordReading(temperatureC: 2.8);

      final completedTrip = telemetryService.completeTrip();
      final cert = telemetryService.generateComplianceCertificate(completedTrip);

      expect(cert['certificate_number'], startsWith('CERT-CC-'));
      expect(cert['vehicle_plate'], 'VIC-REEFER-999');
      expect(cert['min_temp_c'], 2.5);
      expect(cert['max_temp_c'], 3.1);
      expect(cert['compliance_status'], 'PASSED_COMPLIANT');
      expect(cert['regulation_standard'], contains('HACCP'));
    });
  });

  group('Electronic Proof of Delivery (e-PoD) Tests', () {
    test('computeCryptoHash produces deterministic SHA-256 seal', () async {
      final now = DateTime(2026, 10, 5, 14, 0, 0);
      final hash1 = await podService.computeCryptoHash(
        pickingId: 'PICK-001',
        orderCode: 'SO-2026-0042',
        recipientName: 'Alice Supervisor',
        sealNumber: 'SEAL-AU-1001',
        sealIntact: true,
        deliveredAt: now,
        lat: -37.9252,
        lng: 145.1764,
      );

      final hash2 = await podService.computeCryptoHash(
        pickingId: 'PICK-001',
        orderCode: 'SO-2026-0042',
        recipientName: 'Alice Supervisor',
        sealNumber: 'SEAL-AU-1001',
        sealIntact: true,
        deliveredAt: now,
        lat: -37.9252,
        lng: 145.1764,
      );

      expect(hash1, startsWith('SHA256:'));
      expect(hash1, equals(hash2));

      // Altering seal number produces a completely different hash
      final alteredHash = await podService.computeCryptoHash(
        pickingId: 'PICK-001',
        orderCode: 'SO-2026-0042',
        recipientName: 'Alice Supervisor',
        sealNumber: 'SEAL-AU-9999-TAMPERED',
        sealIntact: true,
        deliveredAt: now,
        lat: -37.9252,
        lng: 145.1764,
      );

      expect(alteredHash, isNot(equals(hash1)));
    });

    test('submitDeliveryProof completes order, updates status to delivered, and queues billing', () async {
      // 1. Seed picking and line
      await db.into(db.stockPickings).insert(StockPickingsCompanion.insert(
            id: 'PICK-EPOD-01',
            code: 'OUT-2026-0099',
            pickingType: 'outbound_sales',
            originDocument: const Value('SO-2026-0099'),
            status: const Value('in_transit'),
          ));

      await db.into(db.stockPickingLines).insert(StockPickingLinesCompanion.insert(
            id: 'LINE-EPOD-01',
            pickingId: 'PICK-EPOD-01',
            productId: 'prod-cup-01',
            sourceLocationId: 'WH1-COLD-DOCK',
            destLocationId: 'CUSTOMER-DC',
            demandQty: const Value(72.0),
            uomId: 'box',
            status: const Value('reserved'),
          ));

      // 2. Submit e-PoD
      final record = await podService.submitDeliveryProof(
        pickingId: 'PICK-EPOD-01',
        orderCode: 'SO-2026-0099',
        customerName: 'Woolworths DC Mulgrave',
        destinationAddress: '120 Police Rd, Mulgrave VIC',
        recipientName: 'Robert Vance',
        recipientDesignation: 'Receiving Dock Manager',
        sealNumber: 'SEAL-AU-88319',
        sealIntact: true,
        cartonCount: 72,
        palletCount: 1,
        grossWeightKg: 355.4,
        manualLat: -37.9252,
        manualLng: 145.1764,
      );

      expect(record.manifestAuthorizationCode, startsWith('EPOD-'));
      expect(record.cryptoHash, startsWith('SHA256:'));
      expect(record.syncStatus, 'erp_synced');

      // 3. Verify StockPicking status transitioned to delivered
      final pickingInDb = await (db.select(db.stockPickings)
            ..where((tbl) => tbl.id.equals('PICK-EPOD-01')))
          .getSingle();
      expect(pickingInDb.status, 'delivered');
      expect(pickingInDb.completedDate, isNotNull);
      expect(pickingInDb.notes, contains('Robert Vance'));
      expect(pickingInDb.notes, contains('SEAL-AU-88319'));

      // 4. Verify StockPickingLines updated to done
      final lineInDb = await (db.select(db.stockPickingLines)
            ..where((tbl) => tbl.id.equals('LINE-EPOD-01')))
          .getSingle();
      expect(lineInDb.status, 'done');
    });

    test('getPendingDeliveryStops retrieves active delivery stops', () async {
      await db.into(db.stockPickings).insert(StockPickingsCompanion.insert(
            id: 'PICK-STOP-01',
            code: 'OUT-2026-0101',
            pickingType: 'outbound_sales',
            originDocument: const Value('SO-2026-0101-WOOLWORTHS'),
            status: const Value('assigned'),
            notes: const Value('Customer: Woolworths Distribution Centre | Address: Mulgrave VIC'),
          ));

      await db.into(db.stockPickingLines).insert(StockPickingLinesCompanion.insert(
            id: 'LINE-STOP-01',
            pickingId: 'PICK-STOP-01',
            productId: 'prod-cup-01',
            sourceLocationId: 'WH1-COLD-A01',
            destLocationId: 'WH1-DOCK',
            demandQty: const Value(144.0),
            uomId: 'box',
          ));

      final stops = await podService.getPendingDeliveryStops();
      expect(stops.length, greaterThanOrEqualTo(1));
      final ourStop = stops.firstWhere((s) => s.pickingId == 'PICK-STOP-01');
      expect(ourStop.customerName, contains('Woolworths'));
      expect(ourStop.cartonCount, 144);
      expect(ourStop.palletCount, 2);
    });
  });
}
