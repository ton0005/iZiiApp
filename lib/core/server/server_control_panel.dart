import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../features/server_selection/screens/server_selection_screen.dart';
import '../../core/theme/izii_colors.dart';
import 'server_manager.dart';

/// A premium control panel widget for managing the embedded iZiiApp server.
///
/// Features:
/// - Toggle switch to start/stop the server
/// - Live status indicator with animated pulse
/// - Server info: port, uptime, connected devices
/// - Real-time scrolling log viewer
/// - Auto-restart toggle
///
/// Usage: Embed this widget inside the Dashboard or Settings screen.
class ServerControlPanel extends StatefulWidget {
  const ServerControlPanel({super.key});

  @override
  State<ServerControlPanel> createState() => _ServerControlPanelState();
}

class _ServerControlPanelState extends State<ServerControlPanel>
    with TickerProviderStateMixin {
  final ServerManager _serverManager = ServerManager();
  StreamSubscription<String>? _logSubscription;
  final ScrollController _logScrollController = ScrollController();

  // Live stats
  int _onlineDevices = 0;
  Map<String, dynamic>? _serverStatus;
  Timer? _statsTimer;
  bool _showLogs = false;

  @override
  void initState() {
    super.initState();
    _serverManager.addListener(_onServerChanged);

    _logSubscription = _serverManager.logStream.listen((_) {
      if (mounted && _showLogs) {
        setState(() {});
        _scrollToBottom();
      }
    });

    // Refresh stats every 10 seconds if running
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_serverManager.isRunning) _refreshStats();
    });

    if (_serverManager.isRunning) _refreshStats();
  }

  @override
  void dispose() {
    _serverManager.removeListener(_onServerChanged);
    _logSubscription?.cancel();
    _statsTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _onServerChanged() {
    if (mounted) {
      setState(() {});
      if (_serverManager.isRunning) _refreshStats();
    }
  }

  Future<void> _refreshStats() async {
    final devices = await _serverManager.fetchOnlineDeviceCount();
    final status = await _serverManager.fetchServerStatus();
    if (mounted) {
      setState(() {
        _onlineDevices = devices;
        _serverStatus = status;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Don't render on unsupported platforms
    if (!ServerManager.isSupported) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? IZiiColors.darkSurface : IZiiColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusBorderColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusBorderColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──────────────────────────────────────────────
          _buildHeader(isDark),

          // ── Status Cards Row ────────────────────────────────────────
          if (_serverManager.isRunning) ...[
            const Divider(height: 1),
            _buildStatusCards(isDark),
          ],

          // ── Log Viewer (Expandable) ─────────────────────────────────
          if (_showLogs) ...[
            const Divider(height: 1),
            _buildLogViewer(isDark),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Header: Title + Toggle + Expand
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          // Status indicator dot
          _buildStatusDot(),
          const SizedBox(width: 12),

          // Title & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'iZiiApp Server',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white54
                        : Colors.black45,
                  ),
                ),
              ],
            ),
          ),

          // Log toggle button
          IconButton(
            icon: Icon(
              _showLogs ? Icons.terminal_rounded : Icons.terminal_outlined,
              color: _showLogs
                  ? IZiiColors.primary
                  : (isDark ? Colors.white38 : Colors.black26),
              size: 20,
            ),
            tooltip: _showLogs ? 'Hide Logs' : 'Show Logs',
            onPressed: () => setState(() => _showLogs = !_showLogs),
          ),

          // Auto-restart toggle
          IconButton(
            icon: Icon(
              _serverManager.autoRestart
                  ? Icons.autorenew_rounded
                  : Icons.autorenew_outlined,
              color: _serverManager.autoRestart
                  ? IZiiColors.secondary
                  : (isDark ? Colors.white38 : Colors.black26),
              size: 20,
            ),
            tooltip: _serverManager.autoRestart
                ? 'Auto-Restart: ON'
                : 'Auto-Restart: OFF',
            onPressed: () {
              _serverManager.autoRestart = !_serverManager.autoRestart;
            },
          ),

          // Multi-Server Discovery button
          IconButton(
            icon: Icon(
              Icons.lan_outlined,
              color: isDark ? Colors.cyanAccent : IZiiColors.primary,
              size: 20,
            ),
            tooltip: 'Quét & Chọn iZiiApp Server (Multi-Server)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServerSelectionScreen(
                    onConnected: () => Navigator.pop(context),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 4),

          // Power toggle
          _buildPowerToggle(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusDot() {
    final color = _statusColor;
    final isAnimated =
        _serverManager.status == ServerStatus.running ||
        _serverManager.status == ServerStatus.starting;

    Widget dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );

    if (isAnimated) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 0.85, end: 1.15, duration: 800.ms);
    }

    return dot;
  }

  Widget _buildPowerToggle(bool isDark) {
    final isLoading = _serverManager.status == ServerStatus.starting ||
        _serverManager.status == ServerStatus.stopping;

    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _toggleServer,
        style: ElevatedButton.styleFrom(
          backgroundColor: _serverManager.isRunning
              ? IZiiColors.error.withValues(alpha: 0.15)
              : IZiiColors.success.withValues(alpha: 0.15),
          foregroundColor:
              _serverManager.isRunning ? IZiiColors.error : IZiiColors.success,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    _serverManager.isRunning
                        ? IZiiColors.error
                        : IZiiColors.success,
                  ),
                ),
              )
            : Icon(
                _serverManager.isRunning
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                size: 18,
              ),
        label: Text(
          isLoading
              ? (_serverManager.status == ServerStatus.starting
                  ? 'Starting...'
                  : 'Stopping...')
              : (_serverManager.isRunning ? 'Stop' : 'Start'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Status Cards
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusCards(bool isDark) {
    final totalRecords = _serverStatus?['total_records'] ?? 0;
    final tables = _serverStatus?['tables'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.wifi_tethering_rounded,
            label: 'Port',
            value: '${_serverManager.port}',
            color: IZiiColors.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            icon: Icons.timer_outlined,
            label: 'Uptime',
            value: _serverManager.uptimeString,
            color: IZiiColors.secondary,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            icon: Icons.devices_rounded,
            label: 'Devices',
            value: '$_onlineDevices',
            color: IZiiColors.success,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            icon: Icons.storage_rounded,
            label: 'Records',
            value: _formatCount(totalRecords),
            color: IZiiColors.accent,
            isDark: isDark,
          ),
          if (tables.isNotEmpty) ...[
            const SizedBox(width: 10),
            _buildStatCard(
              icon: Icons.table_chart_outlined,
              label: 'Tables',
              value: '${tables.length}',
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Log Viewer
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLogViewer(bool isDark) {
    final logs = _serverManager.logBuffer;

    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D1117)
            : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white10
              : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          // Log toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(width: 6),
                Text(
                  'Server Logs (${logs.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    _serverManager.clearLogs();
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ],
            ),
          ),

          // Log content
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _logScrollController,
                    child: ListView.builder(
                      controller: _logScrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Text(
                            logs[index],
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 11,
                              height: 1.4,
                              color: _getLogColor(logs[index], isDark),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Actions
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleServer() async {
    if (_serverManager.isRunning) {
      await _serverManager.stopServer();
    } else {
      await _serverManager.startServer();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════════════════════════════════════════

  Color get _statusColor {
    switch (_serverManager.status) {
      case ServerStatus.running:
        return IZiiColors.success;
      case ServerStatus.starting:
      case ServerStatus.stopping:
        return IZiiColors.accent;
      case ServerStatus.error:
        return IZiiColors.error;
      case ServerStatus.stopped:
        return Colors.grey;
    }
  }

  Color get _statusBorderColor {
    switch (_serverManager.status) {
      case ServerStatus.running:
        return IZiiColors.success;
      case ServerStatus.starting:
        return IZiiColors.accent;
      case ServerStatus.error:
        return IZiiColors.error;
      default:
        return Colors.transparent;
    }
  }

  String get _statusSubtitle {
    switch (_serverManager.status) {
      case ServerStatus.running:
        return 'Running on port ${_serverManager.port} • $_onlineDevices device(s) online';
      case ServerStatus.starting:
        return 'Starting Uvicorn ASGI server...';
      case ServerStatus.stopping:
        return 'Shutting down gracefully...';
      case ServerStatus.error:
        return 'Failed to start — check logs for details';
      case ServerStatus.stopped:
        return 'Server is offline. Tap Start to launch.';
    }
  }

  Color _getLogColor(String line, bool isDark) {
    if (line.contains('❌') || line.contains('ERROR') || line.contains('[STDERR]')) {
      return IZiiColors.error;
    }
    if (line.contains('⚠️') || line.contains('WARNING')) {
      return IZiiColors.accent;
    }
    if (line.contains('✅') || line.contains('success')) {
      return IZiiColors.success;
    }
    if (line.contains('🔐') || line.contains('🔑')) {
      return IZiiColors.secondary;
    }
    if (line.contains('[SERVER]')) {
      return isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);
    }
    return isDark ? Colors.white60 : Colors.black54;
  }

  String _formatCount(dynamic count) {
    if (count is int) {
      if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
      return '$count';
    }
    return '$count';
  }
}
