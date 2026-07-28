import 'dart:async';
import 'package:flutter/material.dart';

enum RoomSafetyLevel {
  normal,
  aloneWorkerStarted,  // Orange status
  aloneWorkerTimeout,  // Red status (overdue)
  ropeSafetyTriggered, // Emergency Red Flashing (Pull cord)
  lightCurtainBreached,// Warning Orange Flashing (Optoelectronic curtain breach)
  sensorEmergency,     // Gas/Environmental alert
}

class RoomSafetyStatus {
  final RoomSafetyLevel level;
  final String stageLabel;
  final String? alertMessage;
  final DateTime? startedAt;
  final DateTime? deadline;
  final int? timeLimitMinutes;

  const RoomSafetyStatus({
    required this.level,
    required this.stageLabel,
    this.alertMessage,
    this.startedAt,
    this.deadline,
    this.timeLimitMinutes,
  });

  bool get isAlert =>
      level == RoomSafetyLevel.aloneWorkerTimeout ||
      level == RoomSafetyLevel.ropeSafetyTriggered ||
      level == RoomSafetyLevel.sensorEmergency;

  bool get isAloneWorker =>
      level == RoomSafetyLevel.aloneWorkerStarted ||
      level == RoomSafetyLevel.aloneWorkerTimeout;
}

class SafetyManagementService {
  static final SafetyManagementService _instance = SafetyManagementService._internal();
  factory SafetyManagementService() => _instance;
  SafetyManagementService._internal();

  final _safetyEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get safetyEventStream => _safetyEventController.stream;

  // External live hardware sensor status registry (RoomId -> SensorEvent)
  final Map<String, Map<String, dynamic>> _liveSensorTelemetry = {};

  /// Update live hardware sensor telemetry (Rope Safety, Light Curtain, Motion Sensors, etc.)
  void registerSensorTelemetry(String roomId, Map<String, dynamic> telemetry) {
    _liveSensorTelemetry[roomId] = telemetry;
    _safetyEventController.add({
      'roomId': roomId,
      'telemetry': telemetry,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Evaluates the complete Safety Status for a given room
  RoomSafetyStatus evaluateRoomSafety(Map<String, dynamic>? roomData) {
    if (roomData == null) {
      return const RoomSafetyStatus(
        level: RoomSafetyLevel.normal,
        stageLabel: 'idle',
      );
    }

    final roomId = (roomData['id'] ?? roomData['name'] ?? '').toString();
    final stage = (roomData['current_stage'] ?? 'idle').toString().toLowerCase();

    // 1. Check live Hardware Telemetry (Rope Safety, Light Curtain)
    final telemetry = _liveSensorTelemetry[roomId];
    if (telemetry != null) {
      if (telemetry['rope_pulled'] == true) {
        return const RoomSafetyStatus(
          level: RoomSafetyLevel.ropeSafetyTriggered,
          stageLabel: 'ROPE SAFETY PULL',
          alertMessage: 'EMERGENCY ROPE PULLED',
        );
      }
      if (telemetry['light_curtain_breached'] == true) {
        return const RoomSafetyStatus(
          level: RoomSafetyLevel.lightCurtainBreached,
          stageLabel: 'LIGHT CURTAIN BREACH',
          alertMessage: 'Safety Light Curtain Interrupted',
        );
      }
    }

    // 2. Check Alone Worker Jobs & Deadlines
    final List<Map<String, dynamic>> jobs = roomData['jobs'] != null
        ? List<Map<String, dynamic>>.from(roomData['jobs'])
        : [];

    final activeSoloJob = jobs.firstWhere(
      (j) =>
          j['job_type'] == 'alone_worker' &&
          (j['status'] == 'in_progress' || j['status'] == 'inprog'),
      orElse: () => {},
    );

    final bool stageIsAlone = stage == 'alone_worker';
    final bool stageIsTimeout = stage == 'alone_timeout';

    if (activeSoloJob.isNotEmpty) {
      final startedAtStr =
          activeSoloJob['started_at'] ?? activeSoloJob['scheduled_at'];

      DateTime? startedAt;
      DateTime? deadline;
      int limitMins = (activeSoloJob['time_limit_minutes'] ?? 45) as int;
      bool isOverdue = false;

      if (startedAtStr != null) {
        try {
          startedAt = DateTime.parse(startedAtStr.toString());
          deadline = startedAt.add(Duration(minutes: limitMins));
          if (DateTime.now().isAfter(deadline)) {
            isOverdue = true;
          }
        } catch (_) {}
      }

      if (isOverdue || stageIsTimeout) {
        return RoomSafetyStatus(
          level: RoomSafetyLevel.aloneWorkerTimeout,
          stageLabel: 'alone_timeout',
          alertMessage: 'Alone Worker Check-in Overdue!',
          startedAt: startedAt,
          deadline: deadline,
          timeLimitMinutes: limitMins,
        );
      } else {
        return RoomSafetyStatus(
          level: RoomSafetyLevel.aloneWorkerStarted,
          stageLabel: 'alone_worker',
          alertMessage: 'Alone Worker Active',
          startedAt: startedAt,
          deadline: deadline,
          timeLimitMinutes: limitMins,
        );
      }
    }

    if (stageIsTimeout) {
      return const RoomSafetyStatus(
        level: RoomSafetyLevel.aloneWorkerTimeout,
        stageLabel: 'alone_timeout',
        alertMessage: 'Alone Worker Overdue!',
      );
    }

    if (stageIsAlone) {
      return const RoomSafetyStatus(
        level: RoomSafetyLevel.aloneWorkerStarted,
        stageLabel: 'alone_worker',
      );
    }

    return RoomSafetyStatus(
      level: RoomSafetyLevel.normal,
      stageLabel: stage,
    );
  }

  /// Returns card background color based on RoomSafetyStatus
  Color getCardBackgroundColor(RoomSafetyStatus status, bool isDark, Color defaultColor) {
    switch (status.level) {
      case RoomSafetyLevel.ropeSafetyTriggered:
      case RoomSafetyLevel.aloneWorkerTimeout:
      case RoomSafetyLevel.sensorEmergency:
        return isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50;
      case RoomSafetyLevel.lightCurtainBreached:
      case RoomSafetyLevel.aloneWorkerStarted:
        return isDark ? Colors.orange.withOpacity(0.12) : Colors.orange.shade50;
      case RoomSafetyLevel.normal:
      default:
        return defaultColor;
    }
  }

  /// Returns border color based on RoomSafetyStatus
  Color getBorderColor(RoomSafetyStatus status, Color defaultColor) {
    switch (status.level) {
      case RoomSafetyLevel.ropeSafetyTriggered:
      case RoomSafetyLevel.aloneWorkerTimeout:
      case RoomSafetyLevel.sensorEmergency:
        return Colors.red;
      case RoomSafetyLevel.lightCurtainBreached:
      case RoomSafetyLevel.aloneWorkerStarted:
        return Colors.orange;
      case RoomSafetyLevel.normal:
      default:
        return defaultColor;
    }
  }

  /// Returns box shadow glowing effect based on RoomSafetyStatus
  List<BoxShadow>? getBoxShadow(RoomSafetyStatus status, Color? highlightColor) {
    switch (status.level) {
      case RoomSafetyLevel.ropeSafetyTriggered:
      case RoomSafetyLevel.aloneWorkerTimeout:
      case RoomSafetyLevel.sensorEmergency:
        return [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          )
        ];
      case RoomSafetyLevel.lightCurtainBreached:
      case RoomSafetyLevel.aloneWorkerStarted:
        return [
          BoxShadow(
            color: Colors.orange.withOpacity(0.35),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ];
      case RoomSafetyLevel.normal:
      default:
        if (highlightColor != null) {
          return [
            BoxShadow(
              color: highlightColor.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ];
        }
        return null;
    }
  }

  /// Returns tag text color based on RoomSafetyStatus
  Color getTagColor(RoomSafetyStatus status, Color fallbackColor) {
    switch (status.level) {
      case RoomSafetyLevel.ropeSafetyTriggered:
      case RoomSafetyLevel.aloneWorkerTimeout:
      case RoomSafetyLevel.sensorEmergency:
        return Colors.red;
      case RoomSafetyLevel.lightCurtainBreached:
      case RoomSafetyLevel.aloneWorkerStarted:
        return Colors.orange;
      case RoomSafetyLevel.normal:
      default:
        return fallbackColor;
    }
  }
}
