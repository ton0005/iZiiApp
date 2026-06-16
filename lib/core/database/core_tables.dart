import 'package:drift/drift.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Users extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get type => text()(); // consumer/provider/both
  TextColumn get kycStatus => text().withDefault(const Constant('none'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ModuleRegistryTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get version => text()();
  BoolColumn get isInstalled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class OutboxMutations extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, synced, error

  @override
  Set<Column> get primaryKey => {id};
}

class UserSyncConfigs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()();
  TextColumn get moduleKey => text()(); // project_task, leads_management, deal_pipeline, services, accountant, calendar_events, profile_settings
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get syncGranularity => text().withDefault(const Constant('full'))(); // 'full', 'manual', 'selective'
  TextColumn get selectiveEntities => text().nullable()(); // JSON string array
  BoolColumn get isAdminLocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncAuditLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get moduleKey => text()();
  TextColumn get actionType => text()(); // toggle_on, toggle_off, change_granularity, admin_lock, admin_unlock
  TextColumn get oldState => text()(); // JSON
  TextColumn get newState => text()(); // JSON

  @override
  Set<Column> get primaryKey => {id};
}

class SyncConflictLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()();
  TextColumn get moduleKey => text()();
  TextColumn get recordId => text()();
  TextColumn get targetTable => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get localData => text()(); // JSON
  TextColumn get serverData => text()(); // JSON
  TextColumn get resolvedData => text()(); // JSON
  TextColumn get resolutionStrategy => text()(); // e.g. last_write_wins

  @override
  Set<Column> get primaryKey => {id};
}

class RecordSharingPermissions extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get recordType => text()(); // 'leads', 'deals', 'services', 'tasks'
  TextColumn get recordId => text()();
  TextColumn get sharedWith => text()(); // user_id, role_key, or 'HTI_threshold'
  TextColumn get sharedBy => text()(); // owner user_id
  TextColumn get permissionLevel => text().withDefault(const Constant('view'))(); // 'view', 'edit'
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get revokedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CommunityFeeds extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get recordType => text()(); // 'services', 'tasks'
  TextColumn get recordId => text()();
  TextColumn get postedBy => text()();
  TextColumn get status => text().withDefault(const Constant('pending_approval'))(); // 'pending_approval', 'live', 'withdrawn'
  TextColumn get approvedBy => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  IntColumn get savesCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class UserShareModuleDefaults extends Table {
  TextColumn get userId => text()();
  TextColumn get moduleKey => text()(); // 'leads_management', 'deal_pipeline', 'services', 'project_task'
  TextColumn get defaultPolicy => text().withDefault(const Constant('always_private'))(); // 'always_private', 'ask', 'default_team'
  TextColumn get defaultAudience => text().nullable()(); // JSON string array of default user/role IDs

  @override
  Set<Column> get primaryKey => {userId, moduleKey};
}

class LocalBlePeers extends Table {
  TextColumn get deviceId => text()();
  TextColumn get deviceName => text()();
  TextColumn get publicKey => text()(); // Base64 X25519 public key
  TextColumn get signingPublicKey => text()(); // Base64 ED25519 public key
  DateTimeColumn get lastSeenAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get rssi => integer()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

