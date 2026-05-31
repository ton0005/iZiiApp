// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deals_dao.dart';

// ignore_for_file: type=lint
mixin _$DealsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DealsTable get deals => attachedDatabase.deals;
  $LeadsTable get leads => attachedDatabase.leads;
  $ContactsTable get contacts => attachedDatabase.contacts;
  DealsDaoManager get managers => DealsDaoManager(this);
}

class DealsDaoManager {
  final _$DealsDaoMixin _db;
  DealsDaoManager(this._db);
  $$DealsTableTableManager get deals =>
      $$DealsTableTableManager(_db.attachedDatabase, _db.deals);
  $$LeadsTableTableManager get leads =>
      $$LeadsTableTableManager(_db.attachedDatabase, _db.leads);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
}
