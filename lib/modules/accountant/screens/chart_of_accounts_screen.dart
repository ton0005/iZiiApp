import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/izii_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/accountant_bloc.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AccountantBloc>().add(const LoadAccountantDataEvent());
  }

  void _showAddAccountDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String code = '';
    String name = '';
    String category = 'Asset';
    String gstTaxCode = 'GST';
    double initialBalance = 0.0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: AlertDialog(
                backgroundColor: IZiiColors.darkSurface.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color:
                        IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                title: Text(
                  context.tr('acc_add_account'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Account Code
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText:
                                '${context.tr('acc_code')} (e.g. 1-1100)',
                            labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Required'
                              : null,
                          onSaved: (val) => code = val ?? '',
                        ),
                        const SizedBox(height: 12),
                        // Account Name
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.tr('acc_name'),
                            labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Required'
                              : null,
                          onSaved: (val) => name = val ?? '',
                        ),
                        const SizedBox(height: 12),
                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          dropdownColor: IZiiColors.darkSurface,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.tr('acc_category'),
                            labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          items: [
                            'Asset',
                            'Liability',
                            'Equity',
                            'Revenue',
                            'COGS',
                            'Expense'
                          ]
                              .map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => category = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Tax Code Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: gstTaxCode,
                          dropdownColor: IZiiColors.darkSurface,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.tr('acc_gst_tax_code'),
                            labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          items: ['GST', 'FRE', 'ITS', 'EXM']
                              .map((code) => DropdownMenuItem(
                                    value: code,
                                    child: Text(code),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => gstTaxCode = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Initial Balance
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '${context.tr('acc_balance')} (AUD)',
                            labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (val) => initialBalance =
                              double.tryParse(val ?? '') ?? 0.0,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      context.tr('cancel'),
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IZiiColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        formKey.currentState?.save();
                        context.read<AccountantBloc>().add(
                              AddAccountEvent({
                                'code': code,
                                'name': name,
                                'category': category,
                                'gst_tax_code': gstTaxCode,
                                'balance': initialBalance,
                              }),
                            );
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Text(
                      context.tr('save'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IZiiColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.tr('acc_action_coa'),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: IZiiColors.primary,
        onPressed: () => _showAddAccountDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(context.tr('acc_add_account'),
            style: const TextStyle(color: Colors.white)),
      ).animate().scale(delay: 200.ms, duration: 400.ms),
      body: BlocConsumer<AccountantBloc, AccountantState>(
        listener: (context, state) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: IZiiColors.success,
              ),
            );
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
          if (state.isLoading && state.accounts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: IZiiColors.primary),
            );
          }

          // Group accounts by category
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final acc in state.accounts) {
            final cat = acc['category'] as String;
            grouped.putIfAbsent(cat, () => []).add(acc);
          }

          final categories = [
            'Asset',
            'Liability',
            'Equity',
            'Revenue',
            'COGS',
            'Expense'
          ];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final list = grouped[cat] ?? [];
              if (list.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: IZiiColors.darkSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        IZiiColors.darkSurfaceHighlight.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: ExpansionTile(
                  initiallyExpanded: idx == 0,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cat,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: IZiiColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${list.length} accounts',
                          style: const TextStyle(
                            fontSize: 12,
                            color: IZiiColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (context, itemIdx) {
                        final acc = list[itemIdx];
                        final double bal = (acc['balance'] as num).toDouble();

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: IZiiColors.darkSurfaceHighlight
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                acc['code'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              acc['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  acc['gst_tax_code'],
                                  style: TextStyle(
                                    color: acc['gst_tax_code'] == 'GST'
                                        ? IZiiColors.accent
                                        : Colors.white.withValues(alpha: 0.3),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              '\$${bal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                color:
                                    bal >= 0 ? Colors.white : IZiiColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: (idx * 50).ms, duration: 400.ms)
                  .slideY(begin: 0.05, end: 0);
            },
          );
        },
      ),
    );
  }
}
