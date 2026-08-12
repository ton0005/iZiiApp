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

  /// Renderer đã khởi tạo chưa. `RTCVideoRenderer` KHÔNG dùng lại được sau khi
  /// dispose, và initialize() hai lần cũng hỏng — nên phải theo dõi trạng thái.
  bool _renderersReady = false;

  Future<void> initialize() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  /// Kết thúc MỘT cuộc gọi nhưng giữ engine dùng được cho cuộc sau.
  ///
  /// Trước đây kết thúc cuộc gọi gọi thẳng [dispose], tức là huỷ luôn hai
  /// renderer. Với CallBloc dùng chung toàn app, cuộc gọi thứ hai sẽ dựng lại
  /// trên renderer đã chết → màn hình đen kèm vòng xoay, đúng triệu chứng
  /// "lần 2, 3 bắt máy không được".
  Future<void> stopCall() async {
    try {
      final pc = _peerConnection;
      _peerConnection = null;
      await pc?.close();
    } catch (_) {}

    try {
      // Tắt mic/camera. Không tắt thì đèn camera vẫn sáng sau khi cúp máy.
      for (final t in _localStream?.getTracks() ?? const []) {
        try {
          await t.stop();
        } catch (_) {}
      }
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    _remoteStream = null;
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();

    // Giữ renderer sống, chỉ gỡ nguồn hình.
    try {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    } catch (_) {}

    onIceCandidate = null;
    onRemoteStream = null;
    onConnectionStateChange = null;
    isMicrophoneMuted = false;
    isCameraDisabled = false;
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

  /// Đếm ICE candidate theo loại — công cụ chẩn đoán quan trọng nhất khi cuộc
  /// gọi không nối được. `host` = 0 nghĩa là máy không thấy giao diện mạng nào
  /// của chính nó, và không có STUN/TURN nào cứu được.
  final Map<String, int> candidateStats = {};

  /// [iceServers] rỗng nghĩa là **không dùng STUN/TURN**, chỉ host candidate.
  ///
  /// Trước đây rỗng lại bị thay bằng STUN của Google. Trong mạng LAN kín (máy
  /// tính chạy server nối vào điểm phát của điện thoại, không có Internet),
  /// yêu cầu STUN sẽ treo tới lúc hết giờ và làm chậm hoặc hỏng cả quá trình
  /// thu thập ICE — trong khi host candidate đã thừa đủ để hai máy cùng LAN
  /// nối thẳng với nhau.
  Future<void> setupPeerConnection(List<Map<String, dynamic>> iceServers) async {
    candidateStats.clear();
    final Map<String, dynamic> configuration = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };
    print('[Call] ICE servers: ${iceServers.isEmpty ? "(không dùng — LAN thuần)" : iceServers}');

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
      final raw = candidate.candidate;
      if (raw != null) {
        // Chuỗi candidate có dạng "... typ host ..." / "typ srflx" / "typ relay".
        final m = RegExp(r'\btyp (\w+)').firstMatch(raw);
        final type = m?.group(1) ?? 'unknown';
        candidateStats[type] = (candidateStats[type] ?? 0) + 1;
        if (candidateStats[type] == 1) {
          print('[Call] ICE candidate đầu tiên loại "$type": $raw');
        }
      }
      onIceCandidate?.call(candidate);
    };

    _peerConnection?.onIceGatheringState = (state) {
      print('[Call] ICE gathering → $state | đã thu: $candidateStats');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          (candidateStats['host'] ?? 0) == 0) {
        print(
          '[Call] ⛔ KHÔNG thu được host candidate nào. Máy không liệt kê được '
          'giao diện mạng của chính nó — thường gặp khi thiết bị đang PHÁT '
          'Wi-Fi (tethering): libwebrtc không nhận diện giao diện ap0/swlan0. '
          'Kiểm tra quyền ACCESS_NETWORK_STATE và thử đổi sang một router thật.',
        );
      }
    };

    _peerConnection?.onIceConnectionState = (state) {
      print('[Call] ICE connection → $state');
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

  /// Đã nhận SDP của đầu kia chưa.
  ///
  /// ICE candidate thường về TRƯỚC SDP answer — mạng LAN nhanh hơn vòng
  /// signaling qua server. Gọi `addCandidate` lúc chưa có remote description
  /// thì WebRTC ném lỗi và candidate mất luôn. Thiếu candidate đúng lúc là
  /// nguyên nhân kinh điển của "máy báo đã kết nối nhưng không nghe thấy gì".
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  Future<void> setRemoteDescription(String sdp, String type) async {
    final description = RTCSessionDescription(sdp, type);
    await _peerConnection?.setRemoteDescription(description);
    _remoteDescriptionSet = true;

    // Nhả hàng đợi candidate đã nhận sớm.
    final queued = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in queued) {
      try {
        await _peerConnection?.addCandidate(c);
      } catch (_) {}
    }
  }

  Future<void> addCandidate(String candidate, String sdpMid, int sdpMLineIndex) async {
    final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    if (!_remoteDescriptionSet || _peerConnection == null) {
      _pendingCandidates.add(iceCandidate);
      return;
    }
    try {
      await _peerConnection!.addCandidate(iceCandidate);
    } catch (_) {}
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

  /// Huỷ hẳn engine. CHỈ gọi khi thoát app hoặc đóng bloc — sau lệnh này
  /// engine không dùng lại được. Kết thúc một cuộc gọi thì dùng [stopCall].
  Future<void> dispose() async {
    await stopCall();
    try {
      if (_renderersReady) {
        await localRenderer.dispose();
        await remoteRenderer.dispose();
        _renderersReady = false;
      }
    } catch (_) {}
  }
}
