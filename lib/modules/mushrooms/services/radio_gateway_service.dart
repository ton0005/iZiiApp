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
  });

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
