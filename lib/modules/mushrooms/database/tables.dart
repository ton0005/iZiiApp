import 'package:drift/drift.dart';

class GrowRooms extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()(); // e.g. "Room 33", "Grow Room 52A"
  TextColumn get status => text().withDefault(const Constant('idle'))(); // active, idle
  TextColumn get currentStage => text().withDefault(const Constant('idle'))(); // idle, filling, airing, floor_wet, clean_room, watering, clean_bed, prochloraz, packup_tree
  IntColumn get dayInCycle => integer().withDefault(const Constant(1))();
  RealColumn get targetYield => real().withDefault(const Constant(0.0))();
  RealColumn get pickedYield => real().withDefault(const Constant(0.0))();
  TextColumn get pickingPlanJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catalog of Job Types available when creating a Growing job — CRUD-managed
/// from the "Job Types" screen (Level 2+ only). Seeded with the built-in
/// pipeline steps (filling, watering, prochloraz, ...); anything beyond that
/// is a custom type added by a manager.
class MushroomJobTypes extends Table {
  TextColumn get id => text()(); // slug, e.g. 'filling' or 'custom_deep_clean'
  TextColumn get name => text()(); // Display name
  IntColumn get planMinutes => integer().withDefault(const Constant(30))(); // standard/target duration
  BoolColumn get isSoloJob => boolean().withDefault(const Constant(false))(); // requires Alone Worker safety flow
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))(); // false for the seeded built-ins
  BoolColumn get isActive => boolean().withDefault(const Constant(true))(); // inactive = hidden from new-job dropdown
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomJobs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get roomId => text()();
  TextColumn get jobType => text()(); // filling, airing, floor_wet, clean_room, watering, clean_bed, prochloraz, packup_tree, special_solo, alone_worker
  TextColumn get name => text()(); // Display name
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, completed
  TextColumn get assignee => text().nullable()(); // Staff name
  TextColumn get planDetails => text().nullable()(); // e.g. "2 Side 2L/m2"
  TextColumn get prochlorazRate => text().nullable()(); // e.g. "1.3g/m2"
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get linkedTaskId => text().nullable()(); // Project & Task integration ID

  // --- Solo Safety System Fields ---
  BoolColumn get isSoloJob => boolean().withDefault(const Constant(false))();
  IntColumn get timeLimitMinutes => integer().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  BoolColumn get alarmTriggered => boolean().withDefault(const Constant(false))();

  // --- Scheduling and Prioritization Fields ---
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  TextColumn get priority => text().nullable().withDefault(const Constant('normal'))(); // low, normal, high, urgent
  IntColumn get sequence => integer().nullable()();

  // --- Gas Levels and Timestamps ---
  RealColumn get coLevel => real().nullable()();
  RealColumn get co2Level => real().nullable()();
  DateTimeColumn get checkInTime => dateTime().nullable()();
  DateTimeColumn get checkOutTime => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomJobSafetyConfigs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get jobId => text()(); // References MushroomJobs.id
  IntColumn get checkInIntervalMinutes => integer().withDefault(const Constant(30))();
  IntColumn get gracePeriodMinutes => integer().withDefault(const Constant(5))();
  TextColumn get escalationTarget => text().withDefault(const Constant('supervisor'))();
  BoolColumn get autoStartOnJobBegin => boolean().withDefault(const Constant(true))();
  TextColumn get alarmType => text().withDefault(const Constant('push_inapp'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomSafetyCheckinLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get jobId => text()();
  TextColumn get workerId => text()();
  TextColumn get eventType => text()(); // safe, snooze, sos, missed, complete
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  RealColumn get gpsLatitude => real().nullable()();
  RealColumn get gpsLongitude => real().nullable()();
  IntColumn get responseTimeSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomMaintenanceTickets extends Table {
  TextColumn get id => text()(); // MNT-xxx
  TextColumn get title => text()();
  TextColumn get plant => text()();
  TextColumn get room => text()();
  TextColumn get assignee => text()();
  TextColumn get priority => text()(); // low, normal, high
  TextColumn get status => text().withDefault(const Constant('todo'))(); // todo, inprog, done
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sender => text()();
  TextColumn get contact => text()(); // Growing Crew, Sarah, Mike
  TextColumn get textContent => text()();
  TextColumn get timeString => text()();
  TextColumn get role => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomRoomCrews extends Table {
  TextColumn get id => text()();
  TextColumn get roomName => text()();
  TextColumn get empName => text()();
  TextColumn get empId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomEmployees extends Table {
  TextColumn get id => text()(); // UUID or Employee ID (e.g. EMP001)
  TextColumn get name => text()();
  TextColumn get role => text()(); // Picker, Box Mover, Growing Specialist, etc.
  TextColumn get department => text().nullable()(); // Department name
  TextColumn get passwordHash => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, inactive, on_leave
  TextColumn get linkedUserId => text().nullable()();
  TextColumn get employmentType => text().nullable()(); // Senior, Trainee
  RealColumn get baseRate => real().nullable()(); // Hourly salary rate
  TextColumn get defaultShed => text().nullable()(); // default zone/plant
  TextColumn get pickerTeamColor => text().nullable()(); // ivory, pearl, purple, sapphire, etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomDepartments extends Table {
  TextColumn get id => text()(); // e.g. DEP001, DEP002
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomEmployeeDepartmentRoles extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get employeeId => text()();
  TextColumn get departmentId => text()();
  TextColumn get roleKey => text()(); // manager, supervisor, specialist, picker
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomPermissionOverrides extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get employeeId => text()();
  TextColumn get permissionKey => text()(); // e.g. addRoom, createJob...
  TextColumn get type => text()(); // 'allow' or 'deny'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomYieldSurveys extends Table {
  TextColumn get id => text()();
  TextColumn get roomName => text()();
  TextColumn get strain => text()(); // Button, Cup, Flat
  IntColumn get cycle => integer()();
  RealColumn get expectedYield => real()();
  DateTimeColumn get surveyedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomHarvestPlans extends Table {
  TextColumn get id => text()(); // UUID
  DateTimeColumn get planDate => dateTime()();
  TextColumn get zoneId => text().nullable()(); // M1, M2
  TextColumn get createdBy => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft, published, in_progress, closed
  IntColumn get totalTargetBoxes => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomShifts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get planId => text()(); // FK -> MushroomHarvestPlans
  TextColumn get role => text()(); // SUPERVISOR, TEAM_LEADER, BOX_MOVER_DAY, BOX_MOVER_DS, BOX_MOVER_AN
  TextColumn get employeeId => text()(); // FK -> MushroomEmployees
  DateTimeColumn get startTime => dateTime().nullable()();
  TextColumn get shedRoomListJson => text().nullable()(); // JSON list of rooms

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomPickerTeams extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get planId => text()(); // FK -> MushroomHarvestPlans
  TextColumn get colorCode => text()(); // e.g. Ivory, Pearl, Purple, Sapphire
  TextColumn get teamLeaderId => text().nullable()(); // FK -> MushroomEmployees
  IntColumn get headcount => integer().withDefault(const Constant(0))();
  RealColumn get rateEstimate => real().withDefault(const Constant(0.0))();
  TextColumn get memberIdsJson => text().nullable()(); // JSON list of employee IDs

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomRoomAssignments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get planId => text()(); // FK -> MushroomHarvestPlans
  TextColumn get roomId => text()(); // References GrowRooms.id or room name
  IntColumn get boxTarget => integer().withDefault(const Constant(0))();
  IntColumn get trolleyCount => integer().withDefault(const Constant(0))();
  TextColumn get teamAssignmentsJson => text().nullable()(); // [{teamColorId, headcountUsed}]
  TextColumn get pickingInstructionsJson => text().nullable()(); // ["SSA","Clumps"]
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomAttendanceEvents extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get employeeId => text()(); // FK -> MushroomEmployees
  TextColumn get planId => text().nullable()(); // References MushroomHarvestPlans.id
  TextColumn get eventType => text()(); // CHECK_IN, CHECK_OUT, BREAK_START, BREAK_END
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get source => text()(); // QR, NFC, MANUAL, BLE_BEACON
  TextColumn get location => text().nullable()(); // location or device ID

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomBreakPolicies extends Table {
  TextColumn get id => text()(); // UUID
  IntColumn get standardBreakMinutes => integer().withDefault(const Constant(30))();
  IntColumn get graceMinutes => integer().withDefault(const Constant(5))();
  TextColumn get extraBreakRule => text().withDefault(const Constant('unpaid'))(); // unpaid, deduct_double, flag_for_review

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomDailyTimesheets extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get employeeId => text()(); // FK -> MushroomEmployees
  DateTimeColumn get planDate => dateTime()();
  DateTimeColumn get checkInTime => dateTime().nullable()();
  DateTimeColumn get checkOutTime => dateTime().nullable()();
  IntColumn get totalBreakTakenMinutes => integer().withDefault(const Constant(0))();
  IntColumn get standardBreakAllowedMinutes => integer().withDefault(const Constant(0))();
  IntColumn get extraBreakMinutes => integer().withDefault(const Constant(0))();
  IntColumn get grossWorkedMinutes => integer().withDefault(const Constant(0))();
  IntColumn get paidMinutes => integer().withDefault(const Constant(0))();
  IntColumn get overtimeMinutes => integer().withDefault(const Constant(0))();
  TextColumn get assignedTeamColor => text().nullable()();
  TextColumn get assignedRoomsJson => text().nullable()(); // JSON list of assigned room numbers/names
  TextColumn get status => text().withDefault(const Constant('normal'))(); // normal, needs_review

  @override
  Set<Column> get primaryKey => {id};
}

class MushroomPayrollCalculations extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get employeeId => text()(); // FK -> MushroomEmployees
  TextColumn get payPeriod => text()(); // e.g. "2026-W30", "2026-07-24"
  RealColumn get totalPaidHours => real().withDefault(const Constant(0.0))();
  RealColumn get totalOvertimeHours => real().withDefault(const Constant(0.0))();
  RealColumn get basePay => real().withDefault(const Constant(0.0))();
  RealColumn get overtimePay => real().withDefault(const Constant(0.0))();
  RealColumn get totalPay => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}


