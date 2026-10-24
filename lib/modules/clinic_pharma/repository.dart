import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../supply_chain/repository.dart';
import 'services/dtqg_rules.dart';

class ClinicPharmaRepository {
  final AppDatabase _db;
  final SupplyChainRepository _supplyChain;

  ClinicPharmaRepository([AppDatabase? database])
      : _db = database ?? AppDatabase(),
        _supplyChain = SupplyChainRepository(database);

  Map<String, dynamic> _decodeCustomFields(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  String _encodeCustomFields(dynamic fields) {
    if (fields == null) return '{}';
    if (fields is Map) {
      if (fields.isEmpty) return '{}';
      return jsonEncode(Map<String, dynamic>.from(fields));
    }
    return '{}';
  }

  // === DOCTORS ===

  Future<List<Map<String, dynamic>>> getDoctors({bool activeOnly = false}) async {
    final query = _db.select(_db.doctors);
    if (activeOnly) {
      query.where((tbl) => tbl.active.equals(true));
    }
    final doctors = await query.get();
    return doctors
        .map((d) => <String, dynamic>{
              'id': d.id,
              'name': d.name,
              'specialty': d.specialty,
              'phone': d.phone,
              'email': d.email,
              'so_cchn': d.soCchn,
              'ma_lien_thong_dtqg': d.maLienThongDtqg,
              'duoc_ke_don': d.duocKeDon,
              'dtqg_status': d.dtqgStatus,
              'active': d.active,
              'custom_fields': _decodeCustomFields(d.customFields),
              'created_at': d.createdAt.toIso8601String(),
            })
        .toList();
  }

  Future<String> addDoctor(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();
    final cchn = (data['so_cchn'] as String?)?.trim();
    final maLt = (cchn == null || cchn.isEmpty) ? null : DtqgRules.maLienThongBacSi(cchn);
    final dtqgStatus = data['dtqg_status'] ?? 'pending';
    await _db.into(_db.doctors).insert(DoctorsCompanion.insert(
          id: id,
          name: data['name'],
          specialty: Value(data['specialty'] ?? ''),
          phone: Value(data['phone']),
          email: Value(data['email']),
          soCchn: Value(cchn == null || cchn.isEmpty ? null : cchn),
          maLienThongDtqg: Value(maLt),
          duocKeDon: Value(data['duoc_ke_don'] ?? true),
          dtqgStatus: Value(dtqgStatus),
          active: Value(data['active'] ?? true),
          customFields: Value(_encodeCustomFields(data['custom_fields'])),
        ));

    SyncService().queueMutation('doctors', 'insert', {
      'id': id,
      'name': data['name'],
      'specialty': data['specialty'] ?? '',
      'phone': data['phone'],
      'email': data['email'],
      'so_cchn': cchn,
      'ma_lien_thong_dtqg': maLt,
      'duoc_ke_don': data['duoc_ke_don'] ?? true,
      'dtqg_status': dtqgStatus,
      'active': data['active'] ?? true,
      'custom_fields': data['custom_fields'] ?? {},
    });
    return id;
  }

  Future<void> updateDoctor(String id, Map<String, dynamic> data) async {
    await (_db.update(_db.doctors)..where((tbl) => tbl.id.equals(id)))
        .write(DoctorsCompanion(
      name: data['name'] != null ? Value(data['name']) : const Value.absent(),
      specialty: data['specialty'] != null
          ? Value(data['specialty'])
          : const Value.absent(),
      phone: Value(data['phone']),
      email: Value(data['email']),
      dtqgStatus: data['dtqg_status'] != null
          ? Value(data['dtqg_status'])
          : const Value.absent(),
      duocKeDon: data['duoc_ke_don'] != null
          ? Value(data['duoc_ke_don'])
          : const Value.absent(),
      active: data['active'] != null
          ? Value(data['active'])
          : const Value.absent(),
    ));

    SyncService().queueMutation('doctors', 'update', {'id': id, ...data});
  }

  // === PATIENTS ===

  Future<List<Map<String, dynamic>>> getPatients() async {
    final patients = await _db.select(_db.patients).get();
    return patients.map(_patientToMap).toList();
  }

  Future<Map<String, dynamic>?> getPatientById(String id) async {
    final patient = await (_db.select(_db.patients)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (patient == null) return null;
    return _patientToMap(patient);
  }

  Map<String, dynamic> _patientToMap(Patient p) => {
        'id': p.id,
        'full_name': p.fullName,
        'dob': p.dob?.toIso8601String(),
        'gender': p.gender,
        'phone': p.phone,
        'address': p.address,
        'id_number': p.idNumber,
        'ma_dinh_danh_y_te': p.maDinhDanhYte,
        'so_cccd': p.soCccd,
        'ma_the_bhyt': p.maTheBhyt,
        'guardian_name': p.guardianName,
        'guardian_phone': p.guardianPhone,
        'guardian_address': p.guardianAddress,
        'custom_fields': _decodeCustomFields(p.customFields),
        'created_at': p.createdAt.toIso8601String(),
      };

  Future<String> addPatient(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();
    final dob = data['dob'] != null ? DateTime.tryParse(data['dob']) : null;
    await _db.into(_db.patients).insert(PatientsCompanion.insert(
          id: id,
          fullName: data['full_name'],
          dob: Value(dob),
          gender: Value(data['gender']),
          phone: Value(data['phone']),
          address: Value(data['address']),
          idNumber: Value(data['id_number']),
          maDinhDanhYte: Value(data['ma_dinh_danh_y_te']),
          soCccd: Value(data['so_cccd']),
          maTheBhyt: Value(data['ma_the_bhyt']),
          guardianName: Value(data['guardian_name']),
          guardianPhone: Value(data['guardian_phone']),
          guardianAddress: Value(data['guardian_address']),
          customFields: Value(_encodeCustomFields(data['custom_fields'])),
        ));

    SyncService().queueMutation('patients', 'insert', {
      'id': id,
      'full_name': data['full_name'],
      'dob': data['dob'],
      'gender': data['gender'],
      'phone': data['phone'],
      'address': data['address'],
      'id_number': data['id_number'],
      'ma_dinh_danh_y_te': data['ma_dinh_danh_y_te'],
      'so_cccd': data['so_cccd'],
      'ma_the_bhyt': data['ma_the_bhyt'],
      'guardian_name': data['guardian_name'],
      'guardian_phone': data['guardian_phone'],
      'guardian_address': data['guardian_address'],
      'custom_fields': data['custom_fields'] ?? {},
    });
    return id;
  }

  Future<void> updatePatient(String id, Map<String, dynamic> data) async {
    final dob = data['dob'] != null ? DateTime.tryParse(data['dob']) : null;
    await (_db.update(_db.patients)..where((tbl) => tbl.id.equals(id)))
        .write(PatientsCompanion(
      fullName: data['full_name'] != null
          ? Value(data['full_name'])
          : const Value.absent(),
      dob: dob != null ? Value(dob) : const Value.absent(),
      gender: Value(data['gender']),
      phone: Value(data['phone']),
      address: Value(data['address']),
      idNumber: Value(data['id_number']),
      maDinhDanhYte: Value(data['ma_dinh_danh_y_te']),
      soCccd: Value(data['so_cccd']),
      maTheBhyt: Value(data['ma_the_bhyt']),
      guardianName: Value(data['guardian_name']),
      guardianPhone: Value(data['guardian_phone']),
      guardianAddress: Value(data['guardian_address']),
    ));

    SyncService().queueMutation('patients', 'update', {'id': id, ...data});
  }

  // === APPOINTMENTS ===

  Future<List<Map<String, dynamic>>> getAppointments({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final query = _db.select(_db.appointments);
    if (from != null) {
      query.where((tbl) => tbl.scheduledAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((tbl) => tbl.scheduledAt.isSmallerOrEqualValue(to));
    }
    if (status != null) {
      query.where((tbl) => tbl.status.equals(status));
    }
    query.orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledAt)]);
    final appointments = await query.get();

    final patients = {for (final p in await getPatients()) p['id']: p};
    final doctors = {for (final d in await getDoctors()) d['id']: d};

    return appointments
        .map((a) => <String, dynamic>{
              'id': a.id,
              'patient_id': a.patientId,
              'patient_name': patients[a.patientId]?['full_name'] ?? '',
              'doctor_id': a.doctorId,
              'doctor_name': doctors[a.doctorId]?['name'] ?? '',
              'scheduled_at': a.scheduledAt.toIso8601String(),
              'reason': a.reason,
              'status': a.status,
              'notes': a.notes,
              'created_at': a.createdAt.toIso8601String(),
            })
        .toList();
  }

  Future<String> addAppointment(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();
    final scheduledAt =
        DateTime.tryParse(data['scheduled_at'] ?? '') ?? DateTime.now();
    await _db.into(_db.appointments).insert(AppointmentsCompanion.insert(
          id: id,
          patientId: data['patient_id'],
          doctorId: Value(data['doctor_id']),
          scheduledAt: scheduledAt,
          reason: Value(data['reason']),
          status: Value(data['status'] ?? 'scheduled'),
          notes: Value(data['notes']),
        ));

    SyncService().queueMutation('appointments', 'insert', {
      'id': id,
      'patient_id': data['patient_id'],
      'doctor_id': data['doctor_id'],
      'scheduled_at': scheduledAt.toIso8601String(),
      'reason': data['reason'],
      'status': data['status'] ?? 'scheduled',
      'notes': data['notes'],
    });
    return id;
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    await (_db.update(_db.appointments)..where((tbl) => tbl.id.equals(id)))
        .write(AppointmentsCompanion(status: Value(status)));

    SyncService()
        .queueMutation('appointments', 'update', {'id': id, 'status': status});
  }

  // === MEDICAL VISITS ===

  Future<List<Map<String, dynamic>>> getVisitsForPatient(
      String patientId) async {
    final visits = await (_db.select(_db.medicalVisits)
          ..where((tbl) => tbl.patientId.equals(patientId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.visitDate)]))
        .get();
    return visits.map(_visitToMap).toList();
  }

  Future<Map<String, dynamic>?> getVisitById(String id) async {
    final visit = await (_db.select(_db.medicalVisits)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    return visit == null ? null : _visitToMap(visit);
  }

  Map<String, dynamic> _visitToMap(MedicalVisit v) => {
        'id': v.id,
        'patient_id': v.patientId,
        'doctor_id': v.doctorId,
        'appointment_id': v.appointmentId,
        'visit_date': v.visitDate.toIso8601String(),
        'chief_complaint': v.chiefComplaint,
        'diagnosis': v.diagnosis,
        'notes': v.notes,
        'status': v.status,
        'created_at': v.createdAt.toIso8601String(),
      };

  Future<String> addVisit(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();
    await _db.into(_db.medicalVisits).insert(MedicalVisitsCompanion.insert(
          id: id,
          patientId: data['patient_id'],
          doctorId: Value(data['doctor_id']),
          appointmentId: Value(data['appointment_id']),
          chiefComplaint: Value(data['chief_complaint']),
          diagnosis: Value(data['diagnosis']),
          notes: Value(data['notes']),
          status: Value(data['status'] ?? 'open'),
        ));

    SyncService().queueMutation('medical_visits', 'insert', {
      'id': id,
      'patient_id': data['patient_id'],
      'doctor_id': data['doctor_id'],
      'appointment_id': data['appointment_id'],
      'chief_complaint': data['chief_complaint'],
      'diagnosis': data['diagnosis'],
      'notes': data['notes'],
      'status': data['status'] ?? 'open',
    });

    if (data['appointment_id'] != null) {
      await updateAppointmentStatus(data['appointment_id'], 'completed');
    }
    return id;
  }

  Future<void> updateVisit(String id, Map<String, dynamic> data) async {
    await (_db.update(_db.medicalVisits)..where((tbl) => tbl.id.equals(id)))
        .write(MedicalVisitsCompanion(
      diagnosis: Value(data['diagnosis']),
      notes: Value(data['notes']),
      chiefComplaint: Value(data['chief_complaint']),
      status: data['status'] != null
          ? Value(data['status'])
          : const Value.absent(),
    ));

    SyncService().queueMutation('medical_visits', 'update', {'id': id, ...data});
  }

  // === PRESCRIPTIONS ===

  Future<List<Map<String, dynamic>>> getPrescriptionsForVisit(
      String visitId) async {
    final prescriptions = await (_db.select(_db.prescriptions)
          ..where((tbl) => tbl.visitId.equals(visitId)))
        .get();

    final result = <Map<String, dynamic>>[];
    for (final p in prescriptions) {
      final items = await getPrescriptionItems(p.id);
      result.add({
        'id': p.id,
        'visit_id': p.visitId,
        'patient_id': p.patientId,
        'doctor_id': p.doctorId,
        'prescription_date': p.prescriptionDate.toIso8601String(),
        'status': p.status,
        'notes': p.notes,
        ..._dtqgFields(p),
        'created_at': p.createdAt.toIso8601String(),
        'items': items,
      });
    }
    return result;
  }

  Map<String, dynamic> _dtqgFields(Prescription p) => {
        'ma_don_thuoc': p.maDonThuoc,
        'loai_don': p.loaiDon,
        'chan_doan': _decodeList(p.chanDoanJson),
        'can_nang': p.canNang,
        'hinh_thuc_dieu_tri': p.hinhThucDieuTri,
        'nguoi_giam_ho': p.nguoiGiamHo,
        'loi_dan': p.loiDan,
        'ngay_tai_kham': p.ngayTaiKham,
        'dtqg_status': p.dtqgStatus,
        'dtqg_sent_at': p.dtqgSentAt?.toIso8601String(),
        'dtqg_last_error': p.dtqgLastError,
      };

  List<Map<String, dynamic>> _decodeList(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is List) {
        return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getPrescriptionItems(
      String prescriptionId) async {
    final items = await (_db.select(_db.prescriptionItems)
          ..where((tbl) => tbl.prescriptionId.equals(prescriptionId)))
        .get();
    return items
        .map((i) => <String, dynamic>{
              'id': i.id,
              'prescription_id': i.prescriptionId,
              'product_id': i.productId,
              'medicine_name': i.medicineName,
              'dosage_instructions': i.dosageInstructions,
              'ma_thuoc_cuc_qldd': i.maThuocCucQldd,
              'biet_duoc': i.bietDuoc,
              'don_vi_tinh': i.donViTinh,
              'so_luong_ban': i.soLuongBan,
              'quantity': i.quantity,
              'unit_price': i.unitPrice,
              'total_price': i.totalPrice,
            })
        .toList();
  }

  Future<String> addPrescriptionWithItems(
    Map<String, dynamic> prescriptionData,
    List<Map<String, dynamic>> itemsData,
  ) async {
    final prescriptionId = prescriptionData['id'] ?? const Uuid().v4();
    final loai = (prescriptionData['loai_don'] as String?) ?? 'c';
    final prescribedAt = DateTime.now();
    final diagnoses = prescriptionData['chan_doan'] ?? <Map<String, dynamic>>[];
    final chanDoanJson = jsonEncode(diagnoses);

    // Mã đơn thuốc chỉ sinh được khi cơ sở đã khai báo mã CSKCB 5 ký tự;
    // chưa có thì để trống, đơn vẫn lưu ở trạng thái "draft".
    String? maDon = prescriptionData['ma_don_thuoc'];
    if (maDon == null) {
      final facility = await getFacility();
      final cs = (facility['ma_cskcb'] as String? ?? '').trim();
      if (cs.length == 5) maDon = await _uniqueMaDonThuoc(cs, loai);
    }

    await _db.transaction(() async {
      await _db.into(_db.prescriptions).insert(PrescriptionsCompanion.insert(
            id: prescriptionId,
            visitId: prescriptionData['visit_id'],
            patientId: prescriptionData['patient_id'],
            doctorId: Value(prescriptionData['doctor_id']),
            status: Value(prescriptionData['status'] ?? 'pending'),
            notes: Value(prescriptionData['notes']),
            prescriptionDate: Value(prescribedAt),
            maDonThuoc: Value(maDon),
            loaiDon: Value(loai),
            chanDoanJson: Value(chanDoanJson),
            canNang: Value((prescriptionData['can_nang'] as num?)?.toDouble()),
            hinhThucDieuTri: Value(prescriptionData['hinh_thuc_dieu_tri']),
            nguoiGiamHo: Value(prescriptionData['nguoi_giam_ho']),
            loiDan: Value(prescriptionData['loi_dan']),
            ngayTaiKham: Value(prescriptionData['ngay_tai_kham']),
          ));

      for (final item in itemsData) {
        final itemId = item['id'] ?? const Uuid().v4();
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        await _db
            .into(_db.prescriptionItems)
            .insert(PrescriptionItemsCompanion.insert(
              id: itemId,
              prescriptionId: prescriptionId,
              productId: item['product_id'],
              medicineName: item['medicine_name'],
              dosageInstructions: Value(item['dosage_instructions']),
              maThuocCucQldd: Value(item['ma_thuoc_cuc_qldd']),
              bietDuoc: Value(item['biet_duoc']),
              donViTinh: Value(item['don_vi_tinh']),
              quantity: Value(qty),
              unitPrice: Value(price),
              totalPrice: Value(qty * price),
            ));
      }
    });

    SyncService().queueMutation('prescriptions', 'insert', {
      'id': prescriptionId,
      'visit_id': prescriptionData['visit_id'],
      'patient_id': prescriptionData['patient_id'],
      'doctor_id': prescriptionData['doctor_id'],
      'status': prescriptionData['status'] ?? 'pending',
      'notes': prescriptionData['notes'],
      'prescription_date': prescribedAt.toUtc().toIso8601String(),
      'ma_don_thuoc': maDon,
      'loai_don': loai,
      'chan_doan_json': chanDoanJson,
      'can_nang': prescriptionData['can_nang'],
      'hinh_thuc_dieu_tri': prescriptionData['hinh_thuc_dieu_tri'],
      'nguoi_giam_ho': prescriptionData['nguoi_giam_ho'],
      'loi_dan': prescriptionData['loi_dan'],
      'ngay_tai_kham': prescriptionData['ngay_tai_kham'],
      'dtqg_status': 'draft',
    });
    for (final item in itemsData) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      SyncService().queueMutation('prescription_items', 'insert', {
        'id': item['id'] ?? const Uuid().v4(),
        'prescription_id': prescriptionId,
        'product_id': item['product_id'],
        'medicine_name': item['medicine_name'],
        'dosage_instructions': item['dosage_instructions'],
        'ma_thuoc_cuc_qldd': item['ma_thuoc_cuc_qldd'],
        'biet_duoc': item['biet_duoc'],
        'don_vi_tinh': item['don_vi_tinh'],
        'quantity': qty,
        'unit_price': price,
        'total_price': qty * price,
      });
    }

    return prescriptionId;
  }

  Future<String> _uniqueMaDonThuoc(String maCskcb, String loai) async {
    for (var i = 0; i < 20; i++) {
      final code = DtqgRules.generateMaDonThuoc(maCskcb, loai: loai);
      final exists = await (_db.select(_db.prescriptions)
            ..where((t) => t.maDonThuoc.equals(code)))
          .getSingleOrNull();
      if (exists == null) return code;
    }
    throw Exception('Không sinh được mã đơn thuốc duy nhất');
  }

  /// Đơn đã gửi lên hệ thống quốc gia không được sửa/xóa (FAQ 1.14, 1.19).
  Future<void> assertPrescriptionEditable(String prescriptionId) async {
    final p = await (_db.select(_db.prescriptions)
          ..where((t) => t.id.equals(prescriptionId)))
        .getSingleOrNull();
    if (p != null && p.dtqgStatus == 'sent') {
      throw Exception(
          'Đơn ${p.maDonThuoc ?? ''} đã gửi lên Đơn thuốc quốc gia, không thể sửa/xóa. Hãy tạo đơn mới.');
    }
  }

  /// Cập nhật nội dung đơn (lời dặn, ngày tái khám…). Từ chối nếu đơn đã gửi.
  Future<void> updatePrescriptionContent(
      String prescriptionId, Map<String, dynamic> data) async {
    await assertPrescriptionEditable(prescriptionId);
    await (_db.update(_db.prescriptions)
          ..where((t) => t.id.equals(prescriptionId)))
        .write(PrescriptionsCompanion(
      notes: Value(data['notes']),
      loiDan: Value(data['loi_dan']),
      ngayTaiKham: Value(data['ngay_tai_kham']),
      canNang: Value((data['can_nang'] as num?)?.toDouble()),
    ));
    SyncService().queueMutation('prescriptions', 'update', {'id': prescriptionId, ...data});
  }

  Future<void> deletePrescription(String prescriptionId) async {
    await assertPrescriptionEditable(prescriptionId);
    await (_db.update(_db.prescriptions)
          ..where((t) => t.id.equals(prescriptionId)))
        .write(const PrescriptionsCompanion(status: Value('cancelled')));
    SyncService().queueMutation(
        'prescriptions', 'update', {'id': prescriptionId, 'status': 'cancelled'});
  }

  /// Ghi trạng thái liên thông (do DtqgGateway/server hoặc client gọi).
  Future<void> setDtqgStatus(String prescriptionId, String status,
      {String? error}) async {
    await (_db.update(_db.prescriptions)
          ..where((t) => t.id.equals(prescriptionId)))
        .write(PrescriptionsCompanion(
      dtqgStatus: Value(status),
      dtqgSentAt: status == 'sent' ? Value(DateTime.now()) : const Value.absent(),
      dtqgLastError: Value(error),
    ));
    SyncService().queueMutation('prescriptions', 'update', {
      'id': prescriptionId,
      'dtqg_status': status,
      'dtqg_last_error': error,
    });
  }

  // === FACILITY ===

  Future<Map<String, dynamic>> getFacility() async {
    final f = await (_db.select(_db.clinicFacility)
          ..where((t) => t.id.equals('default')))
        .getSingleOrNull();
    return {
      'ma_cskcb': f?.maCskcb ?? '',
      'name': f?.name ?? '',
      'address': f?.address ?? '',
      'phone': f?.phone ?? '',
      'ma_lien_thong_dtqg': f?.maLienThongDtqg,
      'ma_dinh_danh_cung_ung': f?.maDinhDanhCungUng ?? '',
    };
  }

  Future<void> saveFacility(Map<String, dynamic> data) async {
    final cs = (data['ma_cskcb'] as String? ?? '').trim().toLowerCase();
    await _db.into(_db.clinicFacility).insertOnConflictUpdate(
          ClinicFacilityCompanion(
            id: const Value('default'),
            maCskcb: Value(cs),
            name: Value((data['name'] as String? ?? '').trim()),
            address: Value((data['address'] as String? ?? '').trim()),
            phone: Value((data['phone'] as String? ?? '').trim()),
            maLienThongDtqg: Value(cs.length == 5 ? '01$cs' : null),
            maDinhDanhCungUng: Value(
                (data['ma_dinh_danh_cung_ung'] as String? ?? '').trim()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    SyncService().queueMutation('clinic_facility', 'update', {
      'id': 'default',
      'ma_cskcb': cs,
      'name': data['name'],
      'address': data['address'],
      'phone': data['phone'],
      'ma_dinh_danh_cung_ung': (data['ma_dinh_danh_cung_ung'] as String? ?? '').trim(),
    });
  }

  /// Trừ tồn từng dòng và ghi stock move. PHẢI gọi trong một transaction; ném
  /// lỗi nếu thiếu tồn để cả transaction hoàn tác.
  Future<void> _decrementStock(
      List<Map<String, dynamic>> items, List<void Function()> pendingSync) async {
    for (final item in items) {
      final quant = await _supplyChain.stockQuantsDao
          .getStockQuantByProductId(item['product_id']);
      final available = quant?.quantity ?? 0.0;
      final needed = (item['quantity'] as num).toDouble();
      if (quant == null || available < needed) {
        throw Exception(
            'Không đủ tồn kho cho "${item['medicine_name']}" (cần $needed, còn $available)');
      }

      await _supplyChain.stockQuantsDao
          .updateStockQuant(quant.copyWith(quantity: quant.quantity - needed));

      final moveId = const Uuid().v4();
      await _supplyChain.stockMovesDao.insertStockMove(StockMovesCompanion.insert(
        id: moveId,
        productId: item['product_id'],
        quantity: needed,
        sourceLocationId: 'MAIN',
        destLocationId: 'DISPENSED',
        status: const Value('done'),
      ));

      pendingSync.add(() {
        SyncService().queueMutation('stock_quants', 'update', {
          'id': quant.id,
          'product_id': item['product_id'],
          'quantity': quant.quantity - needed,
        });
        SyncService().queueMutation('stock_moves', 'insert', {
          'id': moveId,
          'product_id': item['product_id'],
          'quantity': needed,
          'source_location_id': 'MAIN',
          'dest_location_id': 'DISPENSED',
          'status': 'done',
        });
      });
    }
  }

  /// Bán thuốc theo đơn điện tử cho khách ngoài (POS): trừ tồn các dòng
  /// `{product_id, medicine_name, quantity}` trong một transaction.
  Future<void> dispenseLines(List<Map<String, dynamic>> lines) async {
    final pendingSync = <void Function()>[];
    await _db.transaction(() => _decrementStock(lines, pendingSync));
    for (final queue in pendingSync) {
      queue();
    }
  }

  /// Marks a prescription as dispensed and decrements pharmacy stock for
  /// each line item. Throws if any item has insufficient stock — no partial
  /// dispense.
  Future<void> dispensePrescription(String prescriptionId) async {
    final prescription = await (_db.select(_db.prescriptions)
          ..where((tbl) => tbl.id.equals(prescriptionId)))
        .getSingleOrNull();
    if (prescription == null) {
      throw Exception('Prescription not found: $prescriptionId');
    }
    if (prescription.status == 'dispensed') {
      throw Exception('Prescription already dispensed');
    }

    final items = await getPrescriptionItems(prescriptionId);
    final pendingSync = <void Function()>[];

    // One DB transaction: validation, stock decrement, stock moves and status
    // change commit together or not at all.
    await _db.transaction(() async {
      await _decrementStock(items, pendingSync);

      await (_db.update(_db.prescriptions)
            ..where((tbl) => tbl.id.equals(prescriptionId)))
          .write(const PrescriptionsCompanion(status: Value('dispensed')));
    });

    // Queue sync only after the local transaction has committed.
    for (final queue in pendingSync) {
      queue();
    }

    SyncService().queueMutation(
        'prescriptions', 'update', {'id': prescriptionId, 'status': 'dispensed'});
  }

  /// Prescriptions awaiting dispense (or all, newest first) with patient name
  /// and line items — feeds the pharmacy queue on desktop/tablet.
  Future<List<Map<String, dynamic>>> getPrescriptionsByStatus(
      {String status = 'pending'}) async {
    final rows = await (_db.select(_db.prescriptions)
          ..where((tbl) => tbl.status.equals(status))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.prescriptionDate)]))
        .get();
    final patients = {for (final p in await getPatients()) p['id']: p};
    final doctors = {for (final d in await getDoctors()) d['id']: d};
    final result = <Map<String, dynamic>>[];
    for (final p in rows) {
      final items = await getPrescriptionItems(p.id);
      result.add({
        'id': p.id,
        'visit_id': p.visitId,
        'patient_id': p.patientId,
        'patient_name': patients[p.patientId]?['full_name'] ?? '',
        'doctor_id': p.doctorId,
        'doctor_name': doctors[p.doctorId]?['name'] ?? '',
        'prescription_date': p.prescriptionDate.toIso8601String(),
        'status': p.status,
        'notes': p.notes,
        ..._dtqgFields(p),
        'items': items,
        'total': items.fold<double>(
            0, (sum, i) => sum + (i['total_price'] as num).toDouble()),
      });
    }
    return result;
  }

  // === MEDICINES (pharmacy inventory, backed by supply_chain Products) ===

  Future<List<Map<String, dynamic>>> getMedicines() async {
    final products = await _supplyChain.getProductsWithStock();
    return products
        .where((p) => (p['custom_fields'] as Map)['category'] == 'medicine')
        .toList();
  }

  Future<String> addMedicine({
    required String name,
    required double price,
    required double cost,
    required double stock,
    String? barcode,
    String? batchNumber,
    String? expiryDate,
    bool requiresPrescription = false,
    String dosageUnit = 'viên',
    String? maThuocCucQldd,
    String? bietDuoc,
  }) async {
    final id = const Uuid().v4();
    final sku = 'MED-${id.substring(0, 8).toUpperCase()}';
    await _supplyChain.addProductWithStock(
      id: id,
      sku: sku,
      name: name,
      price: price,
      cost: cost,
      stock: stock,
      barcode: barcode,
      locationId: 'MAIN',
      customFields: {
        'category': 'medicine',
        'batch_number': batchNumber,
        'expiry_date': expiryDate,
        'requires_prescription': requiresPrescription,
        'dosage_unit': dosageUnit,
        'ma_thuoc_cuc_qldd': maThuocCucQldd,
        'biet_duoc': bietDuoc,
        'don_vi_tinh': dosageUnit,
      },
    );
    return id;
  }

  // === SAMPLE DATA (for testing) ===

  /// Populates the clinic with a handful of doctors, patients, pharmacy
  /// stock and an appointment so the visit/prescription flow can be tried
  /// out end-to-end. No-ops if patients already exist, so it's safe to call
  /// repeatedly.
  Future<void> seedSampleData() async {
    if ((await getPatients()).isNotEmpty) return;

    final doctorId1 = await addDoctor({
      'name': 'Nguyễn Thị Hồng',
      'specialty': 'Nội tổng quát',
      'phone': '0909111222',
      'email': 'bs.hong@example.com',
    });
    final doctorId2 = await addDoctor({
      'name': 'Phạm Văn Đức',
      'specialty': 'Nhi khoa',
      'phone': '0909333444',
      'email': 'bs.duc@example.com',
    });

    final patientId1 = await addPatient({
      'full_name': 'Nguyễn Văn An',
      'dob': DateTime(1985, 3, 12).toIso8601String(),
      'gender': 'male',
      'phone': '0901234567',
      'address': '12 Trần Hưng Đạo, TP. Long Xuyên, An Giang',
      'id_number': 'DN4090185001234',
    });
    await addPatient({
      'full_name': 'Trần Thị Bình',
      'dob': DateTime(1992, 7, 20).toIso8601String(),
      'gender': 'female',
      'phone': '0912345678',
      'address': '45 Nguyễn Huệ, TP. Long Xuyên, An Giang',
      'id_number': 'DN4092192005678',
    });
    final now = DateTime.now();
    final childPatientId = await addPatient({
      'full_name': 'Lê Minh Khôi',
      'dob': DateTime(now.year - 4, 6, 1).toIso8601String(),
      'gender': 'male',
      'phone': '0987654321',
      'address': '78 Lý Thường Kiệt, TP. Long Xuyên, An Giang',
      'id_number': null,
    });

    await addMedicine(
      name: 'Paracetamol 500mg',
      price: 1000,
      cost: 600,
      stock: 500,
      batchNumber: 'PC24001',
      expiryDate: DateTime(now.year + 2, 1, 1).toIso8601String(),
      dosageUnit: 'viên',
    );
    await addMedicine(
      name: 'Amoxicillin 500mg',
      price: 2500,
      cost: 1500,
      stock: 300,
      batchNumber: 'AMX24007',
      expiryDate: DateTime(now.year + 1, 6, 1).toIso8601String(),
      requiresPrescription: true,
      dosageUnit: 'viên',
    );
    await addMedicine(
      name: 'Vitamin C 500mg',
      price: 800,
      cost: 400,
      stock: 400,
      batchNumber: 'VTC24003',
      expiryDate: DateTime(now.year + 2, 3, 1).toIso8601String(),
      dosageUnit: 'viên',
    );
    await addMedicine(
      name: 'Oresol (bù nước điện giải)',
      price: 3000,
      cost: 1800,
      stock: 200,
      batchNumber: 'ORS24011',
      expiryDate: DateTime(now.year + 2, 8, 1).toIso8601String(),
      dosageUnit: 'gói',
    );
    await addMedicine(
      name: 'Cefixim 200mg',
      price: 4500,
      cost: 3000,
      stock: 150,
      batchNumber: 'CFX24002',
      expiryDate: DateTime(now.year + 1, 9, 1).toIso8601String(),
      requiresPrescription: true,
      dosageUnit: 'viên',
    );
    await addMedicine(
      name: 'Siro ho Prospan',
      price: 45000,
      cost: 30000,
      stock: 60,
      batchNumber: 'PSP24005',
      expiryDate: DateTime(now.year + 1, 12, 1).toIso8601String(),
      dosageUnit: 'chai',
    );

    await addAppointment({
      'patient_id': patientId1,
      'doctor_id': doctorId1,
      'scheduled_at':
          DateTime(now.year, now.month, now.day, 9, 0).add(const Duration(days: 1)).toIso8601String(),
      'reason': 'Khám tổng quát định kỳ',
      'status': 'scheduled',
    });
    await addAppointment({
      'patient_id': childPatientId,
      'doctor_id': doctorId2,
      'scheduled_at':
          DateTime(now.year, now.month, now.day, 14, 30).toIso8601String(),
      'reason': 'Sốt, ho, sổ mũi 2 ngày',
      'status': 'scheduled',
    });
  }
}
