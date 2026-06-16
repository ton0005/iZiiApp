import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _syncServerUrl = 'sync_server_url';
  static const String _syncToken = 'sync_token';
  static const String _lastSyncTimestamp = 'last_sync_timestamp';
  static const String _languageCode = 'selected_language_code';
  static const String _activeUserId = 'active_user_id';

  Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCode, code);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageCode) ?? 'vi';
  }

  Future<void> saveGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiApiKey, key);
  }

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKey);
  }

  Future<void> saveSyncServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncServerUrl, url);
  }

  Future<String> getSyncServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncServerUrl) ?? 'http://172.22.16.1:8080';
  }

  Future<void> saveSyncToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncToken, token);
  }

  Future<String> getSyncToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncToken) ?? '';
  }

  Future<void> saveLastSyncTimestamp(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncTimestamp, timestamp);
  }

  Future<String?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncTimestamp);
  }

  Future<void> saveActiveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUserId, userId);
  }

  Future<String> getActiveUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeUserId) ?? 'default_user';
  }

  Future<void> saveBleP2PEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ble_p2p_enabled', value);
  }

  Future<bool> getBleP2PEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ble_p2p_enabled') ?? true;
  }
}
