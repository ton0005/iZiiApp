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

  /// Lưu địa chỉ server do người dùng nhập ở Settings → Sync Server.
  ///
  /// ⚠️ LỖI CŨ — đọc kỹ trước khi sửa lại chỗ này:
  ///
  /// App có HAI nơi lưu "server đang dùng":
  ///   1. `sync_server_url`          — ô nhập trong Settings (hàm này)
  ///   2. `iziiapp_selected_server`  — [ServerConfigService], ghi bởi màn hình
  ///                                    chọn server và bởi mDNS discovery
  ///
  /// [getSyncServerUrl] đọc (2) TRƯỚC, chỉ rơi về (1) khi chưa từng chọn
  /// server nào. Hậu quả: người dùng gõ địa chỉ mới vào Settings, app vẫn gọi
  /// địa chỉ CŨ mãi mãi. Ô nhập trở thành vô nghĩa mà không báo lỗi gì.
  ///
  /// Đúng triệu chứng đã gặp: trình duyệt trên điện thoại vào
  /// `http://<ip>:8080/sync/status` ra JSON bình thường, nhưng app thì không
  /// đăng ký được thiết bị, không đồng bộ, không gọi được — vì nó đang gõ cửa
  /// một địa chỉ khác. Chat vẫn chạy do đi qua BLE, không cần server.
  ///
  /// Nên hàm này phải cập nhật CẢ HAI nơi.
  Future<void> saveSyncServerUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncServerUrl, clean);

    final uri = Uri.tryParse(clean);
    if (uri == null || uri.host.isEmpty) return;

    final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
    final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 8080);

    final cfg = ServerConfigService.instance;
    await cfg.init();
    final current = cfg.currentServer;

    // Chưa chọn server nào → nhánh dự phòng trong getSyncServerUrl đã đọc
    // đúng giá trị vừa lưu, không cần làm gì thêm.
    if (current == null) return;

    if (current.host == uri.host &&
        current.port == port &&
        current.scheme == scheme) {
      return;
    }

    await cfg.setCurrentServer(
      current.copyWith(host: uri.host, port: port, scheme: scheme),
    );
  }

  /// Địa chỉ server mà MỌI request của app dùng.
  ///
  /// Thứ tự ưu tiên giữ nguyên như cũ (server đã chọn thắng), nhưng giờ an
  /// toàn vì [saveSyncServerUrl] đã đồng bộ hai nơi.
  Future<String> getSyncServerUrl() async {
    final serverConfig = ServerConfigService.instance;
    if (!serverConfig.hasSelectedServer) {
      await serverConfig.init();
    }
    String url;
    if (serverConfig.hasSelectedServer && serverConfig.currentServer != null) {
      url = serverConfig.currentServer!.baseUrl;
    } else {
      final prefs = await SharedPreferences.getInstance();
      url = prefs.getString(_syncServerUrl) ?? 'http://10.146.147.160:8080';
    }
    url = url.trim().replaceAll(RegExp(r'/+$'), '');

    // In một lần mỗi khi địa chỉ đổi. Không có dòng này thì "app không kết nối
    // được nhưng trình duyệt thì được" là một câu đố không có manh mối nào.
    if (url != _lastResolvedUrl) {
      _lastResolvedUrl = url;
      final src =
          serverConfig.hasSelectedServer ? 'server selected' : 'Settings';
      // ignore: avoid_print
      print('[Settings] App is calling server: $url  (source: $src)');
    }
    return url;
  }

  static String? _lastResolvedUrl;

  static const _loggedInDisplayName = 'izii_logged_in_display_name';

  /// Tên nhân viên đang đăng nhập trên máy này.
  ///
  /// CHỈ dùng để hiển thị. Khoá định danh của Chat/Call vẫn luôn là device_id —
  /// xem [DeviceUserService.applyLoggedInName] để biết vì sao không được đổi.
  Future<void> saveLoggedInDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name.trim().isEmpty) {
      await prefs.remove(_loggedInDisplayName);
    } else {
      await prefs.setString(_loggedInDisplayName, name.trim());
    }
  }

  Future<String> getLoggedInDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_loggedInDisplayName) ?? '';
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

  /// Token của máy này với [serverUrl].
  ///
  /// ⚠️ Token được lưu theo KHOÁ LÀ ĐỊA CHỈ SERVER. Đổi địa chỉ — ví dụ chuyển
  /// từ `http://192.168.x.x:8080` sang một tunnel HTTPS — là khoá đổi theo và
  /// token coi như biến mất, dù máy vẫn đăng ký hợp lệ.
  ///
  /// Triệu chứng đã gặp: sau khi chuyển sang devtunnel, `/devices/directory`
  /// vẫn 200 (endpoint đó không bắt buộc token) nhưng `/sessions/current` trả
  /// **401 "Thiếu X-iZii-Device-Token"** — điểm danh không dùng được.
  ///
  /// Nên khi không tìm thấy token đúng khoá, ta nhận token đã lưu cho địa chỉ
  /// khác và GẮN LẠI cho địa chỉ hiện tại. Cùng một máy, cùng một server, chỉ
  /// khác đường vào — server xác thực bằng hash token chứ không quan tâm client
  /// gọi qua URL nào.
  Future<String?> getDeviceToken(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final exact = prefs.getString(_deviceTokenKeyFor(serverUrl));
    if (exact != null && exact.isNotEmpty) return exact;

    const prefix = 'device_token::';
    final others = prefs
        .getKeys()
        .where((k) => k.startsWith(prefix))
        .toList(growable: false);
    if (others.isEmpty) return null;

    // Nhiều token cũ thì lấy cái gần nhất — thực tế gần như luôn chỉ có một.
    for (final key in others.reversed) {
      final token = prefs.getString(key);
      if (token == null || token.isEmpty) continue;
      await prefs.setString(_deviceTokenKeyFor(serverUrl), token);
      // ignore: avoid_print
      print(
          '[Settings] The device token has been transferred from "${key.substring(prefix.length)}" '
          'to "$serverUrl".');
      return token;
    }
    return null;
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
