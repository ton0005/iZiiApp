import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../repository.dart';

enum AttendanceWorkState {
  notCheckedIn, // Chưa điểm danh vào ca
  working,      // Đang làm việc trong ca
  onBreak,      // Đang nghỉ giải lao
  checkedOut,   // Đã điểm danh ra về (hoàn thành ca)
}

class EmployeeAttendanceRecord {
  final String id;
  final String name;
  final String role;
  final String department;
  final String teamColor;
  final AttendanceWorkState state;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? breakStartTime;
  final int totalBreakMinutes;
  final int paidMinutes;
  final String? timesheetId;

  const EmployeeAttendanceRecord({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.teamColor,
    required this.state,
    this.checkInTime,
    this.checkOutTime,
    this.breakStartTime,
    this.totalBreakMinutes = 0,
    this.paidMinutes = 0,
    this.timesheetId,
  });

  EmployeeAttendanceRecord copyWith({
    String? id,
    String? name,
    String? role,
    String? department,
    String? teamColor,
    AttendanceWorkState? state,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    DateTime? breakStartTime,
    int? totalBreakMinutes,
    int? paidMinutes,
    String? timesheetId,
  }) {
    return EmployeeAttendanceRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      department: department ?? this.department,
      teamColor: teamColor ?? this.teamColor,
      state: state ?? this.state,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      breakStartTime: breakStartTime ?? this.breakStartTime,
      totalBreakMinutes: totalBreakMinutes ?? this.totalBreakMinutes,
      paidMinutes: paidMinutes ?? this.paidMinutes,
      timesheetId: timesheetId ?? this.timesheetId,
    );
  }
}

class BatchActionResult {
  final int totalRequested;
  final int successCount;
  final String actionName;
  final DateTime timestamp;
  final String summary;

  const BatchActionResult({
    required this.totalRequested,
    required this.successCount,
    required this.actionName,
    required this.timestamp,
    required this.summary,
  });
}

class ManagerAttendanceService {
  final AppDatabase _db;
  final MushroomsRepository _repo;
  static final List<BatchActionResult> _history = [];

  ManagerAttendanceService({AppDatabase? db, MushroomsRepository? repo})
      : _db = db ?? AppDatabase(),
        _repo = repo ?? MushroomsRepository();

  List<BatchActionResult> get recentHistory => List.unmodifiable(_history);

  /// Lấy danh sách toàn bộ nhân sự kèm trạng thái làm việc trong ngày được chỉ định
  Future<List<EmployeeAttendanceRecord>> getDailyAttendanceList({
    DateTime? targetDate,
  }) async {
    final date = targetDate ?? DateTime.now();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // 1. Đảm bảo dữ liệu nhân sự đã sẵn sàng
    await _repo.seedEmployeesIfEmpty();
    final employees = await _db.select(_db.mushroomEmployees).get();

    // 2. Lấy toàn bộ Timesheets của ngày
    final timesheets = await (_db.select(_db.mushroomDailyTimesheets)
          ..where((t) =>
              t.planDate.isBiggerOrEqualValue(startOfDay) &
              t.planDate.isSmallerOrEqualValue(endOfDay)))
        .get();

    final timesheetMap = {for (var ts in timesheets) ts.employeeId: ts};

    // 3. Lấy toàn bộ AttendanceEvents của ngày để xác định trạng thái OnBreak chính xác
    final events = await (_db.select(_db.mushroomAttendanceEvents)
          ..where((e) =>
              e.timestamp.isBiggerOrEqualValue(startOfDay) &
              e.timestamp.isSmallerOrEqualValue(endOfDay))
          ..orderBy([(e) => d.OrderingTerm.asc(e.timestamp)]))
        .get();

    // Nhóm events theo employeeId
    final eventsByEmp = <String, List<MushroomAttendanceEvent>>{};
    for (var ev in events) {
      eventsByEmp.putIfAbsent(ev.employeeId, () => []).add(ev);
    }

    final List<EmployeeAttendanceRecord> records = [];

    for (var emp in employees) {
      final ts = timesheetMap[emp.id];
      final empEvents = eventsByEmp[emp.id] ?? [];

      AttendanceWorkState state = AttendanceWorkState.notCheckedIn;
      DateTime? checkIn = ts?.checkInTime;
      DateTime? checkOut = ts?.checkOutTime;
      DateTime? breakStart;
      final int breakMinutes = ts?.totalBreakTakenMinutes ?? 0;
      final int paidMin = ts?.paidMinutes ?? 0;

      // Tìm sự kiện gần nhất
      if (empEvents.isNotEmpty) {
        final lastEv = empEvents.last;
        if (lastEv.eventType == 'CHECK_IN') {
          state = AttendanceWorkState.working;
          checkIn ??= lastEv.timestamp;
        } else if (lastEv.eventType == 'BREAK_START') {
          state = AttendanceWorkState.onBreak;
          breakStart = lastEv.timestamp;
        } else if (lastEv.eventType == 'BREAK_END') {
          state = AttendanceWorkState.working;
        } else if (lastEv.eventType == 'CHECK_OUT') {
          state = AttendanceWorkState.checkedOut;
          checkOut ??= lastEv.timestamp;
        }
      }

      // Đối soát thêm với timesheet nếu events bị thiếu
      if (checkOut != null) {
        state = AttendanceWorkState.checkedOut;
      } else if (checkIn != null && state == AttendanceWorkState.notCheckedIn) {
        state = AttendanceWorkState.working;
      }

      final teamColor = emp.pickerTeamColor?.trim().isNotEmpty == true
          ? emp.pickerTeamColor!.trim().toUpperCase()
          : 'PURPLE';

      records.add(EmployeeAttendanceRecord(
        id: emp.id,
        name: emp.name,
        role: emp.role,
        department: emp.department ?? 'Harvest',
        teamColor: teamColor,
        state: state,
        checkInTime: checkIn,
        checkOutTime: checkOut,
        breakStartTime: breakStart,
        totalBreakMinutes: breakMinutes,
        paidMinutes: paidMin,
        timesheetId: ts?.id,
      ));
    }

    // Sắp xếp: Ưu tiên theo Team, sau đó theo Tên
    records.sort((a, b) {
      final teamComp = a.teamColor.compareTo(b.teamColor);
      if (teamComp != 0) return teamComp;
      return a.name.compareTo(b.name);
    });

    return records;
  }

  /// 🟢 1. BATCH CHECK IN: Điểm danh vào ca cho danh sách nhân viên
  Future<BatchActionResult> batchCheckIn({
    required List<String> employeeIds,
    DateTime? effectiveTime,
    String? note,
  }) async {
    final now = effectiveTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var count = 0;

    for (var empId in employeeIds) {
      try {
        final emp = await (_db.select(_db.mushroomEmployees)
              ..where((e) => e.id.equals(empId)))
            .getSingleOrNull();
        final empName = emp?.name ?? empId;

        final evId = 'EV_IN_${empId}_${now.millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 5)}';

        // 1. Ghi nhận sự kiện CHECK_IN cục bộ
        await _db.into(_db.mushroomAttendanceEvents).insert(
              MushroomAttendanceEventsCompanion.insert(
                id: evId,
                employeeId: empId,
                eventType: 'CHECK_IN',
                timestamp: d.Value(now),
                source: 'MANAGER_BATCH',
                location: d.Value(note ?? 'Batch Check-in by Manager'),
              ),
            );

        // Queue mutation cho attendance event
        await SyncService().queueMutation('mushroom_attendance_events', 'insert', {
          'id': evId,
          'employee_id': empId,
          'employee_name': empName,
          'event_type': 'CHECK_IN',
          'timestamp': now.toIso8601String(),
          'source': 'MANAGER_BATCH',
          'location': note ?? 'Batch Check-in by Manager',
          'created_at': now.toIso8601String(),
        });

        // 2. Kiểm tra/Tạo Timesheet tương ứng
        final existingTs = await (_db.select(_db.mushroomDailyTimesheets)
              ..where((t) =>
                  t.employeeId.equals(empId) &
                  t.planDate.isBiggerOrEqualValue(today) &
                  t.planDate.isSmallerThanValue(today.add(const Duration(days: 1)))))
            .getSingleOrNull();

        if (existingTs == null) {
          final tsId = 'TS_${empId}_${now.millisecondsSinceEpoch}';
          await _db.into(_db.mushroomDailyTimesheets).insert(
                MushroomDailyTimesheetsCompanion.insert(
                  id: tsId,
                  employeeId: empId,
                  planDate: today,
                  checkInTime: d.Value(now),
                  assignedTeamColor: d.Value(emp?.pickerTeamColor ?? 'PURPLE'),
                  status: const d.Value('normal'),
                ),
              );

          await SyncService().queueMutation('mushroom_daily_timesheets', 'insert', {
            'id': tsId,
            'employee_id': empId,
            'employee_name': empName,
            'plan_date': DateFormat('yyyy-MM-dd').format(today),
            'check_in_time': now.toIso8601String(),
            'assigned_team_color': emp?.pickerTeamColor ?? 'PURPLE',
            'status': 'normal',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
        } else if (existingTs.checkInTime == null) {
          await (_db.update(_db.mushroomDailyTimesheets)
                ..where((t) => t.id.equals(existingTs.id)))
              .write(MushroomDailyTimesheetsCompanion(
                checkInTime: d.Value(now),
              ));

          await SyncService().queueMutation('mushroom_daily_timesheets', 'update', {
            'id': existingTs.id,
            'employee_id': empId,
            'employee_name': empName,
            'check_in_time': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
        }

        count++;
      } catch (e) {
        print('Error batch check-in for $empId: $e');
      }
    }

    try {
      unawaited(SyncService().flushOutbox());
    } catch (_) {}

    final result = BatchActionResult(
      totalRequested: employeeIds.length,
      successCount: count,
      actionName: 'Check In',
      timestamp: now,
      summary: 'Successfully checked in $count/${employeeIds.length} employees.',
    );
    _history.insert(0, result);
    return result;
  }

  /// ☕ 2. BATCH START BREAK: Bắt đầu giờ giải lao cho nhóm nhân viên
  Future<BatchActionResult> batchStartBreak({
    required List<String> employeeIds,
    DateTime? effectiveTime,
    String? note,
  }) async {
    final now = effectiveTime ?? DateTime.now();
    var count = 0;

    for (var empId in employeeIds) {
      try {
        final emp = await (_db.select(_db.mushroomEmployees)
              ..where((e) => e.id.equals(empId)))
            .getSingleOrNull();
        final empName = emp?.name ?? empId;

        final evId = 'EV_BST_${empId}_${now.millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 5)}';

        await _db.into(_db.mushroomAttendanceEvents).insert(
              MushroomAttendanceEventsCompanion.insert(
                id: evId,
                employeeId: empId,
                eventType: 'BREAK_START',
                timestamp: d.Value(now),
                source: 'MANAGER_BATCH',
                location: d.Value(note ?? 'Batch Break Start by Manager'),
              ),
            );

        await SyncService().queueMutation('mushroom_attendance_events', 'insert', {
          'id': evId,
          'employee_id': empId,
          'employee_name': empName,
          'event_type': 'BREAK_START',
          'timestamp': now.toIso8601String(),
          'source': 'MANAGER_BATCH',
          'location': note ?? 'Batch Break Start by Manager',
          'created_at': now.toIso8601String(),
        });

        count++;
      } catch (e) {
        print('Error batch start break for $empId: $e');
      }
    }

    try {
      unawaited(SyncService().flushOutbox());
    } catch (_) {}

    final result = BatchActionResult(
      totalRequested: employeeIds.length,
      successCount: count,
      actionName: 'Start Break',
      timestamp: now,
      summary: 'Started break for $count/${employeeIds.length} employees.',
    );
    _history.insert(0, result);
    return result;
  }

  /// ⏱️ 3. BATCH END BREAK: Kết thúc giờ giải lao & cộng dồn thời gian nghỉ
  Future<BatchActionResult> batchEndBreak({
    required List<String> employeeIds,
    DateTime? effectiveTime,
    String? note,
  }) async {
    final now = effectiveTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var count = 0;

    for (var empId in employeeIds) {
      try {
        final emp = await (_db.select(_db.mushroomEmployees)
              ..where((e) => e.id.equals(empId)))
            .getSingleOrNull();
        final empName = emp?.name ?? empId;

        // Tìm sự kiện BREAK_START gần nhất hôm nay
        final lastBreakStart = await (_db.select(_db.mushroomAttendanceEvents)
              ..where((e) =>
                  e.employeeId.equals(empId) &
                  e.eventType.equals('BREAK_START') &
                  e.timestamp.isBiggerOrEqualValue(today))
              ..orderBy([(e) => d.OrderingTerm.desc(e.timestamp)])
              ..limit(1))
            .getSingleOrNull();

        int breakSpan = 0;
        if (lastBreakStart != null) {
          breakSpan = now.difference(lastBreakStart.timestamp).inMinutes;
          if (breakSpan < 1) breakSpan = 1;
        } else {
          breakSpan = 25; // Standard break fallback nếu không có start
        }

        // Ghi nhận sự kiện BREAK_END
        final evId = 'EV_BEN_${empId}_${now.millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 5)}';
        await _db.into(_db.mushroomAttendanceEvents).insert(
              MushroomAttendanceEventsCompanion.insert(
                id: evId,
                employeeId: empId,
                eventType: 'BREAK_END',
                timestamp: d.Value(now),
                source: 'MANAGER_BATCH',
                location: d.Value(note ?? 'Batch Break End by Manager'),
              ),
            );

        await SyncService().queueMutation('mushroom_attendance_events', 'insert', {
          'id': evId,
          'employee_id': empId,
          'employee_name': empName,
          'event_type': 'BREAK_END',
          'timestamp': now.toIso8601String(),
          'source': 'MANAGER_BATCH',
          'location': note ?? 'Batch Break End by Manager',
          'created_at': now.toIso8601String(),
        });

        // Cộng dồn vào Timesheet
        final existingTs = await (_db.select(_db.mushroomDailyTimesheets)
              ..where((t) =>
                  t.employeeId.equals(empId) &
                  t.planDate.isBiggerOrEqualValue(today) &
                  t.planDate.isSmallerThanValue(today.add(const Duration(days: 1)))))
            .getSingleOrNull();

        if (existingTs != null) {
          final newBreakTotal = existingTs.totalBreakTakenMinutes + breakSpan;
          await (_db.update(_db.mushroomDailyTimesheets)
                ..where((t) => t.id.equals(existingTs.id)))
              .write(MushroomDailyTimesheetsCompanion(
                totalBreakTakenMinutes: d.Value(newBreakTotal),
              ));

          await SyncService().queueMutation('mushroom_daily_timesheets', 'update', {
            'id': existingTs.id,
            'employee_id': empId,
            'employee_name': empName,
            'total_break_taken_minutes': newBreakTotal,
            'updated_at': now.toIso8601String(),
          });
        }

        count++;
      } catch (e) {
        print('Error batch end break for $empId: $e');
      }
    }

    try {
      unawaited(SyncService().flushOutbox());
    } catch (_) {}

    final result = BatchActionResult(
      totalRequested: employeeIds.length,
      successCount: count,
      actionName: 'End Break',
      timestamp: now,
      summary: 'Ended break for $count/${employeeIds.length} employees.',
    );
    _history.insert(0, result);
    return result;
  }

  /// 🔴 4. BATCH CHECK OUT: Điểm danh ra về & chốt giờ làm cho danh sách nhân viên
  Future<BatchActionResult> batchCheckOut({
    required List<String> employeeIds,
    DateTime? effectiveTime,
    String? note,
  }) async {
    final now = effectiveTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var count = 0;

    for (var empId in employeeIds) {
      try {
        final emp = await (_db.select(_db.mushroomEmployees)
              ..where((e) => e.id.equals(empId)))
            .getSingleOrNull();
        final empName = emp?.name ?? empId;

        final evId = 'EV_OUT_${empId}_${now.millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 5)}';

        // 1. Ghi nhận sự kiện CHECK_OUT
        await _db.into(_db.mushroomAttendanceEvents).insert(
              MushroomAttendanceEventsCompanion.insert(
                id: evId,
                employeeId: empId,
                eventType: 'CHECK_OUT',
                timestamp: d.Value(now),
                source: 'MANAGER_BATCH',
                location: d.Value(note ?? 'Batch Check-out by Manager'),
              ),
            );

        await SyncService().queueMutation('mushroom_attendance_events', 'insert', {
          'id': evId,
          'employee_id': empId,
          'employee_name': empName,
          'event_type': 'CHECK_OUT',
          'timestamp': now.toIso8601String(),
          'source': 'MANAGER_BATCH',
          'location': note ?? 'Batch Check-out by Manager',
          'created_at': now.toIso8601String(),
        });

        // 2. Chốt Timesheet
        final existingTs = await (_db.select(_db.mushroomDailyTimesheets)
              ..where((t) =>
                  t.employeeId.equals(empId) &
                  t.planDate.isBiggerOrEqualValue(today) &
                  t.planDate.isSmallerThanValue(today.add(const Duration(days: 1)))))
            .getSingleOrNull();

        final checkIn = existingTs?.checkInTime ?? now.subtract(const Duration(hours: 8));
        final gross = now.difference(checkIn).inMinutes;
        const stdAllowed = 25; // 25 phút tiêu chuẩn
        final totalBreak = existingTs?.totalBreakTakenMinutes ?? stdAllowed;
        final extraBreak = totalBreak > stdAllowed ? (totalBreak - stdAllowed) : 0;
        final paidMinutes = (gross - stdAllowed - extraBreak).clamp(0, gross);

        if (existingTs != null) {
          await (_db.update(_db.mushroomDailyTimesheets)
                ..where((t) => t.id.equals(existingTs.id)))
              .write(MushroomDailyTimesheetsCompanion(
                checkOutTime: d.Value(now),
                grossWorkedMinutes: d.Value(gross),
                standardBreakAllowedMinutes: const d.Value(stdAllowed),
                extraBreakMinutes: d.Value(extraBreak),
                paidMinutes: d.Value(paidMinutes),
                status: d.Value(extraBreak > 0 ? 'needs_review' : 'normal'),
              ));

          await SyncService().queueMutation('mushroom_daily_timesheets', 'update', {
            'id': existingTs.id,
            'employee_id': empId,
            'employee_name': empName,
            'check_out_time': now.toIso8601String(),
            'gross_worked_minutes': gross,
            'standard_break_allowed_minutes': stdAllowed,
            'extra_break_minutes': extraBreak,
            'paid_minutes': paidMinutes,
            'status': extraBreak > 0 ? 'needs_review' : 'normal',
            'updated_at': now.toIso8601String(),
          });
        } else {
          final tsId = 'TS_${empId}_${now.millisecondsSinceEpoch}';
          await _db.into(_db.mushroomDailyTimesheets).insert(
                MushroomDailyTimesheetsCompanion.insert(
                  id: tsId,
                  employeeId: empId,
                  planDate: today,
                  checkInTime: d.Value(checkIn),
                  checkOutTime: d.Value(now),
                  grossWorkedMinutes: d.Value(gross),
                  standardBreakAllowedMinutes: const d.Value(stdAllowed),
                  extraBreakMinutes: d.Value(extraBreak),
                  paidMinutes: d.Value(paidMinutes),
                  status: d.Value(extraBreak > 0 ? 'needs_review' : 'normal'),
                ),
              );

          await SyncService().queueMutation('mushroom_daily_timesheets', 'insert', {
            'id': tsId,
            'employee_id': empId,
            'employee_name': empName,
            'plan_date': DateFormat('yyyy-MM-dd').format(today),
            'check_in_time': checkIn.toIso8601String(),
            'check_out_time': now.toIso8601String(),
            'gross_worked_minutes': gross,
            'standard_break_allowed_minutes': stdAllowed,
            'extra_break_minutes': extraBreak,
            'paid_minutes': paidMinutes,
            'status': extraBreak > 0 ? 'needs_review' : 'normal',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
        }

        count++;
      } catch (e) {
        print('Error batch check-out for $empId: $e');
      }
    }

    try {
      unawaited(SyncService().flushOutbox());
    } catch (_) {}

    final result = BatchActionResult(
      totalRequested: employeeIds.length,
      successCount: count,
      actionName: 'Check Out',
      timestamp: now,
      summary: 'Successfully checked out $count/${employeeIds.length} employees.',
    );
    _history.insert(0, result);
    return result;
  }

  /// Tiện ích sinh dữ liệu mẫu đội ngũ Harvest đông đảo (120 - 160 nhân sự) để test tức thì
  Future<int> generateLargeHarvestCrewIfFew() async {
    final existingCount = (await _db.select(_db.mushroomEmployees).get()).length;
    if (existingCount >= 80) {
      return existingCount;
    }

    final teams = [
      {'color': 'PURPLE', 'count': 18, 'prefix': 'PUR'},
      {'color': 'PEARL', 'count': 16, 'prefix': 'PRL'},
      {'color': 'IVORY', 'count': 18, 'prefix': 'IVO'},
      {'color': 'JADE', 'count': 16, 'prefix': 'JAD'},
      {'color': 'SAPPHIRE', 'count': 16, 'prefix': 'SAP'},
      {'color': 'AMBER', 'count': 14, 'prefix': 'AMB'},
      {'color': 'PEACH', 'count': 14, 'prefix': 'PCH'},
      {'color': 'RUBY', 'count': 14, 'prefix': 'RBY'},
      {'color': 'VENUS', 'count': 12, 'prefix': 'VEN'},
      {'color': 'LIME', 'count': 12, 'prefix': 'LIM'},
    ];

    final sampleFirstNames = ['Hùng', 'Minh', 'Thảo', 'Trang', 'Hải', 'Tuấn', 'Linh', 'Dương', 'Bình', 'Hương', 'Đức', 'Phương', 'Mai', 'An', 'Tâm', 'Khoa', 'Vinh', 'Cường', 'Quỳnh', 'Nam', 'Trúc', 'Khanh', 'Phúc', 'Nga'];
    final sampleLastNames = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Vũ', 'Phan', 'Đỗ', 'Bùi', 'Đặng', 'Hồ', 'Ngô', 'Dương'];

    var added = 0;
    var empIndex = existingCount + 1;

    for (var t in teams) {
      final teamColor = t['color'] as String;
      final count = t['count'] as int;
      final prefix = t['prefix'] as String;

      for (var i = 1; i <= count; i++) {
        final empId = 'EMP_$prefix${i.toString().padLeft(3, '0')}';
        final firstName = sampleFirstNames[(empIndex * 7 + i) % sampleFirstNames.length];
        final lastName = sampleLastNames[(empIndex * 11 + i) % sampleLastNames.length];
        final fullName = '$lastName $firstName ($teamColor-$i)';

        try {
          await _db.into(_db.mushroomEmployees).insertOnConflictUpdate(
                MushroomEmployee(
                  id: empId,
                  name: fullName,
                  role: i == 1 ? 'Team Leader' : 'Picker',
                  department: 'Harvest',
                  pickerTeamColor: teamColor,
                  status: 'active',
                  baseRate: i == 1 ? 32.5 : 29.8,
                  createdAt: DateTime.now(),
                  passwordHash: '',
                ),
              );
          added++;
          empIndex++;
        } catch (_) {}
      }
    }

    return existingCount + added;
  }
}
