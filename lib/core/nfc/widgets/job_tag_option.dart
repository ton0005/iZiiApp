import 'package:flutter/material.dart';

import '../job_tag_service.dart';
import '../nfc_uri_service.dart';

/// Ô "chọn / bỏ chọn thẻ NFC" trong dialog tạo công việc.
///
/// Trạng thái do màn hình cha giữ ([enabled] + [onChanged]) để giá trị sống
/// sót qua `setDialogState` — StatefulBuilder dựng lại con liên tục nên widget
/// này không được tự giữ trạng thái chính.
///
/// Tự ẩn hoàn toàn khi máy không có NFC: hiện một ô tick không bấm được chỉ
/// làm người dùng bối rối.
class JobTagOption extends StatefulWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  /// Nhãn tự do ghi kèm lên thẻ (tuỳ chọn).
  final String label;
  final ValueChanged<String> onLabelChanged;

  /// Xem trước nội dung sẽ ghi, để cảnh báo dung lượng trước khi chạm thẻ.
  final JobTag? preview;

  const JobTagOption({
    super.key,
    required this.enabled,
    required this.onChanged,
    required this.label,
    required this.onLabelChanged,
    this.preview,
  });

  @override
  State<JobTagOption> createState() => _JobTagOptionState();
}

class _JobTagOptionState extends State<JobTagOption> {
  bool? _nfcAvailable;

  @override
  void initState() {
    super.initState();
    JobTagService.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Chưa biết → chưa vẽ gì, tránh nhấp nháy.
    if (_nfcAvailable == null) return const SizedBox.shrink();

    // Máy không có NFC → ẩn hẳn thay vì hiện ô tick vô dụng.
    if (_nfcAvailable == false) return const SizedBox.shrink();

    final preview = widget.preview;
    final tooBig = preview != null && !preview.fitsNtag213;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Divider(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: widget.enabled,
          onChanged: (v) => widget.onChanged(v ?? false),
          title: const Text('Ghi thẻ NFC cho công việc này',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text(
            'Dán thẻ NTAG213 ở cửa phòng. Công nhân chạm thẻ là mở thẳng '
            'công việc, không phải tìm trong danh sách.',
            style: TextStyle(fontSize: 11, height: 1.35),
          ),
        ),
        if (widget.enabled) ...[
          const SizedBox(height: 4),
          TextFormField(
            initialValue: widget.label,
            decoration: const InputDecoration(
              labelText: 'Nhãn trên thẻ (tuỳ chọn)',
              hintText: 'VD: Cửa chính · Kệ A',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: widget.onLabelChanged,
          ),
          const SizedBox(height: 8),
          if (preview != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (tooBig ? Colors.red : Colors.purple).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (tooBig ? Colors.red : Colors.purple)
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tooBig ? Icons.error_outline_rounded : Icons.nfc_rounded,
                      size: 16, color: tooBig ? Colors.red : Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(preview.toString(),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          tooBig
                              ? '${preview.estimatedBytes}/${JobTagService.ntag213Capacity} byte — '
                                  'VƯỢT dung lượng NTAG213, rút ngắn nhãn'
                              : '${preview.estimatedBytes}/${JobTagService.ntag213Capacity} byte',
                          style: TextStyle(
                            fontSize: 11,
                            color: tooBig ? Colors.red : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Hộp thoại chạm thẻ để ghi — hiện sau khi công việc đã được tạo.
///
/// Tách khỏi luồng tạo công việc: **công việc luôn được tạo trước**, ghi thẻ
/// chỉ là bước phụ. Thẻ hỏng hay công nhân bỏ giữa chừng thì công việc vẫn còn
/// nguyên, chỉ là chưa gắn thẻ.
Future<bool> showWriteJobTagSheet(BuildContext context, JobTag tag) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _WriteJobTagSheet(tag: tag),
  );
  return result ?? false;
}

class _WriteJobTagSheet extends StatefulWidget {
  final JobTag tag;
  const _WriteJobTagSheet({required this.tag});

  @override
  State<_WriteJobTagSheet> createState() => _WriteJobTagSheetState();
}

class _WriteJobTagSheetState extends State<_WriteJobTagSheet> {
  String _status = 'Đưa thẻ NFC vào mặt sau máy...';
  bool _done = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _write();
  }

  @override
  void dispose() {
    JobTagService.stop();
    super.dispose();
  }

  Future<void> _write() async {
    setState(() {
      _failed = false;
      _status = 'Đưa thẻ NFC vào mặt sau máy...';
    });
    try {
      await JobTagService.write(widget.tag,
          onStatus: (m) => mounted ? setState(() => _status = m) : null);
      if (!mounted) return;
      setState(() {
        _done = true;
        _status = '✅ Đã ghi thẻ xong. Dán thẻ vào cửa phòng.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = e is NfcTagException ? e.message : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _done
                  ? Icons.check_circle_rounded
                  : (_failed ? Icons.error_rounded : Icons.nfc_rounded),
              size: 56,
              color: _done
                  ? Colors.green
                  : (_failed ? Colors.redAccent : Colors.purple),
            ),
            const SizedBox(height: 16),
            Text(widget.tag.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_status, textAlign: TextAlign.center),
            if (!_done && !_failed) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_failed)
                  TextButton(onPressed: _write, child: const Text('Thử lại')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _done),
                  child: Text(_done ? 'Xong' : 'Bỏ qua'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
