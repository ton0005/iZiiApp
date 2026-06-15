import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/izii_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/accountant_bloc.dart';

class PayrollPayrunScreen extends StatefulWidget {
  const PayrollPayrunScreen({super.key});

  @override
  State<PayrollPayrunScreen> createState() => _PayrollPayrunScreenState();
}

class _PayrollPayrunScreenState extends State<PayrollPayrunScreen> {
  // Payrun form keys & state
  final _payrunFormKey = GlobalKey<FormState>();
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 14));
  DateTime _periodEnd = DateTime.now();
  DateTime _paymentDate = DateTime.now();
  double _grossWages = 0.0;
  double _paygTax = 0.0;
  double _superAmount = 0.0;

  // ABA form keys & state
  final _abaFormKey = GlobalKey<FormState>();
  String _bankCode = 'CBA';
  String _supplierName = 'IZIIAPP PTY LTD';
  String _apcaNumber = '012345';
  final String _description = 'PAYROLL';
  String _sourceBsb = '062-900';
  String _sourceAcc = '123456789';

  // List of payees for ABA file
  final List<Map<String, dynamic>> _payees = [
    {
      'bsb': '012-345',
      'account_number': '987654321',
      'account_title': 'John Doe',
      'amount_dollars': 1250.00,
      'lodgement_reference': 'WAGES JOHN',
    },
    {
      'bsb': '062-001',
      'account_number': '112233445',
      'account_title': 'Jane Smith',
      'amount_dollars': 1480.00,
      'lodgement_reference': 'WAGES JANE',
    }
  ];

  @override
  void initState() {
    super.initState();
    context.read<AccountantBloc>().add(const LoadAccountantDataEvent());
  }

  void _showAddPayeeDialog() {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String bsb = '';
    String acc = '';
    double amt = 0.0;
    String ref = 'WAGES';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: IZiiColors.darkSurface.withValues(alpha: 0.9),
            title: const Text('Add Payee (Employee/Supplier)',
                style: TextStyle(color: Colors.white)),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          const InputDecoration(labelText: 'Payee Name'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                      onSaved: (v) => title = v ?? '',
                    ),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'BSB (e.g. 062-900)'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                      onSaved: (v) => bsb = v ?? '',
                    ),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          const InputDecoration(labelText: 'Account Number'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                      onSaved: (v) => acc = v ?? '',
                    ),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          const InputDecoration(labelText: 'Net Amount (AUD)'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                      onSaved: (v) => amt = double.tryParse(v ?? '') ?? 0.0,
                    ),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Reference'),
                      onSaved: (v) => ref = v ?? 'WAGES',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: IZiiColors.primary),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    formKey.currentState?.save();
                    setState(() {
                      _payees.add({
                        'bsb': bsb,
                        'account_number': acc,
                        'account_title': title,
                        'amount_dollars': amt,
                        'lodgement_reference': ref,
                      });
                    });
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _runStpPayrun() {
    if (!_payrunFormKey.currentState!.validate()) return;
    _payrunFormKey.currentState!.save();

    context.read<AccountantBloc>().add(
          SubmitPayrunEvent({
            'pay_period_start': _periodStart.toIso8601String(),
            'pay_period_end': _periodEnd.toIso8601String(),
            'payment_date': _paymentDate.toIso8601String(),
            'total_gross': _grossWages,
            'total_tax_withheld': _paygTax,
            'total_super': _superAmount,
          }),
        );
  }

  void _generateAbaFile() {
    if (!_abaFormKey.currentState!.validate()) return;
    _abaFormKey.currentState!.save();

    if (_payees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one payee for the ABA export'),
          backgroundColor: IZiiColors.error,
        ),
      );
      return;
    }

    context.read<AccountantBloc>().add(
          GenerateAbaFileEvent(
            userFinancialInstitution: _bankCode,
            userSupplyingFile: _supplierName,
            userApcaNumber: _apcaNumber,
            payDescription: _description,
            processDate: DateTime.now(),
            userBsb: _sourceBsb,
            userAccountNumber: _sourceAcc,
            payees: _payees,
          ),
        );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: IZiiColors.darkBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            context.tr('acc_payroll_title'),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            indicatorColor: IZiiColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: 'STP Payrun'),
              Tab(text: 'History'),
              Tab(text: 'ABA Bank Payments'),
            ],
          ),
        ),
        body: BlocConsumer<AccountantBloc, AccountantState>(
          listener: (context, state) {
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: IZiiColors.success,
                ),
              );
              if (state.abaFileContent != null) {
                _showAbaFileViewer(state.abaFileContent!);
              }
              context
                  .read<AccountantBloc>()
                  .add(const ClearAccountantStatusEvent());
            }
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: IZiiColors.error,
                ),
              );
              context
                  .read<AccountantBloc>()
                  .add(const ClearAccountantStatusEvent());
            }
          },
          builder: (context, state) {
            if (state.isLoading && state.payrollEvents.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: IZiiColors.primary),
              );
            }

            return TabBarView(
              children: [
                // Tab 1: Submit STP Payrun
                _buildNewPayrunTab(),
                // Tab 2: STP History
                _buildStpHistoryTab(state.payrollEvents),
                // Tab 3: Generate ABA Files
                _buildAbaFilesTab(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDatePickerRow(
      String label, DateTime currentVal, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: currentVal,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (selected != null) onChanged(selected);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Row(
              children: [
                Text(
                  _formatDate(currentVal),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today_rounded,
                    color: Colors.white54, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewPayrunTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _payrunFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IZiiColors.darkSurface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildDatePickerRow('Pay Period Start', _periodStart,
                      (d) => setState(() => _periodStart = d)),
                  const Divider(color: Colors.white12),
                  _buildDatePickerRow('Pay Period End', _periodEnd,
                      (d) => setState(() => _periodEnd = d)),
                  const Divider(color: Colors.white12),
                  _buildDatePickerRow('Payment Date', _paymentDate,
                      (d) => setState(() => _paymentDate = d)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('STP payroll values (STP Phase 2 schema mapping)',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IZiiColors.darkSurface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  // Gross Wages
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Total Gross Wages (W1)',
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0.0;
                      setState(() {
                        _grossWages = val;
                        // Calculate PAYG Withholding (rough estimate/tax table simple map)
                        _paygTax =
                            double.parse((val * 0.22).toStringAsFixed(2));
                        // 11% Superannuation (Mandatory SG Rate FY2024-25 / FY2025-26)
                        _superAmount =
                            double.parse((val * 0.11).toStringAsFixed(2));
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // PAYG Tax
                  TextFormField(
                    key: Key('payg_tax_$_paygTax'),
                    initialValue: _paygTax > 0 ? _paygTax.toString() : '',
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'PAYG Withholding (W2)',
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                    onSaved: (v) => _paygTax = double.tryParse(v ?? '') ?? 0.0,
                  ),
                  const SizedBox(height: 12),
                  // Super
                  TextFormField(
                    key: Key('super_$_superAmount'),
                    initialValue:
                        _superAmount > 0 ? _superAmount.toString() : '',
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Superannuation Guarantee (11%)',
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                    onSaved: (v) =>
                        _superAmount = double.tryParse(v ?? '') ?? 0.0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: IZiiColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _runStpPayrun,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_rounded),
                  SizedBox(width: 8),
                  Text('Submit STP to ATO',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildStpHistoryTab(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return const Center(
          child: Text('No historical payruns logged',
              style: TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, idx) {
        final ev = events[idx];
        return Card(
          color: IZiiColors.darkSurface.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              'Pay Date: ${_formatDate(DateTime.parse(ev['payment_date']))}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Period: ${_formatDate(DateTime.parse(ev['pay_period_start']))} - ${_formatDate(DateTime.parse(ev['pay_period_end']))}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: IZiiColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ATO Lodged',
                style: TextStyle(
                    color: IZiiColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHistoryRow('Gross Wages (W1)', ev['total_gross']),
                    _buildHistoryRow(
                        'PAYG Withholding (W2)', ev['total_tax_withheld']),
                    _buildHistoryRow('Superannuation', ev['total_super']),
                    const Divider(color: Colors.white12),
                    _buildHistoryRowStr('STP Lodgment Receipt',
                        ev['stp_receipt_number'] ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: (idx * 50).ms, duration: 300.ms)
            .slideY(begin: 0.05, end: 0);
      },
    );
  }

  Widget _buildHistoryRow(String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text('\$${(val as num).toDouble().toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHistoryRowStr(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(val,
              style: const TextStyle(
                  color: IZiiColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAbaFilesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _abaFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supplier details
            const Text('Supplier Banking Details (Type 0/Type 1 header)',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IZiiColors.darkSurface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _bankCode,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              labelText: 'Bank Code (e.g. CBA, NAB)'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                          onSaved: (v) => _bankCode = v ?? 'CBA',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _apcaNumber,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              labelText: 'APCA number (6 digits)'),
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.length != 6)
                              ? 'Must be 6 digits'
                              : null,
                          onSaved: (v) => _apcaNumber = v ?? '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _supplierName,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Supplying User Name'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                    onSaved: (v) => _supplierName = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _sourceBsb,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              const InputDecoration(labelText: 'Paying BSB'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                          onSaved: (v) => _sourceBsb = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _sourceAcc,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              labelText: 'Paying Account Number'),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                          onSaved: (v) => _sourceAcc = v ?? '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payee Employees & Suppliers',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                TextButton.icon(
                  onPressed: _showAddPayeeDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Payee'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payees list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _payees.length,
              itemBuilder: (context, idx) {
                final p = _payees[idx];
                return Dismissible(
                  key: Key(p['account_number'] + idx.toString()),
                  onDismissed: (direction) {
                    setState(() {
                      _payees.removeAt(idx);
                    });
                  },
                  background: Container(
                    color: IZiiColors.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: ListTile(
                      title: Text(p['account_title'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'BSB: ${p['bsb']} • Acc: ${p['account_number']} • Ref: ${p['lodgement_reference']}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11)),
                      trailing: Text(
                          '\$${p['amount_dollars'].toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: IZiiColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _generateAbaFile,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded),
                  SizedBox(width: 8),
                  Text('Generate ABA Bank Payment File',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  void _showAbaFileViewer(String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: IZiiColors.darkBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ABA File Output (120-char formatted)',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_all_rounded,
                            color: IZiiColors.primary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('ABA content copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
