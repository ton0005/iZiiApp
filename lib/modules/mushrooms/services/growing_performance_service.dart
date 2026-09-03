// lib/modules/mushrooms/services/growing_performance_service.dart
//
// Loads the Growing Performance Board directly from the local iZiiApp
// SQLite database (Drift) — no mock/simulated data.
//
// Source tables:
// • mushroom_jobs               -> job count, actual duration, on-time rate,
//                                   room, Alone Worker gas levels & check-out.
// • mushroom_daily_timesheets   -> shift check-in/out, break time taken,
//                                   extra break, overtime hours.
// • mushroom_employees /
//   mushroom_departments        -> employee & department filters and the
//                                   per-employee breakdown table.
//
// Note: mushroom_jobs.assignee stores the worker's display name (not an
// employee_id FK), so matching a job back to an employee/department is done
// by case-insensitive name lookup. A job whose assignee doesn't match any
// known employee still counts toward the overall KPIs but won't appear
// under a specific employee/department filter.

import 'package:izii_app/core/database/app_database.dart';
import '../models/growing_performance_models.dart';
import '../repository.dart';

class GrowingPerformanceDataset {
  final List<PerformanceDept> departments;
  final List<PerformanceEmployee> employees;
  final List<PerformanceTaskRecord> tasks;
  final List<PerformanceShiftRecord> shifts;

  const GrowingPerformanceDataset({
    required this.departments,
    required this.employees,
    required this.tasks,
    required this.shifts,
  });
}

class GrowingPerformanceService {
  final AppDatabase _db;
  late final MushroomsRepository _repo;

  GrowingPerformanceService([AppDatabase? db]) : _db = db ?? AppDatabase() {
    _repo = MushroomsRepository(_db);
  }

  static const List<int> _palette = [
    0xFF9B59B6, 0xFFF0A93E, 0xFF4AA3DF, 0xFFD0455B, 0xFF6E7B8B,
  ];

  int _colorForDept(String name, int fallbackIndex) {
    final n = name.toLowerCase();
    if (n.contains('grow')) return 0xFF2A78D6;
    if (n.contains('harvest')) return 0xFFEB6834;
    if (n.contains('maint')) return 0xFF1BAF7A;
    return _palette[fallbackIndex % _palette.length];
  }

  int? _roomNumberFromName(String? name) {
    if (name == null) return null;
    final match = RegExp(r'\d+').firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  int _minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute;

  int _dayOffset(DateTime date, DateTime today) {
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    return t.difference(d).inDays;
  }

  Future<List<PerformanceDept>> loadDepartments() async {
    final raw = await _repo.getDepartments();
    final depts = <PerformanceDept>[];
    for (var i = 0; i < raw.length; i++) {
      final d = raw[i];
      final name = (d['name'] as String?) ?? 'Unknown';
      depts.add(PerformanceDept(
        id: (d['id'] as String?) ?? 'DEP_$i',
        name: name,
        colorValue: _colorForDept(name, i),
      ));
    }
    if (depts.isEmpty) {
      depts.add(const PerformanceDept(
          id: 'unassigned', name: 'Unassigned', colorValue: 0xFF898781));
    }
    return depts;
  }

  Future<List<PerformanceEmployee>> loadEmployees(
      List<PerformanceDept> depts) async {
    final raw = await _repo.getEmployees();
    final nameToDeptId = {
      for (final d in depts) d.name.trim().toLowerCase(): d.id,
    };
    return raw.map((e) {
      final deptName = (e['department'] as String?)?.trim();
      final deptId = (deptName != null && deptName.isNotEmpty)
          ? (nameToDeptId[deptName.toLowerCase()] ?? 'unassigned')
          : 'unassigned';
      return PerformanceEmployee(
        id: e['id'] as String,
        name: (e['name'] as String?) ?? e['id'] as String,
        role: (e['role'] as String?) ?? '',
        deptId: deptId,
      );
    }).toList();
  }

  /// Loads up to [rangeDays] days of task/shift history. The screen keeps
  /// this full window in memory and re-filters client-side when the user
  /// switches between Today/7 Days/30 Days so the toggle stays instant.
  Future<GrowingPerformanceDataset> loadDataset({int rangeDays = 30}) async {
    final today = DateTime.now();

    final departments = await loadDepartments();
    final employees = await loadEmployees(departments);
    final nameToEmployee = {
      for (final e in employees) e.name.trim().toLowerCase(): e,
    };

    // Resolve mushroom_jobs.room_id -> a human room number for display.
    final rooms = await _db.select(_db.growRooms).get();
    final roomNameById = {for (final r in rooms) r.id: r.name};

    // --- Tasks (mushroom_jobs) ---
    final jobs = await _db.select(_db.mushroomJobs).get();
    final tasks = <PerformanceTaskRecord>[];
    for (final j in jobs) {
      final isSolo = j.isSoloJob || j.jobType == 'alone_worker';

      final DateTime start =
          (isSolo ? (j.checkInTime ?? j.startedAt) : j.startedAt) ??
              j.createdAt;
      final end = isSolo ? (j.checkOutTime ?? j.completedAt) : j.completedAt;
      if (end == null) continue; // only completed work counts as a "done" job

      final actualMinutes = end.difference(start).inMinutes.toDouble();
      if (actualMinutes < 0) continue;

      final dayOffset = _dayOffset(end, today);
      if (dayOffset < 0 || dayOffset >= rangeDays) continue;

      final matchedEmployee =
          (j.assignee != null && j.assignee!.trim().isNotEmpty)
              ? nameToEmployee[j.assignee!.trim().toLowerCase()]
              : null;
      final employeeId = matchedEmployee?.id ?? j.assignee ?? 'unknown';
      final deptId = matchedEmployee?.deptId ?? 'unassigned';

      final jobType = GrowingPerformanceConstants.jobTypeFor(j.jobType);
      final planMinutes = isSolo
          ? (j.timeLimitMinutes?.toDouble() ?? jobType.planMinutes)
          : jobType.planMinutes;
      final grace = planMinutes * 0.10;
      final onTime = actualMinutes <= planMinutes + grace;

      SoloSafetyInfo? solo;
      if (isSolo) {
        final co = j.coLevel ?? 0.0;
        final co2 = j.co2Level ?? 0.0;
        final isAlarm = j.alarmTriggered ||
            actualMinutes > planMinutes ||
            co > 85.0 ||
            co2 > 4500.0;
        solo = SoloSafetyInfo(
          limitMinutes: planMinutes,
          insideMinutes: actualMinutes,
          coPpm: co,
          co2Ppm: co2,
          isAlarm: isAlarm,
          isCheckedOut: j.checkOutTime != null,
        );
      }

      tasks.add(PerformanceTaskRecord(
        date: end,
        dayOffset: dayOffset,
        employeeId: employeeId,
        deptId: deptId,
        jobId: j.jobType,
        planMinutes: planMinutes,
        actualMinutes: actualMinutes,
        startMinutesOfDay: _minutesOfDay(start),
        roomNumber: _roomNumberFromName(roomNameById[j.roomId]) ?? 0,
        onTime: onTime,
        soloInfo: solo,
      ));
    }

    // --- Shifts (mushroom_daily_timesheets) ---
    final timesheets = await _db.select(_db.mushroomDailyTimesheets).get();
    final shifts = <PerformanceShiftRecord>[];
    for (final ts in timesheets) {
      final dayOffset = _dayOffset(ts.planDate, today);
      if (dayOffset < 0 || dayOffset >= rangeDays) continue;

      PerformanceEmployee? employee;
      for (final e in employees) {
        if (e.id == ts.employeeId) {
          employee = e;
          break;
        }
      }

      shifts.add(PerformanceShiftRecord(
        date: ts.planDate,
        dayOffset: dayOffset,
        employeeId: ts.employeeId,
        deptId: employee?.deptId ?? 'unassigned',
        checkInMinutes:
            ts.checkInTime != null ? _minutesOfDay(ts.checkInTime!) : 0,
        checkOutMinutes:
            ts.checkOutTime != null ? _minutesOfDay(ts.checkOutTime!) : 0,
        allowedBreakMinutes: ts.standardBreakAllowedMinutes.toDouble(),
        takenBreakMinutes: ts.totalBreakTakenMinutes.toDouble(),
        extraBreakMinutes: ts.extraBreakMinutes.toDouble(),
        grossMinutes: ts.grossWorkedMinutes.toDouble(),
        paidMinutes: ts.paidMinutes.toDouble(),
        overtimeHours: ts.overtimeMinutes / 60.0,
      ));
    }

    return GrowingPerformanceDataset(
      departments: departments,
      employees: employees,
      tasks: tasks,
      shifts: shifts,
    );
  }
}
