import 'package:flutter/material.dart';

import '../device_user_service.dart';
import '../nfc_enrollment_service.dart';
import '../enrollment_service.dart';
import '../screens/enroll_device_screen.dart';
import '../screens/issue_enrollment_screen.dart';
import '../screens/manage_devices_screen.dart';

/// Nút nổi truy cập nhanh các thao tác đăng ký thiết bị (QR / NFC).
///
/// Đặt trên Home screen Mushrooms để test nhanh luồng đăng ký mà không phải đi
/// qua tab Settings. Toàn bộ nằm trong một widget nên gỡ ra chỉ cần xoá một
/// dòng `floatingActionButton:` ở màn hình cha.
///
/// Badge trạng thái trên nút cho biết máy này đã đăng ký hay chưa — thông tin
/// hay bị quên nhất khi thử nghiệm nhiều máy cùng lúc.
class DeviceQuickActionsFab extends StatefulWidget {
  final bool isDark;

  const DeviceQuickActionsFab({super.key, this.isDark = false});

  @override
  State<DeviceQuickActionsFab> createState() => _DeviceQuickActionsFabState();
}

class _DeviceQuickActionsFabState extends State<DeviceQuickActionsFab> {
  final _deviceUser = DeviceUserService();
  final _nfc = NfcEnrollmentService();

  bool _enrolled = false;
  bool _nfcAvailable = false;
  String? _myName;

  @override
  void initState() {
    super.initState();
    _refresh();
    _nfc.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });
  }

  @override
  void dispose() {
    _nfc.stop();
    super.dispose();
  }

  Future<void> _refresh() async {
    final enrolled = await _deviceUser.isEnrolled();
    final contacts = await _deviceUser.getContacts();
    if (!mounted) return;
    setState(() {
      _enrolled = enrolled;
      _myName = '${contacts.length} liên hệ';
    });
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _openMenu,
      backgroundColor: _enrolled ? const Color(0xFF14B8A6) : const Color(0xFFF59E0B),
      foregroundColor: Colors.white,
      tooltip: _enrolled ? 'Thiết bị đã đăng ký' : 'Thiết bị CHƯA đăng ký',
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.devices_other_rounded),
          if (!_enrolled)
            const Positioned(
              right: 2,
              top: 2,
              child: Icon(Icons.priority_high_rounded, size: 12, color: Colors.white),
            ),
        ],
      ),
    );
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // ── Dải trạng thái ────────────────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_enrolled ? Colors.teal : Colors.orange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _enrolled ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                    size: 18,
                    color: _enrolled ? Colors.teal : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _enrolled
                          ? 'Máy này đã đăng ký · $_myName trong danh bạ'
                          : 'Máy này CHƯA đăng ký — Chat đang dùng danh bạ demo',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1)),
              title: const Text('Quét mã QR để đăng ký'),
              subtitle: const Text('Mở camera, quét mã do quản lý cấp'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const EnrollDeviceScreen()),
                );
                if (ok == true) await _afterEnroll();
              },
            ),

            ListTile(
              enabled: _nfcAvailable,
              leading: Icon(Icons.nfc_rounded,
                  color: _nfcAvailable ? const Color(0xFF8B5CF6) : Colors.grey),
              title: const Text('Chạm thẻ NFC để đăng ký'),
              subtitle: Text(_nfcAvailable
                  ? 'Chạm mặt sau máy vào thẻ đăng ký'
                  : 'Máy này không có NFC hoặc NFC đang tắt'),
              onTap: _nfcAvailable
                  ? () async {
                      Navigator.pop(ctx);
                      await _enrollViaNfc();
                    }
                  : null,
            ),

            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF14B8A6)),
              title: const Text('Cấp mã cho máy khác'),
              subtitle: const Text('Tạo QR hoặc ghi thẻ NFC (cần quyền admin)'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IssueEnrollmentScreen()),
                );
                await _refresh();
              },
            ),

            ListTile(
              leading: const Icon(Icons.devices_rounded, color: Color(0xFF94A3B8)),
              title: const Text('Quản lý thiết bị'),
              subtitle: const Text('Xem danh sách, thu hồi máy đã mất'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageDevicesScreen()),
                );
                await _refresh();
              },
            ),

            ListTile(
              leading: const Icon(Icons.sync_rounded, color: Color(0xFF0EA5E9)),
              title: const Text('Đồng bộ danh bạ thiết bị'),
              subtitle: const Text('Nạp lại danh sách liên hệ từ máy chủ'),
              onTap: () async {
                Navigator.pop(ctx);
                final n = await _deviceUser.syncDirectory();
                await _refresh();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(n > 0
                        ? 'Đã đồng bộ $n liên hệ từ máy chủ.'
                        : 'Chưa lấy được danh bạ — kiểm tra kết nối hoặc đăng ký trước.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  }

  Future<void> _enrollViaNfc() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Chạm máy vào thẻ đăng ký...')),
    );
    try {
      final ticket = await _nfc.readTicket();
      await EnrollmentService().enroll(ticket);
      await _afterEnroll();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('✅ Đăng ký thành công qua NFC.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  /// Sau khi đăng ký: tạo User từ danh tính thiết bị rồi kéo danh bạ về, để
  /// Chat chuyển ngay từ user demo sang danh tính thật mà không cần khởi động
  /// lại app.
  Future<void> _afterEnroll() async {
    await _deviceUser.ensureLocalUser();
    await _deviceUser.syncDirectory();
    await _refresh();
  }
}
