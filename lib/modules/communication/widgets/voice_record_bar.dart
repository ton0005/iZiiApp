import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';

/// Thanh ghi âm tin nhắn thoại khi bấm nút Mic.
/// Cung cấp đồng hồ đếm thời gian, hiệu ứng sóng âm động, nút huỷ và nút gửi.
class VoiceRecordBar extends StatefulWidget {
  final bool isDark;
  final ValueChanged<VoiceRecordingResult> onSend;
  final VoidCallback onCancel;

  const VoiceRecordBar({
    super.key,
    required this.isDark,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecordBar> createState() => _VoiceRecordBarState();
}

class VoiceRecordingResult {
  final int durationSeconds;
  final List<double> waveform;
  final String? audioPath;

  const VoiceRecordingResult({
    required this.durationSeconds,
    required this.waveform,
    this.audioPath,
  });
}

class _VoiceRecordBarState extends State<VoiceRecordBar> {
  Timer? _timer;
  int _seconds = 0;
  final List<double> _waveform = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  void _startRecording() {
    _seconds = 0;
    _waveform.clear();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) return;
      setState(() {
        if (t.tick % 5 == 0) {
          _seconds++;
        }
        // Giả lập biên độ sóng âm từ micro (0.2 -> 1.0)
        final amplitude = 0.2 + _random.nextDouble() * 0.8;
        _waveform.add(amplitude);
        if (_waveform.length > 40) {
          _waveform.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _submit() {
    _timer?.cancel();
    // Tạo mảng sóng âm chuẩn hoá khoảng 25-30 mẫu
    final normalizedWaveform = _waveform.isNotEmpty
        ? List<double>.from(_waveform)
        : List.generate(20, (_) => 0.2 + _random.nextDouble() * 0.6);

    widget.onSend(VoiceRecordingResult(
      durationSeconds: max(1, _seconds),
      waveform: normalizedWaveform,
      audioPath: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final accent = ChatTheme.getAccent(widget.isDark);
    final danger = ChatTheme.getDanger(widget.isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: widget.isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
      child: Row(
        children: [
          // Nút huỷ ghi âm (thùng rác)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: danger, size: 24),
            tooltip: 'Cancel recording',
            onPressed: () {
              _timer?.cancel();
              widget.onCancel();
            },
          ),
          const SizedBox(width: 8),

          // Chấm đỏ nhấp nháy báo hiệu đang ghi âm
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Đồng hồ đếm thời lượng
          Text(
            _formatDuration(_seconds),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: ChatTheme.getTextPrimary(widget.isDark),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),

          // Visualizer sóng âm (Waveform animation)
          Expanded(
            child: SizedBox(
              height: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _waveform.map((amp) {
                  return Container(
                    width: 3,
                    height: max(4.0, amp * 28.0),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nút gửi tin nhắn thoại
          CircleAvatar(
            backgroundColor: accent,
            radius: 20,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              tooltip: 'Send voice message',
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
