import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:izii_app/modules/warehouse_automation/models/warehouse_3d_models.dart';
import 'package:izii_app/modules/warehouse_automation/services/warehouse_3d_service.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:drift/native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Warehouse3dService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = Warehouse3dService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Isometric 3D Math & Projection Unit Tests', () {
    test('IsometricProjection projects 3D world origin to screen center', () {
      const projection = IsometricProjection(
        zoom: 20.0,
        azimuth: 0,
        elevation: 0,
        panOffset: Offset.zero,
      );
      const canvasSize = Size(800, 600);
      final screenPos = projection.project(0, 0, 0, canvasSize);

      expect(screenPos.dx, equals(400.0));
      expect(screenPos.dy, equals(300.0));
    });

    test('IsometricProjection calculates positive depth order for farther objects', () {
      const projection = IsometricProjection(
        zoom: 25.0,
        azimuth: math.pi / 4,
        elevation: math.pi / 6,
      );

      final depthNear = projection.depth(0, 0, 0);
      final depthFar = projection.depth(10, 10, 0);

      expect(depthFar, greaterThan(depthNear));
    });

    test('Warehouse3dObject calculates correct occupancy rate and status colors', () {
      const emptyBin = Warehouse3dObject(
        id: '1',
        code: 'BIN-01',
        name: 'Bin 01',
        type: 'bin',
        path: '/WH1/A/BIN-01',
        x: 0,
        y: 0,
        z: 0,
        width: 1.2,
        length: 2.4,
        height: 1.6,
        palletCount: 0,
        maxPallets: 1,
      );

      expect(emptyBin.occupancyRate, equals(0.0));
      expect(emptyBin.statusColor, equals(const Color(0xFF10B981))); // Green (Empty)

      final fullBin = emptyBin.copyWith(
        palletCount: 1,
        maxPallets: 1,
      );
      expect(fullBin.occupancyRate, equals(1.0));
      expect(fullBin.statusColor, equals(const Color(0xFFE11D48))); // Red (Full)

      const quarantineZone = Warehouse3dObject(
        id: '2',
        code: 'QUARANTINE',
        name: 'Khu biệt trữ',
        type: 'quarantine',
        path: '/WH1/QUARANTINE',
        x: 10,
        y: 10,
        z: 0,
        width: 4,
        length: 4,
        height: 0.15,
      );
      expect(quarantineZone.statusColor, equals(const Color(0xFF8B5CF6))); // Purple
    });
  });

  group('Warehouse3dService Integration Tests with Drift SQLite', () {
    test('loadWarehouse3dLayout seeds default plant and returns valid 3D locations', () async {
      final objects = await service.loadWarehouse3dLayout();

      expect(objects.isNotEmpty, isTrue);
      final binObjects = objects.where((o) => o.type == 'bin').toList();
      expect(binObjects.length, greaterThanOrEqualTo(4));

      for (final bin in binObjects) {
        expect(bin.width, equals(1.2));
        expect(bin.length, equals(2.4));
        expect(bin.maxWeightKg, greaterThanOrEqualTo(1000.0));
      }
    });

    test('createAisleWithRacks generates full hierarchical Aisle, Racks, and Bins with 3D coordinates', () async {
      const config = AisleTemplateConfig(
        zoneCode: 'COLD',
        aisleCode: 'A99',
        startX: 14.0,
        startY: 5.0,
        bayCount: 3,
        levelCount: 2,
        bayWidth: 2.4,
        levelHeight: 1.8,
        maxWeightPerBinKg: 1200.0,
      );

      await service.createAisleWithRacks(config);

      final objects = await service.loadWarehouse3dLayout();
      final newAisle = objects.firstWhere((o) => o.code == 'COLD-A99');
      expect(newAisle.type, equals('aisle'));
      expect(newAisle.x, equals(14.0));
      expect(newAisle.y, equals(5.0));

      // Check generated bins (3 bays * 2 levels = 6 bins)
      final newBins = objects.where((o) => o.code.startsWith('COLD-A99-R') && o.type == 'bin').toList();
      expect(newBins.length, equals(6));

      final firstBin = newBins.first;
      expect(firstBin.maxWeightKg, equals(1200.0));
      expect(firstBin.isStorable, isTrue);
    });

    test('updateLocationPositionAndStatus updates coordinates and status in Drift', () async {
      final objects = await service.loadWarehouse3dLayout();
      final targetBin = objects.firstWhere((o) => o.type == 'bin');

      await service.updateLocationPositionAndStatus(
        locationId: targetBin.id,
        posX: 25.5,
        posY: 30.5,
        posZ: 4.5,
        status: 'blocked',
        maxWeightKg: 2000.0,
      );

      final reloadedObjects = await service.loadWarehouse3dLayout();
      final updated = reloadedObjects.firstWhere((o) => o.id == targetBin.id);

      expect(updated.x, equals(25.5));
      expect(updated.y, equals(30.5));
      expect(updated.z, equals(4.5));
      expect(updated.status, equals('blocked'));
      expect(updated.maxWeightKg, equals(2000.0));
    });
  });
}
