import 'dart:math';

/// Department Definition
class PerformanceDept {
  final String id;
  final String name;
  final int colorValue;

  const PerformanceDept({
    required this.id,
    required this.name,
    required this.colorValue,
  });
}

/// Job Type Definition
class PerformanceJobType {
  final String id;
  final String name;
  final double planMinutes;
  final double difficulty;

  const PerformanceJobType({
    required this.id,
    required this.name,
    required this.planMinutes,
    this.difficulty = 1.0,
  });
}

/// Employee Information for Performance Board
class PerformanceEmployee {
  final String id;
  final String name;
  final String role;
  final String deptId;
  final double breakBias;
  final double skill;

  const PerformanceEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.deptId,
    this.breakBias = 0.0,
    this.skill = 1.0,
  });
}

/// Solo Safety Session Info
class SoloSafetyInfo {
  final double limitMinutes;
  final double insideMinutes;
  final double coPpm;
  final double co2Ppm;
  final bool isAlarm;
  final bool isCheckedOut;

  const SoloSafetyInfo({
    required this.limitMinutes,
    required this.insideMinutes,
    required this.coPpm,
    required this.co2Ppm,
    required this.isAlarm,
    required this.isCheckedOut,
  });
}

/// Performance Task Record
class PerformanceTaskRecord {
  final DateTime date;
  final int dayOffset;
  final String employeeId;
  final String deptId;
  final String jobId;
  final double planMinutes;
  final double actualMinutes;
  final int startMinutesOfDay;
  final int roomNumber;
  final bool onTime;
  final SoloSafetyInfo? soloInfo;

  const PerformanceTaskRecord({
    required this.date,
    required this.dayOffset,
    required this.employeeId,
    required this.deptId,
    required this.jobId,
    required this.planMinutes,
    required this.actualMinutes,
    required this.startMinutesOfDay,
    required this.roomNumber,
    required this.onTime,
    this.soloInfo,
  });
}

/// Performance Shift Record
class PerformanceShiftRecord {
  final DateTime date;
  final int dayOffset;
  final String employeeId;
  final String deptId;
  final int checkInMinutes;
  final int checkOutMinutes;
  final double allowedBreakMinutes;
  final double takenBreakMinutes;
  final double extraBreakMinutes;
  final double grossMinutes;
  final double paidMinutes;
  final double overtimeHours;

  const PerformanceShiftRecord({
    required this.date,
    required this.dayOffset,
    required this.employeeId,
    required this.deptId,
    required this.checkInMinutes,
    required this.checkOutMinutes,
    required this.allowedBreakMinutes,
    required this.takenBreakMinutes,
    required this.extraBreakMinutes,
    required this.grossMinutes,
    required this.paidMinutes,
    required this.overtimeHours,
  });
}

/// Aggregate KPI Summary for an Employee
class EmployeePerformanceSummary {
  final String employeeId;
  final String name;
  final String role;
  final String deptId;
  final String deptName;
  final int deptColorValue;
  final int totalJobs;
  final double onTimePercent;
  final double avgMinutesPerJob;
  final double vsPlanPercent;
  final double avgBreakTakenMinutes;
  final double allowedBreakMinutes;
  final double totalOvertimeHours;
  final int soloAlarmCount;
  final int soloTotalSessions;
  final int totalShifts;

  const EmployeePerformanceSummary({
    required this.employeeId,
    required this.name,
    required this.role,
    required this.deptId,
    required this.deptName,
    required this.deptColorValue,
    required this.totalJobs,
    required this.onTimePercent,
    required this.avgMinutesPerJob,
    required this.vsPlanPercent,
    required this.avgBreakTakenMinutes,
    required this.allowedBreakMinutes,
    required this.totalOvertimeHours,
    required this.soloAlarmCount,
    required this.soloTotalSessions,
    required this.totalShifts,
  });
}

/// Default Constants & Simulation Dataset Generator
class GrowingPerformanceConstants {
  static const List<PerformanceDept> defaultDepartments = [
    PerformanceDept(id: 'growing', name: 'Growing', colorValue: 0xFF2A78D6),
    PerformanceDept(id: 'harvest', name: 'Harvest', colorValue: 0xFFEB6834),
    PerformanceDept(id: 'maintenance', name: 'Maintenance', colorValue: 0xFF1BAF7A),
  ];

  static const List<PerformanceJobType> defaultJobTypes = [
    PerformanceJobType(id: 'clean_room', name: 'Clean Room', planMinutes: 45, difficulty: 1.15),
    PerformanceJobType(id: 'clean_bed', name: 'Clean Bed', planMinutes: 35, difficulty: 1.05),
    PerformanceJobType(id: 'watering', name: 'Watering', planMinutes: 25, difficulty: 0.95),
    PerformanceJobType(id: 'filling', name: 'Filling', planMinutes: 60, difficulty: 1.20),
    PerformanceJobType(id: 'airing', name: 'Airing', planMinutes: 20, difficulty: 0.90),
    PerformanceJobType(id: 'prochloraz', name: 'Prochloraz', planMinutes: 30, difficulty: 1.00),
    PerformanceJobType(id: 'packup_tree', name: 'Pack Up Tree', planMinutes: 50, difficulty: 1.08),
    PerformanceJobType(id: 'alone_worker', name: 'Alone Worker', planMinutes: 40, difficulty: 1.00),
  ];

  static const List<PerformanceEmployee> defaultEmployees = [
    PerformanceEmployee(id: 'EMP001', name: 'Minh T.', role: 'Growing Specialist', deptId: 'growing', breakBias: -2, skill: 0.92),
    PerformanceEmployee(id: 'EMP002', name: 'Lan N.', role: 'Supervisor', deptId: 'growing', breakBias: -1, skill: 0.88),
    PerformanceEmployee(id: '305629', name: 'Vinh Phan', role: 'Growing Lead', deptId: 'growing', breakBias: 0, skill: 0.85),
    PerformanceEmployee(id: '306606', name: 'Andrew', role: 'Growing Specialist', deptId: 'growing', breakBias: 12, skill: 1.05),
    PerformanceEmployee(id: 'EMP003', name: 'Hùng V.', role: 'Harvest Specialist', deptId: 'harvest', breakBias: -2, skill: 0.90),
    PerformanceEmployee(id: 'EMP004', name: 'Phúc D.', role: 'Harvest Picker', deptId: 'harvest', breakBias: 6, skill: 0.95),
    PerformanceEmployee(id: '333333', name: 'Costa User', role: 'Operator', deptId: 'growing', breakBias: -6, skill: 1.00),
    PerformanceEmployee(id: '555555', name: 'System Admin', role: 'Admin', deptId: 'maintenance', breakBias: 1, skill: 0.80),
  ];

  /// Generates a realistic 30-day simulated dataset based on the HTML mathematical model
  static (List<PerformanceTaskRecord>, List<PerformanceShiftRecord>) generateSimulatedDataset() {
    final List<PerformanceTaskRecord> taskRows = [];
    final List<PerformanceShiftRecord> shiftRows = [];
    final now = DateTime.now(); // Current today anchor date
    final rng = Random(42); // Fixed seed for reproducible data

    double rnd() => rng.nextDouble();
    int ri(int min, int max) => min + rng.nextInt(max - min + 1);

    for (int off = 29; off >= 0; off--) {
      final date = now.subtract(Duration(days: off));
      final dow = date.weekday; // 7 = Sunday
      if (dow == 7) continue; // Sunday off

      final loadFactor = (dow == 6) ? 0.5 : 1.0;

      for (final emp in defaultEmployees) {
        final baseJobs = (emp.deptId == 'maintenance' ? 3 : 6);
        final nJobs = max(1, (baseJobs * loadFactor + (rnd() * 3 - 1.5)).round());

        // Work shift
        final inMin = 6 * 60 + ri(-12, 18);
        const allowed = 30.0;
        final taken = max(14.0, (allowed + emp.breakBias + (rnd() * 16 - 7)).roundToDouble());
        final extra = max(0.0, taken - allowed);
        final gross = ((dow == 6 ? 300 : 510) + (rnd() * 70 - 25)).roundToDouble();
        final paid = gross - extra;
        final ot = max(0.0, (paid - (dow == 6 ? 300 : 480)) / 60.0);

        shiftRows.add(PerformanceShiftRecord(
          date: date,
          dayOffset: off,
          employeeId: emp.id,
          deptId: emp.deptId,
          checkInMinutes: inMin,
          checkOutMinutes: (inMin + gross + taken).toInt(),
          allowedBreakMinutes: allowed,
          takenBreakMinutes: taken,
          extraBreakMinutes: extra,
          grossMinutes: gross,
          paidMinutes: paid,
          overtimeHours: (ot * 10).round() / 10,
        ));

        int clock = inMin + ri(10, 40);
        for (int j = 0; j < nJobs; j++) {
          var jt = defaultJobTypes[ri(0, defaultJobTypes.length - 1)];
          if (emp.deptId == 'maintenance' && rnd() < 0.5) {
            jt = defaultJobTypes[ri(0, 2)];
          }

          final room = ri(1, 60);
          final noise = 1.0 + (rnd() * 0.42 - 0.20);
          var actual = max(6.0, (jt.planMinutes * jt.difficulty * emp.skill * noise).roundToDouble());
          final started = clock;
          clock += actual.toInt() + ri(6, 22);
          final grace = (jt.planMinutes * 0.10).round();
          var onTime = actual <= (jt.planMinutes + grace);

          SoloSafetyInfo? solo;
          if (jt.id == 'alone_worker') {
            final limits = [30.0, 45.0, 60.0, 90.0, 120.0];
            final limit = limits[ri(0, limits.length - 1)];
            final inside = max(8.0, (limit * (0.5 + rnd() * 0.56)).roundToDouble());
            actual = inside;
            onTime = inside <= limit;

            final co = rnd() < 0.10
                ? ((86 + rnd() * 30) * 10).round() / 10
                : ((8 + rnd() * 60) * 10).round() / 10;
            final co2 = rnd() < 0.10
                ? ((4600 + rnd() * 1100) / 10).round() * 10.0
                : ((500 + rnd() * 3300) / 10).round() * 10.0;

            final isAlarm = inside > limit || co > 85.0 || co2 > 4500.0;
            final isCheckedOut = inside <= limit || rnd() > 0.4;

            solo = SoloSafetyInfo(
              limitMinutes: limit,
              insideMinutes: inside,
              coPpm: co,
              co2Ppm: co2,
              isAlarm: isAlarm,
              isCheckedOut: isCheckedOut,
            );
          }

          taskRows.add(PerformanceTaskRecord(
            date: date,
            dayOffset: off,
            employeeId: emp.id,
            deptId: emp.deptId,
            jobId: jt.id,
            planMinutes: jt.planMinutes,
            actualMinutes: actual,
            startMinutesOfDay: started,
            roomNumber: room,
            onTime: onTime,
            soloInfo: solo,
          ));
        }
      }
    }

    return (taskRows, shiftRows);
  }
}