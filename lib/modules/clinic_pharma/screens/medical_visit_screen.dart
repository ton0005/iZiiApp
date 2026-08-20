import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../repository.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

class MedicalVisitScreen extends StatefulWidget {
  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? appointment;

  const MedicalVisitScreen({super.key, this.patient, this.appointment});

  @override
  State<MedicalVisitScreen> createState() => _MedicalVisitScreenState();
}

class _MedicalVisitScreenState extends State<MedicalVisitScreen> {
  final _chiefComplaintController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  Map<String, dynamic>? _selectedPatient;
  Map<String, dynamic>? _selectedDoctor;
  final List<Map<String, dynamic>> _prescriptionItems = [];
  bool _dispenseImmediately = true;
  bool _saving = false;

  late Future<List<Map<String, dynamic>>> _patientsFuture;
  late Future<List<Map<String, dynamic>>> _doctorsFuture;
  late Future<List<Map<String, dynamic>>> _medicinesFuture;

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.patient;
    _patientsFuture = ClinicPharmaRepository().getPatients();
    _doctorsFuture = ClinicPharmaRepository().getDoctors(activeOnly: true);
    _medicinesFuture = ClinicPharmaRepository().getMedicines();
    if (widget.appointment != null) {
      _chiefComplaintController.text = widget.appointment!['reason'] ?? '';
    }
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addPrescriptionLine() async {
    final medicines = await _medicinesFuture;
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        Map<String, dynamic>? selectedMedicine;
        final qtyController = TextEditingController(text: '1');
        final dosageController = TextEditingController();

        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) => AlertDialog(
            title: Text(context.tr('clinic_add_medicine_line')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedMedicine,
                    hint: Text(context.tr('clinic_medicine_name')),
                    items: medicines
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                  '${m['name']} (tồn: ${m['stock']})'),
                            ))
                        .toList(),
                    onChanged: (val) => setStateDialog(() => selectedMedicine = val),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dosageController,
                    decoration: InputDecoration(
                      labelText: context.tr('clinic_dosage_instructions'),
                      hintText: 'VD: 2 viên/lần, 3 lần/ngày sau ăn',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
              ElevatedButton(
                onPressed: () {
                  if (selectedMedicine == null) return;
                  final qty = double.tryParse(qtyController.text) ?? 1.0;
                  Navigator.pop(ctx, {
                    'product_id': selectedMedicine!['id'],
                    'medicine_name': selectedMedicine!['name'],
                    'quantity': qty,
                    'unit_price': (selectedMedicine!['price'] as num).toDouble(),
                    'dosage_instructions': dosageController.text.trim().isEmpty
                        ? null
                        : dosageController.text.trim(),
                  });
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
                child: Text(context.tr('confirm')),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _prescriptionItems.add(result));
    }
  }

  Future<void> _save() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('clinic_select_patient'))));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ClinicPharmaRepository();
      final visitId = await repo.addVisit({
        'id': const Uuid().v4(),
        'patient_id': _selectedPatient!['id'],
        'doctor_id': _selectedDoctor?['id'],
        'appointment_id': widget.appointment?['id'],
        'chief_complaint': _chiefComplaintController.text.trim().isEmpty
            ? null
            : _chiefComplaintController.text.trim(),
        'diagnosis': _diagnosisController.text.trim().isEmpty
            ? null
            : _diagnosisController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'status': 'completed',
      });

      String? prescriptionId;
      if (_prescriptionItems.isNotEmpty) {
        prescriptionId = await repo.addPrescriptionWithItems({
          'visit_id': visitId,
          'patient_id': _selectedPatient!['id'],
          'doctor_id': _selectedDoctor?['id'],
        }, _prescriptionItems);

        if (_dispenseImmediately) {
          await repo.dispensePrescription(prescriptionId);
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _totalAmount {
    double total = 0.0;
    for (final item in _prescriptionItems) {
      total += (item['quantity'] as num) * (item['unit_price'] as num);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_visit_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.patient == null)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _patientsFuture,
                builder: (context, snapshot) {
                  final patients = snapshot.data ?? [];
                  return DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedPatient,
                    decoration: InputDecoration(
                      labelText: '${context.tr('clinic_select_patient')} *',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: patients
                        .map((p) => DropdownMenuItem(value: p, child: Text(p['full_name'])))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPatient = v),
                  );
                },
              )
            else
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF0EA5E9)),
                  title: Text(_selectedPatient?['full_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _doctorsFuture,
              builder: (context, snapshot) {
                final doctors = snapshot.data ?? [];
                return DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedDoctor,
                  decoration: InputDecoration(
                    labelText: context.tr('clinic_select_doctor'),
                    prefixIcon: const Icon(Icons.medical_services_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: doctors
                      .map((d) => DropdownMenuItem(value: d, child: Text('BS. ${d['name']}')))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDoctor = v),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _chiefComplaintController,
              decoration: InputDecoration(
                labelText: context.tr('clinic_chief_complaint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _diagnosisController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr('clinic_diagnosis'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr('clinic_visit_notes'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('clinic_prescription_title'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addPrescriptionLine,
                  icon: const Icon(Icons.add, color: Color(0xFF0EA5E9)),
                  label: Text(context.tr('clinic_add_medicine_line'),
                      style: const TextStyle(color: Color(0xFF0EA5E9))),
                ),
              ],
            ),
            if (_prescriptionItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Text(context.tr('clinic_no_medicines'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _prescriptionItems.length,
                itemBuilder: (context, index) {
                  final item = _prescriptionItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item['medicine_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text([
                        '${item['quantity']} × ${(item['unit_price'] as num).toStringAsFixed(0)} VNĐ',
                        if ((item['dosage_instructions'] as String? ?? '').isNotEmpty)
                          item['dosage_instructions'],
                      ].join('\n')),
                      isThreeLine: (item['dosage_instructions'] as String? ?? '').isNotEmpty,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() => _prescriptionItems.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
            if (_prescriptionItems.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng tiền thuốc',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${_totalAmount.toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0EA5E9))),
                ],
              ),
              SwitchListTile(
                value: _dispenseImmediately,
                onChanged: (v) => setState(() => _dispenseImmediately = v),
                title: Text(context.tr('clinic_dispense_prescription')),
                activeThumbColor: const Color(0xFF0EA5E9),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 22),
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
