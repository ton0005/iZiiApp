import 'package:drift/drift.dart';

class ServiceItems extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('other'))(); // repair, installation, delivery, cleaning, electrical, plumbing, other
  RealColumn get hourlyRate => real()();
  RealColumn get estimatedHours => real().withDefault(const Constant(1.0))();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ServiceBookings extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get serviceItemId => text()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  RealColumn get actualHours => real().nullable()();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, confirmed, in_progress, completed, cancelled
  TextColumn get notes => text().nullable()();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
