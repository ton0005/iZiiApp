import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/izii_colors.dart';

/// A premium card widget that displays a service provider's information
/// with glassmorphic styling, trust-level badges, and animated entrance.
class ProviderCard extends StatelessWidget {
  final String name;
  final String service;
  final String type;
  final double rating;
  final double distance;
  final String trustLevel;
  final int completedOrders;
  final String price;

  /// Index used to stagger entrance animations.
  final int index;

  const ProviderCard({
    super.key,
    required this.name,
    required this.service,
    required this.type,
    required this.rating,
    required this.distance,
    required this.trustLevel,
    required this.completedOrders,
    required this.price,
    this.index = 0,
  });

  // ── Trust-level helpers ──────────────────────────────────────────────

  static const Map<String, Color> _trustColors = {
    'elite': Color(0xFFF59E0B),
    'verified': Color(0xFF10B981),
    'trusted': Color(0xFF6366F1),
    'newcomer': Color(0xFF94A3B8),
  };

  static const Map<String, String> _trustLabels = {
    'elite': 'Elite',
    'verified': 'Verified',
    'trusted': 'Trusted',
    'newcomer': 'Newcomer',
  };

  static const Map<String, IconData> _trustIcons = {
    'elite': Icons.workspace_premium_rounded,
    'verified': Icons.verified_rounded,
    'trusted': Icons.shield_rounded,
    'newcomer': Icons.person_rounded,
  };

  Color get _trustColor => _trustColors[trustLevel] ?? const Color(0xFF94A3B8);
  String get _trustLabel => _trustLabels[trustLevel] ?? 'Newcomer';
  IconData get _trustIcon => _trustIcons[trustLevel] ?? Icons.person_rounded;

  // ── Initials from name ───────────────────────────────────────────────

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ── Rating stars ─────────────────────────────────────────────────────

  Widget _buildStars() {
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B));
        } else if (i == full && hasHalf) {
          return const Icon(Icons.star_half_rounded, size: 14, color: Color(0xFFF59E0B));
        }
        return Icon(Icons.star_outline_rounded,
            size: 14, color: Colors.white.withValues(alpha: 0.2));
      }),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: IZiiColors.darkSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: IZiiColors.primary.withValues(alpha: 0.08),
          highlightColor: IZiiColors.primary.withValues(alpha: 0.04),
          onTap: () {}, // placeholder
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar ──────────────────────────────
                _Avatar(
                  initials: _initials,
                  color: _trustColor,
                ),

                const SizedBox(width: 14),

                // ── Info column ─────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TrustBadge(
                            label: _trustLabel,
                            color: _trustColor,
                            icon: _trustIcon,
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Service
                      Text(
                        service,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Rating + distance
                      Row(
                        children: [
                          _buildStars(),
                          const SizedBox(width: 6),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(Icons.location_on_outlined,
                              size: 14,
                              color: IZiiColors.secondary.withValues(alpha: 0.8)),
                          const SizedBox(width: 3),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Orders + Price + Contact button
                      Row(
                        children: [
                          // Completed orders
                          _InfoPill(
                            icon: Icons.check_circle_outline_rounded,
                            text: '$completedOrders đơn',
                            color: IZiiColors.success,
                          ),
                          const SizedBox(width: 8),
                          // Price
                          _InfoPill(
                            icon: Icons.payments_outlined,
                            text: price,
                            color: IZiiColors.secondary,
                          ),
                          const Spacer(),
                          // Contact button
                          _ContactButton(onTap: () {}),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (80 * index).ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.12,
          end: 0,
          duration: 400.ms,
          delay: (80 * index).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ── Private sub-widgets ─────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _Avatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _TrustBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContactButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: IZiiColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: IZiiColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text(
            'Liên hệ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
