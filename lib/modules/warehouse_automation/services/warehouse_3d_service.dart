import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../supply_chain/repository.dart';
import '../models/warehouse_3d_models.dart';

class Warehouse3dService {
  final AppDatabase _db;
  final SupplyChainRepository _supplyRepo;
  final SyncService _syncService;

  Warehouse3dService([
    AppDatabase? database,
    SupplyChainRepository? supplyRepo,
    SyncService? syncService,
  ])  : _db = database ?? AppDatabase(),
        _supplyRepo = supplyRepo ?? SupplyChainRepository(database),
        _syncService = syncService ?? SyncService();

  /// Loads all 3D warehouse objects with occupancy and stock information
  Future<List<Warehouse3dObject>> loadWarehouse3dLayout() async {
    // Ensure default warehouse seed is present
    await _ensureWarehouseSeed();

    final locations = await _db.select(_db.locations).get();
    final lpns = await _db.select(_db.stockLpns).get();
    final lpnContents = await _db.select(_db.stockLpnContents).get();
    final products = await _db.select(_db.products).get();

    // Group LPNs by locationId or code
    final Map<String, List<StockLpn>> lpnsByLocation = {};
    for (final lpn in lpns) {
      if (lpn.status == 'stored' || lpn.status == 'staged' || lpn.status == 'quarantined') {
        final locKey = lpn.locationId;
        lpnsByLocation.putIfAbsent(locKey, () => []).add(lpn);
      }
    }

    final productMap = {for (var p in products) p.id: p.name};
    final Map<String, List<String>> skusByLpnId = {};
    for (final c in lpnContents) {
      final name = productMap[c.productId] ?? 'Item';
      skusByLpnId.putIfAbsent(c.lpnId, () => []).add(name);
    }

    final List<Warehouse3dObject> objects = [];

    for (final loc in locations) {
      // Determine 3D coordinates (fallback if null)
      final x = loc.posX ?? _deriveDefaultX(loc);
      final y = loc.posY ?? _deriveDefaultY(loc);
      final z = loc.posZ ?? _deriveDefaultZ(loc);

      // Determine dimensions based on type
      final dims = _deriveDimensions(loc.type);

      // Get stored inventory at this location
      final locationLpns = [
        ...?lpnsByLocation[loc.id],
        ...?lpnsByLocation[loc.code],
      ];

      final storedLpnCodes = locationLpns.map((l) => l.lpnCode).toSet().toList();
      final storedSkus = <String>{};
      double currentWeight = 0.0;

      for (final lpn in locationLpns) {
        currentWeight += (lpn.grossWeightKg ?? 0.0);
        final skus = skusByLpnId[lpn.id] ?? [];
        storedSkus.addAll(skus);
      }

      final maxPallets = loc.type == 'bin' ? 1 : (loc.type == 'staging' ? 10 : 20);

      objects.add(Warehouse3dObject(
        id: loc.id,
        code: loc.code,
        name: loc.name,
        type: loc.type,
        parentId: loc.parentId,
        path: loc.path,
        x: x,
        y: y,
        z: z,
        width: dims.$1,
        length: dims.$2,
        height: dims.$3,
        status: loc.status,
        isStorable: loc.isStorable,
        maxWeightKg: loc.maxWeightKg ?? (loc.type == 'bin' ? 1500.0 : 50000.0),
        currentWeightKg: currentWeight,
        palletCount: storedLpnCodes.length,
        maxPallets: maxPallets,
        storedLpns: storedLpnCodes,
        storedSkus: storedSkus.toList(),
      ));
    }

    return objects;
  }

  /// Automatically generates a full Aisle with Racks and Bins with 3D coordinates
  Future<void> createAisleWithRacks(AisleTemplateConfig config) async {
    final now = DateTime.now();

    // 1. Create/Ensure Zone
    final zonePath = '/WH1/${config.zoneCode}';
    var zone = await (_db.select(_db.locations)
          ..where((t) => t.code.equals(config.zoneCode) | t.path.equals(zonePath)))
        .getSingleOrNull();

    if (zone == null) {
      final zoneId = const Uuid().v4();
      await _db.into(_db.locations).insert(LocationsCompanion.insert(
            id: zoneId,
            code: config.zoneCode,
            name: 'Khu vực ${config.zoneCode}',
            type: 'zone',
            path: zonePath,
            depth: const Value(1),
            isStorable: const Value(false),
            status: const Value('active'),
          ));
      _syncService.queueMutation('locations', 'insert', {
        'id': zoneId,
        'code': config.zoneCode,
        'name': 'Khu vực ${config.zoneCode}',
        'type': 'zone',
        'path': zonePath,
        'depth': 1,
        'is_storable': false,
        'status': 'active',
      });
      zone = await (_db.select(_db.locations)..where((t) => t.id.equals(zoneId))).getSingle();
    }

    // 2. Create Aisle
    final aisleCode = '${config.zoneCode}-${config.aisleCode}';
    final aislePath = '$zonePath/${config.aisleCode}';
    final aisleId = const Uuid().v4();

    await _db.into(_db.locations).insert(LocationsCompanion.insert(
          id: aisleId,
          code: aisleCode,
          name: 'Dãy Kệ ${config.aisleCode}',
          parentId: Value(zone.id),
          type: 'aisle',
          path: aislePath,
          depth: const Value(2),
          posX: Value(config.startX),
          posY: Value(config.startY),
          posZ: const Value(0.0),
          isStorable: const Value(false),
          status: const Value('active'),
        ));

    _syncService.queueMutation('locations', 'insert', {
      'id': aisleId,
      'code': aisleCode,
      'name': 'Dãy Kệ ${config.aisleCode}',
      'parent_id': zone.id,
      'type': 'aisle',
      'path': aislePath,
      'depth': 2,
      'pos_x': config.startX,
      'pos_y': config.startY,
      'pos_z': 0.0,
      'is_storable': false,
      'status': 'active',
    });

    // 3. Create Racks (Bays) and Levels/Bins
    for (int bay = 1; bay <= config.bayCount; bay++) {
      final bayStr = bay.toString().padLeft(2, '0');
      final rackCode = '$aisleCode-R$bayStr';
      final rackPath = '$aislePath/R$bayStr';
      final rackId = const Uuid().v4();

      final rackX = config.startX;
      final rackY = config.startY + (bay - 1) * (config.bayWidth + 0.2);

      await _db.into(_db.locations).insert(LocationsCompanion.insert(
            id: rackId,
            code: rackCode,
            name: 'Kệ R$bayStr ($aisleCode)',
            parentId: Value(aisleId),
            type: 'rack',
            path: rackPath,
            depth: const Value(3),
            posX: Value(rackX),
            posY: Value(rackY),
            posZ: const Value(0.0),
            isStorable: const Value(false),
            status: const Value('active'),
          ));

      _syncService.queueMutation('locations', 'insert', {
        'id': rackId,
        'code': rackCode,
        'name': 'Kệ R$bayStr ($aisleCode)',
        'parent_id': aisleId,
        'type': 'rack',
        'path': rackPath,
        'depth': 3,
        'pos_x': rackX,
        'pos_y': rackY,
        'pos_z': 0.0,
        'is_storable': false,
        'status': 'active',
      });

      // Levels & Bins
      for (int lvl = 1; lvl <= config.levelCount; lvl++) {
        final binCode = '$rackCode-L$lvl';
        final binPath = '$rackPath/L$lvl';
        final binId = const Uuid().v4();
        final binZ = (lvl - 1) * config.levelHeight;

        await _db.into(_db.locations).insert(LocationsCompanion.insert(
              id: binId,
              code: binCode,
              name: 'Ô $binCode',
              parentId: Value(rackId),
              type: 'bin',
              path: binPath,
              depth: const Value(4),
              posX: Value(rackX),
              posY: Value(rackY),
              posZ: Value(binZ),
              maxWeightKg: Value(config.maxWeightPerBinKg),
              maxVolumeM3: const Value(3.5),
              isStorable: const Value(true),
              status: const Value('active'),
              updatedAt: Value(now),
            ));

        _syncService.queueMutation('locations', 'insert', {
          'id': binId,
          'code': binCode,
          'name': 'Ô $binCode',
          'parent_id': rackId,
          'type': 'bin',
          'path': binPath,
          'depth': 4,
          'pos_x': rackX,
          'pos_y': rackY,
          'pos_z': binZ,
          'max_weight_kg': config.maxWeightPerBinKg,
          'max_volume_m3': 3.5,
          'is_storable': true,
          'status': 'active',
        });
      }
    }
  }

  /// Updates 3D metric position or status of an existing Location
  Future<void> updateLocationPositionAndStatus({
    required String locationId,
    double? posX,
    double? posY,
    double? posZ,
    String? status,
    double? maxWeightKg,
  }) async {
    final companion = LocationsCompanion(
      posX: posX != null ? Value(posX) : const Value.absent(),
      posY: posY != null ? Value(posY) : const Value.absent(),
      posZ: posZ != null ? Value(posZ) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      maxWeightKg: maxWeightKg != null ? Value(maxWeightKg) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (_db.update(_db.locations)..where((t) => t.id.equals(locationId))).write(companion);

    final updated = await (_db.select(_db.locations)..where((t) => t.id.equals(locationId))).getSingle();
    _syncService.queueMutation('locations', 'update', {
      'id': updated.id,
      'code': updated.code,
      'pos_x': updated.posX,
      'pos_y': updated.posY,
      'pos_z': updated.posZ,
      'status': updated.status,
      'max_weight_kg': updated.maxWeightKg,
      'updated_at': updated.updatedAt?.toIso8601String(),
    });
  }

  /// Ensures full 3D coordinates exist on default warehouse locations
  Future<void> _ensureWarehouseSeed() async {
    await _supplyRepo.seedDefaultWarehouseLocations();

    final locations = await _db.select(_db.locations).get();
    for (final loc in locations) {
      if (loc.posX == null || loc.posY == null || loc.posZ == null) {
        final x = _deriveDefaultX(loc);
        final y = _deriveDefaultY(loc);
        final z = _deriveDefaultZ(loc);

        await (_db.update(_db.locations)..where((t) => t.id.equals(loc.id))).write(
          LocationsCompanion(
            posX: Value(x),
            posY: Value(y),
            posZ: Value(z),
          ),
        );
      }
    }
  }

  (double, double, double) _deriveDimensions(String type) {
    switch (type) {
      case 'bin':
        return (1.2, 2.4, 1.6); // X width, Y length, Z height
      case 'rack':
        return (1.2, 2.4, 5.0);
      case 'dock':
        return (3.5, 4.0, 0.2);
      case 'staging':
        return (6.0, 8.0, 0.15);
      case 'quarantine':
        return (4.0, 4.0, 0.15);
      case 'zone':
        return (15.0, 25.0, 0.05);
      default:
        return (1.0, 1.0, 1.0);
    }
  }

  double _deriveDefaultX(Location loc) {
    if (loc.code.contains('A01')) return 2.0;
    if (loc.code.contains('A02')) return 6.0;
    if (loc.code.contains('A03')) return 10.0;
    if (loc.code.contains('STAGING') || loc.type == 'staging') return -4.0;
    if (loc.code.contains('GATE') || loc.type == 'dock') return -4.0;
    if (loc.code.contains('QUARANTINE') || loc.type == 'quarantine') return 12.0;
    return 0.0;
  }

  double _deriveDefaultY(Location loc) {
    if (loc.code.contains('R01')) return 2.0;
    if (loc.code.contains('R02')) return 5.5;
    if (loc.code.contains('R03')) return 9.0;
    if (loc.code.contains('R04')) return 12.5;
    if (loc.code.contains('STAGING')) return 2.0;
    if (loc.code.contains('GATE')) return 10.0;
    if (loc.code.contains('QUARANTINE')) return 14.0;
    return 1.0;
  }

  double _deriveDefaultZ(Location loc) {
    if (loc.code.endsWith('L1')) return 0.2;
    if (loc.code.endsWith('L2')) return 1.9;
    if (loc.code.endsWith('L3')) return 3.6;
    return 0.0;
  }
}
