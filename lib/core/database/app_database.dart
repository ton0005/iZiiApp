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
  MushroomRooms,
  MushroomJobs,
  MushroomJobSafetyConfigs,
  MushroomSafetyCheckinLogs,
  ChatConversations,
  ChatParticipants,
  ChatMessages,
  // Track 3: Device Identity & E2EE
  DeviceRegistryEntries,
  EncryptedMessageQueue,
  DeviceTrustLedger
])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 16;

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
              await m.createTable(mushroomRooms);
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
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'izii_app_db.sqlite'));

    // Fix for Android: ensure native SQLite library is loaded correctly
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
