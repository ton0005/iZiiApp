import 'package:drift/drift.dart';

class Projects extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, completed, archived
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get projectId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('todo'))(); // todo, in_progress, done
  TextColumn get priority => text().withDefault(const Constant('medium'))(); // low, medium, high
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
