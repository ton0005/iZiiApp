import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/clinic_pharma/services/dtqg_rules.dart';

Map<String, dynamic> _patient({String? dob = '1990-05-01T00:00:00.000'}) => {
      'full_name': 'Nguyễn Văn An',
      'dob': dob,
      'gender': 'male',
      'phone': '0901234567',
      'address': '12 Trần Hưng Đạo',
    };

Map<String, dynamic> _doctor() =>
    {'duoc_ke_don': true, 'dtqg_status': 'active'};

Map<String, dynamic> _item() => {
      'medicine_name': 'Paracetamol 500mg',
      'ma_thuoc_cuc_qldd': 'VD-1234-20',
      'biet_duoc': 'Paracetamol',
      'don_vi_tinh': 'viên',
      'quantity': 10.0,
      'dosage_instructions': 'Uống 1 viên x 3 lần/ngày',
    };

List<String> _validate({
  Map<String, dynamic>? patient,
  Map<String, dynamic>? doctor,
  List<Map<String, dynamic>>? items,
  double? canNang,
  String? giamHo,
  int? hinhThuc = 2,
  List<Map<String, dynamic>>? dx,
}) =>
    DtqgRules.validate(
      patient: patient ?? _patient(),
      doctor: doctor ?? _doctor(),
      diagnoses: dx ?? [{'ma_benh': 'J00', 'ten_benh': 'Viêm mũi họng cấp'}],
      items: items ?? [_item()],
      canNang: canNang,
      nguoiGiamHo: giamHo,
      hinhThucDieuTri: hinhThuc,
      now: DateTime(2026, 10, 16),
    );

void main() {
  group('maDonThuoc', () {
    test('14 ký tự đúng cấu trúc', () {
      final code = DtqgRules.generateMaDonThuoc('01AAA', random: Random(1));
      expect(code.length, 14);
      expect(code.startsWith('01aaa'), isTrue);
      expect(code.endsWith('-c'), isTrue);
      expect(DtqgRules.isValidMaDonThuoc(code), isTrue);
    });
    test('mã cơ sở sai độ dài bị từ chối', () {
      expect(() => DtqgRules.generateMaDonThuoc('123'), throwsArgumentError);
    });
    test('nhận diện mã sai', () {
      expect(DtqgRules.isValidMaDonThuoc('01aaa1234567-x'), isFalse);
      expect(DtqgRules.isValidMaDonThuoc('01aaa123456-c'), isFalse);
      expect(DtqgRules.isValidMaDonThuoc(null), isFalse);
    });
  });

  group('định dạng & ánh xạ', () {
    test('giới tính: 1 chưa rõ, 2 Nam, 3 Nữ', () {
      expect(DtqgRules.mapGender('male'), 2);
      expect(DtqgRules.mapGender('female'), 3);
      expect(DtqgRules.mapGender('other'), 1);
      expect(DtqgRules.mapGender(null), 1);
    });
    test('ngày', () {
      expect(DtqgRules.formatDate(DateTime(2026, 3, 5)), '05/03/2026');
      expect(DtqgRules.formatDateTime(DateTime(2026, 3, 5, 7, 4, 9)),
          '2026-03-05 07:04:09');
    });
    test('mã liên thông bác sĩ bỏ dấu /', () {
      expect(DtqgRules.maLienThongBacSi('001234/AG-CCHN'), '01001234AG-CCHN');
    });
    test('tuổi theo tháng', () {
      final now = DateTime(2026, 10, 16);
      expect(DtqgRules.ageInMonths(DateTime(2020, 10, 17), now), 71);
      expect(DtqgRules.isUnder72Months(DateTime(2020, 10, 17), now), isTrue);
      expect(DtqgRules.isUnder72Months(DateTime(2020, 10, 16), now), isFalse);
    });
  });

  group('validate', () {
    test('đơn hợp lệ', () => expect(_validate(), isEmpty));

    test('trẻ < 72 tháng cần cân nặng và người giám hộ', () {
      final p = _patient(dob: DateTime(2023, 1, 1).toIso8601String());
      final e = _validate(patient: p);
      expect(e.where((x) => x.contains('cân nặng')), isNotEmpty);
      expect(e.where((x) => x.contains('người giám hộ')), isNotEmpty);
      expect(_validate(patient: p, canNang: 12, giamHo: 'Mẹ: Lan, 0909'), isEmpty);
    });

    test('thiếu số điện thoại', () {
      final p = _patient()..['phone'] = '';
      expect(_validate(patient: p).single, contains('điện thoại'));
    });

    test('CCCD phải đủ 12 số', () {
      final p = _patient()..['so_cccd'] = '123';
      expect(_validate(patient: p).single, contains('12 chữ số'));
    });

    test('bác sĩ chưa được duyệt mã liên thông', () {
      final e = _validate(doctor: {'duoc_ke_don': true, 'dtqg_status': 'pending'});
      expect(e.single, contains('mã liên thông'));
    });

    test('dòng thuốc thiếu mã thuốc / vượt 20 ký tự', () {
      final bad = _item()..['ma_thuoc_cuc_qldd'] = '';
      expect(_validate(items: [bad]).single, contains('mã thuốc'));
      final long = _item()..['ma_thuoc_cuc_qldd'] = 'x' * 21;
      expect(_validate(items: [long]).single, contains('tối đa 20'));
    });

    test('thiếu chẩn đoán / hình thức điều trị / thuốc', () {
      expect(_validate(dx: []).single, contains('chẩn đoán'));
      expect(_validate(hinhThuc: null).single, contains('hình thức điều trị'));
      expect(_validate(items: []).single, contains('chưa có thuốc'));
    });
  });

  test('payload gui-don-thuoc', () {
    final body = DtqgRules.buildGuiDonPayload(
      maDonThuoc: '01aaa1234567-c',
      patient: _patient()..['so_cccd'] = '012345678901',
      diagnoses: [
        {'ma_benh': 'J00', 'ten_benh': 'Viêm mũi họng cấp', 'ket_luan': 'Nhẹ'}
      ],
      items: [_item()],
      keDonAt: DateTime(2026, 10, 16, 9, 30, 0),
      hinhThucDieuTri: 2,
      ngayTaiKham: 7,
    );
    expect(body['loai_don_thuoc'], 'c');
    expect(body['ngay_sinh_benh_nhan'], '01/05/1990');
    expect(body['gioi_tinh'], 2);
    expect(body['ngay_gio_ke_don'], '2026-10-16 09:30:00');
    expect(body['ma_dinh_danh_cong_dan'], '012345678901');
    expect((body['thong_tin_don_thuoc'] as List).single['ma_thuoc'], 'VD-1234-20');
    expect((body['chan_doan'] as List).single['ma_benh'], 'J00');
    expect(body['ngay_tai_kham'], 7);
  });
}
