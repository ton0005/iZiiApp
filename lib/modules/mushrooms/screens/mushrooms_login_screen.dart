// lib/modules/mushrooms/screens/mushrooms_login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/employee_service.dart';

class MushroomsLoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;

  const MushroomsLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<MushroomsLoginScreen> createState() => _MushroomsLoginScreenState();
}

class _MushroomsLoginScreenState extends State<MushroomsLoginScreen> {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeService = EmployeeServiceImpl();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _employeeService.login(
        _employeeIdController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        widget.onLoginSuccess(_employeeIdController.text.trim());
      } else {
        setState(() {
          _errorMessage = 'Mã nhân viên hoặc mật khẩu không chính xác.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

    final primaryColor = const Color(0xFF10B981); // Emerald Green
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_person_rounded,
                  size: 48,
                  color: primaryColor,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),

              // Title
              Text(
                'Costa Mushrooms Portal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ).animate().fade(delay: 150.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),

              Text(
                'Nhập thông tin nhân viên để tiếp tục',
                style: TextStyle(
                  fontSize: 14,
                  color: subTextColor,
                ),
              ).animate().fade(delay: 250.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 32),

              // Login Card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Employee ID field
                      TextFormField(
                        controller: _employeeIdController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Mã nhân viên (Employee ID)',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.badge_rounded, color: primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: primaryColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập Mã nhân viên';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.lock_rounded, color: primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: subTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: primaryColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập Mật khẩu';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ).animate().shake(duration: 300.ms),
                        const SizedBox(height: 16),
                      ],

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Đăng Nhập',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(delay: 350.ms).slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}
