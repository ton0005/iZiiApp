import 'dart:io' show Platform, File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;

import '../../../core/settings/settings_service.dart';
import '../../../core/server/server_control_panel.dart';
import '../../../core/server/server_manager.dart';
import '../../../core/server/server_admin_service.dart';
import '../../../core/database/database_backup_service.dart';
import '../../../core/enrollment/screens/manage_devices_screen.dart';
import '../../../core/enrollment/screens/enroll_device_screen.dart';
import '../../../core/enrollment/screens/issue_enrollment_screen.dart';
import '../../../core/enrollment/widgets/device_list_view.dart';

/// Settings tab screen for the Mushrooms module.
///
/// Sections:
/// 1. Server Control Panel (Windows only) — Start/Stop/Restart embedded server
/// 2. Sync Configuration — Server URL, auth token
/// 3. Server Configuration (.env) — DB backend, TLS/mTLS, OAuth2 (Admin)
/// 4. Database Backup & Restore — Manage SQLite backups and restores
/// 5. Language & Region
/// 6. About & System Info
class SettingsTabScreen extends StatefulWidget {
  final bool isDark;

  const SettingsTabScreen({
    super.key,
    required this.isDark,
  });

  @override
  State<SettingsTabScreen> createState() => _SettingsTabScreenState();
}

class _SettingsTabScreenState extends State<SettingsTabScreen> {
  final SettingsService _settingsService = SettingsService();
  final DatabaseBackupService _backupService = DatabaseBackupService();

  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isSaving = false;
  String _selectedLanguage = 'en';

  // Backup State
  List<BackupFileInfo> _backups = [];
  bool _isBackupLoading = false;
  String? _activeDbPath;

  // ── Server Configuration (.env từ xa) ────────────────────────────────────
  final ServerAdminService _adminService = ServerAdminService();
  ServerAdminConfig? _serverConfig;
  bool _isConfigLoading = false;
  bool _isConfigSaving = false;
  String? _configError;
  bool _configDirty = false;

  /// Một controller cho mỗi khoá trong .env. Tạo lười khi nạp cấu hình về, để
  /// không phải khai báo 20 biến riêng lẻ.
  final Map<String, TextEditingController> _envControllers = {};

  // ── Danh sách thiết bị nhúng trong tab ────────────────────────────────────
  final GlobalKey<DeviceListViewState> _deviceListKey =
      GlobalKey<DeviceListViewState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBackups();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    for (final c in _envControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Server Configuration (.env)
  // ══════════════════════════════════════════════════════════════════════════

  TextEditingController _envCtrl(String key) {
    return _envControllers.putIfAbsent(key, () {
      final c = TextEditingController(text: _serverConfig?.values[key] ?? '');
      c.addListener(() {
        if (!_configDirty && mounted) setState(() => _configDirty = true);
      });
      return c;
    });
  }

  Future<void> _loadServerConfig() async {
    setState(() {
      _isConfigLoading = true;
      _configError = null;
    });
    try {
      final cfg = await _adminService.fetchConfig();
      if (!mounted) return;
      setState(() {
        _serverConfig = cfg;
        // Nạp giá trị vào controller đã tồn tại, tạo mới nếu chưa có.
        for (final entry in cfg.values.entries) {
          final c = _envControllers.putIfAbsent(entry.key, () {
            final ctrl = TextEditingController();
            ctrl.addListener(() {
              if (!_configDirty && mounted) setState(() => _configDirty = true);
            });
            return ctrl;
          });
          c.text = entry.value;
        }
        _isConfigLoading = false;
        _configDirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfigLoading = false;
        _configError = e.toString();
      });
    }
  }

  Future<void> _saveServerConfig() async {
    setState(() => _isConfigSaving = true);
    try {
      // Chỉ gửi những khoá controller đang giữ. Secret chưa sửa vẫn mang giá
      // trị mask — server hiểu là "giữ nguyên".
      final values = <String, String>{
        for (final e in _envControllers.entries) e.key: e.value.text.trim(),
      };
      // Giữ lại giá trị admin secret vừa nhập TRƯỚC khi _loadServerConfig()
      // ghi đè controller bằng chuỗi mask.
      final newAdminSecret = values['IZIIAPP_ADMIN_SECRET'];
      final newWsSecret = values['IZIIAPP_WS_SECRET'];

      final updated = await _adminService.updateConfig(values);
      if (!mounted) return;
      setState(() {
        _isConfigSaving = false;
        _configDirty = false;
      });
      await _loadServerConfig();
      if (!mounted) return;

      // Đồng bộ WebSocket token cục bộ nếu có cập nhật IZIIAPP_WS_SECRET
      if (updated.contains('IZIIAPP_WS_SECRET') &&
          newWsSecret != null &&
          newWsSecret.isNotEmpty &&
          !newWsSecret.startsWith('•')) {
        await _settingsService.saveWsToken(newWsSecret);
      }

      // Đổi admin secret = tự khoá mình ra ngoài sau khi server khởi động lại,
      // vì Auth Token đang lưu trên máy vẫn là giá trị cũ. Đề nghị cập nhật
      // luôn thay vì để người dùng phát hiện khi đã mất quyền.
      if (updated.contains('IZIIAPP_ADMIN_SECRET') &&
          newAdminSecret != null &&
          newAdminSecret.isNotEmpty) {
        await _offerUpdateLocalAuthToken(newAdminSecret);
        if (!mounted) return;
      }

      _showRestartRequiredDialog(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfigSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  /// Hỏi có cập nhật Auth Token trên máy này thành admin secret mới không.
  ///
  /// Không tự động ghi đè: có trường hợp admin đổi secret trên server M2 từ máy
  /// đang trỏ về M1 — khi đó ghi đè token sẽ làm hỏng kết nối tới M1.
  Future<void> _offerUpdateLocalAuthToken(String newSecret) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Expanded(child: Text('Cập nhật Auth Token trên máy này?')),
          ],
        ),
        content: const Text(
          'Bạn vừa đổi IZIIAPP_ADMIN_SECRET trên máy chủ. Auth Token đang lưu '
          'trên máy này vẫn là giá trị CŨ, nên sau khi server khởi động lại bạn '
          'sẽ mất quyền quản trị.\n\n'
          'Cập nhật ngay để tránh bị khoá ra ngoài?',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _settingsService.saveSyncToken(newSecret);
      if (!mounted) return;
      setState(() => _tokenController.text = newSecret);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Auth Token updated to new admin secret'),
            backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  void _showRestartRequiredDialog(List<String> updatedKeys) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Expanded(child: Text('Restart server')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              updatedKeys.isEmpty
                  ? 'No settings were changed.'
                  : 'Settings ${updatedKeys.length} updated in .env:',
            ),
            if (updatedKeys.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...updatedKeys.map((k) => Text('  • $k',
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            ],
            const SizedBox(height: 14),
            const Text(
              'The server reads its configuration only once at startup, so these changes are NOT yet in effect. '
              'Please restart the server and then check again.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    final url = await _settingsService.getSyncServerUrl();
    final token = await _settingsService.getSyncToken();
    final lang = await _settingsService.getLanguage();
    if (mounted) {
      setState(() {
        _urlController.text = url;
        _tokenController.text = token;
        _selectedLanguage = lang;
      });
    }
  }

  Future<void> _loadBackups() async {
    setState(() => _isBackupLoading = true);
    try {
      final activeFile = await _backupService.getActiveDatabaseFile();
      final backups = await _backupService.listBackups();
      if (mounted) {
        setState(() {
          _activeDbPath = activeFile.path;
          _backups = backups;
          _isBackupLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isBackupLoading = false);
    }
  }

  Future<void> _handleCreateBackup() async {
    try {
      final backupFile = await _backupService.createBackup();
      await _loadBackups();
      if (mounted && backupFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        Text('Backup created: ${p.basename(backupFile.path)}')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Backup error: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _confirmRestore(BackupFileInfo backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Restore Database?'),
          ],
        ),
        content: Text(
          'Restoring "${backup.fileName}" will overwrite the active database. Make sure to restart iZiiApp afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Now'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _backupService.restoreBackup(backup.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '✅ Database restored successfully! Please restart iZiiApp.'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Restore failed: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await _settingsService.saveSyncServerUrl(_urlController.text.trim());
    await _settingsService.saveSyncToken(_tokenController.text.trim());
    await _settingsService.saveLanguage(_selectedLanguage);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Settings saved successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Server Control Panel (Windows Only) ────────
          if (isDesktop && ServerManager.isSupported) ...[
            _buildSectionHeader(
              icon: Icons.dns_rounded,
              title: 'Embedded Server',
              subtitle: 'Manage the built-in iZiiApp sync server',
              color: const Color(0xFF6366F1),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            const ServerControlPanel(),
            const SizedBox(height: 32),
          ],

          // ── Section 2: Sync Configuration ────────────────────────
          _buildSectionHeader(
            icon: Icons.sync_rounded,
            title: 'Sync Server',
            subtitle: 'Configure connection to the sync backend',
            color: const Color(0xFF06B6D4),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSyncConfigCard(isDark),
          const SizedBox(height: 32),

          // ── Section 3: Đăng ký & quản lý thiết bị ─────────────────
          _buildSectionHeader(
            icon: Icons.devices_rounded,
            title: 'Device Enrollment & Management',
            subtitle:
                'Manage device tokens and enrollment for this iZiiApp instance',
            color: const Color(0xFF14B8A6),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildEnrollmentCard(isDark),
          const SizedBox(height: 32),

          // ── Section 4: Server Configuration (.env từ xa) ──────────
          _buildSectionHeader(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Server Configuration (.env)',
            subtitle: 'Database backend · TLS/mTLS · OAuth2 — only for Admin',
            color: const Color(0xFFEF4444),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildServerConfigCard(isDark),
          const SizedBox(height: 32),

          // ── Section 4: Database Backup & Restore ───────────────────
          _buildSectionHeader(
            icon: Icons.storage_rounded,
            title: 'Database Backup & Restore',
            subtitle: 'Backup or restore active SQLite database',
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDatabaseBackupCard(isDark),
          const SizedBox(height: 32),

          // ── Section 5: Language & Region ──────────────────────────
          _buildSectionHeader(
            icon: Icons.translate_rounded,
            title: 'Language & Region',
            subtitle: 'Interface display language',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildLanguageCard(isDark),
          const SizedBox(height: 32),

          // ── Section 6: About & System Info ────────────────────────
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Version and system information',
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildAboutCard(isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Section Header
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Sync Configuration Card
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSyncConfigCard(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Server URL', isDark),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _urlController,
            hint: 'http://127.0.0.1:8080',
            icon: Icons.link_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildLabel('Auth Token (Optional)', isDark),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _tokenController,
            hint: 'Enter token if authentication is enabled',
            icon: Icons.key_rounded,
            isDark: isDark,
            obscure: true,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Enrollment Card — đăng ký & quản lý thiết bị
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEnrollmentCard(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNotice(
            icon: Icons.shield_rounded,
            color: const Color(0xFF14B8A6),
            text:
                'Each device receives its OWN token via a QR code or an NFC tag  — '
                'not sharing the system secret. If a device is lost, only that '
                'device is revoked, not the entire factory configuration.',
            isDark: isDark,
          ),
          const SizedBox(height: 8),

          // ── Danh sách thiết bị — NHÚNG THẲNG, không phải điều hướng ───────
          //
          // Lazy-load: chỉ gọi /admin/devices khi người dùng thực sự mở nhóm
          // này ra. Tab Settings mở rất thường xuyên, gọi API mỗi lần vừa lãng
          // phí vừa hiện lỗi 401 với người không phải admin.
          _buildConfigGroup(
            isDark: isDark,
            icon: Icons.list_alt_rounded,
            title: 'Device List',
            color: const Color(0xFF14B8A6),
            onExpansionChanged: (expanded) {
              if (expanded && _deviceListKey.currentState?.hasLoaded != true) {
                _deviceListKey.currentState?.reload();
              }
            },
            children: [
              DeviceListView(
                key: _deviceListKey,
                shrinkWrap: true,
                onRequestNewCode: _openIssueEnrollment,
              ),
            ],
          ),

          const Divider(height: 1),

          // Cấp mã cho máy khác
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.qr_code_2_rounded, color: Color(0xFF14B8A6)),
            title: const Text('Issue a registration code'),
            subtitle:
                const Text('Create a QR code or NFC tag for a new device'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openIssueEnrollment,
          ),
          const Divider(height: 1),

          // Máy mới tự đăng ký — BẮT BUỘC là màn hình riêng, xem ghi chú dưới.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_scanner_rounded,
                color: Color(0xFF6366F1)),
            title: const Text('Enroll this device'),
            subtitle: const Text(
                'Scan a QR code or tap an NFC tag provided by your administrator'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              // Camera preview của mobile_scanner cần toàn màn hình và vòng đời
              // riêng để giải phóng camera khi thoát — không nhúng inline được.
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const EnrollDeviceScreen()),
              );
              if (ok == true && mounted) {
                await _loadSettings();
                _deviceListKey.currentState?.reload();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Device enrolled successfully.')),
                  );
                }
              }
            },
          ),
          const Divider(height: 1),

          // Lối vào màn hình đầy đủ, hữu ích khi danh sách dài.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_full_rounded,
                color: Color(0xFF94A3B8)),
            title: const Text('Open Full Management Screen'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageDevicesScreen()),
              );
              _deviceListKey.currentState?.reload();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openIssueEnrollment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IssueEnrollmentScreen()),
    );
    _deviceListKey.currentState?.reload();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Server Configuration Card (.env qua /admin/config)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildServerConfigCard(bool isDark) {
    final cfg = _serverConfig;

    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thanh hành động ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  cfg == null
                      ? 'Server configuration not loaded.'
                      : '${cfg.serverId}  ·  zone ${cfg.zone}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isConfigLoading ? null : _loadServerConfig,
                icon: _isConfigLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                    _isConfigLoading ? 'Loading...' : 'Load Configuration'),
              ),
            ],
          ),

          if (_configError != null) ...[
            const SizedBox(height: 10),
            _buildNotice(
              icon: Icons.error_outline_rounded,
              color: const Color(0xFFEF4444),
              text: _configError!,
              isDark: isDark,
            ),
          ],

          if (cfg == null) ...[
            const SizedBox(height: 12),
            _buildNotice(
              icon: Icons.info_outline_rounded,
              color: const Color(0xFF6366F1),
              text:
                  'Press "Load Configuration" to read the .env file from the server. An Auth Token '
                  'is required in the Sync Server section to match IZIIAPP_SERVER_SECRET.',
              isDark: isDark,
            ),
          ] else ...[
            const SizedBox(height: 14),
            _buildRuntimeStatus(cfg, isDark),
            const SizedBox(height: 6),
            Text(
              'File: ${cfg.envFile}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 14),

            // ── Nhóm 1: Danh tính & Mesh ─────────────────────────────────
            _buildConfigGroup(
              isDark: isDark,
              icon: Icons.hub_rounded,
              title: 'Identity & Mesh',
              color: const Color(0xFF06B6D4),
              children: [
                _envField('IZIIAPP_SERVER_ID', 'server-m1', Icons.badge_rounded,
                    isDark,
                    help:
                        'Must be UNIQUE on each machine. If identical, the two servers '
                        'will ignore each other and the mesh will not synchronize.'),
                _envField('IZIIAPP_ZONE', 'M1', Icons.map_rounded, isDark),
                _envField('IZIIAPP_PEERS', 'https://192.168.1.11:8080,...',
                    Icons.lan_rounded, isDark,
                    help:
                        'Declare things explicitly, because enterprise firewalls, don’t rely solely on mDNS — especially in hotspot mode.'
                        'and enterprise VLANs often block multicast.'),
                _envField('IZIIAPP_SYNC_INTERVAL_SECONDS', '45',
                    Icons.timer_rounded, isDark),
                _envField(
                    'IZIIAPP_SERVER_SECRET', '', Icons.vpn_key_rounded, isDark,
                    secret: true,
                    help: 'Only used for /peer-sync/* between servers. '
                        'Must be IDENTICAL on all 3 machines.'),
                _envField('IZIIAPP_WS_SECRET', '', Icons.cable_rounded, isDark,
                    secret: true,
                    help: 'Token for WebSocket /chat. Leave empty to use the '
                        'shared IZIIAPP_SERVER_SECRET.')
              ],
            ),

            // ── Nhóm: Bảo mật & phân quyền (B1) ──────────────────────────
            _buildConfigGroup(
              isDark: isDark,
              icon: Icons.security_rounded,
              title: 'Security & Permissions',
              color: const Color(0xFFEF4444),
              children: [
                _buildNotice(
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFEF4444),
                  text:
                      'Changing IZIIAPP_ADMIN_SECRET will invalidate the current Auth Token for '
                      'this machine after the server restarts. '
                      'The app will prompt you to update it after saving.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _envField('IZIIAPP_ADMIN_SECRET', '',
                    Icons.admin_panel_settings_rounded, isDark,
                    secret: true,
                    help:
                        'A DEDICATED secret for /admin/ do NOT give it to worker devices. '
                        'Leave empty to use the shared IZIIAPP_SERVER_SECRET, meaning any device with the sync token can delete the database.'),
                _buildBoolField(
                    'IZIIAPP_REQUIRE_DEVICE_TOKEN',
                    'The device must be registered before it is allowed to synchronize',
                    isDark,
                    help:
                        '⚠️ Enable this ONLY after ALL devices have finished registering. If you enable it too early… '
                        'the entire factory will lose connectivity at the same time. The server will reject'
                        'if no device has registered yet.'),
                _envField('IZIIAPP_ENROLLMENT_TOKEN_TTL', '600',
                    Icons.hourglass_bottom_rounded, isDark,
                    help:
                        'How long the enrollment token is valid (in seconds). 600 = 10 minutes. Increase if '
                        'you are using NFC tags attached to walls, for example 3600 for a shift.'),
              ],
            ),

            // ── Nhóm 2: Database backend ─────────────────────────────────
            _buildConfigGroup(
              isDark: isDark,
              icon: Icons.storage_rounded,
              title: 'Database Backend (6.3)',
              color: const Color(0xFF10B981),
              children: [
                _buildBackendSelector(isDark),
                const SizedBox(height: 12),
                _envField(
                    'IZIIAPP_PG_DSN',
                    'postgresql://izii:matkhau@192.168.1.50:5432/iziiapp',
                    Icons.link_rounded,
                    isDark,
                    secret: true,
                    help:
                        'Required when selecting postgres. Run migrate_to_postgres.py '
                        'BEFORE changing the backend, otherwise it will start with an empty DB.'),
                _envField(
                    'IZIIAPP_PG_POOL_MIN', '1', Icons.remove_rounded, isDark),
                _envField(
                    'IZIIAPP_PG_POOL_MAX', '10', Icons.add_rounded, isDark),
                _envField(
                    'IZIIAPP_SERVER_DB_PATH',
                    '(default: server/data/iziiapp.db)',
                    Icons.folder_rounded,
                    isDark),
              ],
            ),

            // ── Nhóm 3: TLS / mTLS ───────────────────────────────────────
            _buildConfigGroup(
              isDark: isDark,
              icon: Icons.lock_rounded,
              title: 'TLS / mTLS cho Peer-Sync (6.4)',
              color: const Color(0xFF8B5CF6),
              children: [
                _buildNotice(
                  icon: Icons.terminal_rounded,
                  color: const Color(0xFF8B5CF6),
                  text: 'Generate the certificate on the server first:\n'
                      'cd server  →  .\\gen_dev_certs.ps1\n'
                      'Then fill in the path below and ENABLE it simultaneously on all three machines. '
                      'Mixing http with https will break peer‑sync at the handshake stage.',
                  isDark: isDark,
                  mono: true,
                ),
                const SizedBox(height: 12),
                _buildCertStatus(cfg, isDark),
                const SizedBox(height: 12),
                _envField('IZIIAPP_TLS_CERT_FILE', 'certs/server-m1.crt',
                    Icons.description_rounded, isDark),
                _envField('IZIIAPP_TLS_KEY_FILE', 'certs/server-m1.key',
                    Icons.key_rounded, isDark),
                _envField('IZIIAPP_TLS_CA_FILE', 'certs/izii-ca.crt',
                    Icons.verified_user_rounded, isDark),
                _buildBoolField('IZIIAPP_TLS_REQUIRE_CLIENT_CERT',
                    'Bắt buộc chứng chỉ client (mTLS thực thụ)', isDark,
                    help: 'Bật thì việc chặn diễn ra ở tầng TLS, trước cả khi '
                        'request tới ứng dụng.'),
                _envField(
                    'IZIIAPP_TLS_ALLOWED_PEER_CNS',
                    'server-m1,server-m2,server-cr',
                    Icons.checklist_rounded,
                    isDark,
                    help:
                        'Leaving this field empty = accept any certificate signed by your own CA.'),
              ],
            ),

            // ── Nhóm 4: OAuth2 chiều ra ──────────────────────────────────
            _buildConfigGroup(
              isDark: isDark,
              icon: Icons.cloud_upload_rounded,
              title: 'OAuth 2.0 — chiều RA (SAP / ERP) (6.4)',
              color: const Color(0xFFF59E0B),
              children: [
                _buildNotice(
                  icon: Icons.info_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  text:
                      'Khác với mTLS ở trên vốn bảo vệ chiều VÀO. Phần này dùng khi '
                      'iZii GỌI RA SAP Event Mesh hoặc OData. Bỏ trống nếu chưa nối ERP.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _envField(
                    'IZIIAPP_OAUTH_TOKEN_URL',
                    'https://<tenant>.authentication.<region>.hana.ondemand.com/oauth/token',
                    Icons.link_rounded,
                    isDark),
                _envField('IZIIAPP_OAUTH_CLIENT_ID', 'sb-xxxxxxxx',
                    Icons.person_rounded, isDark),
                _envField('IZIIAPP_OAUTH_CLIENT_SECRET', '',
                    Icons.password_rounded, isDark,
                    secret: true),
                _envField('IZIIAPP_OAUTH_SCOPE', '(để trống nếu không yêu cầu)',
                    Icons.tune_rounded, isDark),
              ],
            ),

            const SizedBox(height: 18),
            if (_configDirty)
              _buildNotice(
                icon: Icons.edit_note_rounded,
                color: const Color(0xFFF59E0B),
                text: 'Có thay đổi chưa lưu.',
                isDark: isDark,
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isConfigSaving ? null : _saveServerConfig,
                icon: _isConfigSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isConfigSaving ? 'Writing...' : 'Write .env'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Dải trạng thái ĐANG CHẠY — quan trọng vì nó có thể khác giá trị trong
  /// .env khi admin vừa sửa mà chưa khởi động lại server.
  Widget _buildRuntimeStatus(ServerAdminConfig cfg, bool isDark) {
    Widget chip(String label, bool ok, {String? okText, String? offText}) {
      final color = ok ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                ok
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_outline_rounded,
                size: 14,
                color: color),
            const SizedBox(width: 6),
            Text('$label: ${ok ? (okText ?? 'bật') : (offText ?? 'tắt')}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trạng thái đang chạy',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black45)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('DB', cfg.dbBackend == 'postgres',
                okText: 'postgres', offText: 'sqlite'),
            chip('TLS', cfg.tlsEnabled),
            chip('mTLS', cfg.mtlsEnabled),
            chip('OAuth2', cfg.oauthConfigured,
                okText: 'đã cấu hình', offText: 'chưa'),
            chip('Peers', cfg.peersConfigured.isNotEmpty,
                okText: '${cfg.peersConfigured.length}', offText: '0'),
          ],
        ),
      ],
    );
  }

  Widget _buildCertStatus(ServerAdminConfig cfg, bool isDark) {
    const labels = {'cert': 'Chứng chỉ', 'key': 'Khoá riêng', 'ca': 'CA'};
    return Column(
      children: labels.entries.map((e) {
        final exists = cfg.certExists[e.key] ?? false;
        final path = cfg.certPaths[e.key] ?? '';
        final declared = path.isNotEmpty;
        final color = !declared
            ? const Color(0xFF94A3B8)
            : (exists ? const Color(0xFF10B981) : const Color(0xFFEF4444));
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                !declared
                    ? Icons.remove_circle_outline_rounded
                    : (exists
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded),
                size: 15,
                color: color,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(e.value,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54)),
              ),
              Expanded(
                child: Text(
                  !declared
                      ? 'chưa khai báo'
                      : (exists ? path : '$path — KHÔNG TÌM THẤY trên máy chủ'),
                  style: TextStyle(
                      fontSize: 11, fontFamily: 'monospace', color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackendSelector(bool isDark) {
    final ctrl = _envCtrl('IZIIAPP_DB_BACKEND');
    final current = ctrl.text.trim().isEmpty ? 'sqlite' : ctrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('IZIIAPP_DB_BACKEND', isDark),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'sqlite',
                label: Text('SQLite'),
                icon: Icon(Icons.sd_card_rounded, size: 16)),
            ButtonSegment(
                value: 'postgres',
                label: Text('PostgreSQL'),
                icon: Icon(Icons.dns_rounded, size: 16)),
          ],
          selected: {current == 'postgres' ? 'postgres' : 'sqlite'},
          onSelectionChanged: (s) {
            ctrl.text = s.first;
            setState(() => _configDirty = true);
          },
        ),
        const SizedBox(height: 6),
        Text(
          'SQLite chỉ cho MỘT writer — đủ dùng ở biên. Chuyển sang PostgreSQL '
          'khi có nhiều adapter (SAP/OPC/Historian) ghi song song.',
          style: TextStyle(
              fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
        ),
      ],
    );
  }

  Widget _buildBoolField(String key, String label, bool isDark,
      {String? help}) {
    final ctrl = _envCtrl(key);
    final value = ['1', 'true', 'yes'].contains(ctrl.text.trim().toLowerCase());
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: value,
            title: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87)),
            subtitle: Text(key,
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white30 : Colors.black38)),
            onChanged: (v) {
              ctrl.text = v ? 'true' : 'false';
              setState(() => _configDirty = true);
            },
          ),
          if (help != null)
            Text(help,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45)),
        ],
      ),
    );
  }

  Widget _envField(String key, String hint, IconData icon, bool isDark,
      {bool secret = false, String? help}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(key, isDark),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _envCtrl(key),
            hint: hint,
            icon: icon,
            isDark: isDark,
            // Secret KHÔNG obscure: giá trị hiển thị đã là mask "••••••••" nên
            // che thêm chỉ làm admin bối rối không biết đã có giá trị hay chưa.
            obscure: false,
          ),
          if (secret) ...[
            const SizedBox(height: 4),
            Text(
              'Giá trị hiện tại được ẩn. Để nguyên "${_serverConfig?.secretMask ?? '••••••••'}" '
              'nếu không muốn đổi.',
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white38 : Colors.black45),
            ),
          ],
          if (help != null) ...[
            const SizedBox(height: 4),
            Text(help,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black45)),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigGroup({
    required bool isDark,
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
    ValueChanged<bool>? onExpansionChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        onExpansionChanged: onExpansionChanged,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
        leading: Icon(icon, size: 18, color: color),
        title: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ],
      ),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
    bool mono = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontFamily: mono ? 'monospace' : null,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Database Backup & Restore Card
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDatabaseBackupCard(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active DB File Banner
          if (_activeDbPath != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded,
                      size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active DB: $_activeDbPath',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Backups (${_backups.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.backup_rounded, size: 16),
                label: const Text('Create Backup Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _handleCreateBackup,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isBackupLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator()))
          else if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No database backups created yet. Click "Create Backup Now" to create one.',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backups.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final b = _backups[i];
                final sizeMb = (b.sizeBytes / (1024 * 1024)).toStringAsFixed(2);
                final dateStr =
                    "${b.modifiedAt.year}-${b.modifiedAt.month.toString().padLeft(2, '0')}-${b.modifiedAt.day.toString().padLeft(2, '0')} ${b.modifiedAt.hour.toString().padLeft(2, '0')}:${b.modifiedAt.minute.toString().padLeft(2, '0')}";

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_rounded,
                      color: Color(0xFF10B981)),
                  title: Text(
                    b.fileName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  subtitle: Text(
                    '$dateStr • $sizeMb MB',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ),
                  trailing: OutlinedButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 14),
                    label:
                        const Text('Restore', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _confirmRestore(b),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Language & Region Card
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLanguageCard(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display Language',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select interface language',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: _selectedLanguage,
            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedLanguage = val);
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  About Card
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAboutCard(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        children: [
          _buildInfoRow('App Name', 'iZiiApp — Costa Mushrooms', isDark),
          const Divider(height: 20),
          _buildInfoRow('Version', '2.0.0 (Modular Architecture)', isDark),
          const Divider(height: 20),
          _buildInfoRow(
              'Server Engine', 'FastAPI + Uvicorn (SQLite WAL)', isDark),
          const Divider(height: 20),
          _buildInfoRow('Platform', _getPlatformString(), isDark),
          const Divider(height: 20),
          _buildInfoRow('Architecture', 'Repository Pattern + DI', isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Shared Widgets
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E0D9),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white24 : Colors.black26,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon,
            size: 18, color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8F8F6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E0D9),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E0D9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
        ),
      ),
    );
  }

  String _getPlatformString() {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
