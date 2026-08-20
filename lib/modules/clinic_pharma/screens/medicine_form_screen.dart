import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../repository.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({super.key});

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _batchController = TextEditingController();
  final _unitController = TextEditingController(text: 'viên');
  DateTime? _expiryDate;
  bool _requiresPrescription = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _batchController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('clinic_medicine_name'))));
      return;
    }
    await ClinicPharmaRepository().addMedicine(
      name: name,
      price: double.tryParse(_priceController.text) ?? 0.0,
      cost: double.tryParse(_costController.text) ?? 0.0,
      stock: double.tryParse(_stockController.text) ?? 0.0,
      batchNumber: _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
      expiryDate: _expiryDate?.toIso8601String(),
      requiresPrescription: _requiresPrescription,
      dosageUnit: _unitController.text.trim().isEmpty ? 'viên' : _unitController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_medicine_form_title'),
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
                labelText: '${context.tr('clinic_medicine_name')} *',
                prefixIcon: const Icon(Icons.medication_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Giá bán',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Giá vốn',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Tồn kho ban đầu',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: context.tr('clinic_medicine_unit'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _batchController,
              decoration: InputDecoration(
                labelText: context.tr('clinic_medicine_batch'),
                prefixIcon: const Icon(Icons.numbers_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickExpiry,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('clinic_medicine_expiry'),
                  prefixIcon: const Icon(Icons.event_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_expiryDate == null
                    ? ''
                    : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _requiresPrescription,
              onChanged: (v) => setState(() => _requiresPrescription = v),
              title: Text(context.tr('clinic_medicine_requires_prescription')),
              activeThumbColor: const Color(0xFF0EA5E9),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
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
