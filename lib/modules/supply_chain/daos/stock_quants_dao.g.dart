// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_quants_dao.dart';

// ignore_for_file: type=lint
mixin _$StockQuantsDaoMixin on DatabaseAccessor<AppDatabase> {
  $StockQuantsTable get stockQuants => attachedDatabase.stockQuants;
  StockQuantsDaoManager get managers => StockQuantsDaoManager(this);
}

class StockQuantsDaoManager {
  final _$StockQuantsDaoMixin _db;
  StockQuantsDaoManager(this._db);
  $$StockQuantsTableTableManager get stockQuants =>
      $$StockQuantsTableTableManager(_db.attachedDatabase, _db.stockQuants);
}
