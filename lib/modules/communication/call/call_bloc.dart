// lib/modules/communication/call/call_bloc.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_call_engine.dart';
import 'call_signaling_service.dart';

// === EVENTS ===
abstract class CallEvent {}

class StartCallEvent extends CallEvent {
  final String callId;
  final String callerId;
  final String callerName;
  final String calleeId;
  final String calleeName;
  final String callType; // 'audio' or 'video'
  final String? roomId;

  StartCallEvent({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.callType,
    this.roomId,
  });
}

class IncomingCallReceivedEvent extends CallEvent {
  final Map<String, dynamic> data;
  IncomingCallReceivedEvent(this.data);
}

class AcceptCallEvent extends CallEvent {}

class RejectCallEvent extends CallEvent {}

class EndCallEvent extends CallEvent {}

class ToggleMicEvent extends CallEvent {}

class ToggleCamEvent extends CallEvent {}

class SwitchCamEvent extends CallEvent {}

class ToggleSpeakerEvent extends CallEvent {}

class TogglePIPEvent extends CallEvent {}

// ── Sự kiện NỘI BỘ, phát từ kênh tín hiệu và từ timer ─────────────────────
//
// VÌ SAO CẦN: flutter_bloc 9 NÉM StateError nếu `emit` được gọi sau khi handler
// đã kết thúc. Trước đây bloc emit thẳng từ trong `signaling.onEvent.listen`
// và từ callback của Timer đếm giờ — cả hai đều nằm ngoài handler. Hậu quả:
// vừa bắt máy xong là máy trạng thái vỡ, màn hình rơi về nhánh mặc định
// (nền #0F172A + vòng xoay xanh) — đúng triệu chứng "màn hình đen có icon xanh
// xoay". Mọi thứ đến từ bên ngoài giờ phải đi qua `add()`.

class _PeerAcceptedEvent extends CallEvent {}

class _PeerTerminatedEvent extends CallEvent {
  final String reason;
  _PeerTerminatedEvent(this.reason);
}

class _CallTickEvent extends CallEvent {}

// === STATES ===
abstract class CallState {
  final bool isPIP;
  CallState({this.isPIP = false});
}

class CallInitialState extends CallState {}

class CallRingingOutgoingState extends CallState {
  final String callId;
  final String calleeName;
  final String callType;

  CallRingingOutgoingState({
    required this.callId,
    required this.calleeName,
    required this.callType,
    super.isPIP,
  });
}

class CallRingingIncomingState extends CallState {
  final String callId;
  final String callerId;
  final String callerName;
  final String callType;

  CallRingingIncomingState({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callType,
    super.isPIP,
  });
}

class CallConnectedState extends CallState {
  final String callId;
  final String peerName;
  final String callType;
  final bool isMuted;
  final bool isCamDisabled;
  final bool isSpeakerOn;
  final int durationSeconds;

  CallConnectedState({
    required this.callId,
    required this.peerName,
    required this.callType,
    required this.isMuted,
    required this.isCamDisabled,
    required this.isSpeakerOn,
    required this.durationSeconds,
    super.isPIP,
  });

  CallConnectedState copyWith({
    bool? isMuted,
    bool? isCamDisabled,
    bool? isSpeakerOn,
    int? durationSeconds,
    bool? isPIP,
  }) {
    return CallConnectedState(
      callId: callId,
      peerName: peerName,
      callType: callType,
      isMuted: isMuted ?? this.isMuted,
      isCamDisabled: isCamDisabled ?? this.isCamDisabled,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isPIP: isPIP ?? this.isPIP,
    );
  }
}

class CallEndedState extends CallState {
  final String reason;
  CallEndedState([this.reason = 'Call ended']);
}

// === BLOC ===
class CallBloc extends Bloc<CallEvent, CallState> {
  final WebRTCCallEngine engine = WebRTCCallEngine();
  final CallSignalingService signaling = CallSignalingService();

  StreamSubscription? _signalingSubscription;
  Timer? _callDurationTimer;

  String? activeCallId;
  String? currentPeerId;
  String? currentPeerName;
  String? currentCallType;
  String? myClientId;

  CallBloc() : super(CallInitialState()) {
    on<StartCallEvent>(_onStartCall);
    on<IncomingCallReceivedEvent>(_onIncomingCallReceived);
    on<AcceptCallEvent>(_onAcceptCall);
    on<RejectCallEvent>(_onRejectCall);
    on<EndCallEvent>(_onEndCall);
    on<ToggleMicEvent>(_onToggleMic);
    on<ToggleCamEvent>(_onToggleCam);
    on<SwitchCamEvent>(_onSwitchCam);
    on<ToggleSpeakerEvent>(_onToggleSpeaker);
    on<TogglePIPEvent>(_onTogglePIP);
    on<_PeerAcceptedEvent>(_onPeerAccepted);
    on<_PeerTerminatedEvent>(_onPeerTerminated);
    on<_CallTickEvent>(_onCallTick);
  }

  Future<void> initSignaling(String clientId) async {
    myClientId = clientId;
    await signaling.connect(clientId);

    _signalingSubscription?.cancel();
    _signalingSubscription = signaling.onEvent.listen((msg) async {
      final event = msg['event'];
      final data = Map<String, dynamic>.from(msg['data'] ?? {});

      if (event == 'call_invite') {
        // Bên gọi phát lời mời qua CẢ HAI kênh (/call/ws và /chat) để chắc ăn,
        // nên cùng một cuộc gọi thường về tới hai lần. Bỏ qua bản trùng, nếu
        // không máy sẽ đổ chuông chồng lên nhau.
        final incomingId = data['call_id']?.toString();
        if (incomingId != null &&
            incomingId == activeCallId &&
            state is CallRingingIncomingState) {
          return;
        }
        add(IncomingCallReceivedEvent(data));
      } else if (event == 'call_accept') {
        if (state is CallRingingOutgoingState) {
          add(_PeerAcceptedEvent());
        }
      } else if (event == 'call_reject' || event == 'call_end') {
        add(_PeerTerminatedEvent(
            event == 'call_reject' ? 'Đầu kia từ chối' : 'Cuộc gọi đã kết thúc'));
      } else if (event == 'sdp_offer') {
        final sdp = data['sdp'];
        final callId = activeCallId;
        final peerId = currentPeerId;
        // Không còn `!`: offer về muộn sau khi đã cúp máy là chuyện bình
        // thường, ép kiểu ở đây sẽ ném lỗi và giết luôn subscription tín hiệu
        // — mọi cuộc gọi sau đó im lặng.
        if (sdp != null && callId != null && peerId != null) {
          try {
            await engine.setRemoteDescription(sdp, 'offer');
            final answer = await engine.createAnswer();
            signaling.sendSdpAnswer(
                callId: callId, targetId: peerId, sdp: answer.sdp!);
          } catch (e) {
            print('[Call] Lỗi xử lý sdp_offer: $e');
          }
        }
      } else if (event == 'sdp_answer') {
        final sdp = data['sdp'];
        if (sdp != null) {
          try {
            await engine.setRemoteDescription(sdp, 'answer');
          } catch (e) {
            print('[Call] Lỗi xử lý sdp_answer: $e');
          }
        }
      } else if (event == 'ice_candidate') {
        final candidate = data['candidate'];
        final sdpMid = data['sdpMid'];
        final sdpMLineIndex = data['sdpMLineIndex'];
        if (candidate != null) {
          try {
            await engine.addCandidate(
              candidate.toString(),
              sdpMid?.toString() ?? '',
              sdpMLineIndex is int
                  ? sdpMLineIndex
                  : int.tryParse('${sdpMLineIndex ?? 0}') ?? 0,
            );
          } catch (e) {
            print('[Call] Lỗi thêm ICE candidate: $e');
          }
        }
      }
    });
  }

  Future<void> _onStartCall(StartCallEvent event, Emitter<CallState> emit) async {
    activeCallId = event.callId;
    currentPeerId = event.calleeId;
    currentPeerName = event.calleeName;
    currentCallType = event.callType;

    await engine.initialize();
    await engine.openUserMedia(video: event.callType == 'video');

    signaling.sendCallInvite(
      callId: event.callId,
      callerId: event.callerId,
      callerName: event.callerName,
      calleeId: event.calleeId,
      callType: event.callType,
      roomId: event.roomId,
    );

    emit(CallRingingOutgoingState(
      callId: event.callId,
      calleeName: event.calleeName,
      callType: event.callType,
    ));
  }

  void _onIncomingCallReceived(IncomingCallReceivedEvent event, Emitter<CallState> emit) {
    final d = event.data;
    activeCallId = d['call_id'];
    currentPeerId = d['caller_id'];
    currentPeerName = d['caller_name'];
    currentCallType = d['call_type'] ?? 'video';

    emit(CallRingingIncomingState(
      callId: activeCallId!,
      callerId: currentPeerId!,
      callerName: currentPeerName!,
      callType: currentCallType!,
    ));
  }

  Future<void> _onAcceptCall(AcceptCallEvent event, Emitter<CallState> emit) async {
    final callId = activeCallId;
    final peerId = currentPeerId;
    if (callId == null || peerId == null) return;

    try {
      await engine.initialize();
      await engine.openUserMedia(video: currentCallType == 'video');
      // Dựng peer connection TRƯỚC khi báo đã nghe máy: đầu kia sẽ gửi SDP
      // offer ngay khi nhận call_accept, và nếu lúc đó chưa có peer connection
      // thì offer rơi mất — máy báo "đã kết nối" mà không có tiếng.
      await engine.setupPeerConnection([]);
    } catch (e) {
      add(_PeerTerminatedEvent('Không mở được micro/camera: $e'));
      return;
    }

    engine.onIceCandidate = (candidate) {
      final c = candidate.candidate;
      if (c == null) return;
      signaling.sendIceCandidate(
        callId: callId,
        targetId: peerId,
        candidate: c,
        sdpMid: candidate.sdpMid ?? '',
        sdpMLineIndex: candidate.sdpMLineIndex ?? 0,
      );
    };

    signaling.sendCallAccept(
      callId: callId,
      calleeId: myClientId ?? '',
      targetId: peerId,
    );

    _startDurationTimer();

    emit(CallConnectedState(
      callId: callId,
      peerName: currentPeerName ?? 'User',
      callType: currentCallType ?? 'audio',
      isMuted: false,
      isCamDisabled: false,
      isSpeakerOn: true,
      durationSeconds: 0,
    ));
  }

  /// Đầu kia đã bấm nghe — dựng peer connection và gửi SDP offer.
  ///
  /// Chạy trong handler thật nên `emit` hợp lệ.
  Future<void> _onPeerAccepted(
      _PeerAcceptedEvent event, Emitter<CallState> emit) async {
    final callId = activeCallId;
    final peerId = currentPeerId;
    if (callId == null || peerId == null) return;

    try {
      await engine.setupPeerConnection([]);

      engine.onIceCandidate = (candidate) {
        final c = candidate.candidate;
        if (c == null) return; // ứng viên kết thúc — không gửi
        signaling.sendIceCandidate(
          callId: callId,
          targetId: peerId,
          candidate: c,
          sdpMid: candidate.sdpMid ?? '',
          sdpMLineIndex: candidate.sdpMLineIndex ?? 0,
        );
      };

      final offer = await engine.createOffer();
      signaling.sendSdpOffer(callId: callId, targetId: peerId, sdp: offer.sdp!);
    } catch (e) {
      add(_PeerTerminatedEvent('Không thiết lập được kết nối: $e'));
      return;
    }

    _startDurationTimer();

    emit(CallConnectedState(
      callId: callId,
      peerName: currentPeerName ?? 'User',
      callType: currentCallType ?? 'audio',
      isMuted: false,
      isCamDisabled: false,
      isSpeakerOn: true,
      durationSeconds: 0,
    ));
  }

  Future<void> _onPeerTerminated(
      _PeerTerminatedEvent event, Emitter<CallState> emit) async {
    if (state is CallEndedState || state is CallInitialState) return;
    await _cleanupCall();
    emit(CallEndedState(event.reason));
  }

  void _onCallTick(_CallTickEvent event, Emitter<CallState> emit) {
    final s = state;
    if (s is CallConnectedState) {
      emit(s.copyWith(durationSeconds: s.durationSeconds + 1));
    }
  }

  Future<void> _onRejectCall(RejectCallEvent event, Emitter<CallState> emit) async {
    final cId = activeCallId;
    final pId = currentPeerId;
    // Báo cho đầu kia TRƯỚC khi dọn, vì _cleanupCall xoá sạch id.
    if (cId != null && pId != null) {
      signaling.sendCallReject(callId: cId, calleeId: myClientId ?? '', targetId: pId);
    }
    await _cleanupCall();
    emit(CallEndedState('Đã từ chối cuộc gọi'));
  }

  Future<void> _onEndCall(EndCallEvent event, Emitter<CallState> emit) async {
    final cId = activeCallId;
    final pId = currentPeerId;
    if (cId != null && pId != null) {
      signaling.sendCallEnd(callId: cId, targetId: pId);
    }
    await _cleanupCall();
    emit(CallEndedState('Cuộc gọi đã kết thúc'));
  }

  void _onToggleMic(ToggleMicEvent event, Emitter<CallState> emit) {
    engine.toggleMicrophone();
    if (state is CallConnectedState) {
      final curr = state as CallConnectedState;
      emit(curr.copyWith(isMuted: engine.isMicrophoneMuted));
    }
  }

  void _onToggleCam(ToggleCamEvent event, Emitter<CallState> emit) {
    engine.toggleCamera();
    if (state is CallConnectedState) {
      final curr = state as CallConnectedState;
      emit(curr.copyWith(isCamDisabled: engine.isCameraDisabled));
    }
  }

  Future<void> _onSwitchCam(SwitchCamEvent event, Emitter<CallState> emit) async {
    await engine.switchCamera();
  }

  Future<void> _onToggleSpeaker(ToggleSpeakerEvent event, Emitter<CallState> emit) async {
    await engine.toggleSpeaker();
    if (state is CallConnectedState) {
      final curr = state as CallConnectedState;
      emit(curr.copyWith(isSpeakerOn: engine.isSpeakerOn));
    }
  }

  void _onTogglePIP(TogglePIPEvent event, Emitter<CallState> emit) {
    if (state is CallConnectedState) {
      final curr = state as CallConnectedState;
      emit(curr.copyWith(isPIP: !curr.isPIP));
    }
  }

  void _startDurationTimer() {
    _callDurationTimer?.cancel();
    // Timer chạy ngoài handler nên KHÔNG được emit trực tiếp — đẩy sự kiện vào.
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(_CallTickEvent());
    });
  }

  /// Dọn dẹp sau MỘT cuộc gọi — engine vẫn dùng được cho cuộc tiếp theo.
  Future<void> _cleanupCall() async {
    activeCallId = null;
    currentPeerId = null;
    currentPeerName = null;
    currentCallType = null;
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    // stopCall chứ KHÔNG phải dispose: dispose sẽ huỷ renderer và cuộc gọi thứ
    // hai chỉ còn màn hình đen.
    await engine.stopCall();
  }

  @override
  Future<void> close() async {
    _signalingSubscription?.cancel();
    _callDurationTimer?.cancel();
    activeCallId = null;
    currentPeerId = null;
    await engine.dispose();
    signaling.disconnect();
    return super.close();
  }
}
