import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../enrollment_service.dart';
import '../nfc_enrollment_service.dart';

/// Màn hình QUẢN LÝ: cấp vé mời cho thiết bị mới (B3 + B4).
///
/// Vé hiển thị dưới dạng QR và ghi được lên thẻ NFC. Cả hai chỉ là hai cách
/// truyền cùng một vé — logic phía sau dùng chung.
class IssueEnrollmentScreen extends StatefulWidget {
  const IssueEnrollmentScreen({super.key});

  @override
  State<IssueEnrollmentScreen> createState() => _IssueEnrollmentScreenState();
}

class _IssueEnrollmentScreenState extends State<IssueEnrollmentScreen> {
  final _service = EnrollmentService();
  final _nfc = NfcEnrollmentService();
  final _noteController = TextEditingController();

  EnrollmentTicket? _ticket;
  bool _loading = false;
  String? _error;
  String? _nfcStatus;
  bool _nfcAvailable = false;
  Timer? _countdown;
  int _secondsLeft = 0;

  // ── Chế độ thiết bị ───────────────────────────────────────────────────────
  String _profile = 'shared';
  final _ownerIdController = TextEditingController();
  final _ownerNameController = TextEditingController();
  int? _sessionMaxHours; // null = mặc định theo chế độ

  @override
  void initState() {
    super.initState();
    _nfc.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _noteController.dispose();
    _ownerIdController.dispose();
    _ownerNameController.dispose();
    _nfc.stop();
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() {
      _loading = true;
      _error = null;
      _nfcStatus = null;
    });
    try {
      final ticket = await _service.requestTicket(
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        profile: _profile,
        ownerUserId:
            _profile == 'personal' ? _ownerIdController.text.trim() : null,
        ownerUserName:
            _profile == 'personal' ? _ownerNameController.text.trim() : null,
        sessionMaxHours: _sessionMaxHours,
      );
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
        _secondsLeft = ticket.secondsLeft;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Đồng hồ đếm ngược — vé hết hạn thì QR trên màn hình cũng vô dụng, phải
  /// cho người dùng thấy rõ thay vì để họ quét một mã đã chết.
  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final left = _ticket?.secondsLeft ?? 0;
      setState(() => _secondsLeft = left);
      if (left <= 0) t.cancel();
    });
  }

  Future<void> _writeToNfc() async {
    final ticket = _ticket;
    if (ticket == null) return;
    setState(() => _nfcStatus = 'Waiting for NFC card...');
    try {
      await _nfc.writeTicket(ticket,
          onStatus: (m) => mounted ? setState(() => _nfcStatus = m) : null);
    } catch (e) {
      if (mounted) setState(() => _nfcStatus = '❌ $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ticket = _ticket;
    final expired = ticket != null && _secondsLeft <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Enrollment Ticket (QR/NFC)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoBox(
              isDark,
              'This ticket is a one-time use invitation, not a system password. '
              'It will expire in a few minutes and can only be registered to one device — '
              'even if someone screenshots the screen, they cannot reuse it.',
            ),
            const SizedBox(height: 16),

            // ── Chọn chế độ thiết bị ──────────────────────────────────────
            Text('Device Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'shared',
                  label: Text('Sharing Device'),
                  icon: Icon(Icons.tablet_android_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'personal',
                  label: Text('Personal Device'),
                  icon: Icon(Icons.phone_iphone_rounded, size: 16),
                ),
              ],
              selected: {_profile},
              onSelectionChanged: (s) => setState(() {
                _profile = s.first;
                // Máy cá nhân mặc định không giới hạn giờ ca; máy dùng chung
                // dùng mặc định 12 giờ của hệ thống.
                _sessionMaxHours = _profile == 'personal' ? 0 : null;
              }),
            ),
            const SizedBox(height: 8),
            _infoBox(
              isDark,
              _profile == 'shared'
                  ? 'The tablet is placed in the room and shared across multiple shifts. '
                      'Users MUST check in at the beginning of each shift; the session automatically expires after 12 hours.'
                  : 'Personal iPhone/iPad belonging to the Manager or Supervisor, taken home after work. '
                      'NO daily check‑in required _ '
                      'the identity was already established at the time the device was issued.',
            ),

            // ── Chủ máy (chỉ với máy cá nhân) ─────────────────────────────
            if (_profile == 'personal') ...[
              const SizedBox(height: 14),
              TextField(
                controller: _ownerIdController,
                // Nút "Cấp mã" bật/tắt theo ô này nên phải vẽ lại mỗi lần gõ.
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'UserID *',
                  hintText: 'e.g.: 305000',
                  border: OutlineInputBorder(),
                  helperText:
                      'Required for personal devices. Must match the UserID of the Manager/Supervisor in the system.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'e.g.: John Doe (Manager)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _sessionMaxHours ?? 0,
                decoration: const InputDecoration(
                  labelText: 'Session Duration Limit (hours)',
                  border: OutlineInputBorder(),
                  helperText:
                      'Only applies when the device owner manually taps "Start Shift"',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Unlimited')),
                  DropdownMenuItem(value: 8, child: Text('8 hours')),
                  DropdownMenuItem(value: 12, child: Text('12 hours')),
                  DropdownMenuItem(value: 16, child: Text('16 hours')),
                  DropdownMenuItem(value: 24, child: Text('24 hours')),
                ],
                onChanged: (v) => setState(() => _sessionMaxHours = v),
              ),
            ],

            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g.: Tablet in Room M1 — Morning Shift',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            FilledButton.icon(
              // Máy cá nhân bắt buộc có mã chủ máy — server cũng từ chối nếu
              // thiếu, chặn ở đây để báo sớm thay vì để người dùng bấm rồi lỗi.
              onPressed: (_loading ||
                      (_profile == 'personal' &&
                          _ownerIdController.text.trim().isEmpty))
                  ? null
                  : _issue,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.confirmation_number_rounded),
              label: Text(_loading
                  ? 'Creating...'
                  : (ticket == null
                      ? 'Create Enrollment Code'
                      : 'Create New Code')),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBox(_error!),
            ],

            if (ticket != null) ...[
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  // Làm mờ QR khi hết hạn — tránh việc công nhân quét mã chết
                  // rồi báo "app lỗi".
                  child: Opacity(
                    opacity: expired ? 0.15 : 1.0,
                    child: QrImageView(
                      data: ticket.toUri(),
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  expired
                      ? '⏰ Code has expired — tap "Create New Code"'
                      : 'Valid for ${_fmt(_secondsLeft)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: expired ? Colors.redAccent : Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                    'Server: ${ticket.serverUrl}   ·   Zone: ${ticket.zone}',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black45)),
              ),
              const SizedBox(height: 8),
              // Nhắc lại chế độ trên màn hình QR: quản lý hay cấp liên tiếp
              // nhiều mã, dễ quên mã đang hiện là loại nào.
              Center(
                child: Chip(
                  avatar: Icon(
                    _profile == 'personal'
                        ? Icons.phone_iphone_rounded
                        : Icons.tablet_android_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _profile == 'personal'
                        ? 'Personal Device · ${_ownerNameController.text.trim().isEmpty ? _ownerIdController.text.trim() : _ownerNameController.text.trim()}'
                        : 'Shared Device · Requires attendance check-in each shift',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),

              // ── Ghi lên thẻ NFC ──────────────────────────────────────────
              Text('Or write to NFC card',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                _nfcAvailable
                    ? 'Use NTAG213 or higher. Workers just need to tap the device on the card, '
                        'no camera needed — convenient when wearing gloves or in low-light conditions.'
                    : 'This device does not have NFC or NFC is turned off. Use the QR code above.',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: (!_nfcAvailable || expired) ? null : _writeToNfc,
                icon: const Icon(Icons.nfc_rounded),
                label: const Text('Write Code to NFC Card'),
              ),
              if (_nfcStatus != null) ...[
                const SizedBox(height: 10),
                Text(_nfcStatus!, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';

  Widget _infoBox(bool isDark, String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 12, height: 1.45))),
          ],
        ),
      );

  Widget _errorBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 16, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}
