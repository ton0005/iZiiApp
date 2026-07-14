import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/server/server_control_panel.dart';
import '../../../core/server/server_manager.dart';

/// Settings tab screen for the Mushrooms module.
///
/// Sections:
/// 1. Server Control Panel (Windows only) — Start/Stop/Restart embedded server
/// 2. Sync Configuration — Server URL, auth token
/// 3. Language & Region
/// 4. About & System Info
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

  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isSaving = false;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

          // ── Section 3: Language & Region ──────────────────────────
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

          // ── Section 4: About & System Info ────────────────────────
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
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05, end: 0);
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
          // Server URL
          _buildLabel('Server URL', isDark),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _urlController,
            hint: 'http://10.146.147.160:8080',
            icon: Icons.link_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Auth Token
          _buildLabel('Auth Token (optional)', isDark),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _tokenController,
            hint: 'Enter authentication token',
            icon: Icons.vpn_key_rounded,
            isDark: isDark,
            obscure: true,
          ),
          const SizedBox(height: 20),

          // Save Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                elevation: 0,
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
  //  Language Card
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLanguageCard(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Display Language', isDark),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLanguageOption(
                flag: '🇬🇧',
                label: 'English',
                code: 'en',
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildLanguageOption(
                flag: '🇻🇳',
                label: 'Tiếng Việt',
                code: 'vi',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String flag,
    required String label,
    required String code,
    required bool isDark,
  }) {
    final isSelected = _selectedLanguage == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedLanguage = code),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFFF59E0B), size: 18),
              ],
            ],
          ),
        ),
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
        prefixIcon: Icon(icon,
            size: 18,
            color: isDark ? Colors.white38 : Colors.black38),
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
          borderSide:
              const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
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
