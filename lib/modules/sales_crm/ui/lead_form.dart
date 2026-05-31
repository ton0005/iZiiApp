import 'package:flutter/material.dart';

class LeadForm extends StatefulWidget {
  final Map<String, dynamic>? initialLead;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final String submitLabel;

  const LeadForm({
    super.key,
    this.initialLead,
    required this.onSave,
    this.submitLabel = 'Lưu Lead',
  });

  @override
  State<LeadForm> createState() => _LeadFormState();
}

class _LeadFormState extends State<LeadForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _revenueController;
  late String _status;

  final List<String> _statuses = [
    'Khách hàng mới',
    'Đang đàm phán',
    'Chốt đơn',
    'Huỷ',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLead ?? {};
    _nameController =
        TextEditingController(text: initial['name']?.toString() ?? '');
    _titleController =
        TextEditingController(text: initial['title']?.toString() ?? '');
    _revenueController = TextEditingController(
        text: initial['expected_revenue']?.toString() ?? '0');
    final currentStatus = initial['status']?.toString() ?? _statuses.first;
    _status =
        _statuses.contains(currentStatus) ? currentStatus : _statuses.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _revenueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final revenue = double.tryParse(
            _revenueController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
    final formData = {
      ...?widget.initialLead,
      'name': _nameController.text.trim(),
      'title': _titleController.text.trim().isEmpty
          ? 'Khách hàng: ${_nameController.text.trim()}'
          : _titleController.text.trim(),
      'status': _status,
      'expected_revenue': revenue,
      'custom_fields': widget.initialLead?['custom_fields'] ?? {},
    };

    await widget.onSave(formData);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Thông tin Khách hàng'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _nameController,
            label: 'Tên khách hàng',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Tên khách hàng không được để trống';
              }
              return null;
            },
          ),
          _buildTextField(
            controller: _titleController,
            label: 'Nhu cầu / Ghi chú',
            icon: Icons.description_outlined,
            validator: (value) {
              return null;
            },
            maxLines: 3,
          ),
          _buildTextField(
            controller: _revenueController,
            label: 'Trị giá dự kiến (VNĐ)',
            icon: Icons.monetization_on_outlined,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập trị giá dự kiến';
              }
              final parsed =
                  double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
              if (parsed == null || parsed < 0) {
                return 'Trị giá phải là số hợp lệ và không âm';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Trạng thái'),
          const SizedBox(height: 12),
          _buildStatusDropdown(),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _status,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1)),
          items: _statuses
              .map((status) =>
                  DropdownMenuItem(value: status, child: Text(status)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submit,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(widget.submitLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
