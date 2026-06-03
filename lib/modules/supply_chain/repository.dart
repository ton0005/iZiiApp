import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
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
}
