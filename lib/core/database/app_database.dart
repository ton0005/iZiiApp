import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../../modules/sales_crm/database/tables.dart';
import '../../modules/supply_chain/database/tables.dart';
import '../../modules/services/database/tables.dart';
import '../../modules/project/database/tables.dart';
import '../../modules/purchase/database/tables.dart';
import '../../modules/accountant/database/tables.dart';
import '../community/database/tables.dart';
import '../../modules/mushrooms/database/tables.dart';
import '../../modules/communication/database/tables.dart';

import 'core_tables.dart';

part 'app_database.g.dart';

// --- Tables ---


@DriftDatabase(tables: [
  AppSettings,
  Users,
  ModuleRegistryTable,
  Contacts,
  Leads,
  Deals,
  Products,
  StockQuants,
  StockMoves,
  TrustScores,
  Referrals,
  ServiceListings,
  ServiceOrders,
  Reviews,
  ServiceItems,
  ServiceBookings,
  OutboxMutations,
  Projects,
  Tasks,
  PurchaseOrders,
  PurchaseOrderLines,
  AuContacts,
  Accounts,
  TaxRates,
  JournalEntries,
  JournalLines,
  PayrollEvents,
  UserSyncConfigs,
  SyncAuditLogs,
  SyncConflictLogs,
  RecordSharingPermissions,
  CommunityFeeds,
  UserShareModuleDefaults,
  GrowRooms,
  MushroomJobs,
  MushroomJobTypes,
  MushroomJobSafetyConfigs,
  MushroomSafetyCheckinLogs,
  MushroomMaintenanceTickets,
  MushroomChatMessages,
  MushroomRoomCrews,
  MushroomEmployees,
  MushroomDepartments,
  MushroomEmployeeDepartmentRoles,
  MushroomPermissionOverrides,
  MushroomYieldSurveys,
  MushroomHarvestPlans,
  MushroomShifts,
  MushroomPickerTeams,
  MushroomRoomAssignments,
  MushroomAttendanceEvents,
  MushroomBreakPolicies,
  MushroomDailyTimesheets,
  MushroomPayrollCalculations,
  ChatConversations,
  ChatParticipants,
  ChatMessages,
  // Track 3: Device Identity & E2EE
  DeviceRegistryEntries,
  EncryptedMessageQueue,
  DeviceTrustLedger,
  LocalBlePeers,
  InAppNotifications,
  NotificationSettingsTable
])
class AppDatabase extends _$AppDatabase {
  static AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  // Constructor for testing with in-memory or mock database executor
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  // Set test instance override
  static set testInstance(AppDatabase db) => _instance = db;

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 28;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            try {
              await m.addColumn(leads, leads.customFields);
            } catch (_) {}
          }
          if (from < 3) {
            try {
              await m.addColumn(products, products.customFields);
            } catch (_) {}
          }
          if (from < 4) {
            try {
              await m.createTable(serviceItems);
            } catch (_) {}
            try {
              await m.createTable(serviceBookings);
            } catch (_) {}
          }
          if (from < 5) {
            try {
              await m.addColumn(products, products.barcode);
            } catch (_) {}
          }
          if (from < 6) {
            try {
              await m.createTable(outboxMutations);
            } catch (_) {}
          }
          if (from < 7) {
            try {
              await m.createTable(projects);
            } catch (_) {}
            try {
              await m.createTable(tasks);
            } catch (_) {}
            try {
              await m.createTable(purchaseOrders);
            } catch (_) {}
            try {
              await m.createTable(purchaseOrderLines);
            } catch (_) {}
          }
          if (from < 8) {
            try {
              await m.addColumn(leads, leads.source);
            } catch (_) {}
            try {
              await m.addColumn(leads, leads.ownerId);
            } catch (_) {}
            try {
              await m.addColumn(deals, deals.source);
            } catch (_) {}
            try {
              await m.addColumn(deals, deals.ownerId);
            } catch (_) {}
          }
          if (from < 9) {
            try {
              await m.createTable(auContacts);
            } catch (_) {}
            try {
              await m.createTable(accounts);
            } catch (_) {}
            try {
              await m.createTable(taxRates);
            } catch (_) {}
            try {
              await m.createTable(journalEntries);
            } catch (_) {}
            try {
              await m.createTable(journalLines);
            } catch (_) {}
            try {
              await m.createTable(payrollEvents);
            } catch (_) {}
          }
          if (from < 10) {
            try {
              await m.createTable(userSyncConfigs);
            } catch (_) {}
            try {
              await m.createTable(syncAuditLogs);
            } catch (_) {}
            try {
              await m.createTable(syncConflictLogs);
            } catch (_) {}
          }
          if (from < 11) {
            try {
              await m.createTable(recordSharingPermissions);
            } catch (_) {}
            try {
              await m.createTable(communityFeeds);
            } catch (_) {}
            try {
              await m.createTable(userShareModuleDefaults);
            } catch (_) {}

            try {
              await m.addColumn(leads, leads.visibility);
            } catch (_) {}
            try {
              await m.addColumn(deals, deals.visibility);
            } catch (_) {}
            try {
              await m.addColumn(serviceListings, serviceListings.visibility);
            } catch (_) {}
            try {
              await m.addColumn(tasks, tasks.visibility);
            } catch (_) {}
            try {
              await m.addColumn(projects, projects.visibility);
            } catch (_) {}

            try {
              await m.addColumn(trustScores, trustScores.tinScore);
            } catch (_) {}
            try {
              await m.addColumn(trustScores, trustScores.tamScore);
            } catch (_) {}
            try {
              await m.addColumn(trustScores, trustScores.nhanScore);
            } catch (_) {}
            try {
              await m.addColumn(trustScores, trustScores.overallHti);
            } catch (_) {}
            try {
              await m.addColumn(trustScores, trustScores.completedTransactions);
            } catch (_) {}
            try {
              await m.addColumn(trustScores, trustScores.mutualAidCompleted);
            } catch (_) {}
            try {
              await m.addColumn(trustScores, trustScores.amicableDisputesResolved);
            } catch (_) {}
            try {
              await m.addColumn(trustScores, trustScores.updatedAt);
            } catch (_) {}
          }
          if (from < 12) {
            try {
              await m.createTable(growRooms);
            } catch (_) {}
            try {
              await m.createTable(mushroomJobs);
            } catch (_) {}
          }
          if (from < 13) {
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.scheduledAt);
            } catch (_) {}
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.priority);
            } catch (_) {}
          }
          if (from < 14) {
            try {
              await m.createTable(mushroomJobSafetyConfigs);
            } catch (_) {}
            try {
              await m.createTable(mushroomSafetyCheckinLogs);
            } catch (_) {}
          }
          if (from < 15) {
            try {
              await m.createTable(chatConversations);
            } catch (_) {}
            try {
              await m.createTable(chatParticipants);
            } catch (_) {}
            try {
              await m.createTable(chatMessages);
            } catch (_) {}
          }
          // Track 3: Device Identity & E2EE Messaging
          if (from < 16) {
            try {
              await m.createTable(deviceRegistryEntries);
            } catch (_) {}
            try {
              await m.createTable(encryptedMessageQueue);
            } catch (_) {}
            try {
              await m.createTable(deviceTrustLedger);
            } catch (_) {}
          }
          if (from < 17) {
            try {
              await customStatement('''
                CREATE TABLE IF NOT EXISTS local_ble_peers (
                  device_id TEXT NOT NULL PRIMARY KEY,
                  device_name TEXT NOT NULL,
                  public_key TEXT NOT NULL,
                  signing_public_key TEXT NOT NULL,
                  last_seen_at TEXT NOT NULL,
                  rssi INTEGER NOT NULL
                );
              ''');
            } catch (_) {}
          }
          if (from < 18) {
            try {
              await customStatement('''
                CREATE TABLE IF NOT EXISTS in_app_notifications (
                  id TEXT NOT NULL PRIMARY KEY,
                  user_id TEXT NOT NULL,
                  title TEXT NOT NULL,
                  body TEXT NOT NULL,
                  event_type TEXT NOT NULL,
                  resource_id TEXT,
                  read_at INTEGER,
                  created_at INTEGER NOT NULL
                );
              ''');
            } catch (_) {}
            try {
              await customStatement('''
                CREATE TABLE IF NOT EXISTS notification_settings_table (
                  user_id TEXT NOT NULL,
                  event_type TEXT NOT NULL,
                  enable_push INTEGER NOT NULL DEFAULT 1,
                  enable_in_app INTEGER NOT NULL DEFAULT 1,
                  enable_email INTEGER NOT NULL DEFAULT 1,
                  digest_frequency TEXT NOT NULL DEFAULT 'instant',
                  PRIMARY KEY (user_id, event_type)
                );
              ''');
            } catch (_) {}
          }
          if (from < 19) {
            try {
              await m.createTable(growRooms);
            } catch (_) {}
            try {
              await m.createTable(mushroomMaintenanceTickets);
            } catch (_) {}
            try {
              await m.createTable(mushroomChatMessages);
            } catch (_) {}
            try {
              await m.createTable(mushroomRoomCrews);
            } catch (_) {}
          }
          if (from < 20) {
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.coLevel);
            } catch (_) {}
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.co2Level);
            } catch (_) {}
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.checkInTime);
            } catch (_) {}
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.checkOutTime);
            } catch (_) {}
          }
          if (from < 21) {
            try {
              await m.createTable(mushroomEmployees);
            } catch (_) {}
          }
          if (from < 22) {
            try {
              await m.addColumn(mushroomEmployees, mushroomEmployees.department);
            } catch (_) {}
          }
          if (from < 23) {
            try {
              await m.createTable(mushroomYieldSurveys);
            } catch (_) {}
          }
          if (from < 24) {
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.sequence);
            } catch (_) {}
            try {
              await m.createTable(mushroomDepartments);
            } catch (_) {}
            try {
              await m.createTable(mushroomEmployeeDepartmentRoles);
            } catch (_) {}
            try {
              await m.createTable(mushroomPermissionOverrides);
            } catch (_) {}
          }
          if (from < 25) {
            try {
              await m.addColumn(mushroomEmployees, mushroomEmployees.passwordHash);
            } catch (_) {}
            try {
              await m.addColumn(mushroomEmployees, mushroomEmployees.linkedUserId);
            } catch (_) {}
          }
          if (from < 26) {
            try {
              await m.addColumn(mushroomEmployees, mushroomEmployees.employmentType);
            } catch (_) {}
            try {
              await m.addColumn(mushroomEmployees, mushroomEmployees.baseRate);
            } catch (_) {}
            try {
              await m.addColumn(mushroomEmployees, mushroomEmployees.defaultShed);
            } catch (_) {}
            try {
              await m.addColumn(mushroomEmployees, mushroomEmployees.pickerTeamColor);
            } catch (_) {}
            try {
              await m.createTable(mushroomHarvestPlans);
            } catch (_) {}
            try {
              await m.createTable(mushroomShifts);
            } catch (_) {}
            try {
              await m.createTable(mushroomPickerTeams);
            } catch (_) {}
            try {
              await m.createTable(mushroomRoomAssignments);
            } catch (_) {}
            try {
              await m.createTable(mushroomAttendanceEvents);
            } catch (_) {}
            try {
              await m.createTable(mushroomBreakPolicies);
            } catch (_) {}
            try {
              await m.createTable(mushroomDailyTimesheets);
            } catch (_) {}
            try {
              await m.createTable(mushroomPayrollCalculations);
            } catch (_) {}
          }
          if (from < 27) {
            try {
              await m.createTable(mushroomJobTypes);
            } catch (_) {}
          }
          if (from < 28) {
            try {
              await m.addColumn(mushroomJobs, mushroomJobs.onTimeOverride);
            } catch (_) {}
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    File file;
    final envPath = Platform.environment['IZIIAPP_DB_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      file = File(envPath);
    } else if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? r'C:\Users\CHANH\AppData\Local';
      final secureDir = Directory(p.join(localAppData, 'izii_app', 'data'));
      if (!secureDir.existsSync()) {
        secureDir.createSync(recursive: true);
      }
      file = File(p.join(secureDir.path, 'izii_app_db.sqlite'));

      // ── Migration một lần từ DB cũ nằm trong OneDrive ────────────────────
      //
      // ⚠️ CẨN TRỌNG: đoạn này từng là cái bẫy khi reset dữ liệu. Điều kiện cũ
      // chỉ là `if (!file.existsSync())`, nghĩa là MỖI LẦN xoá DB local, lần
      // chạy kế tiếp app sẽ âm thầm copy lại toàn bộ dữ liệu cũ từ OneDrive —
      // người dùng tưởng đã reset sạch nhưng dữ liệu cũ quay về nguyên vẹn.
      //
      // Giờ có thêm file cờ: migration chỉ chạy đúng MỘT lần trong đời máy.
      // Sau khi đã migrate (hoặc sau khi reset chủ động), cờ tồn tại và đoạn
      // này không bao giờ chạy lại nữa.
      final legacyFlag = File(p.join(secureDir.path, '.legacy_migrated'));
      if (!file.existsSync() && !legacyFlag.existsSync()) {
        final legacyFile = File(
          p.join(
            Platform.environment['USERPROFILE'] ?? r'C:\Users\CHANH',
            'OneDrive',
            'Documents',
            'izii_app_db.sqlite',
          ),
        );
        if (legacyFile.existsSync()) {
          try {
            legacyFile.copySync(file.path);
          } catch (_) {
            file = legacyFile;
          }
        }
        // Đánh dấu đã xử lý, kể cả khi không tìm thấy file cũ — để lần sau
        // không dò lại nữa.
        try {
          legacyFlag.writeAsStringSync(
            'Legacy OneDrive DB migration handled at '
            '${DateTime.now().toIso8601String()}.\n'
            'Xoá file này chỉ khi bạn thực sự muốn nạp lại DB cũ từ OneDrive.\n',
          );
        } catch (_) {}
      }
    } else {
      final dbFolder = await getApplicationSupportDirectory();
      file = File(p.join(dbFolder.path, 'izii_app_db.sqlite'));
    }

    // Fix for Android: ensure native SQLite library is loaded correctly
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
