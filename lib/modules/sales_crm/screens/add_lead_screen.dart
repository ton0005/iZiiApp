import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../bloc/crm_bloc.dart';
import '../ui/lead_form.dart';

class AddLeadScreen extends StatefulWidget {
  const AddLeadScreen({super.key});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  Future<void> _saveLead(Map<String, dynamic> values) async {
    final lead = {
      ...values,
      'id': const Uuid().v4(),
      'custom_fields': values['custom_fields'] ?? {},
    };

    try {
      await CrmRepository().addLead(lead);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm khách hàng "${lead['name']}"!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thêm lead: $e'),
          backgroundColor: const Color(0xFFF43F5E),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Khách hàng Mới'),
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
          submitLabel: 'Thêm Lead',
          onSave: _saveLead,
        ),
      ),
    );
  }
}
