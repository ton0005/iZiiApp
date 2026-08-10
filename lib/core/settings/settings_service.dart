import 'package:shared_preferences/shared_preferences.dart';

import '../services/server_config_service.dart';

class SettingsService {
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _syncServerUrl = 'sync_server_url';
  static const String _syncToken = 'sync_token';
  static const String _lastSyncTimestamp = 'last_sync_timestamp';
  static const String _languageCode = 'selected_language_code';
  static const String _activeUserId = 'active_user_id';

  Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCode, 'en');
  }

  Future<String> getLanguage() async {
    return 'en';
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
    final serverConfig = ServerConfigService.instance;
    if (!serverConfig.hasSelectedServer) {
      await serverConfig.init();
    }
    if (serverConfig.hasSelectedServer && serverConfig.currentServer != null) {
      return serverConfig.currentServer!.baseUrl;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncServerUrl) ?? 'http://10.146.147.160:8080';
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

  // ── Con trỏ đồng bộ dạng sequence ──────────────────────────────────────────
  //
  // Thay cho last_sync_timestamp vì so sánh chuỗi thời gian phụ thuộc đồng hồ
  // server; lệch vài giây là bỏ sót bản ghi mà không có lỗi nào.
  //
  // Lưu THEO TỪNG SERVER URL: seq là số thứ tự trong log của riêng một server,
  // gửi seq của server A cho server B là vô nghĩa và sẽ làm mất dữ liệu. Cơ chế
  // cũ dùng một key toàn cục nên đổi server là hỏng ngay.
  String _seqKeyFor(String serverUrl) =>
      'last_sync_seq::${serverUrl.trim().replaceAll(RegExp(r'/+$'), '')}';

  Future<void> saveLastSyncSeq(String serverUrl, int seq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seqKeyFor(serverUrl), seq);
  }

  Future<int?> getLastSyncSeq(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_seqKeyFor(serverUrl));
  }

  Future<void> clearLastSyncSeq(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seqKeyFor(serverUrl));
  }

  // ── Device token (cấp qua luồng enrollment QR/NFC) ────────────────────────
  //
  // Token RIÊNG của máy này, khác hoàn toàn với IZIIAPP_SERVER_SECRET dùng
  // chung trước đây. Thu hồi được riêng lẻ khi mất máy.
  //
  // Lưu theo từng server URL vì mỗi server cấp token riêng — một máy có thể
  // đăng ký với cả M1 lẫn M2.
  String _deviceTokenKeyFor(String serverUrl) =>
      'device_token::${serverUrl.trim().replaceAll(RegExp(r'/+$'), '')}';

  Future<void> saveDeviceToken(String serverUrl, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceTokenKeyFor(serverUrl), token);
  }

  Future<String?> getDeviceToken(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceTokenKeyFor(serverUrl));
  }

  Future<void> clearDeviceToken(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceTokenKeyFor(serverUrl));
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
