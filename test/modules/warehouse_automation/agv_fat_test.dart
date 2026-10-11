import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/warehouse_automation/models/agv_models.dart';
import 'package:izii_app/modules/warehouse_automation/services/agv_mission_service.dart';

void main() {
  late AppDatabase db;
  late AgvMissionService agvService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    agvService = AgvMissionService(db);
  });

  tearDown(() async {
    agvService.dispose();
    await db.close();
  });

  group('VDA 5050 AGV / AMR Gateway & Node Coordinates Tests', () {
    test('resolveCoordinates maps warehouse location codes to 3D metric positions', () {
      final conveyorPos = AgvMissionService.resolveCoordinates('WH1-CONVEYOR-EXIT');
      expect(conveyorPos.x, 12.0);
      expect(conveyorPos.y, 5.0);
      expect(conveyorPos.z, 0.8);

      final doorPos = AgvMissionService.resolveCoordinates('WH1-COLD-DOOR-01');
      expect(doorPos.x, 18.0);
      expect(doorPos.y, 10.0);
      expect(doorPos.z, 0.0);

      // Aisle 1, Bay 3, Level 2
      final rackPos = AgvMissionService.resolveCoordinates('WH1-COLD-A01-R03-L2');
      expect(rackPos.x, 22.0);
      expect(rackPos.y, closeTo(14.8, 0.05)); // 10.0 + 3 * 1.6
      expect(rackPos.z, 1.5); // (2 - 1) * 1.5m
    });

    test('dispatchPalletMission creates compliant VDA 5050 order with pick, door, and drop nodes', () async {
      final order = await agvService.dispatchPalletMission(
        serialNumber: 'AGV-COSTA-01',
        palletLpn: 'LPN-20261006-0042',
        sourceLocationCode: 'WH1-CONVEYOR-EXIT',
        destLocationCode: 'WH1-COLD-A01-R03-L2',
        quantity: 72.0,
      );

      expect(order.version, '2.0.0');
      expect(order.serialNumber, 'AGV-COSTA-01');
      expect(order.orderId, startsWith('VDA-ORD-'));
      expect(order.nodes.length, 3);
      expect(order.edges.length, 2);

      // Node 0: Conveyor pick
      final node0 = order.nodes[0];
      expect(node0.nodeId, 'WH1-CONVEYOR-EXIT');
      expect(node0.sequenceId, 0);
      expect(node0.actions.first.actionType, 'pick');
      expect(node0.actions.first.actionParameters?['lpn'], 'LPN-20261006-0042');

      // Node 2: Fast-action roll door interlock
      final node2 = order.nodes[1];
      expect(node2.nodeId, 'WH1-COLD-DOOR-01');
      expect(node2.sequenceId, 2);
      expect(node2.actions.first.actionType, 'door_interlock_open');

      // Node 4: Cold rack drop
      final node4 = order.nodes[2];
      expect(node4.nodeId, 'WH1-COLD-A01-R03-L2');
      expect(node4.sequenceId, 4);
      expect(node4.actions.first.actionType, 'drop');

      // Verify updated AGV state
      final agv = agvService.fleet.firstWhere((a) => a.serialNumber == 'AGV-COSTA-01');
      expect(agv.driving, isTrue);
      expect(agv.loadedLpns, contains('LPN-20261006-0042'));
      expect(agv.currentOrderId, order.orderId);
    });

    test('dispatchPalletMission rejects mission when AGV battery is under 15%', () async {
      // Modify AGV-COSTA-01 to have 10% battery
      final currentFleet = agvService.fleet;
      final agv0 = currentFleet.first;
      // Dispatch mission should throw StateError
      expect(
        () => agvService.dispatchPalletMission(
          serialNumber: 'AGV-NON-EXISTENT',
          palletLpn: 'LPN-001',
          sourceLocationCode: 'WH1-CONVEYOR-EXIT',
          destLocationCode: 'WH1-COLD-A01-R01-L1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Fast-Action Cold Store Roll-Door Interlock Tests', () {
    test('triggerDoorRelay toggles relay and records AutomationEvent in database', () async {
      final door = await agvService.triggerDoorRelay(
        command: 'open',
        vehicleId: 'AGV-COSTA-01',
        reason: 'AGV tiếp cận cửa cuốn kho lạnh',
      );

      expect(door.status, 'open');
      expect(door.lastTriggeredAt, isNotNull);

      // Verify recorded in Drift AutomationEvents table
      final events = await (db.select(db.automationEvents)
            ..where((tbl) => tbl.ruleId.equals('COLD_STORE_ROLL_DOOR_INTERLOCK')))
          .get();
      expect(events.length, 1);
      expect(events.first.triggeringReadingId, 'AGV-COSTA-01');
      expect(events.first.status, 'success');

      // Close door
      final closedDoor = await agvService.triggerDoorRelay(
        command: 'close',
        vehicleId: 'DISPATCH-CONTROL',
      );
      expect(closedDoor.status, 'closed');
    });

    test('checkProximityAndOpenDoor opens door when vehicle is within proximity radius', () async {
      // Door is at (18.0, 10.0). Proximity radius is 4.5m.
      // Vehicle at (17.0, 9.0) -> Distance sqrt(1 + 1) = 1.41m <= 4.5m -> Should open!
      const vehicleNearby = AgvNodePosition(x: 17.0, y: 9.0);
      final opened = await agvService.checkProximityAndOpenDoor(vehicleNearby, 'AGV-COSTA-01');
      expect(opened, isTrue);
      expect(agvService.coldDoor.status, 'open');

      // Close door for next check
      await agvService.triggerDoorRelay(command: 'close', vehicleId: 'TEST');

      // Vehicle at (5.0, 2.0) -> Distance sqrt(13^2 + 8^2) = 15.26m > 4.5m -> Should NOT open!
      const vehicleFar = AgvNodePosition(x: 5.0, y: 2.0);
      final notOpened = await agvService.checkProximityAndOpenDoor(vehicleFar, 'AGV-COSTA-01');
      expect(notOpened, isFalse);
      expect(agvService.coldDoor.status, 'closed');
    });
  });

  group('End-to-End Factory Acceptance Testing (FAT) Commissioning Tests', () {
    test('executeFatCommissioning verifies all 8 stages and validates plant commissioning', () async {
      final report = await agvService.executeFatCommissioning();

      expect(report.overallResult, 'PASSED_COMMISSIONED');
      expect(report.isSuccessful, isTrue);
      expect(report.totalStages, 8);
      expect(report.passedStages, 8);
      expect(report.reportId, startsWith('FAT-COSTA-WMS-'));
      expect(report.plantLocation, contains('Costa Mushroom Facility'));

      // Validate stress test parameters
      expect(report.concurrentMobileTerminals, 50);
      expect(report.offlineMutationsQueued, 1500);
      expect(report.syncConflictRate, '0.00%');
      expect(report.meanLatencyMs, lessThan(50.0));

      // Validate stage sequence
      final stages = report.stages;
      expect(stages[0].name, contains('MES Harvest'));
      expect(stages[1].name, contains('Central Conveyor'));
      expect(stages[2].name, contains('Pallet Scale'));
      expect(stages[3].name, contains('AGV Putaway'));
      expect(stages[4].name, contains('FEFO Wave Picking'));
      expect(stages[5].name, contains('Packout Weight'));
      expect(stages[6].name, contains('In-Transit BLE'));
      expect(stages[7].name, contains('e-PoD'));

      for (final s in stages) {
        expect(s.passed, isTrue);
        expect(s.metrics.isNotEmpty, isTrue);
        expect(s.standard.isNotEmpty, isTrue);
      }
    });
  });
}
