import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../../modules/sales_crm/database/tables.dart';
import '../../modules/supply_chain/database/tables.dart';
import '../../modules/services/database/tables.dart';
import '../community/database/tables.dart';

part 'app_database.g.dart';

// --- Tables ---

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
  OutboxMutations
])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(leads, leads.customFields);
          }
          if (from < 3) {
            await m.addColumn(products, products.customFields);
          }
          if (from < 4) {
            await m.createTable(serviceItems);
            await m.createTable(serviceBookings);
          }
          if (from < 5) {
            // Add barcode column as nullable text
            // Note: SQLite doesn't support adding UNIQUE constraints via ALTER TABLE,
            // so we add it nullable and can enforce uniqueness at application level
            await m.addColumn(products, products.barcode);
          }
          if (from < 6) {
            await m.createTable(outboxMutations);
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
