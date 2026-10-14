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
}
