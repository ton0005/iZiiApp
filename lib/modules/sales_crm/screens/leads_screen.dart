import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/crm_bloc.dart';
import 'add_lead_screen.dart';
import 'edit_lead_screen.dart';
import 'deal_detail_screen.dart';

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrmBloc()..add(LoadLeadsEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('crm_leads_management')),
          actions: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final result = await Navigator.of(ctx).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const AddLeadScreen(),
                    ),
                  );
                  if (result == true && ctx.mounted) {
                    ctx.read<CrmBloc>().add(LoadLeadsEvent());
                  }
                },
              ),
            ),
          ],
        ),
        body: BlocBuilder<CrmBloc, CrmState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(
                child: Text(
                  context.tr('crm_lead_load_error').replaceAll('{error}', state.error!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (state.leads.isEmpty) {
              return Center(child: Text(context.tr('crm_no_leads_found')));
            }
            return ListView.builder(
              itemCount: state.leads.length,
              itemBuilder: (context, index) {
                final lead = state.leads[index] as Map<String, dynamic>;
                final customFields =
                    lead['custom_fields'] as Map<String, dynamic>? ?? {};

                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF6366F1)),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lead['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (lead['deal_id'] != null)
                        IconButton(
                          icon: const Icon(Icons.link, color: Color(0xFF06B6D4), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            final deal = {
                              'id': lead['deal_id'],
                              'title': lead['deal_title'] ?? lead['title'],
                              'amount': lead['deal_amount'],
                              'stage': lead['deal_stage'],
                              'expected_close_date': lead['deal_expected_close_date'],
                              'contact_id': lead['deal_contact_id'],
                              'source': lead['deal_source'],
                              'owner_id': lead['deal_owner_id'],
                              'lead_id': lead['id'],
                            };
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DealDetailScreen(deal: deal),
                              ),
                            ).then((_) {
                              context.read<CrmBloc>().add(LoadLeadsEvent());
                            });
                          },
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${context.tr('crm_customer_label')}: ${lead['name'] ?? context.tr('crm_deal_no_name')}'),
                      Text(
                        context.tr('crm_expected_value').replaceAll('{value}', lead['expected_revenue'].toString()),
                        style: const TextStyle(color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(lead['created_at']),
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                      if (customFields.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: customFields.entries.map((entry) {
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                '${entry.key}: ${entry.value}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: customFields.isEmpty,
                  trailing: PopupMenuButton<String>(
                    onSelected: (newStatus) {
                      context.read<CrmBloc>().add(
                            UpdateLeadStatusEvent(lead['id'], newStatus),
                          );
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: 'new', child: Text('🆕 ${context.tr('crm_status_new')}')),
                      PopupMenuItem(
                          value: 'qualified',
                          child: Text('💎 ${context.tr('crm_status_qualified')}')),
                      PopupMenuItem(
                          value: 'won', child: Text('✅ ${context.tr('crm_status_won')}')),
                      PopupMenuItem(
                          value: 'lost', child: Text('❌ ${context.tr('crm_status_lost')}')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(lead['status'])
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getStatusColor(lead['status'])
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getStatusLabel(lead['status'], context),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(lead['status']),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down,
                              size: 16, color: _getStatusColor(lead['status'])),
                        ],
                      ),
                    ),
                  ),
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EditLeadScreen(lead: lead),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.read<CrmBloc>().add(LoadLeadsEvent());
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.blue;
      case 'qualified':
        return Colors.purple;
      case 'won':
        return Colors.green;
      case 'lost':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusLabel(String status, BuildContext context) {
    switch (status) {
      case 'new':
        return context.tr('crm_status_new');
      case 'qualified':
        return context.tr('crm_status_qualified');
      case 'won':
        return context.tr('crm_status_won');
      case 'lost':
        return context.tr('crm_status_lost');
      default:
        if (status == 'Khách hàng mới') return context.tr('crm_status_new');
        if (status == 'Đang đàm phán') return context.tr('crm_status_negotiation');
        if (status == 'Chốt đơn') return context.tr('crm_status_won');
        if (status == 'Huỷ') return context.tr('crm_status_cancelled');
        return status;
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
