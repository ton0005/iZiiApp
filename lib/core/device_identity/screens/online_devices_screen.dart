import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../device_discovery_bloc.dart';
import '../device_identity_models.dart';
import '../crypto_service.dart';
import 'dart:convert';

/// Device discovery screen — shows all online devices grouped by user.
/// Accessible from the Chat inbox via the "Online Devices" button.
import '../ble_device_discovery_service.dart';
import '../../database/app_database.dart';

class OnlineDevicesScreen extends StatefulWidget {
  const OnlineDevicesScreen({super.key});

  @override
  State<OnlineDevicesScreen> createState() => _OnlineDevicesScreenState();
}

class _OnlineDevicesScreenState extends State<OnlineDevicesScreen>
    with SingleTickerProviderStateMixin {
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

  late TabController _tabController;
  final BleDeviceDiscoveryService _bleDiscovery = BleDeviceDiscoveryService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Automatically start scanning and advertising when the screen opens
    _bleDiscovery.startScanning();
    _bleDiscovery.startAdvertising();
  }

  @override
  void dispose() {
    _bleDiscovery.stopScanning();
    _bleDiscovery.stopAdvertising();
    _tabController.dispose();
    super.dispose();
  }

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
            '📡 Thiết bị kết nối',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: _secondary,
            labelColor: _textPrimary,
            unselectedLabelColor: _textSecondary,
            tabs: const [
              Tab(text: 'Trực tuyến (Server)'),
              Tab(text: 'Ngoại tuyến (Bluetooth)'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _secondary),
              onPressed: () {
                if (_tabController.index == 0) {
                  context
                      .read<DeviceDiscoveryBloc>()
                      .add(DiscoverOnlineDevicesEvent());
                } else {
                  _bleDiscovery.stopScanning();
                  _bleDiscovery.startScanning();
                }
              },
              tooltip: 'Làm mới',
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Server-based Online Devices
            BlocBuilder<DeviceDiscoveryBloc, DeviceDiscoveryState>(
              builder: (context, state) {
                if (state.status == DeviceDiscoveryStatus.loading &&
                    state.onlineDevices.isEmpty) {
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

            // Tab 2: BLE Nearby Devices
            StreamBuilder<List<LocalBlePeer>>(
              stream: _bleDiscovery.nearbyPeersStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildBleEmptyState();
                }
                return _buildBlePeersList(context, snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBleEmptyState() {
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
              Icons.bluetooth_searching_rounded,
              size: 48,
              color: _secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Đang quét Bluetooth...',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đảm bảo rằng Bluetooth đã bật\nvà thiết bị khác cũng đang chạy iZiiApp.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildBlePeersList(BuildContext context, List<LocalBlePeer> peers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        return _buildBlePeerCard(context, peer)
            .animate()
            .fadeIn(delay: (100 * index).ms, duration: 300.ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildBlePeerCard(BuildContext context, LocalBlePeer peer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Trigger connection & Noise Handshake authentication
            final success =
                await _bleDiscovery.connectAndAuthenticate(peer.deviceId);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Xác thực bảo mật thành công với ${peer.deviceName}!'),
                  backgroundColor: _success,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Không thể kết nối bảo mật tới ${peer.deviceName}.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Platform icon placeholder
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('📱', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),

                // Peer Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              peer.deviceName,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (peer.publicKey.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            DeviceFingerprintBadge(
                              publicKeyBase64: peer.publicKey,
                              color: _secondary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'RSSI: ${peer.rssi} dBm',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Kết nối P2P',
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
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Color(0xFFF43F5E)),
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
              context
                  .read<DeviceDiscoveryBloc>()
                  .add(DiscoverOnlineDevicesEvent());
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, DeviceDiscoveryState state) {
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
              Padding(
                padding: EdgeInsets.only(
                    left: 4, bottom: 8, top: index > 0 ? 16 : 0),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _success.withValues(alpha: 0.15),
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
              ...devices.asMap().entries.map((entry) {
                final i = entry.key;
                final device = entry.value;
                return _buildDeviceCard(context, device)
                    .animate()
                    .fadeIn(
                        delay: (100 * (index * devices.length + i)).ms,
                        duration: 300.ms)
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
              ? _success.withValues(alpha: 0.3)
              : _surfaceLight.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đang mở hội thoại với ${device.deviceName}...',
                  style: GoogleFonts.inter(),
                ),
                backgroundColor: _surfaceCard,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(platformIcon,
                        style: const TextStyle(fontSize: 22)),
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
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (device.fingerprint.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _secondary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                device.fingerprint,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _secondary,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                                color: statusDot.withValues(alpha: 0.5),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
      case 'android':
        return '📱';
      case 'windows':
      case 'macos':
        return '💻';
      case 'linux':
        return '🖥️';
      default:
        return '📟';
    }
  }
}

class DeviceFingerprintBadge extends StatelessWidget {
  final String publicKeyBase64;
  final Color color;

  const DeviceFingerprintBadge({
    super.key,
    required this.publicKeyBase64,
    required this.color,
  });

  Future<String> _getFingerprint() async {
    if (publicKeyBase64.isEmpty) return '';
    final bytes = utf8.encode(publicKeyBase64);
    final hashBytes = await CryptoService().sha256Hash(bytes);
    final hexString =
        hashBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hexString.substring(0, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (publicKeyBase64.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<String>(
      future: _getFingerprint(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data!.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              snapshot.data!,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
