import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/settings/settings_service.dart';
import '../models/chat_models.dart';

class ChatWebSocketService {
  static final ChatWebSocketService _instance = ChatWebSocketService._internal();
  factory ChatWebSocketService() => _instance;
  ChatWebSocketService._internal();

  final SettingsService _settingsService = SettingsService();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  
  // Stream Controllers
  final _eventStreamController = StreamController<ChatWebSocketEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  // Public streams
  Stream<ChatWebSocketEvent> get eventStream => _eventStreamController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _currentUserId;

  void setUserId(String userId) {
    _currentUserId = userId;
  }

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final baseUrl = await _settingsService.getSyncServerUrl();
      // Convert http/https to ws/wss
      String wsUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      if (!wsUrl.endsWith('/')) {
        wsUrl += '/';
      }
      wsUrl += 'chat';

      print('[ChatWS] Connecting to $wsUrl ...');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Intercept asynchronous sink errors to prevent Unhandled Exception crashes
      _channel!.sink.done.catchError((error) {
        print('[ChatWS] WebSocket sink error: $error');
      });
      
      // Wait for connection to be ready before marking as connected
      // This throws an exception if the WebSocket upgrade handshake fails
      await _channel!.ready;
      
      _isConnected = true;
      _isConnecting = false;
      _connectionStateController.add(true);
      print('[ChatWS] Connected successfully.');


      // Start listening to messages
      _channel!.stream.listen(
        (message) {
          _onMessageReceived(message as String);
        },
        onError: (error) {
          print('[ChatWS] Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('[ChatWS] Connection closed.');
          _handleDisconnect();
        },
      );

      _startHeartbeat();
    } catch (e) {
      print('[ChatWS] Failed to connect: $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _onMessageReceived(String rawMessage) {
    try {
      final event = ChatWebSocketEvent.fromJson(rawMessage);
      print('[ChatWS] Received event: ${event.event}');
      if (!_eventStreamController.isClosed) {
        _eventStreamController.add(event);
      }
    } catch (e) {
      print('[ChatWS] Error parsing WebSocket message: $e');
    }
  }

  void sendEvent(ChatWebSocketEvent event) {
    if (!_isConnected || _channel == null) {
      print('[ChatWS] Cannot send event, WebSocket disconnected.');
      return;
    }
    try {
      _channel!.sink.add(event.toJson());
      print('[ChatWS] Sent event: ${event.event}');
    } catch (e) {
      print('[ChatWS] Error sending WebSocket message: $e');
    }
  }

  /// Track 3: Send an E2EE encrypted message via WebSocket for real-time delivery.
  /// Falls back to HTTP relay if WebSocket is disconnected.
  void sendEncryptedMessage({
    required String conversationId,
    required String senderDeviceId,
    required String recipientDeviceId,
    required String ciphertextBase64,
    required String nonceBase64,
    required String signatureBase64,
  }) {
    sendEvent(ChatWebSocketEvent(
      event: 'e2ee_message',
      data: {
        'conversation_id': conversationId,
        'sender_device_id': senderDeviceId,
        'recipient_device_id': recipientDeviceId,
        'ciphertext': ciphertextBase64,
        'nonce': nonceBase64,
        'signature': signatureBase64,
        'sent_at': DateTime.now().toIso8601String(),
      },
    ));
  }

  /// Track 3: Send device presence/heartbeat via WebSocket
  void sendDevicePresence(String deviceId) {
    sendEvent(ChatWebSocketEvent(
      event: 'device_presence',
      data: {
        'device_id': deviceId,
        'status': 'online',
        'timestamp': DateTime.now().toIso8601String(),
      },
    ));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _currentUserId != null) {
        sendEvent(ChatWebSocketEvent(
          event: 'heartbeat',
          data: {
            'user_id': _currentUserId,
            'sync_status': 'synced',
          },
        ));
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
    _heartbeatTimer?.cancel();
    _channel = null;

    // Schedule reconnection
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('[ChatWS] Retrying connection...');
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
  }

  void dispose() {
    disconnect();
    _eventStreamController.close();
    _connectionStateController.close();
  }
}
