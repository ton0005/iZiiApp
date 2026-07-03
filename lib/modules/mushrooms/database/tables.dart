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

class MushroomJobs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get roomId => text()();
  TextColumn get jobType => text()(); // filling, airing, floor_wet, clean_room, watering, clean_bed, prochloraz, packup_tree, special_solo
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

