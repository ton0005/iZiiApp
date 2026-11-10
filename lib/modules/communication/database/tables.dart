import 'package:drift/drift.dart';
import '../../../core/database/core_tables.dart';

class ChatConversations extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get type => text()(); // 'direct' | 'record_linked' | 'group'
  TextColumn get title => text().nullable()(); // Tên nhóm / Kênh
  TextColumn get description => text().nullable()(); // Mô tả
  TextColumn get avatarUrl => text().nullable()(); // URL ảnh đại diện
  BoolColumn get isBroadcast => boolean().withDefault(const Constant(false))(); // Kênh thông báo (chỉ admin đăng tin)
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))(); // Ghim lên đầu inbox
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))(); // Lưu trữ cuộc hội thoại
  DateTimeColumn get mutedUntil => dateTime().nullable()(); // Tắt thông báo đến thời điểm
  IntColumn get unreadCount => integer().withDefault(const Constant(0))(); // Số tin chưa đọc
  TextColumn get recordType => text().nullable()(); // 'lead' | 'deal' | 'job' | 'service'
  TextColumn get recordId => text().nullable()(); // Linked UUID
  TextColumn get createdBy => text().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatParticipants extends Table {
  TextColumn get conversationId => text().references(ChatConversations, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get role => text().withDefault(const Constant('member'))(); // 'owner' | 'admin' | 'member'
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {conversationId, userId};
}

/// Đã đọc tin nhắn trong nhóm / kênh (Phase 2)
class ChatMessageReads extends Table {
  TextColumn get conversationId => text()();
  TextColumn get messageId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get readAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {messageId, userId};
}

class ChatMessages extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get conversationId => text().references(ChatConversations, #id)();
  TextColumn get senderId => text().references(Users, #id)();
  TextColumn get type => text()(); // 'text' | 'file' | 'record_link' | 'location' | 'sos'
  TextColumn get content => text()(); // JSON string matching the message payload schema
  DateTimeColumn get sentAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  // Không đặt references(): tin gốc có thể chưa về máy này (sync lệch thứ tự)
  // hoặc đã bị dọn — trả lời/chuyển tiếp vẫn phải lưu được.
  TextColumn get replyToId => text().nullable()();
  DateTimeColumn get editedAt => dateTime().nullable()();
  TextColumn get forwardedFromId => text().nullable()();
  /// Có giá trị = tin đang được ghim (thời điểm ghim). Ghim là trạng thái chung
  /// của hội thoại, đồng bộ giữa các thành viên bằng sự kiện `pin` mã hoá.
  DateTimeColumn get pinnedAt => dateTime().nullable()();
  IntColumn get burnAfterSeconds => integer().nullable()(); // Tin nhắn tự huỷ sau N giây
  DateTimeColumn get scheduledAt => dateTime().nullable()(); // Lên lịch gửi tin vào thời điểm

  @override
  Set<Column> get primaryKey => {id};
}

/// Cảm xúc (emoji) thả vào tin nhắn. Mỗi người một cảm xúc cho mỗi tin.
/// KHÔNG đi qua outbox đồng bộ plaintext — chỉ đến từ sự kiện E2EE `reaction`.
class ChatReactions extends Table {
  TextColumn get messageId => text()();
  TextColumn get userId => text()();
  TextColumn get emoji => text()();
  DateTimeColumn get reactedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {messageId, userId};
}

/// Hàng đợi gửi E2EE cục bộ: phong bì CHƯA gửi được (mất mạng, server sập,
/// chưa lấy được khoá người nhận).
///
/// Chứa plaintext của phong bì nên TUYỆT ĐỐI không được đưa vào OutboxMutations
/// hay bất kỳ đường đồng bộ nào — bảng này không có trong sync_config_repository.
/// Thà tin nằm chờ còn hơn rơi về đường plaintext.
class E2eeOutbox extends Table {
  TextColumn get id => text()(); // id phong bì
  TextColumn get conversationId => text()();
  TextColumn get envelope => text()(); // ChatEnvelope.toJson()
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================
// Track 3: Device Identity & E2EE Messaging Tables
// ============================================================

/// Local cache of the server's Device Registry.
/// Stores public keys of all known devices (own + remote).
class DeviceRegistryEntries extends Table {
  TextColumn get deviceId => text()();       // SHA-256 of public key, e.g. "izii-d-a3f8c2e9"
  TextColumn get userId => text()();
  TextColumn get publicKey => text()();      // Base64 X25519 public key
  TextColumn get signingPublicKey => text()(); // Base64 ED25519 public key
  TextColumn get deviceName => text()();     // e.g. "Vinh's iPhone 15 Pro"
  TextColumn get platform => text()();       // 'ios' | 'android' | 'windows' | 'macos' | 'linux'
  DateTimeColumn get registeredAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  BoolColumn get isTrusted => boolean().withDefault(const Constant(true))();
  BoolColumn get isRevoked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {deviceId};
}

/// Encrypted message queue — local cache of messages pulled from server.
/// Server stores these too, but this table lets us persist them locally for
/// offline decryption and history.
class EncryptedMessageQueue extends Table {
  TextColumn get id => text()();             // UUID
  TextColumn get conversationId => text()();
  TextColumn get senderDeviceId => text()(); // DID of sender
  TextColumn get recipientDeviceId => text()(); // DID of this device
  TextColumn get encryptedPayload => text()(); // Base64 AES-256-GCM ciphertext
  TextColumn get nonce => text()();          // Base64 GCM nonce/IV
  TextColumn get signature => text()();      // Base64 ED25519 signature
  DateTimeColumn get sentAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deliveredAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only trust ledger — records device trust events.
/// No UPDATE or DELETE should ever be performed on this table.
/// Prepared for Phase 3 (Trust Chain + QR approval).
class DeviceTrustLedger extends Table {
  TextColumn get id => text()();             // UUID
  TextColumn get eventType => text()();      // 'registered' | 'trusted' | 'revoked'
  TextColumn get deviceId => text()();
  TextColumn get actorDeviceId => text().nullable()(); // Device that approved/revoked
  TextColumn get signature => text()();      // ED25519 signature of event
  DateTimeColumn get eventAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class InAppNotifications extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get eventType => text()(); // e.g. new_message, mention, added_to_group, missed_call
  TextColumn get resourceId => text().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class NotificationSettingsTable extends Table {
  TextColumn get userId => text()();
  TextColumn get eventType => text()(); // 'new_message', 'new_group_message', 'mention', 'added_to_group', 'missed_call'
  BoolColumn get enablePush => boolean().withDefault(const Constant(true))();
  BoolColumn get enableInApp => boolean().withDefault(const Constant(true))();
  BoolColumn get enableEmail => boolean().withDefault(const Constant(true))();
  TextColumn get digestFrequency => text().withDefault(const Constant('instant'))();

  @override
  Set<Column> get primaryKey => {userId, eventType};
}
