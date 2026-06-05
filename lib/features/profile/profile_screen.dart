import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/izii_colors.dart';
import 'widgets/trust_score_widget.dart';
import 'widgets/stats_row.dart';
import 'widgets/menu_item.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Gradient Header ──
          SliverToBoxAdapter(
            child: _ProfileHeader(isDark: isDark),
          ),

          // ── Trust Score ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: const TrustScoreWidget(
                  score: 3.2,
                  trustLevel: TrustLevel.newcomer,
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms).scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      delay: 300.ms,
                      curve: Curves.easeOutBack,
                    ),
              ),
            ),
          ),

          // ── Stats Row ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const StatsRow(
                items: [
                  StatItem(
                    icon: Icons.check_circle_outline_rounded,
                    value: '12',
                    label: 'Đơn hoàn thành',
                  ),
                  StatItem(
                    icon: Icons.star_rounded,
                    value: '4.5',
                    label: 'Đánh giá TB',
                  ),
                  StatItem(
                    icon: Icons.people_outline_rounded,
                    value: '3',
                    label: 'Giới thiệu',
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 500.ms)
                  .slideY(begin: 0.15, end: 0, duration: 500.ms, delay: 500.ms),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Menu Section ──
          SliverToBoxAdapter(
            child: _MenuSection(isDark: isDark),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Profile Header
// ═══════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  final bool isDark;

  const _ProfileHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IZiiColors.primary,
            IZiiColors.primary.withOpacity(0.85),
            IZiiColors.secondary.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hồ sơ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  _GlassIconButton(
                    icon: Icons.edit_outlined,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Avatar
              _AvatarWithGradientBorder(initials: 'U')
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 16),

              // Name
              const Text(
                'User Demo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 8),

              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Consumer & Provider',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 10),

              // KYC badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: IZiiColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: IZiiColors.accent.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: IZiiColors.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Chưa xác minh',
                      style: TextStyle(
                        color: IZiiColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Avatar with gradient border
// ═══════════════════════════════════════════════════════════
class _AvatarWithGradientBorder extends StatelessWidget {
  final String initials;

  const _AvatarWithGradientBorder({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            IZiiColors.accent,
            IZiiColors.secondary,
            IZiiColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: IZiiColors.primary.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: IZiiColors.darkSurface,
          border: Border.all(color: IZiiColors.darkBackground, width: 3),
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Glass Icon Button
// ═══════════════════════════════════════════════════════════
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(0.15),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Menu Section
// ═══════════════════════════════════════════════════════════
class _MenuSection extends StatelessWidget {
  final bool isDark;

  const _MenuSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final containerColor = isDark
        ? IZiiColors.darkSurface.withOpacity(0.5)
        : IZiiColors.lightSurface;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              children: _buildMenuItems(context),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 600.ms)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 600.ms);
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final items = <_MenuData>[
      _MenuData(
        icon: Icons.build_circle_outlined,
        title: 'Dịch vụ của tôi',
        color: IZiiColors.primary,
        onTap: () {},
      ),
      _MenuData(
        icon: Icons.inventory_2_outlined,
        title: 'Đơn hàng',
        color: IZiiColors.secondary,
        onTap: () {},
      ),
      _MenuData(
        icon: Icons.people_alt_outlined,
        title: 'Mời bạn bè',
        color: IZiiColors.success,
        onTap: () => context.push('/invite'),
      ),
      _MenuData(
        icon: Icons.settings_outlined,
        title: 'Cài đặt',
        color: const Color(0xFF8B5CF6),
        onTap: () => context.push('/settings'),
      ),
      _MenuData(
        icon: Icons.smart_toy_outlined,
        title: 'Cấu hình AI',
        color: IZiiColors.accent,
        onTap: () {},
      ),
      _MenuData(
        icon: Icons.sync_rounded,
        title: 'Đồng bộ Dữ liệu',
        color: const Color(0xFF06B6D4),
        onTap: () => context.push('/settings/sync'),
      ),
      _MenuData(
        icon: Icons.bar_chart_rounded,
        title: 'Báo cáo',
        color: IZiiColors.secondary,
        onTap: () {},
      ),
      _MenuData(
        icon: Icons.help_outline_rounded,
        title: 'Trợ giúp',
        color: const Color(0xFF64748B),
        onTap: () {},
      ),
      _MenuData(
        icon: Icons.logout_rounded,
        title: 'Đăng xuất',
        color: IZiiColors.error,
        onTap: () => _showLogoutDialog(context),
      ),
    ];

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final isLast = index == items.length - 1;

      return ProfileMenuItem(
        icon: data.icon,
        title: data.title,
        iconColor: data.color,
        showDivider: !isLast,
        onTap: data.onTap,
      );
    }).toList();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IZiiColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Huỷ',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // TODO: Implement actual logout
            },
            child: Text(
              'Đăng xuất',
              style: TextStyle(color: IZiiColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MenuData({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}
