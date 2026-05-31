import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../database/tables.dart';

part 'stock_quants_dao.g.dart';

@DriftAccessor(tables: [StockQuants])
class StockQuantsDao extends DatabaseAccessor<AppDatabase>
    with _$StockQuantsDaoMixin {
  StockQuantsDao(AppDatabase db) : super(db);

  Future<List<StockQuant>> getAllStockQuants() => select(stockQuants).get();
  Stream<List<StockQuant>> watchAllStockQuants() => select(stockQuants).watch();

  Future<StockQuant?> getStockQuantByProductId(String productId) =>
      (select(stockQuants)..where((tbl) => tbl.productId.equals(productId)))
          .getSingleOrNull();

  Future<void> insertStockQuant(StockQuantsCompanion entry) =>
      into(stockQuants).insert(entry);

  Future<bool> updateStockQuant(StockQuant stockQuant) =>
      update(stockQuants).replace(stockQuant);

  Future<int> deleteStockQuant(String id) =>
      (delete(stockQuants)..where((tbl) => tbl.id.equals(id))).go();
}
