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
          await _connectMediaAsCaller();
        }
      } else if (event == 'call_reject' || event == 'call_end') {
        _cleanupCall();
        emit(CallEndedState(event == 'call_reject' ? 'Call rejected' : 'Call ended'));
      } else if (event == 'sdp_offer') {
        final sdp = data['sdp'];
        if (sdp != null) {
          await engine.setRemoteDescription(sdp, 'offer');
          final answer = await engine.createAnswer();
          signaling.sendSdpAnswer(callId: activeCallId!, targetId: currentPeerId!, sdp: answer.sdp!);
        }
      } else if (event == 'sdp_answer') {
        final sdp = data['sdp'];
        if (sdp != null) {
          await engine.setRemoteDescription(sdp, 'answer');
        }
      } else if (event == 'ice_candidate') {
        final candidate = data['candidate'];
        final sdpMid = data['sdpMid'];
        final sdpMLineIndex = data['sdpMLineIndex'];
        if (candidate != null && sdpMid != null && sdpMLineIndex != null) {
          await engine.addCandidate(candidate, sdpMid, sdpMLineIndex);
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
    if (activeCallId == null || currentPeerId == null) return;

    await engine.initialize();
    await engine.openUserMedia(video: currentCallType == 'video');
    await engine.setupPeerConnection([]);

    engine.onIceCandidate = (candidate) {
      signaling.sendIceCandidate(
        callId: activeCallId!,
        targetId: currentPeerId!,
        candidate: candidate.candidate!,
        sdpMid: candidate.sdpMid!,
        sdpMLineIndex: candidate.sdpMLineIndex!,
      );
    };

    signaling.sendCallAccept(
      callId: activeCallId!,
      calleeId: myClientId ?? '',
      targetId: currentPeerId!,
    );

    _startDurationTimer();

    emit(CallConnectedState(
      callId: activeCallId!,
      peerName: currentPeerName ?? 'User',
      callType: currentCallType!,
      isMuted: false,
      isCamDisabled: false,
      isSpeakerOn: true,
      durationSeconds: 0,
    ));
  }

  Future<void> _connectMediaAsCaller() async {
    await engine.setupPeerConnection([]);

    engine.onIceCandidate = (candidate) {
      signaling.sendIceCandidate(
        callId: activeCallId!,
        targetId: currentPeerId!,
        candidate: candidate.candidate!,
        sdpMid: candidate.sdpMid!,
        sdpMLineIndex: candidate.sdpMLineIndex!,
      );
    };

    final offer = await engine.createOffer();
    signaling.sendSdpOffer(
      callId: activeCallId!,
      targetId: currentPeerId!,
      sdp: offer.sdp!,
    );

    _startDurationTimer();

    emit(CallConnectedState(
      callId: activeCallId!,
      peerName: currentPeerName ?? 'User',
      callType: currentCallType!,
      isMuted: false,
      isCamDisabled: false,
      isSpeakerOn: true,
      durationSeconds: 0,
    ));
  }

  void _onRejectCall(RejectCallEvent event, Emitter<CallState> emit) {
    final cId = activeCallId;
    final pId = currentPeerId;
    _cleanupCall();
    if (cId != null && pId != null) {
      signaling.sendCallReject(callId: cId, calleeId: myClientId ?? '', targetId: pId);
    }
    emit(CallEndedState('Call rejected'));
  }

  void _onEndCall(EndCallEvent event, Emitter<CallState> emit) {
    final cId = activeCallId;
    final pId = currentPeerId;
    _cleanupCall();
    if (cId != null && pId != null) {
      signaling.sendCallEnd(callId: cId, targetId: pId);
    }
    emit(CallEndedState('Call ended'));
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
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state is CallConnectedState) {
        final curr = state as CallConnectedState;
        emit(curr.copyWith(durationSeconds: curr.durationSeconds + 1));
      }
    });
  }

  void _cleanupCall() {
    activeCallId = null;
    currentPeerId = null;
    _callDurationTimer?.cancel();
    engine.dispose();
  }

  @override
  Future<void> close() {
    _signalingSubscription?.cancel();
    _cleanupCall();
    signaling.disconnect();
    return super.close();
  }
}
