import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

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
    if (participants.isEmpty) return null;

    final companionParticipant = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );

    final query = _db.select(_db.users)
      ..where((u) => u.id.equals(companionParticipant.userId));
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

  // Fetch all users that are shared with or inside the trust network
  Future<List<User>> getReachableContacts(String currentUserId) async {
    // Ensure default user and mock contacts exist in database
    await _db.into(_db.users).insert(
          User(
            id: 'default_user',
            name: 'Tôi (Demo User)',
            type: 'both',
            kycStatus: 'verified',
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );

    final mockContacts = [
      User(
        id: 'user_an_nguyen',
        name: 'Nguyễn Văn An',
        email: 'an.nguyen@izii.net',
        phone: '0901234567',
        type: 'provider',
        kycStatus: 'verified',
        createdAt: DateTime.now(),
      ),
      User(
        id: 'user_huong_vo',
        name: 'Võ Thị Hương',
        email: 'huong.vo@izii.net',
        phone: '0907654321',
        type: 'provider',
        kycStatus: 'verified',
        createdAt: DateTime.now(),
      ),
      User(
        id: 'user_bich_tran',
        name: 'Trần Thị Bích',
        email: 'bich.tran@izii.net',
        phone: '0988888888',
        type: 'provider',
        kycStatus: 'verified',
        createdAt: DateTime.now(),
      ),
      User(
        id: 'user_quill_phan',
        name: 'Quill Phan',
        email: 'Quill.Phan@iziiapp.com',
        phone: '0488951392',
        type: 'provider',
        kycStatus: 'verified',
        createdAt: DateTime.now(),
      ),
    ];
    for (var mock in mockContacts) {
      await _db.into(_db.users).insert(mock, mode: InsertMode.insertOrIgnore);
    }

    final query = _db.select(_db.users)
      ..where((u) => u.id.equals(currentUserId).not());
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
