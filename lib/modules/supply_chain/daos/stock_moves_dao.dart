import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../database/tables.dart';

part 'stock_moves_dao.g.dart';

@DriftAccessor(tables: [StockMoves])
class StockMovesDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovesDaoMixin {
  StockMovesDao(super.db);

  Future<List<StockMove>> getAllStockMoves() => select(stockMoves).get();
  Stream<List<StockMove>> watchAllStockMoves() => select(stockMoves).watch();

  Future<StockMove?> getStockMoveById(String id) =>
      (select(stockMoves)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> insertStockMove(StockMovesCompanion entry) =>
      into(stockMoves).insert(entry);

  Future<bool> updateStockMove(StockMove stockMove) =>
      update(stockMoves).replace(stockMove);

  Future<int> deleteStockMove(String id) =>
      (delete(stockMoves)..where((tbl) => tbl.id.equals(id))).go();
}
