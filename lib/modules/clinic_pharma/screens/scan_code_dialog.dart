import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Lấy mã đơn thuốc `xxxxxyyyyyyy-z` từ nội dung quét được: mã trần, hoặc
/// nằm trong URL / chuỗi dài hơn (một số máy quét thêm tiền tố, ký tự xuống dòng).
String? extractMaDonThuoc(String raw) {
  final m = RegExp(r'(?<![0-9a-z])([0-9a-z]{12}-[chny])(?![0-9a-z])', caseSensitive: false)
      .firstMatch(raw.trim());
  return m?.group(1)!.toLowerCase();
}

/// Camera quét mã đơn thuốc (QR/barcode). Máy tính để bàn Windows/Linux không
/// có camera plugin: dùng súng quét USB (gõ phím vào ô nhập) thay vì hộp thoại này.
bool get cameraScanSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

Future<String?> scanMaDonThuoc(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => const _ScanDialog(),
  );
}

class _ScanDialog extends StatefulWidget {
  const _ScanDialog();

  @override
  State<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<_ScanDialog> {
  bool _handled = false; // mobile_scanner bắn liên tục khi camera còn trỏ vào mã
  String? _hint;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final code = extractMaDonThuoc(raw);
      if (code != null) {
        _handled = true;
        Navigator.of(context).pop(code);
        return;
      }
      if (mounted) setState(() => _hint = 'Mã quét được không phải mã đơn thuốc.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quét mã đơn thuốc'),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(onDetect: _onDetect),
          )),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_hint!, style: const TextStyle(color: Colors.orange)),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy'))],
    );
  }
}
