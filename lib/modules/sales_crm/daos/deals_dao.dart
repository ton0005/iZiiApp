import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../database/tables.dart';

part 'deals_dao.g.dart';

@DriftAccessor(tables: [Deals, Leads, Contacts])
class DealsDao extends DatabaseAccessor<AppDatabase> with _$DealsDaoMixin {
  DealsDao(super.db);

  Future<List<Deal>> getAllDeals() => select(deals).get();
  Stream<List<Deal>> watchAllDeals() => select(deals).watch();

  Future<Deal?> getDealById(String id) =>
      (select(deals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertDeal(DealsCompanion entry) => into(deals).insert(entry);

  Future<bool> updateDeal(Deal deal) => update(deals).replace(deal);

  Future<int> deleteDeal(String id) =>
      (delete(deals)..where((t) => t.id.equals(id))).go();
}
