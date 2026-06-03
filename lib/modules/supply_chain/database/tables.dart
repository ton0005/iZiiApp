import 'package:drift/drift.dart';

class Products extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get sku => text().unique()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  RealColumn get cost => real()();
  TextColumn get type => text()
      .withDefault(const Constant('product'))(); // product, service, consumable
  TextColumn get barcode =>
      text().nullable()(); // Note: unique constraint handled at app level
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class StockQuants extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get locationId => text()(); // Kho hàng
  RealColumn get quantity => real()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMoves extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  TextColumn get sourceLocationId => text()();
  TextColumn get destLocationId => text()();
  TextColumn get status =>
      text().withDefault(const Constant('draft'))(); // draft, done, cancelled
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
