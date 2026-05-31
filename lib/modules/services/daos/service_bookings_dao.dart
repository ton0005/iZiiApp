import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../database/tables.dart';

part 'service_bookings_dao.g.dart';

@DriftAccessor(tables: [ServiceBookings])
class ServiceBookingsDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceBookingsDaoMixin {
  ServiceBookingsDao(AppDatabase db) : super(db);

  Future<List<ServiceBooking>> getAllBookings() =>
      (select(serviceBookings)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Stream<List<ServiceBooking>> watchAllBookings() =>
      (select(serviceBookings)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<List<ServiceBooking>> getBookingsByStatus(String status) =>
      (select(serviceBookings)..where((tbl) => tbl.status.equals(status))).get();

  Future<List<ServiceBooking>> getBookingsByServiceId(String serviceItemId) =>
      (select(serviceBookings)..where((tbl) => tbl.serviceItemId.equals(serviceItemId))).get();

  Future<ServiceBooking?> getBookingById(String id) =>
      (select(serviceBookings)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> insertBooking(ServiceBookingsCompanion entry) =>
      into(serviceBookings).insert(entry);

  Future<bool> updateBooking(ServiceBooking booking) =>
      update(serviceBookings).replace(booking);

  Future<int> deleteBooking(String id) =>
      (delete(serviceBookings)..where((tbl) => tbl.id.equals(id))).go();
}
