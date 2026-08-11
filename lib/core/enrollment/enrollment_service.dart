import 'package:dio/dio.dart';

import '../device_identity/device_identity_service.dart';
import '../settings/settings_service.dart';

/// Nội dung một "vé mời" đăng ký thiết bị.
///
/// Đây là thứ được hiển thị dưới dạng QR hoặc ghi lên thẻ NFC — KHÔNG PHẢI
/// secret của hệ thống. Vé hết hạn sau vài phút và chỉ dùng được một lần.
class EnrollmentTicket {
  final String token;
  final String serverUrl;
  final String zone;
  final DateTime? expiresAt;

  EnrollmentTicket({
    required this.token,
    required this.serverUrl,
    this.zone = '',
    this.expiresAt,
  });

  /// Chuỗi ghi lên thẻ NFC / mã hoá vào QR.
  ///
  /// Dùng URI scheme để iOS đọc được thẻ ngay cả khi app chưa mở.
  String toUri() {
    final u = Uri.encodeComponent(serverUrl);
    return 'izii://enroll?t=$token&u=$u&z=$zone';
  }

  /// Phân tích chuỗi quét/đọc được. Trả null nếu không đúng định dạng.
  ///
  /// Chấp nhận cả `izii://enroll?...` lẫn URL http(s) có cùng query — một số
  /// máy Android ghi thẻ dạng URL thay vì custom scheme.
  static EnrollmentTicket? tryParse(String raw) {
    try {
      final s = raw.trim();
      if (s.isEmpty) return null;

      Uri? uri;
      try {
        uri = Uri.parse(s);
      } catch (_) {
        return null;
      }

      String? token = uri.queryParameters['t'];
      String? serverUrl = uri.queryParameters['u'];
      String? zone = uri.queryParameters['z'];

      // Thử phân tích thủ công query string nếu parser mặc định trả rỗng
      if (token == null || token.isEmpty || serverUrl == null || serverUrl.isEmpty) {
        final qPos = s.indexOf('?');
        if (qPos != -1) {
          final qStr = s.substring(qPos + 1);
          final params = Uri.splitQueryString(qStr);
          token ??= params['t'];
          serverUrl ??= params['u'];
          zone ??= params['z'];
        }
      }

      if (token == null || token.trim().isEmpty) return null;
      if (serverUrl == null || serverUrl.trim().isEmpty) return null;

      String cleanUrl = serverUrl.trim();
      if (cleanUrl.contains('%')) {
        try {
          cleanUrl = Uri.decodeComponent(cleanUrl);
        } catch (_) {}
      }

      return EnrollmentTicket(
        token: token.trim(),
        serverUrl: cleanUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        zone: (zone ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  int get secondsLeft {
    if (expiresAt == null) return 0;
    final s = expiresAt!.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }
}

/// Kết quả đăng ký thành công.
class EnrollmentResult {
  final String deviceToken;
  final String deviceId;
  final String serverId;
  final String zone;

  EnrollmentResult({
    required this.deviceToken,
    required this.deviceId,
    required this.serverId,
    required this.zone,
  });
}

/// Luồng đăng ký thiết bị — dùng chung cho QR (B3) và NFC (B4).
///
/// Điểm mấu chốt của thiết kế: QR và NFC chỉ là hai cách TRUYỀN cùng một vé
/// mời. Toàn bộ logic đổi vé lấy token nằm ở đây, nên thêm NFC sau khi đã có
/// QR gần như không tốn gì.
class EnrollmentService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final SettingsService _settings = SettingsService();

  // ── Phía ADMIN: xin vé mời ────────────────────────────────────────────────

  /// Gọi server xin vé mời mới. Cần quyền admin.
  ///
  /// [profile] quyết định chế độ của máy sắp đăng ký:
  ///   • `shared`   — tablet dùng chung tại phòng, BẮT BUỘC điểm danh mỗi ca
  ///   • `personal` — iPhone/iPad riêng của Manager/Supervisor, KHÔNG cần điểm
  ///                  danh vì danh tính đã xác định qua [ownerUserId]
  ///
  /// Chế độ chọn LÚC CẤP MÃ chứ không phải lúc quét: người nhận máy không chọn
  /// sai được, và cũng không tự nâng máy mình lên `personal` để né điểm danh.
  ///
  /// [sessionMaxHours] số giờ tối đa một ca. 0 hoặc null với máy cá nhân =
  /// không giới hạn.
  Future<EnrollmentTicket> requestTicket({
    String? note,
    int? ttlSeconds,
    String profile = 'shared',
    String? ownerUserId,
    String? ownerUserName,
    int? sessionMaxHours,
  }) async {
    final url = (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');
    final token = await _settings.getSyncToken();

    try {
      final resp = await _dio.post(
        '$url/admin/enrollment-token',
        data: {
          if (note != null) 'note': note,
          if (ttlSeconds != null) 'ttl_seconds': ttlSeconds,
          'profile': profile,
          if (ownerUserId != null) 'owner_user_id': ownerUserId,
          if (ownerUserName != null) 'owner_user_name': ownerUserName,
          if (sessionMaxHours != null) 'session_max_hours': sessionMaxHours,
        },
        options: Options(headers: {
          if (token.isNotEmpty) 'X-iZii-Admin-Token': token,
          // Header cũ để tương thích với server chưa cập nhật.
          if (token.isNotEmpty) 'X-iZii-Server-Token': token,
          'Content-Type': 'application/json',
        }),
      );
      final data = Map<String, dynamic>.from(resp.data);
      return EnrollmentTicket(
        token: data['token'].toString(),
        serverUrl: (data['server_url'] ?? url).toString(),
        zone: (data['zone'] ?? '').toString(),
        expiresAt: DateTime.tryParse((data['expires_at'] ?? '').toString()),
      );
    } on DioException catch (e) {
      throw EnrollmentException(_describe(e));
    }
  }

  // ── Phía THIẾT BỊ MỚI: đổi vé lấy token ───────────────────────────────────

  /// Đổi vé mời lấy token riêng và lưu vào máy.
  ///
  /// Gửi kèm public key để server đăng ký luôn vào sổ thiết bị — công nhân chỉ
  /// phải chạm/quét đúng một lần thay vì hai bước riêng.
  Future<EnrollmentResult> enroll(EnrollmentTicket ticket) async {
    final identity = await DeviceIdentityService().getOrCreateIdentity();
    final userId = await _safeUserId();

    try {
      final resp = await _dio.post(
        '${ticket.serverUrl.replaceAll(RegExp(r'/+$'), '')}/devices/enroll',
        data: {
          'token': ticket.token,
          'device_id': identity.deviceId,
          'device_name': identity.deviceName,
          'platform': _platformName(),
          'user_id': userId,
          'public_key': identity.publicKeyBase64,
          'signing_public_key': identity.signingPublicKeyBase64,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final data = Map<String, dynamic>.from(resp.data);
      final deviceToken = data['device_token'].toString();

      // Lưu NGAY. Server chỉ giữ hash nên không cấp lại được — mất token thì
      // phải xin vé mời mới và đăng ký lại từ đầu.
      await _settings.saveDeviceToken(ticket.serverUrl, deviceToken);
      await _settings.saveSyncServerUrl(ticket.serverUrl);

      return EnrollmentResult(
        deviceToken: deviceToken,
        deviceId: data['device_id'].toString(),
        serverId: (data['server_id'] ?? '').toString(),
        zone: (data['zone'] ?? '').toString(),
      );
    } on DioException catch (e) {
      throw EnrollmentException(_describe(e));
    }
  }

  Future<String> _safeUserId() async {
    try {
      return await _settings.getActiveUserId();
    } catch (_) {
      return '';
    }
  }

  String _platformName() {
    try {
      // ignore: avoid_web_libraries_in_flutter
      return const bool.fromEnvironment('dart.library.io') ? 'mobile' : 'web';
    } catch (_) {
      return 'unknown';
    }
  }

  String _describe(DioException e) {
    final code = e.response?.statusCode;
    if (code == 403) {
      return 'Mã đăng ký không hợp lệ hoặc đã hết hạn. Hãy xin quản lý cấp mã mới.';
    }
    if (code == 429) {
      return 'Thử quá nhiều lần. Đợi vài phút rồi thử lại.';
    }
    if (code == 401) {
      return 'Không có quyền admin. Kiểm tra Auth Token trong phần Sync Server.';
    }
    if (code == 503) {
      return 'Máy chủ chưa cấu hình IZIIAPP_ADMIN_SECRET nên từ chối thao tác quản trị.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Không kết nối được máy chủ. Kiểm tra mạng và địa chỉ server.';
    }
    return e.message ?? 'Lỗi không xác định.';
  }
}

class EnrollmentException implements Exception {
  final String message;
  EnrollmentException(this.message);
  @override
  String toString() => message;
}
