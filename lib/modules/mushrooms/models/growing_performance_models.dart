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

/// Job Type Definition — operational standard time per job type.
/// This is a business rule (target/plan duration), not a value stored in the
/// database — MushroomJobs only records real actual timestamps, so the
/// "planned" reference used to compute on-time rate has to live somewhere.
class PerformanceJobType {
  final String id;
  final String name;
  final double planMinutes;
  final double difficulty;
  final String? color;

  const PerformanceJobType({
    required this.id,
    required this.name,
    required this.planMinutes,
    this.difficulty = 1.0,
    this.color,
  });
}

/// Employee Information for Performance Board
class PerformanceEmployee {
  final String id;
  final String name;
  final String role;
  final String deptId;

  const PerformanceEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.deptId,
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

/// Standard/plan-time reference table (business constants — see
/// [PerformanceJobType] doc). Real job records (id, room, assignee, actual
/// timestamps, gas levels, on-time status, department/employee lists) all
/// come from the SQLite database via [GrowingPerformanceService] — see
/// lib/modules/mushrooms/services/growing_performance_service.dart.
class GrowingPerformanceConstants {
  static const List<PerformanceJobType> defaultJobTypes = [
    PerformanceJobType(id: 'clean_room', name: 'Clean Room', planMinutes: 45, difficulty: 1.15),
    PerformanceJobType(id: 'clean_bed', name: 'Clean Bed', planMinutes: 35, difficulty: 1.05),
    PerformanceJobType(id: 'watering', name: 'Watering', planMinutes: 25, difficulty: 0.95),
    PerformanceJobType(id: 'filling', name: 'Filling', planMinutes: 60, difficulty: 1.20),
    PerformanceJobType(id: 'airing', name: 'Airing', planMinutes: 20, difficulty: 0.90),
    PerformanceJobType(id: 'floor_wet', name: 'Floor Wet', planMinutes: 25, difficulty: 1.00),
    PerformanceJobType(id: 'prochloraz', name: 'Prochloraz', planMinutes: 30, difficulty: 1.00),
    PerformanceJobType(id: 'packup_tree', name: 'Pack Up Tree', planMinutes: 50, difficulty: 1.08),
    PerformanceJobType(id: 'special_solo', name: 'Special Solo', planMinutes: 40, difficulty: 1.00),
    PerformanceJobType(id: 'alone_worker', name: 'Alone Worker', planMinutes: 40, difficulty: 1.00),
  ];

  /// Fallback standard time (minutes) for a job_type that has no entry above.
  static const double fallbackPlanMinutes = 30;

  static PerformanceJobType jobTypeFor(String jobTypeId) {
    return defaultJobTypes.firstWhere(
      (j) => j.id == jobTypeId,
      orElse: () => PerformanceJobType(
        id: jobTypeId,
        name: jobTypeId,
        planMinutes: fallbackPlanMinutes,
      ),
    );
  }
}
