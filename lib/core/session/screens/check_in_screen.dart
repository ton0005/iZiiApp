import 'package:flutter/material.dart';

import '../../nfc/employee_badge_service.dart';
import '../../nfc/nfc_uri_service.dart';
import '../work_session_service.dart';

/// Màn hình điểm danh đầu ca (G1).
///
/// Ba cách, hiện đồng thời để công nhân chọn cách tiện nhất tại thời điểm đó:
///   • Chạm thẻ nhân viên — nhanh nhất, dùng được khi đeo găng
///   • Chọn tên từ danh sách — luôn có, không cần phần cứng
///   • Nhập PIN — chỉ hiện với nhân viên đã được quản lý đặt PIN
///
/// [employees] là danh sách nhân viên lấy từ database local, dạng
/// `{'id','name','department','role'}`.
class CheckInScreen extends StatefulWidget {
  final List<Map<String, dynamic>> employees;

  /// true khi mở vì bắt buộc (ví dụ đang định tạo Alone Worker mà chưa điểm danh).
  final bool mandatory;
  final String? reason;

  const CheckInScreen({
    super.key,
    required this.employees,
    this.mandatory = false,
    this.reason,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _service = WorkSessionService();
  final _searchController = TextEditingController();

  bool _nfcAvailable = false;
  bool _busy = false;
  String? _status;
  String? _error;
  String _query = '';
  Set<String> _usersWithPin = {};

  @override
  void initState() {
    super.initState();
    EmployeeBadgeService.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });
    _service.usersWithPin().then((s) {
      if (mounted) setState(() => _usersWithPin = s);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    EmployeeBadgeService.stop();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return widget.employees;
    final q = _query.trim().toLowerCase();
    return widget.employees.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final id = (e['id'] ?? '').toString().toLowerCase();
      final dept = (e['department'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q) || dept.contains(q);
    }).toList();
  }

  Future<void> _checkIn({
    required String userId,
    String? userName,
    String? department,
    String method = 'list',
    String? pin,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Đang điểm danh...';
    });
    try {
      final session = await _service.checkIn(
        userId: userId,
        userName: userName,
        department: department,
        method: method,
        pin: pin,
      );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = e.toString();
      });
    }
  }

  Future<void> _checkInByBadge() async {
    setState(() {
      _error = null;
      _status = 'Chạm thẻ nhân viên vào mặt sau máy...';
    });
    try {
      final badge = await EmployeeBadgeService.read(
        onStatus: (m) => mounted ? setState(() => _status = m) : null,
      );
      await _checkIn(
        userId: badge.userId,
        userName: badge.userName,
        department: badge.department,
        method: 'nfc_badge',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = null;
        _error = e is NfcTagException ? e.message : '$e';
      });
    }
  }

  /// Nhân viên có PIN thì phải nhập trước khi vào ca.
  Future<void> _promptPin(Map<String, dynamic> emp) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mã PIN của ${emp['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: 'Nhập 4-6 chữ số',
            counterText: '',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Vào ca'),
          ),
        ],
      ),
    );
    if (pin == null || pin.isEmpty) return;
    await _checkIn(
      userId: (emp['id'] ?? '').toString(),
      userName: (emp['name'] ?? '').toString(),
      department: (emp['department'] ?? '').toString(),
      method: 'pin',
      pin: pin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      // Bắt buộc thì không cho thoát bằng nút Back — nếu không công nhân sẽ
      // bấm Back rồi thắc mắc vì sao vẫn không tạo được công việc.
      canPop: !widget.mandatory,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Điểm danh đầu ca'),
          automaticallyImplyLeading: !widget.mandatory,
        ),
        body: Column(
          children: [
            if (widget.mandatory)
              Container(
                width: double.infinity,
                color: Colors.orange.withValues(alpha: 0.15),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 20, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.reason ??
                            'Cần điểm danh trước khi tiếp tục. Hệ thống phải biết '
                                'đích danh ai đang làm việc để cảnh báo an toàn có ý nghĩa.',
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Chạm thẻ nhân viên ───────────────────────────────────────
            if (_nfcAvailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _checkInByBadge,
                    icon: const Icon(Icons.nfc_rounded, size: 26),
                    label: const Text('Chạm thẻ nhân viên',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ),

            if (_nfcAvailable)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('hoặc chọn tên', style: TextStyle(fontSize: 12))),
                  Expanded(child: Divider()),
                ]),
              ),

            // ── Tìm kiếm ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên hoặc mã nhân viên',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),

            if (_status != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_status!, style: const TextStyle(fontSize: 13))),
                ]),
              ),

            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
              ),

            // ── Danh sách nhân viên ──────────────────────────────────────
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('Không tìm thấy nhân viên nào.',
                          textAlign: TextAlign.center)))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final e = _filtered[i];
                        final id = (e['id'] ?? '').toString();
                        final hasPin = _usersWithPin.contains(id);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.white12
                                : const Color(0xFF14B8A6).withValues(alpha: .15),
                            child: Text(
                              (e['name'] ?? '?').toString().characters.first.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text((e['name'] ?? id).toString()),
                          subtitle: Text(
                            [e['department'], e['role']]
                                .where((x) => x != null && x.toString().isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: hasPin
                              ? const Icon(Icons.lock_rounded, size: 18, color: Colors.orange)
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: _busy
                              ? null
                              : () {
                                  if (hasPin) {
                                    _promptPin(e);
                                  } else {
                                    _checkIn(
                                      userId: id,
                                      userName: (e['name'] ?? '').toString(),
                                      department: (e['department'] ?? '').toString(),
                                      method: 'list',
                                    );
                                  }
                                },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
