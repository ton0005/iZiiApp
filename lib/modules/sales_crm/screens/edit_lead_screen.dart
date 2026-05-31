import 'package:flutter/material.dart';
import '../bloc/crm_bloc.dart';
import '../ui/lead_form.dart';

class EditLeadScreen extends StatefulWidget {
  final Map<String, dynamic> lead;

  const EditLeadScreen({super.key, required this.lead});

  @override
  State<EditLeadScreen> createState() => _EditLeadScreenState();
}

class _EditLeadScreenState extends State<EditLeadScreen> {
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
        content: Text('Đã cập nhật khách hàng "${updatedLead['name']}"!'),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa Khách hàng'),
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
        child: LeadForm(
          initialLead: widget.lead,
          submitLabel: 'Cập nhật Lead',
          onSave: _saveLead,
        ),
      ),
    );
  }
}
