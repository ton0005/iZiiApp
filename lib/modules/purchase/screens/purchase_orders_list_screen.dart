import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/purchase_bloc.dart';

class PurchaseOrdersListScreen extends StatefulWidget {
  const PurchaseOrdersListScreen({super.key});

  @override
  State<PurchaseOrdersListScreen> createState() => _PurchaseOrdersListScreenState();
}

class _PurchaseOrdersListScreenState extends State<PurchaseOrdersListScreen> {
  static const _statusColors = {
    'draft': Color(0xFF94A3B8),
    'sent': Color(0xFF3B82F6),
    'approved': Color(0xFF8B5CF6),
    'received': Color(0xFF10B981),
    'cancelled': Color(0xFFF43F5E),
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PurchaseBloc()..add(LoadPurchaseOrdersEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('purchase_orders_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
            ),
          ),
        ),
        body: BlocBuilder<PurchaseBloc, PurchaseState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.error != null) {
              return Center(child: Text('${context.tr('error')}: ${state.error}'));
            }

            if (state.purchaseOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(context.tr('purchase_no_orders'), style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await context.push<bool>('/purchase/create');
                        if (result == true && context.mounted) {
                          context.read<PurchaseBloc>().add(LoadPurchaseOrdersEvent());
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('purchase_create_title')),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.purchaseOrders.length,
              itemBuilder: (context, index) {
                final order = state.purchaseOrders[index];
                final status = order['status'] as String? ?? 'draft';
                final statusColor = _statusColors[status] ?? Colors.grey;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showOrderDetailDialog(context, order),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order['order_number'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (newStatus) {
                                  context.read<PurchaseBloc>().add(UpdatePurchaseOrderStatusEvent(order['id'], newStatus));
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'draft', child: Text(context.tr('purchase_status_draft'))),
                                  PopupMenuItem(value: 'sent', child: Text(context.tr('purchase_status_sent'))),
                                  PopupMenuItem(value: 'approved', child: Text(context.tr('purchase_status_approved'))),
                                  PopupMenuItem(value: 'received', child: Text(context.tr('purchase_status_received'))),
                                  PopupMenuItem(value: 'cancelled', child: Text(context.tr('purchase_status_cancelled'))),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getStatusLabel(status, context),
                                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_drop_down, color: statusColor, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _infoRow(Icons.business, context.tr('purchase_partner_label'), order['partner_name'] ?? ''),
                          _infoRow(Icons.calendar_today, context.tr('ser_booking_appointment'), _formatDate(order['order_date'])),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${order['lines']?.length ?? 0} ${context.tr('supply_action_products').toLowerCase()}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              Text(
                                '${_formatPrice(order['total_amount'])} VNĐ',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.08, end: 0);
              },
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              heroTag: 'add_purchase_order',
              onPressed: () async {
                final result = await context.push<bool>('/purchase/create');
                if (result == true && context.mounted) {
                  context.read<PurchaseBloc>().add(LoadPurchaseOrdersEvent());
                }
              },
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          }
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _getStatusLabel(String status, BuildContext context) {
    switch (status) {
      case 'draft':
        return context.tr('purchase_status_draft');
      case 'sent':
        return context.tr('purchase_status_sent');
      case 'approved':
        return context.tr('purchase_status_approved');
      case 'received':
        return context.tr('purchase_status_received');
      case 'cancelled':
        return context.tr('purchase_status_cancelled');
      default:
        return status;
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      return price.toStringAsFixed(0);
    }
    return price.toString();
  }

  void _showOrderDetailDialog(BuildContext context, Map<String, dynamic> order) {
    final lines = order['lines'] as List? ?? [];
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${context.tr('purchase_orders_title')}: ${order['order_number']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${context.tr('purchase_partner_label')}: ${order['partner_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lines.length,
                  itemBuilder: (context, idx) {
                    final line = lines[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line['product_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                Text('${context.tr('inv_stock_quantity')}: ${line['quantity']} × ${_formatPrice(line['unit_price'])} VNĐ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text('${_formatPrice(line['total_price'])} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${_formatPrice(order['total_amount'])} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Đóng')),
        ],
      ),
    );
  }
}
