import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/mushrooms/services/safety_management_service.dart';

void main() {
  group('SafetyManagementService Verification', () {
    late SafetyManagementService service;

    setUp(() {
      service = SafetyManagementService();
    });

    test('Evaluates normal room status when no safety events exist', () {
      final status = service.evaluateRoomSafety({
        'id': 'Room 1',
        'current_stage': 'growing',
      });

      expect(status.level, equals(RoomSafetyLevel.normal));
      expect(status.stageLabel, equals('growing'));
      expect(status.isAlert, isFalse);
    });

    test('Evaluates Alone Worker Started status with Orange border & fill', () {
      final status = service.evaluateRoomSafety({
        'id': 'Room 5',
        'current_stage': 'alone_worker',
        'jobs': [
          {
            'job_type': 'alone_worker',
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
            'time_limit_minutes': 45,
          }
        ]
      });

      expect(status.level, equals(RoomSafetyLevel.aloneWorkerStarted));
      expect(status.stageLabel, equals('alone_worker'));

      final borderColor = service.getBorderColor(status, Colors.grey);
      expect(borderColor, equals(Colors.orange));
    });

    test('Evaluates Alone Worker Timeout status when deadline passes', () {
      final overdueTime = DateTime.now().subtract(const Duration(minutes: 60));
      final status = service.evaluateRoomSafety({
        'id': 'Room 5',
        'current_stage': 'alone_worker',
        'jobs': [
          {
            'job_type': 'alone_worker',
            'status': 'in_progress',
            'started_at': overdueTime.toIso8601String(),
            'time_limit_minutes': 45,
          }
        ]
      });

      expect(status.level, equals(RoomSafetyLevel.aloneWorkerTimeout));
      expect(status.stageLabel, equals('alone_timeout'));
      expect(status.isAlert, isTrue);

      final borderColor = service.getBorderColor(status, Colors.grey);
      expect(borderColor, equals(Colors.red));
    });

    test('Registers hardware Rope Safety pull telemetry', () {
      service.registerSensorTelemetry('Room 12', {
        'rope_pulled': true,
      });

      final status = service.evaluateRoomSafety({
        'id': 'Room 12',
        'current_stage': 'growing',
      });

      expect(status.level, equals(RoomSafetyLevel.ropeSafetyTriggered));
      expect(status.stageLabel, equals('ROPE SAFETY PULL'));
      expect(status.isAlert, isTrue);

      final borderColor = service.getBorderColor(status, Colors.grey);
      expect(borderColor, equals(Colors.red));
    });

    test('Registers hardware Light Curtain breach telemetry', () {
      service.registerSensorTelemetry('Room 20', {
        'light_curtain_breached': true,
      });

      final status = service.evaluateRoomSafety({
        'id': 'Room 20',
        'current_stage': 'growing',
      });

      expect(status.level, equals(RoomSafetyLevel.lightCurtainBreached));
      expect(status.stageLabel, equals('LIGHT CURTAIN BREACH'));

      final borderColor = service.getBorderColor(status, Colors.grey);
      expect(borderColor, equals(Colors.orange));
    });
  });
}
