import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../bloc/crm_bloc.dart';

class DealPipelineScreen extends StatelessWidget {
  const DealPipelineScreen({super.key});

  static const _stageLabels = {
    'proposal': 'Đề xuất',
    'negotiation': 'Đàm phán',
    'closed_won': 'Thắng',
    'closed_lost': 'Thua',
  };

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
              title: const Text('Deal Pipeline', style: TextStyle(fontWeight: FontWeight.bold)),
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
                for (final stage in _stageLabels.keys) {
                  grouped[stage] = [];
                }
                for (final deal in state.deals) {
                  grouped[deal['stage']]?.add(deal);
                }

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  children: _stageLabels.entries.map((entry) {
                    final stageKey = entry.key;
                    final stageTitle = entry.value;
                    final stageDeals = grouped[stageKey] ?? [];

                    return _PipelineColumn(
                      stageKey: stageKey,
                      title: stageTitle,
                      deals: stageDeals,
                      color: _stageColors[stageKey] ?? Colors.grey,
                    );
                  }).toList(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PipelineColumn extends StatefulWidget {
  final String stageKey;
  final String title;
  final List<Map<String, dynamic>> deals;
  final Color color;

  const _PipelineColumn({
    required this.stageKey,
    required this.title,
    required this.deals,
    required this.color,
  });

  @override
  State<_PipelineColumn> createState() => _PipelineColumnState();
}

class _PipelineColumnState extends State<_PipelineColumn> {
  bool _isDraggingOver = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => details.data['stage'] != widget.stageKey,
      onAcceptWithDetails: (details) {
        final deal = details.data;
        context.read<CrmBloc>().add(UpdateDealStageEvent(deal['id'], widget.stageKey));
        setState(() {
          _isDraggingOver = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật Deal sang cột "${widget.title}"'),
            backgroundColor: widget.color,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      onLeave: (data) {
        setState(() {
          _isDraggingOver = false;
        });
      },
      onMove: (details) {
        if (!_isDraggingOver && details.data['stage'] != widget.stageKey) {
          setState(() {
            _isDraggingOver = true;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size.width * 0.8,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isDraggingOver
                ? widget.color.withOpacity(0.08)
                : Theme.of(context).colorScheme.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isDraggingOver
                  ? widget.color
                  : Colors.grey.withValues(alpha: 0.15),
              width: _isDraggingOver ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.deals.length}',
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable list of cards
              Expanded(
                child: widget.deals.isEmpty
                    ? Center(
                        child: Text(
                          'Kéo thả deal vào đây',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.deals.length,
                        itemBuilder: (context, index) {
                          final deal = widget.deals[index];
                          return _DealDragCard(deal: deal, color: widget.color);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DealDragCard extends StatelessWidget {
  final Map<String, dynamic> deal;
  final Color color;

  const _DealDragCard({
    required this.deal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dealCard = Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.08)),
      ),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deal['title'] ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deal['contact_name'] ?? 'Không có tên',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (deal['lead_title'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.link_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deal['lead_title'] ?? '',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatCurrency(deal['amount'])}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.drag_indicator, color: Colors.grey[400], size: 20),
              ],
            ),
          ],
        ),
      ),
    );

    return LongPressDraggable<Map<String, dynamic>>(
      data: deal,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.72,
          child: Opacity(
            opacity: 0.9,
            child: Transform.scale(
              scale: 0.95,
              child: dealCard,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: dealCard,
      ),
      child: dealCard.animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount is num) {
      return '${amount.toStringAsFixed(0)} VNĐ';
    }
    return amount?.toString() ?? '0 VNĐ';
  }
}
