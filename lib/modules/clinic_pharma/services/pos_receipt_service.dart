import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptLine {
  final String name;
  final String unit;
  final double quantity;
  final double unitPrice;
  final bool substitute;
  final String? prescribedName; // thuốc gốc trong đơn khi có thay thế

  const ReceiptLine({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.substitute = false,
    this.prescribedName,
  });

  double get total => quantity * unitPrice;
}

/// Biên nhận bán thuốc theo đơn điện tử (khổ cuộn 80mm). Có mã hóa đơn và mã
/// đơn thuốc đúng như đã báo cáo lên Đơn thuốc quốc gia để đối chiếu khi cần.
class PosReceiptService {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    _regular ??= pw.Font.ttf(
        (await rootBundle.load('assets/fonts/NotoSans-Regular.ttf')).buffer.asByteData());
    _bold ??= pw.Font.ttf(
        (await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')).buffer.asByteData());
  }

  static String money(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '$b đ';
  }

  static Future<Uint8List> generate({
    required String pharmacyName,
    required String pharmacyAddress,
    required String pharmacyPhone,
    required String invoiceCode,
    required String maDonThuoc,
    required String patientName,
    required List<ReceiptLine> lines,
    DateTime? soldAt,
    String? pharmacist,
    bool pendingSync = false,
  }) async {
    await _ensureFonts();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
          base: _regular!, bold: _bold!, italic: _regular!, boldItalic: _bold!),
    );
    final at = soldAt ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final when = '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
    final total = lines.fold<double>(0, (s, l) => s + l.total);
    const small = pw.TextStyle(fontSize: 8.5);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(10),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(
            child: pw.Text(pharmacyName,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
        if (pharmacyAddress.isNotEmpty) pw.Center(child: pw.Text(pharmacyAddress, style: small)),
        if (pharmacyPhone.isNotEmpty) pw.Center(child: pw.Text('ĐT: $pharmacyPhone', style: small)),
        pw.SizedBox(height: 6),
        pw.Center(
            child: pw.Text('HÓA ĐƠN BÁN THUỐC THEO ĐƠN',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        pw.Text('Số HĐ: $invoiceCode', style: small),
        pw.Text('Ngày: $when', style: small),
        pw.Text('Mã đơn thuốc: $maDonThuoc', style: small),
        pw.Text('Người bệnh: $patientName', style: small),
        pw.Divider(thickness: 0.5),
        for (final l in lines) ...[
          pw.Text(l.name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          if (l.substitute)
            pw.Text('(thay thế cho: ${l.prescribedName ?? 'thuốc trong đơn'})',
                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(
                '${l.quantity % 1 == 0 ? l.quantity.toInt() : l.quantity} ${l.unit} × ${money(l.unitPrice)}',
                style: small),
            pw.Text(money(l.total), style: small),
          ]),
          pw.SizedBox(height: 3),
        ],
        pw.Divider(thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TỔNG CỘNG', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(money(total), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 6),
        if ((pharmacist ?? '').isNotEmpty) pw.Text('Dược sĩ: $pharmacist', style: small),
        if (pendingSync)
          pw.Text('Lưu ý: chưa cập nhật được lên hệ thống Đơn thuốc quốc gia, sẽ tự gửi lại.',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text('Cảm ơn quý khách!', style: small)),
      ]),
    ));
    return doc.save();
  }
}
