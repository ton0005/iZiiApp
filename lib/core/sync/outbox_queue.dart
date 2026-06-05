import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class OutboxQueue {
  static final OutboxQueue _instance = OutboxQueue._internal();
  factory OutboxQueue() => _instance;
  OutboxQueue._internal();

  final AppDatabase _db = AppDatabase();

  Future<void> addMutation(String tableName, String operation, Map<String, dynamic> data) async {
    final id = const Uuid().v4();
    await _db.into(_db.outboxMutations).insert(
      OutboxMutationsCompanion.insert(
        id: id,
        targetTable: tableName,
        operation: operation,
        payload: jsonEncode(data),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    final list = await (_db.select(_db.outboxMutations)
          ..where((tbl) => tbl.status.equals('pending'))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .get();

    return list.map((m) {
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(m.payload);
      } catch (_) {}
      return {
        'id': m.id,
        'table': m.targetTable,
        'operation': m.operation,
        'data': data,
        'timestamp': m.createdAt.toIso8601String(),
        'status': m.status,
      };
    }).toList();
  }

  Future<void> markAsSynced(String mutationId) async {
    await (_db.update(_db.outboxMutations)..where((tbl) => tbl.id.equals(mutationId)))
        .write(const OutboxMutationsCompanion(status: Value('synced')));
  }

  Future<void> markAsFailed(String mutationId) async {
    await (_db.update(_db.outboxMutations)..where((tbl) => tbl.id.equals(mutationId)))
        .write(const OutboxMutationsCompanion(status: Value('error')));
  }

  Future<void> clearSynced() async {
    await (_db.delete(_db.outboxMutations)..where((tbl) => tbl.status.equals('synced'))).go();
  }
}
