// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_bookings_dao.dart';

// ignore_for_file: type=lint
mixin _$ServiceBookingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ServiceBookingsTable get serviceBookings => attachedDatabase.serviceBookings;
  ServiceBookingsDaoManager get managers => ServiceBookingsDaoManager(this);
}

class ServiceBookingsDaoManager {
  final _$ServiceBookingsDaoMixin _db;
  ServiceBookingsDaoManager(this._db);
  $$ServiceBookingsTableTableManager get serviceBookings =>
      $$ServiceBookingsTableTableManager(
          _db.attachedDatabase, _db.serviceBookings);
}
