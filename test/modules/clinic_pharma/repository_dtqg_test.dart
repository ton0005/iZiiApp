import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/clinic_pharma/repository.dart';
import 'package:izii_app/modules/clinic_pharma/services/dtqg_rules.dart';

void main() {
  late AppDatabase db;
  late ClinicPharmaRepository repo;
  late String patientId;
  late String medId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = ClinicPharmaRepository(db);
    patientId = await repo.addPatient({'full_name': 'An', 'phone': '0901234567'});
    medId = await repo.addMedicine(
        name: 'Paracetamol', price: 1000, cost: 500, stock: 5,
        maThuocCucQldd: 'VD-1', bietDuoc: 'Paracetamol');
  });

  tearDown(() async => db.close());

  Future<String> makeRx({double qty = 2}) => repo.addPrescriptionWithItems({
        'visit_id': 'v1',
        'patient_id': patientId,
        'chan_doan': [
          {'ma_benh': 'J00', 'ten_benh': 'Viêm mũi họng'}
        ],
      }, [
        {
          'product_id': medId,
          'medicine_name': 'Paracetamol',
          'quantity': qty,
          'unit_price': 1000.0,
          'ma_thuoc_cuc_qldd': 'VD-1',
          'biet_duoc': 'Paracetamol',
          'don_vi_tinh': 'viên',
        }
      ]);

  test('sinh mã đơn khi cơ sở đã có mã CSKCB, duy nhất và đúng định dạng', () async {
    await repo.saveFacility({'ma_cskcb': '01AAA', 'name': 'PK Test'});
    final a = await makeRx();
    final b = await makeRx();
    final rxs = await repo.getPrescriptionsByStatus();
    final codes = rxs.map((r) => r['ma_don_thuoc'] as String?).toList();
    expect(codes.every(DtqgRules.isValidMaDonThuoc), isTrue);
    expect(codes.toSet().length, 2);
    expect(a == b, isFalse);
    expect((await repo.getFacility())['ma_lien_thong_dtqg'], '0101aaa');
  });

  test('chưa có mã CSKCB: đơn lưu draft, chưa có mã', () async {
    await makeRx();
    final rx = (await repo.getPrescriptionsByStatus()).single;
    expect(rx['ma_don_thuoc'], isNull);
    expect(rx['dtqg_status'], 'draft');
    expect(rx['items'][0]['ma_thuoc_cuc_qldd'], 'VD-1');
  });

  test('đơn đã gửi không sửa/xóa được nhưng vẫn cấp phát được', () async {
    final id = await makeRx();
    await repo.setDtqgStatus(id, 'sent');
    expect(() => repo.updatePrescriptionContent(id, {'loi_dan': 'x'}), throwsException);
    expect(() => repo.deletePrescription(id), throwsException);
    await repo.dispensePrescription(id);
    final dispensed = await repo.getPrescriptionsByStatus(status: 'dispensed');
    expect(dispensed.single['dtqg_status'], 'sent');
  });

  test('cấp phát thiếu tồn không trừ kho và đơn vẫn pending', () async {
    final id = await makeRx(qty: 99);
    await expectLater(repo.dispensePrescription(id), throwsException);
    expect((await repo.getPrescriptionsByStatus()).single['status'], 'pending');
    final meds = await repo.getMedicines();
    expect(meds.single['stock'], 5);
  });

  test('mã liên thông bác sĩ sinh từ số CCHN', () async {
    await repo.addDoctor({'name': 'BS A', 'so_cchn': '00123/AG-CCHN'});
    final d = (await repo.getDoctors()).single;
    expect(d['ma_lien_thong_dtqg'], '0100123AG-CCHN');
    expect(d['dtqg_status'], 'pending');
  });

  test('bán theo đơn (POS): dispenseLines trừ kho, thiếu tồn thì hoàn tác toàn bộ', () async {
    final other = await repo.addMedicine(name: 'Vitamin C', price: 800, cost: 400, stock: 1);
    await repo.dispenseLines([
      {'product_id': medId, 'medicine_name': 'Paracetamol', 'quantity': 2.0},
    ]);
    var meds = {for (final m in await repo.getMedicines()) m['id']: m['stock']};
    expect(meds[medId], 3);

    // Dòng thứ hai thiếu tồn → dòng đầu cũng không được trừ.
    await expectLater(
        repo.dispenseLines([
          {'product_id': medId, 'medicine_name': 'Paracetamol', 'quantity': 1.0},
          {'product_id': other, 'medicine_name': 'Vitamin C', 'quantity': 5.0},
        ]),
        throwsException);
    meds = {for (final m in await repo.getMedicines()) m['id']: m['stock']};
    expect(meds[medId], 3);
    expect(meds[other], 1);
  });

  test('thuốc lưu mã Cục QLD trong customFields để POS đối chiếu', () async {
    final m = (await repo.getMedicines()).firstWhere((x) => x['id'] == medId);
    expect((m['custom_fields'] as Map)['ma_thuoc_cuc_qldd'], 'VD-1');
  });
}
