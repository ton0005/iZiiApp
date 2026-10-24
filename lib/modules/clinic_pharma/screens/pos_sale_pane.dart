import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../repository.dart';
import '../services/dtqg_service.dart';
import '../services/pos_receipt_service.dart';
import 'scan_code_dialog.dart';

/// Nhà thuốc bán theo đơn thuốc điện tử (Đơn thuốc quốc gia, QĐ 808 mục VIII–IX):
/// tra đơn theo mã → chọn thuốc xuất kho (có thể thay thuốc) → bán → cập nhật
/// số lượng bán lên hệ thống quốc gia và trừ kho cục bộ.
class PosSalePane extends StatefulWidget {
  const PosSalePane({super.key});

  @override
  State<PosSalePane> createState() => _PosSalePaneState();
}

class _SaleLine {
  final PosLine line;
  Map<String, dynamic>? medicine; // thuốc thực xuất kho
  final TextEditingController qty = TextEditingController();
  _SaleLine(this.line);

  Map<String, dynamic> get fields =>
      Map<String, dynamic>.from((medicine?['custom_fields'] as Map?) ?? const {});
  String get soldCode => (fields['ma_thuoc_cuc_qldd'] as String? ?? '').trim();
  bool get isSubstitute => medicine != null && soldCode.isNotEmpty && soldCode != line.maThuoc;
  double get stock => (medicine?['stock'] as num?)?.toDouble() ?? 0;
  double get quantity => double.tryParse(qty.text.trim().replaceAll(',', '.')) ?? 0;
}

class _PosSalePaneState extends State<PosSalePane> {
  final _repo = ClinicPharmaRepository();
  final _service = DtqgService();
  final _code = TextEditingController();
  final _invoice = TextEditingController();

  List<Map<String, dynamic>> _medicines = [];
  PosPrescription? _rx;
  List<_SaleLine> _lines = [];
  String? _error;
  bool _loading = false;
  bool _selling = false;

  @override
  void initState() {
    super.initState();
    _newInvoice();
    _loadMedicines();
  }

  @override
  void dispose() {
    _code.dispose();
    _invoice.dispose();
    for (final l in _lines) {
      l.qty.dispose();
    }
    super.dispose();
  }

  void _newInvoice() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    _invoice.text =
        'HD${two(n.year % 100)}${two(n.month)}${two(n.day)}${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  Future<void> _loadMedicines() async {
    final m = await _repo.getMedicines();
    if (mounted) setState(() => _medicines = m);
  }

  Future<void> _scan() async {
    final code = await scanMaDonThuoc(context);
    if (code == null || !mounted) return;
    _code.text = code;
    await _lookup();
  }

  Future<void> _lookup() async {
    // Súng quét USB gõ cả chuỗi (có thể kèm tiền tố/xuống dòng) → rút lấy mã đơn.
    final code = extractMaDonThuoc(_code.text) ?? _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rx = await _service.lookup(code);
      await _loadMedicines();
      for (final l in _lines) {
        l.qty.dispose();
      }
      final lines = [for (final l in rx.lines) _SaleLine(l)];
      for (final sl in lines) {
        sl.medicine = _medicines.cast<Map<String, dynamic>?>().firstWhere(
            (m) => ((m!['custom_fields'] as Map?)?['ma_thuoc_cuc_qldd'] ?? '') == sl.line.maThuoc,
            orElse: () => null);
        final want = sl.line.conLai;
        final q = sl.medicine == null ? 0.0 : (want < sl.stock ? want : sl.stock);
        sl.qty.text = q > 0 ? q.toStringAsFixed(q % 1 == 0 ? 0 : 1) : '';
      }
      if (!mounted) return;
      setState(() {
        _rx = rx;
        _lines = lines;
        _newInvoice();
      });
    } on DtqgException catch (e) {
      if (mounted) {
        setState(() {
          _rx = null;
          _lines = [];
          _error = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _validateLocal() {
    final errs = <String>[];
    var any = false;
    for (final l in _lines) {
      final q = l.quantity;
      if (q <= 0) continue;
      any = true;
      final name = l.line.tenThuoc;
      if (l.medicine == null) {
        errs.add('$name: chưa chọn thuốc xuất kho');
        continue;
      }
      if (l.soldCode.isEmpty) {
        errs.add('$name: thuốc "${l.medicine!['name']}" chưa có mã thuốc (Cục QLD) — cập nhật ở Kho thuốc');
      }
      if (q > l.line.conLai + 1e-9) {
        errs.add('$name: bán ${q.toStringAsFixed(0)} vượt số còn lại ${l.line.conLai.toStringAsFixed(0)}');
      }
      if (q > l.stock + 1e-9) {
        errs.add('$name: kho chỉ còn ${l.stock.toStringAsFixed(0)}');
      }
    }
    if (!any) errs.add('Chưa nhập số lượng bán');
    if (_invoice.text.trim().isEmpty) errs.add('Thiếu mã hóa đơn');
    return errs;
  }

  Future<void> _sell() async {
    final rx = _rx;
    if (rx == null) return;
    final errs = _validateLocal();
    if (errs.isNotEmpty) {
      await _showErrors('Chưa thể bán', errs);
      return;
    }
    final sold = _lines.where((l) => l.quantity > 0).toList();
    setState(() => _selling = true);
    try {
      final result = await _service.sell(
        maDonThuoc: rx.maDonThuoc,
        maHoaDon: _invoice.text.trim(),
        lines: [
          for (final l in sold)
            {
              'ma_thuoc_da_ke_don': l.line.maThuoc,
              'so_luong_ban': l.quantity,
              if (l.isSubstitute) ...{
                'ma_thuoc': l.soldCode,
                'ten_thuoc': l.medicine!['name'],
                'biet_duoc': (l.fields['biet_duoc'] as String?)?.trim().isNotEmpty == true
                    ? l.fields['biet_duoc']
                    : l.line.bietDuoc,
                'don_vi_tinh': (l.fields['don_vi_tinh'] ?? l.fields['dosage_unit'] ?? l.line.donViTinh),
              },
            }
        ],
      );
      if (!result.recorded) {
        // Hệ thống từ chối → chưa giao thuốc, KHÔNG trừ kho.
        await _showErrors('Hệ thống quốc gia từ chối', result.errors.isEmpty ? [result.result] : result.errors);
        return;
      }
      // Đã ghi nhận (kể cả đang chờ gửi lại do mất mạng) → thuốc giao cho khách, trừ kho.
      try {
        await _repo.dispenseLines([
          for (final l in sold)
            {
              'product_id': l.medicine!['id'],
              'medicine_name': l.medicine!['name'],
              'quantity': l.quantity,
            }
        ]);
      } catch (e) {
        await _showErrors('Đã cập nhật đơn nhưng trừ kho thất bại — kiểm kho thủ công', ['$e']);
      }
      if (!mounted) return;
      final receiptLines = [
        for (final l in sold)
          ReceiptLine(
            name: l.medicine!['name'] as String,
            unit: (l.fields['don_vi_tinh'] ?? l.fields['dosage_unit'] ?? l.line.donViTinh).toString(),
            quantity: l.quantity,
            unitPrice: (l.medicine!['price'] as num?)?.toDouble() ?? 0,
            substitute: l.isSubstitute,
            prescribedName: l.line.tenThuoc,
          )
      ];
      final invoiceCode = _invoice.text.trim();
      final pending = result.result != 'sent';
      final facility = await _repo.getFacility();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 12),
        content: Text(pending
            ? 'Đã ghi nhận bán. Mất kết nối — server sẽ tự gửi lại lên hệ thống quốc gia.'
            : 'Đã bán và cập nhật số lượng bán lên Đơn thuốc quốc gia'),
        action: SnackBarAction(
          label: 'In biên nhận',
          onPressed: () async {
            final bytes = await PosReceiptService.generate(
              pharmacyName: facility['name'] as String? ?? '',
              pharmacyAddress: facility['address'] as String? ?? '',
              pharmacyPhone: facility['phone'] as String? ?? '',
              invoiceCode: invoiceCode,
              maDonThuoc: rx.maDonThuoc,
              patientName: rx.hoTen,
              lines: receiptLines,
              pendingSync: pending,
            );
            await Printing.layoutPdf(
                name: 'bien_nhan_$invoiceCode.pdf', onLayout: (_) async => bytes);
          },
        ),
      ));
      await _lookup();
    } on DtqgException catch (e) {
      await _showErrors('Không bán được', [e.message]);
    } finally {
      if (mounted) setState(() => _selling = false);
    }
  }

  Future<void> _showErrors(String title, List<String> errors) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final e in errors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e)),
                    ]),
                  ),
              ]),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rx = _rx;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.qr_code_scanner),
                hintText: 'Nhập / dán mã đơn thuốc (VD: 01aaa1234567-c)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (cameraScanSupported) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Quét mã đơn bằng camera',
              onPressed: _loading ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ],
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _lookup,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: const Text('Tra đơn'),
          ),
        ]),
        const SizedBox(height: 12),
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
        if (rx == null && _error == null)
          const Expanded(
            child: Center(
              child: Text('Nhập mã đơn thuốc điện tử để tra và bán thuốc theo đơn',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        if (rx != null) Expanded(child: _buildRx(rx)),
      ]),
    );
  }

  Widget _buildRx(PosPrescription rx) {
    final dx = rx.chanDoan
        .map((d) => '${d['ten_benh'] ?? d['ten_chan_doan'] ?? ''} (${d['ma_benh'] ?? d['ma_chan_doan'] ?? ''})')
        .join('; ');
    return ListView(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(rx.hoTen,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (rx.hetHan) const Chip(label: Text('HẾT HẠN'), backgroundColor: Color(0xFFFECACA)),
              if (rx.daBanHet) const Chip(label: Text('ĐÃ BÁN HẾT'), backgroundColor: Color(0xFFFDE68A)),
              if (rx.coTheBan) const Chip(label: Text('CÒN HIỆU LỰC'), backgroundColor: Color(0xFFBBF7D0)),
            ]),
            const SizedBox(height: 4),
            Text('Mã đơn: ${rx.maDonThuoc} · Sinh: ${rx.ngaySinh} · ${rx.diaChi}',
                style: const TextStyle(color: Colors.grey)),
            Text('Kê lúc ${rx.ngayGioKeDon} · BS. ${rx.tenBacSi} · ${rx.tenCoSo}',
                style: const TextStyle(color: Colors.grey)),
            if (dx.isNotEmpty) Text('Chẩn đoán: $dx'),
            if ((rx.loiDan ?? '').isNotEmpty) Text('Lời dặn: ${rx.loiDan}'),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      for (final l in _lines) _lineCard(l, rx),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _invoice,
            maxLength: 20,
            decoration: const InputDecoration(
                labelText: 'Mã hóa đơn bán lẻ', isDense: true, border: OutlineInputBorder()),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: (_selling || !rx.coTheBan) ? null : _sell,
            icon: _selling
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.point_of_sale),
            label: const Text('Bán & cập nhật hệ thống quốc gia', style: TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    ]);
  }

  Widget _lineCard(_SaleLine l, PosPrescription rx) {
    final done = l.line.conLai <= 0;
    final q = l.quantity;
    final over = q > l.line.conLai + 1e-9 || (l.medicine != null && q > l.stock + 1e-9);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(l.line.tenThuoc, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Text('Kê ${l.line.soLuong.toStringAsFixed(0)} ${l.line.donViTinh} · '
                'đã bán ${l.line.daBan.toStringAsFixed(0)} · còn ${l.line.conLai.toStringAsFixed(0)}'),
          ]),
          Text('${l.line.bietDuoc} · mã ${l.line.maThuoc} · ${l.line.cachDung}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          if (done)
            const Text('Đã bán đủ', style: TextStyle(color: Colors.green))
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: l.medicine?['id'] as String?,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Thuốc xuất kho', isDense: true, border: OutlineInputBorder()),
                  items: [
                    for (final m in _medicines)
                      DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text(
                            '${m['name']} (tồn ${(m['stock'] as num?)?.toStringAsFixed(0) ?? 0})',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    l.medicine = _medicines.firstWhere((m) => m['id'] == id);
                  }),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: l.qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Số lượng bán',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    errorText: over ? 'Vượt' : null,
                  ),
                ),
              ),
            ]),
          if (l.isSubstitute)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Thay thế thuốc: chỉ dược sĩ đại học, cùng hoạt chất/đường dùng/liều và phải có sự đồng ý của người mua.',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          if (l.medicine != null && l.soldCode.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Thuốc này chưa có mã Cục QLD — không thể báo cáo bán.',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}
