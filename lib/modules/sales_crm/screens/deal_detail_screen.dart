import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/crm_bloc.dart';
import 'edit_lead_screen.dart';

class DealDetailScreen extends StatefulWidget {
  final Map<String, dynamic> deal;

  const DealDetailScreen({super.key, required this.deal});

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  Map<String, dynamic>? _lead;
  bool _loadingLead = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedLead();
  }

  Future<void> _loadLinkedLead() async {
    final leadId = widget.deal['lead_id'];
    if (leadId != null) {
      setState(() {
        _loadingLead = true;
      });
      try {
        final lead = await CrmRepository().getLeadById(leadId);
        if (mounted) {
          setState(() {
            _lead = lead;
            _loadingLead = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loadingLead = false;
          });
        }
      }
    }
  }

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'proposal':
        return Colors.blue;
      case 'negotiation':
        return Colors.orange;
      case 'closed_won':
        return Colors.green;
      case 'closed_lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStageLabel(String stage) {
    switch (stage) {
      case 'proposal':
        return context.tr('crm_status_proposal');
      case 'negotiation':
        return context.tr('crm_status_negotiation');
      case 'closed_won':
        return context.tr('crm_status_won');
      case 'closed_lost':
        return context.tr('crm_status_lost');
      default:
        return stage;
    }
  }

  Widget _buildStageStep(String step, String currentStage, String label) {
    final stages = ['proposal', 'negotiation', 'closed_won'];
    final currentIdx = stages.indexOf(currentStage);
    final stepIdx = stages.indexOf(step);

    final isCompleted = currentIdx >= stepIdx && currentStage != 'closed_lost';
    final isActive = currentStage == step;

    Color stepColor = Colors.grey;
    if (isActive) {
      stepColor = _getStageColor(currentStage);
    } else if (isCompleted) {
      stepColor = Colors.green;
    }

    if (currentStage == 'closed_lost' && step == 'closed_won') {
      stepColor = Colors.red;
      label = context.tr('crm_status_lost');
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: stepColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: stepColor,
                width: isActive ? 3 : 2,
              ),
            ),
            child: Icon(
              isCompleted && !isActive ? Icons.check : Icons.circle,
              size: 12,
              color: stepColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final contactName =
        deal['contact_name'] ?? context.tr('crm_deal_unknown_contact');
    final contactPhone = deal['contact_phone'];
    final amount = deal['amount'] ?? 0.0;
    final stage = deal['stage'] ?? 'proposal';
    final source = deal['source'] ?? 'direct';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('crm_deal_detail_title')),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deal Summary Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E293B),
                      const Color(0xFF0F172A).withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            deal['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _getStageColor(stage).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  _getStageColor(stage).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _getStageLabel(stage),
                            style: TextStyle(
                              color: _getStageColor(stage),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('crm_deal_amount'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Stage Progression Timeline
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('crm_deal_stage'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStageStep('proposal', stage,
                            context.tr('crm_status_proposal')),
                        Container(
                            height: 2, width: 20, color: Colors.grey.shade700),
                        _buildStageStep('negotiation', stage,
                            context.tr('crm_status_negotiation')),
                        Container(
                            height: 2, width: 20, color: Colors.grey.shade700),
                        _buildStageStep(
                            'closed_won', stage, context.tr('crm_status_won')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Contact Information
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('crm_info_customer_info'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF06B6D4),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(contactName),
                      subtitle:
                          contactPhone != null ? Text(contactPhone) : null,
                    ),
                    if (deal['expected_close_date'] != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '${context.tr('crm_deal_close_date')}: ${deal['expected_close_date'].toString().split('T')[0]}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.share, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '${context.tr('crm_source_label')}: ${source.toString().toUpperCase()}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Originating Lead Card
            if (widget.deal['lead_id'] != null) ...[
              Text(
                context.tr('crm_originating_lead'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _loadingLead
                      ? const Center(child: CircularProgressIndicator())
                      : _lead == null
                          ? Text(context.tr('crm_no_leads_found'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _lead!['title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _lead!['status']
                                                ?.toString()
                                                .toUpperCase() ??
                                            '',
                                        style: const TextStyle(
                                          color: Colors.purple,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_lead!['name'] != null)
                                  Text(
                                    '${context.tr('crm_customer_label')}: ${_lead!['name']}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditLeadScreen(lead: _lead!),
                                        ),
                                      );
                                      _loadLinkedLead();
                                    },
                                    icon: const Icon(Icons.arrow_forward),
                                    label: Text(context.tr('crm_view_lead')),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
