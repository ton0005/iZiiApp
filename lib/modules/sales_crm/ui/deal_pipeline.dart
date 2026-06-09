import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/responsive_kanban_board.dart';
import '../bloc/crm_bloc.dart';
import '../screens/deal_detail_screen.dart';
import '../screens/edit_lead_screen.dart';

class DealPipelineScreen extends StatelessWidget {
  const DealPipelineScreen({super.key});

  static const _stages = ['proposal', 'negotiation', 'closed_won', 'closed_lost'];

  static const _stageColors = {
    'proposal': Color(0xFF3B82F6), // Blue
    'negotiation': Color(0xFF8B5CF6), // Purple
    'closed_won': Color(0xFF10B981), // Emerald Green
    'closed_lost': Color(0xFFEF4444), // Red
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrmBloc()..add(LoadDealsEvent()),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.tr('crm_deal_pipeline_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<CrmBloc>().add(LoadDealsEvent());
                  },
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
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Lỗi tải dữ liệu: ${state.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  );
                }

                // Group deals by stage
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final stage in _stages) {
                  grouped[stage] = [];
                }
                for (final deal in state.deals) {
                  final s = deal['stage'] as String? ?? 'proposal';
                  grouped[s]?.add(deal);
                }

                return ResponsiveKanbanBoard<Map<String, dynamic>>(
                  laneKeys: _stages,
                  laneTitle: (key, ctx) => _getStageLabel(key, ctx),
                  laneColor: (key) => _stageColors[key] ?? Colors.grey,
                  groupedData: grouped,
                  itemKey: (deal) => deal['id']?.toString() ?? '',
                  itemLane: (deal) => deal['stage']?.toString() ?? 'proposal',
                  emptyLaneHint: context.tr('crm_deal_pipeline_drag_hint'),
                  onItemMoved: (deal, newStage) {
                    context.read<CrmBloc>().add(UpdateDealStageEvent(deal['id'], newStage));
                    final stageTitle = _getStageLabel(newStage, context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('crm_deal_pipeline_updated').replaceAll('{stage}', stageTitle)),
                        backgroundColor: _stageColors[newStage] ?? Colors.grey,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  cardBuilder: (ctx, deal, laneColor, mode, dragHandle) {
                    return _buildDealCard(ctx, deal, laneColor, mode, dragHandle);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _getStageLabel(String stage, BuildContext context) {
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

  Widget _buildDealCard(
    BuildContext context,
    Map<String, dynamic> deal,
    Color laneColor,
    KanbanLayoutMode mode,
    Widget dragHandle,
  ) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DealDetailScreen(deal: deal),
          ),
        );
        if (context.mounted) {
          context.read<CrmBloc>().add(LoadDealsEvent());
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.08)),
        ),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      deal['title'] ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  dragHandle,
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deal['contact_name'] ?? context.tr('crm_deal_unknown_contact'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatDate(deal['created_at']),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (deal['lead_title'] != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final leadId = deal['lead_id'];
                    if (leadId != null) {
                      final lead = await CrmRepository().getLeadById(leadId);
                      if (lead != null && context.mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditLeadScreen(lead: lead),
                          ),
                        );
                        if (context.mounted) {
                          context.read<CrmBloc>().add(LoadDealsEvent());
                        }
                      }
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          deal['lead_title'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _formatCurrency(deal['amount']),
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount is num) {
      return '${amount.toStringAsFixed(0)} VNĐ';
    }
    return amount?.toString() ?? '0 VNĐ';
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
