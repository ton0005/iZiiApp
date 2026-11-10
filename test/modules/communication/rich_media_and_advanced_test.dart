// test/modules/communication/rich_media_and_advanced_test.dart
//
// Kiểm thử tự động cho Phase 3, Phase 4, Phase 5, Phase 6:
// Phase 3: Tin nhắn thoại (Voice recording & waveform), Trích xuất liên kết xem trước (Link preview).
// Phase 4: Tìm kiếm tin nhắn cục bộ (E2EE Client Search), Ghim (Pin), Lưu trữ (Archive), Tắt thông báo (Mute), Đếm chưa đọc (Unread Count).
// Phase 5: Thông báo & Trạng thái hiện diện.
// Phase 6: Tin nhắn tự huỷ (Disappearing / Burn-after), Lên lịch gửi tin (Scheduled messages), Thăm dò ý kiến (Polls).

import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/communication/repository/chat_repository.dart';
import 'package:izii_app/modules/communication/widgets/link_preview_card.dart';
import 'package:izii_app/modules/communication/widgets/poll_message_widget.dart';

void main() {
  group('Phase 3: Rich Media & Link Previews', () {
    test('LinkPreviewCard.extractUrls trích xuất chính xác các URL trong tin nhắn', () {
      const text = 'Xin chào, vui lòng kiểm tra báo cáo tại https://costa.com.au/safety và xem thêm ở http://mushrooms.org/ca-lam!';
      final urls = LinkPreviewCard.extractUrls(text);

      expect(urls.length, equals(2));
      expect(urls, contains('https://costa.com.au/safety'));
      expect(urls, contains('http://mushrooms.org/ca-lam'));
    });

    test('Tin nhắn không có URL trả về danh sách rỗng', () {
      const text = 'Hôm nay thu hoạch nấm phòng 3 đạt 120kg.';
      final urls = LinkPreviewCard.extractUrls(text);
      expect(urls, isEmpty);
    });
  });

  group('Phase 4: Inbox Organization & Client Search', () {
    late AppDatabase db;
    late ChatRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.testInstance = db;
      repo = ChatRepository(db);

      for (final id in ['alice', 'bob']) {
        await db.into(db.users).insert(UsersCompanion.insert(
              id: id,
              name: id.toUpperCase(),
              type: 'both',
            ));
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('Ghim cuộc hội thoại (isPinned) đẩy hội thoại lên đầu danh sách', () async {
      final c1 = await repo.getOrCreateDirectConversation('alice', 'bob');

      var convos = await repo.getConversations('alice');
      expect(convos.first.isPinned, isFalse);

      await repo.setConversationPinned(c1.id, true);
      convos = await repo.getConversations('alice');
      expect(convos.first.isPinned, isTrue);

      await repo.setConversationPinned(c1.id, false);
      convos = await repo.getConversations('alice');
      expect(convos.first.isPinned, isFalse);
    });

    test('Lưu trữ (Archive) và tắt thông báo (Mute)', () async {
      final c1 = await repo.getOrCreateDirectConversation('alice', 'bob');

      await repo.setConversationArchived(c1.id, true);
      var conv = await (db.select(db.chatConversations)..where((c) => c.id.equals(c1.id))).getSingle();
      expect(conv.isArchived, isTrue);

      final muteTime = DateTime.now().add(const Duration(hours: 8));
      await repo.setConversationMuted(c1.id, muteTime);
      conv = await (db.select(db.chatConversations)..where((c) => c.id.equals(c1.id))).getSingle();
      expect(conv.mutedUntil, isNotNull);
    });

    test('Đếm chưa đọc (Unread Count): tăng và đặt lại về 0 khi đọc', () async {
      final c1 = await repo.getOrCreateDirectConversation('alice', 'bob');

      await repo.incrementUnreadCount(c1.id);
      await repo.incrementUnreadCount(c1.id);

      var conv = await (db.select(db.chatConversations)..where((c) => c.id.equals(c1.id))).getSingle();
      expect(conv.unreadCount, equals(2));

      await repo.markConversationRead(c1.id);
      conv = await (db.select(db.chatConversations)..where((c) => c.id.equals(c1.id))).getSingle();
      expect(conv.unreadCount, equals(0));
    });

    test('Tìm kiếm tin nhắn cục bộ (searchMessages) lọc đúng nội dung', () async {
      final c1 = await repo.getOrCreateDirectConversation('alice', 'bob');

      await repo.saveMessage(ChatMessage(
        id: 'msg_search_1',
        conversationId: c1.id,
        senderId: 'bob',
        type: 'text',
        content: jsonEncode({'text': 'Nhiệt độ phòng 1 đang ở mức 18 độ C'}),
        sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isDeleted: false,
      ));

      await repo.saveMessage(ChatMessage(
        id: 'msg_search_2',
        conversationId: c1.id,
        senderId: 'alice',
        type: 'text',
        content: jsonEncode({'text': 'Đã kiểm tra độ ẩm phòng 2'}),
        sentAt: DateTime.now(),
        isDeleted: false,
      ));

      final results = await repo.searchMessages(query: 'Nhiệt độ');
      expect(results.length, equals(1));
      expect(results.first.id, equals('msg_search_1'));

      final allResults = await repo.searchMessages(query: 'phòng');
      expect(allResults.length, equals(2));
    });
  });

  group('Phase 6: Advanced (Disappearing Messages, Scheduled, Polls)', () {
    late AppDatabase db;
    late ChatRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.testInstance = db;
      repo = ChatRepository(db);

      for (final id in ['alice', 'bob']) {
        await db.into(db.users).insert(UsersCompanion.insert(
              id: id,
              name: id.toUpperCase(),
              type: 'both',
            ));
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('Tin nhắn tự huỷ (purgeDisappearingMessages) xoá tin nhắn đã hết hạn', () async {
      final c1 = await repo.getOrCreateDirectConversation('alice', 'bob');

      // Tin nhắn tự huỷ sau 10 giây, đã đọc cách đây 30 giây -> hết hạn
      await db.into(db.chatMessages).insert(ChatMessage(
            id: 'burn_msg_1',
            conversationId: c1.id,
            senderId: 'alice',
            type: 'text',
            content: jsonEncode({'text': 'Mã két an toàn là 9999'}),
            sentAt: DateTime.now().subtract(const Duration(minutes: 1)),
            readAt: DateTime.now().subtract(const Duration(seconds: 30)),
            burnAfterSeconds: 10,
            isDeleted: false,
          ));

      // Tin nhắn tự huỷ sau 600 giây, đã đọc cách đây 10 giây -> CHƯA hết hạn
      await db.into(db.chatMessages).insert(ChatMessage(
            id: 'burn_msg_2',
            conversationId: c1.id,
            senderId: 'alice',
            type: 'text',
            content: jsonEncode({'text': 'Tin nhắn này còn hạn 10 phút'}),
            sentAt: DateTime.now(),
            readAt: DateTime.now().subtract(const Duration(seconds: 10)),
            burnAfterSeconds: 600,
            isDeleted: false,
          ));

      final purgedCount = await repo.purgeDisappearingMessages();
      expect(purgedCount, equals(1));

      final msg1 = await repo.getMessageById('burn_msg_1');
      expect(msg1!.isDeleted, isTrue);

      final msg2 = await repo.getMessageById('burn_msg_2');
      expect(msg2!.isDeleted, isFalse);
    });

    test('Lên lịch gửi tin (getScheduledMessagesToSend) trả về tin đến hạn', () async {
      final c1 = await repo.getOrCreateDirectConversation('alice', 'bob');

      // Lên lịch trong quá khứ 1 phút -> đã đến hạn
      await db.into(db.chatMessages).insert(ChatMessage(
            id: 'sched_msg_1',
            conversationId: c1.id,
            senderId: 'alice',
            type: 'text',
            content: jsonEncode({'text': 'Báo cáo ca đêm tự động'}),
            sentAt: DateTime.now(),
            scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
            isDeleted: false,
          ));

      // Lên lịch tương lai 1 giờ -> CHƯA đến hạn
      await db.into(db.chatMessages).insert(ChatMessage(
            id: 'sched_msg_2',
            conversationId: c1.id,
            senderId: 'alice',
            type: 'text',
            content: jsonEncode({'text': 'Nhắc lịch bảo trì'}),
            sentAt: DateTime.now(),
            scheduledAt: DateTime.now().add(const Duration(hours: 1)),
            isDeleted: false,
          ));

      final readyMessages = await repo.getScheduledMessagesToSend();
      expect(readyMessages.length, equals(1));
      expect(readyMessages.first.id, equals('sched_msg_1'));
    });

    test('Bình chọn (PollOption) chuyển đổi map và tính toán số phiếu', () {
      final opt1 = PollOption(id: 'opt_1', text: 'Ca sáng', voterIds: ['alice', 'bob']);
      final opt2 = PollOption(id: 'opt_2', text: 'Ca chiều', voterIds: ['charlie']);

      final map = opt1.toMap();
      expect(map['text'], equals('Ca sáng'));
      expect(map['voter_ids'], containsAll(['alice', 'bob']));

      final restored = PollOption.fromMap(map);
      expect(restored.id, equals('opt_1'));
      expect(restored.voterIds.length, equals(2));

      final totalVotes = opt1.voterIds.length + opt2.voterIds.length;
      expect(totalVotes, equals(3));
    });
  });
}
