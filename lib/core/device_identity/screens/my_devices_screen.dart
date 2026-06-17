// =============================================================================
// My Devices Screen — Track 3: Device Identity & E2EE Messaging
// =============================================================================
// Settings → My Trusted Devices screen.
// Shows the current device highlighted at the top, followed by all other
// registered devices with status indicators, device info, and revoke controls.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../device_discovery_bloc.dart';
import '../device_identity_models.dart';
import '../device_identity_service.dart';
import '../device_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Color Constants — matching IZiiColors from the project theme
// ─────────────────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF6366F1); // Electric Indigo
const _kSecondary = Color(0xFF06B6D4); // Cyan
const _kSuccess = Color(0xFF10B981); // Emerald
const _kError = Color(0xFFF43F5E); // Rose
const _kWarning = Color(0xFFF59E0B); // Amber
const _kDarkBg = Color(0xFF0F172A);
const _kDarkSurface = Color(0xFF1E293B);
const _kDarkSurfaceHighlight = Color(0xFF334155);

class MyDevicesScreen extends StatelessWidget {
  const MyDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DeviceDiscoveryBloc(
        identityService: DeviceIdentityService(),
        discoveryService: DeviceDiscoveryService(),
      )..add(LoadMyDevicesEvent()),
      child: const _MyDevicesView(),
    );
  }
}

class _MyDevicesView extends StatelessWidget {
  const _MyDevicesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: _kDarkBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          '🔐 Thiết bị tin cậy',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kSecondary),
            tooltip: 'Làm mới',
            onPressed: () {
              context.read<DeviceDiscoveryBloc>().add(LoadMyDevicesEvent());
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<DeviceDiscoveryBloc, DeviceDiscoveryState>(
        builder: (context, state) {
          // ── Loading State ──
          if (state.status == DeviceDiscoveryStatus.loading) {
            return _buildLoadingState();
          }

          // ── Error State ──
          if (state.status == DeviceDiscoveryStatus.error) {
            return _buildErrorState(context, state.errorMessage);
          }

          // ── Loaded / Empty ──
          if (state.myDevices.isEmpty) {
            return _buildEmptyState();
          }

          return _buildDeviceList(context, state);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loading Shimmer State
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor:
                  AlwaysStoppedAnimation(_kPrimary.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đang tải danh sách thiết bị...',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error State
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildErrorState(BuildContext context, String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kError.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: _kError, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Không thể tải thiết bị',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Đã xảy ra lỗi không xác định.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                context.read<DeviceDiscoveryBloc>().add(LoadMyDevicesEvent());
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty State
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.devices_rounded,
                color: _kPrimary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có thiết bị nào',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thiết bị của bạn sẽ xuất hiện ở đây\nsau khi đăng ký.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Device List — main content
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDeviceList(BuildContext context, DeviceDiscoveryState state) {
    // Separate current device from others
    final currentDevice = state.myDevices
        .where((d) => d.deviceId == state.currentDeviceId)
        .toList();
    final otherDevices = state.myDevices
        .where((d) => d.deviceId != state.currentDeviceId)
        .toList();

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Security Banner ──
              SliverToBoxAdapter(
                child: _buildSecurityBanner()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: -0.1, end: 0),
              ),

              // ── Current Device Section Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'THIẾT BỊ HIỆN TẠI',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kSuccess,
                      letterSpacing: 1.2,
                    ),
                  ),
                ).animate()
                    .fadeIn(duration: 300.ms, delay: 200.ms),
              ),

              // ── Current Device Card ──
              if (currentDevice.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _CurrentDeviceCard(device: currentDevice.first)
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 300.ms)
                        .slideY(begin: 0.15, end: 0),
                  ),
                ),

              // ── Other Devices Section Header ──
              if (otherDevices.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'THIẾT BỊ KHÁC',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${otherDevices.length} thiết bị',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate()
                      .fadeIn(duration: 300.ms, delay: 450.ms),
                ),

              // ── Other Device Cards ──
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final device = otherDevices[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeviceCard(device: device)
                            .animate()
                            .fadeIn(
                              duration: 450.ms,
                              delay: (500 + index * 100).ms,
                            )
                            .slideY(begin: 0.12, end: 0),
                      );
                    },
                    childCount: otherDevices.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),

        // ── Bottom Action Button ──
        _buildBottomAction(context),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Security Info Banner
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSecurityBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _kPrimary.withValues(alpha: 0.12),
              _kSecondary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kSecondary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mã hoá đầu cuối (E2EE)',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mọi tin nhắn được mã hoá X25519 + AES-256-GCM giữa các thiết bị tin cậy.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom Action Button — Approve New Device
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _kDarkSurface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        child: Tooltip(
          message: 'Phase 3 — Sắp ra mắt',
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: null, // Disabled
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                '+ Phê duyệt thiết bị mới',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary.withValues(alpha: 0.3),
                disabledBackgroundColor: _kDarkSurfaceHighlight,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate()
        .fadeIn(duration: 400.ms, delay: 700.ms)
        .slideY(begin: 0.2, end: 0);
  }
}

// =============================================================================
// Current Device Card — highlighted with green border + glow
// =============================================================================

class _CurrentDeviceCard extends StatelessWidget {
  final RemoteDevice device;

  const _CurrentDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kDarkSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kSuccess.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kSuccess.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
        // Glassmorphism effect
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kDarkSurface.withValues(alpha: 0.9),
            _kDarkSurfaceHighlight.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              // Platform icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kSuccess, Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _kSuccess.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _platformEmoji(device.platform),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.deviceName,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (device.fingerprint.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kSuccess.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _kSuccess.withOpacity(0.3)),
                            ),
                            child: Text(
                              device.fingerprint,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kSuccess,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DID: ${_truncateId(device.deviceId)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white38,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // "This device" badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kSuccess.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _kSuccess.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📱', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      'Thiết bị này',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kSuccess,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Info chips row ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: '🟢',
                label: 'Trực tuyến',
                color: _kSuccess,
              ),
              _InfoChip(
                icon: '🔑',
                label: 'Tin cậy',
                color: _kPrimary,
              ),
              _InfoChip(
                icon: '📅',
                label: 'Đăng ký: ${DateFormat('dd/MM/yyyy').format(device.registeredAt)}',
                color: Colors.white38,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Other Device Card — glassmorphism style
// =============================================================================

class _DeviceCard extends StatelessWidget {
  final RemoteDevice device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(device.status);
    final statusEmoji = _statusEmoji(device.status);
    final statusLabel = _statusLabel(device.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        // Glassmorphism
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kDarkSurface.withValues(alpha: 0.85),
            _kDarkSurfaceHighlight.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Icon + Name + Status ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    _platformEmoji(device.platform),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.deviceName,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (device.fingerprint.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _kPrimary.withOpacity(0.3)),
                            ),
                            child: Text(
                              device.fingerprint,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'DID: ${_truncateId(device.deviceId)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white30,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(statusEmoji, style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Bottom Row: Registration date + Revoke button ──
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 6),
              Text(
                'Đăng ký: ${DateFormat('dd/MM/yyyy').format(device.registeredAt)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
              if (device.lastSeenAt != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.access_time_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 4),
                Text(
                  _formatLastSeen(device.lastSeenAt!),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ],
              const Spacer(),
              // Revoke button (disabled)
              Tooltip(
                message: 'Sắp ra mắt',
                child: TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.link_off_rounded, size: 14),
                  label: Text(
                    'Thu hồi',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _kError.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Small Info Chip Widget
// =============================================================================

class _InfoChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Helpers
// =============================================================================

String _platformEmoji(String platform) {
  switch (platform.toLowerCase()) {
    case 'ios':
    case 'android':
      return '📱';
    case 'windows':
    case 'macos':
    case 'linux':
      return '💻';
    case 'ipad':
    case 'tablet':
      return '📟';
    default:
      return '📱';
  }
}

String _truncateId(String id) {
  if (id.length <= 14) return id;
  return '${id.substring(0, 14)}...';
}

Color _statusColor(DevicePresenceStatus status) {
  switch (status) {
    case DevicePresenceStatus.online:
      return _kSuccess;
    case DevicePresenceStatus.idle:
      return _kWarning;
    case DevicePresenceStatus.offline:
      return _kError;
  }
}

String _statusEmoji(DevicePresenceStatus status) {
  switch (status) {
    case DevicePresenceStatus.online:
      return '🟢';
    case DevicePresenceStatus.idle:
      return '🟡';
    case DevicePresenceStatus.offline:
      return '🔴';
  }
}

String _statusLabel(DevicePresenceStatus status) {
  switch (status) {
    case DevicePresenceStatus.online:
      return 'Trực tuyến';
    case DevicePresenceStatus.idle:
      return 'Nhàn rỗi';
    case DevicePresenceStatus.offline:
      return 'Ngoại tuyến';
  }
}

String _formatLastSeen(DateTime lastSeen) {
  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return DateFormat('dd/MM/yyyy').format(lastSeen);
}
