import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../database/tables.dart';

part 'service_items_dao.g.dart';

@DriftAccessor(tables: [ServiceItems])
class ServiceItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceItemsDaoMixin {
  ServiceItemsDao(AppDatabase db) : super(db);

  Future<List<ServiceItem>> getAllServiceItems() => select(serviceItems).get();
  Stream<List<ServiceItem>> watchAllServiceItems() => select(serviceItems).watch();

  Future<List<ServiceItem>> getActiveServiceItems() =>
      (select(serviceItems)..where((tbl) => tbl.isActive.equals(true))).get();

  Future<List<ServiceItem>> getServiceItemsByCategory(String category) =>
      (select(serviceItems)..where((tbl) => tbl.category.equals(category))).get();

  Future<ServiceItem?> getServiceItemById(String id) =>
      (select(serviceItems)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> insertServiceItem(ServiceItemsCompanion entry) =>
      into(serviceItems).insert(entry);

  Future<bool> updateServiceItem(ServiceItem item) =>
      update(serviceItems).replace(item);

  Future<int> deleteServiceItem(String id) =>
      (delete(serviceItems)..where((tbl) => tbl.id.equals(id))).go();
}
