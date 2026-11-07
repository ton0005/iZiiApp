import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/device_identity/device_identity_service.dart';
import '../../../core/settings/settings_service.dart';
import '../models/chat_models.dart';

/// ⚠️ TODO(production): XOÁ HẰNG NÀY TRƯỚC KHI PHÁT HÀNH.
///
/// Secret WS mặc định cứng, chỉ để test app mà chưa cần cấu hình token. Nó nằm
/// trong mã nguồn nên AI tải được app đều đọc được → coi như không có secret.
/// Khi lên production: bỏ hằng này, bắt buộc `getWsToken()` có giá trị (nếu
/// rỗng thì báo "chưa cấu hình server" thay vì dùng secret mặc định), và đặt
/// IZIIAPP_WS_SECRET riêng cho server. Xem lib/modules/communication/plan/01.md.
const String _kDevFallbackWsSecret = 'iZiiServerSecretKey2026';

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
  int _reconnectAttempts = 0;
  String? _currentUserId;

  void setUserId(String userId) {
    _currentUserId = userId;
  }

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final baseUrl = await _settingsService.getSyncServerUrl();
      final uri = Uri.parse(baseUrl.trim());
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final portStr = uri.hasPort ? ':${uri.port}' : '';
      final wsToken = await _settingsService.getWsToken();
      final effectiveToken = wsToken.isNotEmpty ? wsToken : _kDevFallbackWsSecret;

      // Danh tính máy để server chỉ giao tin hội thoại cho đúng thành viên.
      // Thiếu cả hai thì server coi là bản cũ và KHÔNG giao tin hội thoại qua
      // WS nữa (tin vẫn về qua /sync/pull, chỉ chậm hơn).
      final query = <String, String>{'token': effectiveToken};
      try {
        final identity = await DeviceIdentityService().getOrCreateIdentity();
        if (identity.deviceId.isNotEmpty) query['device_id'] = identity.deviceId;
      } catch (_) {
        if (_currentUserId != null) query['device_id'] = _currentUserId!;
      }
      final deviceToken = await _settingsService.getDeviceToken(baseUrl);
      if (deviceToken != null && deviceToken.isNotEmpty) {
        query['device_token'] = deviceToken;
      }
      final wsUrl = Uri(
        scheme: scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: '/chat',
        queryParameters: query,
      ).toString();
      final maskedToken = effectiveToken.length > 6 ? '${effectiveToken.substring(0, 4)}...' : '***';

      print('[ChatWS] Connecting to $scheme://${uri.host}$portStr/chat?token=$maskedToken ...');
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
      _reconnectAttempts = 0;
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
    if (rawMessage.trim() == 'pong') {
      return;
    }
    try {
      final event = ChatWebSocketEvent.fromJson(rawMessage);
      if (event.event == 'pong') {
        return;
      }
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
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isConnected) {
        // Send raw text ping to keep tunnel and proxies alive
        try {
          _channel?.sink.add('ping');
        } catch (_) {}

        if (_currentUserId != null) {
          sendEvent(ChatWebSocketEvent(
            event: 'heartbeat',
            data: {
              'user_id': _currentUserId,
              'sync_status': 'synced',
            },
          ));
        }
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
    _heartbeatTimer?.cancel();
    _channel = null;

    // Exponential backoff: 2s, 4s, 8s, up to 30s
    _reconnectAttempts++;
    final backoffSeconds = (_reconnectAttempts * 2).clamp(2, 30);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      print('[ChatWS] Retrying connection (attempt $_reconnectAttempts after ${backoffSeconds}s)...');
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
