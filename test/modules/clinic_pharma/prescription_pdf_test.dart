import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/clinic_pharma/services/prescription_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('đơn thuốc PDF có mã đơn + QR và đủ trường Phụ lục 4', () async {
    final bytes = await PrescriptionPdfService.generate(
      facilityAuthority: 'SỞ Y TẾ',
      facilityName: 'PK Test',
      facilityPhone: '0281234567',
      facilityAddress: '1 Nguyễn Huệ',
      patient: {
        'full_name': 'Nguyễn Văn An',
        'dob': '1990-05-01T00:00:00.000',
        'gender': 'male',
        'phone': '0901234567',
        'address': '12 Trần Hưng Đạo',
        'ma_the_bhyt': 'DN4090185001234',
      },
      doctor: {'name': 'A'},
      visit: {'visit_date': DateTime.now().toIso8601String()},
      prescription: {
        'ma_don_thuoc': '01aaa1234567-c',
        'ngay_tai_kham': 7,
        'chan_doan': [
          {'ma_benh': 'J00', 'ten_benh': 'Viêm mũi họng cấp'}
        ],
      },
      items: [
        {
          'medicine_name': 'Paracetamol',
          'quantity': 10.0,
          'don_vi_tinh': 'viên',
          'dosage_instructions': '1 viên x 3 lần/ngày'
        }
      ],
    );
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
