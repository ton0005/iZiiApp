import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/enrollment/device_user_service.dart';

class ChatRepository {
  final AppDatabase _db;

  ChatRepository([AppDatabase? database]) : _db = database ?? AppDatabase();

  // === CONVERSATIONS ===

  Future<List<ChatConversation>> getConversations(String currentUserId) async {
    final query = _db.select(_db.chatConversations)
      ..where((c) {
        final subquery = _db.selectOnly(_db.chatParticipants)
          ..addColumns([_db.chatParticipants.conversationId])
          ..where(_db.chatParticipants.userId.equals(currentUserId));
        return c.id.isInQuery(subquery);
      })
      ..orderBy([
        (c) =>
            OrderingTerm(expression: c.lastMessageAt, mode: OrderingMode.desc)
      ]);

    return query.get();
  }

  Future<List<ChatParticipant>> getParticipants(String conversationId) async {
    final query = _db.select(_db.chatParticipants)
      ..where((p) => p.conversationId.equals(conversationId));
    return query.get();
  }

  Future<User?> getCompanion(
      String conversationId, String currentUserId) async {
    final participants = await getParticipants(conversationId);
    final otherParticipants = participants.where((p) => p.userId != currentUserId).toList();

    String? companionUserId;
    if (otherParticipants.isNotEmpty) {
      companionUserId = otherParticipants.first.userId;
    } else if (conversationId.startsWith('direct_')) {
      final parts = conversationId.replaceFirst('direct_', '').split('_');
      for (final p in parts) {
        if (p != currentUserId) {
          companionUserId = p;
          break;
        }
      }
    }

    if (companionUserId == null || companionUserId == currentUserId) {
      return null;
    }

    final query = _db.select(_db.users)
      ..where((u) => u.id.equals(companionUserId!));
    return query.getSingleOrNull();
  }

  Future<ChatConversation> getOrCreateDirectConversation(
      String currentUserId, String otherUserId) async {
    final ids = [currentUserId, otherUserId]..sort();
    final convoId = 'direct_${ids[0]}_${ids[1]}';

    final query = _db.select(_db.chatConversations)
      ..where((c) => c.id.equals(convoId));

    final existing = await query.getSingleOrNull();
    if (existing != null) return existing;

    // Create new conversation
    final now = DateTime.now();

    final newConvo = ChatConversation(
      id: convoId,
      type: 'direct',
      createdBy: currentUserId,
      createdAt: now,
      lastMessageAt: now,
    );

    await _db.into(_db.chatConversations).insert(newConvo);

    await _db.into(_db.chatParticipants).insert(ChatParticipant(
          conversationId: convoId,
          userId: currentUserId,
          joinedAt: now,
          muted: false,
        ));

    await _db.into(_db.chatParticipants).insert(ChatParticipant(
          conversationId: convoId,
          userId: otherUserId,
          joinedAt: now,
          muted: false,
        ));

    return newConvo;
  }

  Future<ChatConversation> getOrCreateRecordLinkedConversation({
    required String currentUserId,
    required String recordType,
    required String recordId,
    required List<String> participantUserIds,
  }) async {
    final query = _db.select(_db.chatConversations)
      ..where((c) => c.type.equals('record_linked'))
      ..where((c) => c.recordType.equals(recordType))
      ..where((c) => c.recordId.equals(recordId));

    final existingConvo = await query.getSingleOrNull();
    if (existingConvo != null) return existingConvo;

    final convoId = const Uuid().v4();
    final now = DateTime.now();

    final newConvo = ChatConversation(
      id: convoId,
      type: 'record_linked',
      recordType: recordType,
      recordId: recordId,
      createdBy: currentUserId,
      createdAt: now,
      lastMessageAt: now,
    );

    await _db.into(_db.chatConversations).insert(newConvo);

    for (var userId in participantUserIds) {
      await _db.into(_db.chatParticipants).insert(ChatParticipant(
            conversationId: convoId,
            userId: userId,
            joinedAt: now,
            muted: false,
          ));
    }

    return newConvo;
  }

  // === MESSAGES ===

  Future<List<ChatMessage>> getMessages(String conversationId,
      {int limit = 50, int offset = 0}) async {
    final query = _db.select(_db.chatMessages)
      ..where((m) => m.conversationId.equals(conversationId))
      ..orderBy(
          [(m) => OrderingTerm(expression: m.sentAt, mode: OrderingMode.desc)])
      ..limit(limit, offset: offset);

    final messages = await query.get();
    // Return in chronological order
    return messages.reversed.toList();
  }

  Future<ChatMessage?> getLatestMessage(String conversationId) async {
    final query = _db.select(_db.chatMessages)
      ..where((m) => m.conversationId.equals(conversationId))
      ..orderBy(
          [(m) => OrderingTerm(expression: m.sentAt, mode: OrderingMode.desc)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> saveMessage(ChatMessage message) async {
    await _db
        .into(_db.chatMessages)
        .insert(message, mode: InsertMode.insertOrReplace);

    // Update lastMessageAt on conversation
    final updateQuery = _db.update(_db.chatConversations)
      ..where((c) => c.id.equals(message.conversationId));
    await updateQuery.write(ChatConversationsCompanion(
      lastMessageAt: Value(message.sentAt),
    ));
  }

  Future<void> updateMessageStatus(
    String messageId, {
    DateTime? deliveredAt,
    DateTime? readAt,
  }) async {
    final updateQuery = _db.update(_db.chatMessages)
      ..where((m) => m.id.equals(messageId));
    await updateQuery.write(ChatMessagesCompanion(
      deliveredAt:
          deliveredAt != null ? Value(deliveredAt) : const Value.absent(),
      readAt: readAt != null ? Value(readAt) : const Value.absent(),
    ));
  }

  Future<void> deleteMessage(String messageId) async {
    final updateQuery = _db.update(_db.chatMessages)
      ..where((m) => m.id.equals(messageId));
    await updateQuery.write(const ChatMessagesCompanion(
      isDeleted: Value(true),
    ));
  }

  // === OUTBOX INTEGRATION ===

  Future<void> queueMessageOffline(ChatMessage message) async {
    final outboxId = const Uuid().v4();
    final mutation = OutboxMutation(
      id: outboxId,
      targetTable: 'chat_messages',
      operation: 'insert',
      payload: jsonEncode({
        'id': message.id,
        'conversation_id': message.conversationId,
        'sender_id': message.senderId,
        'type': message.type,
        'content': message.content,
        'sent_at': message.sentAt.toIso8601String(),
      }),
      createdAt: DateTime.now(),
      status: 'pending',
    );
    await _db.into(_db.outboxMutations).insert(mutation);
  }

  /// Mã của các tài khoản demo từng được seed cứng trong code.
  ///
  /// Giữ lại danh sách này CHỈ để dọn dẹp — không bao giờ tạo mới nữa. Xem
  /// [purgeDemoAccounts].
  static const demoUserIds = <String>[
    'user_an_nguyen',
    'user_huong_vo',
    'user_bich_tran',
    'user_quill_phan',
    'default_user',
  ];

  /// Xoá sạch tài khoản demo và mọi dấu vết của chúng khỏi máy này.
  ///
  /// VÌ SAO PHẢI XOÁ CHỨ KHÔNG CHỈ NGỪNG TẠO: bốn tài khoản demo dùng chung
  /// không gian định danh với nhân viên thật (`user_quill_phan` vs `EMP007`),
  /// nên danh bạ lẫn lộn thật/giả và tin nhắn gửi nhầm người. Nguy hiểm hơn,
  /// chúng từng bị dùng làm khoá định tuyến cho Chat/Call, gây lệch namespace
  /// với `device_id` — lỗi đã tốn nhiều ngày để lần ra.
  ///
  /// Chạy một lần lúc khởi động, idempotent.
  Future<int> purgeDemoAccounts() async {
    var removed = 0;
    try {
      // Xoá tin nhắn và hội thoại dính tới tài khoản demo trước, để không còn
      // bản ghi mồ côi trỏ vào user đã biến mất.
      final demoParticipants = await (_db.select(_db.chatParticipants)
            ..where((p) => p.userId.isIn(demoUserIds)))
          .get();

      final convoIds = demoParticipants.map((p) => p.conversationId).toSet();

      for (final convoId in convoIds) {
        await (_db.delete(_db.chatMessages)
              ..where((m) => m.conversationId.equals(convoId)))
            .go();
        await (_db.delete(_db.chatParticipants)
              ..where((p) => p.conversationId.equals(convoId)))
            .go();
        await (_db.delete(_db.chatConversations)
              ..where((c) => c.id.equals(convoId)))
            .go();
      }

      await (_db.delete(_db.chatMessages)
            ..where((m) => m.senderId.isIn(demoUserIds)))
          .go();

      removed = await (_db.delete(_db.users)
            ..where((u) => u.id.isIn(demoUserIds)))
          .go();

      if (removed > 0) {
        print('[Chat] Đã xoá $removed tài khoản demo và dữ liệu liên quan.');
      }
    } catch (e) {
      print('[Chat] Lỗi khi dọn dẹp tài khoản demo: $e');
    }
    return removed;
  }

  /// Danh bạ: CHỈ các thiết bị thật đã đăng ký với server.
  ///
  /// Không còn nhánh dự phòng bằng tài khoản demo. Danh bạ rỗng là trạng thái
  /// hợp lệ và có ý nghĩa — nó nói đúng sự thật: chưa có máy nào khác đăng ký.
  /// Bịa ra vài cái tên để màn hình đỡ trống chỉ khiến người dùng nhắn cho
  /// người không tồn tại.
  Future<List<User>> getReachableContacts(String currentUserId) async {
    try {
      await DeviceUserService().syncDirectory();
    } catch (_) {
      // Mất mạng → dùng bản danh bạ đã đồng bộ lần trước, còn hơn là bịa.
    }

    final query = _db.select(_db.users)
      ..where((u) => u.id.equals(currentUserId).not())
      ..where((u) => u.id.isIn(demoUserIds).not());
    return query.get();
  }

  // ============================================================
  // Track 3: E2EE Message Persistence
  // ============================================================

  /// Save an encrypted message envelope to the local queue.
  Future<void> saveEncryptedMessage(EncryptedMessageQueueData entry) async {
    await _db.into(_db.encryptedMessageQueue).insert(
          entry,
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Get all pending (undelivered) encrypted messages for a device.
  Future<List<EncryptedMessageQueueData>> getPendingEncryptedMessages(
      String recipientDeviceId) async {
    final query = _db.select(_db.encryptedMessageQueue)
      ..where((m) => m.recipientDeviceId.equals(recipientDeviceId))
      ..where((m) => m.deliveredAt.isNull())
      ..orderBy(
          [(m) => OrderingTerm(expression: m.sentAt, mode: OrderingMode.asc)]);
    return query.get();
  }

  /// Mark an encrypted message as delivered.
  Future<void> markEncryptedMessageDelivered(String messageId) async {
    final updateQuery = _db.update(_db.encryptedMessageQueue)
      ..where((m) => m.id.equals(messageId));
    await updateQuery.write(EncryptedMessageQueueCompanion(
      deliveredAt: Value(DateTime.now()),
    ));
  }

  // ============================================================
  // Track 3: Device Registry Cache
  // ============================================================

  /// Look up a device's public key from the local cache.
  Future<DeviceRegistryEntry?> getDeviceRegistryEntry(String deviceId) async {
    final query = _db.select(_db.deviceRegistryEntries)
      ..where((d) => d.deviceId.equals(deviceId));
    return query.getSingleOrNull();
  }

  /// Cache a remote device's info locally.
  Future<void> saveDeviceRegistryEntry(DeviceRegistryEntry entry) async {
    await _db.into(_db.deviceRegistryEntries).insert(
          entry,
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Get all registered devices for a user.
  Future<List<DeviceRegistryEntry>> getDevicesForUser(String userId) async {
    final query = _db.select(_db.deviceRegistryEntries)
      ..where((d) => d.userId.equals(userId))
      ..where((d) => d.isRevoked.equals(false));
    return query.get();
  }

  /// Get all registered devices.
  Future<List<DeviceRegistryEntry>> getAllRegisteredDevices() async {
    final query = _db.select(_db.deviceRegistryEntries)
      ..where((d) => d.isRevoked.equals(false));
    return query.get();
  }
}
