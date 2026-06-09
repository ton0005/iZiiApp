import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/crm_bloc.dart';
import '../ui/lead_form.dart';
import 'deal_detail_screen.dart';

class EditLeadScreen extends StatefulWidget {
  final Map<String, dynamic> lead;

  const EditLeadScreen({super.key, required this.lead});

  @override
  State<EditLeadScreen> createState() => _EditLeadScreenState();
}

class _EditLeadScreenState extends State<EditLeadScreen> {
  Map<String, dynamic>? _linkedDeal;
  bool _loadingDeal = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedDeal();
  }

  Future<void> _loadLinkedDeal() async {
    setState(() {
      _loadingDeal = true;
    });
    try {
      final deal = await CrmRepository().getDealByLeadId(widget.lead['id']);
      if (mounted) {
        setState(() {
          _linkedDeal = deal;
          _loadingDeal = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDeal = false;
        });
      }
    }
  }

  Future<void> _convertToDeal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('crm_convert_to_deal')),
        content: Text(context.tr('crm_convert_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _loadingDeal = true;
      });
      try {
        await CrmRepository().convertLeadToDeal(widget.lead['id']);
        await _loadLinkedDeal();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('crm_converted_success')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _loadingDeal = false;
          });
        }
      }
    }
  }

  Future<void> _saveLead(Map<String, dynamic> values) async {
    final updatedLead = {
      ...widget.lead,
      ...values,
      'custom_fields':
          widget.lead['custom_fields'] ?? values['custom_fields'] ?? {},
    };

    await CrmRepository().updateLeadFull(updatedLead);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context
            .tr('crm_customer_updated')
            .replaceAll('{name}', updatedLead['name'] ?? '')),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('crm_edit_customer')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_loadingDeal)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              )
            else if (_linkedDeal != null)
              Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('crm_linked_deal'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF06B6D4),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _linkedDeal!['stage']?.toString().toUpperCase() ??
                                  '',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _linkedDeal!['title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${context.tr('crm_deal_amount')}: \$${(_linkedDeal!['amount'] ?? 0.0).toStringAsFixed(2)}',
                        style:
                            const TextStyle(color: Colors.green, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DealDetailScreen(deal: _linkedDeal!),
                              ),
                            );
                            _loadLinkedDeal();
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(context.tr('crm_view_deal')),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(context.tr('crm_no_linked_deal')),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _convertToDeal,
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(context.tr('crm_convert_to_deal')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            LeadForm(
              initialLead: widget.lead,
              submitLabel: context.tr('crm_update_lead'),
              onSave: _saveLead,
            ),
          ],
        ),
      ),
    );
  }
}
