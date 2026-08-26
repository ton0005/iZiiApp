import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/employee_service.dart';

/// Brand-new Sign In / Sign Up screen for the Costa Mushrooms module.
///
/// Two modes controlled by a toggle:
/// - **Sign In**: Employee ID + Password login.
/// - **Sign Up**: Register a new employee account.
class MushroomsAuthScreen extends StatefulWidget {
  final void Function(String employeeId) onAuthSuccess;

  const MushroomsAuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<MushroomsAuthScreen> createState() => _MushroomsAuthScreenState();
}

class _MushroomsAuthScreenState extends State<MushroomsAuthScreen>
    with SingleTickerProviderStateMixin {
  final EmployeeService _employeeService = EmployeeServiceImpl();

  // Shared state
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Sign In fields
  final _signInIdController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  bool _obscureSignIn = true;

  // Sign Up fields
  final _signUpIdController = TextEditingController();
  final _signUpNameController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();
  bool _obscureSignUp = true;
  bool _obscureSignUpConfirm = true;
  String _selectedRole = 'Growing Specialist';
  String _selectedDepartment = 'Growing';

  static const _roles = [
    'Manager',
    'Supervisor',
    'Growing Specialist',
    'Harvest Picker',
  ];

  static const _departments = [
    'Growing',
    'Harvest',
    'Maintenance',
    'Administration',
  ];

  @override
  void dispose() {
    _signInIdController.dispose();
    _signInPasswordController.dispose();
    _signUpIdController.dispose();
    _signUpNameController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════�  Future<void> _handleSignIn() async {
    final empId = _signInIdController.text.trim();
    final pass = _signInPasswordController.text;

    if (empId.isEmpty) {
      setState(() => _errorMessage = 'Please enter Employee ID.');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _errorMessage = 'Please enter Password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await _employeeService.login(empId, pass);
      if (success) {
        widget.onAuthSuccess(empId);
      } else {
        setState(() => _errorMessage = 'Incorrect Employee ID or password.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Sign Up Handler
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleSignUp() async {
    final empId = _signUpIdController.text.trim();
    final name = _signUpNameController.text.trim();
    final pass = _signUpPasswordController.text;
    final confirm = _signUpConfirmPasswordController.text;

    if (empId.isEmpty || name.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'Confirm password does not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await _employeeService.registerEmployee(
        employeeId: empId,
        name: name,
        role: _selectedRole,
        department: _selectedDepartment,
        password: pass,
      );

      if (success) {
        widget.onAuthSuccess(empId);
      } else {
        setState(() => _errorMessage = 'Employee ID "$empId" already exists. Please choose a different ID.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Registration error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF10B981);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo / Header ──────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 36),
                ).animate().fade(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

                const SizedBox(height: 20),
                Text(
                  'Costa Mushrooms Portal',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ).animate().fade(delay: 100.ms),
                const SizedBox(height: 4),
                Text(
                  _isSignUp ? 'Create a new employee account' : 'Sign in to your account',
                  style: TextStyle(fontSize: 13, color: subTextColor),
                ).animate().fade(delay: 150.ms),

                const SizedBox(height: 28),

                // ── Auth Card ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Mode Toggle ────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildToggleButton('Sign In', !_isSignUp, primaryColor, isDark),
                            _buildToggleButton('Sign Up', _isSignUp, primaryColor, isDark),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Form Content ───────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _isSignUp
                            ? _buildSignUpForm(textColor, subTextColor, primaryColor, isDark)
                            : _buildSignInForm(textColor, subTextColor, primaryColor, isDark),
                      ),

                      // ── Error / Success Messages ──────────────────
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_successMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Submit Button ──────────────────────────────
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : (_isSignUp ? _handleSignUp : _handleSignIn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                ),
                              : Text(
                                  _isSignUp ? 'Register Account' : 'Sign In',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Switch Mode Link ───────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 13, color: subTextColor),
                              children: [
                                TextSpan(text: _isSignUp ? 'Already have an account? ' : "Don't have an account? "),
                                TextSpan(
                                  text: _isSignUp ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(delay: 200.ms).slideY(begin: 0.08, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Toggle Button
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildToggleButton(String label, bool isActive, Color primaryColor, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isSignUp = label == 'Sign Up';
            _errorMessage = null;
            _successMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Sign In Form
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSignInForm(Color textColor, Color subTextColor, Color primaryColor, bool isDark) {
    return Column(
      key: const ValueKey('sign_in'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Employee ID', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signInIdController,
          hint: 'e.g. 555555 or EMP001',
          icon: Icons.badge_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 16),
        _buildLabel('Password', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signInPasswordController,
          hint: 'Enter password',
          icon: Icons.lock_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
          obscure: _obscureSignIn,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignIn ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: subTextColor,
            ),
            onPressed: () => setState(() => _obscureSignIn = !_obscureSignIn),
          ),
          onSubmitted: (_) => _handleSignIn(),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Sign Up Form
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSignUpForm(Color textColor, Color subTextColor, Color primaryColor, bool isDark) {
    return Column(
      key: const ValueKey('sign_up'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Employee ID', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpIdController,
          hint: 'e.g. 100001',
          icon: Icons.badge_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 14),

        _buildLabel('Full Name', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpNameController,
          hint: 'e.g. John Doe',
          icon: Icons.person_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 14),

        // Role & Department row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Role', subTextColor),
                  const SizedBox(height: 6),
                  _buildDropdown<String>(
                    value: _selectedRole,
                    items: _roles,
                    isDark: isDark,
                    textColor: textColor,
                    primaryColor: primaryColor,
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Department', subTextColor),
                  const SizedBox(height: 6),
                  _buildDropdown<String>(
                    value: _selectedDepartment,
                    items: _departments,
                    isDark: isDark,
                    textColor: textColor,
                    primaryColor: primaryColor,
                    onChanged: (v) => setState(() => _selectedDepartment = v!),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildLabel('Password', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpPasswordController,
          hint: 'Minimum 6 characters',
          icon: Icons.lock_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
          obscure: _obscureSignUp,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUp ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: subTextColor,
            ),
            onPressed: () => setState(() => _obscureSignUp = !_obscureSignUp),
          ),
        ),
        const SizedBox(height: 14),

        _buildLabel('Confirm Password', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpConfirmPasswordController,
          hint: 'Re-enter password',
          icon: Icons.lock_outline_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
          obscure: _obscureSignUpConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUpConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: subTextColor,
            ),
            onPressed: () => setState(() => _obscureSignUpConfirm = !_obscureSignUpConfirm),
          ),
          onSubmitted: (_) => _handleSignUp(),
        ),
      ],
    );
  }            ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Phòng Ban', subTextColor),
                  const SizedBox(height: 6),
                  _buildDropdown<String>(
                    value: _selectedDepartment,
                    items: _departments,
                    isDark: isDark,
                    textColor: textColor,
                    primaryColor: primaryColor,
                    onChanged: (v) => setState(() => _selectedDepartment = v!),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildLabel('Mật Khẩu', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpPasswordController,
          hint: 'Tối thiểu 6 ký tự',
          icon: Icons.lock_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
          obscure: _obscureSignUp,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUp ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: subTextColor,
            ),
            onPressed: () => setState(() => _obscureSignUp = !_obscureSignUp),
          ),
        ),
        const SizedBox(height: 14),

        _buildLabel('Xác Nhận Mật Khẩu', subTextColor),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpConfirmPasswordController,
          hint: 'Nhập lại mật khẩu',
          icon: Icons.lock_outline_rounded,
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
          primaryColor: primaryColor,
          obscure: _obscureSignUpConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUpConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: subTextColor,
            ),
            onPressed: () => setState(() => _obscureSignUpConfirm = !_obscureSignUpConfirm),
          ),
          onSubmitted: (_) => _handleSignUp(),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Shared Widgets
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white24 : Colors.black26),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white38 : Colors.black38),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required bool isDark,
    required Color textColor,
    required Color primaryColor,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        icon: Icon(Icons.expand_more_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black38),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString(), style: TextStyle(color: textColor, fontSize: 13)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
