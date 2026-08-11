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
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;
  bool isConnected = false;

  Future<void> connect(String clientId) async {
    // Listen to ChatWebSocketService fallback events
    _chatWsSubscription?.cancel();
    _chatWsSubscription = ChatWebSocketService().eventStream.listen((event) {
      final evName = event.event;
      if (evName.startsWith('call_') || evName.startsWith('sdp_') || evName == 'ice_candidate') {
        if (!_eventController.isClosed) {
          _eventController.add({
            'event': evName,
            'data': event.data,
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
            final Map<String, dynamic> data = jsonDecode(message as String);
            if (!_eventController.isClosed) {
              _eventController.add(data);
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
    isConnected = false;
  }
}
