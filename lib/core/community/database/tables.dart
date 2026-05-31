import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class TrustScores extends Table {
  TextColumn get userId => text().references(Users, #id)();
  RealColumn get overallScore => real().withDefault(const Constant(0.0))();
  IntColumn get referralCount => integer().withDefault(const Constant(0))();
  TextColumn get referredBy => text().nullable().references(Users, #id)();
  IntColumn get completedOrders => integer().withDefault(const Constant(0))();
  RealColumn get avgRating => real().withDefault(const Constant(0.0))();
  DateTimeColumn get memberSince => dateTime().withDefault(currentDateAndTime)();
  TextColumn get level => text().withDefault(const Constant('newcomer'))(); // newcomer, trusted, verified, elite
  BoolColumn get kycVerified => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId};
}

class Referrals extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get inviterId => text().references(Users, #id)();
  TextColumn get inviteeId => text().nullable().references(Users, #id)();
  TextColumn get contactInfo => text()(); // phone or email
  TextColumn get status => text().withDefault(const Constant('sent'))(); // sent, accepted, expired
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get acceptedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ServiceListings extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get providerId => text().references(Users, #id)();
  TextColumn get serviceType => text()(); // repair, installation, etc.
  TextColumn get title => text()();
  TextColumn get description => text()();
  RealColumn get priceMin => real().nullable()();
  RealColumn get priceMax => real().nullable()();
  TextColumn get location => text().nullable()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  RealColumn get rating => real().withDefault(const Constant(0.0))();
  IntColumn get completedCount => integer().withDefault(const Constant(0))();
  TextColumn get tags => text().nullable()(); // comma separated
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ServiceOrders extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get consumerId => text().references(Users, #id)();
  TextColumn get providerId => text().references(Users, #id)();
  TextColumn get serviceListingId => text().references(ServiceListings, #id)();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, accepted, in_progress, completed, cancelled, disputed
  TextColumn get description => text()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get totalPrice => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Reviews extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get orderId => text().references(ServiceOrders, #id)();
  TextColumn get reviewerId => text().references(Users, #id)();
  TextColumn get revieweeId => text().references(Users, #id)();
  RealColumn get rating => real()(); // 1.0 - 5.0
  TextColumn get comment => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
