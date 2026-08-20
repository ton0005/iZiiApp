import 'package:drift/drift.dart';

class Doctors extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get specialty => text().withDefault(const Constant(''))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Patients extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get fullName => text()();
  DateTimeColumn get dob => dateTime().nullable()();
  TextColumn get gender => text().nullable()(); // male, female, other
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get idNumber => text().nullable()(); // CMND/CCCD/BHYT
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Appointments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get reason => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))(); // scheduled, checked_in, completed, cancelled, no_show
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MedicalVisits extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()();
  TextColumn get appointmentId => text().nullable()();
  DateTimeColumn get visitDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get chiefComplaint => text().nullable()();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))(); // open, completed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Prescriptions extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get visitId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()();
  DateTimeColumn get prescriptionDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, dispensed, cancelled
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PrescriptionItems extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get prescriptionId => text()();
  TextColumn get productId => text()(); // references supply_chain Products.id
  TextColumn get medicineName => text()(); // denormalized snapshot
  TextColumn get dosageInstructions => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
