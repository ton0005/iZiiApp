import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dtqg_service.dart';

/// Trạng thái liên thông Đơn thuốc quốc gia của các đơn đã kê. Nguồn là
/// server (nơi gọi API và ghi 'sent'/'rejected'), không phải DB cục bộ.
class DtqgStatusPane extends StatefulWidget {
  const DtqgStatusPane({super.key});

  @override
  State<DtqgStatusPane> createState() => _DtqgStatusPaneState();
}

class _DtqgStatusPaneState extends State<DtqgStatusPane> {
  final _service = DtqgService();
  List<DtqgRxStatus> _rows = [];
  String? _filter; // null = tất cả
  String? _error;
  bool _loading = true;
  String? _sending;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Đơn 'queued' được server gửi ngầm; tự làm mới để thấy kết quả.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rows = await _service.listPrescriptions();
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } on DtqgException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(DtqgRxStatus r) async {
    setState(() => _sending = r.id);
    try {
      final res = await _service.sendPrescription(r.id);
      if (!mounted) return;
      final msg = switch (res.result) {
        'sent' => 'Đã gửi đơn ${r.maDonThuoc} lên Đơn thuốc quốc gia',
        'retry' => 'Mất kết nối tới hệ thống quốc gia — sẽ tự thử lại',
        'blocked' => res.errors.join('\n'),
        _ => 'Bị từ chối: ${res.errors.join('; ')}',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load(silent: true);
    } on DtqgException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  static ({Color color, String label}) _style(String s) {
    switch (s) {
      case 'sent':
        return (color: Colors.green, label: 'Đã gửi');
      case 'queued':
        return (color: Colors.orange, label: 'Chờ gửi');
      case 'rejected':
        return (color: Colors.red, label: 'Bị từ chối');
      default:
        return (color: Colors.grey, label: 'Nháp (chưa liên thông)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in _rows) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    final shown = _filter == null ? _rows : _rows.where((r) => r.status == _filter).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              ChoiceChip(
                label: Text('Tất cả (${_rows.length})'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final s in const ['queued', 'rejected', 'sent', 'draft'])
                ChoiceChip(
                  label: Text('${_style(s).label} (${counts[s] ?? 0})'),
                  selected: _filter == s,
                  onSelected: (_) => setState(() => _filter = _filter == s ? null : s),
                ),
            ]),
          ),
          IconButton(tooltip: 'Làm mới', onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 8),
        if (_error != null)
          Card(
            color: Colors.red.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!)),
              ]),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : shown.isEmpty
                  ? const Center(
                      child: Text('Không có đơn nào', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _tile(shown[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _tile(DtqgRxStatus r) {
    final st = _style(r.status);
    final canSend = r.status == 'queued' || r.status == 'rejected';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        isThreeLine: (r.lastError ?? '').isNotEmpty,
        leading: Icon(
            r.status == 'sent' ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
            color: st.color),
        title: Text('${r.patientName}  ·  ${r.maDonThuoc ?? 'chưa có mã đơn'}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text([
          if (r.doctorName.isNotEmpty) 'BS. ${r.doctorName}',
          '${r.itemCount} thuốc',
          if ((r.prescriptionDate ?? '').isNotEmpty) r.prescriptionDate!.substring(0, 16).replaceAll('T', ' '),
          if ((r.lastError ?? '').isNotEmpty) '\nLỗi: ${r.lastError}',
        ].join(' · ').replaceAll(' · \nLỗi', '\nLỗi')),
        trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Chip(
            label: Text(st.label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            backgroundColor: st.color,
            visualDensity: VisualDensity.compact,
          ),
          if (canSend)
            FilledButton(
              onPressed: _sending == null ? () => _send(r) : null,
              child: _sending == r.id
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(r.status == 'rejected' ? 'Gửi lại' : 'Gửi ngay'),
            ),
        ]),
      ),
    );
  }
}
