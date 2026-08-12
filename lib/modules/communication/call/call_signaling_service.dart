// lib/modules/communication/call/call_signaling_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:izii_app/core/settings/settings_service.dart';

import '../services/chat_websocket_service.dart';
import '../models/chat_models.dart';

class CallSignalingService {
  WebSocketChannel? _channel;
  StreamSubscription? _chatWsSubscription;

  /// Id đang dùng để đăng ký trên `/call/ws/{id}`.
  ///
  /// PHẢI theo dõi riêng: trước đây `connect()` thoát sớm khi đã có kết nối,
  /// nên khi ứng dụng đổi danh tính (lúc khởi động là device_id, sau khi nạp
  /// xong hồ sơ mới thành user_id) thì socket vẫn nằm nguyên dưới id CŨ.
  /// Server đăng ký `/call/ws/izii-d-1093d407` trong khi gói tín hiệu lại ghi
  /// `target_id: user_an_nguyen` — không bao giờ khớp, mọi gói phải đi đường
  /// quảng bá dự phòng.
  String? _clientId;
  String? get clientId => _clientId;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;
  bool isConnected = false;

  /// Gói tín hiệu này có phải gửi cho MÌNH không.
  ///
  /// Kênh `/chat` là BROADCAST — server phát cho mọi máy đang kết nối. Nếu
  /// không lọc thì máy thứ ba cũng đổ chuông khi A gọi B, và tệ hơn là nhận
  /// luôn cả SDP/ICE của cuộc gọi không liên quan tới mình.
  ///
  /// Lọc theo `target_id` (do bên gửi ghi) hoặc `callee_id` (có trong dữ liệu
  /// lời mời). Không có cả hai thì cho qua — thà đổ chuông thừa còn hơn bỏ sót
  /// cuộc gọi vì server phiên bản cũ chưa gắn trường này.
  bool _isForMe(Map<String, dynamic> data, String clientId) {
    final target = data['target_id'] ?? data['callee_id'];
    if (target == null || target.toString().isEmpty) return true;
    return target.toString() == clientId;
  }

  Future<void> connect(String clientId) async {
    // Đổi danh tính thì phải mở lại socket dưới id mới, không được giữ cái cũ.
    if (isConnected && _clientId != null && _clientId != clientId) {
      print('[Call] Đổi danh tính tín hiệu: $_clientId → $clientId, nối lại.');
      disconnect();
    }
    _clientId = clientId;

    // Listen to ChatWebSocketService fallback events
    _chatWsSubscription?.cancel();
    _chatWsSubscription = ChatWebSocketService().eventStream.listen((event) {
      final evName = event.event;
      if (evName.startsWith('call_') || evName.startsWith('sdp_') || evName == 'ice_candidate') {
        final data = event.data;
        final senderId = data['sender_id'] ?? data['caller_id'];
        if (senderId != null && senderId == clientId) {
          return; // Ignore own echo sent over /chat WebSocket
        }
        if (!_isForMe(data, clientId)) return;
        if (!_eventController.isClosed) {
          _eventController.add({
            'event': evName,
            'data': data,
          });
        }
      }
    });

    if (isConnected) return;

    final settings = SettingsService();
    final serverUrl = await settings.getSyncServerUrl();
    
    // Replace http/https with ws/wss
    String wsUrl = serverUrl
        .replaceAll('http://', 'ws://')
        .replaceAll('https://', 'wss://');
    
    if (!wsUrl.endsWith('/')) wsUrl += '/';
    final uri = Uri.parse('${wsUrl}call/ws/$clientId');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> msg = jsonDecode(message as String);
            // Server có lúc phát quảng bá khi không tìm thấy người nhận trên
            // /call/ws, nên kênh trực tiếp cũng phải lọc như kênh /chat.
            final payload = Map<String, dynamic>.from(msg['data'] ?? {});
            if (msg['target_id'] != null) {
              payload['target_id'] = msg['target_id'];
            }
            if (!_isForMe(payload, clientId)) return;
            if (!_eventController.isClosed) {
              _eventController.add({'event': msg['event'], 'data': payload});
            }
          } catch (_) {}
        },
        onError: (err) {
          isConnected = false;
        },
        onDone: () {
          isConnected = false;
        },
      );
    } catch (_) {
      isConnected = false;
    }
  }

  void sendEvent(String event, {String? targetId, Map<String, dynamic>? data}) {
    final payloadData = data ?? {};
    final payloadMap = {
      'event': event,
      if (targetId != null) 'target_id': targetId,
      'data': payloadData,
    };
    final payload = jsonEncode(payloadMap);

    if (_channel != null && isConnected) {
      try {
        _channel!.sink.add(payload);
      } catch (_) {}
    }

    // Always fallback relay via main /chat WebSocket channel for maximum reliability
    try {
      ChatWebSocketService().sendEvent(ChatWebSocketEvent(
        event: event,
        data: {
          if (targetId != null) 'target_id': targetId,
          ...payloadData,
        },
      ));
    } catch (_) {}
  }

  void sendCallInvite({
    required String callId,
    required String callerId,
    required String callerName,
    required String calleeId,
    required String callType,
    String? roomId,
  }) {
    sendEvent(
      'call_invite',
      targetId: calleeId,
      data: {
        'call_id': callId,
        'caller_id': callerId,
        'caller_name': callerName,
        'callee_id': calleeId,
        'call_type': callType,
        'room_id': roomId,
      },
    );
  }

  void sendCallAccept({required String callId, required String calleeId, required String targetId}) {
    sendEvent('call_accept', targetId: targetId, data: {'call_id': callId, 'callee_id': calleeId});
  }

  void sendCallReject({required String callId, required String calleeId, required String targetId, String? reason}) {
    sendEvent('call_reject', targetId: targetId, data: {'call_id': callId, 'callee_id': calleeId, 'reason': reason});
  }

  void sendCallEnd({required String callId, required String targetId}) {
    sendEvent('call_end', targetId: targetId, data: {'call_id': callId});
  }

  void sendSdpOffer({required String callId, required String targetId, required String sdp}) {
    sendEvent('sdp_offer', targetId: targetId, data: {'call_id': callId, 'sdp': sdp, 'type': 'offer'});
  }

  void sendSdpAnswer({required String callId, required String targetId, required String sdp}) {
    sendEvent('sdp_answer', targetId: targetId, data: {'call_id': callId, 'sdp': sdp, 'type': 'answer'});
  }

  void sendIceCandidate({
    required String callId,
    required String targetId,
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
  }) {
    sendEvent(
      'ice_candidate',
      targetId: targetId,
      data: {
        'call_id': callId,
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
      },
    );
  }

  void disconnect() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    isConnected = false;
  }
}
