import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import '../database/tables.dart';

part 'contacts_dao.g.dart';

@DriftAccessor(tables: [Contacts])
class ContactsDao extends DatabaseAccessor<AppDatabase>
    with _$ContactsDaoMixin {
  ContactsDao(super.db);

  Future<List<Contact>> getAllContacts() => select(contacts).get();
  Stream<List<Contact>> watchAllContacts() => select(contacts).watch();

  Future<Contact?> getContactById(String id) =>
      (select(contacts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertContact(ContactsCompanion entry) =>
      into(contacts).insert(entry);

  Future<bool> updateContact(Contact contact) =>
      update(contacts).replace(contact);

  Future<int> deleteContact(String id) =>
      (delete(contacts)..where((t) => t.id.equals(id))).go();
}
