import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class OutboxQueue {
  static final OutboxQueue _instance = OutboxQueue._internal();
  factory OutboxQueue() => _instance;
  OutboxQueue._internal();

  AppDatabase get _db => AppDatabase();

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

  /// Server TỪ CHỐI VĨNH VIỄN thay đổi này — gửi lại bao nhiêu lần cũng vậy.
  ///
  /// VÌ SAO PHẢI CÓ TRẠNG THÁI RIÊNG: hàng đợi gửi theo thứ tự và chỉ lấy các
  /// bản ghi `pending`. Một thay đổi bị server trả 409 (ví dụ công việc Alone
  /// Worker giao cho người chưa điểm danh) sẽ nằm mãi ở đầu hàng và chặn TOÀN
  /// BỘ các thay đổi phía sau — người dùng thấy y như mất kết nối, dù mạng vẫn
  /// thông và mọi thứ khác vẫn 200.
  ///
  /// Log ngày 15/08 ghi nhận đúng hiện tượng này: 40 lần `/sync/push` trả 409
  /// liên tiếp trong khi mọi request khác đều thành công.
  ///
  /// Đánh dấu `rejected` để nó rời khỏi hàng đợi, giữ lại bản ghi để tra cứu.
  Future<void> markAsRejected(String mutationId) async {
    await (_db.update(_db.outboxMutations)..where((tbl) => tbl.id.equals(mutationId)))
        .write(const OutboxMutationsCompanion(status: Value('rejected')));
  }

  /// Các thay đổi từng bị server từ chối — để màn hình Đồng bộ hiện lại cho
  /// người dùng biết cái gì đã không được ghi nhận.
  Future<List<Map<String, dynamic>>> getRejectedMutations() async {
    final list = await (_db.select(_db.outboxMutations)
          ..where((tbl) => tbl.status.equals('rejected'))
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
      };
    }).toList();
  }

  Future<void> clearRejected() async {
    await (_db.delete(_db.outboxMutations)..where((tbl) => tbl.status.equals('rejected'))).go();
  }

  Future<void> clearSynced() async {
    await (_db.delete(_db.outboxMutations)..where((tbl) => tbl.status.equals('synced'))).go();
  }
}
