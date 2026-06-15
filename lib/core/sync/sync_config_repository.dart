import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class SyncConfigRepository {
  static final SyncConfigRepository _instance = SyncConfigRepository._internal();
  factory SyncConfigRepository() => _instance;
  SyncConfigRepository._internal();

  final AppDatabase _db = AppDatabase();

  static const Map<String, String> tableToModuleMap = {
    'projects': 'project_task',
    'tasks': 'project_task',
    'leads': 'leads_management',
    'contacts': 'leads_management',
    'deals': 'deal_pipeline',
    'service_items': 'services',
    'service_bookings': 'services',
    'au_contacts': 'accountant',
    'accounts': 'accountant',
    'tax_rates': 'accountant',
    'journal_entries': 'accountant',
    'journal_lines': 'accountant',
    'payroll_events': 'accountant',
    'purchase_orders': 'accountant',
    'purchase_order_lines': 'accountant',
    'users': 'profile_settings',
    'app_settings': 'profile_settings',
    'chat_conversations': 'in_app_chat',
    'chat_participants': 'in_app_chat',
    'chat_messages': 'in_app_chat',
  };

  /// Lists of modules and metadata
  static const List<Map<String, dynamic>> modulesMetadata = [
    {
      'key': 'project_task',
      'name_en': 'Project & Task',
      'name_vi': 'Dự án & Công việc',
      'icon': 'assignment_turned_in_rounded',
      'default_enabled': true,
      'is_always_on': false,
    },
    {
      'key': 'leads_management',
      'name_en': 'Leads Management',
      'name_vi': 'Quản lý Cơ hội',
      'icon': 'people_alt_rounded',
      'default_enabled': true,
      'is_always_on': false,
    },
    {
      'key': 'deal_pipeline',
      'name_en': 'Deal Pipeline',
      'name_vi': 'Đường ống Cơ hội',
      'icon': 'monetization_on_rounded',
      'default_enabled': true,
      'is_always_on': false,
    },
    {
      'key': 'services',
      'name_en': 'Services',
      'name_vi': 'Dịch vụ & Đặt lịch',
      'icon': 'cleaning_services_rounded',
      'default_enabled': true,
      'is_always_on': false,
    },
    {
      'key': 'accountant',
      'name_en': 'Accountant',
      'name_vi': 'Kế toán & Tài chính',
      'icon': 'account_balance_rounded',
      'default_enabled': true,
      'is_always_on': false,
    },
    {
      'key': 'in_app_chat',
      'name_en': 'In-App Chat',
      'name_vi': 'Trò chuyện & Hợp tác',
      'icon': 'chat_bubble_outline_rounded',
      'default_enabled': true,
      'is_always_on': false,
    },
    {
      'key': 'profile_settings',
      'name_en': 'User Profile & Settings',
      'name_vi': 'Thông tin & Cài đặt',
      'icon': 'person_outline_rounded',
      'default_enabled': true,
      'is_always_on': true,
    }
  ];

  /// Initialize and seed default sync configurations for a user
  Future<void> seedDefaultConfigs(String userId) async {
    final existing = await (_db.select(_db.userSyncConfigs)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();

    final existingKeys = existing.map((c) => c.moduleKey).toSet();

    for (var mod in modulesMetadata) {
      final key = mod['key'] as String;
      if (!existingKeys.contains(key)) {
        await _db.into(_db.userSyncConfigs).insert(
              UserSyncConfigsCompanion.insert(
                id: const Uuid().v4(),
                userId: userId,
                moduleKey: key,
                isEnabled: Value(mod['default_enabled'] as bool),
                syncGranularity: Value(mod['is_always_on'] as bool ? 'full' : 'full'),
                isAdminLocked: Value(mod['is_always_on'] as bool),
              ),
            );
      }
    }
  }

  /// Get all sync configs for a specific user
  Future<List<UserSyncConfig>> getConfigsForUser(String userId) async {
    await seedDefaultConfigs(userId);
    return await (_db.select(_db.userSyncConfigs)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
  }

  /// Get sync config for a specific module
  Future<UserSyncConfig?> getConfigForModule(String userId, String moduleKey) async {
    await seedDefaultConfigs(userId);
    return await (_db.select(_db.userSyncConfigs)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.moduleKey.equals(moduleKey)))
        .getSingleOrNull();
  }

  /// Save sync configuration changes with audit logging
  Future<void> saveConfig(
    String userId,
    String moduleKey, {
    required bool isEnabled,
    required String syncGranularity,
    List<String>? selectiveEntities,
    bool? isAdminLocked,
  }) async {
    final current = await getConfigForModule(userId, moduleKey);
    if (current == null) return;

    // Reject changes if locked by Admin (unless current call is by Admin updating lock state)
    if (current.isAdminLocked && isAdminLocked == null) {
      throw Exception('Module is locked by Admin policy');
    }

    final selectiveEntitiesJson = selectiveEntities != null ? jsonEncode(selectiveEntities) : null;

    final companion = UserSyncConfigsCompanion(
      isEnabled: Value(isEnabled),
      syncGranularity: Value(syncGranularity),
      selectiveEntities: Value(selectiveEntitiesJson),
      isAdminLocked: isAdminLocked != null ? Value(isAdminLocked) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (_db.update(_db.userSyncConfigs)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.moduleKey.equals(moduleKey)))
        .write(companion);

    // Write audit log
    final oldStateJson = jsonEncode({
      'is_enabled': current.isEnabled,
      'sync_granularity': current.syncGranularity,
      'selective_entities': current.selectiveEntities,
      'is_admin_locked': current.isAdminLocked,
    });

    final newStateJson = jsonEncode({
      'is_enabled': isEnabled,
      'sync_granularity': syncGranularity,
      'selective_entities': selectiveEntitiesJson,
      'is_admin_locked': isAdminLocked ?? current.isAdminLocked,
    });

    await _db.into(_db.syncAuditLogs).insert(
          SyncAuditLogsCompanion.insert(
            id: const Uuid().v4(),
            userId: userId,
            moduleKey: moduleKey,
            actionType: _determineActionType(current.isEnabled, isEnabled, current.isAdminLocked, isAdminLocked),
            oldState: oldStateJson,
            newState: newStateJson,
          ),
        );
  }

  String _determineActionType(bool oldEnabled, bool newEnabled, bool oldLock, bool? newLock) {
    if (newLock != null && newLock != oldLock) {
      return newLock ? 'admin_lock' : 'admin_unlock';
    }
    if (oldEnabled != newEnabled) {
      return newEnabled ? 'toggle_on' : 'toggle_off';
    }
    return 'change_granularity';
  }

  /// Count unsynced outbox mutations mapping to tables of a module
  Future<int> getUnsyncedCountForModule(String moduleKey) async {
    final allPending = await (_db.select(_db.outboxMutations)
          ..where((tbl) => tbl.status.equals('pending')))
        .get();

    int count = 0;
    for (var m in allPending) {
      if (tableToModuleMap[m.targetTable] == moduleKey) {
        count++;
      }
    }
    return count;
  }

  /// Log a conflict resolved during sync
  Future<void> logConflict({
    required String userId,
    required String moduleKey,
    required String recordId,
    required String tableName,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
    required Map<String, dynamic> resolvedData,
    required String strategy,
  }) async {
    await _db.into(_db.syncConflictLogs).insert(
          SyncConflictLogsCompanion.insert(
            id: const Uuid().v4(),
            userId: userId,
            moduleKey: moduleKey,
            recordId: recordId,
            targetTable: tableName,
            localData: jsonEncode(localData),
            serverData: jsonEncode(serverData),
            resolvedData: jsonEncode(resolvedData),
            resolutionStrategy: strategy,
          ),
        );
  }

  /// Get recent conflict logs
  Future<List<SyncConflictLog>> getConflictLogs(String userId) async {
    return await (_db.select(_db.syncConflictLogs)
          ..where((tbl) => tbl.userId.equals(userId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.timestamp, mode: OrderingMode.desc)])
          ..limit(50))
        .get();
  }

  /// Get recent audit logs
  Future<List<SyncAuditLog>> getAuditLogs(String userId) async {
    return await (_db.select(_db.syncAuditLogs)
          ..where((tbl) => tbl.userId.equals(userId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.timestamp, mode: OrderingMode.desc)])
          ..limit(50))
        .get();
  }
}
