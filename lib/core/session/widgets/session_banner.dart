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
        title: const Text('End shift?'),
        content: Text(
          '${_session?.displayName ?? ''} has been on shift for ${_session?.elapsedText ?? ''}.\n\n'
          'After ending, this device will not be able to create Alone Worker tasks '
          'until someone checks in again.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End shift'),
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

    // ── Personal Device (iPhone/iPad of Manager, Supervisor) ───────────────
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
                            : 'Personal Device',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      const Text('Personal device · Daily check-in exempt',
                          style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Who is on shift',
                  icon: const Icon(Icons.groups_rounded, size: 20),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActiveSessionsScreen()),
                  ),
                ),
                const Text('Start shift',
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
                          Text('On shift · ${s.elapsedText}',
                              style: const TextStyle(fontSize: 11.5)),
                        ],
                      )
                    : const Text(
                        'Shift Check-in — tap to start shift',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
              ),
              IconButton(
                tooltip: 'Who is on shift',
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

/// Ensure a shift session exists before performing a task that requires check-in.
Future<bool> ensureCheckedIn(
  BuildContext context, {
  String? reason,
  String? assignee,
}) async {
  final service = WorkSessionService();

  if (assignee != null && assignee.trim().isNotEmpty) {
    final ok = await service.isPersonOnShift(assignee.trim());
    if (ok) return true;
    if (!context.mounted) return false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assignee not checked in'),
        content: Text(
          '"$assignee" is not checked in for this shift.\n\n'
          'Alone Worker tasks require knowing the exact person in the room '
          'and can only be assigned to workers on shift. Please ask them to '
          'check in on their device and try again.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
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
