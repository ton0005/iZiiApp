import 'package:drift/drift.dart';

class PurchaseOrders extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get orderNumber => text()(); // e.g. PO-2026-0001
  TextColumn get partnerName => text()(); // Supplier name
  DateTimeColumn get orderDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft, sent, approved, received, cancelled
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get customFields => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseOrderLines extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get purchaseOrderId => text()();
  TextColumn get productName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
