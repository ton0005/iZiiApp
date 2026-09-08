import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../enrollment_service.dart';
import '../nfc_enrollment_service.dart';

/// Màn hình THIẾT BỊ MỚI: quét QR hoặc chạm thẻ NFC để đăng ký (B3 + B4).
///
/// Công nhân không phải gõ gì cả — đó là điểm mấu chốt. Chuỗi token 32 ký tự
/// ngẫu nhiên là bất khả thi khi đeo găng trong phòng trồng.
class EnrollDeviceScreen extends StatefulWidget {
  const EnrollDeviceScreen({super.key});

  @override
  State<EnrollDeviceScreen> createState() => _EnrollDeviceScreenState();
}

class _EnrollDeviceScreenState extends State<EnrollDeviceScreen> {
  final _service = EnrollmentService();
  final _nfc = NfcEnrollmentService();

  bool _nfcAvailable = false;
  bool _busy = false;
  String? _status;
  String? _error;
  EnrollmentResult? _result;

  /// Chặn quét lặp: mobile_scanner bắn liên tục cùng một mã khi camera còn trỏ
  /// vào QR, không khoá thì sẽ gọi enroll hàng chục lần và các lần sau đều
  /// thất bại vì vé chỉ dùng được một lần.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _nfc.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });
  }

  @override
  void dispose() {
    _nfc.stop();
    super.dispose();
  }

  Future<void> _enroll(EnrollmentTicket ticket) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Registering with the server...';
    });
    try {
      final result = await _service.enroll(ticket);
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
        _status = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = e.toString();
        // Cho quét lại sau khi lỗi — có thể admin vừa cấp mã mới.
        _handled = false;
      });
    }
  }

  void _onQrDetect(BarcodeCapture capture) {
    if (_handled || _busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final ticket = EnrollmentTicket.tryParse(raw);
      if (ticket != null) {
        _handled = true;
        _enroll(ticket);
        return;
      } else {
        if (mounted && _error == null) {
          setState(() {
            _error = 'Invalid enrollment QR code. Please request a new one from your administrator.';
          });
        }
      }
    }
  }

  Future<void> _scanNfc() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _status = 'Tap the device against the enrollment tag...';
    });
    try {
      final ticket = await _nfc.readTicket(
        onStatus: (m) => mounted ? setState(() => _status = m) : null,
      );
      await _enroll(ticket);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildSuccess();

    return Scaffold(
      appBar: AppBar(title: const Text('Enroll Device')),
      body: Column(
        children: [
          // ── Vùng camera quét QR ─────────────────────────────────────────
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(onDetect: _onQrDetect),
                // Khung ngắm
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),

          // ── Bảng điều khiển ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Point the camera at the QR code provided by your administrator to enroll this device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_nfcAvailable) ...[
                  const SizedBox(height: 14),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or', style: TextStyle(fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _scanNfc,
                    icon: const Icon(Icons.nfc_rounded),
                    label: const Text('Tap NFC Tag to Enroll'),
                  ),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(_status!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.blue)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final r = _result!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 76, color: Colors.green),
              const SizedBox(height: 20),
              Text('Enrollment Successful',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'This device has been enrolled on ${r.serverId} (zone ${r.zone}).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Device ID: ${r.deviceId}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Start Using Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
