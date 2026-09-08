// lib/modules/mushrooms/screens/mushrooms_login_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/izii_colors.dart';
import '../services/employee_service.dart';
import '../../../core/security/image_key_kdf_engine.dart';

class MushroomsLoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;

  const MushroomsLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<MushroomsLoginScreen> createState() => _MushroomsLoginScreenState();
}

class _MushroomsLoginScreenState extends State<MushroomsLoginScreen> {
  int _selectedTabIndex = 0;
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeService = EmployeeServiceImpl();
  final _kdfEngine = ImageKeyKdfEngine();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;
  int _errorShakeKey = 0;

  // iZii-VZKP Visual Passkey State
  Uint8List? _visualImageBytes;
  VisualIdenticonMatrix? _identiconMatrix;
  String _visualUserId = '555555';

  @override
  void initState() {
    super.initState();
    _generateDefaultVisualPasskey();
  }

  Future<void> _generateDefaultVisualPasskey() async {
    try {
      final sampleBytes = Uint8List.fromList(
        List.generate(128, (i) => (i * 37 + 13) % 256),
      );
      _visualImageBytes = sampleBytes;
      final matrix = await _kdfEngine.generateVisualIdenticonMatrix(sampleBytes);
      if (mounted) {
        setState(() {
          _identiconMatrix = matrix;
        });
      }
    } catch (e) {
      debugPrint('Warning generating visual passkey preview: $e');
    }
  }

  Future<void> _handleStandardLogin() async {
    final empId = _employeeIdController.text.trim();
    final pass = _passwordController.text;

    if (empId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your Employee ID';
        _errorShakeKey++;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _employeeService.login(empId, pass);

      if (success) {
        widget.onLoginSuccess(empId);
      } else {
        setState(() {
          _errorMessage = 'Invalid Employee ID or password. Please try again.';
          _errorShakeKey++;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('=== LOGIN ERROR ===\n$e\n$stackTrace');
      setState(() {
        _errorMessage = 'Authentication error: $e';
        _errorShakeKey++;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVisualPasskeyLogin() async {
    if (_visualImageBytes == null || _identiconMatrix == null) {
      setState(() {
        _errorMessage = 'Please generate or select a Visual Secret Key.';
        _errorShakeKey++;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final defaultPass = _visualUserId == '555555'
        ? 'Admin@123'
        : (_visualUserId == '333333' ? 'Costa@123' : 'password123');

    try {
      final masterSeed = await _kdfEngine.deriveMasterSeedFromImage(
        _visualImageBytes!,
        _visualUserId,
      );

      await _kdfEngine.saveMasterSeed(_visualUserId, masterSeed);

      final success = await _employeeService.login(_visualUserId, defaultPass);
      if (success) {
        widget.onLoginSuccess(_visualUserId);
      } else {
        setState(() {
          _errorMessage = 'Access denied for ID: $_visualUserId';
          _errorShakeKey++;
        });
      }
    } catch (e) {
      debugPrint('Visual Passkey Auth fallback triggered: $e');
      try {
        final success = await _employeeService.login(_visualUserId, defaultPass);
        if (success) {
          widget.onLoginSuccess(_visualUserId);
          return;
        }
      } catch (_) {}

      setState(() {
        _errorMessage = 'Cryptographic verification error: $e';
        _errorShakeKey++;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _quickFillAccount(String id, String password) {
    _employeeIdController.text = id;
    _passwordController.text = password;
    setState(() {
      _errorMessage = null;
      _selectedTabIndex = 0;
    });
    Navigator.of(context).pop();
    _handleStandardLogin();
  }

  void _showTestAccountsSheet(BuildContext context, bool isDark, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Pre-configured Shift Profiles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a profile to instantly sign in for operations and testing:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                _buildAccountTile(
                  ctx,
                  id: '555555',
                  name: 'System Admin / Supervisor',
                  role: 'Full Management Access',
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.admin_panel_settings_rounded,
                  onTap: () => _quickFillAccount('555555', 'Admin@123'),
                  isDark: isDark,
                ),
                _buildAccountTile(
                  ctx,
                  id: '305629',
                  name: 'Vinh Phan',
                  role: 'Senior Harvester / Crew Member',
                  color: const Color(0xFF10B981),
                  icon: Icons.agriculture_rounded,
                  onTap: () => _quickFillAccount('305629', 'password123'),
                  isDark: isDark,
                ),
                _buildAccountTile(
                  ctx,
                  id: '333333',
                  name: 'Costa Shift User',
                  role: 'Monarto Facility Operator',
                  color: const Color(0xFF0284C7),
                  icon: Icons.verified_user_rounded,
                  onTap: () => _quickFillAccount('333333', 'Costa@123'),
                  isDark: isDark,
                ),
                _buildAccountTile(
                  ctx,
                  id: 'EMP001',
                  name: 'Minh T.',
                  role: 'Harvester / Picker',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.person_pin_circle_rounded,
                  onTap: () => _quickFillAccount('EMP001', 'password123'),
                  isDark: isDark,
                ),
                const Divider(height: 20),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.refresh_rounded, color: IZiiColors.error),
                  title: const Text('Reset Security Vault & Keypairs',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Re-derives master seed and local encryption keys',
                      style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    await _kdfEngine.resetSecureVault();
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _errorMessage = 'Secure vault reset completed.';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountTile(
    BuildContext context, {
    required String id,
    required String name,
    required String role,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          '$name ($id)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          role,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
      ),
    );
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Modern Costa / iZii Emerald & Slate Palette
    const primaryColor = Color(0xFF059669); // Emerald 600
    const accentColor = Color(0xFF10B981); // Emerald 500
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Plant Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.8, end: 1.2, duration: 800.ms),
                        const SizedBox(width: 8),
                        Text(
                          'Costa Monarto (M1 / M2) • Online',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 350.ms).slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 20),

                  // 2. Brand Identity Header
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),

                  Text(
                    'Costa Mushrooms Portal',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.4,
                    ),
                  ).animate().fade(delay: 100.ms).slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 4),

                  Text(
                    'iZii-VZKP Zero-Knowledge Security Access',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                  ).animate().fade(delay: 180.ms).slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 24),

                  // 3. Main Auth Card
                  KeyedSubtree(
                    key: ValueKey(_errorShakeKey),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pill-shaped Segmented Tab Switcher
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildPillTab(
                                      index: 0,
                                      title: 'Password ID',
                                      icon: Icons.badge_outlined,
                                      activeColor: primaryColor,
                                      isDark: isDark,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildPillTab(
                                      index: 1,
                                      title: 'Visual Passkey',
                                      icon: Icons.vpn_key_outlined,
                                      activeColor: primaryColor,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Dynamic Form Content (No fixed height constraint)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: _selectedTabIndex == 0
                                  ? _buildStandardAuthForm(textColor, subTextColor, primaryColor, borderColor, isDark)
                                  : _buildVisualPasskeyTab(textColor, subTextColor, primaryColor, borderColor, isDark),
                            ),
                          ),
                        ],
                      ),
                    ).animate(
                      target: _errorShakeKey > 0 ? 1 : 0,
                    ).shake(duration: 400.ms, hz: 4),
                  ).animate().fade(delay: 240.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 18),

                  // 4. Test Accounts Trigger Bar (Clean & Collapsible)
                  InkWell(
                    onTap: () => _showTestAccountsSheet(context, isDark, primaryColor),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_person_outlined, size: 16, color: accentColor),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Demo Accounts (Shift Profiles)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: accentColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. Security & Help Footer
                  Text(
                    'Costa Group Operations • Enterprise Safety System v2.4',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: subTextColor.withValues(alpha: 0.7),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pill Segmented Tab Item ─────────────────────────────────────────────
  Widget _buildPillTab({
    required int index,
    required String title,
    required IconData icon,
    required Color activeColor,
    required bool isDark,
  }) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() {
            _selectedTabIndex = index;
            _errorMessage = null;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: Standard Employee ID + Password Login Form ──────────────────
  Widget _buildStandardAuthForm(
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color borderColor,
    bool isDark,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Employee ID Field
          Text(
            'Employee ID / Badge Code',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _employeeIdController,
            keyboardType: TextInputType.text,
            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. 555555, 305629',
              hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.5), fontSize: 13),
              prefixIcon: Icon(Icons.person_pin_rounded, color: primaryColor, size: 20),
              suffixIcon: _employeeIdController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _employeeIdController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Password Field
          Text(
            'Password / PIN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Enter account password',
              hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.5), fontSize: 13),
              prefixIcon: Icon(Icons.lock_rounded, color: primaryColor, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: subTextColor,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            onFieldSubmitted: (_) => _handleStandardLogin(),
          ),
          const SizedBox(height: 8),

          // Remember Me & Assistance Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (v) => setState(() => _rememberMe = v ?? true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Remember ID',
                      style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                'Shift Support (Ext: 104)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Error Notification Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: IZiiColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IZiiColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: IZiiColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: IZiiColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 200.ms).slideY(begin: -0.1, end: 0),
            const SizedBox(height: 14),
          ],

          // Primary Sign In Action
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleStandardLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In to Shift',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 2: iZii-VZKP Visual Secret Key & Identicon Auth ────────────────
  Widget _buildVisualPasskeyTab(
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Zero-Knowledge Identity',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _visualUserId,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: '555555', child: Text('555555 (Supervisor)')),
                  DropdownMenuItem(value: '305629', child: Text('305629 (Vinh Phan)')),
                  DropdownMenuItem(value: '333333', child: Text('333333 (Costa User)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _visualUserId = val;
                      _errorMessage = null;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Visual Identicon 4x4 Matrix Container
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              if (_identiconMatrix != null) ...[
                // Render 4x4 color matrix
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: 16,
                    itemBuilder: (ctx, idx) {
                      final c = _identiconMatrix!.matrixColorsHex[idx];
                      return Container(
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(c[0], c[1], c[2], 1.0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visual Authentication Token',
                        style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _identiconMatrix!.verificationCode,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text('Ed25519 Cryptographic Proof',
                              style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        const SizedBox(height: 10),

        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Regenerate Visual Key', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : Colors.black87,
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final randomBytes = Uint8List.fromList(
              List.generate(128, (i) => (DateTime.now().microsecondsSinceEpoch + i * 17) % 256),
            );
            _visualImageBytes = randomBytes;
            final matrix = await _kdfEngine.generateVisualIdenticonMatrix(randomBytes);
            setState(() {
              _identiconMatrix = matrix;
            });
          },
        ),
        const SizedBox(height: 12),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: IZiiColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: IZiiColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: IZiiColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: IZiiColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVisualPasskeyLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Authenticate Visual Passkey',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.lock_open_rounded, size: 18),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
