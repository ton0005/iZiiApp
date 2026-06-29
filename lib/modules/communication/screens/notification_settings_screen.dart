import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/notification_service.dart';
import '../../../core/database/app_database.dart';
import '../bloc/chat_bloc.dart';
import '../theme/chat_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  List<NotificationSettingsTableData> _settings = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final chatBloc = context.read<ChatBloc>();
    final userId = chatBloc.currentUserId ?? '';
    _userId = userId;

    // Try to sync with server first
    await _notificationService.syncSettings(userId);

    // Read from Drift local SQLite
    final db = chatBloc.db;
    final localSettings = await (db.select(db.notificationSettingsTable)
          ..where((t) => t.userId.equals(userId)))
        .get();

    // Populate mock configs if SQLite is completely empty
    if (localSettings.isEmpty) {
      final defaultEvents = ['new_message', 'new_group_message', 'mention', 'added_to_group', 'missed_call'];
      for (var ev in defaultEvents) {
        final mockSetting = NotificationSettingsTableData(
          userId: userId,
          eventType: ev,
          enablePush: true,
          enableInApp: true,
          enableEmail: true,
          digestFrequency: 'instant',
        );
        await db.into(db.notificationSettingsTable).insertOnConflictUpdate(mockSetting);
      }
      final reloaded = await (db.select(db.notificationSettingsTable)
            ..where((t) => t.userId.equals(userId)))
          .get();
      if (mounted) {
        setState(() {
          _settings = reloaded;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _settings = localSettings;
        _isLoading = false;
      });
    }
  }

  String _getEventLabel(String eventType) {
    switch (eventType) {
      case 'new_message':
        return 'Tin nhắn mới (1-1)';
      case 'new_group_message':
        return 'Tin nhắn nhóm (Group)';
      case 'mention':
        return 'Nhắc tên (@mention)';
      case 'added_to_group':
        return 'Được thêm vào nhóm';
      case 'missed_call':
        return 'Cuộc gọi nhỡ';
      default:
        return eventType;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'new_message':
        return Icons.chat_bubble_rounded;
      case 'new_group_message':
        return Icons.groups_rounded;
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'added_to_group':
        return Icons.group_add_rounded;
      case 'missed_call':
        return Icons.phone_missed_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Future<void> _toggleChannel(NotificationSettingsTableData setting, String channel, bool enabled) async {
    final updated = NotificationSettingsTableData(
      userId: setting.userId,
      eventType: setting.eventType,
      enablePush: channel == 'push' ? enabled : setting.enablePush,
      enableInApp: channel == 'in_app' ? enabled : setting.enableInApp,
      enableEmail: channel == 'email' ? enabled : setting.enableEmail,
      digestFrequency: setting.digestFrequency,
    );

    // Optimistic UI update
    setState(() {
      final index = _settings.indexWhere((s) => s.eventType == setting.eventType);
      if (index != -1) {
        _settings[index] = updated;
      }
    });

    final success = await _notificationService.updateSetting(updated);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi đồng bộ cấu hình với server.')),
      );
    }
  }

  Future<void> _changeFrequency(NotificationSettingsTableData setting, String freq) async {
    final updated = NotificationSettingsTableData(
      userId: setting.userId,
      eventType: setting.eventType,
      enablePush: setting.enablePush,
      enableInApp: setting.enableInApp,
      enableEmail: setting.enableEmail,
      digestFrequency: freq,
    );

    setState(() {
      final index = _settings.indexWhere((s) => s.eventType == setting.eventType);
      if (index != -1) {
        _settings[index] = updated;
      }
    });

    await _notificationService.updateSetting(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ChatTheme.getBgPrimary(isDark),
      appBar: AppBar(
        title: const Text('Cấu hình Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings.isEmpty
              ? Center(
                  child: Text(
                    'Không tìm thấy cấu hình thông báo.',
                    style: TextStyle(color: ChatTheme.getTextMuted(isDark)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _settings.length,
                  itemBuilder: (context, index) {
                    final setting = _settings[index];

                    return Card(
                      color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_getEventIcon(setting.eventType), color: ChatTheme.getAccent(isDark)),
                                const SizedBox(width: 12),
                                Text(
                                  _getEventLabel(setting.eventType),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ChatTheme.getTextPrimary(isDark),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            // Channels toggles
                            _buildChannelToggle(
                              label: 'Push Notification (Real-time)',
                              value: setting.enablePush,
                              onChanged: (val) => _toggleChannel(setting, 'push', val),
                              isDark: isDark,
                            ),
                            _buildChannelToggle(
                              label: 'In-app Notification (Hộp thư)',
                              value: setting.enableInApp,
                              onChanged: (val) => _toggleChannel(setting, 'in_app', val),
                              isDark: isDark,
                            ),
                            _buildChannelToggle(
                              label: 'Email Notification',
                              value: setting.enableEmail,
                              onChanged: (val) => _toggleChannel(setting, 'email', val),
                              isDark: isDark,
                            ),
                            if (setting.enableEmail) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tần suất Email:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: ChatTheme.getTextMuted(isDark),
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    value: setting.digestFrequency,
                                    dropdownColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
                                    style: TextStyle(
                                      color: ChatTheme.getTextPrimary(isDark),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    underline: const SizedBox(),
                                    items: const [
                                      DropdownMenuItem(value: 'instant', child: Text('Tức thời')),
                                      DropdownMenuItem(value: 'hourly', child: Text('Hàng giờ')),
                                      DropdownMenuItem(value: 'daily', child: Text('Hàng ngày (Digest)')),
                                      DropdownMenuItem(value: 'never', child: Text('Không bao giờ')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _changeFrequency(setting, val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildChannelToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: ChatTheme.getTextPrimary(isDark),
            ),
          ),
          Switch(
            value: value,
            activeColor: ChatTheme.getAccent(isDark),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
