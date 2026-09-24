import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as d;

import '../database/app_database.dart';
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

  final bool isOnBreak;
  final DateTime? breakStartedAt;

  WorkSession({
    required this.id,
    required this.userId,
    this.userName = '',
    this.department = '',
    this.zone = '',
    this.method = 'list',
    this.startedAt,
    this.isOnBreak = false,
    this.breakStartedAt,
  });

  factory WorkSession.fromJson(Map<String, dynamic> j) => WorkSession(
        id: (j['id'] ?? '').toString(),
        userId: (j['user_id'] ?? '').toString(),
        userName: (j['user_name'] ?? '').toString(),
        department: (j['department'] ?? '').toString(),
        zone: (j['zone'] ?? '').toString(),
        method: (j['method'] ?? 'list').toString(),
        startedAt: DateTime.tryParse((j['started_at'] ?? '').toString()),
        isOnBreak: j['is_on_break'] == true,
        breakStartedAt:
            DateTime.tryParse((j['break_started_at'] ?? '').toString()),
      );

  WorkSession copyWith({
    String? id,
    String? userId,
    String? userName,
    String? department,
    String? zone,
    String? method,
    DateTime? startedAt,
    bool? isOnBreak,
    DateTime? breakStartedAt,
  }) {
    return WorkSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      department: department ?? this.department,
      zone: zone ?? this.zone,
      method: method ?? this.method,
      startedAt: startedAt ?? this.startedAt,
      isOnBreak: isOnBreak ?? this.isOnBreak,
      breakStartedAt: breakStartedAt ?? this.breakStartedAt,
    );
  }

  String get displayName => userName.isNotEmpty ? userName : userId;

  Duration get elapsed => startedAt == null
      ? Duration.zero
      : DateTime.now().difference(startedAt!.toLocal());

  String get elapsedText {
    final d = elapsed;
    if (d.inHours > 0) return '${d.inHours} hours ${d.inMinutes % 60} minutes';
    return '${d.inMinutes} minutes';
  }

  Duration get breakElapsed => breakStartedAt == null
      ? Duration.zero
      : DateTime.now().difference(breakStartedAt!.toLocal());

  String get breakElapsedText {
    final d = breakElapsed;
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes} minutes';
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
    if (!force &&
        _cachedAt != null &&
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
      if (_cached != null) {
        await _enrichWithBreakState(_cached!);
      }
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

  /// Tra cứu sự kiện nghỉ gần nhất trong CSDL cục bộ để khôi phục trạng thái nghỉ.
  Future<void> _enrichWithBreakState(WorkSession session) async {
    try {
      final db = AppDatabase();
      final lastEvent = await (db.select(db.mushroomAttendanceEvents)
            ..where((tbl) => tbl.employeeId.equals(session.userId))
            ..orderBy([(t) => d.OrderingTerm.desc(t.timestamp)])
            ..limit(1))
          .getSingleOrNull();

      if (lastEvent != null && lastEvent.eventType == 'BREAK_START') {
        _cached = session.copyWith(
          isOnBreak: true,
          breakStartedAt: lastEvent.timestamp,
        );
      }
    } catch (_) {}
  }

  /// Bắt đầu nghỉ giải lao (Break Start) — ghi sự kiện và đổi trạng thái.
  Future<void> startBreak({String? planId}) async {
    final s = _cached;
    if (s == null) return;
    final now = DateTime.now();
    try {
      final db = AppDatabase();
      await db.into(db.mushroomAttendanceEvents).insert(
            MushroomAttendanceEventsCompanion.insert(
              id: 'AE_${now.millisecondsSinceEpoch}',
              employeeId: s.userId,
              planId: d.Value(planId),
              eventType: 'BREAK_START',
              timestamp: d.Value(now),
              source: 'MANUAL',
            ),
          );
    } catch (_) {}
    _cached = s.copyWith(isOnBreak: true, breakStartedAt: now);
    _cachedAt = DateTime.now();
  }

  /// Kết thúc nghỉ giải lao (Break End) — ghi sự kiện và quay lại làm việc.
  Future<void> endBreak({String? planId}) async {
    final s = _cached;
    if (s == null) return;
    final now = DateTime.now();
    try {
      final db = AppDatabase();
      await db.into(db.mushroomAttendanceEvents).insert(
            MushroomAttendanceEventsCompanion.insert(
              id: 'AE_${now.millisecondsSinceEpoch}',
              employeeId: s.userId,
              planId: d.Value(planId),
              eventType: 'BREAK_END',
              timestamp: d.Value(now),
              source: 'MANUAL',
            ),
          );
    } catch (_) {}
    _cached = s.copyWith(isOnBreak: false, breakStartedAt: null);
    _cachedAt = DateTime.now();
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

  /// Người này có đang trong ca không — trên BẤT KỲ thiết bị nào hoặc qua điểm danh theo nhóm.
  ///
  /// Khác với [getCurrent] (hỏi "ai đang cầm máy NÀY"). Dùng khi giao việc cho
  /// người khác: quản lý ngồi laptop cần biết công nhân đã điểm danh trên iPad
  /// hay qua Batch Attendance hay chưa.
  ///
  /// [identifier] nhận cả mã nhân viên lẫn tên, vì công việc lưu TÊN người
  /// được phân công chứ không lưu mã.
  ///
  /// Ưu tiên 1: Tra cứu CSDL cục bộ (tức thời khi vừa điểm danh Batch trên máy này).
  /// Ưu tiên 2: Tra cứu máy chủ qua `/sessions/active`.
  Future<bool> isPersonOnShift(String identifier) async {
    final raw = identifier.trim();
    if (raw.isEmpty) return false;

    // 1. Kiểm tra CSDL cục bộ trước (khi Manager vừa batch checkin trên máy hoặc thiết bị offline)
    try {
      final db = AppDatabase();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Tách mã trong ngoặc nếu có dạng "Tên (Mã)"
      String cleanName = raw;
      String? extractedId;
      final match = RegExp(r'^(.*?)\s*\(([^)]+)\)$').firstMatch(raw);
      if (match != null) {
        cleanName = match.group(1)?.trim() ?? raw;
        extractedId = match.group(2)?.trim();
      }

      final cleanLower = cleanName.toLowerCase();
      final rawLower = raw.toLowerCase();
      final extLower = extractedId?.toLowerCase();

      // Tra cứu nhân sự trong CSDL cục bộ để lấy id và name chuẩn
      final emps = await db.select(db.mushroomEmployees).get();
      final matchedEmp = emps.cast<MushroomEmployee?>().firstWhere(
        (e) {
          if (e == null) return false;
          final eName = e.name.trim().toLowerCase();
          final eId = e.id.trim().toLowerCase();
          return eName == cleanLower ||
              eId == cleanLower ||
              eName == rawLower ||
              eId == rawLower ||
              (extLower != null && (eId == extLower || eName == extLower));
        },
        orElse: () => null,
      );

      final empId = matchedEmp?.id ?? extractedId ?? raw;
      final empName = matchedEmp?.name ?? cleanName;

      // Kiểm tra bảng timesheet hôm nay: check_in_time có và check_out_time chưa có
      final ts = await (db.select(db.mushroomDailyTimesheets)
            ..where((t) =>
                (t.employeeId.equals(empId) | t.employeeId.equals(empName)) &
                t.planDate.isBiggerOrEqualValue(startOfDay) &
                t.planDate.isSmallerOrEqualValue(endOfDay)))
          .get();

      if (ts.any((t) => t.checkInTime != null && t.checkOutTime == null)) {
        return true;
      }

      // Kiểm tra sự kiện điểm danh gần nhất hôm nay
      final events = await (db.select(db.mushroomAttendanceEvents)
            ..where((e) =>
                (e.employeeId.equals(empId) | e.employeeId.equals(empName)) &
                e.timestamp.isBiggerOrEqualValue(startOfDay) &
                e.timestamp.isSmallerOrEqualValue(endOfDay))
            ..orderBy([(e) => d.OrderingTerm.desc(e.timestamp)])
            ..limit(1))
          .get();

      if (events.isNotEmpty) {
        final lastEv = events.first.eventType;
        if (lastEv == 'CHECK_IN' || lastEv == 'BREAK_END') {
          return true;
        }
      }
    } catch (_) {}

    // 2. Tra cứu danh sách active sessions trên máy chủ
    try {
      final sessions = await listActive();

      String cleanName = raw;
      String? extractedId;
      final match = RegExp(r'^(.*?)\s*\(([^)]+)\)$').firstMatch(raw);
      if (match != null) {
        cleanName = match.group(1)?.trim() ?? raw;
        extractedId = match.group(2)?.trim();
      }

      final needle = raw.toLowerCase();
      final cleanLower = cleanName.toLowerCase();
      final extLower = extractedId?.toLowerCase();

      return sessions.any((s) {
        final id = (s['user_id'] ?? '').toString().trim().toLowerCase();
        final name = (s['user_name'] ?? '').toString().trim().toLowerCase();
        if (id.isEmpty && name.isEmpty) return false;

        final idMatch = id.isNotEmpty && (
          id == needle ||
          id == cleanLower ||
          (extLower != null && id == extLower)
        );
        final nameMatch = name.isNotEmpty && (
          name == needle ||
          name == cleanLower ||
          (extLower != null && name == extLower) ||
          (cleanLower.isNotEmpty && cleanLower.length >= 3 && name.length >= 3 && (name.contains(cleanLower) || cleanLower.contains(name)))
        );
        return idMatch || nameMatch;
      });
    } catch (_) {
      // Khi không tra cứu được server và CSDL cục bộ cũng không xác nhận:
      // Không cho phép bỏ qua kiểm tra an toàn Alone Worker.
      return false;
    }
  }

  /// Lấy tập hợp tất cả định danh (id, name dạng lowercase) của các nhân viên đang trong ca (Checked In).
  /// Kết hợp cả CSDL cục bộ (Daily Timesheets, Attendance Events) và máy chủ (/sessions/active).
  Future<Set<String>> getCheckedInIdentifiers() async {
    final Set<String> checkedIn = {};

    // 1. CSDL cục bộ
    try {
      final db = AppDatabase();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Timesheet hôm nay đã check-in và chưa check-out
      final ts = await (db.select(db.mushroomDailyTimesheets)
            ..where((t) =>
                t.planDate.isBiggerOrEqualValue(startOfDay) &
                t.planDate.isSmallerOrEqualValue(endOfDay)))
          .get();

      for (final t in ts) {
        if (t.checkInTime != null && t.checkOutTime == null) {
          final id = t.employeeId.trim().toLowerCase();
          if (id.isNotEmpty) checkedIn.add(id);
        }
      }

      // Sự kiện điểm danh hôm nay
      final events = await (db.select(db.mushroomAttendanceEvents)
            ..where((e) =>
                e.timestamp.isBiggerOrEqualValue(startOfDay) &
                e.timestamp.isSmallerOrEqualValue(endOfDay))
            ..orderBy([(e) => d.OrderingTerm.desc(e.timestamp)]))
          .get();

      final seen = <String>{};
      for (final ev in events) {
        final empId = ev.employeeId.trim().toLowerCase();
        if (seen.add(empId)) {
          if (ev.eventType == 'CHECK_IN' || ev.eventType == 'BREAK_END') {
            if (empId.isNotEmpty) checkedIn.add(empId);
          }
        }
      }

      // Đối chiếu nhân sự để nạp cả name lẫn id
      final emps = await db.select(db.mushroomEmployees).get();
      for (final emp in emps) {
        final idLower = emp.id.trim().toLowerCase();
        final nameLower = emp.name.trim().toLowerCase();
        if (checkedIn.contains(idLower) && nameLower.isNotEmpty) {
          checkedIn.add(nameLower);
        } else if (checkedIn.contains(nameLower) && idLower.isNotEmpty) {
          checkedIn.add(idLower);
        }
      }
    } catch (_) {}

    // 2. Tra cứu máy chủ qua /sessions/active
    try {
      final sessions = await listActive();
      for (final s in sessions) {
        final id = (s['user_id'] ?? '').toString().trim().toLowerCase();
        final name = (s['user_name'] ?? '').toString().trim().toLowerCase();
        if (id.isNotEmpty) checkedIn.add(id);
        if (name.isNotEmpty) checkedIn.add(name);
      }
    } catch (_) {}

    return checkedIn;
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
      // Phân biệt "chưa từng đăng ký" với "đã đăng ký nhưng token chết".
      // Gộp chung thành một câu khiến người dùng quét lại mã, thấy báo "máy đã
      // đăng ký rồi", rồi quay lại đây vẫn bị chặn — vòng luẩn quẩn đã gặp.
      return 'The server does not accept this device’s token.\n\n'
          'If the device has been registered before, it is likely that the server has been reinstalled, '
          'rendering the old token invalid. Please ask your manager for a new QR code and scan it.';
    }
    if (code == 403) return detail?.toString() ?? 'Incorrect PIN.';
    if (code == 400) {
      return detail?.toString() ?? 'Invalid check-in information.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot connect to the server. Please check your Wi-Fi connection.';
    }
    return e.message ?? 'Undefined error.';
  }
}

class WorkSessionException implements Exception {
  final String message;
  WorkSessionException(this.message);
  @override
  String toString() => message;
}
