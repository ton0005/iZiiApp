import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import '../../core/localization/app_localizations.dart';
import 'manifest.dart';
import 'screens/chart_of_accounts_screen.dart';
import 'screens/add_journal_entry_screen.dart';
import 'screens/financial_reports_screen.dart';
import 'screens/payroll_payrun_screen.dart';

class AccountantModule implements IZiiModule {
  @override
  ModuleManifest get manifest => accountantManifest;

  @override
  List<String> get tableNames => [
        'AuContacts',
        'Accounts',
        'TaxRates',
        'JournalEntries',
        'JournalLines',
        'PayrollEvents',
      ];

  @override
  List<AgentTool> get agentTools => []; // No AI tools needed for step 2 core

  @override
  Map<String, WidgetBuilder> get routes => {
        '/accountant/coa': (context) => const ChartOfAccountsScreen(),
        '/accountant/journal': (context) => const AddJournalEntryScreen(),
        '/accountant/reports': (context) => const FinancialReportsScreen(),
        '/accountant/payroll': (context) => const PayrollPayrunScreen(),
      };

  @override
  Widget? get dashboardWidget => const _AccountantDashboardWidget();

  @override
  Future<void> initialize() async {
    // Dynamic localization maps are registered directly inside translations folder,
    // but we can register runtime checks or log details here if needed.
  }

  @override
  Future<void> dispose() async {
    // Cleanup resources
  }

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {
    // AI customization handler
  }
}

class _AccountantDashboardWidget extends StatelessWidget {
  const _AccountantDashboardWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  color: Color(0xFF06B6D4), size: 20),
              const SizedBox(width: 8),
              Text(
                context.tr('module_izii.accountant_name'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Double-entry General Ledger, BAS lodgment & payroll active.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildShortcutButton(context, 'CoA', '/accountant/coa'),
              const SizedBox(width: 8),
              _buildShortcutButton(context, 'Journal', '/accountant/journal'),
              const SizedBox(width: 8),
              _buildShortcutButton(context, 'Reports', '/accountant/reports'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildShortcutButton(
      BuildContext context, String label, String route) {
    return InkWell(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
