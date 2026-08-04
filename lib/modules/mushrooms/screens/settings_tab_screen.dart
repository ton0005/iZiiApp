import 'dart:io' show Platform, File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;

import '../../../core/settings/settings_service.dart';
import '../../../core/server/server_control_panel.dart';
import '../../../core/server/server_manager.dart';
import '../../../core/database/database_backup_service.dart';

/// Settings tab screen for the Mushrooms module.
///
/// Sections:
/// 1. Server Control Panel (Windows only) — Start/Stop/Restart embedded server
/// 2. Sync Configuration — Server URL, auth token
/// 3. Database Backup & Restore — Manage SQLite backups and restores
/// 4. Language & Region
/// 5. About & System Info
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
    super.dispose();
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
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Backup created: ${p.basename(backupFile.path)}')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup error: $e'), backgroundColor: Colors.redAccent),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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
              content: Text('✅ Database restored successfully! Please restart iZiiApp.'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.redAccent),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

          // ── Section 3: Database Backup & Restore ───────────────────
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

          // ── Section 4: Language & Region ──────────────────────────
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

          // ── Section 5: About & System Info ────────────────────────
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
                  const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF10B981)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _handleCreateBackup,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isBackupLoading)
            const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))
          else if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No database backups created yet. Click "Create Backup Now" to create one.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
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
                final dateStr = "${b.modifiedAt.year}-${b.modifiedAt.month.toString().padLeft(2, '0')}-${b.modifiedAt.day.toString().padLeft(2, '0')} ${b.modifiedAt.hour.toString().padLeft(2, '0')}:${b.modifiedAt.minute.toString().padLeft(2, '0')}";

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF10B981)),
                  title: Text(
                    b.fileName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                  subtitle: Text(
                    '$dateStr • $sizeMb MB',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                  ),
                  trailing: OutlinedButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 14),
                    label: const Text('Restore', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          _buildInfoRow('Server Engine', 'FastAPI + Uvicorn (SQLite WAL)', isDark),
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
        prefixIcon: Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F8F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
