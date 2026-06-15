import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../database/tables.dart';

part 'leads_dao.g.dart';

@DriftAccessor(tables: [Leads, Contacts])
class LeadsDao extends DatabaseAccessor<AppDatabase> with _$LeadsDaoMixin {
  LeadsDao(super.db);

  Future<List<Lead>> getAllLeads() => select(leads).get();
  Stream<List<Lead>> watchAllLeads() => select(leads).watch();

  Future<Lead?> getLeadById(String id) =>
      (select(leads)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertLead(LeadsCompanion entry) => into(leads).insert(entry);

  Future<bool> updateLead(Lead lead) => update(leads).replace(lead);

  Future<int> deleteLead(String id) =>
      (delete(leads)..where((t) => t.id.equals(id))).go();
}
