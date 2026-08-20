import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../repository.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key});

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _reasonController = TextEditingController();
  Map<String, dynamic>? _selectedPatient;
  Map<String, dynamic>? _selectedDoctor;
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));

  late Future<List<Map<String, dynamic>>> _patientsFuture;
  late Future<List<Map<String, dynamic>>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _patientsFuture = ClinicPharmaRepository().getPatients();
    _doctorsFuture = ClinicPharmaRepository().getDoctors(activeOnly: true);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('clinic_select_patient'))));
      return;
    }
    await ClinicPharmaRepository().addAppointment({
      'patient_id': _selectedPatient!['id'],
      'doctor_id': _selectedDoctor?['id'],
      'scheduled_at': _scheduledAt.toIso8601String(),
      'reason': _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_appointment_form_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            InkWell(
              onTap: _pickDateTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('clinic_appointment_time'),
                  prefixIcon: const Icon(Icons.schedule_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                    '${_scheduledAt.hour.toString().padLeft(2, '0')}:${_scheduledAt.minute.toString().padLeft(2, '0')} '
                    '${_scheduledAt.day}/${_scheduledAt.month}/${_scheduledAt.year}'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: context.tr('clinic_appointment_reason'),
                prefixIcon: const Icon(Icons.notes_outlined),
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
