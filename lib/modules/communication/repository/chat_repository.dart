import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/enrollment/device_user_service.dart';
import '../models/chat_envelope.dart';
import '../models/chat_models.dart';

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
            OrderingTerm(expression: c.isPinned, mode: OrderingMode.desc),
        (c) =>
            OrderingTerm(expression: c.lastMessageAt, mode: OrderingMode.desc)
      ]);

    return query.get();
  }

  /// Thành viên hội thoại 1-1 `direct_<a>_<b>` — cùng quy tắc với
  /// `server/chat_access.py` (`is_direct_member`).
  ///
  /// Không dùng split('_') vì id có thể chứa '_'. Khớp đầu/cuối vẫn mơ hồ
  /// (`direct_EMP_007_x` khớp cả "EMP"), nên dựa thêm vào việc
  /// [getOrCreateDirectConversation] luôn sắp xếp hai id: phần đầu <= phần cuối.
  static bool isDirectMember(String conversationId, String memberId) {
    const prefix = 'direct_';
    if (!conversationId.startsWith(prefix) || memberId.isEmpty) return false;
    final rest = conversationId.substring(prefix.length);
    final head = '${memberId}_';
    final tail = '_$memberId';
    if (rest.startsWith(head) &&
        memberId.compareTo(rest.substring(head.length)) <= 0) {
      return true;
    }
    if (rest.endsWith(tail) &&
        rest.substring(0, rest.length - tail.length).compareTo(memberId) <= 0) {
      return true;
    }
    return false;
  }

  /// Máy này có thuộc hội thoại [conversationId] không.
  Future<bool> isLocalMember(String conversationId, String memberId) async {
    if (conversationId.startsWith('direct_')) {
      return isDirectMember(conversationId, memberId);
    }
    final row = await (_db.select(_db.chatParticipants)
          ..where((p) =>
              p.conversationId.equals(conversationId) &
              p.userId.equals(memberId)))
        .getSingleOrNull();
    return row != null;
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
    final existingUser = await query.getSingleOrNull();
    if (existingUser != null) return existingUser;

    // Fallback: If not found in users table yet, create a placeholder user from companionUserId
    final fallbackUser = User(
      id: companionUserId,
      name: companionUserId,
      type: 'both',
      kycStatus: 'verified',
      createdAt: DateTime.now(),
    );
    try {
      await _db.into(_db.users).insertOnConflictUpdate(fallbackUser);
    } catch (_) {}
    return fallbackUser;
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
      isBroadcast: false,
      isPinned: false,
      isArchived: false,
      unreadCount: 0,
    );

    await _db.into(_db.chatConversations).insert(newConvo);

    await _db.into(_db.chatParticipants).insert(ChatParticipant(
          conversationId: convoId,
          userId: currentUserId,
          joinedAt: now,
          muted: false,
          role: 'member',
        ));

    await _db.into(_db.chatParticipants).insert(ChatParticipant(
          conversationId: convoId,
          userId: otherUserId,
          joinedAt: now,
          muted: false,
          role: 'member',
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
      isBroadcast: false,
      isPinned: false,
      isArchived: false,
      unreadCount: 0,
    );

    await _db.into(_db.chatConversations).insert(newConvo);

    for (var userId in participantUserIds) {
      await _db.into(_db.chatParticipants).insert(ChatParticipant(
            conversationId: convoId,
            userId: userId,
            joinedAt: now,
            muted: false,
            role: userId == currentUserId ? 'owner' : 'member',
          ));
    }

    return newConvo;
  }

  // === PHASE 2: GROUPS & CHANNELS ===

  Future<ChatConversation> createGroup({
    required String title,
    String? description,
    String? avatarUrl,
    bool isBroadcast = false,
    required List<String> memberUserIds,
    required String creatorId,
    String? customId,
  }) async {
    final convoId = customId ?? 'group_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
    final now = DateTime.now();

    final newConvo = ChatConversation(
      id: convoId,
      type: 'group',
      title: title,
      description: description,
      avatarUrl: avatarUrl,
      isBroadcast: isBroadcast,
      createdBy: creatorId,
      createdAt: now,
      lastMessageAt: now,
      isPinned: false,
      isArchived: false,
      unreadCount: 0,
    );

    await _db.into(_db.chatConversations).insertOnConflictUpdate(newConvo);

    final allMembers = {creatorId, ...memberUserIds};
    for (final uid in allMembers) {
      await _db.into(_db.chatParticipants).insertOnConflictUpdate(ChatParticipant(
        conversationId: convoId,
        userId: uid,
        role: uid == creatorId ? 'owner' : 'member',
        joinedAt: now,
        muted: false,
      ));
    }

    return newConvo;
  }

  Future<void> updateGroupInfo(String conversationId, {
    String? title,
    String? description,
    String? avatarUrl,
    bool? isBroadcast,
  }) async {
    final existing = await (_db.select(_db.chatConversations)..where((c) => c.id.equals(conversationId))).getSingleOrNull();
    if (existing == null) return;

    await (_db.update(_db.chatConversations)..where((c) => c.id.equals(conversationId))).write(
      ChatConversationsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        avatarUrl: avatarUrl != null ? Value(avatarUrl) : const Value.absent(),
        isBroadcast: isBroadcast != null ? Value(isBroadcast) : const Value.absent(),
      ),
    );
  }

  Future<void> addGroupParticipant(String conversationId, String userId, {String role = 'member'}) async {
    await _db.into(_db.chatParticipants).insertOnConflictUpdate(ChatParticipant(
      conversationId: conversationId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
      muted: false,
    ));
  }

  Future<void> removeGroupParticipant(String conversationId, String userId) async {
    await (_db.delete(_db.chatParticipants)
          ..where((p) => p.conversationId.equals(conversationId) & p.userId.equals(userId)))
        .go();
  }

  Future<void> setParticipantRole(String conversationId, String userId, String role) async {
    await (_db.update(_db.chatParticipants)
          ..where((p) => p.conversationId.equals(conversationId) & p.userId.equals(userId)))
        .write(ChatParticipantsCompanion(role: Value(role)));
  }

  Future<void> leaveGroup(String conversationId, String userId) async {
    await removeGroupParticipant(conversationId, userId);
  }

  Future<GroupDetails?> getGroupDetails(String conversationId) async {
    final conv = await (_db.select(_db.chatConversations)
          ..where((c) => c.id.equals(conversationId)))
        .getSingleOrNull();
    if (conv == null) return null;

    final participants = await (_db.select(_db.chatParticipants)
          ..where((p) => p.conversationId.equals(conversationId)))
        .get();

    final members = participants.map((p) {
      return GroupMemberInfo(
        userId: p.userId,
        name: p.userId,
        role: p.role,
        joinedAt: p.joinedAt,
      );
    }).toList();

    return GroupDetails(
      id: conv.id,
      title: conv.title ?? 'Group',
      description: conv.description,
      avatarUrl: conv.avatarUrl,
      isBroadcast: conv.isBroadcast,
      createdBy: conv.createdBy,
      createdAt: conv.createdAt,
      members: members,
    );
  }

  Future<bool> isUserAdmin(String conversationId, String userId) async {
    final p = await (_db.select(_db.chatParticipants)
          ..where((p) => p.conversationId.equals(conversationId) & p.userId.equals(userId)))
        .getSingleOrNull();
    if (p == null) return false;
    return p.role == 'owner' || p.role == 'admin';
  }

  Future<bool> canUserPost(String conversationId, String userId) async {
    if (conversationId.startsWith('direct_')) return true;
    final conv = await (_db.select(_db.chatConversations)..where((c) => c.id.equals(conversationId))).getSingleOrNull();
    if (conv == null || !conv.isBroadcast) return true;
    return isUserAdmin(conversationId, userId);
  }

  Future<void> recordMessageRead(String conversationId, String messageId, String userId, {DateTime? readAt}) async {
    final ts = readAt ?? DateTime.now();
    await _db.into(_db.chatMessageReads).insertOnConflictUpdate(ChatMessageRead(
      conversationId: conversationId,
      messageId: messageId,
      userId: userId,
      readAt: ts,
    ));
  }

  Future<List<ChatMessageRead>> getMessageReads(String messageId) async {
    return (_db.select(_db.chatMessageReads)
          ..where((r) => r.messageId.equals(messageId))
          ..orderBy([(r) => OrderingTerm(expression: r.readAt)]))
        .get();
  }

  // === MESSAGES ===

  static const int messagePageSize = 50;

  /// Một trang tin, cũ trước. Truyền [before] (tin cũ nhất đang hiển thị) để
  /// lấy trang liền trước nó.
  ///
  /// Phân trang theo khoá (sent_at, id) chứ không theo offset: tin mới đến
  /// trong lúc đang cuộn sẽ làm offset lệch và lặp/bỏ sót tin. Có thêm id vì
  /// nhiều tin có thể trùng sent_at (gửi hàng loạt, đồng bộ lại).
  Future<List<ChatMessage>> getMessages(String conversationId,
      {int limit = messagePageSize, ChatMessage? before}) async {
    final query = _db.select(_db.chatMessages)
      ..where((m) {
        final inConvo = m.conversationId.equals(conversationId);
        if (before == null) return inConvo;
        return inConvo &
            (m.sentAt.isSmallerThanValue(before.sentAt) |
                (m.sentAt.equals(before.sentAt) &
                    m.id.isSmallerThanValue(before.id)));
      })
      ..orderBy([
        (m) => OrderingTerm(expression: m.sentAt, mode: OrderingMode.desc),
        (m) => OrderingTerm(expression: m.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);

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
    // Đảm bảo hội thoại và người tham gia tồn tại trong SQLite local nếu đây là tin nhắn mới
    if (message.conversationId.startsWith('direct_')) {
      final parts = message.conversationId.replaceFirst('direct_', '').split('_');
      if (parts.length >= 2) {
        final now = message.sentAt;
        await _db.into(_db.chatConversations).insertOnConflictUpdate(
              ChatConversation(
                id: message.conversationId,
                type: 'direct',
                createdBy: message.senderId,
                createdAt: now,
                lastMessageAt: now,
                isBroadcast: false,
                isPinned: false,
                isArchived: false,
                unreadCount: 0,
              ),
            );
        for (final uid in parts) {
          await _db.into(_db.chatParticipants).insertOnConflictUpdate(
                ChatParticipant(
                  conversationId: message.conversationId,
                  userId: uid,
                  joinedAt: now,
                  muted: false,
                  role: 'member',
                ),
              );
        }
      }
    }

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

  // === E2EE ENVELOPES (hội thoại 1-1) ===

  /// Id của đối tác trong hội thoại 1-1; null nếu [myId] không thuộc hội thoại.
  /// Cùng quy tắc tách với [isDirectMember].
  static String? directPeer(String conversationId, String myId) {
    if (!isDirectMember(conversationId, myId)) return null;
    final rest = conversationId.substring('direct_'.length);
    final head = '${myId}_';
    if (rest.startsWith(head) &&
        myId.compareTo(rest.substring(head.length)) <= 0) {
      return rest.substring(head.length);
    }
    return rest.substring(0, rest.length - '_$myId'.length);
  }

  Future<void> enqueueE2ee(ChatEnvelope e) async {
    await _db.into(_db.e2eeOutbox).insert(
          E2eeOutboxData(
            id: e.id,
            conversationId: e.conversationId,
            envelope: e.toJson(),
            attempts: 0,
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Phong bì chờ gửi, CŨ TRƯỚC — thứ tự gửi phải giữ nguyên, nếu không sửa/thu
  /// hồi có thể tới trước tin gốc.
  Future<List<E2eeOutboxData>> pendingE2ee({int limit = 50}) {
    return (_db.select(_db.e2eeOutbox)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt),
            (t) => OrderingTerm(expression: t.id),
          ])
          ..limit(limit))
        .get();
  }

  Future<Set<String>> pendingE2eeIds() async {
    final rows = await (_db.selectOnly(_db.e2eeOutbox)
          ..addColumns([_db.e2eeOutbox.id]))
        .get();
    return rows.map((r) => r.read(_db.e2eeOutbox.id)!).toSet();
  }

  Future<void> removeE2ee(String id) =>
      (_db.delete(_db.e2eeOutbox)..where((t) => t.id.equals(id))).go();

  Future<void> markE2eeFailed(String id, String error) async {
    final row = await (_db.select(_db.e2eeOutbox)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.e2eeOutbox)..where((t) => t.id.equals(id))).write(
      E2eeOutboxCompanion(
        attempts: Value(row.attempts + 1),
        lastError: Value(error.length > 200 ? error.substring(0, 200) : error),
      ),
    );
  }

  Future<ChatMessage?> getMessageById(String id) => (_db.select(_db.chatMessages)
        ..where((m) => m.id.equals(id)))
      .getSingleOrNull();

  Future<List<ChatMessage>> getPinnedMessages(String conversationId) {
    return (_db.select(_db.chatMessages)
          ..where((m) =>
              m.conversationId.equals(conversationId) &
              m.pinnedAt.isNotNull() &
              m.isDeleted.equals(false))
          ..orderBy([
            (m) => OrderingTerm(expression: m.pinnedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<Map<String, List<ChatReaction>>> getReactionsFor(
      Iterable<String> messageIds) async {
    final ids = messageIds.toList();
    if (ids.isEmpty) return {};
    final rows = await (_db.select(_db.chatReactions)
          ..where((r) => r.messageId.isIn(ids))
          ..orderBy([(r) => OrderingTerm(expression: r.reactedAt)]))
        .get();
    final result = <String, List<ChatReaction>>{};
    for (final r in rows) {
      result.putIfAbsent(r.messageId, () => []).add(r);
    }
    return result;
  }

  /// Áp một phong bì vào DB cục bộ. [senderId] là người GỬI ĐÃ XÁC THỰC (từ
  /// chữ ký/ECDH), không phải thứ phong bì tự khai.
  ///
  /// Quyền: chỉ người gửi gốc mới sửa/thu hồi tin của mình. Thả cảm xúc và ghim
  /// thì mọi thành viên làm được (đã kiểm tra thành viên ở tầng kênh).
  /// Hàm idempotent — gửi lại cùng phong bì không đổi kết quả.
  Future<EnvelopeOutcome> applyEnvelope(
    ChatEnvelope e, {
    required String senderId,
    DateTime? receivedAt,
  }) async {
    // Đồng hồ máy gửi lệch/độc hại: không cho tin "đến từ tương lai" ghim lên
    // cuối danh sách mãi mãi.
    final now = DateTime.now();
    final ts = e.ts.isAfter(now.add(const Duration(minutes: 5))) ? now : e.ts;

    if (e.kind == ChatEnvelopeKind.message) {
      // Tin đã có (kể cả đã thu hồi) → không ghi đè. Nếu không, phát lại một
      // phong bì cũ sẽ "hồi sinh" tin đã thu hồi.
      if (await getMessageById(e.id) != null) return EnvelopeOutcome.duplicate;
      await saveMessage(ChatMessage(
        id: e.id,
        conversationId: e.conversationId,
        senderId: senderId,
        type: e.type ?? 'text',
        content: jsonEncode(e.content ?? const {}),
        sentAt: ts,
        deliveredAt: receivedAt,
        isDeleted: false,
        replyToId: e.replyToId,
        forwardedFromId: e.forwardedFromId,
      ));
      return EnvelopeOutcome.applied;
    }

    final target = await getMessageById(e.targetId ?? '');
    if (target == null || target.conversationId != e.conversationId) {
      // Sự kiện tới trước tin gốc hoặc nhắm sai hội thoại.
      return EnvelopeOutcome.ignored;
    }
    final update = _db.update(_db.chatMessages)
      ..where((m) => m.id.equals(target.id));

    switch (e.kind) {
      case ChatEnvelopeKind.edit:
        if (target.senderId != senderId || target.isDeleted) {
          return EnvelopeOutcome.ignored;
        }
        final prev = target.editedAt;
        if (prev != null && !ts.isAfter(prev)) return EnvelopeOutcome.ignored;
        final content = _decodeContent(target.content);
        content['text'] = e.newText ?? '';
        await update.write(ChatMessagesCompanion(
          content: Value(jsonEncode(content)),
          editedAt: Value(ts),
        ));
        return EnvelopeOutcome.applied;

      case ChatEnvelopeKind.revoke:
        if (target.senderId != senderId) return EnvelopeOutcome.ignored;
        if (target.isDeleted) return EnvelopeOutcome.duplicate;
        // Xoá sạch nội dung chứ không chỉ cờ isDeleted: "thu hồi với mọi người"
        // phải thật sự xoá khỏi máy người nhận.
        await update.write(const ChatMessagesCompanion(
          content: Value('{}'),
          isDeleted: Value(true),
          pinnedAt: Value(null),
        ));
        await (_db.delete(_db.chatReactions)
              ..where((r) => r.messageId.equals(target.id)))
            .go();
        return EnvelopeOutcome.applied;

      case ChatEnvelopeKind.reaction:
        if (target.isDeleted) return EnvelopeOutcome.ignored;
        final emoji = e.emoji ?? '';
        if (emoji.runes.length > 8) return EnvelopeOutcome.ignored;
        final existing = await (_db.select(_db.chatReactions)
              ..where((r) =>
                  r.messageId.equals(target.id) & r.userId.equals(senderId)))
            .getSingleOrNull();
        if (existing != null && existing.reactedAt.isAfter(ts)) {
          return EnvelopeOutcome.ignored;
        }
        if (emoji.isEmpty) {
          await (_db.delete(_db.chatReactions)
                ..where((r) =>
                    r.messageId.equals(target.id) & r.userId.equals(senderId)))
              .go();
        } else {
          await _db.into(_db.chatReactions).insertOnConflictUpdate(
                ChatReaction(
                    messageId: target.id,
                    userId: senderId,
                    emoji: emoji,
                    reactedAt: ts),
              );
        }
        return EnvelopeOutcome.applied;

      case ChatEnvelopeKind.pin:
        if (target.isDeleted) return EnvelopeOutcome.ignored;
        await update.write(ChatMessagesCompanion(
          pinnedAt: Value((e.pinned ?? false) ? ts : null),
        ));
        return EnvelopeOutcome.applied;

      case ChatEnvelopeKind.message:
        return EnvelopeOutcome.ignored; // đã xử lý ở trên
    }
  }

  static Map<String, dynamic> _decodeContent(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return <String, dynamic>{};
  }

  // === OUTBOX INTEGRATION ===

  Future<void> queueMessageOffline(ChatMessage message) async {
    // Tin 1-1 chỉ được đi bằng E2EE (xem E2eeOutbox). Đây là chốt chặn cuối:
    // dù có đường code nào quên và gọi hàm này, plaintext cũng không lên server
    // qua đồng bộ.
    if (message.conversationId.startsWith('direct_')) return;

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
        if (message.replyToId != null) 'reply_to_id': message.replyToId,
        if (message.editedAt != null)
          'edited_at': message.editedAt!.toIso8601String(),
        if (message.forwardedFromId != null)
          'forwarded_from_id': message.forwardedFromId,
        if (message.isDeleted) 'is_deleted': true,
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

  // ============================================================
  // Phase 4 & 6: Inbox Organization, Search & Advanced
  // ============================================================

  /// Ghim / bỏ ghim cuộc hội thoại trong Inbox
  Future<void> setConversationPinned(String conversationId, bool isPinned) async {
    await (_db.update(_db.chatConversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ChatConversationsCompanion(isPinned: Value(isPinned)));
  }

  /// Lưu trữ / bỏ lưu trữ cuộc hội thoại
  Future<void> setConversationArchived(String conversationId, bool isArchived) async {
    await (_db.update(_db.chatConversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ChatConversationsCompanion(isArchived: Value(isArchived)));
  }

  /// Tắt thông báo cuộc hội thoại có thời hạn
  Future<void> setConversationMuted(String conversationId, DateTime? until) async {
    await (_db.update(_db.chatConversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ChatConversationsCompanion(mutedUntil: Value(until)));
  }

  /// Đánh dấu đã đọc cuộc hội thoại (đặt unreadCount về 0)
  Future<void> markConversationRead(String conversationId) async {
    await (_db.update(_db.chatConversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(const ChatConversationsCompanion(unreadCount: Value(0)));
  }

  /// Tăng số lượng tin chưa đọc
  Future<void> incrementUnreadCount(String conversationId) async {
    final conv = await (_db.select(_db.chatConversations)
          ..where((c) => c.id.equals(conversationId)))
        .getSingleOrNull();
    final count = (conv?.unreadCount ?? 0) + 1;
    await (_db.update(_db.chatConversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ChatConversationsCompanion(unreadCount: Value(count)));
  }

  /// Tìm kiếm tin nhắn cục bộ (FTS-style search giữ nguyên E2EE)
  Future<List<ChatMessage>> searchMessages({
    String? conversationId,
    required String query,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final queryObj = _db.select(_db.chatMessages)
      ..where((m) => m.isDeleted.equals(false));
    if (conversationId != null) {
      queryObj.where((m) => m.conversationId.equals(conversationId));
    }
    queryObj.orderBy([(m) => OrderingTerm(expression: m.sentAt, mode: OrderingMode.desc)]);

    final all = await queryObj.get();
    return all.where((m) {
      try {
        final decoded = jsonDecode(m.content);
        if (decoded is Map) {
          final text = decoded['text']?.toString().toLowerCase() ?? '';
          return text.contains(q);
        }
      } catch (_) {}
      return false;
    }).take(limit).toList();
  }

  /// Phase 6: Xoá tin nhắn tự huỷ đã hết hạn (Disappearing Messages)
  Future<int> purgeDisappearingMessages() async {
    final now = DateTime.now();
    final query = _db.select(_db.chatMessages)
      ..where((m) => m.burnAfterSeconds.isNotNull() & m.readAt.isNotNull() & m.isDeleted.equals(false));
    final messages = await query.get();
    int purged = 0;

    for (final m in messages) {
      final burnSeconds = m.burnAfterSeconds ?? 0;
      if (burnSeconds > 0 && m.readAt != null) {
        final expiry = m.readAt!.add(Duration(seconds: burnSeconds));
        if (now.isAfter(expiry)) {
          await (_db.update(_db.chatMessages)..where((row) => row.id.equals(m.id))).write(
            const ChatMessagesCompanion(
              isDeleted: Value(true),
              content: Value('{"text":"[Disappearing message expired]"}'),
            ),
          );
          purged++;
        }
      }
    }
    return purged;
  }

  /// Phase 6: Lấy danh sách tin nhắn đã lên lịch đến giờ gửi
  Future<List<ChatMessage>> getScheduledMessagesToSend() async {
    final now = DateTime.now();
    final query = _db.select(_db.chatMessages)
      ..where((m) => m.scheduledAt.isNotNull() & m.deliveredAt.isNull() & m.isDeleted.equals(false))
      ..where((m) => m.scheduledAt.isSmallerOrEqualValue(now));
    return query.get();
  }
}

/// Kết quả áp một phong bì E2EE vào DB cục bộ.
enum EnvelopeOutcome {
  /// Đã thay đổi dữ liệu.
  applied,

  /// Đã có sẵn / đã áp rồi — bình thường khi gửi lại.
  duplicate,

  /// Bị bỏ: không đủ quyền, nhắm sai hội thoại, tin gốc chưa tới, hoặc lỗi thời.
  ignored,
}
