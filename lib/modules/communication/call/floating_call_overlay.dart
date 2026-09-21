// lib/modules/communication/call/floating_call_overlay.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_bloc.dart';
import 'call_screen.dart';

class FloatingCallOverlay extends StatefulWidget {
  final Widget child;

  const FloatingCallOverlay({super.key, required this.child});

  @override
  State<FloatingCallOverlay> createState() => _FloatingCallOverlayState();
}

class _FloatingCallOverlayState extends State<FloatingCallOverlay> {
  Offset _offset = const Offset(20, 100);

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        widget.child,
        BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is CallConnectedState && state.isPIP) {
              final bloc = context.read<CallBloc>();
              final isVideo = state.callType == 'video' && !state.isCamDisabled;

              return Positioned(
                left: _offset.dx,
                top: _offset.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final newX = (_offset.dx + details.delta.dx)
                          .clamp(12.0, screenSize.width - 156.0);
                      final newY = (_offset.dy + details.delta.dy)
                          .clamp(40.0, screenSize.height - 230.0);
                      _offset = Offset(newX, newY);
                    });
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                    bloc.add(TogglePIPEvent());
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: const CallScreen(),
                        ),
                      ),
                    );
                  },
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.transparent,
                    child: Container(
                      width: 144,
                      height: 196,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isVideo
                              ? const Color(0xFF06B6D4).withValues(alpha: 0.6)
                              : const Color(0xFF10B981).withValues(alpha: 0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: (isVideo
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0xFF10B981))
                                .withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            // Video Stream or Audio Avatar
                            if (isVideo)
                              Positioned.fill(
                                child: RTCVideoView(
                                  bloc.engine.remoteRenderer,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                ),
                              )
                            else
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        Color(0xFF065F46),
                                        Color(0xFF0A0F1D)
                                      ],
                                      radius: 0.9,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF059669),
                                                Color(0xFF10B981)
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 14,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              state.peerName.isNotEmpty
                                                  ? state.peerName[0]
                                                      .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            state.peerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Top subtle scrim
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black54,
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Duration Pill (Bottom Left)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _formatDuration(
                                              state.durationSeconds),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // End Call Button (Top Right)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  bloc.add(EndCallEvent());
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF43F5E),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF43F5E)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.call_end_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),

                            // Maximize hint indicator (Top Left)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.open_in_full_rounded,
                                  color: Colors.white70,
                                  size: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
