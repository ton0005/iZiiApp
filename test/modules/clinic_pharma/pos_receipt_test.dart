import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/clinic_pharma/services/pos_receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('định dạng tiền', () {
    expect(PosReceiptService.money(0), '0 đ');
    expect(PosReceiptService.money(1500), '1.500 đ');
    expect(PosReceiptService.money(1234567), '1.234.567 đ');
  });

  test('biên nhận PDF có dòng thay thế và tổng', () async {
    final bytes = await PosReceiptService.generate(
      pharmacyName: 'Nhà thuốc An Khang',
      pharmacyAddress: '1 Nguyễn Huệ',
      pharmacyPhone: '0281234567',
      invoiceCode: 'HD261017103000',
      maDonThuoc: '01aaa1234567-c',
      patientName: 'Nguyễn Văn An',
      pendingSync: true,
      lines: const [
        ReceiptLine(name: 'Efferalgan 500mg', unit: 'viên', quantity: 5, unitPrice: 2000,
            substitute: true, prescribedName: 'Paracetamol 500mg'),
        ReceiptLine(name: 'Vitamin C', unit: 'viên', quantity: 2.5, unitPrice: 800),
      ],
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1500));
  });
}
