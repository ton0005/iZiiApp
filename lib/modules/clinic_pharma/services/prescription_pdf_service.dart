import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders a prescription ("Đơn thuốc") PDF matching the standard Vietnamese
/// health-ministry prescription pad layout: facility header, patient
/// identification block, numbered medicine list with dosage lines, advice
/// and signature block.
class PrescriptionPdfService {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    _regular ??= pw.Font.ttf(
        (await rootBundle.load('assets/fonts/NotoSans-Regular.ttf')).buffer.asByteData());
    _bold ??= pw.Font.ttf(
        (await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')).buffer.asByteData());
  }

  static Future<Uint8List> generate({
    required String facilityAuthority,
    required String facilityName,
    required String facilityPhone,
    String facilityAddress = '',
    required Map<String, dynamic> patient,
    Map<String, dynamic>? doctor,
    required Map<String, dynamic> visit,
    required Map<String, dynamic> prescription,
    required List<Map<String, dynamic>> items,
    String weight = '',
    String advice = '',
    String guardianName = '',
  }) async {
    await _ensureFonts();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _regular!,
        bold: _bold!,
        // Không có font nghiêng riêng: dùng font thường để chữ nghiêng (ngày, ghi chú) vẫn có dấu tiếng Việt.
        italic: _regular!,
        boldItalic: _bold!,
      ),
    );

    final visitDate = DateTime.tryParse(
            prescription['prescription_date'] as String? ?? '') ??
        DateTime.tryParse(visit['visit_date'] as String? ?? '') ??
        DateTime.now();

    final dob = DateTime.tryParse(patient['dob'] as String? ?? '');
    String age = '';
    if (dob != null) {
      final now = DateTime.now();
      var years = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        years--;
      }
      age = years.toString();
    }

    final dobText = dob == null
        ? ''
        : '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
    final insuranceNo = ((patient['ma_the_bhyt'] as String?)?.isNotEmpty ?? false)
        ? patient['ma_the_bhyt'] as String
        : ((patient['so_cccd'] as String?) ?? (patient['id_number'] as String?) ?? '');
    final revisitDays = prescription['ngay_tai_kham'] as int?;
    final gender = patient['gender'] as String?;
    final isMale = gender == 'male';
    final isFemale = gender == 'female';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(facilityAuthority.toUpperCase(),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(facilityName,
                style: const pw.TextStyle(fontSize: 9, decoration: pw.TextDecoration.underline)),
            if (facilityAddress.isNotEmpty)
              pw.Text('Địa chỉ: $facilityAddress', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('ĐT: $facilityPhone', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('ĐƠN THUỐC',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            if ((prescription['ma_don_thuoc'] as String?)?.isNotEmpty ?? false)
              pw.Center(
                child: pw.Column(children: [
                  pw.Text('Mã đơn thuốc: ${prescription['ma_don_thuoc']}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  // Nhà thuốc quét mã này để tra đơn trên Đơn thuốc quốc gia.
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: prescription['ma_don_thuoc'] as String,
                    width: 52,
                    height: 52,
                    drawText: false,
                  ),
                ]),
              ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: _field('Họ tên', (patient['full_name'] as String?) ?? ''),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(flex: 2, child: _field('Ngày sinh', dobText)),
                pw.SizedBox(width: 8),
                pw.Expanded(flex: 1, child: _field('Tuổi', age)),
                pw.SizedBox(width: 8),
                pw.Expanded(flex: 1, child: _field('Cân nặng', weight)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Text('Giới tính: ', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Nam',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: isMale ? pw.FontWeight.bold : pw.FontWeight.normal,
                        decoration: isMale ? pw.TextDecoration.underline : null)),
                pw.SizedBox(width: 12),
                pw.Text('Nữ',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: isFemale ? pw.FontWeight.bold : pw.FontWeight.normal,
                        decoration: isFemale ? pw.TextDecoration.underline : null)),
              ],
            ),
            pw.SizedBox(height: 6),
            _field('Số thẻ BHYT / số định danh công dân (nếu có)', insuranceNo),
            pw.SizedBox(height: 6),
            _field('Địa chỉ liên hệ', (patient['address'] as String?) ?? ''),
            pw.SizedBox(height: 6),
            _field('Số điện thoại liên hệ', (patient['phone'] as String?) ?? ''),
            pw.SizedBox(height: 6),
            _field(
                'Chẩn đoán',
                ((prescription['chan_doan'] as List?)?.isNotEmpty ?? false)
                    ? (prescription['chan_doan'] as List)
                        .map((d) => '${d['ten_benh']} (${d['ma_benh']})')
                        .join('; ')
                    : (visit['diagnosis'] as String?) ?? ''),
            pw.SizedBox(height: 10),
            pw.Text('Thuốc điều trị:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            if (items.isEmpty)
              pw.Text('(Không có thuốc)',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic))
            else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    pw.Text(
                      '${i + 1}. ${items[i]['medicine_name']}  '
                      'SL: ${_formatQty(items[i]['quantity'])} '
                      '${(items[i]['don_vi_tinh'] as String?) ?? (items[i]['dosage_unit'] as String?) ?? ''}',
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, top: 1, bottom: 4),
                      child: pw.Text(
                        (items[i]['dosage_instructions'] as String?)?.isNotEmpty == true
                            ? items[i]['dosage_instructions']
                            : 'Ngày ....... lần, mỗi lần .......',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ],
              ),
            pw.SizedBox(height: 10),
            _field('Lời dặn', advice),
            if (revisitDays != null) ...[
              pw.SizedBox(height: 4),
              _field('Tái khám sau (ngày)', revisitDays.toString()),
            ],
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Ngày ${visitDate.day.toString().padLeft(2, '0')} '
                      'tháng ${visitDate.month.toString().padLeft(2, '0')} '
                      'năm ${visitDate.year}',
                      style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Bác sỹ/Y sỹ khám bệnh',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 36),
                    pw.Text((doctor?['name'] as String?) != null ? 'BS. ${doctor!['name']}' : '',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 0.5),
            pw.Text('Khám lại xin mang theo đơn này',
                style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Tên bố/mẹ của trẻ hoặc người đưa trẻ đến khám bệnh, chữa bệnh:',
              style: const pw.TextStyle(fontSize: 8.5),
            ),
            pw.SizedBox(height: 2),
            _field('Họ tên', guardianName, labelSize: 8.5, valueSize: 8.5),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static String _formatQty(dynamic qty) {
    final n = (qty as num?)?.toDouble() ?? 0;
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  static pw.Widget _field(String label, String value,
      {double labelSize = 9, double valueSize = 9}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('$label: ', style: pw.TextStyle(fontSize: labelSize)),
        pw.Expanded(
          child: pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey700)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(value, style: pw.TextStyle(fontSize: valueSize)),
          ),
        ),
      ],
    );
  }
}
