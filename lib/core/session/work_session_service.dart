import 'package:dio/dio.dart';

import '../settings/settings_service.dart';

/// Một phiên làm việc đang mở trên máy này.
class WorkSession {
  final String id;
  final String userId;
  final String userName;
  final String department;
  final String zone;
  final String method;
  final DateTime? startedAt;

  WorkSession({
    required this.id,
    required this.userId,
    this.userName = '',
    this.department = '',
    this.zone = '',
    this.method = 'list',
    this.startedAt,
  });

  factory WorkSession.fromJson(Map<String, dynamic> j) => WorkSession(
        id: (j['id'] ?? '').toString(),
        userId: (j['user_id'] ?? '').toString(),
        userName: (j['user_name'] ?? '').toString(),
        department: (j['department'] ?? '').toString(),
        zone: (j['zone'] ?? '').toString(),
        method: (j['method'] ?? 'list').toString(),
        startedAt: DateTime.tryParse((j['started_at'] ?? '').toString()),
      );

  String get displayName => userName.isNotEmpty ? userName : userId;

  Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!.toLocal());

  String get elapsedText {
    final d = elapsed;
    if (d.inHours > 0) return '${d.inHours} giờ ${d.inMinutes % 60} phút';
    return '${d.inMinutes} phút';
  }
}

/// Điểm danh đầu ca — tách danh tính NGƯỜI khỏi danh tính MÁY (G1).
///
/// VÌ SAO CẦN: một tablet dùng chung nhiều ca sẽ khiến hệ thống ghi cả hai ca là
/// cùng một người. Với cảnh báo Làm việc một mình thì đó là lỗi nghiêm trọng —
/// khi có sự cố, hệ thống phải nói được ĐÍCH DANH ai đang trong phòng.
///
/// Phiên lưu trên SERVER chứ không trên máy: nếu lưu cục bộ thì người dùng gỡ
/// app cài lại là xoá được dấu vết, và quản lý không xem được ai đang trong ca.
class WorkSessionService {
  static final WorkSessionService _instance = WorkSessionService._internal();
  factory WorkSessionService() => _instance;
  WorkSessionService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 12),
  ));
  final SettingsService _settings = SettingsService();

  /// Bộ nhớ đệm để màn hình không phải gọi mạng liên tục.
  WorkSession? _cached;
  DateTime? _cachedAt;

  /// Chế độ của máy này: 'shared' (tablet dùng chung) hoặc 'personal'
  /// (iPhone/iPad riêng của Manager, Supervisor).
  String _profile = 'shared';
  String _ownerName = '';
  int? _maxHours;

  WorkSession? get cachedSession => _cached;

  /// Máy cá nhân — không bắt buộc điểm danh vì danh tính đã xác định từ lúc
  /// cấp máy. Manager mang iPhone về nhà, bắt điểm danh mỗi sáng là vô nghĩa.
  bool get isPersonal => _profile == 'personal';
  String get ownerName => _ownerName;

  /// Số giờ tối đa của một ca trên máy này. null = không giới hạn.
  int? get maxHours => _maxHours;

  /// Có cần hiện màn hình điểm danh không.
  bool get requiresCheckIn => !isPersonal;

  Future<String> _baseUrl() async =>
      (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _headers() async {
    final url = await _baseUrl();
    final token = await _settings.getDeviceToken(url);
    return {
      if (token != null && token.isNotEmpty) 'X-iZii-Device-Token': token,
      'Content-Type': 'application/json',
    };
  }

  /// Phiên đang mở của máy này. Trả null nếu chưa điểm danh.
  ///
  /// [force] bỏ qua bộ nhớ đệm — dùng sau khi vừa điểm danh hoặc kết thúc ca.
  Future<WorkSession?> getCurrent({bool force = false}) async {
    if (!force && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(seconds: 30)) {
      return _cached;
    }
    try {
      final resp = await _dio.get('${await _baseUrl()}/sessions/current',
          options: Options(headers: await _headers()));
      final data = Map<String, dynamic>.from(resp.data);

      // Chế độ máy do SERVER quyết định (ghi lúc cấp mã đăng ký), không phải
      // do máy tự khai — nếu không thì ai cũng tự nâng mình thành 'personal'
      // để khỏi điểm danh.
      _profile = (data['profile'] ?? 'shared').toString();
      _ownerName = (data['owner_user_name'] ?? '').toString();
      _maxHours = data['max_hours'] is int ? data['max_hours'] as int : null;

      _cached = data['has_session'] == true && data['session'] != null
          ? WorkSession.fromJson(Map<String, dynamic>.from(data['session']))
          : null;
      _cachedAt = DateTime.now();
      return _cached;
    } on DioException catch (e) {
      // Mất mạng thì giữ nguyên giá trị đã đệm — công nhân vẫn làm việc được,
      // không bắt điểm danh lại chỉ vì Wi-Fi chập chờn.
      if (e.response?.statusCode == 401) {
        _cached = null;
        _cachedAt = DateTime.now();
      }
      return _cached;
    }
  }

  /// Điểm danh. Trả về phiên mới, hoặc ném [WorkSessionException].
  Future<WorkSession> checkIn({
    required String userId,
    String? userName,
    String? department,
    String method = 'list',
    String? pin,
  }) async {
    try {
      final resp = await _dio.post(
        '${await _baseUrl()}/sessions/start',
        data: {
          'user_id': userId,
          if (userName != null) 'user_name': userName,
          if (department != null) 'department': department,
          'method': method,
          if (pin != null) 'pin': pin,
        },
        options: Options(headers: await _headers()),
      );
      final data = Map<String, dynamic>.from(resp.data);
      final session = WorkSession(
        id: (data['session_id'] ?? '').toString(),
        userId: (data['user_id'] ?? '').toString(),
        userName: (data['user_name'] ?? '').toString(),
        zone: (data['zone'] ?? '').toString(),
        method: method,
        startedAt: DateTime.tryParse((data['started_at'] ?? '').toString()),
      );
      _cached = session;
      _cachedAt = DateTime.now();
      return session;
    } on DioException catch (e) {
      throw WorkSessionException(_describe(e));
    }
  }

  /// Kết thúc ca.
  Future<void> checkOut() async {
    try {
      await _dio.post('${await _baseUrl()}/sessions/end',
          options: Options(headers: await _headers()));
    } on DioException catch (e) {
      throw WorkSessionException(_describe(e));
    } finally {
      _cached = null;
      _cachedAt = DateTime.now();
    }
  }

  /// Danh sách người đang trong ca — cho màn hình giám sát của quản lý.
  Future<List<Map<String, dynamic>>> listActive() async {
    try {
      final resp = await _dio.get('${await _baseUrl()}/sessions/active',
          options: Options(headers: await _headers()));
      final data = Map<String, dynamic>.from(resp.data);
      return List<Map<String, dynamic>>.from(
        (data['sessions'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } on DioException catch (e) {
      throw WorkSessionException(_describe(e));
    }
  }

  /// Người này có đang trong ca không — trên BẤT KỲ thiết bị nào.
  ///
  /// Khác với [getCurrent] (hỏi "ai đang cầm máy NÀY"). Dùng khi giao việc cho
  /// người khác: quản lý ngồi laptop cần biết công nhân đã điểm danh trên iPad
  /// hay chưa.
  ///
  /// [identifier] nhận cả mã nhân viên lẫn tên, vì công việc lưu TÊN người
  /// được phân công chứ không lưu mã.
  ///
  /// Mất mạng thì trả `true` — không chặn sản xuất vì Wi-Fi chập chờn. Server
  /// vẫn kiểm độc lập ở `/sync/push`, đó mới là ràng buộc thật.
  Future<bool> isPersonOnShift(String identifier) async {
    final needle = identifier.trim().toLowerCase();
    if (needle.isEmpty) return false;
    try {
      final sessions = await listActive();
      return sessions.any((s) {
        final id = (s['user_id'] ?? '').toString().trim().toLowerCase();
        final name = (s['user_name'] ?? '').toString().trim().toLowerCase();
        return id == needle || name == needle;
      });
    } catch (_) {
      return true;
    }
  }

  /// Nhân viên nào đã được đặt PIN — để màn hình biết có hiện ô nhập PIN không.
  Future<Set<String>> usersWithPin() async {
    try {
      final resp = await _dio.get('${await _baseUrl()}/sessions/pin/status',
          options: Options(headers: await _headers()));
      final data = Map<String, dynamic>.from(resp.data);
      return Set<String>.from(
        (data['users_with_pin'] as List).map((e) => e.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  String _describe(DioException e) {
    final code = e.response?.statusCode;
    final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
    if (code == 401) {
      return 'Máy này chưa đăng ký với hệ thống. Quét mã QR đăng ký trước khi điểm danh.';
    }
    if (code == 403) return detail?.toString() ?? 'Mã PIN không đúng.';
    if (code == 400) return detail?.toString() ?? 'Thông tin điểm danh không hợp lệ.';
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Không kết nối được máy chủ. Kiểm tra Wi-Fi.';
    }
    return e.message ?? 'Lỗi không xác định.';
  }
}

class WorkSessionException implements Exception {
  final String message;
  WorkSessionException(this.message);
  @override
  String toString() => message;
}
