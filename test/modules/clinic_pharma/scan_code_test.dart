import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/clinic_pharma/screens/scan_code_dialog.dart';

void main() {
  test('rút mã đơn thuốc từ nội dung quét', () {
    expect(extractMaDonThuoc('01aaa1234567-c'), '01aaa1234567-c');
    expect(extractMaDonThuoc('  01AAA1234567-C\r\n'), '01aaa1234567-c');
    expect(extractMaDonThuoc('https://donthuocquocgia.vn/don/01aaa1234567-c?x=1'), '01aaa1234567-c');
    expect(extractMaDonThuoc('01aaa1234567-n'), '01aaa1234567-n');
  });

  test('từ chối nội dung không phải mã đơn', () {
    expect(extractMaDonThuoc('hello'), isNull);
    expect(extractMaDonThuoc('01aaa1234567-x'), isNull);
    expect(extractMaDonThuoc('01aaa123456-c'), isNull);
    expect(extractMaDonThuoc('x01aaa1234567-cz'), isNull);
    expect(extractMaDonThuoc(''), isNull);
  });
}
