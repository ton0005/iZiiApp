// lib/modules/communication/call/call_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_bloc.dart';

/// Bảng màu chuyên dụng cho giao diện Call / Video Call theo chuẩn thiết kế hiện đại
class CallTheme {
  static const Color bgDark = Color(0xFF0A0F1D);
  static const Color bgSurface = Color(0xFF131B2E);
  static const Color glassFill = Color(0x330F172A);
  static const Color glassBorder = Color(0x26FFFFFF);

  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldGlow = Color(0x4D10B981);
  static const Color crimson = Color(0xFFF43F5E);
  static const Color crimsonGlow = Color(0x4DF43F5E);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanGlow = Color(0x4D06B6D4);
  static const Color amber = Color(0xFFF59E0B);
  static const Color textMuted = Color(0xFF94A3B8);
}

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _pulseController;

  // Video call controls & draggable PiP
  bool _areControlsVisible = true;
  Timer? _controlsTimer;
  Offset _pipPosition = const Offset(20, 70);
  bool _isSwappedVideo = false;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);

    _resetControlsTimer();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    _controlsTimer?.cancel();
    super.dispose();
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _areControlsVisible) {
        setState(() => _areControlsVisible = false);
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
    });
    if (_areControlsVisible) {
      _resetControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallEndedState) {
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.call_end_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.reason,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<CallBloc>();

        if (state is CallRingingIncomingState) {
          return _buildIncomingCallView(context, bloc, state);
        } else if (state is CallRingingOutgoingState) {
          return _buildOutgoingCallView(context, bloc, state);
        } else if (state is CallConnectedState) {
          return _buildConnectedCallView(context, bloc, state);
        }

        return Scaffold(
          backgroundColor: CallTheme.bgDark,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CallTheme.bgSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CallTheme.cyan.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(CallTheme.cyan),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'INITIALIZING SECURE CALL...',
                  style: TextStyle(
                    color: CallTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 1. INCOMING CALL VIEW (Cuộc gọi đến)
  // ==========================================
  Widget _buildIncomingCallView(
      BuildContext context, CallBloc bloc, CallRingingIncomingState state) {
    final isVideo = state.callType == 'video';
    final initial = state.callerName.isNotEmpty ? state.callerName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: CallTheme.bgDark,
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -100,
            left: -100,
            right: -100,
            height: 450,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    (isVideo ? CallTheme.cyan : CallTheme.emerald).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Top Badge: Call Type & Security
                _buildGlassPill(
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      color: isVideo ? CallTheme.cyan : CallTheme.emerald,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVideo ? 'INCOMING HD VIDEO' : 'INCOMING AUDIO CALL',
                      style: TextStyle(
                        color: isVideo ? CallTheme.cyan : CallTheme.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Caller Name & Department / ID
                Text(
                  state.callerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'iZii Secure Network • ID: ${state.callerId.length > 8 ? state.callerId.substring(0, 8) : state.callerId}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CallTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                // Center Pulsing Avatar with Waves
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radar Ripple Waves
                      CustomPaint(
                        painter: _RadarWavesPainter(
                          animation: _rippleController,
                          waveColor: (isVideo ? CallTheme.cyan : CallTheme.emerald).withValues(alpha: 0.35),
                        ),
                        size: const Size(260, 260),
                      ),

                      // Avatar Glow Container
                      ScaleTransition(
                        scale: _pulseController,
                        child: Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isVideo
                                  ? [const Color(0xFF0284C7), const Color(0xFF06B6D4)]
                                  : [const Color(0xFF059669), const Color(0xFF10B981)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isVideo ? CallTheme.cyan : CallTheme.emerald).withValues(alpha: 0.45),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Quick Message Decline Button
                TextButton.icon(
                  onPressed: () => _showQuickReplyDialog(context, bloc),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: CallTheme.textMuted, size: 18),
                  label: const Text(
                    'Reply with Message',
                    style: TextStyle(color: CallTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),

                const SizedBox(height: 28),

                // Call Actions: Reject & Accept
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decline Action
                      _buildBigActionBtn(
                        label: 'Decline',
                        icon: Icons.call_end_rounded,
                        color: CallTheme.crimson,
                        glowColor: CallTheme.crimsonGlow,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          bloc.add(RejectCallEvent());
                        },
                      ),

                      // Accept Action
                      _buildBigActionBtn(
                        label: 'Accept',
                        icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: CallTheme.emerald,
                        glowColor: CallTheme.emeraldGlow,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          bloc.add(AcceptCallEvent());
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. OUTGOING CALL VIEW (Cuộc gọi đi)
  // ==========================================
  Widget _buildOutgoingCallView(
      BuildContext context, CallBloc bloc, CallRingingOutgoingState state) {
    final isVideo = state.callType == 'video';
    final initial = state.calleeName.isNotEmpty ? state.calleeName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: CallTheme.bgDark,
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned(
            top: -80,
            left: -80,
            right: -80,
            height: 400,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.8,
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Top Badge
                _buildGlassPill(
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.phone_forwarded_rounded,
                      color: const Color(0xFF60A5FA),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVideo ? 'CALLING HD VIDEO...' : 'CALLING...',
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                Text(
                  state.calleeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: CallTheme.emerald),
                    SizedBox(width: 6),
                    Text(
                      'End-to-End Encrypted',
                      style: TextStyle(
                        fontSize: 13,
                        color: CallTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Center Pulsing Avatar with Waves
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radar Ripple Waves
                      CustomPaint(
                        painter: _RadarWavesPainter(
                          animation: _rippleController,
                          waveColor: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                        ),
                        size: const Size(260, 260),
                      ),

                      // Avatar
                      ScaleTransition(
                        scale: _pulseController,
                        child: Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Cancel Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: _buildBigActionBtn(
                    label: 'Cancel',
                    icon: Icons.call_end_rounded,
                    color: CallTheme.crimson,
                    glowColor: CallTheme.crimsonGlow,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      bloc.add(EndCallEvent());
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. CONNECTED CALL VIEW (Đã kết nối)
  // ==========================================
  Widget _buildConnectedCallView(
      BuildContext context, CallBloc bloc, CallConnectedState state) {
    final isVideo = state.callType == 'video';

    if (isVideo) {
      return _buildConnectedVideoView(context, bloc, state);
    } else {
      return _buildConnectedAudioView(context, bloc, state);
    }
  }

  // --- 3A. Connected Audio View ---
  Widget _buildConnectedAudioView(
      BuildContext context, CallBloc bloc, CallConnectedState state) {
    final initial = state.peerName.isNotEmpty ? state.peerName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: CallTheme.bgDark,
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    const Color(0xFF065F46).withValues(alpha: 0.25),
                    CallTheme.bgDark,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header Pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // PiP / Minimize
                      _buildRoundIconButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        tooltip: 'Minimize call',
                        onTap: () => bloc.add(TogglePIPEvent()),
                      ),

                      // Duration & HD Audio Badge
                      _buildGlassPill(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: CallTheme.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(state.durationSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(width: 1, height: 12, color: Colors.white24),
                          const SizedBox(width: 10),
                          const Text(
                            'HD VOICE',
                            style: TextStyle(
                              color: CallTheme.emerald,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),

                      // Encryption Icon
                      _buildRoundIconButton(
                        icon: Icons.lock_outline_rounded,
                        tooltip: 'Encrypted',
                        color: CallTheme.emerald,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Peer Name & Status
                Text(
                  state.peerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.isMuted ? 'Microphone Muted' : 'Speaking...',
                  style: TextStyle(
                    fontSize: 14,
                    color: state.isMuted ? CallTheme.amber : CallTheme.emerald,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const Spacer(flex: 2),

                // Avatar with Voice Waves
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!state.isMuted)
                        CustomPaint(
                          painter: _RadarWavesPainter(
                            animation: _pulseController,
                            waveColor: CallTheme.emerald.withValues(alpha: 0.25),
                          ),
                          size: const Size(240, 240),
                        ),
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF047857), Color(0xFF10B981)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CallTheme.emerald.withValues(alpha: 0.4),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Audio Call Control Dock
                _buildAudioDock(bloc, state),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3B. Connected Video View ---
  Widget _buildConnectedVideoView(
      BuildContext context, CallBloc bloc, CallConnectedState state) {
    final isCamOff = state.isCamDisabled;

    // Pick renderers based on swap state
    final mainRenderer = _isSwappedVideo
        ? bloc.engine.localRenderer
        : bloc.engine.remoteRenderer;
    final pipRenderer = _isSwappedVideo
        ? bloc.engine.remoteRenderer
        : bloc.engine.localRenderer;

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _toggleControlsVisibility,
        child: Stack(
          children: [
            // Main Video Stream (Remote)
            Positioned.fill(
              child: isCamOff && _isSwappedVideo
                  ? _buildCamOffPlaceholder(state.peerName)
                  : RTCVideoView(
                      mainRenderer,
                      mirror: _isSwappedVideo,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            ),

            // Subtle Gradient Scrims (Top & Bottom) for high readability
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Draggable Floating PiP Preview (Local Camera)
            Positioned(
              left: _pipPosition.dx,
              top: _pipPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final newX = (_pipPosition.dx + details.delta.dx)
                        .clamp(16.0, screenSize.width - 136.0);
                    final newY = (_pipPosition.dy + details.delta.dy)
                        .clamp(50.0, screenSize.height - 230.0);
                    _pipPosition = Offset(newX, newY);
                  });
                },
                onTap: () {
                  setState(() => _isSwappedVideo = !_isSwappedVideo);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 120,
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF1E293B),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: isCamOff && !_isSwappedVideo
                              ? _buildCamOffMini()
                              : RTCVideoView(
                                  pipRenderer,
                                  mirror: !_isSwappedVideo,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                ),
                        ),
                        // Swap indicator pill
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz_rounded, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  _isSwappedVideo ? 'Remote' : 'You',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top Header Bar (Animated fade when tapped)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _areControlsVisible ? 50 : -80,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _areControlsVisible ? 1.0 : 0.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Minimize to PiP
                    _buildGlassCircleBtn(
                      icon: Icons.keyboard_arrow_down_rounded,
                      tooltip: 'Minimize',
                      onTap: () => bloc.add(TogglePIPEvent()),
                    ),

                    // Peer info & Duration Glass Pill
                    _buildGlassPill(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: CallTheme.emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.peerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(width: 1, height: 12, color: Colors.white24),
                        const SizedBox(width: 10),
                        Text(
                          _formatDuration(state.durationSeconds),
                          style: const TextStyle(
                            color: CallTheme.cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),

                    // Switch Camera Button
                    _buildGlassCircleBtn(
                      icon: Icons.flip_camera_ios_rounded,
                      tooltip: 'Flip Camera',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        bloc.add(SwitchCamEvent());
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Floating Glass Control Dock
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              bottom: _areControlsVisible ? 36 : -110,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _areControlsVisible ? 1.0 : 0.0,
                child: _buildVideoDock(bloc, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DOCK CONTROLS & WIDGET BUILDERS
  // ==========================================

  Widget _buildAudioDock(CallBloc bloc, CallConnectedState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Mic Mute
          _buildDockIconBtn(
            icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: state.isMuted ? 'Unmute' : 'Mute',
            isActive: state.isMuted,
            activeColor: CallTheme.crimson,
            onTap: () {
              HapticFeedback.lightImpact();
              bloc.add(ToggleMicEvent());
            },
          ),

          // Speaker
          _buildDockIconBtn(
            icon: state.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: 'Speaker',
            isActive: state.isSpeakerOn,
            activeColor: CallTheme.cyan,
            onTap: () {
              HapticFeedback.lightImpact();
              bloc.add(ToggleSpeakerEvent());
            },
          ),

          // Camera Toggle
          _buildDockIconBtn(
            icon: state.isCamDisabled ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: 'Video',
            isActive: !state.isCamDisabled,
            activeColor: CallTheme.cyan,
            onTap: () {
              HapticFeedback.lightImpact();
              bloc.add(ToggleCamEvent());
            },
          ),

          // End Call
          _buildBigActionBtn(
            label: 'End',
            icon: Icons.call_end_rounded,
            color: CallTheme.crimson,
            glowColor: CallTheme.crimsonGlow,
            size: 58,
            onTap: () {
              HapticFeedback.mediumImpact();
              bloc.add(EndCallEvent());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoDock(CallBloc bloc, CallConnectedState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Mic
              _buildDockIconBtn(
                icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: state.isMuted ? 'Muted' : 'Mic',
                isActive: state.isMuted,
                activeColor: CallTheme.crimson,
                onTap: () {
                  HapticFeedback.lightImpact();
                  bloc.add(ToggleMicEvent());
                },
              ),

              // Camera On/Off
              _buildDockIconBtn(
                icon: state.isCamDisabled ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                label: state.isCamDisabled ? 'Cam Off' : 'Cam',
                isActive: state.isCamDisabled,
                activeColor: CallTheme.crimson,
                onTap: () {
                  HapticFeedback.lightImpact();
                  bloc.add(ToggleCamEvent());
                },
              ),

              // Switch Front/Back Cam
              _buildDockIconBtn(
                icon: Icons.cameraswitch_rounded,
                label: 'Flip',
                onTap: () {
                  HapticFeedback.lightImpact();
                  bloc.add(SwitchCamEvent());
                },
              ),

              // Speaker
              _buildDockIconBtn(
                icon: state.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                label: 'Speaker',
                isActive: state.isSpeakerOn,
                activeColor: CallTheme.cyan,
                onTap: () {
                  HapticFeedback.lightImpact();
                  bloc.add(ToggleSpeakerEvent());
                },
              ),

              // End Call Action
              _buildBigActionBtn(
                label: 'End',
                icon: Icons.call_end_rounded,
                color: CallTheme.crimson,
                glowColor: CallTheme.crimsonGlow,
                size: 54,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  bloc.add(EndCallEvent());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamOffPlaceholder(String peerName) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded, color: CallTheme.textMuted, size: 54),
            ),
            const SizedBox(height: 16),
            Text(
              '$peerName turned off camera',
              style: const TextStyle(color: CallTheme.textMuted, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamOffMini() {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28),
      ),
    );
  }

  // --- Reusable Component Helpers ---

  Widget _buildGlassPill({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    String? tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBigActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required Color glowColor,
    required VoidCallback onTap,
    double size = 70,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 28,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.48),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDockIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final effectiveColor = isActive ? (activeColor ?? CallTheme.cyan) : Colors.white;
    final bgColor = isActive
        ? (activeColor ?? CallTheme.cyan).withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.08);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(
                color: isActive ? effectiveColor : Colors.white.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: effectiveColor, size: 22),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: effectiveColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showQuickReplyDialog(BuildContext context, CallBloc bloc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final replies = [
          'Tôi đang bận, sẽ gọi lại sau.',
          'Đang trong cuộc họp quan trọng.',
          'Vui lòng để lại tin nhắn trong chat.',
          'Đang lái xe, không tiện nghe máy.',
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quick Reply & Decline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...replies.map(
                  (text) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.send_rounded, color: CallTheme.cyan, size: 20),
                    title: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      bloc.add(RejectCallEvent());
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter vẽ sóng lan toả (Radar concentric waves)
class _RadarWavesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color waveColor;

  _RadarWavesPainter({required this.animation, required this.waveColor})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final progress = (animation.value + (i / 3.0)) % 1.0;
      final radius = 60.0 + (maxRadius - 60.0) * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = waveColor.withValues(alpha: waveColor.a * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - progress);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavesPainter oldDelegate) => true;
}
