import 'package:dio/dio.dart';

import '../settings/settings_service.dart';

/// Kết quả đọc cấu hình server.
class ServerAdminConfig {
  final String serverId;
  final String zone;
  final String envFile;
  final bool envFileExists;

  /// Giá trị trong .env. Secret đã bị che bằng [secretMask].
  final Map<String, String> values;
  final String secretMask;

  /// Trạng thái ĐANG CHẠY — có thể khác .env nếu chưa khởi động lại.
  final String dbBackend;
  final bool tlsEnabled;
  final bool mtlsEnabled;
  final bool oauthConfigured;
  final List<String> peersConfigured;

  /// Chứng chỉ TLS: đường dẫn khai báo và file có tồn tại thật không.
  final Map<String, bool> certExists;
  final Map<String, String> certPaths;

  ServerAdminConfig({
    required this.serverId,
    required this.zone,
    required this.envFile,
    required this.envFileExists,
    required this.values,
    required this.secretMask,
    required this.dbBackend,
    required this.tlsEnabled,
    required this.mtlsEnabled,
    required this.oauthConfigured,
    required this.peersConfigured,
    required this.certExists,
    required this.certPaths,
  });

  factory ServerAdminConfig.fromJson(Map<String, dynamic> json) {
    final runtime = (json['runtime'] as Map?) ?? {};
    final certs = (json['certs'] as Map?) ?? {};

    final certExists = <String, bool>{};
    final certPaths = <String, String>{};
    for (final k in ['cert', 'key', 'ca']) {
      final entry = (certs[k] as Map?) ?? {};
      certExists[k] = entry['exists'] == true;
      certPaths[k] = (entry['path'] ?? '').toString();
    }

    return ServerAdminConfig(
      serverId: (json['server_id'] ?? '').toString(),
      zone: (json['zone'] ?? '').toString(),
      envFile: (json['env_file'] ?? '').toString(),
      envFileExists: json['env_file_exists'] == true,
      values: Map<String, String>.from(
        ((json['values'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v ?? '').toString())),
      ),
      secretMask: (json['secret_mask'] ?? '••••••••').toString(),
      dbBackend: (runtime['db_backend'] ?? 'sqlite').toString(),
      tlsEnabled: runtime['tls_enabled'] == true,
      mtlsEnabled: runtime['mtls_enabled'] == true,
      oauthConfigured: runtime['oauth_configured'] == true,
      peersConfigured: List<String>.from(
        (runtime['peers_configured'] as List?)?.map((e) => e.toString()) ?? const [],
      ),
      certExists: certExists,
      certPaths: certPaths,
    );
  }
}

/// Gọi các endpoint /admin/* của iZiiServer.
///
/// Mọi lời gọi đều cần header `X-iZii-Server-Token` khớp IZIIAPP_SERVER_SECRET
/// trên server. Token lấy từ ô "Auth Token" trong phần Sync Server của màn hình
/// Settings — cùng một secret, không cần nhập hai lần.
class ServerAdminService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final SettingsService _settings = SettingsService();

  Future<Map<String, String>> _headers() async {
    final token = await _settings.getSyncToken();
    return {
      if (token.isNotEmpty) 'X-iZii-Server-Token': token,
      'Content-Type': 'application/json',
    };
  }

  Future<String> _baseUrl() async {
    final url = await _settings.getSyncServerUrl();
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  /// Đọc cấu hình. Ném [ServerAdminException] kèm thông điệp dễ hiểu khi lỗi.
  Future<ServerAdminConfig> fetchConfig() async {
    try {
      final resp = await _dio.get(
        '${await _baseUrl()}/admin/config',
        options: Options(headers: await _headers()),
      );
      return ServerAdminConfig.fromJson(Map<String, dynamic>.from(resp.data));
    } on DioException catch (e) {
      throw ServerAdminException(_describe(e));
    }
  }

  /// Ghi cấu hình. Trả về danh sách khoá đã đổi.
  ///
  /// Secret không muốn đổi thì để nguyên giá trị mask hoặc bỏ khỏi map —
  /// server sẽ giữ nguyên giá trị cũ.
  Future<List<String>> updateConfig(Map<String, String> values) async {
    try {
      final resp = await _dio.put(
        '${await _baseUrl()}/admin/config',
        data: {'values': values},
        options: Options(headers: await _headers()),
      );
      final data = Map<String, dynamic>.from(resp.data);
      return List<String>.from(
        (data['updated_keys'] as List?)?.map((e) => e.toString()) ?? const [],
      );
    } on DioException catch (e) {
      throw ServerAdminException(_describe(e));
    }
  }

  String _describe(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401) {
      return 'Token wrong or missing. Check the Auth Token field in the Sync Server section — '
          'this value must match the IZIIAPP_SERVER_SECRET on the server.';
    }
    if (code == 503) {
      return 'The server has not set IZIIAPP_SERVER_SECRET, so it is rejecting all admin operations.';
    }
    if (code == 400) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      return detail?.toString() ?? 'Invalid data sent.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Failed to connect to the server. Check the Server URL and ensure the server is running.';
    }
    return e.message ?? 'Undefined error.';
  }
}

class ServerAdminException implements Exception {
  final String message;
  ServerAdminException(this.message);
  @override
  String toString() => message;
}
