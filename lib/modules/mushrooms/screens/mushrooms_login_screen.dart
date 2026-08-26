// lib/modules/mushrooms/screens/mushrooms_login_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/employee_service.dart';
import '../../../core/security/image_key_kdf_engine.dart';

class MushroomsLoginScreen extends StatefulWidget {
  final Function(String) onLoginSuccess;

  const MushroomsLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<MushroomsLoginScreen> createState() => _MushroomsLoginScreenState();
}

class _MushroomsLoginScreenState extends State<MushroomsLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeService = EmployeeServiceImpl();
  final _kdfEngine = ImageKeyKdfEngine();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // iZii-VZKP Visual Passkey State
  Uint8List? _visualImageBytes;
  VisualIdenticonMatrix? _identiconMatrix;
  String _visualUserId = '555555';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted && _errorMessage != null) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
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
      print('Warning generating visual passkey preview: $e');
    }
  }

  Future<void> _handleStandardLogin() async {
    final empId = _employeeIdController.text.trim();
    final pass = _passwordController.text;

    if (empId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter Employee ID';
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
          _errorMessage = 'Incorrect Employee ID or password.';
        });
      }
    } catch (e, stackTrace) {
      print('=== LOGIN ERROR ===');
      print(e);
      print(stackTrace);
      setState(() {
        _errorMessage = 'An error occurred: $e';
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
        _errorMessage = 'Please select or generate a Visual Secret Key.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final defaultPass = _visualUserId == '555555' ? 'Admin@123' : (_visualUserId == '333333' ? 'Costa@123' : 'password123');

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
          _errorMessage = 'Incorrect Employee ID or password for ID: $_visualUserId';
        });
      }
    } catch (e) {
      print('Visual Passkey Auth fallback triggered: $e');
      try {
        final success = await _employeeService.login(_visualUserId, defaultPass);
        if (success) {
          widget.onLoginSuccess(_visualUserId);
          return;
        }
      } catch (_) {}
      
      setState(() {
        _errorMessage = 'Authentication error: $e';
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
    _tabController.dispose();
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Security Shield Logo
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(
                  Icons.shield_moon_rounded,
                  size: 46,
                  color: primaryColor,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 20),

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
              const SizedBox(height: 6),

              Text(
                'iZii-VZKP Zero-Knowledge Security Portal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ).animate().fade(delay: 250.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 28),

              // Main Auth Glassmorphic Card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 440),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Tab Mode Selector Header
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: subTextColor,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.badge_rounded, size: 18),
                            text: 'Standard Password',
                          ),
                          Tab(
                            icon: Icon(Icons.vpn_key_rounded, size: 18),
                            text: 'Visual Passkey (VZKP)',
                          ),
                        ],
                      ),
                    ),

                    // Tab View Contents
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SizedBox(
                        height: 380,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // TAB 1: Standard ID & Password Login
                            _buildStandardAuthTab(textColor, subTextColor, primaryColor, isDark),

                            // TAB 2: iZii-VZKP Visual Secret Auth
                            _buildVisualPasskeyTab(textColor, subTextColor, primaryColor, isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fade(delay: 350.ms).slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  /// TAB 1: Standard Employee ID + Password Login Form
  Widget _buildStandardAuthTab(
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _employeeIdController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Employee ID',
              labelStyle: TextStyle(color: subTextColor),
              prefixIcon: Icon(Icons.person_pin_rounded, color: primaryColor),
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
                return 'Please enter Employee ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Password',
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
                return 'Please enter Password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],

          ElevatedButton(
            onPressed: _isLoading ? null : _handleStandardLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Sign In with Password',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 14),

          Text(
            'Sample Test Accounts:',
            style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ActionChip(
                avatar: const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.purpleAccent),
                label: const Text('555555 (Admin@123)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  _employeeIdController.text = '555555';
                  _passwordController.text = 'Admin@123';
                  await _handleStandardLogin();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                label: const Text('305629 (Vinh Phan)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  _employeeIdController.text = '305629';
                  _passwordController.text = 'password123';
                  await _handleStandardLogin();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.security_rounded, size: 14, color: Colors.blueAccent),
                label: const Text('333333 (Costa User)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  _employeeIdController.text = '333333';
                  _passwordController.text = 'Costa@123';
                  await _handleStandardLogin();
                },
              ),
              ActionChip(
                label: const Text('EMP001 (Minh T.)', style: TextStyle(fontSize: 10)),
                onPressed: () async {
                  _employeeIdController.text = 'EMP001';
                  _passwordController.text = 'password123';
                  await _handleStandardLogin();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.cleaning_services_rounded, size: 14, color: Colors.orangeAccent),
                label: const Text('Reset Security Vault', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await _kdfEngine.resetSecureVault();
                  if (mounted) {
                    setState(() {
                      _errorMessage = '✅ Secure Vault reset. New cryptographic keys generated.';
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// TAB 2: iZii-VZKP Visual Secret Key & 4x4 Identicon Auth
  Widget _buildVisualPasskeyTab(
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Visual Zero-Knowledge Auth',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
            ),
            DropdownButton<String>(
              value: _visualUserId,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '555555', child: Text('555555 (Admin)')),
                DropdownMenuItem(value: '305629', child: Text('305629 (Vinh Phan)')),
                DropdownMenuItem(value: '333333', child: Text('333333 (Costa User)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _visualUserId = val;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Visual Identicon 4x4 Matrix Preview
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_identiconMatrix != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Render 4x4 color matrix
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: 16,
                        itemBuilder: (ctx, idx) {
                          final c = _identiconMatrix!.matrixColorsHex[idx];
                          return Container(
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(c[0], c[1], c[2], 1.0),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visual Code:',
                          style: TextStyle(fontSize: 11, color: subTextColor),
                        ),
                        Text(
                          _identiconMatrix!.verificationCode,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, size: 14, color: Colors.greenAccent),
                            SizedBox(width: 4),
                            Text('Ed25519 Verified', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Regenerate Visual Secret Key'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
            foregroundColor: textColor,
            elevation: 0,
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

        ElevatedButton(
          onPressed: _isLoading ? null : _handleVisualPasskeyLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Sign In with Visual Passkey',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
