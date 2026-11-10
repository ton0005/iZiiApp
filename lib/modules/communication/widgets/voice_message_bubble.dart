import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';

/// Bong bóng phát tin nhắn thoại (Voice Message Player Bubble).
/// Hỗ trợ thanh sóng âm (waveform), tua tiến độ, nút đổi tốc độ phát (1x, 1.5x, 2x).
class VoiceMessageBubble extends StatefulWidget {
  final int durationSeconds;
  final List<double> waveform;
  final bool isMe;
  final bool isDark;

  const VoiceMessageBubble({
    super.key,
    required this.durationSeconds,
    this.waveform = const [],
    required this.isMe,
    required this.isDark,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _isPlaying = false;
  double _currentProgress = 0.0; // 0.0 -> 1.0
  double _speed = 1.0; // 1.0 -> 1.5 -> 2.0 -> 1.0
  Timer? _playbackTimer;

  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    if (widget.waveform.isNotEmpty) {
      _bars = widget.waveform;
    } else {
      final rnd = Random(widget.durationSeconds);
      _bars = List.generate(24, (_) => 0.2 + rnd.nextDouble() * 0.8);
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      if (_currentProgress >= 1.0) {
        _currentProgress = 0.0;
      }
      setState(() => _isPlaying = true);
      _startTimer();
    }
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    final intervalMs = 100;
    final totalDurationMs = widget.durationSeconds * 1000;

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) return;
      setState(() {
        final step = (intervalMs * _speed) / totalDurationMs;
        _currentProgress += step;
        if (_currentProgress >= 1.0) {
          _currentProgress = 1.0;
          _isPlaying = false;
          _playbackTimer?.cancel();
        }
      });
    });
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
    if (_isPlaying) {
      _startTimer();
    }
  }

  void _seekTo(double ratio) {
    setState(() {
      _currentProgress = ratio.clamp(0.0, 1.0);
    });
  }

  String _formatTime(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString();
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final accent = ChatTheme.getAccent(widget.isDark);
    final activeColor = widget.isMe ? Colors.white : accent;
    final inactiveColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.35)
        : (widget.isDark ? Colors.grey.shade700 : Colors.grey.shade400);

    final currentSeconds = (_currentProgress * widget.durationSeconds).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nút Play / Pause
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.25)
                        : accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: activeColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Waveform Bars (chạm để tua)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barCount = _bars.length;
                    final totalWidth = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final ratio = details.localPosition.dx / totalWidth;
                        _seekTo(ratio);
                      },
                      child: SizedBox(
                        height: 32,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(barCount, (idx) {
                            final barProgress = (idx + 1) / barCount;
                            final isPassed = _currentProgress >= barProgress;
                            final amp = _bars[idx];

                            return Container(
                              width: 3,
                              height: max(4.0, amp * 28.0),
                              decoration: BoxDecoration(
                                color: isPassed ? activeColor : inactiveColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Nút đổi tốc độ (1x / 1.5x / 2x)
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : (widget.isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_speed}x',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Hiển thị thời gian: thời gian hiện tại / tổng thời gian
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Text(
              _isPlaying || _currentProgress > 0
                  ? '${_formatTime(currentSeconds)} / ${_formatTime(widget.durationSeconds)}'
                  : _formatTime(widget.durationSeconds),
              style: TextStyle(
                fontSize: 10,
                color: widget.isMe
                    ? Colors.white70
                    : ChatTheme.getTextMuted(widget.isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
