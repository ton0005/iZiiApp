import 'dart:async';

import 'package:flutter/material.dart';

import '../work_session_service.dart';

/// AI ĐANG TRONG CA — màn hình giám sát cho quản lý (G1).
///
/// Đây là câu trả lời cho câu hỏi quan trọng nhất khi có sự cố trong nhà máy:
/// ai đang ở đây, trên máy nào, từ lúc nào. Trước khi có phiên làm việc, câu
/// này không trả lời được — hệ thống chỉ biết "máy nào" chứ không biết "ai".
class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  final _service = WorkSessionService();
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Tự làm mới mỗi 30 giây — màn hình này thường để mở trên máy phòng điều
    // khiển, quản lý không bấm làm mới liên tục.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _service.listActive();
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Ca dài bất thường cần được chú ý — có thể là quên kết thúc ca, cũng có
  /// thể là người thực sự còn trong nhà máy quá lâu.
  Color _durationColor(int? minutes) {
    if (minutes == null) return Colors.grey;
    if (minutes > 10 * 60) return Colors.redAccent;
    if (minutes > 8 * 60) return Colors.orange;
    return Colors.green;
  }

  String _fmtDuration(int? minutes) {
    if (minutes == null) return '—';
    if (minutes < 60) return '$minutes phút';
    return '${minutes ~/ 60} giờ ${minutes % 60} phút';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ai đang trong ca'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  color: const Color(0xFF14B8A6).withValues(alpha: .12),
                  child: Row(
                    children: [
                      Text('${_sessions.length}',
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E))),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text('người đang làm việc\nTự cập nhật mỗi 30 giây',
                            style: TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),

                Expanded(
                  child: _sessions.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Hiện không có ai điểm danh.\n\n'
                              'Nếu có người đang làm việc mà không hiện ở đây,\n'
                              'nghĩa là họ chưa điểm danh đầu ca.',
                              textAlign: TextAlign.center,
                              style: TextStyle(height: 1.6),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _sessions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final s = _sessions[i];
                            final minutes = s['minutes_elapsed'] as int?;
                            final color = _durationColor(minutes);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: .18),
                                child: Icon(Icons.person_rounded, color: color),
                              ),
                              title: Text(
                                (s['user_name'] ?? s['user_id']).toString(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [s['department'], 'Zone ${s['zone']}']
                                        .where((x) =>
                                            x != null && x.toString().trim().isNotEmpty)
                                        .join(' · '),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Máy: ${s['device_name']} · điểm danh bằng '
                                    '${_methodLabel(s['method']?.toString())}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_fmtDuration(minutes),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: color)),
                                  if (minutes != null && minutes > 8 * 60)
                                    const Text('ca dài',
                                        style: TextStyle(fontSize: 10, color: Colors.orange)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _methodLabel(String? m) {
    switch (m) {
      case 'nfc_badge':
        return 'thẻ NFC';
      case 'pin':
        return 'mã PIN';
      case 'auto':
        return 'tự động';
      default:
        return 'chọn tên';
    }
  }
}
