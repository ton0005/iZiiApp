import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../bloc/services_bloc.dart';
import 'add_booking_screen.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ServicesBloc()..add(LoadBookingsEvent()),
      child: const _BookingsBody(),
    );
  }
}

class _BookingsBody extends StatefulWidget {
  const _BookingsBody();

  @override
  State<_BookingsBody> createState() => _BookingsBodyState();
}

class _BookingsBodyState extends State<_BookingsBody> {
  String _statusFilter = 'all';

  static const _statusLabels = {
    'all': 'Tất cả',
    'pending': 'Chờ xác nhận',
    'confirmed': 'Đã xác nhận',
    'in_progress': 'Đang thực hiện',
    'completed': 'Hoàn thành',
    'cancelled': 'Đã huỷ',
  };

  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
    'confirmed': Color(0xFF3B82F6),
    'in_progress': Color(0xFF8B5CF6),
    'completed': Color(0xFF10B981),
    'cancelled': Color(0xFFF43F5E),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn đặt Dịch vụ', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
          ),
        ),
      ),
      body: Column(
        children: [
          // Status filter
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _statusLabels.entries.map((entry) {
                  final isSelected = _statusFilter == entry.key;
                  final color = entry.key == 'all' ? const Color(0xFF8B5CF6) : (_statusColors[entry.key] ?? Colors.grey);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(entry.value),
                      selectedColor: color.withValues(alpha: 0.2),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: isSelected ? color : theme.textTheme.bodyMedium?.color,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      side: BorderSide(color: isSelected ? color : theme.dividerColor.withValues(alpha: 0.3)),
                      onSelected: (_) => setState(() => _statusFilter = entry.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: BlocBuilder<ServicesBloc, ServicesState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _statusFilter == 'all'
                    ? state.bookings
                    : state.bookings.where((b) => b['status'] == _statusFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Chưa có đơn đặt dịch vụ', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Nhấn nút + để tạo đơn mới', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final booking = filtered[index];
                    return _BookingCard(
                      booking: booking,
                      onStatusChange: (newStatus, {double? hours}) async {
                        await ServiceModuleRepository().updateBookingStatus(booking['id'], newStatus, actualHours: hours);
                        if (context.mounted) context.read<ServicesBloc>().add(LoadBookingsEvent());
                      },
                    ).animate().fadeIn(delay: (index * 50).ms, duration: 300.ms).slideX(begin: 0.05, end: 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_booking',
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddBookingScreen()),
          );
          if (result == true && context.mounted) {
            context.read<ServicesBloc>().add(LoadBookingsEvent());
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo đơn', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Future<void> Function(String status, {double? hours}) onStatusChange;

  const _BookingCard({required this.booking, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = booking['status'] as String? ?? 'pending';
    final statusColor = _BookingsBodyState._statusColors[status] ?? Colors.grey;
    final statusLabel = _BookingsBodyState._statusLabels[status] ?? status;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking['service_name'] ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.person_outline, 'Khách hàng', booking['customer_name'] ?? ''),
            if ((booking['customer_phone'] ?? '').isNotEmpty)
              _infoRow(Icons.phone_outlined, 'SĐT', booking['customer_phone']),
            if (booking['scheduled_at'] != null)
              _infoRow(Icons.schedule, 'Lịch hẹn', _formatDateTime(booking['scheduled_at'])),
            _infoRow(Icons.attach_money, 'Thành tiền', '${_formatPrice(booking['total_amount'])} VNĐ'),
            if (booking['actual_hours'] != null)
              _infoRow(Icons.timer, 'Giờ thực tế', '${booking['actual_hours']} giờ'),

            // Action buttons based on status
            if (status != 'completed' && status != 'cancelled') ...[
              const Divider(height: 20),
              _buildActionButtons(context, status),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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

  Widget _buildActionButtons(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onStatusChange('cancelled'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
                child: const Text('Huỷ'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => onStatusChange('confirmed'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                child: const Text('Xác nhận'),
              ),
            ),
          ],
        );
      case 'confirmed':
        return ElevatedButton.icon(
          onPressed: () => onStatusChange('in_progress'),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Bắt đầu thực hiện'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
        );
      case 'in_progress':
        return ElevatedButton.icon(
          onPressed: () => _showCompleteDialog(context),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Hoàn thành'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showCompleteDialog(BuildContext context) {
    final hoursController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoàn thành dịch vụ'),
        content: TextField(
          controller: hoursController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số giờ thực tế',
            hintText: 'VD: 2.5',
            prefixIcon: Icon(Icons.timer),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              final hours = double.tryParse(hoursController.text);
              Navigator.pop(ctx);
              onStatusChange('completed', hours: hours);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
      if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
      return price.toStringAsFixed(0);
    }
    return '0';
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
