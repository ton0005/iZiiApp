import 'dart:async';

import 'package:flutter/material.dart';

import '../../../modules/mushrooms/repository.dart';
import '../screens/active_sessions_screen.dart';
import '../screens/check_in_screen.dart';
import '../work_session_service.dart';

/// Thanh trạng thái phiên làm việc, đặt trên đầu màn hình Home.
///
/// Hai trạng thái:
///   • CHƯA điểm danh → dải cam, bấm để điểm danh
///   • ĐÃ điểm danh   → dải xanh, hiện tên và thời gian đã làm
///
/// Vì sao đặt ngay trên Home: điểm danh là việc dễ quên nhất trong ngày, và
/// hậu quả chỉ lộ ra khi công nhân định tạo công việc Alone Worker rồi bị chặn.
/// Nhắc trước từ đầu ca đỡ phiền hơn nhiều so với chặn giữa chừng.
class SessionBanner extends StatefulWidget {
  final bool isDark;
  const SessionBanner({super.key, this.isDark = false});

  @override
  State<SessionBanner> createState() => _SessionBannerState();
}

class _SessionBannerState extends State<SessionBanner> {
  final _service = WorkSessionService();
  WorkSession? _session;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Cập nhật mỗi phút để phần "đã làm N phút" không đứng yên.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final s = await _service.getCurrent(force: force);
    if (!mounted) return;
    setState(() {
      _session = s;
      _loading = false;
    });
  }

  Future<void> _openCheckIn() async {
    final employees = await MushroomsRepository().getEmployees();
    if (!mounted) return;
    final result = await Navigator.of(context).push<WorkSession>(
      MaterialPageRoute(builder: (_) => CheckInScreen(employees: employees)),
    );
    if (result != null) await _load(force: true);
  }

  Future<void> _confirmCheckOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết thúc ca?'),
        content: Text(
          '${_session?.displayName ?? ''} đã làm ${_session?.elapsedText ?? ''}.\n\n'
          'Sau khi kết thúc, máy này sẽ không tạo được công việc Làm việc một mình '
          'cho tới khi có người điểm danh lại.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kết thúc ca'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.checkOut();
    } catch (_) {}
    await _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final s = _session;
    final hasSession = s != null;

    // ── Máy CÁ NHÂN (iPhone/iPad của Manager, Supervisor) ──────────────────
    //
    // Không hiện dải cam "chưa điểm danh" — máy dùng riêng, mang về nhà, danh
    // tính đã xác định từ lúc cấp máy. Hiện cảnh báo mỗi lần mở app chỉ gây
    // khó chịu mà không thêm chút an toàn nào.
    //
    // Vẫn cho bấm "Bắt đầu ca" để xuất hiện trong danh sách ai đang có mặt tại
    // nhà máy — hữu ích khi Manager xuống hiện trường, nhưng không bắt buộc.
    if (_service.isPersonal && !hasSession) {
      return Material(
        color: const Color(0xFF6366F1).withValues(alpha: widget.isDark ? .16 : .10),
        child: InkWell(
          onTap: _openCheckIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                const Icon(Icons.phone_iphone_rounded,
                    size: 19, color: Color(0xFF6366F1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _service.ownerName.isNotEmpty
                            ? _service.ownerName
                            : 'Máy cá nhân',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      const Text('Máy riêng · không cần điểm danh hằng ngày',
                          style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ai đang trong ca',
                  icon: const Icon(Icons.groups_rounded, size: 20),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActiveSessionsScreen()),
                  ),
                ),
                const Text('Bắt đầu ca',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF6366F1))),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFF6366F1)),
              ],
            ),
          ),
        ),
      );
    }

    final color = hasSession ? const Color(0xFF14B8A6) : const Color(0xFFF59E0B);

    return Material(
      color: color.withValues(alpha: widget.isDark ? .18 : .12),
      child: InkWell(
        onTap: hasSession ? _confirmCheckOut : _openCheckIn,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(
                hasSession ? Icons.how_to_reg_rounded : Icons.person_off_rounded,
                size: 20, color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hasSession
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.displayName,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('Đang trong ca · ${s.elapsedText}',
                              style: const TextStyle(fontSize: 11.5)),
                        ],
                      )
                    : const Text(
                        'Chưa điểm danh — chạm để vào ca',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
              IconButton(
                tooltip: 'Ai đang trong ca',
                icon: const Icon(Icons.groups_rounded, size: 20),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActiveSessionsScreen()),
                ),
              ),
              Icon(hasSession ? Icons.logout_rounded : Icons.chevron_right_rounded,
                  size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Đảm bảo có phiên trước khi làm một việc bắt buộc điểm danh.
///
/// Trả true nếu đã có phiên (hoặc vừa điểm danh xong), false nếu người dùng huỷ.
///
/// Dùng cho Alone Worker: chặn ở client cho trải nghiệm tốt (mở luôn màn hình
/// điểm danh thay vì báo lỗi), nhưng **server vẫn kiểm độc lập** — client là
/// tiện lợi, server mới là ràng buộc thật.
Future<bool> ensureCheckedIn(
  BuildContext context, {
  String? reason,
  String? assignee,
}) async {
  final service = WorkSessionService();

  // Có phân công cho người khác thì NGƯỜI ĐÓ mới là người cần đang trong ca,
  // không phải người đang cầm máy. Quản lý ngồi laptop giao việc cho công nhân
  // đã điểm danh trên iPad — bắt quản lý điểm danh ở đây là chặn nhầm người.
  //
  // Kiểm bằng danh sách "ai đang trong ca" lấy từ server, vì người được phân
  // công có thể đang ở một thiết bị hoàn toàn khác.
  if (assignee != null && assignee.trim().isNotEmpty) {
    final ok = await service.isPersonOnShift(assignee.trim());
    if (ok) return true;
    if (!context.mounted) return false;

    // Không tự mở màn hình điểm danh: người cần điểm danh không ngồi ở đây.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Người được giao chưa điểm danh'),
        content: Text(
          '"$assignee" chưa điểm danh đầu ca.\n\n'
          'Công việc Làm việc một mình cần biết đích danh ai đang trong phòng, '
          'nên chỉ giao được cho người đã vào ca. Hãy nhờ họ điểm danh trên '
          'máy của mình rồi thử lại.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
    return false;
  }

  final current = await service.getCurrent(force: true);
  if (current != null) return true;

  // Máy cá nhân đã biết đích danh chủ máy — điều kiện an toàn đã thoả, không
  // cần điểm danh. Server cũng cho qua theo cùng logic (identity_is_known).
  if (service.isPersonal) return true;

  if (!context.mounted) return false;

  final employees = await MushroomsRepository().getEmployees();
  if (!context.mounted) return false;

  final result = await Navigator.of(context).push<WorkSession>(
    MaterialPageRoute(
      builder: (_) => CheckInScreen(
        employees: employees,
        mandatory: true,
        reason: reason,
      ),
    ),
  );
  return result != null;
}
