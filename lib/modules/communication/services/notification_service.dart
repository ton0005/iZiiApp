import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/settings/settings_service.dart';

class NotificationService {
  final AppDatabase _db;
  final SettingsService _settingsService;

  NotificationService({
    AppDatabase? db,
    SettingsService? settingsService,
  }) : _db = db ?? AppDatabase(),
       _settingsService = settingsService ?? SettingsService();

  Future<String> get _baseUrl async => await _settingsService.getSyncServerUrl();

  /// Register push token to server
  Future<bool> registerPushToken({
    required String userId,
    required String deviceId,
    required String pushToken,
    required String platform,
    required String deviceName,
  }) async {
    try {
      final baseUrl = await _baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'user_id': userId,
          'push_token': pushToken,
          'platform': platform,
          'device_name': deviceName,
          'public_key': 'mock_public_key', // Required by server model
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch in-app notifications from server and sync with local Drift SQLite
  Future<void> syncNotifications(String userId) async {
    try {
      final baseUrl = await _baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/notifications?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List remoteNotifs = data['notifications'] ?? [];

        for (var notif in remoteNotifs) {
          final entry = InAppNotification(
            id: notif['id'],
            userId: notif['user_id'],
            title: notif['title'],
            body: notif['body'],
            eventType: notif['event_type'],
            resourceId: notif['resource_id'],
            readAt: notif['read_at'] != null ? DateTime.parse(notif['read_at']) : null,
            createdAt: DateTime.parse(notif['created_at']),
          );
          await _db.into(_db.inAppNotifications).insertOnConflictUpdate(entry);
        }
      }
    } catch (_) {}
  }

  /// Sync user notification settings with the server
  Future<void> syncSettings(String userId) async {
    try {
      final baseUrl = await _baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/notification-settings?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List remoteSettings = data['settings'] ?? [];
        for (var s in remoteSettings) {
          final entry = NotificationSettingsTableData(
            userId: userId,
            eventType: s['event_type'],
            enablePush: s['enable_push'] ?? true,
            enableInApp: s['enable_in_app'] ?? true,
            enableEmail: s['enable_email'] ?? true,
            digestFrequency: s['digest_frequency'] ?? 'instant',
          );
          await _db.into(_db.notificationSettingsTable).insertOnConflictUpdate(entry);
        }
      }
    } catch (_) {}
  }

  /// Update user notification setting locally and sync to server
  Future<bool> updateSetting(NotificationSettingsTableData setting) async {
    try {
      // 1. Update SQLite
      await _db.into(_db.notificationSettingsTable).insertOnConflictUpdate(setting);

      // 2. Update Server
      final baseUrl = await _baseUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/notification-settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': setting.userId,
          'event_type': setting.eventType,
          'enable_push': setting.enablePush,
          'enable_in_app': setting.enableInApp,
          'enable_email': setting.enableEmail,
          'digest_frequency': setting.digestFrequency,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Mark a single notification as read
  Future<bool> markAsRead(String notificationId, String userId) async {
    try {
      final baseUrl = await _baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/notifications/read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'notification_ids': [notificationId],
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        final query = _db.update(_db.inAppNotifications)
          ..where((t) => t.id.equals(notificationId));
        await query.write(InAppNotificationsCompanion(
          readAt: Value(DateTime.now()),
        ));
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Mark all notifications for the user as read
  Future<bool> markAllAsRead(String userId) async {
    try {
      final baseUrl = await _baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/notifications/read-all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        final query = _db.update(_db.inAppNotifications)
          ..where((t) => t.userId.equals(userId));
        await query.write(InAppNotificationsCompanion(
          readAt: Value(DateTime.now()),
        ));
        return true;
      }
    } catch (_) {}
    return false;
  }
}
