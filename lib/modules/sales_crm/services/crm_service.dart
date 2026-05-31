import 'package:izii_app/core/sync/sync_service.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/sales_crm/repository.dart';

class CrmService {
  final SalesCrmRepository repo;
  final SyncService sync;

  CrmService(AppDatabase db, this.sync) : repo = SalesCrmRepository(db);

  Future<String> createContact(
      {required String name,
      String? phone,
      String? email,
      String? company}) async {
    final id = await repo.createContact(
        name: name, phone: phone, email: email, company: company);
    sync.queueMutation('contacts', 'insert', {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
    });
    return id;
  }

  Future<String> createLead(
      {required String title,
      String? contactId,
      double? expectedRevenue}) async {
    final id = await repo.createLead(
        title: title, contactId: contactId, expectedRevenue: expectedRevenue);
    sync.queueMutation('leads', 'insert', {
      'id': id,
      'title': title,
      'contactId': contactId,
      'expectedRevenue': expectedRevenue,
    });
    return id;
  }

  Future<String> createDeal(
      {required String title,
      required String contactId,
      double amount = 0.0,
      String? leadId}) async {
    final id = await repo.createDeal(
        title: title, contactId: contactId, amount: amount, leadId: leadId);
    sync.queueMutation('deals', 'insert', {
      'id': id,
      'title': title,
      'contactId': contactId,
      'leadId': leadId,
      'amount': amount,
    });
    return id;
  }

  // Additional helpers (update/delete) can be added similarly.
}
