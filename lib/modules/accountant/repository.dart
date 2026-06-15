import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/sync/sync_service.dart';

class AccountantRepository {
  static final AccountantRepository _instance = AccountantRepository._internal();
  factory AccountantRepository() => _instance;
  AccountantRepository._internal();

  final _db = AppDatabase();

  // Helper to generate UUIDs locally
  String _generateId(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 9000))}';
  }

  // --- Accounts Management ---

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final accounts = await _db.select(_db.accounts).get();
    return accounts.map((a) => {
      'id': a.id,
      'code': a.code,
      'name': a.name,
      'category': a.category,
      'gst_tax_code': a.gstTaxCode,
      'balance': a.balance,
      'is_active': a.isActive,
    }).toList();
  }

  Future<void> addAccount(Map<String, dynamic> account) async {
    final id = account['id'] ?? _generateId('acc');
    await _db.into(_db.accounts).insert(
      AccountsCompanion.insert(
        id: id,
        code: account['code'],
        name: account['name'],
        category: account['category'],
        gstTaxCode: drift.Value(account['gst_tax_code'] ?? 'GST'),
        balance: drift.Value(account['balance'] ?? 0.0),
        isActive: drift.Value(account['is_active'] ?? true),
      ),
    );
    SyncService().queueMutation('accounts', 'insert', {
      'id': id,
      'code': account['code'],
      'name': account['name'],
      'category': account['category'],
      'gst_tax_code': account['gst_tax_code'] ?? 'GST',
      'balance': account['balance'] ?? 0.0,
      'is_active': account['is_active'] ?? true,
    });
  }

  // --- Double-Entry Journal Postings ---

  Future<void> addJournalEntry(Map<String, dynamic> entry) async {
    final lines = entry['lines'] as List<dynamic>;
    
    // 1. Validate Double-Entry Balance: Debits must equal Credits
    double totalDebits = 0.0;
    double totalCredits = 0.0;
    for (var l in lines) {
      totalDebits += (l['debit'] as num?)?.toDouble() ?? 0.0;
      totalCredits += (l['credit'] as num?)?.toDouble() ?? 0.0;
    }

    // Allow margin for tiny floating point variations
    if ((totalDebits - totalCredits).abs() > 0.001) {
      throw Exception('Journal entry is not balanced. Total Debits: \$${totalDebits.toStringAsFixed(2)}, Total Credits: \$${totalCredits.toStringAsFixed(2)}');
    }

    final entryId = entry['id'] ?? _generateId('je');
    final entryDate = DateTime.tryParse(entry['entry_date'].toString()) ?? DateTime.now();

    // 2. Process inside a SQL Transaction
    await _db.transaction(() async {
      // A. Insert entry header
      await _db.into(_db.journalEntries).insert(
        JournalEntriesCompanion.insert(
          id: entryId,
          entryDate: entryDate,
          reference: drift.Value(entry['reference'] as String?),
          narration: drift.Value(entry['narration'] as String?),
        ),
      );

      // B. Insert lines and update account balances
      for (var l in lines) {
        final lineId = _generateId('jl');
        final accountId = l['account_id'] as String;
        final debit = (l['debit'] as num?)?.toDouble() ?? 0.0;
        final credit = (l['credit'] as num?)?.toDouble() ?? 0.0;
        final gstAmount = (l['gst_amount'] as num?)?.toDouble() ?? 0.0;
        final gstTaxCode = l['gst_tax_code'] as String?;

        await _db.into(_db.journalLines).insert(
          JournalLinesCompanion.insert(
            id: lineId,
            journalEntryId: entryId,
            accountId: accountId,
            debit: drift.Value(debit),
            credit: drift.Value(credit),
            gstAmount: drift.Value(gstAmount),
            gstTaxCode: drift.Value(gstTaxCode),
          ),
        );

        // Update the account balance depending on asset/liability/revenue/expense rules
        final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId))).getSingle();
        double balanceChange = 0.0;
        if (account.category == 'Asset' || account.category == 'Expense' || account.category == 'COGS') {
          balanceChange = debit - credit;
        } else {
          balanceChange = credit - debit;
        }

        await _db.update(_db.accounts).replace(
          account.copyWith(balance: account.balance + balanceChange),
        );
      }
    });

    // C. Queue Sync Mutation
    SyncService().queueMutation('journal_entries', 'insert', {
      'id': entryId,
      'entry_date': entryDate.toIso8601String(),
      'reference': entry['reference'],
      'narration': entry['narration'],
      'lines': lines,
    });
  }

  // --- Financial Reporting Engine ---

  Future<Map<String, dynamic>> getFinancialReports(DateTime startDate, DateTime endDate) async {
    final accounts = await _db.select(_db.accounts).get();
    
    // We compute period activities by checking General Ledger lines
    final linesQuery = _db.select(_db.journalLines).join([
      drift.leftOuterJoin(_db.journalEntries, _db.journalEntries.id.equalsExp(_db.journalLines.journalEntryId)),
    ])..where(_db.journalEntries.entryDate.isBetweenValues(startDate, endDate));

    final rows = await linesQuery.get();
    
    // Activity map: account_id -> net activity during period
    final activityMap = <String, double>{};
    for (final row in rows) {
      final line = row.readTable(_db.journalLines);
      final accId = line.accountId;
      final debit = line.debit;
      final credit = line.credit;

      activityMap[accId] = (activityMap[accId] ?? 0.0) + (debit - credit);
    }

    final pAndL = <String, dynamic>{
      'revenue': <Map<String, dynamic>>[],
      'cogs': <Map<String, dynamic>>[],
      'expense': <Map<String, dynamic>>[],
      'total_revenue': 0.0,
      'total_cogs': 0.0,
      'total_expense': 0.0,
      'net_profit': 0.0,
    };

    final balanceSheet = <String, dynamic>{
      'assets': <Map<String, dynamic>>[],
      'liabilities': <Map<String, dynamic>>[],
      'equity': <Map<String, dynamic>>[],
      'total_assets': 0.0,
      'total_liabilities': 0.0,
      'total_equity': 0.0,
    };

    for (final acc in accounts) {
      final activity = activityMap[acc.id] ?? 0.0;
      
      // Calculate dynamic period balance for P&L (Wages, Sales)
      // Sales/Revenue, COGS, Expenses
      if (acc.category == 'Revenue') {
        final revenueVal = -activity; // Credit is positive for revenue
        pAndL['revenue'].add({'name': acc.name, 'code': acc.code, 'amount': revenueVal});
        pAndL['total_revenue'] = (pAndL['total_revenue'] as double) + revenueVal;
      } else if (acc.category == 'COGS') {
        pAndL['cogs'].add({'name': acc.name, 'code': acc.code, 'amount': activity});
        pAndL['total_cogs'] = (pAndL['total_cogs'] as double) + activity;
      } else if (acc.category == 'Expense') {
        pAndL['expense'].add({'name': acc.name, 'code': acc.code, 'amount': activity});
        pAndL['total_expense'] = (pAndL['total_expense'] as double) + activity;
      }

      // Balance Sheet lists the cumulative balances (as of endDate)
      if (acc.category == 'Asset') {
        balanceSheet['assets'].add({'name': acc.name, 'code': acc.code, 'amount': acc.balance});
        balanceSheet['total_assets'] = (balanceSheet['total_assets'] as double) + acc.balance;
      } else if (acc.category == 'Liability') {
        balanceSheet['liabilities'].add({'name': acc.name, 'code': acc.code, 'amount': acc.balance});
        balanceSheet['total_liabilities'] = (balanceSheet['total_liabilities'] as double) + acc.balance;
      } else if (acc.category == 'Equity') {
        balanceSheet['equity'].add({'name': acc.name, 'code': acc.code, 'amount': acc.balance});
        balanceSheet['total_equity'] = (balanceSheet['total_equity'] as double) + acc.balance;
      }
    }

    pAndL['net_profit'] = (pAndL['total_revenue'] as double) - (pAndL['total_cogs'] as double) - (pAndL['total_expense'] as double);
    
    // Add Net Profit to Equity for Balance Sheet balancing checks
    balanceSheet['equity'].add({'name': 'Net Profit / Retained Earnings', 'code': '3-9999', 'amount': pAndL['net_profit']});
    balanceSheet['total_equity'] = (balanceSheet['total_equity'] as double) + (pAndL['net_profit'] as double);

    return {
      'profit_and_loss': pAndL,
      'balance_sheet': balanceSheet,
    };
  }

  // --- BAS Tax Calculator (Compliance) ---

  Future<Map<String, dynamic>> calculateBasReport(DateTime startDate, DateTime endDate) async {
    final linesQuery = _db.select(_db.journalLines).join([
      drift.leftOuterJoin(_db.journalEntries, _db.journalEntries.id.equalsExp(_db.journalLines.journalEntryId)),
      drift.leftOuterJoin(_db.accounts, _db.accounts.id.equalsExp(_db.journalLines.accountId)),
    ])..where(_db.journalEntries.entryDate.isBetweenValues(startDate, endDate));

    final rows = await linesQuery.get();

    double g1TotalSales = 0.0;
    double g3GstFreeSales = 0.0;
    double g10CapitalPurchases = 0.0;
    double g11NonCapitalPurchases = 0.0;
    double gstCollected1A = 0.0;
    double gstPaid1B = 0.0;

    for (final row in rows) {
      final line = row.readTable(_db.journalLines);
      final entry = row.readTable(_db.journalEntries);
      final acc = row.readTable(_db.accounts);

      final debit = line.debit;
      final credit = line.credit;
      final gstVal = line.gstAmount;
      final taxCode = line.gstTaxCode;

      // Sales / Outputs
      if (acc.category == 'Revenue') {
        g1TotalSales += credit; // Credit represents sales amount
        if (taxCode == 'FRE') {
          g3GstFreeSales += credit;
        }
        if (taxCode == 'GST') {
          gstCollected1A += gstVal;
        }
      }

      // Purchases / Inputs
      if (acc.category == 'Expense' || acc.category == 'COGS' || acc.category == 'Asset') {
        final purchaseAmt = debit; // Debit represents purchase cost
        if (acc.category == 'Asset') {
          g10CapitalPurchases += purchaseAmt;
        } else {
          g11NonCapitalPurchases += purchaseAmt;
        }

        if (taxCode == 'GST') {
          gstPaid1B += gstVal;
        }
      }
    }

    // Grab PAYG Withheld from Payroll Events
    final payrollQuery = _db.select(_db.payrollEvents)
      ..where((p) => p.paymentDate.isBetweenValues(startDate, endDate));
    final payrolls = await payrollQuery.get();

    double w1GrossWages = 0.0;
    double w2PaygWithheld = 0.0;
    for (final p in payrolls) {
      w1GrossWages += p.totalGross;
      w2PaygWithheld += p.totalTaxWithheld;
    }

    final double netBasDue = (gstCollected1A + w2PaygWithheld) - gstPaid1B;

    return {
      'G1': g1TotalSales,
      'G3': g3GstFreeSales,
      'G10': g10CapitalPurchases,
      'G11': g11NonCapitalPurchases,
      '1A': gstCollected1A,
      '1B': gstPaid1B,
      'W1': w1GrossWages,
      'W2': w2PaygWithheld,
      'net_due': netBasDue,
    };
  }

  // --- Payroll STP Lodgment ---

  Future<void> submitStpPayrollEvent(Map<String, dynamic> payrun) async {
    final id = payrun['id'] ?? _generateId('pr');
    final start = DateTime.tryParse(payrun['pay_period_start'].toString()) ?? DateTime.now();
    final end = DateTime.tryParse(payrun['pay_period_end'].toString()) ?? DateTime.now();
    final payDate = DateTime.tryParse(payrun['payment_date'].toString()) ?? DateTime.now();
    
    final receiptNum = 'ATO_STP_${DateTime.now().millisecondsSinceEpoch}';

    await _db.into(_db.payrollEvents).insert(
      PayrollEventsCompanion.insert(
        id: id,
        payPeriodStart: start,
        payPeriodEnd: end,
        paymentDate: payDate,
        totalGross: (payrun['total_gross'] as num).toDouble(),
        totalTaxWithheld: (payrun['total_tax_withheld'] as num).toDouble(),
        totalSuper: (payrun['total_super'] as num).toDouble(),
        stpSubmissionStatus: const drift.Value('submitted'),
        stpReceiptNumber: drift.Value(receiptNum),
      ),
    );

    SyncService().queueMutation('payroll_events', 'insert', {
      'id': id,
      'pay_period_start': start.toIso8601String(),
      'pay_period_end': end.toIso8601String(),
      'payment_date': payDate.toIso8601String(),
      'total_gross': payrun['total_gross'],
      'total_tax_withheld': payrun['total_tax_withheld'],
      'total_super': payrun['total_super'],
      'stp_submission_status': 'submitted',
      'stp_receipt_number': receiptNum,
    });
  }

  // --- ABA (Australian Bankers Association) Bulk Pay Generator ---

  String generateAbaFile({
    required String userFinancialInstitution, // e.g., 'CBA', 'NAB'
    required String userSupplyingFile, // e.g., 'IZIIAPP PTY LTD'
    required String userApcaNumber, // 6-digit APCA number
    required String payDescription, // 12-char description, e.g., 'PAYROLL'
    required DateTime processDate,
    required String userBsb, // User BSB: e.g. '062-900'
    required String userAccountNumber, // User account: e.g. '123456789'
    required List<Map<String, dynamic>> payees, // List of {bsb, account_number, amount_dollars, account_title, lodgement_reference}
  }) {
    final StringBuffer buffer = StringBuffer();

    // Helper to pad fields
    String padLeft(String val, int width, [String char = ' ']) {
      if (val.length >= width) return val.substring(0, width);
      return char * (width - val.length) + val;
    }
    String padRight(String val, int width, [String char = ' ']) {
      if (val.length >= width) return val.substring(0, width);
      return val + (char * (width - val.length));
    }

    // 1. Generate Descriptive Record (Type 0)
    final String dateStr = '${processDate.day.toString().padLeft(2, '0')}${processDate.month.toString().padLeft(2, '0')}${processDate.year.toString().substring(2)}';
    buffer.write('0'); // Record type
    buffer.write(padRight('', 17)); // Spaces
    buffer.write('01'); // Reel Sequence Number
    buffer.write(padRight(userFinancialInstitution, 3)); // User Bank Code
    buffer.write(padRight('', 7)); // Spaces
    buffer.write(padRight(userSupplyingFile, 26)); // Supplying User Name
    buffer.write(padLeft(userApcaNumber, 6, '0')); // User Identification Number
    buffer.write(padRight(payDescription, 12)); // Entry Description
    buffer.write(dateStr); // Process Date DDMMYY
    buffer.write(padRight('', 40)); // Filler spaces
    buffer.write('\r\n');

    int totalCents = 0;
    int payeeCount = 0;

    // 2. Generate Detail Records (Type 1)
    for (var payee in payees) {
      final double amtDollars = (payee['amount_dollars'] as num).toDouble();
      final int cents = (amtDollars * 100).round();
      totalCents += cents;
      payeeCount++;

      buffer.write('1'); // Record type
      buffer.write(payee['bsb'].toString().replaceAll('-', '')); // BSB (6 digits)
      buffer.write(padLeft(payee['account_number'].toString(), 9)); // Account number
      buffer.write(' '); // Indicator (space)
      buffer.write('53'); // Transaction code (53 = payroll payment, 50 = standard credit)
      buffer.write(padLeft(cents.toString(), 10, '0')); // Amount in cents
      buffer.write(padRight(payee['account_title'].toString(), 32)); // Title of account
      buffer.write(padRight(payee['lodgement_reference'] ?? 'PAYMENT', 18)); // Lodgement reference
      buffer.write(userBsb.replaceAll('-', '')); // BSB of supplying user bank
      buffer.write(padLeft(userAccountNumber, 9)); // Account number of supplying user
      buffer.write(padRight(userSupplyingFile, 16)); // Name of supplying user
      buffer.write('00000000'); // Withholding tax amount
      buffer.write('\r\n');
    }

    // 3. Generate File Total Record (Type 7)
    buffer.write('7'); // Record type
    buffer.write('999-999'); // BSB
    buffer.write(padRight('', 12)); // Spaces
    buffer.write(padLeft(totalCents.toString(), 10, '0')); // Net total
    buffer.write(padLeft(totalCents.toString(), 10, '0')); // Credit total (payments to workers)
    buffer.write(padLeft('0', 10, '0')); // Debit total
    buffer.write(padRight('', 24)); // Spaces
    buffer.write(padLeft(payeeCount.toString(), 6, '0')); // Count of detail records
    buffer.write(padRight('', 34)); // Filler spaces
    buffer.write('\r\n');

    return buffer.toString();
  }

  // --- Fetch Additional Entities ---

  Future<List<Map<String, dynamic>>> getPayrollEvents() async {
    final events = await (_db.select(_db.payrollEvents)
      ..orderBy([(t) => drift.OrderingTerm(expression: t.paymentDate, mode: drift.OrderingMode.desc)]))
      .get();
    return events.map((p) => {
      'id': p.id,
      'pay_period_start': p.payPeriodStart.toIso8601String(),
      'pay_period_end': p.payPeriodEnd.toIso8601String(),
      'payment_date': p.paymentDate.toIso8601String(),
      'total_gross': p.totalGross,
      'total_tax_withheld': p.totalTaxWithheld,
      'total_super': p.totalSuper,
      'stp_submission_status': p.stpSubmissionStatus,
      'stp_receipt_number': p.stpReceiptNumber,
      'created_at': p.createdAt.toIso8601String(),
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getJournalEntries() async {
    final entries = await (_db.select(_db.journalEntries)
      ..orderBy([(t) => drift.OrderingTerm(expression: t.entryDate, mode: drift.OrderingMode.desc)]))
      .get();
    final List<Map<String, dynamic>> list = [];
    for (final entry in entries) {
      final lines = await (_db.select(_db.journalLines)..where((l) => l.journalEntryId.equals(entry.id))).get();
      list.add({
        'id': entry.id,
        'entry_date': entry.entryDate.toIso8601String(),
        'reference': entry.reference,
        'narration': entry.narration,
        'created_at': entry.createdAt.toIso8601String(),
        'lines': lines.map((l) => {
          'id': l.id,
          'account_id': l.accountId,
          'debit': l.debit,
          'credit': l.credit,
          'gst_amount': l.gstAmount,
          'gst_tax_code': l.gstTaxCode,
        }).toList(),
      });
    }
    return list;
  }

  // --- Seeding ---

  Future<void> seedTaxRatesAndAccounts() async {
    // 1. Seed Tax Rates
    final existingRates = await _db.select(_db.taxRates).get();
    if (existingRates.isEmpty) {
      await _db.into(_db.taxRates).insert(const TaxRatesCompanion(
        code: drift.Value('GST'),
        rate: drift.Value(0.10),
        description: drift.Value('Goods and Services Tax (10%)'),
      ));
      await _db.into(_db.taxRates).insert(const TaxRatesCompanion(
        code: drift.Value('FRE'),
        rate: drift.Value(0.00),
        description: drift.Value('GST Free'),
      ));
      await _db.into(_db.taxRates).insert(const TaxRatesCompanion(
        code: drift.Value('ITS'),
        rate: drift.Value(0.00),
        description: drift.Value('Input Taxed Sales'),
      ));
      await _db.into(_db.taxRates).insert(const TaxRatesCompanion(
        code: drift.Value('EXM'),
        rate: drift.Value(0.00),
        description: drift.Value('Exempt'),
      ));
    }

    // 2. Seed Default Accounts
    final existingAccounts = await _db.select(_db.accounts).get();
    if (existingAccounts.isEmpty) {
      final defaultAccounts = [
        // Assets
        {'code': '1-1000', 'name': 'Operating Bank Account', 'category': 'Asset', 'gst_tax_code': 'ITS', 'balance': 50000.0},
        {'code': '1-1200', 'name': 'Accounts Receivable', 'category': 'Asset', 'gst_tax_code': 'GST', 'balance': 0.0},
        {'code': '1-1500', 'name': 'Office Equipment', 'category': 'Asset', 'gst_tax_code': 'GST', 'balance': 12000.0},
        
        // Liabilities
        {'code': '2-1000', 'name': 'Accounts Payable', 'category': 'Liability', 'gst_tax_code': 'GST', 'balance': 0.0},
        {'code': '2-2000', 'name': 'GST Collected', 'category': 'Liability', 'gst_tax_code': 'ITS', 'balance': 0.0},
        {'code': '2-2100', 'name': 'GST Paid', 'category': 'Liability', 'gst_tax_code': 'ITS', 'balance': 0.0},
        {'code': '2-2200', 'name': 'PAYG Withholding Payable', 'category': 'Liability', 'gst_tax_code': 'ITS', 'balance': 0.0},
        {'code': '2-2300', 'name': 'Superannuation Payable', 'category': 'Liability', 'gst_tax_code': 'ITS', 'balance': 0.0},
        
        // Equity
        {'code': '3-1000', 'name': 'Owner Capital', 'category': 'Equity', 'gst_tax_code': 'ITS', 'balance': 62000.0},
        {'code': '3-8000', 'name': 'Retained Earnings', 'category': 'Equity', 'gst_tax_code': 'ITS', 'balance': 0.0},

        // Revenue
        {'code': '4-1000', 'name': 'Sales Revenue', 'category': 'Revenue', 'gst_tax_code': 'GST', 'balance': 0.0},
        {'code': '4-1200', 'name': 'GST Free Sales', 'category': 'Revenue', 'gst_tax_code': 'FRE', 'balance': 0.0},

        // COGS
        {'code': '5-1000', 'name': 'Cost of Goods Sold', 'category': 'COGS', 'gst_tax_code': 'GST', 'balance': 0.0},

        // Expenses
        {'code': '6-1000', 'name': 'Wages & Salaries Expense', 'category': 'Expense', 'gst_tax_code': 'ITS', 'balance': 0.0},
        {'code': '6-1100', 'name': 'Superannuation Expense', 'category': 'Expense', 'gst_tax_code': 'ITS', 'balance': 0.0},
        {'code': '6-1200', 'name': 'Office Rent', 'category': 'Expense', 'gst_tax_code': 'GST', 'balance': 0.0},
        {'code': '6-1300', 'name': 'Electricity & Utilities', 'category': 'Expense', 'gst_tax_code': 'GST', 'balance': 0.0},
        {'code': '6-1400', 'name': 'Bank Fees', 'category': 'Expense', 'gst_tax_code': 'ITS', 'balance': 0.0},
        {'code': '6-1500', 'name': 'Shipping & Delivery Expense', 'category': 'Expense', 'gst_tax_code': 'GST', 'balance': 0.0},
      ];

      for (var acc in defaultAccounts) {
        await addAccount(acc);
      }
    }
  }

  Future<bool> hasJournalEntryReference(String reference) async {
    final query = _db.select(_db.journalEntries)..where((tbl) => tbl.reference.equals(reference));
    final entries = await query.get();
    return entries.isNotEmpty;
  }
}
