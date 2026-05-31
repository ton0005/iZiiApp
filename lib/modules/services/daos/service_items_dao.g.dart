// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_items_dao.dart';

// ignore_for_file: type=lint
mixin _$ServiceItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ServiceItemsTable get serviceItems => attachedDatabase.serviceItems;
  ServiceItemsDaoManager get managers => ServiceItemsDaoManager(this);
}

class ServiceItemsDaoManager {
  final _$ServiceItemsDaoMixin _db;
  ServiceItemsDaoManager(this._db);
  $$ServiceItemsTableTableManager get serviceItems =>
      $$ServiceItemsTableTableManager(_db.attachedDatabase, _db.serviceItems);
}
