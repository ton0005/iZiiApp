// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leads_dao.dart';

// ignore_for_file: type=lint
mixin _$LeadsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LeadsTable get leads => attachedDatabase.leads;
  $ContactsTable get contacts => attachedDatabase.contacts;
  LeadsDaoManager get managers => LeadsDaoManager(this);
}

class LeadsDaoManager {
  final _$LeadsDaoMixin _db;
  LeadsDaoManager(this._db);
  $$LeadsTableTableManager get leads =>
      $$LeadsTableTableManager(_db.attachedDatabase, _db.leads);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
}
