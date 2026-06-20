import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/theme/izii_colors.dart';
import '../../settings/settings_service.dart';
import '../sync_service.dart';
import '../sync_config_repository.dart';
import '../../database/app_database.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final SyncService _syncService = SyncService();
  final SyncConfigRepository _syncConfigRepo = SyncConfigRepository();
  final Connectivity _connectivity = Connectivity();

  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _isSaving = false;
  bool _isManualSyncing = false;
  String _connectionStatus = 'Đang kiểm tra...';
  bool _isOnline = false;
  String? _lastSyncTime;

  // Admin Mode Simulation Switch
  bool _isAdminMode = false;

  // Sync Preferences & Logs
  List<UserSyncConfig> _configs = [];
  Map<String, int> _unsyncedCounts = {};
  List<SyncConflictLog> _conflicts = [];
  List<SyncAuditLog> _audits = [];
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

  Future<String> _getActiveUserId() async {
    try {
      return await _settingsService.getActiveUserId();
    } catch (_) {
      return 'default_user';
    }
  }

  Future<void> _loadSettings() async {
    final url = await _settingsService.getSyncServerUrl();
    final token = await _settingsService.getSyncToken();
    final lastSync = await _settingsService.getLastSyncTimestamp();

    final userId = await _getActiveUserId();
    final configs = await _syncConfigRepo.getConfigsForUser(userId);
    final conflicts = await _syncConfigRepo.getConflictLogs(userId);
    final audits = await _syncConfigRepo.getAuditLogs(userId);

    final Map<String, int> counts = {};
    for (var mod in SyncConfigRepository.modulesMetadata) {
      final key = mod['key'] as String;
      counts[key] = await _syncConfigRepo.getUnsyncedCountForModule(key);
    }

    if (mounted) {
      setState(() {
        _urlController.text = url;
        _tokenController.text = token;
        _configs = configs;
        _unsyncedCounts = counts;
        _conflicts = conflicts;
        _audits = audits;

        if (lastSync != null) {
          final parsed = DateTime.tryParse(lastSync);
          if (parsed != null) {
            _lastSyncTime =
                '${parsed.day}/${parsed.month} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
          }
        }
      });
    }
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

    final success = await _syncService.triggerSync(isManual: true);

    if (mounted) {
      setState(() {
        _isManualSyncing = false;
      });
      _spinController.stop();
      _loadSettings(); // Reload last sync timestamp and configs

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

  Future<void> _toggleModule(UserSyncConfig config, bool value) async {
    final userId = await _getActiveUserId();
    final unsynced = _unsyncedCounts[config.moduleKey] ?? 0;

    if (!value && unsynced > 0) {
      // Prompt user with choices when disabling with unsynced local mutations
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Thay đổi chưa đồng bộ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'Bạn đang có $unsynced thay đổi chưa đồng bộ trong module này. Bạn muốn làm gì trước khi tắt đồng bộ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'disable_only'),
              child: const Text('Tắt & Giữ offline',
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1)),
              onPressed: () => Navigator.pop(context, 'sync_then_disable'),
              child: const Text('Đồng bộ & Tắt',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (result == 'cancel' || result == null) {
        return;
      }

      if (result == 'sync_then_disable') {
        setState(() => _isManualSyncing = true);
        _spinController.repeat();
        await _syncService.triggerSync(isManual: true);
        setState(() => _isManualSyncing = false);
        _spinController.stop();
      }
    }

    try {
      await _syncConfigRepo.saveConfig(
        userId,
        config.moduleKey,
        isEnabled: value,
        syncGranularity: config.syncGranularity,
        selectiveEntities: config.selectiveEntities != null
            ? List<String>.from(jsonDecode(config.selectiveEntities!))
            : null,
        isAdminLocked: _isAdminMode ? config.isAdminLocked : null,
      );
      _loadSettings();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _updateGranularity(
      UserSyncConfig config, String granularity) async {
    final userId = await _getActiveUserId();
    try {
      await _syncConfigRepo.saveConfig(
        userId,
        config.moduleKey,
        isEnabled: config.isEnabled,
        syncGranularity: granularity,
        selectiveEntities: config.selectiveEntities != null
            ? List<String>.from(jsonDecode(config.selectiveEntities!))
            : null,
        isAdminLocked: _isAdminMode ? config.isAdminLocked : null,
      );
      _loadSettings();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _updateSelectiveEntities(
      UserSyncConfig config, String entity, bool selected) async {
    final userId = await _getActiveUserId();
    List<String> entities = [];
    if (config.selectiveEntities != null) {
      entities = List<String>.from(jsonDecode(config.selectiveEntities!));
    }

    if (selected) {
      if (!entities.contains(entity)) entities.add(entity);
    } else {
      entities.remove(entity);
    }

    try {
      await _syncConfigRepo.saveConfig(
        userId,
        config.moduleKey,
        isEnabled: config.isEnabled,
        syncGranularity: config.syncGranularity,
        selectiveEntities: entities,
        isAdminLocked: _isAdminMode ? config.isAdminLocked : null,
      );
      _loadSettings();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _toggleAdminLock(UserSyncConfig config, bool value) async {
    final userId = await _getActiveUserId();
    try {
      await _syncConfigRepo.saveConfig(
        userId,
        config.moduleKey,
        isEnabled: config.isEnabled,
        syncGranularity: config.syncGranularity,
        selectiveEntities: config.selectiveEntities != null
            ? List<String>.from(jsonDecode(config.selectiveEntities!))
            : null,
        isAdminLocked: value,
      );
      _loadSettings();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: $error'),
        backgroundColor: const Color(0xFFF43F5E),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'assignment_turned_in_rounded':
        return Icons.assignment_turned_in_rounded;
      case 'people_alt_rounded':
        return Icons.people_alt_rounded;
      case 'monetization_on_rounded':
        return Icons.monetization_on_rounded;
      case 'cleaning_services_rounded':
        return Icons.cleaning_services_rounded;
      case 'account_balance_rounded':
        return Icons.account_balance_rounded;
      case 'chat_bubble_outline_rounded':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.sync_alt_rounded;
    }
  }

  List<String> _getModuleSubEntities(String moduleKey) {
    switch (moduleKey) {
      case 'project_task':
        return ['projects', 'tasks'];
      case 'leads_management':
        return ['leads', 'contacts'];
      case 'deal_pipeline':
        return ['deals', 'contacts'];
      case 'services':
        return ['service_items', 'service_bookings'];
      case 'accountant':
        return ['accounts', 'journal_entries', 'payroll_events'];
      case 'in_app_chat':
        return ['chat_conversations', 'chat_participants', 'chat_messages'];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đồng bộ & Dữ liệu',
              style: TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
              ),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.sync_rounded), text: 'Cấu hình'),
              Tab(
                  icon: Icon(Icons.history_toggle_off_rounded),
                  text: 'Audit Log'),
              Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Xung đột'),
            ],
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: TabBarView(
          children: [
            // --- Tab 1: Cấu hình Sync ---
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(cardColor),
                  const SizedBox(height: 16),
                  _buildModulesSection(cardColor),
                  const SizedBox(height: 16),
                  _buildConfigCard(cardColor),
                  const SizedBox(height: 16),
                  _buildLogsCard(cardColor),
                ],
              ),
            ),

            // --- Tab 2: Audit Logs ---
            _buildAuditLogsView(cardColor),

            // --- Tab 3: Conflicts Logs ---
            _buildConflictLogsView(cardColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Color cardColor) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
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
                      const Text('Trạng thái kết nối',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(_connectionStatus,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                // Admin mode switch
                Row(
                  children: [
                    const Text('Admin',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    Switch(
                      value: _isAdminMode,
                      onChanged: (val) {
                        setState(() => _isAdminMode = val);
                      },
                      activeThumbColor: const Color(0xFF6366F1),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isManualSyncing ? null : _runSync,
                      icon: const Icon(Icons.sync_rounded, size: 20),
                      label: const Text('Đồng bộ tất cả',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildModulesSection(Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Đồng bộ theo từng Module',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ..._configs.map((config) {
          final isAlwaysOn = config.moduleKey == 'profile_settings';
          final subEntities = _getModuleSubEntities(config.moduleKey);
          final metadata = SyncConfigRepository.modulesMetadata.firstWhere(
            (m) => m['key'] == config.moduleKey,
            orElse: () =>
                {'name_vi': config.moduleKey, 'icon': 'sync_alt_rounded'},
          );

          final int unsyncedCount = _unsyncedCounts[config.moduleKey] ?? 0;
          final bool isLocked = config.isAdminLocked && !_isAdminMode;

          return Card(
            color: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1.5,
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: Icon(_getIconData(metadata['icon'] as String),
                  color: const Color(0xFF6366F1)),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      metadata['name_vi'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (config.isAdminLocked)
                    const Icon(Icons.lock_rounded,
                        size: 16, color: Colors.amber),
                ],
              ),
              subtitle: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: config.isEnabled
                          ? (unsyncedCount > 0
                              ? Colors.amber.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15))
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      config.isEnabled
                          ? (unsyncedCount > 0
                              ? 'Chờ đồng bộ ($unsyncedCount)'
                              : 'Đã đồng bộ')
                          : 'Tắt đồng bộ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: config.isEnabled
                            ? (unsyncedCount > 0 ? Colors.orange : Colors.green)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: isAlwaysOn
                  ? const Text('Bắt buộc',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold))
                  : Switch(
                      value: config.isEnabled,
                      onChanged:
                          isLocked ? null : (val) => _toggleModule(config, val),
                      activeThumbColor: const Color(0xFF06B6D4),
                    ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Admin control to lock module
                      if (_isAdminMode && !isAlwaysOn) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bắt buộc đồng bộ (Admin Lock)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            Switch(
                              value: config.isAdminLocked,
                              onChanged: (val) => _toggleAdminLock(config, val),
                              activeThumbColor: Colors.amber,
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                      // Sync granularity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Chế độ đồng bộ:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          DropdownButton<String>(
                            value: config.syncGranularity,
                            items: const [
                              DropdownMenuItem(
                                  value: 'full',
                                  child: Text('Tự động (Real-time)')),
                              DropdownMenuItem(
                                  value: 'manual',
                                  child: Text('Chỉ khi ấn nút')),
                              DropdownMenuItem(
                                  value: 'selective',
                                  child: Text('Tùy chọn thực thể')),
                            ],
                            onChanged: (isAlwaysOn || isLocked)
                                ? null
                                : (val) {
                                    if (val != null) {
                                      _updateGranularity(config, val);
                                    }
                                  },
                          ),
                        ],
                      ),
                      // Sub-entities list for selective sync
                      if (config.syncGranularity == 'selective' &&
                          subEntities.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Chọn thực thể muốn đồng bộ:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: subEntities.map((ent) {
                            final isSelected = config.selectiveEntities !=
                                    null &&
                                List<String>.from(
                                        jsonDecode(config.selectiveEntities!))
                                    .contains(ent);
                            return FilterChip(
                              label: Text(ent),
                              selected: isSelected,
                              onSelected: (isAlwaysOn || isLocked)
                                  ? null
                                  : (val) {
                                      _updateSelectiveEntities(
                                          config, ent, val);
                                    },
                              selectedColor: const Color(0xFF06B6D4)
                                  .withValues(alpha: 0.25),
                              checkmarkColor: const Color(0xFF06B6D4),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                )
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConfigCard(Color cardColor) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Địa chỉ Server URL',
                hintText: 'http://10.146.147.160:8080',
                prefixIcon: const Icon(Icons.link_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
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
    );
  }

  Widget _buildLogsCard(Color cardColor) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: _localLogs.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có log đồng bộ nào phát sinh.',
                        style: TextStyle(
                            color: Colors.grey,
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
                                fontFamily: 'monospace', fontSize: 11),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsView(Color cardColor) {
    if (_audits.isEmpty) {
      return const Center(
          child: Text('Chưa có lịch sử thay đổi cấu hình đồng bộ.',
              style:
                  TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _audits.length,
      itemBuilder: (context, index) {
        final audit = _audits[index];
        final metadata = SyncConfigRepository.modulesMetadata.firstWhere(
          (m) => m['key'] == audit.moduleKey,
          orElse: () => {'name_vi': audit.moduleKey},
        );

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(
              audit.actionType.contains('lock')
                  ? Icons.security_rounded
                  : Icons.edit_note_rounded,
              color: const Color(0xFF6366F1),
            ),
            title: Text(
              '${metadata['name_vi']} - ${audit.actionType.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Người dùng: ${audit.userId}\nThời gian: ${audit.timestamp.toLocal().toString().substring(0, 19)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConflictLogsView(Color cardColor) {
    if (_conflicts.isEmpty) {
      return const Center(
          child: Text('Chưa ghi nhận xung đột dữ liệu nào.',
              style:
                  TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conflicts.length,
      itemBuilder: (context, index) {
        final conflict = _conflicts[index];
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(
              'Xung đột: ${conflict.targetTable} (${conflict.recordId})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFF43F5E)),
            ),
            subtitle: Text(
              'Giải quyết bằng: ${conflict.resolutionStrategy.toUpperCase()}\nThời gian: ${conflict.timestamp.toLocal().toString().substring(0, 19)}',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dữ liệu cục bộ (Local Data):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(conflict.localData,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                    const SizedBox(height: 8),
                    const Text('Dữ liệu máy chủ (Server Data):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(conflict.serverData,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                    const SizedBox(height: 8),
                    const Text('Dữ liệu đã giải quyết (Resolved):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(conflict.resolvedData,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.green)),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
