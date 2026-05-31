// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_moves_dao.dart';

// ignore_for_file: type=lint
mixin _$StockMovesDaoMixin on DatabaseAccessor<AppDatabase> {
  $StockMovesTable get stockMoves => attachedDatabase.stockMoves;
  StockMovesDaoManager get managers => StockMovesDaoManager(this);
}

class StockMovesDaoManager {
  final _$StockMovesDaoMixin _db;
  StockMovesDaoManager(this._db);
  $$StockMovesTableTableManager get stockMoves =>
      $$StockMovesTableTableManager(_db.attachedDatabase, _db.stockMoves);
}
