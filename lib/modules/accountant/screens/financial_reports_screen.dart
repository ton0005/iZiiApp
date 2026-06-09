import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/izii_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/accountant_bloc.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Set to current Australian Financial Year by default (if today is June 8, 2026, the current FY is July 1, 2025 - June 30, 2026)
    final now = DateTime.now();
    if (now.month >= 7) {
      _startDate = DateTime(now.year, 7, 1);
      _endDate = DateTime(now.year + 1, 6, 30);
    } else {
      _startDate = DateTime(now.year - 1, 7, 1);
      _endDate = DateTime(now.year, 6, 30);
    }
    
    _loadReports();
  }

  void _loadReports() {
    context.read<AccountantBloc>().add(LoadFinancialReportsEvent(_startDate, _endDate));
    context.read<AccountantBloc>().add(LoadBasReportEvent(_startDate, _endDate));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: IZiiColors.primary,
              surface: IZiiColors.darkSurface,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: IZiiColors.darkBackground,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReports();
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IZiiColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.tr('acc_reports_title'),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded, color: Colors.white),
            onPressed: () => _selectDateRange(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: IZiiColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: [
            Tab(text: context.tr('acc_pl_report')),
            Tab(text: context.tr('acc_bs_report')),
            Tab(text: context.tr('acc_bas_report')),
          ],
        ),
      ),
      body: BlocBuilder<AccountantBloc, AccountantState>(
        builder: (context, state) {
          if (state.isLoading && state.financialReports == null) {
            return const Center(
              child: CircularProgressIndicator(color: IZiiColors.primary),
            );
          }

          final Map<String, dynamic> pAndL = state.financialReports != null
              ? Map<String, dynamic>.from(state.financialReports!['profit_and_loss'] as Map)
              : const {};
          final Map<String, dynamic> bs = state.financialReports != null
              ? Map<String, dynamic>.from(state.financialReports!['balance_sheet'] as Map)
              : const {};
          final Map<String, dynamic> bas = state.basReport != null
              ? Map<String, dynamic>.from(state.basReport!)
              : const {};

          return Column(
            children: [
              // Date Range Indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.white.withOpacity(0.02),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reporting Period',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    ),
                    Text(
                      '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Profit & Loss
                    _buildProfitAndLossTab(pAndL),
                    // Tab 2: Balance Sheet
                    _buildBalanceSheetTab(bs),
                    // Tab 3: BAS Tax Statement
                    _buildBasTab(bas),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(String name, double amount, {bool isHeader = false, bool isSubtotal = false}) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: isHeader ? 16 : 14,
      fontWeight: (isHeader || isSubtotal) ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isHeader ? 8.0 : 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: style),
          Text(
            '${amount < 0 ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: style.copyWith(
              color: isSubtotal
                  ? (amount >= 0 ? IZiiColors.success : IZiiColors.error)
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitAndLossTab(Map<String, dynamic> pAndL) {
    if (pAndL.isEmpty) {
      return const Center(child: Text('No data for selected period', style: TextStyle(color: Colors.white38)));
    }

    final double netProfit = (pAndL['net_profit'] as num?)?.toDouble() ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Total Revenue
        Text('REVENUE', style: TextStyle(color: IZiiColors.primary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        ...((pAndL['revenue'] as List? ?? []).map((e) => _buildRow(e['name'], (e['amount'] as num).toDouble()))),
        _buildRow(context.tr('acc_total_revenue'), (pAndL['total_revenue'] as num?)?.toDouble() ?? 0.0, isSubtotal: true),
        const SizedBox(height: 24),

        // Cost of Goods Sold
        Text('COST OF GOODS SOLD', style: TextStyle(color: IZiiColors.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        ...((pAndL['cogs'] as List? ?? []).map((e) => _buildRow(e['name'], (e['amount'] as num).toDouble()))),
        _buildRow(context.tr('acc_total_cogs'), (pAndL['total_cogs'] as num?)?.toDouble() ?? 0.0, isSubtotal: true),
        const SizedBox(height: 24),

        // Expenses
        Text('EXPENSES', style: TextStyle(color: IZiiColors.error, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        ...((pAndL['expense'] as List? ?? []).map((e) => _buildRow(e['name'], (e['amount'] as num).toDouble()))),
        _buildRow(context.tr('acc_total_expense'), (pAndL['total_expense'] as num?)?.toDouble() ?? 0.0, isSubtotal: true),
        const SizedBox(height: 32),

        // Net Profit Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: netProfit >= 0
                ? IZiiColors.success.withOpacity(0.12)
                : IZiiColors.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: netProfit >= 0 ? IZiiColors.success.withOpacity(0.3) : IZiiColors.error.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('acc_net_profit'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                '${netProfit < 0 ? '-' : ''}\$${netProfit.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: netProfit >= 0 ? IZiiColors.success : IZiiColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildBalanceSheetTab(Map<String, dynamic> bs) {
    if (bs.isEmpty) {
      return const Center(child: Text('No data as of end date', style: TextStyle(color: Colors.white38)));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Assets
        Text('ASSETS', style: TextStyle(color: IZiiColors.secondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        ...((bs['assets'] as List? ?? []).map((e) => _buildRow(e['name'], (e['amount'] as num).toDouble()))),
        _buildRow(context.tr('acc_total_assets'), (bs['total_assets'] as num?)?.toDouble() ?? 0.0, isSubtotal: true),
        const SizedBox(height: 24),

        // Liabilities
        Text('LIABILITIES', style: TextStyle(color: IZiiColors.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        ...((bs['liabilities'] as List? ?? []).map((e) => _buildRow(e['name'], (e['amount'] as num).toDouble()))),
        _buildRow(context.tr('acc_total_liabilities'), (bs['total_liabilities'] as num?)?.toDouble() ?? 0.0, isSubtotal: true),
        const SizedBox(height: 24),

        // Equity
        Text('EQUITY', style: TextStyle(color: IZiiColors.primary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        ...((bs['equity'] as List? ?? []).map((e) => _buildRow(e['name'], (e['amount'] as num).toDouble()))),
        _buildRow(context.tr('acc_total_equity'), (bs['total_equity'] as num?)?.toDouble() ?? 0.0, isSubtotal: true),
        const SizedBox(height: 32),

        // Balance Verification Check
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              (bs['total_assets'] as double) == (bs['total_liabilities'] as double) + (bs['total_equity'] as double)
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              color: (bs['total_assets'] as double) == (bs['total_liabilities'] as double) + (bs['total_equity'] as double)
                  ? IZiiColors.success
                  : IZiiColors.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              (bs['total_assets'] as double) == (bs['total_liabilities'] as double) + (bs['total_equity'] as double)
                  ? 'Ledger is in perfect balance'
                  : 'Out of balance warning',
              style: TextStyle(
                color: (bs['total_assets'] as double) == (bs['total_liabilities'] as double) + (bs['total_equity'] as double)
                    ? IZiiColors.success
                    : IZiiColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildBasLabelVal(String label, String code, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: const TextStyle(color: IZiiColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBasTab(Map<String, dynamic> bas) {
    if (bas.isEmpty) {
      return const Center(child: Text('No data for selected period', style: TextStyle(color: Colors.white38)));
    }

    final double netDue = (bas['net_due'] as num?)?.toDouble() ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // GST Sales section
        Text('GOODS & SERVICES TAX - SALES', style: TextStyle(color: IZiiColors.primary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        _buildBasLabelVal(context.tr('acc_bas_total_sales'), 'G1', (bas['G1'] as num).toDouble()),
        _buildBasLabelVal(context.tr('acc_bas_gst_free_sales'), 'G3', (bas['G3'] as num).toDouble()),
        const SizedBox(height: 16),

        // GST Purchases section
        Text('GOODS & SERVICES TAX - PURCHASES', style: TextStyle(color: IZiiColors.secondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        _buildBasLabelVal(context.tr('acc_bas_capital_purchases'), 'G10', (bas['G10'] as num).toDouble()),
        _buildBasLabelVal(context.tr('acc_bas_non_capital_purchases'), 'G11', (bas['G11'] as num).toDouble()),
        const SizedBox(height: 16),

        // Net GST summary
        Text('ATO SUMMARY LABELS', style: TextStyle(color: IZiiColors.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const Divider(color: Colors.white12),
        _buildBasLabelVal(context.tr('acc_bas_gst_collected'), '1A', (bas['1A'] as num).toDouble()),
        _buildBasLabelVal(context.tr('acc_bas_gst_paid'), '1B', (bas['1B'] as num).toDouble()),
        _buildBasLabelVal(context.tr('acc_bas_wages'), 'W1', (bas['W1'] as num).toDouble()),
        _buildBasLabelVal(context.tr('acc_bas_payg_withheld'), 'W2', (bas['W2'] as num).toDouble()),
        const SizedBox(height: 24),

        // BAS Due / Refund Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: netDue >= 0 ? IZiiColors.error.withOpacity(0.12) : IZiiColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: netDue >= 0 ? IZiiColors.error.withOpacity(0.3) : IZiiColors.success.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('acc_bas_net_due'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${netDue < 0 ? '-' : ''}\$${netDue.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: netDue >= 0 ? IZiiColors.error : IZiiColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
