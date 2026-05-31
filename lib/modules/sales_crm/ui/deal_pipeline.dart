import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';

class DealPipelineScreen extends StatefulWidget {
  const DealPipelineScreen({super.key});

  @override
  State<DealPipelineScreen> createState() => _DealPipelineScreenState();
}

class _DealPipelineScreenState extends State<DealPipelineScreen> {
  final AppDatabase _db = AppDatabase();
  late Future<List<Map<String, dynamic>>> _dealsFuture;

  static const _stageLabels = {
    'proposal': 'Đề xuất',
    'negotiation': 'Đàm phán',
    'closed_won': 'Thắng',
    'closed_lost': 'Thua',
  };

  @override
  void initState() {
    super.initState();
    _dealsFuture = _loadDeals();
  }

  Future<List<Map<String, dynamic>>> _loadDeals() async {
    final query = _db.select(_db.deals).join([
      leftOuterJoin(_db.leads, _db.leads.id.equalsExp(_db.deals.leadId)),
      leftOuterJoin(
          _db.contacts, _db.contacts.id.equalsExp(_db.deals.contactId)),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      final deal = row.readTable(_db.deals);
      final lead = row.readTableOrNull(_db.leads);
      final contact = row.readTableOrNull(_db.contacts);
      return {
        'id': deal.id,
        'title': deal.title,
        'stage': deal.stage,
        'amount': deal.amount,
        'expected_close_date': deal.expectedCloseDate?.toIso8601String(),
        'lead_title': lead?.title ?? 'Không có lead',
        'contact_name': contact?.name ?? 'Không có khách hàng',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deal Pipeline'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          final deals = snapshot.data ?? [];
          if (deals.isEmpty) {
            return const Center(child: Text('Chưa có deal nào.'));
          }

          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final stage in _stageLabels.keys) {
            grouped[stage] = [];
          }
          for (final deal in deals) {
            grouped[deal['stage']]?.add(deal);
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _stageLabels.entries.map((entry) {
                final stage = entry.key;
                final stageDeals = grouped[stage] ?? [];
                return Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.value,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${stageDeals.length} deals',
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 14),
                      if (stageDeals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('Không có deal trong giai đoạn này.'),
                        )
                      else
                        ...stageDeals.map((deal) => _buildDealCard(deal)),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.refresh),
        label: const Text('Làm mới'),
        onPressed: () => setState(() => _dealsFuture = _loadDeals()),
      ),
    );
  }

  Widget _buildDealCard(Map<String, dynamic> deal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deal['title'] ?? '',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Khách hàng: ${deal['contact_name']}',
                style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 4),
            Text('Lead: ${deal['lead_title']}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Giá trị: ${_formatCurrency(deal['amount'])}',
                    style: const TextStyle(color: Colors.green)),
                Text(
                    deal['expected_close_date'] != null
                        ? 'Đóng: ${deal['expected_close_date'].split('T').first}'
                        : 'Chưa có ngày',
                    style: const TextStyle(color: Colors.blueGrey)),
              ],
            ),
          ],
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
}
