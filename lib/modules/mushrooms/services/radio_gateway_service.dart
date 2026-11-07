import 'package:dio/dio.dart';

import '../../../core/settings/settings_service.dart';

/// Hytera radio (DMR / TETRA) alarms bridged into the Alone Worker flow.
///
/// Radios never talk to the app directly: alarms travel radio → repeater →
/// dispatch gateway → iZiiServer (`/api/v1/radio/events`). When the radio
/// holder has an Alone Worker job running, the server flips the same
/// `alarm_triggered` / `alone_timeout` flags the existing alarm UI watches, so
/// those reach every device through normal sync. This service covers what
/// sync does not: alarms not linked to a job (unassigned radio, no active
/// job), supervisor acknowledgement, and radio ↔ employee assignment.
class RadioAlarm {
  final String id;
  final String radioId;
  final String eventType; // sos | man_down | lone_worker
  final String status; // open | cancelled_on_radio | acknowledged
  final DateTime? receivedAt;
  final double? latitude;
  final double? longitude;
  final String? employeeId;
  final String? employeeName;
  final String? jobId;
  final String? roomId;
  final int repeatCount;
  final String? ackedBy;
  final DateTime? ackedAt;
  final String? ackNote;
  final String? system;

  const RadioAlarm({
    required this.id,
    required this.radioId,
    required this.eventType,
    required this.status,
    this.receivedAt,
    this.latitude,
    this.longitude,
    this.employeeId,
    this.employeeName,
    this.jobId,
    this.roomId,
    this.repeatCount = 0,
    this.ackedBy,
    this.ackedAt,
    this.ackNote,
    this.system,
  });

  bool get isUnbound =>
      (employeeId ?? '').isEmpty && (employeeName ?? '').isEmpty;
  bool get needsAction => status == 'open' || status == 'cancelled_on_radio';
  bool get hasLocation => latitude != null && longitude != null;

  String get label {
    switch (eventType) {
      case 'sos':
        return 'SOS';
      case 'man_down':
        return 'MAN DOWN';
      case 'lone_worker':
        return 'LONE WORKER TIMEOUT';
      default:
        return eventType.toUpperCase();
    }
  }

  String get holder => (employeeName ?? '').isNotEmpty
      ? employeeName!
      : ((employeeId ?? '').isNotEmpty ? employeeId! : 'Unassigned radio');

  factory RadioAlarm.fromJson(Map<String, dynamic> j) => RadioAlarm(
        id: j['id'].toString(),
        radioId: (j['radio_id'] ?? '').toString(),
        eventType: (j['event_type'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        receivedAt: DateTime.tryParse((j['received_at'] ?? '').toString())?.toLocal(),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        employeeId: j['employee_id'] as String?,
        employeeName: j['employee_name'] as String?,
        jobId: j['job_id'] as String?,
        roomId: j['room_id'] as String?,
        repeatCount: (j['repeat_count'] as num?)?.toInt() ?? 0,
        ackedBy: j['acked_by'] as String?,
        ackedAt: DateTime.tryParse((j['acked_at'] ?? '').toString())?.toLocal(),
        ackNote: j['ack_note'] as String?,
        system: j['system'] as String?,
      );
}

class RadioDevice {
  final String radioId;
  final String system; // dmr | tetra
  final String? model;
  final String? label;
  final String? employeeId;
  final String? employeeName;
  final bool active;
  final DateTime? lastSeenAt;
  final String? lastEventType;
  final double? lastBattery;
  final double? lastLatitude;
  final double? lastLongitude;
  /// 'on' | 'off' | null (chưa hỏi) — theo kết quả lệnh gần nhất gửi xuống bộ đàm.
  final String? loneWorkerState;
  final DateTime? loneWorkerCheckedAt;

  const RadioDevice({
    required this.radioId,
    required this.system,
    this.model,
    this.label,
    this.employeeId,
    this.employeeName,
    this.active = true,
    this.lastSeenAt,
    this.lastEventType,
    this.lastBattery,
    this.lastLatitude,
    this.lastLongitude,
    this.loneWorkerState,
    this.loneWorkerCheckedAt,
  });

  /// Bridge thấy bộ đàm gửi gói trong [window] gần đây (đăng ký RRS định kỳ, báo động...).
  bool isRecentlySeen([Duration window = const Duration(minutes: 2)]) =>
      lastSeenAt != null && DateTime.now().difference(lastSeenAt!) <= window;

  bool get isAssigned =>
      (employeeId ?? '').isNotEmpty || (employeeName ?? '').isNotEmpty;

  factory RadioDevice.fromJson(Map<String, dynamic> j) => RadioDevice(
        radioId: j['radio_id'].toString(),
        system: (j['system'] ?? 'dmr').toString(),
        model: j['model'] as String?,
        label: j['label'] as String?,
        employeeId: j['employee_id'] as String?,
        employeeName: j['employee_name'] as String?,
        active: j['active'] == true || j['active'] == 1,
        lastSeenAt: DateTime.tryParse((j['last_seen_at'] ?? '').toString())?.toLocal(),
        lastEventType: j['last_event_type'] as String?,
        lastBattery: (j['last_battery'] as num?)?.toDouble(),
        lastLatitude: (j['last_latitude'] as num?)?.toDouble(),
        lastLongitude: (j['last_longitude'] as num?)?.toDouble(),
        loneWorkerState: j['lone_worker_state'] as String?,
        loneWorkerCheckedAt: DateTime.tryParse((j['lone_worker_checked_at'] ?? '').toString())?.toLocal(),
      );
}

/// Lệnh iZii → bộ đàm, đi qua radio_bridge: pending → sent → done | failed | expired.
class RadioCommand {
  final String id;
  final String radioId;
  final String command; // lone_worker_status | lone_worker_enable | lone_worker_disable | text_message
  final String status;
  final Map<String, dynamic> params;
  final Map<String, dynamic>? result;
  final String? error;
  final String? reason; // manual | alone_worker_timeout
  final String? jobId;
  final DateTime? createdAt;
  final DateTime? doneAt;

  const RadioCommand({
    required this.id,
    required this.radioId,
    required this.command,
    required this.status,
    this.params = const {},
    this.result,
    this.error,
    this.reason,
    this.jobId,
    this.createdAt,
    this.doneAt,
  });

  bool get isFinished => status == 'done' || status == 'failed' || status == 'expired';
  bool get isOk => status == 'done';

  /// 'on' / 'off' khi lệnh Lone Worker thành công.
  String? get loneWorker => result?['lone_worker'] as String?;
  String? get text => params['text'] as String?;

  factory RadioCommand.fromJson(Map<String, dynamic> j) => RadioCommand(
        id: j['id'].toString(),
        radioId: (j['radio_id'] ?? '').toString(),
        command: (j['command'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        params: j['params'] is Map ? Map<String, dynamic>.from(j['params'] as Map) : const {},
        result: j['result'] is Map ? Map<String, dynamic>.from(j['result'] as Map) : null,
        error: j['error'] as String?,
        reason: j['reason'] as String?,
        jobId: j['job_id'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal(),
        doneAt: DateTime.tryParse((j['done_at'] ?? '').toString())?.toLocal(),
      );
}

class RadioGatewayService {
  static final RadioGatewayService _instance = RadioGatewayService._internal();
  factory RadioGatewayService() => _instance;
  RadioGatewayService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 12),
  ));
  final SettingsService _settings = SettingsService();

  Future<String> _baseUrl() async =>
      (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');

  /// Device token identifies who acknowledged; the admin token (the Sync
  /// Server auth token on manager devices) is needed to assign radios.
  Future<Map<String, String>> _headers() async {
    final url = await _baseUrl();
    final deviceToken = await _settings.getDeviceToken(url);
    final adminToken = await _settings.getSyncToken();
    return {
      if (deviceToken != null && deviceToken.isNotEmpty) 'X-iZii-Device-Token': deviceToken,
      if (adminToken.isNotEmpty) 'X-iZii-Admin-Token': adminToken,
      'Content-Type': 'application/json',
    };
  }

  Future<List<RadioAlarm>> listAlarms({bool activeOnly = true, int limit = 100}) async {
    final resp = await _dio.get(
      '${await _baseUrl()}/api/v1/radio/alarms',
      queryParameters: {'status': activeOnly ? 'active' : 'all', 'limit': limit},
      options: Options(headers: await _headers()),
    );
    final list = (resp.data['alarms'] as List?) ?? const [];
    return list
        .map((e) => RadioAlarm.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RadioAlarm> acknowledge(String alarmId, {String? note}) async {
    final resp = await _dio.post(
      '${await _baseUrl()}/api/v1/radio/alarms/$alarmId/ack',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
      options: Options(headers: await _headers()),
    );
    return RadioAlarm.fromJson(Map<String, dynamic>.from(resp.data['alarm'] as Map));
  }

  Future<List<RadioDevice>> listDevices() async {
    final resp = await _dio.get(
      '${await _baseUrl()}/api/v1/radio/devices',
      options: Options(headers: await _headers()),
    );
    final list = (resp.data['devices'] as List?) ?? const [];
    return list
        .map((e) => RadioDevice.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Assign (or with empty employee fields, unassign) a radio. Admin only.
  Future<RadioDevice> saveDevice({
    required String radioId,
    String? employeeId,
    String? employeeName,
    String? label,
    String? model,
    String system = 'dmr',
    bool active = true,
  }) async {
    final resp = await _dio.put(
      '${await _baseUrl()}/api/v1/radio/devices/${Uri.encodeComponent(radioId.trim())}',
      data: {
        'employee_id': employeeId,
        'employee_name': employeeName,
        'label': label,
        'model': model,
        'system': system,
        'active': active,
      },
      options: Options(headers: await _headers()),
    );
    return RadioDevice.fromJson(Map<String, dynamic>.from(resp.data['device'] as Map));
  }

  Future<void> deleteDevice(String radioId) async {
    await _dio.delete(
      '${await _baseUrl()}/api/v1/radio/devices/${Uri.encodeComponent(radioId)}',
      options: Options(headers: await _headers()),
    );
  }

  Future<RadioCommand> sendCommand(String radioId, String command, {Map<String, dynamic>? params}) async {
    final resp = await _dio.post(
      '${await _baseUrl()}/api/v1/radio/devices/${Uri.encodeComponent(radioId.trim())}/commands',
      data: {'command': command, if (params != null) 'params': params},
      options: Options(headers: await _headers()),
    );
    return RadioCommand.fromJson(Map<String, dynamic>.from(resp.data['command'] as Map));
  }

  Future<List<RadioCommand>> listCommands({String? radioId, int limit = 50}) async {
    final resp = await _dio.get(
      '${await _baseUrl()}/api/v1/radio/commands',
      queryParameters: {if (radioId != null) 'radio_id': radioId.trim(), 'limit': limit},
      options: Options(headers: await _headers()),
    );
    final list = (resp.data['commands'] as List?) ?? const [];
    return list.map((e) => RadioCommand.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Gửi lệnh rồi chờ bridge báo kết quả (bộ đàm trả lời) — tối đa [timeout].
  Future<RadioCommand> runCommand(
    String radioId,
    String command, {
    Map<String, dynamic>? params,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    var cmd = await sendCommand(radioId, command, params: params);
    final end = DateTime.now().add(timeout);
    while (!cmd.isFinished && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final list = await listCommands(radioId: radioId, limit: 20);
      cmd = list.firstWhere((c) => c.id == cmd.id, orElse: () => cmd);
    }
    return cmd;
  }

  /// Commissioning: push a fake alarm through the real server pipeline.
  /// It DOES raise a real alarm on the holder's Alone Worker job.
  Future<void> simulate(String radioId, String eventType) async {
    await _dio.post(
      '${await _baseUrl()}/api/v1/radio/simulate',
      data: {'radio_id': radioId, 'event_type': eventType},
      options: Options(headers: await _headers()),
    );
  }

  static String describeError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) {
        return 'Not authorised. Enroll this device or set the admin Auth Token in Sync Server settings.';
      }
      if (code == 404) return 'Not found on the server.';
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Unable to connect to the server.';
      }
      final detail = e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
      return detail?.toString() ?? e.message ?? 'Request failed.';
    }
    return e.toString();
  }
}
