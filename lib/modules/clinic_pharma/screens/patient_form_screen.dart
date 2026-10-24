import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../repository.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _idNumberController = TextEditingController();
  DateTime? _dob;
  String? _gender;

  final _maYteController = TextEditingController();
  final _cccdController = TextEditingController();
  final _bhytController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _guardianAddressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _maYteController.dispose();
    _cccdController.dispose();
    _bhytController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('clinic_patient_name'))));
      return;
    }
    await ClinicPharmaRepository().addPatient({
      'full_name': name,
      'dob': _dob?.toIso8601String(),
      'gender': _gender,
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'id_number': _idNumberController.text.trim().isEmpty
          ? null
          : _idNumberController.text.trim(),
      'so_cccd': _cccdController.text.trim().isEmpty ? null : _cccdController.text.trim(),
      'ma_the_bhyt': _bhytController.text.trim().isEmpty ? null : _bhytController.text.trim(),
      'ma_dinh_danh_y_te': _maYteController.text.trim().isEmpty ? null : _maYteController.text.trim(),
      'guardian_name': _guardianNameController.text.trim().isEmpty ? null : _guardianNameController.text.trim(),
      'guardian_phone': _guardianPhoneController.text.trim().isEmpty ? null : _guardianPhoneController.text.trim(),
      'guardian_address': _guardianAddressController.text.trim().isEmpty ? null : _guardianAddressController.text.trim(),
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_patient_form_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '${context.tr('clinic_patient_name')} *',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDob,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('clinic_patient_dob'),
                  prefixIcon: const Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_dob == null
                    ? ''
                    : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: InputDecoration(
                labelText: context.tr('clinic_patient_gender'),
                prefixIcon: const Icon(Icons.wc_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                DropdownMenuItem(value: 'male', child: Text(context.tr('clinic_gender_male'))),
                DropdownMenuItem(value: 'female', child: Text(context.tr('clinic_gender_female'))),
                DropdownMenuItem(value: 'other', child: Text(context.tr('clinic_gender_other'))),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.tr('clinic_patient_phone'),
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: context.tr('clinic_patient_address'),
                prefixIcon: const Icon(Icons.home_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idNumberController,
              decoration: InputDecoration(
                labelText: context.tr('clinic_patient_id_number'),
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cccdController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: 'Mã định danh công dân (12 số)',
                prefixIcon: const Icon(Icons.credit_card_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bhytController,
              decoration: InputDecoration(
                labelText: 'Mã thẻ BHYT (nếu có)',
                prefixIcon: const Icon(Icons.health_and_safety_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maYteController,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Mã định danh y tế (≤ 10 ký tự)',
                prefixIcon: const Icon(Icons.local_hospital_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _guardianNameController,
              decoration: InputDecoration(
                labelText: 'Người giám hộ (bắt buộc với trẻ dưới 72 tháng)',
                prefixIcon: const Icon(Icons.family_restroom_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _guardianPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'SĐT người giám hộ',
                prefixIcon: const Icon(Icons.phone_in_talk_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _guardianAddressController,
              decoration: InputDecoration(
                labelText: 'Địa chỉ người giám hộ',
                prefixIcon: const Icon(Icons.home_work_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_outline, size: 22),
                label: Text(context.tr('save'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
