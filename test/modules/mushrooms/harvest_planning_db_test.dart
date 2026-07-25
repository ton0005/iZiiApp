// test/modules/mushrooms/harvest_planning_db_test.dart

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:izii_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Harvest Planning - Database Schema Verification', () {
    test('Can insert and retrieve Mushroom Employees with new custom columns', () async {
      await db.into(db.mushroomEmployees).insert(
            MushroomEmployeesCompanion.insert(
              id: 'EMP_H001',
              name: 'John Doe',
              role: 'Picker',
              department: const Value('Harvesting'),
              employmentType: const Value('Senior'),
              baseRate: const Value(28.5),
              defaultShed: const Value('M1'),
              pickerTeamColor: const Value('Pearl'),
            ),
          );

      final employee = await (db.select(db.mushroomEmployees)
            ..where((t) => t.id.equals('EMP_H001')))
          .getSingle();

      expect(employee.name, equals('John Doe'));
      expect(employee.role, equals('Picker'));
      expect(employee.employmentType, equals('Senior'));
      expect(employee.baseRate, equals(28.5));
      expect(employee.defaultShed, equals('M1'));
      expect(employee.pickerTeamColor, equals('Pearl'));
    });

    test('Can create and query Harvest Plan, Shifts, and Teams', () async {
      final planDate = DateTime(2026, 7, 24);
      const planId = 'PLAN_20260724';

      // 1. Insert plan
      await db.into(db.mushroomHarvestPlans).insert(
            MushroomHarvestPlansCompanion.insert(
              id: planId,
              planDate: planDate,
              zoneId: const Value('M2'),
              status: const Value('published'),
              totalTargetBoxes: const Value(450),
            ),
          );

      // 2. Insert shift
      await db.into(db.mushroomShifts).insert(
            MushroomShiftsCompanion.insert(
              id: 'SHIFT_001',
              planId: planId,
              role: 'TEAM_LEADER',
              employeeId: 'EMP_LEADER',
              startTime: Value(planDate.add(const Duration(hours: 7))),
              shedRoomListJson: const Value('["Room 3", "Room 4"]'),
            ),
          );

      // 3. Insert picker team
      await db.into(db.mushroomPickerTeams).insert(
            MushroomPickerTeamsCompanion.insert(
              id: 'TEAM_PEARL',
              planId: planId,
              colorCode: 'Pearl',
              teamLeaderId: const Value('EMP_LEADER'),
              headcount: const Value(8),
              rateEstimate: const Value(31.9),
              memberIdsJson: const Value('["EMP_01", "EMP_02"]'),
            ),
          );

      // Verify Plan details
      final plan = await (db.select(db.mushroomHarvestPlans)
            ..where((t) => t.id.equals(planId)))
          .getSingle();
      expect(plan.zoneId, equals('M2'));
      expect(plan.status, equals('published'));
      expect(plan.totalTargetBoxes, equals(450));

      // Verify Team details
      final team = await (db.select(db.mushroomPickerTeams)
            ..where((t) => t.id.equals('TEAM_PEARL')))
          .getSingle();
      expect(team.colorCode, equals('Pearl'));
      expect(team.headcount, equals(8));
      expect(team.rateEstimate, equals(31.9));
    });

    test('Can insert and retrieve Room Assignments and Attendance Events', () async {
      const planId = 'PLAN_20260724';

      // 1. Insert room assignment
      await db.into(db.mushroomRoomAssignments).insert(
            MushroomRoomAssignmentsCompanion.insert(
              id: 'ASSIGN_001',
              planId: planId,
              roomId: 'room_3',
              boxTarget: const Value(150),
              trolleyCount: const Value(4),
              teamAssignmentsJson: const Value('[{"teamColor": "Pearl", "headcount": 8}]'),
              pickingInstructionsJson: const Value('["SSA", "Clumps"]'),
              notes: const Value('Handle carefully'),
            ),
          );

      // 2. Insert attendance events
      final eventTime = DateTime.now();
      await db.into(db.mushroomAttendanceEvents).insert(
            MushroomAttendanceEventsCompanion.insert(
              id: 'EVENT_001',
              employeeId: 'EMP_H001',
              planId: const Value(planId),
              eventType: 'CHECK_IN',
              timestamp: Value(eventTime),
              source: 'QR',
              location: const Value('Shed 2'),
            ),
          );

      final assignment = await (db.select(db.mushroomRoomAssignments)
            ..where((t) => t.id.equals('ASSIGN_001')))
          .getSingle();
      expect(assignment.roomId, equals('room_3'));
      expect(assignment.boxTarget, equals(150));
      expect(assignment.pickingInstructionsJson, equals('["SSA", "Clumps"]'));

      final event = await (db.select(db.mushroomAttendanceEvents)
            ..where((t) => t.id.equals('EVENT_001')))
          .getSingle();
      expect(event.eventType, equals('CHECK_IN'));
      expect(event.source, equals('QR'));
    });

    test('Timesheets and Payroll Calculation CRUD', () async {
      final today = DateTime.now();

      // 1. Insert daily timesheet
      await db.into(db.mushroomDailyTimesheets).insert(
            MushroomDailyTimesheetsCompanion.insert(
              id: 'TS_001',
              employeeId: 'EMP_H001',
              planDate: today,
              checkInTime: Value(today.subtract(const Duration(hours: 8))),
              checkOutTime: Value(today),
              totalBreakTakenMinutes: const Value(45),
              standardBreakAllowedMinutes: const Value(30),
              extraBreakMinutes: const Value(15),
              grossWorkedMinutes: const Value(480),
              paidMinutes: const Value(435), // 480 - 30 (std break) - 15 (extra break)
              status: const Value('needs_review'),
            ),
          );

      // 2. Insert payroll calculations
      await db.into(db.mushroomPayrollCalculations).insert(
            MushroomPayrollCalculationsCompanion.insert(
              id: 'PAY_001',
              employeeId: 'EMP_H001',
              payPeriod: '2026-W30',
              totalPaidHours: const Value(7.25),
              basePay: const Value(206.63), // 7.25 * 28.5
              totalPay: const Value(206.63),
            ),
          );

      final timesheet = await (db.select(db.mushroomDailyTimesheets)
            ..where((t) => t.id.equals('TS_001')))
          .getSingle();
      expect(timesheet.totalBreakTakenMinutes, equals(45));
      expect(timesheet.extraBreakMinutes, equals(15));
      expect(timesheet.paidMinutes, equals(435));
      expect(timesheet.status, equals('needs_review'));

      final payroll = await (db.select(db.mushroomPayrollCalculations)
            ..where((t) => t.id.equals('PAY_001')))
          .getSingle();
      expect(payroll.payPeriod, equals('2026-W30'));
      expect(payroll.totalPaidHours, equals(7.25));
      expect(payroll.basePay, equals(206.63));
    });
  });
}
