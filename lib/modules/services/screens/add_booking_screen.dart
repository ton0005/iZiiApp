import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../bloc/services_bloc.dart';

class AddBookingScreen extends StatefulWidget {
  const AddBookingScreen({super.key});

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _availableServices = [];
  Map<String, dynamic>? _selectedService;
  DateTime? _scheduledAt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final services = await ServiceModuleRepository().getServices();
    setState(() {
      _availableServices = services.where((s) => s['is_active'] == true).toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn dịch vụ')),
      );
      return;
    }
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên khách hàng không được để trống')),
      );
      return;
    }

    final data = {
      'id': const Uuid().v4(),
      'service_item_id': _selectedService!['id'],
      'customer_name': _customerNameController.text.trim(),
      'customer_phone': _customerPhoneController.text.trim().isNotEmpty ? _customerPhoneController.text.trim() : null,
      'scheduled_at': _scheduledAt?.toIso8601String(),
      'estimated_hours': _selectedService!['estimated_hours'],
      'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    };

    try {
      await ServiceModuleRepository().addBooking(data);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo đơn đặt dịch vụ!'), backgroundColor: Color(0xFF10B981)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFF43F5E), duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo đơn Đặt dịch vụ'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader('Chọn dịch vụ'),
                  const SizedBox(height: 12),

                  // Service selector
                  if (_availableServices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Chưa có dịch vụ nào. Vui lòng thêm dịch vụ trước.', textAlign: TextAlign.center),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedService?['id'],
                        hint: const Text('Chọn dịch vụ'),
                        items: _availableServices.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text('${s['name']} (${_formatPrice(s['hourly_rate'])} VNĐ/giờ)'),
                          );
                        }).toList(),
                        onChanged: (id) {
                          setState(() {
                            _selectedService = _availableServices.firstWhere((s) => s['id'] == id);
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.home_repair_service_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),

                  // Estimated cost preview
                  if (_selectedService != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ước tính chi phí', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatPrice(_selectedService!['hourly_rate'])} × ${_selectedService!['estimated_hours']} giờ = ${_formatPrice((_selectedService!['hourly_rate'] as num) * (_selectedService!['estimated_hours'] as num))} VNĐ',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  _buildSectionHeader('Thông tin khách hàng'),
                  const SizedBox(height: 12),
                  _buildTextField(_customerNameController, 'Tên khách hàng *', Icons.person_outline),
                  _buildTextField(_customerPhoneController, 'Số điện thoại', Icons.phone_outlined, keyboardType: TextInputType.phone),

                  const SizedBox(height: 8),
                  _buildSectionHeader('Lịch hẹn'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _scheduledAt != null
                                  ? '${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} - ${_scheduledAt!.hour}:${_scheduledAt!.minute.toString().padLeft(2, '0')}'
                                  : 'Chọn ngày & giờ hẹn (tùy chọn)',
                              style: TextStyle(
                                color: _scheduledAt != null ? null : Colors.grey,
                              ),
                            ),
                          ),
                          if (_scheduledAt != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _scheduledAt = null),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildTextField(_notesController, 'Ghi chú', Icons.notes_outlined, maxLines: 3),

                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller, keyboardType: keyboardType, maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
          filled: true, fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.check_circle_outline, size: 22),
        label: const Text('Tạo đơn đặt dịch vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
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
}
