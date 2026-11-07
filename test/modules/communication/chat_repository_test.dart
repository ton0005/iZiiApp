// test/modules/communication/chat_repository_test.dart
//
// Nền tảng chat Phase 0:
// 1. isDirectMember khớp đúng quy tắc của server/chat_access.py (id có '_').
// 2. Phân trang lịch sử theo khoá (sent_at, id): không lặp, không sót tin,
//    kể cả khi nhiều tin trùng sent_at.
// 3. Cột mới (replyToId, editedAt, forwardedFromId) đi qua outbox.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/communication/repository/chat_repository.dart';

void main() {
  group('isDirectMember', () {
    test('khớp hai thành viên của direct_a_b', () {
      expect(ChatRepository.isDirectMember('direct_a_b', 'a'), isTrue);
      expect(ChatRepository.isDirectMember('direct_a_b', 'b'), isTrue);
      expect(ChatRepository.isDirectMember('direct_a_b', 'c'), isFalse);
      expect(ChatRepository.isDirectMember('group-1', 'a'), isFalse);
      expect(ChatRepository.isDirectMember('direct_a_b', ''), isFalse);
    });

    test('id chứa dấu gạch dưới không bị tách sai', () {
      const cid = 'direct_EMP_007_izii-d-ab12';
      expect(ChatRepository.isDirectMember(cid, 'EMP_007'), isTrue);
      expect(ChatRepository.isDirectMember(cid, 'izii-d-ab12'), isTrue);
      expect(ChatRepository.isDirectMember(cid, 'EMP'), isFalse);
      expect(ChatRepository.isDirectMember(cid, '007'), isFalse);
    });
  });

  group('ChatRepository với DB in-memory', () {
    late AppDatabase db;
    late ChatRepository repo;
    const convo = 'direct_a_b';
    final base = DateTime(2026, 11, 1, 8);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.testInstance = db;
      repo = ChatRepository(db);
      for (final id in ['a', 'b']) {
        await db.into(db.users).insert(UsersCompanion.insert(
              id: id,
              name: id,
              type: 'both',
            ));
      }
    });

    tearDown(() async {
      await db.close();
    });

    ChatMessage msg(String id, DateTime sentAt) => ChatMessage(
          id: id,
          conversationId: convo,
          senderId: 'a',
          type: 'text',
          content: jsonEncode({'text': id}),
          sentAt: sentAt,
          isDeleted: false,
        );

    test('isLocalMember dùng quy tắc direct và bảng participants', () async {
      expect(await repo.isLocalMember(convo, 'a'), isTrue);
      expect(await repo.isLocalMember(convo, 'c'), isFalse);
      expect(await repo.isLocalMember('group-1', 'a'), isFalse);
    });

    test('phân trang lấy đủ mọi tin, không lặp, kể cả trùng sent_at', () async {
      // 120 tin, cứ 3 tin trùng một thời điểm.
      for (var i = 0; i < 120; i++) {
        await repo.saveMessage(msg(
            'm${i.toString().padLeft(3, '0')}', base.add(Duration(minutes: i ~/ 3))));
      }

      final seen = <String>[];
      var page = await repo.getMessages(convo);
      expect(page.length, ChatRepository.messagePageSize);
      expect(page.last.id, 'm119'); // trang đầu là trang MỚI nhất, cũ trước
      seen.insertAll(0, page.map((m) => m.id));

      var oldest = page.first;
      while (true) {
        page = await repo.getMessages(convo, before: oldest);
        if (page.isEmpty) break;
        seen.insertAll(0, page.map((m) => m.id));
        oldest = page.first;
      }

      expect(seen.length, 120);
      expect(seen.toSet().length, 120);
      expect(seen.first, 'm000');
      expect(seen.last, 'm119');
    });

    test('outbox mang theo reply/edit/forward (hội thoại không phải 1-1)', () async {
      // Tin 1-1 KHÔNG được vào outbox đồng bộ (đi bằng E2EE) — xem
      // direct_e2ee_channel_test. Outbox plaintext chỉ còn cho hội thoại theo
      // bản ghi/nhóm.
      final m = msg('m1', base).copyWith(
        conversationId: 'record-uuid-1',
        replyToId: const Value('m0'),
        editedAt: Value(base.add(const Duration(minutes: 5))),
        forwardedFromId: const Value('orig-9'),
      );
      await repo.saveMessage(m);
      await repo.queueMessageOffline(m);

      final saved = await (db.select(db.chatMessages)
            ..where((t) => t.id.equals('m1')))
          .getSingle();
      expect(saved.replyToId, 'm0');
      expect(saved.forwardedFromId, 'orig-9');

      final outbox = await db.select(db.outboxMutations).get();
      final payload = jsonDecode(outbox.single.payload) as Map<String, dynamic>;
      expect(payload['reply_to_id'], 'm0');
      expect(payload['forwarded_from_id'], 'orig-9');
      expect(DateTime.parse(payload['edited_at'] as String),
          base.add(const Duration(minutes: 5)));
    });
  });
}
