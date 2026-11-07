import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' show Value;
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/device_identity/device_identity_service.dart';
import '../../../core/device_identity/device_discovery_service.dart';
import '../../../core/device_identity/device_identity_models.dart';
import '../models/chat_envelope.dart';
import '../models/chat_models.dart';
import '../repository/chat_repository.dart';
import '../services/chat_websocket_service.dart';
import '../services/direct_e2ee_channel.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/enrollment/device_user_service.dart';
import '../../../core/device_identity/ble_device_discovery_service.dart';
import '../models/ble_models.dart';
import '../../../core/events/app_event_bus.dart';
import '../call/incoming_call_service.dart';

// --- Events ---
abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class LoadConversationsEvent extends ChatEvent {}

class LoadContactsEvent extends ChatEvent {}

class OpenConversationEvent extends ChatEvent {
  final String conversationId;
  const OpenConversationEvent(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

/// Cuộn lên đầu danh sách — nạp thêm một trang tin cũ hơn.
class LoadOlderMessagesEvent extends ChatEvent {
  final String conversationId;
  const LoadOlderMessagesEvent(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

class OpenDirectChatWithUserEvent extends ChatEvent {
  final String otherUserId;
  const OpenDirectChatWithUserEvent(this.otherUserId);
  @override
  List<Object?> get props => [otherUserId];
}

class SendMessageEvent extends ChatEvent {
  final String conversationId;
  final String text;
  final ChatMessageType type;
  final Map<String, dynamic>? extraContent;
  final String? replyToId;
  final String? forwardedFromId;

  const SendMessageEvent({
    required this.conversationId,
    required this.text,
    this.type = ChatMessageType.text,
    this.extraContent,
    this.replyToId,
    this.forwardedFromId,
  });

  @override
  List<Object?> get props =>
      [conversationId, text, type, extraContent, replyToId, forwardedFromId];
}

/// Gửi một phong bì E2EE đã dựng sẵn (dùng cho cả sự kiện nền như tải tệp xong).
class SendEnvelopeEvent extends ChatEvent {
  final ChatEnvelope envelope;
  const SendEnvelopeEvent(this.envelope);
  @override
  List<Object?> get props => [envelope.id];
}

class FlushE2eeOutboxEvent extends ChatEvent {}

class EditMessageEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  final String newText;
  const EditMessageEvent(this.conversationId, this.messageId, this.newText);
  @override
  List<Object?> get props => [conversationId, messageId, newText];
}

/// [forEveryone] chỉ có hiệu lực ở hội thoại 1-1 (E2EE) và với tin của chính
/// mình; ngoài ra chỉ xoá trên máy này.
class RevokeMessageEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  final bool forEveryone;
  const RevokeMessageEvent(this.conversationId, this.messageId,
      {this.forEveryone = false});
  @override
  List<Object?> get props => [conversationId, messageId, forEveryone];
}

class ToggleReactionEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  final String emoji;
  const ToggleReactionEvent(this.conversationId, this.messageId, this.emoji);
  @override
  List<Object?> get props => [conversationId, messageId, emoji];
}

class TogglePinEvent extends ChatEvent {
  final String conversationId;
  final String messageId;
  const TogglePinEvent(this.conversationId, this.messageId);
  @override
  List<Object?> get props => [conversationId, messageId];
}

class ForwardMessagesEvent extends ChatEvent {
  final List<ChatMessage> sources;
  final List<String> targetConversationIds;
  const ForwardMessagesEvent(this.sources, this.targetConversationIds);
  @override
  List<Object?> get props =>
      [sources.map((m) => m.id).toList(), targetConversationIds];
}

class UpdateWsConnectionStateEvent extends ChatEvent {
  final bool isConnected;
  const UpdateWsConnectionStateEvent(this.isConnected);
  @override
  List<Object?> get props => [isConnected];
}

class ReceivedWsEvent extends ChatEvent {
  final ChatWebSocketEvent event;
  const ReceivedWsEvent(this.event);
  @override
  List<Object?> get props => [event];
}

class SendTypingStateEvent extends ChatEvent {
  final String conversationId;
  final bool isTyping;
  const SendTypingStateEvent(this.conversationId, this.isTyping);
  @override
  List<Object?> get props => [conversationId, isTyping];
}

class SwitchUserEvent extends ChatEvent {
  final String userId;
  const SwitchUserEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Tên hiển thị của máy vừa đổi (đăng nhập / đăng xuất / điểm danh).
///
/// KHÔNG đổi khoá định danh — chỉ nạp lại danh bạ để giao diện hiện tên mới.
class RefreshIdentityEvent extends ChatEvent {
  const RefreshIdentityEvent();
  @override
  List<Object?> get props => const [];
}

/// Track 3: Send an E2EE-encrypted message to all recipient devices
class SendEncryptedMessageEvent extends ChatEvent {
  final String conversationId;
  final String text;
  const SendEncryptedMessageEvent({
    required this.conversationId,
    required this.text,
  });
  @override
  List<Object?> get props => [conversationId, text];
}

/// Track 3: Process encrypted messages pulled from the server
class PullEncryptedMessagesEvent extends ChatEvent {}

class RefreshPresenceEvent extends ChatEvent {}

class PickAttachmentsEvent extends ChatEvent {
  final List<AttachmentFile> files;
  const PickAttachmentsEvent(this.files);
  @override
  List<Object?> get props => [files];
}

class RemoveAttachmentEvent extends ChatEvent {
  final String fileId;
  const RemoveAttachmentEvent(this.fileId);
  @override
  List<Object?> get props => [fileId];
}

class UploadProgressTickEvent extends ChatEvent {
  final String messageId;
  final String fileId;
  final double progress;
  const UploadProgressTickEvent(this.messageId, this.fileId, this.progress);
  @override
  List<Object?> get props => [messageId, fileId, progress];
}

class SendMessageWithAttachmentsEvent extends ChatEvent {
  final String conversationId;
  final String text;
  const SendMessageWithAttachmentsEvent({
    required this.conversationId,
    required this.text,
  });
  @override
  List<Object?> get props => [conversationId, text];
}

class RetryUploadAttachmentEvent extends ChatEvent {
  final ChatMessage message;
  const RetryUploadAttachmentEvent(this.message);
  @override
  List<Object?> get props => [message];
}

// --- States ---
class ChatState extends Equatable {
  final List<ChatConversation> conversations;
  final List<User> contacts;
  final List<ChatMessage> activeMessages;
  final String? activeConversationId;
  /// Khoá định danh của máy này — LUÔN là `device_id`, không đổi khi đăng nhập.
  final String? currentUserId;

  /// Tên hiển thị của máy này: tên người đang đăng nhập nếu có, không thì tên
  /// máy. Tách khỏi [currentUserId] vì tên thay đổi còn khoá định tuyến thì
  /// không được phép đổi.
  final String myDisplayName;

  final Map<String, ChatPresenceState> userPresenceMap;
  final Map<String, List<String>>
      typingUsersMap; // Map<ConversationId, List<UserId>>
  final bool isLoading;
  final bool isWsConnected;
  final String? error;
  final List<AttachmentFile> draftAttachments;
  final Map<String, double> uploadProgressMap;
  /// Còn tin cũ hơn trong DB local chưa nạp lên màn hình.
  final bool hasMoreHistory;
  final bool isLoadingOlder;

  /// Cảm xúc theo id tin, cho các tin đang hiển thị.
  final Map<String, List<ChatReaction>> reactionsMap;

  /// Tin được ghim của hội thoại đang mở, mới ghim trước.
  final List<ChatMessage> pinnedMessages;

  /// Id tin/sự kiện còn nằm trong hàng đợi E2EE (chưa tới server) — UI hiện
  /// đồng hồ thay vì dấu tích.
  final Set<String> pendingSendIds;

  const ChatState({
    this.conversations = const [],
    this.contacts = const [],
    this.activeMessages = const [],
    this.activeConversationId,
    this.currentUserId,
    this.myDisplayName = '',
    this.userPresenceMap = const {},
    this.typingUsersMap = const {},
    this.isLoading = false,
    this.isWsConnected = false,
    this.error,
    this.draftAttachments = const [],
    this.uploadProgressMap = const {},
    this.hasMoreHistory = false,
    this.isLoadingOlder = false,
    this.reactionsMap = const {},
    this.pinnedMessages = const [],
    this.pendingSendIds = const {},
  });

  ChatState copyWith({
    List<ChatConversation>? conversations,
    List<User>? contacts,
    List<ChatMessage>? activeMessages,
    String? activeConversationId,
    String? currentUserId,
    String? myDisplayName,
    Map<String, ChatPresenceState>? userPresenceMap,
    Map<String, List<String>>? typingUsersMap,
    bool? isLoading,
    bool? isWsConnected,
    String? error,
    List<AttachmentFile>? draftAttachments,
    Map<String, double>? uploadProgressMap,
    bool? hasMoreHistory,
    bool? isLoadingOlder,
    Map<String, List<ChatReaction>>? reactionsMap,
    List<ChatMessage>? pinnedMessages,
    Set<String>? pendingSendIds,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      contacts: contacts ?? this.contacts,
      activeMessages: activeMessages ?? this.activeMessages,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      currentUserId: currentUserId ?? this.currentUserId,
      myDisplayName: myDisplayName ?? this.myDisplayName,
      userPresenceMap: userPresenceMap ?? this.userPresenceMap,
      typingUsersMap: typingUsersMap ?? this.typingUsersMap,
      isLoading: isLoading ?? this.isLoading,
      isWsConnected: isWsConnected ?? this.isWsConnected,
      error: error,
      draftAttachments: draftAttachments ?? this.draftAttachments,
      uploadProgressMap: uploadProgressMap ?? this.uploadProgressMap,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      reactionsMap: reactionsMap ?? this.reactionsMap,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      pendingSendIds: pendingSendIds ?? this.pendingSendIds,
    );
  }

  @override
  List<Object?> get props => [
        conversations,
        contacts,
        activeMessages,
        activeConversationId,
        currentUserId,
        myDisplayName,
        userPresenceMap,
        typingUsersMap,
        isLoading,
        isWsConnected,
        error,
        draftAttachments,
        uploadProgressMap,
        hasMoreHistory,
        isLoadingOlder,
        reactionsMap,
        pinnedMessages,
        pendingSendIds,
      ];
}

// --- BLoC ---
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  final ChatWebSocketService _wsService;
  final DirectE2eeChannel _e2ee;
  final AppDatabase _db = AppDatabase();
  StreamSubscription? _wsEventSubscription;
  StreamSubscription? _wsConnSubscription;
  StreamSubscription? _bleMessageSubscription;
  StreamSubscription? _syncSubscription;
  Timer? _pullTimer;

  /// Đang có một vòng kéo tin chạy dở. Xem chú thích trong
  /// [_onPullEncryptedMessages] — không có cờ này thì các vòng poll chồng lên
  /// nhau và cùng xử lý một hàng đợi.
  bool _isPullingMessages = false;
  String? _currentUserId;
  final Map<String, DateTime> _presenceLastSeen = {};

  String? get currentUserId => _currentUserId;
  ChatRepository get chatRepository => _chatRepository;
  AppDatabase get db => _db;

  ChatBloc({
    ChatRepository? chatRepository,
    ChatWebSocketService? wsService,
    DirectE2eeChannel? e2eeChannel,
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _wsService = wsService ?? ChatWebSocketService(),
        _e2ee = e2eeChannel ??
            DirectE2eeChannel(repo: chatRepository ?? ChatRepository()),
        super(const ChatState()) {
    on<LoadConversationsEvent>(_onLoadConversations);
    on<LoadContactsEvent>(_onLoadContacts);
    on<OpenConversationEvent>(_onOpenConversation);
    on<LoadOlderMessagesEvent>(_onLoadOlderMessages);
    on<OpenDirectChatWithUserEvent>(_onOpenDirectChatWithUser);
    on<SendMessageEvent>(_onSendMessage);
    on<UpdateWsConnectionStateEvent>(_onUpdateWsConnectionState);
    on<ReceivedWsEvent>(_onReceivedWs);
    on<SendTypingStateEvent>(_onSendTypingState);
    on<SwitchUserEvent>(_onSwitchUser);
    on<RefreshIdentityEvent>(_onRefreshIdentity);
    on<SendEncryptedMessageEvent>(_onSendEncryptedMessage);
    on<PullEncryptedMessagesEvent>((event, emit) async {
      await _onPullEncryptedMessages(event, emit);
      // Mỗi nhịp kéo tin cũng là dịp gửi bù những gì còn kẹt trong hàng đợi.
      await _flushOutbox(emit);
    });
    on<FlushE2eeOutboxEvent>((event, emit) => _flushOutbox(emit));
    on<SendEnvelopeEvent>((event, emit) => _sendEnvelope(event.envelope, emit));
    on<EditMessageEvent>(_onEditMessage);
    on<RevokeMessageEvent>(_onRevokeMessage);
    on<ToggleReactionEvent>(_onToggleReaction);
    on<TogglePinEvent>(_onTogglePin);
    on<ForwardMessagesEvent>(_onForwardMessages);
    on<RefreshPresenceEvent>(_onRefreshPresence);
    on<PickAttachmentsEvent>(_onPickAttachments);
    on<RemoveAttachmentEvent>(_onRemoveAttachment);
    on<UploadProgressTickEvent>(_onUploadProgressTick);
    on<SendMessageWithAttachmentsEvent>(_onSendMessageWithAttachments);
    on<RetryUploadAttachmentEvent>(_onRetryUploadAttachment);

    _init();
  }

  Future<void> _init() async {
    try {
      // Dọn tài khoản demo TRƯỚC khi làm bất cứ việc gì khác. Chúng dùng chung
      // không gian định danh với nhân viên thật nên gây lẫn danh bạ, và từng
      // bị dùng làm khoá định tuyến Chat/Call gây lệch với device_id.
      await _chatRepository.purgeDemoAccounts();

      // Danh tính của máy này = device_id, và KHÔNG BAO GIỜ đổi.
      //
      // Đây là khoá định tuyến của cả Chat lẫn Call: `/call/ws/{id}`,
      // `target_id` trong gói tín hiệu, và khoá lưu device token đều dùng giá
      // trị này. Đăng nhập chỉ đổi TÊN HIỂN THỊ, không đổi id — đổi id giữa
      // chừng là nguyên nhân của lỗi "gọi được đi nhưng không ai nhận được".
      final deviceUserId = await DeviceUserService().ensureLocalUser();
      if (deviceUserId != null) {
        add(SwitchUserEvent(deviceUserId));
      } else {
        // Chưa lấy được danh tính thiết bị (hiếm — chỉ khi secure storage lỗi).
        // Không bịa user demo: để trống còn hơn gửi tin dưới danh tính giả.
        print('[Chat] Chưa có danh tính thiết bị — Chat/Call tạm thời chưa sẵn sàng.');
      }
    } catch (e) {
      print('[Chat] Lỗi khởi tạo danh tính: $e');
    }

    // Listen to connection state
    _wsConnSubscription = _wsService.connectionStateStream.listen((connected) {
      add(UpdateWsConnectionStateEvent(connected));
    });

    // Listen to events
    _wsEventSubscription = _wsService.eventStream.listen((event) {
      add(ReceivedWsEvent(event));
    });

    // Listen to BLE P2P messages
    _bleMessageSubscription =
        BleDeviceDiscoveryService().messageReceivedStream.listen((packet) {
      if (packet.messageType == BleMessageType.message) {
        try {
          final jsonStr = utf8.decode(packet.payload);
          final chatMsgMap = jsonDecode(jsonStr) as Map<String, dynamic>;
          add(ReceivedWsEvent(ChatWebSocketEvent(
            event: 'message_received',
            data: {
              'message_id': chatMsgMap['id'],
              'conversation_id': chatMsgMap['conversation_id'],
              'sender_id': chatMsgMap['sender_id'],
              'type': chatMsgMap['type'],
              'content': chatMsgMap['content'] is String
                  ? jsonDecode(chatMsgMap['content'])
                  : chatMsgMap['content'],
              'sent_at': chatMsgMap['sent_at'],
            },
          )));
        } catch (e) {
          print('[ChatBloc] Error processing BLE message: $e');
        }
      }
    });

    // Listen to SyncService events to refresh conversations & messages when pulled from server
    _syncSubscription?.cancel();
    _syncSubscription = SyncService().syncEventStream.listen((syncEvent) {
      final hasChat = syncEvent.tables.any((t) => t.startsWith('chat_'));
      if (hasChat) {
        add(LoadConversationsEvent());
        final activeId = state.activeConversationId;
        if (activeId != null) {
          add(OpenConversationEvent(activeId));
        }
      }
    });

    // Adaptive periodic polling for E2EE messages, HTTP Sync and Presence
    int pollTick = 0;
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      pollTick++;
      final isWsConnected = _wsService.isConnected;

      // Khi WebSocket đang kết nối ổn định:
      // Real-time events đã được server broadcast qua WS tức thời (< 50ms).
      // Chỉ cần chạy polling bảo hiểm mỗi 30 giây (mỗi 6 chu kỳ) để giảm 85% tải cho server và tunnel.
      if (isWsConnected) {
        if (pollTick % 6 == 0) {
          add(PullEncryptedMessagesEvent());
          add(RefreshPresenceEvent());
          SyncService().triggerSync();
        }
      } else {
        // Fallback khi mất kết nối WebSocket: giữ chu kỳ 5 giây
        add(PullEncryptedMessagesEvent());
        add(RefreshPresenceEvent());
        SyncService().triggerSync();
      }
    });
  }

  Future<void> _onLoadConversations(
    LoadConversationsEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentUserId == null) return;

    // Chỉ hiện trạng thái loading nếu danh sách hội thoại ban đầu hoàn toàn rỗng
    if (state.conversations.isEmpty) {
      emit(state.copyWith(isLoading: true));
    }
    try {
      final conversations =
          await _chatRepository.getConversations(_currentUserId!);
      emit(state.copyWith(conversations: conversations, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onLoadContacts(
    LoadContactsEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentUserId == null) return;

    if (state.contacts.isEmpty) {
      emit(state.copyWith(isLoading: true));
    }
    try {
      final contacts =
          await _chatRepository.getReachableContacts(_currentUserId!);
      emit(state.copyWith(contacts: contacts, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onOpenConversation(
    OpenConversationEvent event,
    Emitter<ChatState> emit,
  ) async {
    final isDifferentConvo = state.activeConversationId != event.conversationId;
    // Chỉ bật spinner loading khi chuyển sang hội thoại mới chưa có tin nhắn
    if (isDifferentConvo && state.activeMessages.isEmpty) {
      emit(state.copyWith(
          isLoading: true, activeConversationId: event.conversationId));
    } else if (isDifferentConvo) {
      // Chuyển hội thoại: bỏ cảm xúc/ghim của hội thoại trước.
      emit(state.copyWith(
          activeConversationId: event.conversationId,
          reactionsMap: const {},
          pinnedMessages: const []));
    } else {
      emit(state.copyWith(activeConversationId: event.conversationId));
    }
    try {
      // OpenConversationEvent còn được bắn lại sau xoá/tải tệp. Giữ nguyên số
      // tin đang hiển thị, nếu không người dùng đang xem tin cũ sẽ bị cắt về
      // trang cuối.
      final limit = isDifferentConvo
          ? ChatRepository.messagePageSize
          : (state.activeMessages.length > ChatRepository.messagePageSize
              ? state.activeMessages.length
              : ChatRepository.messagePageSize);
      final messages = await _chatRepository.getMessages(event.conversationId,
          limit: limit);
      emit(state.copyWith(
        activeMessages: messages,
        isLoading: false,
        hasMoreHistory: messages.length >= limit,
      ));
      await _refreshExtras(emit);

      // Update read receipts
      if (_currentUserId != null && messages.isNotEmpty) {
        final lastMsg = messages.last;
        if (lastMsg.senderId != _currentUserId && lastMsg.readAt == null) {
          _wsService.sendEvent(ChatWebSocketEvent(
            event: 'msg_read',
            data: {
              'message_id': lastMsg.id,
              'conversation_id': event.conversationId,
              'read_at': DateTime.now().toIso8601String(),
            },
          ));
          await _chatRepository.updateMessageStatus(lastMsg.id,
              readAt: DateTime.now());
        }
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onLoadOlderMessages(
    LoadOlderMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state.activeConversationId != event.conversationId ||
        state.isLoadingOlder ||
        !state.hasMoreHistory ||
        state.activeMessages.isEmpty) {
      return;
    }
    emit(state.copyWith(isLoadingOlder: true));
    try {
      final older = await _chatRepository.getMessages(event.conversationId,
          before: state.activeMessages.first);
      // Người dùng có thể đã chuyển hội thoại trong lúc chờ DB.
      if (state.activeConversationId != event.conversationId) {
        emit(state.copyWith(isLoadingOlder: false));
        return;
      }
      emit(state.copyWith(
        activeMessages: [...older, ...state.activeMessages],
        hasMoreHistory: older.length >= ChatRepository.messagePageSize,
        isLoadingOlder: false,
      ));
      await _refreshExtras(emit);
    } catch (e) {
      emit(state.copyWith(isLoadingOlder: false, error: e.toString()));
    }
  }

  Future<void> _onOpenDirectChatWithUser(
    OpenDirectChatWithUserEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentUserId == null) return;
    emit(state.copyWith(isLoading: true));
    try {
      final convo = await _chatRepository.getOrCreateDirectConversation(
        _currentUserId!,
        event.otherUserId,
      );
      add(OpenConversationEvent(convo.id));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentUserId == null) return;

    final messageId = const Uuid().v4();
    final now = DateTime.now();

    final contentMap = <String, dynamic>{'text': event.text};
    if (event.extraContent != null) {
      contentMap.addAll(event.extraContent!);
    }

    final chatMsg = ChatMessage(
      id: messageId,
      conversationId: event.conversationId,
      senderId: _currentUserId!,
      type: event.type.name,
      content: jsonEncode(contentMap),
      sentAt: now,
      isDeleted: false,
      replyToId: event.replyToId,
      forwardedFromId: event.forwardedFromId,
    );

    // 1. Optimistic UI: Hiển thị ngay tức thì trên màn hình người gửi (< 1ms)
    if (state.activeConversationId == event.conversationId) {
      final updatedList = List<ChatMessage>.from(state.activeMessages)
        ..add(chatMsg);
      emit(state.copyWith(activeMessages: updatedList));
    }

    // Tin 1-1 CHỈ đi bằng E2EE: lưu cục bộ rồi xếp vào hàng đợi mã hoá. Không
    // WebSocket plaintext, không outbox đồng bộ. Gửi chưa được thì nằm chờ,
    // không bao giờ rơi về plaintext.
    if (DirectE2eeChannel.isDirect(event.conversationId)) {
      await _chatRepository.saveMessage(chatMsg);
      await _sendEnvelope(
        ChatEnvelope.message(
          id: messageId,
          conversationId: event.conversationId,
          type: event.type.name,
          content: contentMap,
          ts: now,
          replyToId: event.replyToId,
          forwardedFromId: event.forwardedFromId,
        ),
        emit,
      );
      // Cùng phòng với đối tác qua BLE (không có mạng): gửi thẳng, bản E2EE
      // vẫn nằm trong hàng đợi và bị khử trùng lặp theo id ở máy nhận.
      if (!_wsService.isConnected) {
        unawaited(_sendViaBleIfNearby(
            messageId, event.conversationId, event.type.name, contentMap, now));
      }
      add(LoadConversationsEvent());
      return;
    }

    // 2. Realtime WebSocket: Bắn ngay gói tin qua WebSocket ở mili-giây đầu tiên (< 30ms tới người nhận)
    if (_wsService.isConnected) {
      _wsService.sendEvent(ChatWebSocketEvent(
        event: 'send_message',
        data: {
          'message_id': messageId,
          'conversation_id': event.conversationId,
          'sender_id': _currentUserId,
          'type': event.type.name,
          'content': contentMap,
          'sent_at': now.toIso8601String(),
          if (event.replyToId != null) 'reply_to_id': event.replyToId,
          if (event.forwardedFromId != null)
            'forwarded_from_id': event.forwardedFromId,
        },
      ));
    } else {
      // Offline fallback: Kiểm tra nếu thiết bị đối phương có kết nối BLE P2P lân cận
      unawaited(_sendViaBleIfNearby(
          messageId, event.conversationId, event.type.name, contentMap, now));
    }

    // 3. Zero-Loss Guarantee: Lưu SQLite cục bộ và xếp hàng Outbox ngầm (không chặn UI chat)
    unawaited(() async {
      try {
        await _chatRepository.saveMessage(chatMsg);
        await _chatRepository.queueMessageOffline(chatMsg);
        // Đẩy nhanh Outbox lên PostgreSQL mà không kích hoạt Full Database Sync
        SyncService().debounceFlushOutbox();
      } catch (e) {
        print('[ChatBloc] Error persisting message: $e');
      }
    }());

    // Cập nhật preview tóm tắt cuộc hội thoại ngoài danh sách chat
    add(LoadConversationsEvent());
  }

  /// Gửi qua BLE P2P nếu đối tác đang ở gần. BLE có lớp mã hoá phiên riêng
  /// (ble_p2p_handshake_service), khác với kênh server.
  Future<void> _sendViaBleIfNearby(String messageId, String conversationId,
      String type, Map<String, dynamic> contentMap, DateTime sentAt) async {
    try {
      final companion =
          await _chatRepository.getCompanion(conversationId, _currentUserId!);
      final bleDiscovery = BleDeviceDiscoveryService();
      final companionId = companion?.id;
      final bleDeviceId = companionId != null
          ? bleDiscovery.getConnectedDeviceIdForUser(companionId)
          : null;
      if (bleDeviceId == null) return;

      print(
          '[ChatBloc] Companion is connected via BLE P2P. Sending message directly...');
      final payloadBytes = utf8.encode(jsonEncode({
        'id': messageId,
        'conversation_id': conversationId,
        'sender_id': _currentUserId!,
        'type': type,
        'content': contentMap,
        'sent_at': sentAt.toIso8601String(),
      }));
      final packet = BleMeshPacket(
        messageId: messageId,
        senderDeviceId: 'local-device',
        recipientDeviceId: bleDeviceId,
        payload: payloadBytes,
        ttl: 1,
        messageType: BleMessageType.message,
      );
      await bleDiscovery.sendPacket(bleDeviceId, packet);
    } catch (e) {
      print('[ChatBloc] BLE fallback error: $e');
    }
  }

  /// Xếp phong bì vào hàng đợi E2EE rồi thử gửi ngay. Trạng thái "đang chờ"
  /// được phát TRƯỚC khi gửi để UI hiện đồng hồ ngay lập tức.
  Future<void> _sendEnvelope(ChatEnvelope envelope, Emitter<ChatState> emit) async {
    final me = _currentUserId;
    if (me == null) return;
    await _chatRepository.enqueueE2ee(envelope);
    emit(state.copyWith(
        pendingSendIds: await _chatRepository.pendingE2eeIds()));
    await _e2ee.flush(myId: me);
    emit(state.copyWith(
        pendingSendIds: await _chatRepository.pendingE2eeIds()));
  }

  Future<void> _flushOutbox(Emitter<ChatState> emit) async {
    final me = _currentUserId;
    if (me == null) return;
    await _e2ee.flush(myId: me);
    emit(state.copyWith(
        pendingSendIds: await _chatRepository.pendingE2eeIds()));
  }

  /// Nạp cảm xúc, tin ghim và trạng thái chờ cho hội thoại đang mở.
  Future<void> _refreshExtras(Emitter<ChatState> emit) async {
    final convoId = state.activeConversationId;
    if (convoId == null) return;
    final reactions = await _chatRepository
        .getReactionsFor(state.activeMessages.map((m) => m.id));
    final pinned = await _chatRepository.getPinnedMessages(convoId);
    final pending = await _chatRepository.pendingE2eeIds();
    if (state.activeConversationId != convoId) return;
    emit(state.copyWith(
        reactionsMap: reactions, pinnedMessages: pinned, pendingSendIds: pending));
  }

  /// Nạp lại hội thoại đang mở sau khi có sửa/thu hồi/cảm xúc/ghim, giữ nguyên
  /// số tin đang hiển thị (người dùng có thể đã cuộn lên xem tin cũ).
  Future<void> _reloadActive(Emitter<ChatState> emit) async {
    final convoId = state.activeConversationId;
    if (convoId == null) return;
    final keep = state.activeMessages.length > ChatRepository.messagePageSize
        ? state.activeMessages.length
        : ChatRepository.messagePageSize;
    final messages = await _chatRepository.getMessages(convoId, limit: keep);
    if (state.activeConversationId != convoId) return;
    emit(state.copyWith(activeMessages: messages));
    await _refreshExtras(emit);
  }

  Future<void> _onEditMessage(
      EditMessageEvent event, Emitter<ChatState> emit) async {
    final me = _currentUserId;
    final text = event.newText.trim();
    if (me == null || text.isEmpty) return;
    final msg = await _chatRepository.getMessageById(event.messageId);
    if (msg == null ||
        msg.senderId != me ||
        msg.isDeleted ||
        !DirectE2eeChannel.isDirect(msg.conversationId)) {
      return;
    }
    final env = ChatEnvelope.edit(
      id: const Uuid().v4(),
      conversationId: msg.conversationId,
      targetId: msg.id,
      newText: text,
      ts: DateTime.now(),
    );
    await _chatRepository.applyEnvelope(env, senderId: me);
    await _reloadActive(emit);
    await _sendEnvelope(env, emit);
    add(LoadConversationsEvent());
  }

  Future<void> _onRevokeMessage(
      RevokeMessageEvent event, Emitter<ChatState> emit) async {
    final me = _currentUserId;
    if (me == null) return;
    final msg = await _chatRepository.getMessageById(event.messageId);
    if (msg == null) return;

    final everyone = event.forEveryone &&
        msg.senderId == me &&
        DirectE2eeChannel.isDirect(msg.conversationId);
    if (everyone) {
      final env = ChatEnvelope.revoke(
        id: const Uuid().v4(),
        conversationId: msg.conversationId,
        targetId: msg.id,
        ts: DateTime.now(),
      );
      await _chatRepository.applyEnvelope(env, senderId: me);
      await _reloadActive(emit);
      await _sendEnvelope(env, emit);
    } else {
      // Chỉ xoá trên máy này.
      await _chatRepository.deleteMessage(msg.id);
      await _reloadActive(emit);
    }
    add(LoadConversationsEvent());
  }

  Future<void> _onToggleReaction(
      ToggleReactionEvent event, Emitter<ChatState> emit) async {
    final me = _currentUserId;
    if (me == null || !DirectE2eeChannel.isDirect(event.conversationId)) return;
    final mine = (state.reactionsMap[event.messageId] ?? const [])
        .where((r) => r.userId == me)
        .map((r) => r.emoji)
        .firstOrNull;
    final env = ChatEnvelope.reaction(
      id: const Uuid().v4(),
      conversationId: event.conversationId,
      targetId: event.messageId,
      // Bấm lại đúng cảm xúc đang có = gỡ.
      emoji: mine == event.emoji ? '' : event.emoji,
      ts: DateTime.now(),
    );
    await _chatRepository.applyEnvelope(env, senderId: me);
    await _refreshExtras(emit);
    await _sendEnvelope(env, emit);
  }

  Future<void> _onTogglePin(
      TogglePinEvent event, Emitter<ChatState> emit) async {
    final me = _currentUserId;
    if (me == null || !DirectE2eeChannel.isDirect(event.conversationId)) return;
    final msg = await _chatRepository.getMessageById(event.messageId);
    if (msg == null || msg.isDeleted) return;
    final env = ChatEnvelope.pin(
      id: const Uuid().v4(),
      conversationId: event.conversationId,
      targetId: msg.id,
      pinned: msg.pinnedAt == null,
      ts: DateTime.now(),
    );
    await _chatRepository.applyEnvelope(env, senderId: me);
    await _reloadActive(emit);
    await _sendEnvelope(env, emit);
  }

  Future<void> _onForwardMessages(
      ForwardMessagesEvent event, Emitter<ChatState> emit) async {
    if (_currentUserId == null) return;
    for (final src in event.sources) {
      if (src.isDeleted) continue;
      final content = Map<String, dynamic>.from(
          (jsonDecode(src.content) as Map?) ?? const {});
      final text = (content.remove('text') ?? '').toString();
      // Tên người gửi gốc đi cùng tin: máy nhận có thể không có tin gốc.
      content['forwarded_from'] = await _displayNameOf(src.senderId);
      final type = ChatMessageType.values.firstWhere(
          (t) => t.name == src.type,
          orElse: () => ChatMessageType.text);
      for (final target in event.targetConversationIds) {
        add(SendMessageEvent(
          conversationId: target,
          text: text,
          type: type,
          extraContent: content,
          forwardedFromId: src.id,
        ));
      }
    }
  }

  Future<String> _displayNameOf(String userId) async {
    if (userId == _currentUserId && state.myDisplayName.isNotEmpty) {
      return state.myDisplayName;
    }
    final u = await (_db.select(_db.users)..where((t) => t.id.equals(userId)))
        .getSingleOrNull();
    return u?.name ?? userId;
  }

  void _onUpdateWsConnectionState(
    UpdateWsConnectionStateEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(isWsConnected: event.isConnected));

    // Broadcast our presence to other connected users
    if (event.isConnected && _currentUserId != null) {
      _wsService.sendEvent(ChatWebSocketEvent(
        event: 'presence_update',
        data: {
          'user_id': _currentUserId,
          'presence': 'online_synced',
        },
      ));

      // Kênh chat sống lại thì kênh gọi cũng phải sống lại. Nếu bỏ qua bước
      // này, máy vẫn chat được nhưng không nhận được cuộc gọi nào — đúng triệu
      // chứng đã gặp trước đây.
      IncomingCallService().ensureConnected(_currentUserId!);
    }
  }

  Future<void> _onReceivedWs(
    ReceivedWsEvent event,
    Emitter<ChatState> emit,
  ) async {
    final wsEvent = event.event;
    final data = wsEvent.data;

    // Server mới chỉ giao gói hội thoại cho thành viên, nhưng server cũ, hội
    // thoại chưa đăng ký và gói BLE vẫn có thể phát rộng. Không phải thành
    // viên thì bỏ qua — không lưu tin, không cho người ngoài đánh dấu đã đọc.
    final scopedConvoId = data['conversation_id']?.toString() ?? '';
    if (scopedConvoId.isNotEmpty &&
        _currentUserId != null &&
        !await _chatRepository.isLocalMember(scopedConvoId, _currentUserId!)) {
      return;
    }

    switch (wsEvent.event) {
      case 'sync_trigger':
        print('[ChatWS] Sync trigger received from WebSocket. Pulling updates (debounced)...');
        SyncService().debounceSync();
        break;

      case 'event_reaction':
        print('[ChatWS] Real-time event reaction received: ${wsEvent.data}');
        try {
          final domainEvent = AppDomainEvent.fromMap(data);
          AppEventBus().emit(domainEvent);
        } catch (e) {
          print('[ChatWS] Error parsing event_reaction: $e');
        }
        break;

      case 'call_invite':
        print('[ChatWS] Real-time call_invite received via WebSocket: $data');
        try {
          final domainEvent = AppDomainEvent(
            eventId: 'call_invite_${DateTime.now().millisecondsSinceEpoch}',
            eventType: 'communication.call_invite',
            originTable: 'calls',
            data: data,
            timestamp: DateTime.now().toIso8601String(),
          );
          AppEventBus().emit(domainEvent);
        } catch (e) {
          print('[ChatWS] Error handling call_invite: $e');
        }
        break;

      case 'send_message':
      case 'message_received':
        final msgId = (data['message_id'] ?? '').toString();
        final convoId = (data['conversation_id'] ?? '').toString();
        final senderId = (data['sender_id'] ?? '').toString();
        // Tin 1-1 chỉ nhận qua E2EE. Gói plaintext 'send_message' cho hội thoại
        // 1-1 đến từ bản app cũ hoặc kẻ giả mạo — bỏ. ('message_received' là
        // đường BLE P2P, có mã hoá phiên riêng, nên vẫn nhận.)
        if (wsEvent.event == 'send_message' &&
            DirectE2eeChannel.isDirect(convoId)) {
          print('[ChatWS] Bỏ tin plaintext vào hội thoại 1-1 $convoId.');
          break;
        }
        final type = (data['type'] ?? 'text').toString();
        final content = data['content'] is Map<String, dynamic>
            ? data['content'] as Map<String, dynamic>
            : (data['content'] is Map
                ? Map<String, dynamic>.from(data['content'] as Map)
                : {'text': data['content']?.toString() ?? ''});
        final sentAt = data['sent_at'] != null
            ? DateTime.tryParse(data['sent_at'].toString()) ?? DateTime.now()
            : DateTime.now();

        // Bỏ qua tin nhắn do chính máy này gửi phát lại qua broadcast
        if (senderId.isNotEmpty && senderId == _currentUserId) {
          break;
        }

        final chatMsg = ChatMessage(
          id: msgId,
          conversationId: convoId,
          senderId: senderId,
          type: type,
          content: jsonEncode(content),
          sentAt: sentAt,
          deliveredAt: DateTime.now(),
          isDeleted: false,
          replyToId: data['reply_to_id']?.toString(),
          forwardedFromId: data['forwarded_from_id']?.toString(),
        );

        await _chatRepository.saveMessage(chatMsg);

        // Notify server that it's delivered
        if (senderId != _currentUserId) {
          _wsService.sendEvent(ChatWebSocketEvent(
            event: 'msg_delivered',
            data: {
              'message_id': msgId,
              'conversation_id': convoId,
              'delivered_at': DateTime.now().toIso8601String(),
            },
          ));
        }

        // Add to active message stream if currently open
        if (state.activeConversationId == convoId) {
          final updatedList = List<ChatMessage>.from(state.activeMessages)
            ..add(chatMsg);
          emit(state.copyWith(activeMessages: updatedList));

          // Mark read automatically since user has it open
          if (senderId != _currentUserId) {
            _wsService.sendEvent(ChatWebSocketEvent(
              event: 'msg_read',
              data: {
                'message_id': msgId,
                'conversation_id': convoId,
                'read_at': DateTime.now().toIso8601String(),
              },
            ));
            await _chatRepository.updateMessageStatus(msgId,
                readAt: DateTime.now());
          }
        }
        add(LoadConversationsEvent());
        break;

      case 'msg_delivered':
        final msgId = data['message_id'] as String;
        final deliveredAt = DateTime.parse(data['delivered_at'] as String);
        await _chatRepository.updateMessageStatus(msgId,
            deliveredAt: deliveredAt);
        _updateActiveMessageStatus(msgId, deliveredAt: deliveredAt, emit: emit);
        break;

      case 'msg_read':
        final msgId = data['message_id'] as String;
        final readAt = DateTime.parse(data['read_at'] as String);
        await _chatRepository.updateMessageStatus(msgId, readAt: readAt);
        _updateActiveMessageStatus(msgId, readAt: readAt, emit: emit);
        break;

      case 'presence_update':
        final userId = data['user_id'] as String;
        final presenceStr = data['presence'] as String;
        final presence = ChatPresenceStateExtension.fromString(presenceStr);

        if (presence == ChatPresenceState.onlineSynced) {
          _presenceLastSeen[userId] = DateTime.now();
        }
        final updatedPresenceMap =
            Map<String, ChatPresenceState>.from(state.userPresenceMap)
              ..[userId] = presence;
        _logPresence('presence_update', userId, presence, updatedPresenceMap);
        emit(state.copyWith(userPresenceMap: updatedPresenceMap));
        break;

      case 'typing_state':
        final convoId = data['conversation_id'] as String;
        final userId = data['user_id'] as String;
        final isTyping = data['is_typing'] as bool;

        final currentTyping =
            List<String>.from(state.typingUsersMap[convoId] ?? []);
        if (isTyping) {
          if (!currentTyping.contains(userId)) {
            currentTyping.add(userId);
          }
        } else {
          currentTyping.remove(userId);
        }

        final updatedTypingMap =
            Map<String, List<String>>.from(state.typingUsersMap)
              ..[convoId] = currentTyping;
        emit(state.copyWith(typingUsersMap: updatedTypingMap));
        break;

      case 'e2ee_message':
        // A new encrypted message is available — pull immediately
        add(PullEncryptedMessagesEvent());
        break;

      case 'heartbeat':
        // Treat heartbeats from other users as presence online
        final hbUserId = data['user_id'] as String?;
        if (hbUserId != null && hbUserId != _currentUserId) {
          _presenceLastSeen[hbUserId] = DateTime.now();
          final updatedMap =
              Map<String, ChatPresenceState>.from(state.userPresenceMap)
                ..[hbUserId] = ChatPresenceState.onlineSynced;
          _logPresence('heartbeat', hbUserId,
              ChatPresenceState.onlineSynced, updatedMap);
          emit(state.copyWith(userPresenceMap: updatedMap));
        } else if (kLogPresence && hbUserId == _currentUserId) {
          // Nhịp tim của CHÍNH MÌNH vọng về — bình thường, nhưng nếu chỉ thấy
          // loại này thì nghĩa là máy kia chưa gửi được nhịp tim nào.
          print('[Presence] ↩︎ nhịp tim của chính mình ($hbUserId) — bỏ qua.');
        }
        break;
    }
  }

  void _updateActiveMessageStatus(
    String messageId, {
    DateTime? deliveredAt,
    DateTime? readAt,
    required Emitter<ChatState> emit,
  }) {
    final activeMsgs = List<ChatMessage>.from(state.activeMessages);
    final index = activeMsgs.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final oldMsg = activeMsgs[index];
      // copyWith thay vì dựng lại: dựng lại sẽ làm rơi các cột mới
      // (replyToId, editedAt, forwardedFromId).
      activeMsgs[index] = oldMsg.copyWith(
        deliveredAt: Value(deliveredAt ?? oldMsg.deliveredAt),
        readAt: Value(readAt ?? oldMsg.readAt),
      );
      emit(state.copyWith(activeMessages: activeMsgs));
    }
  }

  void _onSendTypingState(
    SendTypingStateEvent event,
    Emitter<ChatState> emit,
  ) {
    if (_currentUserId == null || !_wsService.isConnected) return;
    _wsService.sendEvent(ChatWebSocketEvent(
      event: 'typing_state',
      data: {
        'conversation_id': event.conversationId,
        'user_id': _currentUserId,
        'is_typing': event.isTyping,
      },
    ));
  }

  /// Tên hiển thị đổi — nạp lại danh bạ, KHÔNG đụng tới khoá định danh.
  Future<void> _onRefreshIdentity(
    RefreshIdentityEvent event,
    Emitter<ChatState> emit,
  ) async {
    final name = await SettingsService().getLoggedInDisplayName();
    emit(state.copyWith(myDisplayName: name));
    add(LoadContactsEvent());
    add(LoadConversationsEvent());
  }

  Future<void> _onSwitchUser(
    SwitchUserEvent event,
    Emitter<ChatState> emit,
  ) async {
    final identity = await DeviceIdentityService().getOrCreateIdentity();
    final effectiveUserId =
        identity.deviceId.isNotEmpty ? identity.deviceId : event.userId;

    await SettingsService().saveActiveUserId(effectiveUserId);
    _currentUserId = effectiveUserId;

    // Re-register device and start heartbeat with the device ID
    try {
      final discoveryService = DeviceDiscoveryService();
      await discoveryService.registerDevice();
      discoveryService.startHeartbeat();
    } catch (_) {}

    _wsService.disconnect();
    _wsService.setUserId(effectiveUserId);
    _wsService.connect();

    // Mở kênh tín hiệu cuộc gọi ngay khi biết mình là ai
    IncomingCallService().switchUser(effectiveUserId);

    final name = await SettingsService().getLoggedInDisplayName();
    emit(state.copyWith(
      currentUserId: effectiveUserId,
      myDisplayName: name,
    ));

    // Trigger reload
    add(LoadConversationsEvent());
    add(LoadContactsEvent());
  }

  @override
  Future<void> close() {
    _pullTimer?.cancel();
    _wsEventSubscription?.cancel();
    _wsConnSubscription?.cancel();
    _bleMessageSubscription?.cancel();
    _syncSubscription?.cancel();
    return super.close();
  }

  // ============================================================
  // Track 3: E2EE Encrypted Messaging
  // ============================================================

  /// Send an E2EE-encrypted message.
  /// 1. Get all recipient devices from server
  /// 2. Encrypt the message separately for each device's public key
  /// 3. Sign with our ED25519 key
  /// 4. Send encrypted envelopes via server relay
  /// 5. Also save plaintext locally for sender's own view
  Future<void> _onSendEncryptedMessage(
    SendEncryptedMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentUserId == null) return;

    try {
      final identityService = DeviceIdentityService();
      final discoveryService = DeviceDiscoveryService();
      final myIdentity = await identityService.getOrCreateIdentity();

      final companion = await _chatRepository.getCompanion(
          event.conversationId, _currentUserId!);
      if (companion == null) {
        add(SendMessageEvent(
          conversationId: event.conversationId,
          text: event.text,
        ));
        return;
      }

      // Get online devices for the companion user (excluding our own)
      final onlineDevices = await discoveryService.getOnlineDevices();
      final recipientDevices = onlineDevices
          .where((d) =>
              d.userId == companion.id && d.deviceId != myIdentity.deviceId)
          .toList();

      if (recipientDevices.isEmpty) {
        // No devices online — fall back to regular outbox sync
        add(SendMessageEvent(
          conversationId: event.conversationId,
          text: event.text,
        ));
        return;
      }

      // Encrypt for each recipient device
      final payloadsPerDevice = <String, EncryptedPayload>{};
      for (final device in recipientDevices) {
        final payload = await identityService.encryptForDevice(
          event.text,
          device,
        );
        payloadsPerDevice[device.deviceId] = payload;
      }

      // Send via server relay
      final sendSuccess = await discoveryService.sendEncryptedMessage(
        conversationId: event.conversationId,
        recipientDeviceIds: recipientDevices.map((d) => d.deviceId).toList(),
        payloadsPerDevice: payloadsPerDevice,
      );

      if (!sendSuccess) {
        print('[E2EE] ❌ HTTP relay failed — falling back to regular send');
        add(SendMessageEvent(
          conversationId: event.conversationId,
          text: event.text,
        ));
        return;
      }

      // Notify receiver via WebSocket to pull immediately
      if (_wsService.isConnected) {
        _wsService.sendEvent(ChatWebSocketEvent(
          event: 'e2ee_message',
          data: {
            'conversation_id': event.conversationId,
            'sender_device_id': myIdentity.deviceId,
          },
        ));
      }

      // Save plaintext locally for sender's own message list
      final messageId = const Uuid().v4();
      final now = DateTime.now();
      final chatMsg = ChatMessage(
        id: messageId,
        conversationId: event.conversationId,
        senderId: _currentUserId!,
        type: 'text',
        content: jsonEncode({'text': event.text}),
        sentAt: now,
        isDeleted: false,
      );
      await _chatRepository.saveMessage(chatMsg);

      if (state.activeConversationId == event.conversationId) {
        final updatedList = List<ChatMessage>.from(state.activeMessages)
          ..add(chatMsg);
        emit(state.copyWith(activeMessages: updatedList));
      }
      add(LoadConversationsEvent());

      print(
          '[E2EE] Sent encrypted message to ${recipientDevices.length} devices');
    } catch (e) {
      print('[E2EE] Error sending encrypted message: $e');
      // Fallback to regular send
      add(SendMessageEvent(
        conversationId: event.conversationId,
        text: event.text,
      ));
    }
  }

  /// Pull and decrypt encrypted messages from the server.
  Future<void> _onPullEncryptedMessages(
    PullEncryptedMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    // Chống chồng lấn: mỗi lô có thể mất vài giây để giải mã, trong khi timer
    // vẫn bắn 5 giây một lần. Không có chốt này thì các vòng poll đè lên nhau,
    // cùng lấy một hàng đợi, cùng ack — log cho thấy "Acknowledged 0/126" vì
    // vòng trước đã ack hết rồi.
    if (_isPullingMessages) return;
    _isPullingMessages = true;

    try {
      final identityService = DeviceIdentityService();
      final discoveryService = DeviceDiscoveryService();
      final myIdentity = await identityService.getOrCreateIdentity();

      // Pull pending messages for this device
      final pendingMessages = await discoveryService.getPendingMessages();

      if (pendingMessages.isEmpty) return;

      final messageIdsToAck = <String>[];
      // Tin giải mã KHÔNG được cũng phải báo về server. Trước đây chỉ `continue`
      // im lặng nên server tưởng chưa giao và gửi lại mãi mãi.
      final messageIdsFailed = <String>[];
      String? firstFailureReason;
      final touchedConvos = <String>{};

      for (final msgMap in pendingMessages) {
        try {
          final msgId = msgMap['id'] as String;
          final conversationId = msgMap['conversation_id'] as String;
          final senderDeviceId = msgMap['sender_device_id'] as String;
          final ciphertextBase64 = msgMap['ciphertext'] as String;
          final nonceBase64 = msgMap['nonce'] as String;
          final signatureBase64 = msgMap['signature'] as String;
          final sentAt = DateTime.parse(msgMap['sent_at'] as String);

          // Get sender's public key
          final senderDevice =
              await discoveryService.getDeviceInfo(senderDeviceId);
          if (senderDevice == null) {
            print('[E2EE] Sender device info not available yet (network timeout or offline): $senderDeviceId');
            // Không đưa vào messageIdsFailed để tránh làm server dead-letter/xoá mất tin.
            // Tin sẽ được giữ trong hàng đợi server và giải mã khi có khoá ở vòng sau.
            continue;
          }

          // Build EncryptedPayload and decrypt
          final encPayload = EncryptedPayload(
            ciphertextBase64: ciphertextBase64,
            nonceBase64: nonceBase64,
            senderDeviceId: senderDeviceId,
            signatureBase64: signatureBase64,
            sentAt: sentAt,
          );

          final senderX25519PubKeyBytes =
              base64Decode(senderDevice.publicKeyBase64);
          final senderEd25519PubKeyBytes =
              base64Decode(senderDevice.signingPublicKeyBase64);
          final plaintext = await identityService.decryptPayload(
            encPayload,
            senderX25519PubKeyBytes,
            senderEd25519PubKeyBytes,
          );

          // Bản mã giải ra được một PHONG BÌ (tin/sửa/thu hồi/cảm xúc/ghim).
          // processIncoming đối chiếu hội thoại + thành viên rồi mới áp vào DB.
          final result = await _e2ee.processIncoming(
            conversationId: conversationId,
            plaintext: plaintext,
            senderIds: {senderDeviceId, senderDevice.userId},
            myIds: {
              if (_currentUserId != null) _currentUserId!,
              myIdentity.deviceId,
            },
            receivedAt: DateTime.now(),
          );
          if (result.isRejected) {
            print('[E2EE] ⛔ Từ chối phong bì từ $senderDeviceId: '
                '${result.rejectReason}');
            messageIdsFailed.add(msgId);
            firstFailureReason ??= result.rejectReason;
            continue;
          }

          messageIdsToAck.add(msgId);
          touchedConvos.add(conversationId);

          final env = result.envelope!;
          if (env.kind == ChatEnvelopeKind.message &&
              result.outcome == EnvelopeOutcome.applied) {
            // Biên nhận chỉ mang id tin (không mang nội dung), đi qua WS và
            // được server định tuyến theo hội thoại.
            _wsService.sendEvent(ChatWebSocketEvent(
              event: 'msg_delivered',
              data: {
                'message_id': env.id,
                'conversation_id': conversationId,
                'delivered_at': DateTime.now().toIso8601String(),
              },
            ));
            if (state.activeConversationId == conversationId) {
              final readAt = DateTime.now();
              await _chatRepository.updateMessageStatus(env.id, readAt: readAt);
              _wsService.sendEvent(ChatWebSocketEvent(
                event: 'msg_read',
                data: {
                  'message_id': env.id,
                  'conversation_id': conversationId,
                  'read_at': readAt.toIso8601String(),
                },
              ));
            }
          }
          print('[E2EE] ${env.kind.name} từ $senderDeviceId '
              '(${result.outcome?.name}) — ${plaintext.length} ký tự');
        } catch (e) {
          print('[E2EE] Error decrypting message: $e');
          // Báo lỗi thay vì nuốt im. Server đếm số lần thất bại và sau 5 lần
          // sẽ chuyển tin sang dead-letter, nhờ vậy một tin hỏng không làm kẹt
          // cả hàng đợi.
          final failedId = msgMap['id'];
          if (failedId is String) {
            messageIdsFailed.add(failedId);
            firstFailureReason ??= e.toString();
          }
        }
      }

      if (state.activeConversationId != null &&
          touchedConvos.contains(state.activeConversationId)) {
        await _reloadActive(emit);
      }

      // Báo kết quả cho server — CẢ tin thành công lẫn tin lỗi.
      if (messageIdsToAck.isNotEmpty || messageIdsFailed.isNotEmpty) {
        await discoveryService.acknowledgeMessages(
          messageIdsToAck,
          failedIds: messageIdsFailed,
          failedReason: firstFailureReason,
        );
        if (messageIdsToAck.isNotEmpty) add(LoadConversationsEvent());
        print('[E2EE] Ack ${messageIdsToAck.length} tin'
            '${messageIdsFailed.isEmpty ? '' : ', lỗi ${messageIdsFailed.length} tin'}');
      }

      // Còn tồn đọng thì kéo lô tiếp NGAY, không đợi hết chu kỳ 5 giây.
      // Chốt _isPullingMessages được nhả trong finally trước khi sự kiện mới
      // được xử lý, nên không tạo đệ quy.
      if (discoveryService.lastPullHasMore) {
        add(PullEncryptedMessagesEvent());
      }
    } catch (e) {
      print('[E2EE] Error pulling encrypted messages: $e');
    } finally {
      _isPullingMessages = false;
    }
  }

  // ══ LOG TẠM ĐỂ CHẨN ĐOÁN CHỈ BÁO XANH ═════════════════════════════════════
  //
  // Đặt `kLogPresence = false` là tắt sạch, không phải đi tìm từng dòng print.
  // Xoá hẳn khối này sau khi đã xác định được vì sao người dùng không hiện
  // xanh.
  //
  // Cách đọc log:
  //   [Presence] heartbeat  izii-d-xxx → onlineSynced   ← nhịp tim máy kia TỚI
  //   [Presence] ↩︎ nhịp tim của chính mình             ← chỉ thấy loại này
  //                                                       = máy kia không gửi
  //   [Presence] 🔄 làm mới: ... xoá N mục               ← bị quét sạch định kỳ
  //   [Presence] bản đồ hiện tại: {…}                    ← trạng thái sau mỗi lần đổi
  static const bool kLogPresence = true;

  void _logPresence(
    String source,
    String userId,
    ChatPresenceState presence,
    Map<String, ChatPresenceState> map,
  ) {
    if (!kLogPresence) return;
    final short = userId.length > 20 ? '${userId.substring(0, 20)}…' : userId;
    print('[Presence] $source  $short → ${presence.name}');
    print('[Presence] bản đồ hiện tại: '
        '${map.entries.map((e) => "${e.key}=${e.value.name}").join(", ")}');
  }

  Future<void> _onRefreshPresence(
    RefreshPresenceEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final onlineDevices = await DeviceDiscoveryService().getOnlineDevices();
      final updatedMap = Map<String, ChatPresenceState>.from(state.userPresenceMap);
      final now = DateTime.now();

      var marked = 0;
      for (var dev in onlineDevices) {
        if (dev.deviceId.isNotEmpty && dev.deviceId != _currentUserId) {
          _presenceLastSeen[dev.deviceId] = now;
          updatedMap[dev.deviceId] = ChatPresenceState.onlineSynced;
          marked++;

          // Tự động đảm bảo thiết bị trực tuyến này có trong bảng users local
          if (dev.deviceName.isNotEmpty) {
            try {
              _db.into(_db.users).insertOnConflictUpdate(
                User(
                  id: dev.deviceId,
                  name: dev.deviceName,
                  type: 'both',
                  kycStatus: 'verified',
                  createdAt: now,
                ),
              );
            } catch (_) {}
          }
        }
        if (dev.userId.isNotEmpty && dev.userId != _currentUserId) {
          _presenceLastSeen[dev.userId] = now;
          updatedMap[dev.userId] = ChatPresenceState.onlineSynced;
        }
      }

      // Chỉ đánh dấu offline nếu đã quá 90 giây không nhận được tín hiệu (tránh chớp tắt khi mạng lag / HTTP trễ)
      var cleared = 0;
      for (var key in updatedMap.keys.toList()) {
        final lastSeen = _presenceLastSeen[key];
        if (lastSeen == null || now.difference(lastSeen) > const Duration(seconds: 90)) {
          if (updatedMap[key] == ChatPresenceState.onlineSynced) {
            updatedMap[key] = ChatPresenceState.offline;
            cleared++;
          }
        }
      }

      if (kLogPresence) {
        print('[Presence] 🔄 làm mới: server báo ${onlineDevices.length} máy '
            'trực tuyến · xoá $cleared mục · tô xanh $marked mục');
        for (final d in onlineDevices) {
          print('[Presence]    · device_id=${d.deviceId} user_id=${d.userId}'
              '${d.deviceId == d.userId ? "" : "  ⚠️ HAI KHOÁ KHÁC NHAU"}');
        }
        print('[Presence] bản đồ sau khi làm mới: '
            '${updatedMap.entries.map((e) => "${e.key}=${e.value.name}").join(", ")}');
      }

      emit(state.copyWith(userPresenceMap: updatedMap));
    } catch (e) {
      if (kLogPresence) print('[Presence] ❌ làm mới thất bại: $e');
    }
  }

  void _onPickAttachments(
    PickAttachmentsEvent event,
    Emitter<ChatState> emit,
  ) {
    final updatedList = List<AttachmentFile>.from(state.draftAttachments)
      ..addAll(event.files);
    emit(state.copyWith(draftAttachments: updatedList));
  }

  void _onRemoveAttachment(
    RemoveAttachmentEvent event,
    Emitter<ChatState> emit,
  ) {
    final updatedList = List<AttachmentFile>.from(state.draftAttachments)
      ..removeWhere((f) => f.id == event.fileId);
    emit(state.copyWith(draftAttachments: updatedList));
  }

  void _onUploadProgressTick(
    UploadProgressTickEvent event,
    Emitter<ChatState> emit,
  ) {
    final updatedMap = Map<String, double>.from(state.uploadProgressMap)
      ..['${event.messageId}_${event.fileId}'] = event.progress;
    emit(state.copyWith(uploadProgressMap: updatedMap));
  }

  Future<void> _onSendMessageWithAttachments(
    SendMessageWithAttachmentsEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentUserId == null) return;

    final attachments = List<AttachmentFile>.from(state.draftAttachments);
    if (attachments.isEmpty) return;

    // Clear draft attachments
    emit(state.copyWith(draftAttachments: const []));

    final messageId = const Uuid().v4();
    final now = DateTime.now();

    // Create ChatMessage object with status 'uploading' to prevent SyncService from duplicate uploading
    final initialAttachments = attachments
        .map((a) => AttachmentFile(
              id: a.id,
              name: a.name,
              mimeType: a.mimeType,
              fileSize: a.fileSize,
              localUri: a.localUri,
              remoteUrl: a.remoteUrl,
              uploadStatus: 'uploading',
            ))
        .toList();

    final messageContent = ChatMessageContent(
      text: event.text,
      attachments: initialAttachments,
    );

    final chatMsg = ChatMessage(
      id: messageId,
      conversationId: event.conversationId,
      senderId: _currentUserId!,
      type: ChatMessageType.file.name, // Mark as file message type
      content: messageContent.toJson(),
      sentAt: now,
      isDeleted: false,
    );

    // Save locally
    await _chatRepository.saveMessage(chatMsg);

    // Update active messages if this conversation is open
    if (state.activeConversationId == event.conversationId) {
      final updatedList = List<ChatMessage>.from(state.activeMessages)
        ..add(chatMsg);
      emit(state.copyWith(activeMessages: updatedList));
    }
    add(LoadConversationsEvent());

    // Trigger upload in background
    _uploadAttachmentsAndSend(chatMsg, attachments);
  }

  Future<void> _onRetryUploadAttachment(
    RetryUploadAttachmentEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final content = ChatMessageContent.fromJson(event.message.content);
      if (content.attachments != null && content.attachments!.isNotEmpty) {
        _uploadAttachmentsAndSend(event.message, content.attachments!);
      }
    } catch (e) {
      print('[ChatBloc] Error retrying attachment upload: $e');
    }
  }

  Future<void> _uploadAttachmentsAndSend(
    ChatMessage message,
    List<AttachmentFile> attachments,
  ) async {
    final updatedAttachments = <AttachmentFile>[];
    bool hasFailure = false;

    for (var att in attachments) {
      if (att.remoteUrl != null &&
          att.remoteUrl!.isNotEmpty &&
          att.uploadStatus == 'success') {
        updatedAttachments.add(att);
        continue;
      }

      // Set to uploading status
      add(UploadProgressTickEvent(message.id, att.id, 0.0));

      try {
        final filePath = att.localUri;
        if (filePath == null || !await File(filePath).exists()) {
          throw Exception('Local file does not exist: $filePath');
        }

        // Start upload
        final remoteUrl = await _uploadFile(message.id, att.id, filePath);
        if (remoteUrl != null) {
          updatedAttachments.add(AttachmentFile(
            id: att.id,
            name: att.name,
            mimeType: att.mimeType,
            fileSize: att.fileSize,
            localUri: att.localUri,
            remoteUrl: remoteUrl,
            uploadStatus: 'success',
          ));
        } else {
          hasFailure = true;
          updatedAttachments.add(AttachmentFile(
            id: att.id,
            name: att.name,
            mimeType: att.mimeType,
            fileSize: att.fileSize,
            localUri: att.localUri,
            uploadStatus: 'failed',
          ));
        }
      } catch (e) {
        print('[ChatBloc] Error uploading attachment: $e');
        hasFailure = true;
        updatedAttachments.add(AttachmentFile(
          id: att.id,
          name: att.name,
          mimeType: att.mimeType,
          fileSize: att.fileSize,
          localUri: att.localUri,
          uploadStatus: 'failed',
        ));
      }
    }

    // Update local database message with final status/URLs
    final finalContent = ChatMessageContent(
      text: ChatMessageContent.fromJson(message.content).text,
      attachments: updatedAttachments,
    );

    final updatedMsg = message.copyWith(content: finalContent.toJson());

    await _chatRepository.saveMessage(updatedMsg);

    // Update active message list in state
    if (state.activeConversationId == message.conversationId) {
      add(OpenConversationEvent(message.conversationId));
    }

    // Hội thoại 1-1: gửi phong bì E2EE khi tải lên xong, không outbox/WS plaintext.
    // Tải lỗi thì giữ tin ở máy, người dùng bấm "thử lại" (RetryUploadAttachmentEvent).
    // LƯU Ý: nội dung tệp trên server hiện CHƯA mã hoá (Phase 3) — chỉ liên kết
    // và tên tệp đi trong phong bì mã hoá.
    if (DirectE2eeChannel.isDirect(updatedMsg.conversationId)) {
      if (hasFailure) {
        print('[ChatBloc] Tải tệp lỗi — tin 1-1 giữ ở máy, chờ thử lại.');
        return;
      }
      final contentMap = finalContent.toMap();
      // Đường dẫn cục bộ của người gửi vô nghĩa với người nhận.
      final atts = contentMap['attachments'];
      if (atts is List) {
        contentMap['attachments'] = [
          for (final a in atts)
            if (a is Map)
              (Map<String, dynamic>.from(a)..remove('local_uri'))
        ];
      }
      add(SendEnvelopeEvent(ChatEnvelope.message(
        id: updatedMsg.id,
        conversationId: updatedMsg.conversationId,
        type: updatedMsg.type,
        content: contentMap,
        ts: updatedMsg.sentAt,
        replyToId: updatedMsg.replyToId,
        forwardedFromId: updatedMsg.forwardedFromId,
      )));
      return;
    }

    // Always queue message in offline outbox so SyncService can sync/retry upload
    await _chatRepository.queueMessageOffline(updatedMsg);

    if (hasFailure) {
      print('[ChatBloc] Some attachments failed to upload. Message is saved locally and queued in outbox. Will retry on sync.');
      SyncService().triggerSync();
      return;
    }

    // Broadcast via WS
    if (_wsService.isConnected) {
      _wsService.sendEvent(ChatWebSocketEvent(
        event: 'send_message',
        data: {
          'message_id': updatedMsg.id,
          'conversation_id': updatedMsg.conversationId,
          'sender_id': _currentUserId,
          'type': updatedMsg.type,
          'content': finalContent.toMap(),
          'sent_at': updatedMsg.sentAt.toIso8601String(),
        },
      ));
    } else {
      // Trigger sync outbox push immediately
      SyncService().triggerSync();
    }
  }

  Future<String?> _uploadFile(
    String messageId,
    String fileId,
    String filePath,
  ) async {
    return SyncService().uploadAttachment(
      filePath,
      onProgress: (sent, total) {
        if (total > 0) {
          final progress = sent / total;
          add(UploadProgressTickEvent(messageId, fileId, progress));
        }
      },
    );
  }
}
