import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'settings_service.dart';
import '../bloc/app_bloc.dart';
import '../localization/app_localizations.dart';
import '../device_identity/ble_device_discovery_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _settingsService = SettingsService();
  bool _isSaved = false;
  bool _isBleEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadBleSettings();
  }

  Future<void> _loadBleSettings() async {
    final enabled = await _settingsService.getBleP2PEnabled();
    setState(() => _isBleEnabled = enabled);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final key = await _settingsService.getGeminiApiKey();
    if (key != null) {
      _apiKeyController.text = key;
    }
  }

  Future<void> _saveApiKey() async {
    await _settingsService.saveGeminiApiKey(_apiKeyController.text);
    setState(() => _isSaved = true);

    // Hide notification after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Language Configurations ---
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language_rounded,
                            color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('settings_language'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('settings_language_desc'),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text(
                                'Tiếng Việt',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            selected:
                                Localizations.localeOf(context).languageCode ==
                                    'vi',
                            selectedColor:
                                const Color(0xFF10B981).withValues(alpha: 0.25),
                            checkmarkColor: const Color(0xFF10B981),
                            onSelected: (selected) {
                              if (selected) {
                                context
                                    .read<AppBloc>()
                                    .add(const ChangeLocaleEvent(Locale('vi')));
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text(
                                'English',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            selected:
                                Localizations.localeOf(context).languageCode ==
                                    'en',
                            selectedColor:
                                const Color(0xFF10B981).withValues(alpha: 0.25),
                            checkmarkColor: const Color(0xFF10B981),
                            onSelected: (selected) {
                              if (selected) {
                                context
                                    .read<AppBloc>()
                                    .add(const ChangeLocaleEvent(Locale('en')));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- AI Configurations ---
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smart_toy_outlined,
                            color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('settings_api_config'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('settings_api_desc'),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: context.tr('settings_api_key_label'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveApiKey,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(context.tr('settings_save_api_key'),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (_isSaved) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          context.tr('settings_save_success'),
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Sync Settings ---
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sync_rounded,
                            color: Color(0xFF06B6D4)),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('settings_sync_title'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('settings_sync_desc'),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.sync_outlined),
                        label: Text(context.tr('settings_go_to_sync'),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => context.push('/settings/sync'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Bluetooth P2P Settings ---
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bluetooth_rounded,
                            color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Text(
                          'Kết nối P2P Bluetooth',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cho phép thiết bị khác phát hiện và gửi tin nhắn bảo mật ngang hàng (P2P) qua Bluetooth khi ngoại tuyến.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Kích hoạt Bluetooth Chat P2P',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      value: _isBleEnabled,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (bool value) async {
                        setState(() {
                          _isBleEnabled = value;
                        });
                        await _settingsService.saveBleP2PEnabled(value);
                        if (value) {
                          await BleDeviceDiscoveryService().startAdvertising();
                        } else {
                          await BleDeviceDiscoveryService().stopAdvertising();
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
