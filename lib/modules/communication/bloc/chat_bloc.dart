import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/device_identity/device_identity_service.dart';
import '../../../core/device_identity/device_discovery_service.dart';
import '../../../core/device_identity/device_identity_models.dart';
import '../models/chat_models.dart';
import '../repository/chat_repository.dart';
import '../services/chat_websocket_service.dart';
import '../../../core/settings/settings_service.dart';

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

  const SendMessageEvent({
    required this.conversationId,
    required this.text,
    this.type = ChatMessageType.text,
    this.extraContent,
  });

  @override
  List<Object?> get props => [conversationId, text, type, extraContent];
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

// --- States ---
class ChatState extends Equatable {
  final List<ChatConversation> conversations;
  final List<User> contacts;
  final List<ChatMessage> activeMessages;
  final String? activeConversationId;
  final String? currentUserId;
  final Map<String, ChatPresenceState> userPresenceMap;
  final Map<String, List<String>>
      typingUsersMap; // Map<ConversationId, List<UserId>>
  final bool isLoading;
  final bool isWsConnected;
  final String? error;

  const ChatState({
    this.conversations = const [],
    this.contacts = const [],
    this.activeMessages = const [],
    this.activeConversationId,
    this.currentUserId,
    this.userPresenceMap = const {},
    this.typingUsersMap = const {},
    this.isLoading = false,
    this.isWsConnected = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatConversation>? conversations,
    List<User>? contacts,
    List<ChatMessage>? activeMessages,
    String? activeConversationId,
    String? currentUserId,
    Map<String, ChatPresenceState>? userPresenceMap,
    Map<String, List<String>>? typingUsersMap,
    bool? isLoading,
    bool? isWsConnected,
    String? error,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      contacts: contacts ?? this.contacts,
      activeMessages: activeMessages ?? this.activeMessages,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      currentUserId: currentUserId ?? this.currentUserId,
      userPresenceMap: userPresenceMap ?? this.userPresenceMap,
      typingUsersMap: typingUsersMap ?? this.typingUsersMap,
      isLoading: isLoading ?? this.isLoading,
      isWsConnected: isWsConnected ?? this.isWsConnected,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        conversations,
        contacts,
        activeMessages,
        activeConversationId,
        currentUserId,
        userPresenceMap,
        typingUsersMap,
        isLoading,
        isWsConnected,
        error,
      ];
}

// --- BLoC ---
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  final ChatWebSocketService _wsService;
  final AppDatabase _db = AppDatabase();
  StreamSubscription? _wsEventSubscription;
  StreamSubscription? _wsConnSubscription;
  Timer? _pullTimer;
  String? _currentUserId;

  String? get currentUserId => _currentUserId;
  ChatRepository get chatRepository => _chatRepository;
  AppDatabase get db => _db;

  ChatBloc({
    ChatRepository? chatRepository,
    ChatWebSocketService? wsService,
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _wsService = wsService ?? ChatWebSocketService(),
        super(const ChatState()) {
    on<LoadConversationsEvent>(_onLoadConversations);
    on<LoadContactsEvent>(_onLoadContacts);
    on<OpenConversationEvent>(_onOpenConversation);
    on<OpenDirectChatWithUserEvent>(_onOpenDirectChatWithUser);
    on<SendMessageEvent>(_onSendMessage);
    on<UpdateWsConnectionStateEvent>(_onUpdateWsConnectionState);
    on<ReceivedWsEvent>(_onReceivedWs);
    on<SendTypingStateEvent>(_onSendTypingState);
    on<SwitchUserEvent>(_onSwitchUser);
    on<SendEncryptedMessageEvent>(_onSendEncryptedMessage);
    on<PullEncryptedMessagesEvent>(_onPullEncryptedMessages);

    _init();
  }

  Future<void> _init() async {
    try {
      const defaultUserId = 'default_user';
      await _db.into(_db.users).insert(
            User(
              id: defaultUserId,
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
          id: 'user_Quill_Phan',
          name: 'Quill Phan',
          email: 'Quill.Phan@izii.com',
          phone: '0988889988',
          type: 'provider',
          kycStatus: 'verified',
          createdAt: DateTime.now(),
        ),
      ];
      for (var mock in mockContacts) {
        await _db.into(_db.users).insert(mock, mode: InsertMode.insertOrIgnore);
      }

      final activeUserId = await SettingsService().getActiveUserId();
      add(SwitchUserEvent(activeUserId));
    } catch (_) {}

    // Listen to connection state
    _wsConnSubscription = _wsService.connectionStateStream.listen((connected) {
      add(UpdateWsConnectionStateEvent(connected));
    });

    // Listen to events
    _wsEventSubscription = _wsService.eventStream.listen((event) {
      add(ReceivedWsEvent(event));
    });

    // Periodic polling for E2EE messages and HTTP Sync
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      add(PullEncryptedMessagesEvent());
      SyncService().triggerSync();
    });
  }

  Future<void> _onLoadConversations(
    LoadConversationsEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (_currentUserId == null) return;

    // Trigger background sync to push local messages and pull new messages
    SyncService().triggerSync();

    emit(state.copyWith(isLoading: true));
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

    // Trigger background sync to pull latest contact updates
    SyncService().triggerSync();

    emit(state.copyWith(isLoading: true));
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
    emit(state.copyWith(
        isLoading: true, activeConversationId: event.conversationId));
    try {
      final messages = await _chatRepository.getMessages(event.conversationId);
      emit(state.copyWith(activeMessages: messages, isLoading: false));

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

    // Auto-detect E2EE capability: if the companion has online devices, encrypt!
    final companion = await _chatRepository.getCompanion(
        event.conversationId, _currentUserId!);
    if (companion != null) {
      try {
        final discoveryService = DeviceDiscoveryService();
        final onlineDevices = await discoveryService.getOnlineDevices();
        final companionDevices =
            onlineDevices.where((d) => d.userId == companion.id).toList();

        if (companionDevices.isNotEmpty) {
          add(SendEncryptedMessageEvent(
            conversationId: event.conversationId,
            text: event.text,
          ));
          return;
        }
      } catch (e) {
        print('[E2EE] Error checking companion devices: $e');
      }
    }

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
    );

    // Save message locally first
    await _chatRepository.saveMessage(chatMsg);

    // Update state to include new message
    if (state.activeConversationId == event.conversationId) {
      final updatedList = List<ChatMessage>.from(state.activeMessages)
        ..add(chatMsg);
      emit(state.copyWith(activeMessages: updatedList));
    }

    // Refresh conversation list to update snippets
    add(LoadConversationsEvent());

    // Connection check
    if (_wsService.isConnected) {
      _wsService.sendEvent(ChatWebSocketEvent(
        event: 'send_message',
        data: {
          'message_id': messageId,
          'conversation_id': event.conversationId,
          'type': event.type.name,
          'content': contentMap,
          'sent_at': now.toIso8601String(),
        },
      ));
    } else {
      // Outbox fallback
      await _chatRepository.queueMessageOffline(chatMsg);
      // Trigger background sync to push this message to server immediately
      SyncService().triggerSync();
    }
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
    }
  }

  Future<void> _onReceivedWs(
    ReceivedWsEvent event,
    Emitter<ChatState> emit,
  ) async {
    final wsEvent = event.event;
    final data = wsEvent.data;

    switch (wsEvent.event) {
      case 'message_received':
        final msgId = data['message_id'] as String;
        final convoId = data['conversation_id'] as String;
        final senderId = data['sender_id'] as String;
        final type = data['type'] as String;
        final content = data['content'] as Map<String, dynamic>;
        final sentAt = DateTime.parse(data['sent_at'] as String);

        final chatMsg = ChatMessage(
          id: msgId,
          conversationId: convoId,
          senderId: senderId,
          type: type,
          content: jsonEncode(content),
          sentAt: sentAt,
          deliveredAt: DateTime.now(),
          isDeleted: false,
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

        final updatedPresenceMap =
            Map<String, ChatPresenceState>.from(state.userPresenceMap)
              ..[userId] = presence;
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
          final updatedMap =
              Map<String, ChatPresenceState>.from(state.userPresenceMap)
                ..[hbUserId] = ChatPresenceState.onlineSynced;
          emit(state.copyWith(userPresenceMap: updatedMap));
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
      activeMsgs[index] = ChatMessage(
        id: oldMsg.id,
        conversationId: oldMsg.conversationId,
        senderId: oldMsg.senderId,
        type: oldMsg.type,
        content: oldMsg.content,
        sentAt: oldMsg.sentAt,
        deliveredAt: deliveredAt ?? oldMsg.deliveredAt,
        readAt: readAt ?? oldMsg.readAt,
        isDeleted: oldMsg.isDeleted,
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

  Future<void> _onSwitchUser(
    SwitchUserEvent event,
    Emitter<ChatState> emit,
  ) async {
    await SettingsService().saveActiveUserId(event.userId);
    _currentUserId = event.userId;
    _wsService.disconnect();
    _wsService.setUserId(event.userId);
    _wsService.connect();

    emit(state.copyWith(currentUserId: event.userId));

    // Trigger reload
    add(LoadConversationsEvent());
    add(LoadContactsEvent());
  }

  @override
  Future<void> close() {
    _pullTimer?.cancel();
    _wsEventSubscription?.cancel();
    _wsConnSubscription?.cancel();
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
    try {
      final identityService = DeviceIdentityService();
      final discoveryService = DeviceDiscoveryService();
      final myIdentity = await identityService.getOrCreateIdentity();

      // Pull pending messages for this device
      final pendingMessages = await discoveryService.getPendingMessages();

      if (pendingMessages.isEmpty) return;

      final messageIdsToAck = <String>[];

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
            print('[E2EE] Unknown sender device: $senderDeviceId, skipping');
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

          final senderX25519PubKeyBytes = base64Decode(senderDevice.publicKeyBase64);
          final senderEd25519PubKeyBytes = base64Decode(senderDevice.signingPublicKeyBase64);
          final plaintext = await identityService.decryptPayload(
            encPayload,
            senderX25519PubKeyBytes,
            senderEd25519PubKeyBytes,
          );

          // Save decrypted message locally
          final chatMsg = ChatMessage(
            id: msgId,
            conversationId: conversationId,
            senderId: senderDevice.userId,
            type: 'text',
            content: jsonEncode({'text': plaintext}),
            sentAt: sentAt,
            deliveredAt: DateTime.now(),
            isDeleted: false,
          );
          await _chatRepository.saveMessage(chatMsg);

          // Update UI if this conversation is active
          if (state.activeConversationId == conversationId) {
            final updatedList = List<ChatMessage>.from(state.activeMessages)
              ..add(chatMsg);
            emit(state.copyWith(activeMessages: updatedList));
          }

          messageIdsToAck.add(msgId);
          print(
              '[E2EE] Decrypted message from $senderDeviceId: ${plaintext.length} chars');
        } catch (e) {
          print('[E2EE] Error decrypting message: $e');
        }
      }

      // Acknowledge delivery
      if (messageIdsToAck.isNotEmpty) {
        await discoveryService.acknowledgeMessages(messageIdsToAck);
        add(LoadConversationsEvent());
        print('[E2EE] Acknowledged ${messageIdsToAck.length} messages');
      }
    } catch (e) {
      print('[E2EE] Error pulling encrypted messages: $e');
    }
  }
}
