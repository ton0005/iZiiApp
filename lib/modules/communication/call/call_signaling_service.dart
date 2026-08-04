// lib/modules/communication/call/call_signaling_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:izii_app/core/settings/settings_service.dart';

class CallSignalingService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;
  bool isConnected = false;

  Future<void> connect(String clientId) async {
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
      isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message as String);
            _eventController.add(data);
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
    if (_channel != null && isConnected) {
      final payload = jsonEncode({
        'event': event,
        if (targetId != null) 'target_id': targetId,
        'data': data ?? {},
      });
      _channel!.sink.add(payload);
    }
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
