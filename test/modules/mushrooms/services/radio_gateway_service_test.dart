import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/mushrooms/services/radio_gateway_service.dart';

void main() {
  group('RadioAlarm.fromJson', () {
    test('linked alarm from bound radio', () {
      final a = RadioAlarm.fromJson({
        'id': 'ralm_1',
        'radio_id': '1001',
        'event_type': 'man_down',
        'status': 'open',
        'received_at': '2026-10-10T01:02:03+00:00',
        'latitude': -37.81,
        'longitude': 144.96,
        'employee_id': 'EMP001',
        'employee_name': 'Nguyen Van A',
        'job_id': 'job-1',
        'repeat_count': 2,
        'system': 'dmr',
      });
      expect(a.label, 'MAN DOWN');
      expect(a.holder, 'Nguyen Van A');
      expect(a.needsAction, isTrue);
      expect(a.hasLocation, isTrue);
      expect(a.isUnbound, isFalse);
      expect(a.repeatCount, 2);
      expect(a.receivedAt, isNotNull);
    });

    test('unbound radio and cancelled-on-radio still needs action', () {
      final a = RadioAlarm.fromJson({
        'id': 'ralm_2',
        'radio_id': '9999',
        'event_type': 'sos',
        'status': 'cancelled_on_radio',
      });
      expect(a.isUnbound, isTrue);
      expect(a.holder, 'Unassigned radio');
      expect(a.needsAction, isTrue);
      expect(a.hasLocation, isFalse);
    });

    test('acknowledged alarm no longer needs action', () {
      final a = RadioAlarm.fromJson({
        'id': 'ralm_3',
        'radio_id': '1001',
        'event_type': 'lone_worker',
        'status': 'acknowledged',
        'acked_by': 'Supervisor',
      });
      expect(a.label, 'LONE WORKER TIMEOUT');
      expect(a.needsAction, isFalse);
    });
  });

  test('RadioDevice.fromJson reads sqlite-style ints', () {
    final d = RadioDevice.fromJson({
      'radio_id': '2001',
      'system': 'tetra',
      'model': 'PT580H',
      'active': 1,
      'last_battery': 76.0,
    });
    expect(d.active, isTrue);
    expect(d.isAssigned, isFalse);
    expect(d.system, 'tetra');
  });

  group('RadioCommand.fromJson', () {
    test('Lone Worker status answered by the radio', () {
      final c = RadioCommand.fromJson({
        'id': 'rcmd_1',
        'radio_id': '507',
        'command': 'lone_worker_status',
        'status': 'done',
        'params': {},
        'result': {'lone_worker': 'on'},
        'reason': 'manual',
        'created_at': '2026-11-02T08:00:00+00:00',
      });
      expect(c.isFinished, isTrue);
      expect(c.isOk, isTrue);
      expect(c.loneWorker, 'on');
    });

    test('time-out message still on its way', () {
      final c = RadioCommand.fromJson({
        'id': 'rcmd_2',
        'radio_id': '507',
        'command': 'text_message',
        'status': 'sent',
        'params': {'text': 'ALONE WORKER TIMEOUT - Room 6A.'},
        'reason': 'alone_worker_timeout',
        'job_id': 'job-1',
      });
      expect(c.isFinished, isFalse);
      expect(c.text, contains('Room 6A'));
      expect(c.jobId, 'job-1');
      expect(c.loneWorker, isNull);
    });

    test('radio unreachable', () {
      final c = RadioCommand.fromJson({
        'id': 'rcmd_3',
        'radio_id': '507',
        'command': 'lone_worker_enable',
        'status': 'failed',
        'error': 'radio did not answer',
      });
      expect(c.isFinished, isTrue);
      expect(c.isOk, isFalse);
      expect(c.error, 'radio did not answer');
    });
  });

  test('RadioDevice reads Lone Worker state and recency', () {
    final d = RadioDevice.fromJson({
      'radio_id': '507',
      'active': 1,
      'lone_worker_state': 'on',
      'lone_worker_checked_at': DateTime.now().toUtc().toIso8601String(),
      'last_seen_at': DateTime.now().toUtc().subtract(const Duration(seconds: 30)).toIso8601String(),
    });
    expect(d.loneWorkerState, 'on');
    expect(d.loneWorkerCheckedAt, isNotNull);
    expect(d.isRecentlySeen(), isTrue);
    expect(d.isRecentlySeen(const Duration(seconds: 10)), isFalse);
  });
}
