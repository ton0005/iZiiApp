// lib/modules/communication/call/webrtc_call_engine.dart

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef IceCandidateCallback = void Function(RTCIceCandidate candidate);
typedef RemoteStreamCallback = void Function(MediaStream stream);
typedef ConnectionStateCallback = void Function(RTCPeerConnectionState state);

class WebRTCCallEngine {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  IceCandidateCallback? onIceCandidate;
  RemoteStreamCallback? onRemoteStream;
  ConnectionStateCallback? onConnectionStateChange;

  bool isMicrophoneMuted = false;
  bool isCameraDisabled = false;
  bool isSpeakerOn = true;

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> openUserMedia({bool video = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;
  }

  Future<void> setupPeerConnection(List<Map<String, dynamic>> iceServers) async {
    final Map<String, dynamic> configuration = {
      'iceServers': iceServers.isNotEmpty
          ? iceServers
          : [
              {'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302']},
            ],
      'sdpSemantics': 'unified-plan',
    };

    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    // Add local tracks to peer connection
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    }

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate?.call(candidate);
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      onConnectionStateChange?.call(state);
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) throw Exception('PeerConnection not initialized');
    final RTCSessionDescription offer = await _peerConnection!.createOffer({
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      'optional': [],
    });
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) throw Exception('PeerConnection not initialized');
    final RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      'optional': [],
    });
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(String sdp, String type) async {
    final description = RTCSessionDescription(sdp, type);
    await _peerConnection?.setRemoteDescription(description);
  }

  Future<void> addCandidate(String candidate, String sdpMid, int sdpMLineIndex) async {
    final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    await _peerConnection?.addCandidate(iceCandidate);
  }

  void toggleMicrophone() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      isMicrophoneMuted = !isMicrophoneMuted;
      _localStream!.getAudioTracks()[0].enabled = !isMicrophoneMuted;
    }
  }

  void toggleCamera() {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      isCameraDisabled = !isCameraDisabled;
      _localStream!.getVideoTracks()[0].enabled = !isCameraDisabled;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks()[0];
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> toggleSpeaker() async {
    isSpeakerOn = !isSpeakerOn;
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      await Helper.setSpeakerphoneOn(isSpeakerOn);
    }
  }

  Future<void> dispose() async {
    try {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _peerConnection?.close();
    } catch (_) {}
  }
}
