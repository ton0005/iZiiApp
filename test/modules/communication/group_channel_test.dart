// test/modules/communication/group_channel_test.dart
//
// Phase 2: Nhóm và Kênh thông báo (Groups & Broadcast Channels)
// 1. Tạo nhóm & kênh thông báo (owner, admin, member).
// 2. Quyền gửi bài: kênh thông báo chỉ admin/owner được đăng.
// 3. Phân quyền admin / promote / demote.
// 4. Đã xem bởi N người (message read receipts).
// 5. getGroupDetails nạp đầy đủ thông tin nhóm và thành viên.

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/communication/repository/chat_repository.dart';

void main() {
  group('Phase 2 Groups and Broadcast Channels', () {
    late AppDatabase db;
    late ChatRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.testInstance = db;
      repo = ChatRepository(db);

      for (final id in ['alice', 'bob', 'charlie']) {
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

    test('createGroup tạo nhóm thường với đúng roles và thông tin', () async {
      final group = await repo.createGroup(
        title: 'Team Alpha',
        description: 'Phòng ban dự án Alpha',
        creatorId: 'alice',
        memberUserIds: ['bob', 'charlie'],
      );

      expect(group.title, equals('Team Alpha'));
      expect(group.description, equals('Phòng ban dự án Alpha'));
      expect(group.isBroadcast, isFalse);

      final details = await repo.getGroupDetails(group.id);
      expect(details, isNotNull);
      expect(details!.title, equals('Team Alpha'));
      expect(details.members.length, equals(3));

      expect(await repo.isUserAdmin(group.id, 'alice'), isTrue);
      expect(await repo.isUserAdmin(group.id, 'bob'), isFalse);
      expect(await repo.isUserAdmin(group.id, 'charlie'), isFalse);

      // Nhóm thường: mọi thành viên đều có thể gửi tin
      expect(await repo.canUserPost(group.id, 'alice'), isTrue);
      expect(await repo.canUserPost(group.id, 'bob'), isTrue);
      expect(await repo.canUserPost(group.id, 'charlie'), isTrue);
    });

    test('Kênh thông báo (broadcast channel): chỉ admin/owner mới được đăng', () async {
      final channel = await repo.createGroup(
        title: 'Thông báo nông trường Costa Mushrooms',
        description: 'Kênh phát tin chính thức ca làm & an toàn lao động',
        isBroadcast: true,
        creatorId: 'alice',
        memberUserIds: ['bob', 'charlie'],
      );

      expect(channel.isBroadcast, isTrue);

      // Alice là owner -> có thể đăng
      expect(await repo.canUserPost(channel.id, 'alice'), isTrue);

      // Bob và Charlie là member -> KHÔNG được đăng
      expect(await repo.canUserPost(channel.id, 'bob'), isFalse);
      expect(await repo.canUserPost(channel.id, 'charlie'), isFalse);

      // Promote Bob lên admin -> Bob được đăng
      await repo.setParticipantRole(channel.id, 'bob', 'admin');
      expect(await repo.isUserAdmin(channel.id, 'bob'), isTrue);
      expect(await repo.canUserPost(channel.id, 'bob'), isTrue);

      // Charlie vẫn là member -> vẫn không được đăng
      expect(await repo.canUserPost(channel.id, 'charlie'), isFalse);
    });

    test('Rời nhóm và xoá thành viên', () async {
      final group = await repo.createGroup(
        title: 'Dự án beta',
        creatorId: 'alice',
        memberUserIds: ['bob', 'charlie'],
      );

      var details = await repo.getGroupDetails(group.id);
      expect(details!.members.map((m) => m.userId), containsAll(['alice', 'bob', 'charlie']));

      // Charlie rời nhóm
      await repo.leaveGroup(group.id, 'charlie');
      details = await repo.getGroupDetails(group.id);
      expect(details!.members.map((m) => m.userId), isNot(contains('charlie')));
      expect(details.members.length, equals(2));
    });

    test('Đã xem bởi N người (Read Receipts)', () async {
      const convoId = 'group_test_reads';
      const msgId = 'msg_001';

      await repo.recordMessageRead(convoId, msgId, 'bob');
      await repo.recordMessageRead(convoId, msgId, 'charlie');

      final reads = await repo.getMessageReads(msgId);
      expect(reads.length, equals(2));
      expect(reads.map((r) => r.userId), containsAll(['bob', 'charlie']));
      expect(reads[0].conversationId, equals(convoId));
    });
  });
}
