import 'package:drift/drift.dart';
import '../../sales_crm/database/tables.dart';

class AuContacts extends Table {
  TextColumn get id => text().references(Contacts, #id)(); // References Core Contact
  TextColumn get abn => text().nullable()(); // 11-digit ABN
  TextColumn get abnStatus => text().nullable()(); // Active, Cancelled
  BoolColumn get isRctiEligible => boolean().withDefault(const Constant(false))(); // Recipient-Created Tax Invoice flag
  TextColumn get bpayBillerCode => text().nullable()();
  TextColumn get bpayCrn => text().nullable()(); // Luhn Mod 10 Customer Reference Number
  TextColumn get bankBsb => text().nullable()(); // 6-digit Bank State Branch code
  TextColumn get bankAccountNumber => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get code => text()(); // Code: '1-1000', '4-2000'
  TextColumn get name => text()(); // Name: 'Sales', 'Rent Expense'
  TextColumn get category => text()(); // Asset, Liability, Equity, Revenue, COGS, Expense
  TextColumn get gstTaxCode => text().withDefault(const Constant('GST'))(); // Default Tax mapping (GST, FRE, ITS, EXM)
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class TaxRates extends Table {
  TextColumn get code => text()(); // GST, FRE, ITS, EXM
  RealColumn get rate => real()(); // 0.10, 0.00
  TextColumn get description => text()();

  @override
  Set<Column> get primaryKey => {code};
}

class JournalEntries extends Table {
  TextColumn get id => text()(); // UUID
  DateTimeColumn get entryDate => dateTime()();
  TextColumn get reference => text().nullable()(); // Invoice ID or receipt ref
  TextColumn get narration => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class JournalLines extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get journalEntryId => text().references(JournalEntries, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  RealColumn get debit => real().withDefault(const Constant(0.0))();
  RealColumn get credit => real().withDefault(const Constant(0.0))();
  RealColumn get gstAmount => real().withDefault(const Constant(0.0))();
  TextColumn get gstTaxCode => text().nullable().references(TaxRates, #code)();

  @override
  Set<Column> get primaryKey => {id};
}

class PayrollEvents extends Table {
  TextColumn get id => text()(); // UUID
  DateTimeColumn get payPeriodStart => dateTime()();
  DateTimeColumn get payPeriodEnd => dateTime()();
  DateTimeColumn get paymentDate => dateTime()();
  RealColumn get totalGross => real()();
  RealColumn get totalTaxWithheld => real()(); // PAYG tax
  RealColumn get totalSuper => real()(); // Superannuation Guarantee
  TextColumn get stpSubmissionStatus => text().withDefault(const Constant('pending'))(); // pending, submitted, accepted, rejected
  TextColumn get stpReceiptNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
