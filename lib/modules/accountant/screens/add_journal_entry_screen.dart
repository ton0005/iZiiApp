import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/izii_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/accountant_bloc.dart';

class AddJournalEntryScreen extends StatefulWidget {
  const AddJournalEntryScreen({super.key});

  @override
  State<AddJournalEntryScreen> createState() => _AddJournalEntryScreenState();
}

class _AddJournalEntryScreenState extends State<AddJournalEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _entryDate = DateTime.now();
  final _referenceController = TextEditingController();
  final _narrationController = TextEditingController();

  // Journal lines state
  final List<Map<String, dynamic>> _lines = [];

  @override
  void initState() {
    super.initState();
    context.read<AccountantBloc>().add(const LoadAccountantDataEvent());
    // Add two blank lines initially
    _addNewLine();
    _addNewLine();
  }

  void _addNewLine() {
    setState(() {
      _lines.add({
        'account_id': null,
        'debit': 0.0,
        'credit': 0.0,
        'gst_tax_code': 'GST',
        'gst_amount': 0.0,
      });
    });
  }

  void _removeLine(int idx) {
    if (_lines.length <= 2) return; // Keep at least 2 lines
    setState(() {
      _lines.removeAt(idx);
    });
  }

  void _recalculateGst(int idx) {
    final line = _lines[idx];
    final taxCode = line['gst_tax_code'] as String;
    final debit = line['debit'] as double;
    final credit = line['credit'] as double;
    final double amount = debit > 0 ? debit : credit;

    if (taxCode == 'GST') {
      // 1/11th inclusive calculation
      setState(() {
        _lines[idx]['gst_amount'] = double.parse((amount / 11).toStringAsFixed(4));
      });
    } else {
      setState(() {
        _lines[idx]['gst_amount'] = 0.0;
      });
    }
  }

  double get _totalDebits => _lines.fold(0.0, (sum, l) => sum + (l['debit'] as double));
  double get _totalCredits => _lines.fold(0.0, (sum, l) => sum + (l['credit'] as double));
  double get _difference => (_totalDebits - _totalCredits).abs();

  void _postEntry() {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate that at least some accounts are selected
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i]['account_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select an account for line ${i + 1}'),
            backgroundColor: IZiiColors.error,
          ),
        );
        return;
      }
    }

    if (_difference > 0.009) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('acc_error_unbalanced')),
          backgroundColor: IZiiColors.error,
        ),
      );
      return;
    }

    context.read<AccountantBloc>().add(
      AddJournalEntryEvent({
        'entry_date': _entryDate.toIso8601String(),
        'reference': _referenceController.text.isEmpty ? null : _referenceController.text,
        'narration': _narrationController.text.isEmpty ? null : _narrationController.text,
        'lines': _lines,
      }),
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IZiiColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.tr('acc_add_journal_entry'),
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
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            onPressed: _postEntry,
          ),
        ],
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
            context.read<AccountantBloc>().add(const ClearAccountantStatusEvent());
            Navigator.pop(context);
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: IZiiColors.error,
              ),
            );
            context.read<AccountantBloc>().add(const ClearAccountantStatusEvent());
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.accounts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: IZiiColors.primary),
            );
          }

          final accounts = state.accounts;

          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Header Information ---
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: IZiiColors.darkSurface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: IZiiColors.darkSurfaceHighlight.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Date Selector
                              InkWell(
                                onTap: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: _entryDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (selected != null) {
                                    setState(() => _entryDate = selected);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: context.tr('acc_entry_date'),
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                    border: InputBorder.none,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${_entryDate.day.toString().padLeft(2, '0')}/${_entryDate.month.toString().padLeft(2, '0')}/${_entryDate.year}',
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                      const Icon(Icons.calendar_today_rounded, color: Colors.white70),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(color: Colors.white12),
                              // Reference
                              TextFormField(
                                controller: _referenceController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: context.tr('acc_reference'),
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  border: InputBorder.none,
                                ),
                              ),
                              const Divider(color: Colors.white12),
                              // Narration
                              TextFormField(
                                controller: _narrationController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: context.tr('acc_narration'),
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Transaction Lines Title ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Lines',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addNewLine,
                              icon: const Icon(Icons.add_rounded, color: IZiiColors.primary),
                              label: Text(
                                context.tr('acc_add_line'),
                                style: const TextStyle(color: IZiiColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // --- Dynamic Lines ---
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lines.length,
                          itemBuilder: (context, idx) {
                            final line = _lines[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: IZiiColors.darkSurface.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Line ${idx + 1}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_lines.length > 2)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded,
                                              color: IZiiColors.error, size: 20),
                                          onPressed: () => _removeLine(idx),
                                        ),
                                    ],
                                  ),
                                  // Account dropdown
                                  DropdownButtonFormField<String>(
                                    value: line['account_id'],
                                    dropdownColor: IZiiColors.darkSurface,
                                    style: const TextStyle(color: Colors.white),
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: context.tr('acc_category'),
                                      labelStyle:
                                          TextStyle(color: Colors.white.withOpacity(0.4)),
                                      border: InputBorder.none,
                                    ),
                                    items: accounts.map((acc) {
                                      return DropdownMenuItem<String>(
                                        value: acc['id'],
                                        child: Text(
                                          '[${acc['code']}] ${acc['name']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _lines[idx]['account_id'] = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Debit Field
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: line['debit'] > 0
                                              ? line['debit'].toString()
                                              : '',
                                          style: const TextStyle(color: Colors.white),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: context.tr('acc_debit'),
                                            labelStyle: TextStyle(
                                                color: Colors.white.withOpacity(0.4)),
                                            prefixText: '\$ ',
                                            prefixStyle: const TextStyle(color: Colors.white),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _lines[idx]['debit'] =
                                                  double.tryParse(val) ?? 0.0;
                                              if (_lines[idx]['debit'] > 0) {
                                                _lines[idx]['credit'] = 0.0;
                                              }
                                            });
                                            _recalculateGst(idx);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Credit Field
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: line['credit'] > 0
                                              ? line['credit'].toString()
                                              : '',
                                          style: const TextStyle(color: Colors.white),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: context.tr('acc_credit'),
                                            labelStyle: TextStyle(
                                                color: Colors.white.withOpacity(0.4)),
                                            prefixText: '\$ ',
                                            prefixStyle: const TextStyle(color: Colors.white),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _lines[idx]['credit'] =
                                                  double.tryParse(val) ?? 0.0;
                                              if (_lines[idx]['credit'] > 0) {
                                                _lines[idx]['debit'] = 0.0;
                                              }
                                            });
                                            _recalculateGst(idx);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // GST Code dropdown
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: line['gst_tax_code'],
                                          dropdownColor: IZiiColors.darkSurface,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            labelText: context.tr('acc_gst_tax_code'),
                                            labelStyle: TextStyle(
                                                color: Colors.white.withOpacity(0.4)),
                                            border: InputBorder.none,
                                          ),
                                          items: ['GST', 'FRE', 'ITS', 'EXM']
                                              .map((tax) => DropdownMenuItem(
                                                    value: tax,
                                                    child: Text(tax),
                                                  ))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _lines[idx]['gst_tax_code'] = val;
                                              });
                                              _recalculateGst(idx);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // GST Amount Field (Calculated)
                                      Expanded(
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: context.tr('acc_gst_amount'),
                                            labelStyle: TextStyle(
                                                color: Colors.white.withOpacity(0.4)),
                                            border: InputBorder.none,
                                          ),
                                          child: Text(
                                            '\$ ${(line['gst_amount'] as double).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Footer Running Balancer ---
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: IZiiColors.darkSurface.withOpacity(0.8),
                        border: Border(
                          top: BorderSide(
                            color: IZiiColors.darkSurfaceHighlight.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Debits',
                                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text('\$${_totalDebits.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Credits',
                                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text('\$${_totalCredits.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Out of Balance',
                                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text(
                                      '\$${_difference.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: _difference < 0.009
                                            ? IZiiColors.success
                                            : IZiiColors.error,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _difference < 0.009
                                    ? IZiiColors.primary
                                    : Colors.white10,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _difference < 0.009 ? _postEntry : null,
                              child: Text(
                                context.tr('acc_save_entry'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
