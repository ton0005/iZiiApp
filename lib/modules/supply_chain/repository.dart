import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_service.dart';
import 'daos/products_dao.dart';
import 'daos/stock_moves_dao.dart';
import 'daos/stock_quants_dao.dart';

class SupplyChainRepository {
  final AppDatabase _db;
  late final ProductsDao productsDao;
  late final StockQuantsDao stockQuantsDao;
  late final StockMovesDao stockMovesDao;

  SupplyChainRepository([AppDatabase? database])
      : _db = database ?? AppDatabase() {
    productsDao = ProductsDao(_db);
    stockQuantsDao = StockQuantsDao(_db);
    stockMovesDao = StockMovesDao(_db);
  }

  // --- JSON helpers (same pattern as CRM) ---

  Map<String, dynamic> _decodeCustomFields(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  String _encodeCustomFields(dynamic fields) {
    if (fields == null) return '{}';
    if (fields is Map) {
      if (fields.isEmpty) return '{}';
      return jsonEncode(Map<String, dynamic>.from(fields));
    }
    return '{}';
  }

  Future<List<Product>> getAllProducts() => productsDao.getAllProducts();
  Stream<List<Product>> watchAllProducts() => productsDao.watchAllProducts();
  Future<Product?> getProductById(String id) => productsDao.getProductById(id);
  Future<Product?> getProductByBarcode(String barcode) => productsDao.getProductByBarcode(barcode);

  Future<void> addProductWithStock({
    required String id,
    required String sku,
    required String name,
    required double price,
    required double cost,
    required double stock,
    String? barcode,
    String locationId = 'MAIN',
    dynamic customFields,
  }) async {
    await productsDao.insertProduct(ProductsCompanion.insert(
      id: id,
      sku: sku,
      name: name,
      price: price,
      cost: cost,
      barcode: barcode != null ? Value(barcode) : const Value.absent(),
      customFields: Value(_encodeCustomFields(customFields)),
    ));

    if (stock > 0) {
      await stockQuantsDao.insertStockQuant(StockQuantsCompanion.insert(
        id: const Uuid().v4(),
        productId: id,
        locationId: locationId,
        quantity: stock,
      ));
    }

    SyncService().queueMutation('products', 'insert', {
      'id': id,
      'sku': sku,
      'name': name,
      'price': price,
      'cost': cost,
      'barcode': barcode,
      'custom_fields': customFields is Map ? customFields : {},
    });
  }

  Future<void> updateProductWithStock({
    required String id,
    required String name,
    required double price,
    required double cost,
    double? stock,
    String? barcode,
    String locationId = 'MAIN',
    dynamic customFields,
  }) async {
    final product = await productsDao.getProductById(id);
    if (product == null) {
      throw Exception('Product not found: $id');
    }

    // Merge existing custom fields with new ones
    String updatedCustomFields;
    if (customFields != null) {
      final existing = _decodeCustomFields(product.customFields);
      final incoming = customFields is Map
          ? Map<String, dynamic>.from(customFields)
          : <String, dynamic>{};
      existing.addAll(incoming);
      updatedCustomFields = _encodeCustomFields(existing);
    } else {
      updatedCustomFields = product.customFields;
    }

    await productsDao.updateProduct(product.copyWith(
      name: name,
      price: price,
      cost: cost,
      barcode: Value(barcode),
      customFields: updatedCustomFields,
    ));

    if (stock != null) {
      final quant = await stockQuantsDao.getStockQuantByProductId(id);
      if (quant != null) {
        await stockQuantsDao.updateStockQuant(quant.copyWith(quantity: stock));
      } else {
        await stockQuantsDao.insertStockQuant(StockQuantsCompanion.insert(
          id: const Uuid().v4(),
          productId: id,
          locationId: locationId,
          quantity: stock,
        ));
      }
    }

    SyncService().queueMutation('products', 'update', {
      'id': id,
      'name': name,
      'price': price,
      'cost': cost,
      'barcode': barcode,
      'custom_fields': _decodeCustomFields(updatedCustomFields),
    });
  }

  Future<List<StockMove>> getStockMoves() => stockMovesDao.getAllStockMoves();
  Stream<List<StockMove>> watchStockMoves() =>
      stockMovesDao.watchAllStockMoves();

  Future<int> getStockQuantity(String productId) async {
    final quant = await stockQuantsDao.getStockQuantByProductId(productId);
    return quant?.quantity.toInt() ?? 0;
  }

  Future<int> checkStock(String productName) async {
    final allProducts = await getAllProducts();
    Product? product;
    for (final item in allProducts) {
      if (item.name.toLowerCase().contains(productName.toLowerCase())) {
        product = item;
        break;
      }
    }
    if (product == null) return -1;
    return await getStockQuantity(product.id);
  }

  Future<List<Map<String, dynamic>>> getProductsWithStock() async {
    final query = _db.select(_db.products).join([
      leftOuterJoin(_db.stockQuants,
          _db.stockQuants.productId.equalsExp(_db.products.id)),
    ]);

    final result = await query.get();
    final Map<String, Map<String, dynamic>> productsMap = {};

    for (final row in result) {
      final product = row.readTable(_db.products);
      final quant = row.readTableOrNull(_db.stockQuants);
      productsMap.putIfAbsent(
          product.id,
          () => {
                'id': product.id,
                'name': product.name,
                'price': product.price,
                'stock': 0,
                'created_at': product.createdAt.toIso8601String(),
                'custom_fields': _decodeCustomFields(product.customFields),
              });
      if (quant != null) {
        productsMap[product.id]!['stock'] =
            (productsMap[product.id]!['stock'] as int) + quant.quantity.toInt();
      }
    }

    return productsMap.values.toList();
  }

  // ── WMS / LPN & Packaging Methods ──────────────────────────────────────────

  Future<List<StockLpn>> getAllLpns() => _db.select(_db.stockLpns).get();
  Stream<List<StockLpn>> watchAllLpns() => _db.select(_db.stockLpns).watch();
  Future<StockLpn?> getLpnByCode(String code) =>
      (_db.select(_db.stockLpns)..where((tbl) => tbl.lpnCode.equals(code))).getSingleOrNull();

  Future<List<StockLot>> getAllLots() => _db.select(_db.stockLots).get();
  Future<StockLot?> getLotByNumber(String lotNumber) =>
      (_db.select(_db.stockLots)..where((tbl) => tbl.lotNumber.equals(lotNumber))).getSingleOrNull();

  Future<StockLot> createLot({
    required String productId,
    required String lotNumber,
    DateTime? productionDate,
    DateTime? bestBeforeDate,
    required DateTime expiryDate,
    String status = 'approved',
    String? notes,
  }) async {
    final lotId = const Uuid().v4();
    final entry = StockLotsCompanion.insert(
      id: lotId,
      productId: productId,
      lotNumber: lotNumber,
      productionDate: Value(productionDate),
      bestBeforeDate: Value(bestBeforeDate),
      expiryDate: expiryDate,
      status: Value(status),
      notes: Value(notes),
    );
    await _db.into(_db.stockLots).insert(entry);

    SyncService().queueMutation('stock_lots', 'insert', {
      'id': lotId,
      'product_id': productId,
      'lot_number': lotNumber,
      'production_date': productionDate?.toIso8601String(),
      'best_before_date': bestBeforeDate?.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'status': status,
      'notes': notes,
    });

    return (_db.select(_db.stockLots)..where((tbl) => tbl.id.equals(lotId))).getSingle();
  }

  Future<StockLpn> createPalletLpn({
    required String lpnCode,
    required String locationId,
    required String productId,
    String? lotId,
    required double quantity, // number of boxes or units
    required String uomId,
    double grossWeightKg = 0.0,
    double tareWeightKg = 0.0,
    double netWeightKg = 0.0,
    String? packagingId,
    Map<String, dynamic>? customFields,
  }) async {
    final lpnId = const Uuid().v4();
    final lpnEntry = StockLpnsCompanion.insert(
      id: lpnId,
      lpnCode: lpnCode,
      locationId: locationId,
      status: const Value('staged'),
      grossWeightKg: Value(grossWeightKg),
      tareWeightKg: Value(tareWeightKg),
      netWeightKg: Value(netWeightKg),
      packagingId: Value(packagingId),
      customFields: Value(_encodeCustomFields(customFields)),
    );
    await _db.into(_db.stockLpns).insert(lpnEntry);

    final contentId = const Uuid().v4();
    await _db.into(_db.stockLpnContents).insert(StockLpnContentsCompanion.insert(
      id: contentId,
      lpnId: lpnId,
      productId: productId,
      lotId: Value(lotId),
      quantity: Value(quantity),
      uomId: uomId,
    ));

    // Register quant on staging location
    final quantId = const Uuid().v4();
    await _db.into(_db.stockQuants).insert(StockQuantsCompanion.insert(
      id: quantId,
      productId: productId,
      locationId: locationId,
      lotId: Value(lotId),
      lpnId: Value(lpnId),
      quantity: quantity,
      availableQty: Value(quantity),
    ));

    // Queue sync mutations
    SyncService().queueMutation('stock_lpns', 'insert', {
      'id': lpnId,
      'lpn_code': lpnCode,
      'location_id': locationId,
      'status': 'staged',
      'gross_weight_kg': grossWeightKg,
      'tare_weight_kg': tareWeightKg,
      'net_weight_kg': netWeightKg,
      'packaging_id': packagingId,
      'custom_fields': customFields ?? {},
    });

    SyncService().queueMutation('stock_lpn_contents', 'insert', {
      'id': contentId,
      'lpn_id': lpnId,
      'product_id': productId,
      'lot_id': lotId,
      'quantity': quantity,
      'uom_id': uomId,
    });

    return (_db.select(_db.stockLpns)..where((tbl) => tbl.id.equals(lpnId))).getSingle();
  }

  Future<List<StockLpnContent>> getLpnContents(String lpnId) =>
      (_db.select(_db.stockLpnContents)..where((tbl) => tbl.lpnId.equals(lpnId))).get();

  Future<Map<String, dynamic>?> getLpnFullDetails(String lpnCode) async {
    final pallet = await getLpnByCode(lpnCode);
    if (pallet == null) return null;

    final contents = await getLpnContents(pallet.id);

    String productName = 'Chưa xác định';
    String? lotNumber;
    double totalQty = 0;
    String uom = 'box';

    if (contents.isNotEmpty) {
      final firstContent = contents.first;
      final product = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(firstContent.productId)))
          .getSingleOrNull();
      if (product != null) {
        productName = product.name;
      }

      if (firstContent.lotId != null) {
        final lot = await (_db.select(_db.stockLots)
              ..where((tbl) => tbl.id.equals(firstContent.lotId!)))
            .getSingleOrNull();
        lotNumber = lot?.lotNumber;
      }

      totalQty = contents.fold(0.0, (sum, item) => sum + item.quantity);
      uom = firstContent.uomId;
    }

    final loc = await (_db.select(_db.locations)
          ..where((tbl) => tbl.code.equals(pallet.locationId) | tbl.id.equals(pallet.locationId)))
        .getSingleOrNull();

    return {
      'pallet': pallet,
      'product_name': productName,
      'lot_number': lotNumber ?? 'UNKNOWN',
      'total_quantity': totalQty,
      'uom': uom,
      'location_code': pallet.locationId,
      'location_name': loc?.name ?? pallet.locationId,
      'gross_weight': pallet.grossWeightKg ?? 0.0,
      'net_weight': pallet.netWeightKg ?? 0.0,
      'tare_weight': pallet.tareWeightKg ?? 0.0,
      'status': pallet.status,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentPalletMoves({int limit = 10}) async {
    final moves = await (_db.select(_db.stockMoves)
          ..where((tbl) => tbl.lpnId.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)])
          ..limit(limit))
        .get();

    final results = <Map<String, dynamic>>[];
    for (final m in moves) {
      StockLpn? pallet;
      if (m.lpnId != null) {
        pallet = await (_db.select(_db.stockLpns)
              ..where((tbl) => tbl.id.equals(m.lpnId!)))
            .getSingleOrNull();
      }
      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(m.productId)))
          .getSingleOrNull();

      results.add({
        'move_id': m.id,
        'lpn_code': pallet?.lpnCode ?? m.lpnId ?? 'Unknown',
        'product_name': prod?.name ?? 'Unknown',
        'source': m.sourceLocationId,
        'dest': m.destLocationId,
        'quantity': m.quantity,
        'created_at': m.date,
        'status': m.status,
      });
    }
    return results;
  }

  Future<void> movePalletLpn({
    required String lpnCode,
    required String destLocationId,
    String transportType = 'forklift',
  }) async {
    final pallet = await getLpnByCode(lpnCode);
    if (pallet == null) {
      throw ArgumentError('Pallet với mã LPN "$lpnCode" không tồn tại.');
    }

    // Resolve destination code if ID was passed or vice versa
    final destLoc = await (_db.select(_db.locations)
          ..where((tbl) => tbl.code.equals(destLocationId) | tbl.id.equals(destLocationId)))
        .getSingleOrNull();
    final actualDestLocation = destLoc?.code ?? destLocationId;

    final sourceLocationId = pallet.locationId;
    if (sourceLocationId == actualDestLocation) {
      return; // Already at destination
    }

    // 1. Update StockLpns location
    await (_db.update(_db.stockLpns)..where((tbl) => tbl.id.equals(pallet.id))).write(
      StockLpnsCompanion(
        locationId: Value(actualDestLocation),
        status: const Value('stored'),
      ),
    );

    // 2. Update StockQuants location for this pallet
    await (_db.update(_db.stockQuants)..where((tbl) => tbl.lpnId.equals(pallet.id))).write(
      StockQuantsCompanion(
        locationId: Value(actualDestLocation),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 3. Create StockMoves record
    final contents = await (_db.select(_db.stockLpnContents)
          ..where((tbl) => tbl.lpnId.equals(pallet.id)))
        .get();

    for (final c in contents) {
      final moveId = const Uuid().v4();
      await _db.into(_db.stockMoves).insert(StockMovesCompanion.insert(
        id: moveId,
        productId: c.productId,
        lotId: Value(c.lotId),
        lpnId: Value(pallet.id),
        sourceLocationId: sourceLocationId,
        destLocationId: actualDestLocation,
        quantity: c.quantity,
        status: const Value('done'),
        transportType: Value(transportType),
      ));

      SyncService().queueMutation('stock_moves', 'insert', {
        'id': moveId,
        'product_id': c.productId,
        'lot_id': c.lotId,
        'lpn_id': pallet.id,
        'source_location_id': sourceLocationId,
        'dest_location_id': actualDestLocation,
        'quantity': c.quantity,
        'status': 'done',
        'transport_type': transportType,
      });
    }

    SyncService().queueMutation('stock_lpns', 'update', {
      'id': pallet.id,
      'location_id': actualDestLocation,
      'status': 'stored',
    });
  }

  Future<List<Location>> getAvailableLocations() async {
    await seedDefaultWarehouseLocations();
    return (_db.select(_db.locations)..where((tbl) => tbl.status.equals('active'))).get();
  }

  Future<void> seedDefaultWarehouseLocations() async {
    final existing = await _db.select(_db.locations).get();
    if (existing.isNotEmpty) return;

    final defaultLocations = [
      {'code': 'M1-STAGING', 'name': 'Khu Tập Kết Đóng Pallet M1', 'type': 'staging', 'path': '/WH1/STAGING', 'depth': 1},
      {'code': 'WH1-COLD-GATE', 'name': 'Cửa Tự Động Kho Lạnh #01', 'type': 'dock', 'path': '/WH1/COLD/GATE', 'depth': 2},
      {'code': 'WH1-COLD-A01-R01-L1', 'name': 'Dãy A Kệ 01 Tầng 1 (Cold Store)', 'type': 'bin', 'path': '/WH1/COLD/A01/R01/L1', 'depth': 4},
      {'code': 'WH1-COLD-A01-R01-L2', 'name': 'Dãy A Kệ 01 Tầng 2 (Cold Store)', 'type': 'bin', 'path': '/WH1/COLD/A01/R01/L2', 'depth': 4},
      {'code': 'WH1-COLD-A01-R02-L1', 'name': 'Dãy A Kệ 02 Tầng 1 (Cold Store)', 'type': 'bin', 'path': '/WH1/COLD/A01/R02/L1', 'depth': 4},
      {'code': 'WH1-COLD-A02-R01-L1', 'name': 'Dãy A2 Kệ 01 Tầng 1 (Fast-Moving)', 'type': 'bin', 'path': '/WH1/COLD/A02/R01/L1', 'depth': 4},
      {'code': 'WH1-QUARANTINE', 'name': 'Khu Vực Cách Ly / Biệt Trữ (QC)', 'type': 'quarantine', 'path': '/WH1/QUARANTINE', 'depth': 1},
    ];

    for (final loc in defaultLocations) {
      await _db.into(_db.locations).insert(LocationsCompanion.insert(
        id: const Uuid().v4(),
        code: loc['code'] as String,
        name: loc['name'] as String,
        type: loc['type'] as String,
        path: loc['path'] as String,
        depth: Value(loc['depth'] as int),
        status: const Value('active'),
        isStorable: const Value(true),
      ));
    }
  }
}

