import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../settings/settings_service.dart';
import '../sync_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();

  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _isSaving = false;
  bool _isManualSyncing = false;
  String _connectionStatus = 'Đang kiểm tra...';
  bool _isOnline = false;
  String? _lastSyncTime;
  final List<String> _localLogs = [];
  StreamSubscription<String>? _logSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadSettings();
    _checkNetwork();

    // Listen to real-time logs from SyncService
    _logSubscription = _syncService.syncLogStream.listen((log) {
      if (mounted) {
        setState(() {
          _localLogs.insert(0, log);
        });
      }
    });

    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _updateConnectionState(results);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _logSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final url = await _settingsService.getSyncServerUrl();
    final token = await _settingsService.getSyncToken();
    final lastSync = await _settingsService.getLastSyncTimestamp();

    setState(() {
      _urlController.text = url;
      _tokenController.text = token;
      if (lastSync != null) {
        final parsed = DateTime.tryParse(lastSync);
        if (parsed != null) {
          _lastSyncTime =
              '${parsed.day}/${parsed.month} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        }
      }
    });
  }

  Future<void> _checkNetwork() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionState(result);
  }

  void _updateConnectionState(List<ConnectivityResult> results) {
    if (mounted) {
      setState(() {
        _isOnline = !results.contains(ConnectivityResult.none);
        _connectionStatus =
            _isOnline ? 'Trực tuyến (Connected)' : 'Ngoại tuyến (Offline)';
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    await _settingsService.saveSyncServerUrl(url);
    await _settingsService.saveSyncToken(token);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình API Server thành công!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _runSync() async {
    if (_isManualSyncing) return;
    setState(() {
      _isManualSyncing = true;
    });
    _spinController.repeat();

    final success = await _syncService.triggerSync();

    if (mounted) {
      setState(() {
        _isManualSyncing = false;
      });
      _spinController.stop();
      _loadSettings(); // Reload last sync timestamp

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Đồng bộ hoàn tất!'
              : 'Đồng bộ thất bại. Vui lòng kiểm tra lại cấu hình.'),
          backgroundColor:
              success ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đồng bộ Dữ liệu',
            style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Sync Status Header Card ---
            _buildStatusCard(),
            const SizedBox(height: 20),

            // --- Server Configurations ---
            _buildConfigCard(),
            const SizedBox(height: 20),

            // --- Sync Progress Logs ---
            _buildLogsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1).withOpacity(0.04),
              const Color(0xFF06B6D4).withOpacity(0.04),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? const Color(0xFF10B981).withOpacity(0.12)
                        : const Color(0xFFF59E0B).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: _isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trạng thái kết nối',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _connectionStatus,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lần đồng bộ cuối',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_lastSyncTime ?? 'Chưa bao giờ',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
                RotationTransition(
                  turns: _spinController,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isManualSyncing ? null : _runSync,
                      icon: const Icon(Icons.sync_rounded, size: 20),
                      label: const Text('Đồng bộ ngay',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildConfigCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings_input_component_outlined,
                    color: Color(0xFF6366F1), size: 20),
                SizedBox(width: 8),
                Text('Cấu hình API Server',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 18),

            // Server URL field
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Địa chỉ Server URL',
                hintText: 'http://127.0.0.1:8080',
                prefixIcon: const Icon(Icons.link_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Token field
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'API Token Bảo mật',
                hintText: 'Nhập token kết nối...',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Lưu cấu hình',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            )
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildLogsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_edu_outlined,
                    color: Color(0xFF06B6D4), size: 20),
                SizedBox(width: 8),
                Text('Nhật ký đồng bộ (Real-time)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: _localLogs.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có log đồng bộ nào phát sinh.',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                            fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _localLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _localLogs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0);
  }
}
