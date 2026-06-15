import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/izii_colors.dart';

enum TrustLevel { newcomer, trusted, verified, elite }

class TrustScoreWidget extends StatelessWidget {
  final double score;
  final double maxScore;
  final TrustLevel trustLevel;
  final double size;

  const TrustScoreWidget({
    super.key,
    required this.score,
    this.maxScore = 5.0,
    required this.trustLevel,
    this.size = 140,
  });

  /// Color mapped to each trust level.
  static Color colorForLevel(TrustLevel level) {
    switch (level) {
      case TrustLevel.elite:
        return const Color(0xFFF59E0B); // amber
      case TrustLevel.verified:
        return const Color(0xFF10B981); // emerald
      case TrustLevel.trusted:
        return const Color(0xFF6366F1); // indigo
      case TrustLevel.newcomer:
        return const Color(0xFF94A3B8); // gray
    }
  }

  static String labelForLevel(TrustLevel level) {
    switch (level) {
      case TrustLevel.elite:
        return 'Elite';
      case TrustLevel.verified:
        return 'Verified';
      case TrustLevel.trusted:
        return 'Trusted';
      case TrustLevel.newcomer:
        return 'Newcomer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color levelColor = colorForLevel(trustLevel);
    final String levelLabel = labelForLevel(trustLevel);
    final double fraction = (score / maxScore).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: fraction),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _TrustRingPainter(
                  progress: value,
                  ringColor: levelColor,
                  trackColor:
                      IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.4),
                  strokeWidth: 10,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (value * maxScore).toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: size * 0.26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '/ ${maxScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: size * 0.11,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: levelColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: levelColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Text(
            levelLabel,
            style: TextStyle(
              color: levelColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that draws a circular arc progress ring.
class _TrustRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _TrustRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [
          ringColor.withValues(alpha: 0.6),
          ringColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );

    // Glow dot at the end
    if (progress > 0.01) {
      final angle = -pi / 2 + 2 * pi * progress;
      final dotCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawCircle(
        dotCenter,
        strokeWidth * 0.65,
        Paint()
          ..color = ringColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        dotCenter,
        strokeWidth * 0.38,
        Paint()..color = ringColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrustRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
}
