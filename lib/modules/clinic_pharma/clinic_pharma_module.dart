import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import '../../core/localization/app_localizations.dart';
import 'repository.dart';
import 'screens/patients_list_screen.dart';
import 'screens/patient_form_screen.dart';
import 'screens/doctors_list_screen.dart';
import 'screens/doctor_form_screen.dart';
import 'screens/appointments_list_screen.dart';
import 'screens/appointment_form_screen.dart';
import 'screens/medical_visit_screen.dart';
import 'screens/medicines_screen.dart';
import 'screens/medicine_form_screen.dart';

class ClinicPharmaModule implements IZiiModule {
  @override
  ModuleManifest get manifest => const ModuleManifest(
        id: 'izii.clinic_pharma',
        name: 'Clinic & Pharmacy',
        description: 'Quản lý bệnh nhân, lịch hẹn, phiếu khám, đơn thuốc và kho thuốc.',
        version: '1.0.0',
        category: 'healthcare',
        dependencies: ['izii.supply_chain'],
      );

  @override
  List<String> get tableNames => [
        'Doctors',
        'Patients',
        'Appointments',
        'MedicalVisits',
        'Prescriptions',
        'PrescriptionItems',
      ];

  @override
  List<AgentTool> get agentTools => [
        AgentTool(
          name: 'get_upcoming_appointments',
          description: 'Lấy danh sách lịch hẹn khám sắp tới trong hệ thống.',
          parameters: {'type': 'object', 'properties': {}},
          execute: (args) async {
            final appointments = await ClinicPharmaRepository()
                .getAppointments(from: DateTime.now(), status: 'scheduled');
            if (appointments.isEmpty) return 'Không có lịch hẹn sắp tới nào.';
            return appointments
                .map((a) =>
                    '${a['patient_name']} - BS. ${a['doctor_name']} - ${a['scheduled_at']} - ${a['status']}')
                .join('\n');
          },
        ),
        AgentTool(
          name: 'create_appointment',
          description:
              'Tạo một lịch hẹn khám mới. Cần patient_id, thời gian hẹn scheduled_at (ISO8601). Yêu cầu xác nhận.',
          parameters: {
            'type': 'object',
            'properties': {
              'patient_id': {'type': 'string', 'description': 'ID bệnh nhân'},
              'doctor_id': {
                'type': 'string',
                'description': 'ID bác sĩ (không bắt buộc)'
              },
              'scheduled_at': {
                'type': 'string',
                'description': 'Thời gian hẹn khám, định dạng ISO8601'
              },
              'reason': {'type': 'string', 'description': 'Lý do khám'},
            },
            'required': ['patient_id', 'scheduled_at'],
          },
          requiresConfirmation: true,
          execute: (args) async {
            await ClinicPharmaRepository().addAppointment({
              'patient_id': args['patient_id'],
              'doctor_id': args['doctor_id'],
              'scheduled_at': args['scheduled_at'],
              'reason': args['reason'],
            });
            return 'Đã tạo lịch hẹn khám thành công.';
          },
        ),
        AgentTool(
          name: 'search_patients',
          description: 'Tìm kiếm bệnh nhân theo tên hoặc số điện thoại.',
          parameters: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Tên hoặc SĐT bệnh nhân'},
            },
            'required': ['query'],
          },
          execute: (args) async {
            final query = (args['query'] as String).toLowerCase();
            final patients = await ClinicPharmaRepository().getPatients();
            final matches = patients.where((p) {
              final name = (p['full_name'] as String).toLowerCase();
              final phone = (p['phone'] as String? ?? '').toLowerCase();
              return name.contains(query) || phone.contains(query);
            }).toList();
            if (matches.isEmpty) {
              return 'Không tìm thấy bệnh nhân nào phù hợp với "$query".';
            }
            return matches
                .map((p) => '${p['full_name']} - SĐT: ${p['phone'] ?? 'N/A'}')
                .join('\n');
          },
        ),
        AgentTool(
          name: 'check_medicine_stock',
          description: 'Kiểm tra tồn kho của một loại thuốc trong nhà thuốc.',
          parameters: {
            'type': 'object',
            'properties': {
              'medicine_name': {
                'type': 'string',
                'description': 'Tên thuốc cần kiểm tra'
              },
            },
            'required': ['medicine_name'],
          },
          execute: (args) async {
            final query = (args['medicine_name'] as String).toLowerCase();
            final medicines = await ClinicPharmaRepository().getMedicines();
            final matches = medicines
                .where((m) => (m['name'] as String).toLowerCase().contains(query))
                .toList();
            if (matches.isEmpty) {
              return 'Không tìm thấy thuốc nào phù hợp với "$query".';
            }
            return matches
                .map((m) => '${m['name']} - tồn kho: ${m['stock']}')
                .join('\n');
          },
        ),
      ];

  @override
  Map<String, WidgetBuilder> get routes => {
        '/clinic/patients': (context) => const PatientsListScreen(),
        '/clinic/patients/form': (context) => const PatientFormScreen(),
        '/clinic/doctors': (context) => const DoctorsListScreen(),
        '/clinic/doctors/form': (context) => const DoctorFormScreen(),
        '/clinic/appointments': (context) => const AppointmentsListScreen(),
        '/clinic/appointments/form': (context) => const AppointmentFormScreen(),
        '/clinic/visits/form': (context) => const MedicalVisitScreen(),
        '/clinic/medicines': (context) => const MedicinesScreen(),
        '/clinic/medicines/form': (context) => const MedicineFormScreen(),
      };

  @override
  Widget? get dashboardWidget => const _ClinicPharmaDashboardWidget();

  @override
  Future<void> initialize() async {
    AppLocalizations.registerModuleTranslations('vi', {
      'module_izii.clinic_pharma_name': 'Phòng khám & Nhà thuốc',
      'module_izii.clinic_pharma_desc':
          'Quản lý bệnh nhân, lịch hẹn, phiếu khám, đơn thuốc và kho thuốc.',
      'clinic_dashboard_title': 'Phòng khám & Nhà thuốc',
      'clinic_today_appointments': 'Lịch hẹn hôm nay',
      'clinic_total_patients': 'Bệnh nhân',
      'clinic_low_stock_medicines': 'Thuốc sắp hết',
      'clinic_patients_title': 'Bệnh nhân',
      'clinic_no_patients': 'Chưa có bệnh nhân nào',
      'clinic_patient_form_title': 'Thêm bệnh nhân',
      'clinic_patient_name': 'Họ và tên',
      'clinic_patient_dob': 'Ngày sinh',
      'clinic_patient_gender': 'Giới tính',
      'clinic_patient_phone': 'Số điện thoại',
      'clinic_patient_address': 'Địa chỉ',
      'clinic_patient_id_number': 'CMND/CCCD/BHYT',
      'clinic_gender_male': 'Nam',
      'clinic_gender_female': 'Nữ',
      'clinic_gender_other': 'Khác',
      'clinic_doctors_title': 'Bác sĩ',
      'clinic_no_doctors': 'Chưa có bác sĩ nào',
      'clinic_doctor_form_title': 'Thêm bác sĩ',
      'clinic_doctor_name': 'Tên bác sĩ',
      'clinic_doctor_specialty': 'Chuyên khoa',
      'clinic_appointments_title': 'Lịch hẹn',
      'clinic_no_appointments': 'Chưa có lịch hẹn nào',
      'clinic_appointment_form_title': 'Đặt lịch hẹn',
      'clinic_select_patient': 'Chọn bệnh nhân',
      'clinic_select_doctor': 'Chọn bác sĩ (tuỳ chọn)',
      'clinic_appointment_time': 'Thời gian hẹn',
      'clinic_appointment_reason': 'Lý do khám',
      'clinic_status_scheduled': 'Đã đặt',
      'clinic_status_checked_in': 'Đã check-in',
      'clinic_status_completed': 'Hoàn tất',
      'clinic_status_cancelled': 'Đã huỷ',
      'clinic_status_no_show': 'Không đến',
      'clinic_visit_title': 'Phiếu khám',
      'clinic_chief_complaint': 'Lý do khám',
      'clinic_diagnosis': 'Chẩn đoán',
      'clinic_visit_notes': 'Ghi chú',
      'clinic_prescription_title': 'Đơn thuốc',
      'clinic_add_medicine_line': 'Thêm thuốc',
      'clinic_dosage_instructions': 'Liều dùng',
      'clinic_dispense_prescription': 'Xuất thuốc',
      'clinic_print_prescription_title': 'In đơn thuốc',
      'clinic_facility_authority': 'Sở Y tế',
      'clinic_facility_name': 'Tên cơ sở khám bệnh',
      'clinic_facility_phone': 'Điện thoại',
      'clinic_patient_weight': 'Cân nặng',
      'clinic_prescription_advice': 'Lời dặn',
      'clinic_guardian_name': 'Tên bố/mẹ (nếu là trẻ em)',
      'clinic_refresh_preview': 'Cập nhật xem trước',
      'clinic_medicines_title': 'Kho thuốc',
      'clinic_no_medicines': 'Chưa có thuốc nào trong kho',
      'clinic_medicine_form_title': 'Thêm thuốc',
      'clinic_medicine_name': 'Tên thuốc',
      'clinic_medicine_batch': 'Số lô',
      'clinic_medicine_expiry': 'Hạn dùng',
      'clinic_medicine_requires_prescription': 'Cần đơn thuốc',
      'clinic_medicine_unit': 'Đơn vị tính',
      'clinic_action_patients': 'Bệnh nhân',
      'clinic_action_patients_sub': 'Hồ sơ và lịch sử khám',
      'clinic_action_doctors': 'Bác sĩ',
      'clinic_action_doctors_sub': 'Danh sách bác sĩ',
      'clinic_action_appointments': 'Lịch hẹn',
      'clinic_action_appointments_sub': 'Đặt và theo dõi lịch khám',
      'clinic_action_visits': 'Phiếu khám',
      'clinic_action_visits_sub': 'Khám bệnh và kê đơn thuốc',
      'clinic_action_medicines': 'Kho thuốc',
      'clinic_action_medicines_sub': 'Tồn kho và hạn dùng',
    });
    AppLocalizations.registerModuleTranslations('en', {
      'module_izii.clinic_pharma_name': 'Clinic & Pharmacy',
      'module_izii.clinic_pharma_desc':
          'Manage patients, appointments, visits, prescriptions and pharmacy stock.',
      'clinic_dashboard_title': 'Clinic & Pharmacy',
      'clinic_today_appointments': 'Today\'s appointments',
      'clinic_total_patients': 'Patients',
      'clinic_low_stock_medicines': 'Low stock medicines',
      'clinic_patients_title': 'Patients',
      'clinic_no_patients': 'No patients yet',
      'clinic_patient_form_title': 'Add Patient',
      'clinic_patient_name': 'Full name',
      'clinic_patient_dob': 'Date of birth',
      'clinic_patient_gender': 'Gender',
      'clinic_patient_phone': 'Phone number',
      'clinic_patient_address': 'Address',
      'clinic_patient_id_number': 'ID/Insurance number',
      'clinic_gender_male': 'Male',
      'clinic_gender_female': 'Female',
      'clinic_gender_other': 'Other',
      'clinic_doctors_title': 'Doctors',
      'clinic_no_doctors': 'No doctors yet',
      'clinic_doctor_form_title': 'Add Doctor',
      'clinic_doctor_name': 'Doctor name',
      'clinic_doctor_specialty': 'Specialty',
      'clinic_appointments_title': 'Appointments',
      'clinic_no_appointments': 'No appointments yet',
      'clinic_appointment_form_title': 'Book Appointment',
      'clinic_select_patient': 'Select patient',
      'clinic_select_doctor': 'Select doctor (optional)',
      'clinic_appointment_time': 'Appointment time',
      'clinic_appointment_reason': 'Reason for visit',
      'clinic_status_scheduled': 'Scheduled',
      'clinic_status_checked_in': 'Checked in',
      'clinic_status_completed': 'Completed',
      'clinic_status_cancelled': 'Cancelled',
      'clinic_status_no_show': 'No show',
      'clinic_visit_title': 'Medical Visit',
      'clinic_chief_complaint': 'Chief complaint',
      'clinic_diagnosis': 'Diagnosis',
      'clinic_visit_notes': 'Notes',
      'clinic_prescription_title': 'Prescription',
      'clinic_add_medicine_line': 'Add medicine',
      'clinic_dosage_instructions': 'Dosage instructions',
      'clinic_dispense_prescription': 'Dispense',
      'clinic_print_prescription_title': 'Print Prescription',
      'clinic_facility_authority': 'Health authority',
      'clinic_facility_name': 'Facility name',
      'clinic_facility_phone': 'Phone',
      'clinic_patient_weight': 'Weight',
      'clinic_prescription_advice': 'Advice',
      'clinic_guardian_name': 'Guardian name (if child)',
      'clinic_refresh_preview': 'Refresh preview',
      'clinic_medicines_title': 'Pharmacy Inventory',
      'clinic_no_medicines': 'No medicines in stock yet',
      'clinic_medicine_form_title': 'Add Medicine',
      'clinic_medicine_name': 'Medicine name',
      'clinic_medicine_batch': 'Batch number',
      'clinic_medicine_expiry': 'Expiry date',
      'clinic_medicine_requires_prescription': 'Requires prescription',
      'clinic_medicine_unit': 'Unit',
      'clinic_action_patients': 'Patients',
      'clinic_action_patients_sub': 'Records and visit history',
      'clinic_action_doctors': 'Doctors',
      'clinic_action_doctors_sub': 'Doctor directory',
      'clinic_action_appointments': 'Appointments',
      'clinic_action_appointments_sub': 'Book and track visits',
      'clinic_action_visits': 'Medical Visit',
      'clinic_action_visits_sub': 'Examine and prescribe',
      'clinic_action_medicines': 'Pharmacy Inventory',
      'clinic_action_medicines_sub': 'Stock and expiry tracking',
    });
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {}
}

class _ClinicPharmaDashboardWidget extends StatefulWidget {
  const _ClinicPharmaDashboardWidget();

  @override
  State<_ClinicPharmaDashboardWidget> createState() =>
      _ClinicPharmaDashboardWidgetState();
}

class _ClinicPharmaDashboardWidgetState
    extends State<_ClinicPharmaDashboardWidget> {
  int _todayAppointments = 0;
  int _totalPatients = 0;
  int _lowStockMedicines = 0;
  bool _loading = true;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = ClinicPharmaRepository();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final appointments =
        await repo.getAppointments(from: startOfDay, to: endOfDay);
    final patients = await repo.getPatients();
    final medicines = await repo.getMedicines();
    final lowStock =
        medicines.where((m) => (m['stock'] as num? ?? 0) < 10).length;

    if (mounted) {
      setState(() {
        _todayAppointments = appointments.length;
        _totalPatients = patients.length;
        _lowStockMedicines = lowStock;
        _loading = false;
      });
    }
  }

  Future<void> _seedSampleData() async {
    setState(() => _seeding = true);
    try {
      final repo = ClinicPharmaRepository();
      final hadData = (await repo.getPatients()).isNotEmpty;
      await repo.seedSampleData();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hadData
              ? 'Đã có dữ liệu, bỏ qua tạo mẫu.'
              : 'Đã tạo dữ liệu mẫu: bác sĩ, bệnh nhân, thuốc, lịch hẹn.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('clinic_dashboard_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statTile(context, _todayAppointments.toString(),
                  'clinic_today_appointments', Icons.event_available),
              _statTile(context, _totalPatients.toString(),
                  'clinic_total_patients', Icons.people_outline),
              _statTile(context, _lowStockMedicines.toString(),
                  'clinic_low_stock_medicines', Icons.medication_outlined),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _seeding ? null : _seedSampleData,
                icon: _seeding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.science_outlined, size: 16),
                label: const Text('Nạp dữ liệu mẫu',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statTile(
      BuildContext context, String value, String labelKey, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0EA5E9), size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(context.tr(labelKey),
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
