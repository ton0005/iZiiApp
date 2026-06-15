import 'package:drift/drift.dart';

class Contacts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get company => text().nullable()();
  BoolColumn get isCustomer => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Leads extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get title => text()();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get status =>
      text().withDefault(const Constant('new'))(); // new, qualified, won, lost
  RealColumn get expectedRevenue => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('direct'))(); // direct, website, referral, campaign
  TextColumn get ownerId => text().nullable()(); // assigned sales rep
  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  TextColumn get visibility => text().withDefault(const Constant('private'))(); // private, team, community
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Deals extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get title => text()();
  TextColumn get leadId => text().nullable().references(Leads, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();
  RealColumn get amount => real()();
  TextColumn get stage => text().withDefault(const Constant(
      'proposal'))(); // proposal, negotiation, closed_won, closed_lost
  TextColumn get source => text().withDefault(const Constant('direct'))(); // direct, website, referral, campaign
  TextColumn get ownerId => text().nullable()(); // assigned sales rep
  TextColumn get visibility => text().withDefault(const Constant('private'))(); // private, team, community
  DateTimeColumn get expectedCloseDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
