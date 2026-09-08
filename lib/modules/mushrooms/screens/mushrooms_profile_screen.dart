// lib/modules/mushrooms/screens/mushrooms_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../services/employee_service.dart';

class MushroomsProfileScreen extends StatefulWidget {
  final bool isDark;

  const MushroomsProfileScreen({super.key, required this.isDark});

  @override
  State<MushroomsProfileScreen> createState() => _MushroomsProfileScreenState();
}

class _MushroomsProfileScreenState extends State<MushroomsProfileScreen> {
  final _employeeService = EmployeeServiceImpl();
  final _formKey = GlobalKey<FormState>();

  MushroomEmployee? _employee;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final emp = await _employeeService.getCurrentEmployee();
    if (mounted) {
      setState(() {
        _employee = emp;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_employee == null) return;

    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;

    setState(() {
      _isSubmitting = true;
    });

    final success = await _employeeService.changePassword(
      employeeId: _employee!.id,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current password is incorrect.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = const Color(0xFF10B981);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Profile & Account',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Information Card
                      Card(
                        color: cardBg,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor:
                                        primaryColor.withValues(alpha: 0.15),
                                    child: Icon(Icons.person_rounded,
                                        size: 32, color: primaryColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _employee?.name ?? 'Chưa xác định',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mã NV: ${_employee?.id ?? ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: subTextColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              _buildInfoRow('Role', _employee?.role ?? 'N/A',
                                  textColor, subTextColor),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                  'Department',
                                  _employee?.department ?? 'N/A',
                                  textColor,
                                  subTextColor),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                  'Status',
                                  _employee?.status.toUpperCase() ?? 'ACTIVE',
                                  primaryColor,
                                  subTextColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Change Password Form Card
                      Card(
                        color: cardBg,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lock_reset_rounded,
                                        color: primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Change Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Old Password
                                TextFormField(
                                  controller: _oldPasswordController,
                                  obscureText: _obscureOld,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Current Password',
                                    labelStyle: TextStyle(color: subTextColor),
                                    prefixIcon: Icon(Icons.lock_outline_rounded,
                                        color: primaryColor),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureOld
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: subTextColor,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscureOld = !_obscureOld),
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Please enter your current password'
                                      : null,
                                ),
                                const SizedBox(height: 16),

                                // New Password
                                TextFormField(
                                  controller: _newPasswordController,
                                  obscureText: _obscureNew,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'New Password',
                                    labelStyle: TextStyle(color: subTextColor),
                                    prefixIcon: Icon(Icons.vpn_key_outlined,
                                        color: primaryColor),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureNew
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: subTextColor,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscureNew = !_obscureNew),
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Please enter your new password';
                                    if (v.length < 6)
                                      return 'Password must be at least 6 characters long';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Confirm New Password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Confirm New Password',
                                    labelStyle: TextStyle(color: subTextColor),
                                    prefixIcon: Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: primaryColor),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: subTextColor,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Please confirm your new password';
                                    if (v != _newPasswordController.text)
                                      return 'Password confirmation does not match';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _handleChangePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Đổi Mật Khẩu',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color valueColor, Color labelColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: labelColor)),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}
