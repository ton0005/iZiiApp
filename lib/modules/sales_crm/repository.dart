import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'daos/contacts_dao.dart';
import 'daos/leads_dao.dart';
import 'daos/deals_dao.dart';

class SalesCrmRepository {
  final AppDatabase db;
  final ContactsDao contacts;
  final LeadsDao leads;
  final DealsDao deals;
  final Uuid _uuid = const Uuid();

  SalesCrmRepository(this.db)
      : contacts = ContactsDao(db),
        leads = LeadsDao(db),
        deals = DealsDao(db);

  Future<String> createContact(
      {required String name,
      String? phone,
      String? email,
      String? company}) async {
    final id = _uuid.v4();
    final companion = ContactsCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      email: Value(email),
      address: const Value(null),
      company: Value(company),
      isCustomer: const Value(true),
      createdAt: Value(DateTime.now()),
    );
    await contacts.insertContact(companion);
    return id;
  }

  Future<String> createLead(
      {required String title,
      String? contactId,
      double? expectedRevenue}) async {
    final id = _uuid.v4();
    final companion = LeadsCompanion(
      id: Value(id),
      title: Value(title),
      contactId: Value(contactId),
      status: const Value('new'),
      expectedRevenue: Value(expectedRevenue ?? 0.0),
      notes: const Value(null),
      customFields: const Value('{}'),
      createdAt: Value(DateTime.now()),
    );
    await leads.insertLead(companion);
    return id;
  }

  Future<String> createDeal(
      {required String title,
      required String contactId,
      double amount = 0.0,
      String? leadId}) async {
    final id = _uuid.v4();
    final companion = DealsCompanion(
      id: Value(id),
      title: Value(title),
      leadId: Value(leadId),
      contactId: Value(contactId),
      amount: Value(amount),
      stage: const Value('proposal'),
      expectedCloseDate: const Value(null),
      createdAt: Value(DateTime.now()),
    );
    await deals.insertDeal(companion);
    return id;
  }

  Future<List<Contact>> listContacts() => contacts.getAllContacts();
  Stream<List<Lead>> watchLeads() => leads.watchAllLeads();
  Future<List<Deal>> listDeals() => deals.getAllDeals();
}
