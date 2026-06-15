import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../device_discovery_bloc.dart';
import '../device_identity_models.dart';

/// Device discovery screen — shows all online devices grouped by user.
/// Accessible from the Chat inbox via the "Online Devices" button.
class OnlineDevicesScreen extends StatelessWidget {
  const OnlineDevicesScreen({super.key});

  // ── Colors (matching project theme) ──
  static const _surfaceDark = Color(0xFF0F172A);
  static const _surfaceCard = Color(0xFF1E293B);
  static const _surfaceLight = Color(0xFF334155);
  static const _primary = Color(0xFF6366F1);
  static const _secondary = Color(0xFF06B6D4);
  static const _success = Color(0xFF10B981);
  static const _warning = Color(0xFFF59E0B);
  static const _textPrimary = Color(0xFFF8FAFC);
  static const _textSecondary = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DeviceDiscoveryBloc()..add(DiscoverOnlineDevicesEvent()),
      child: Scaffold(
        backgroundColor: _surfaceDark,
        appBar: AppBar(
          backgroundColor: _surfaceDark,
          elevation: 0,
          title: Text(
            '📡 Thiết bị trực tuyến',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _secondary),
              onPressed: () {
                // Reload online devices
                context.read<DeviceDiscoveryBloc>().add(DiscoverOnlineDevicesEvent());
              },
              tooltip: 'Làm mới',
            ),
          ],
        ),
        body: BlocBuilder<DeviceDiscoveryBloc, DeviceDiscoveryState>(
          builder: (context, state) {
            if (state.status == DeviceDiscoveryStatus.loading && state.onlineDevices.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }

            if (state.errorMessage != null && state.onlineDevices.isEmpty) {
              return _buildErrorState(context, state.errorMessage!);
            }

            if (state.onlineDevices.isEmpty) {
              return _buildEmptyState();
            }

            return _buildDeviceList(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _surfaceCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _surfaceLight, width: 1),
            ),
            child: const Icon(
              Icons.devices_other_rounded,
              size: 48,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Không có thiết bị nào trực tuyến',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi các thiết bị khác kết nối tới cùng server,\nchúng sẽ xuất hiện ở đây.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: null, // Placeholder
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text(
              'Quét mã QR để thêm thiết bị',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textSecondary,
              side: const BorderSide(color: _surfaceLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFF43F5E)),
          const SizedBox(height: 16),
          Text(
            'Không thể tải danh sách thiết bị',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<DeviceDiscoveryBloc>().add(DiscoverOnlineDevicesEvent());
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, DeviceDiscoveryState state) {
    // Group devices by userId
    final Map<String, List<RemoteDevice>> grouped = {};
    for (final device in state.onlineDevices) {
      grouped.putIfAbsent(device.userId, () => []).add(device);
    }

    final userIds = grouped.keys.toList();

    return RefreshIndicator(
      color: _primary,
      backgroundColor: _surfaceCard,
      onRefresh: () async {
        context.read<DeviceDiscoveryBloc>().add(DiscoverOnlineDevicesEvent());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: userIds.length,
        itemBuilder: (context, index) {
          final userId = userIds[index];
          final devices = grouped[userId]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User section header
              Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8, top: index > 0 ? 16 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _secondary],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '👤',
                          style: GoogleFonts.inter(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        userId,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${devices.length} thiết bị',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Device cards
              ...devices.asMap().entries.map((entry) {
                final i = entry.key;
                final device = entry.value;
                return _buildDeviceCard(context, device)
                    .animate()
                    .fadeIn(delay: (100 * (index * devices.length + i)).ms, duration: 300.ms)
                    .slideY(begin: 0.1, end: 0);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, RemoteDevice device) {
    final statusDot = device.status == DevicePresenceStatus.online
        ? _success
        : device.status == DevicePresenceStatus.idle
            ? _warning
            : _textSecondary;

    final statusLabel = device.status == DevicePresenceStatus.online
        ? 'Trực tuyến'
        : device.status == DevicePresenceStatus.idle
            ? 'Không hoạt động'
            : 'Ngoại tuyến';

    final platformIcon = _getPlatformIcon(device.platform);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: device.status == DevicePresenceStatus.online
              ? _success.withOpacity(0.3)
              : _surfaceLight.withOpacity(0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navigate to conversation with this device's user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đang mở hội thoại với ${device.deviceName}...',
                  style: GoogleFonts.inter(),
                ),
                backgroundColor: _surfaceCard,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Platform icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(platformIcon, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),

                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'DID: ${device.deviceId.length > 16 ? '${device.deviceId.substring(0, 16)}...' : device.deviceId}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status + Send button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusDot,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusDot.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusDot,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _secondary],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Gửi tin nhắn',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return '📱';
      case 'android':
        return '📱';
      case 'windows':
        return '💻';
      case 'macos':
        return '💻';
      case 'linux':
        return '🖥️';
      default:
        return '📟';
    }
  }
}
