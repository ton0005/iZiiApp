import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../settings/settings_service.dart';

/// Danh sách thiết bị đã đăng ký — widget THUẦN, không có Scaffold.
///
/// Tách khỏi [ManageDevicesScreen] để dùng được ở hai nơi:
///   • Nhúng thẳng vào tab Settings  → [shrinkWrap] = true
///   • Màn hình riêng toàn màn hình   → [shrinkWrap] = false
///
/// VÌ SAO PHẢI TÁCH: tab Settings là một `SingleChildScrollView`. Đặt
/// `ListView` cuộn được vào trong đó sẽ ném lỗi "Vertical viewport was given
/// unbounded height". Và nếu nhúng nguyên `Scaffold` thì sẽ có AppBar lồng
/// AppBar cùng một FloatingActionButton nổi đè lên nội dung tab.
class DeviceListView extends StatefulWidget {
  /// true khi nhúng trong màn hình đã cuộn sẵn (tab Settings).
  final bool shrinkWrap;

  /// Gọi khi người dùng muốn cấp mã mới — để nơi nhúng tự quyết định
  /// điều hướng, vì widget này không biết mình đang nằm trong ngữ cảnh nào.
  final VoidCallback? onRequestNewCode;

  const DeviceListView({
    super.key,
    this.shrinkWrap = false,
    this.onRequestNewCode,
  });

  @override
  State<DeviceListView> createState() => DeviceListViewState();
}

class DeviceListViewState extends State<DeviceListView> {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final _settings = SettingsService();

  List<Map<String, dynamic>> _devices = [];
  bool _loading = false;
  String? _error;
  bool _requireDeviceToken = false;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    // Khi nhúng trong Settings, KHÔNG tự gọi API lúc dựng widget — tab Settings
    // mở rất thường xuyên, gọi /admin/devices mỗi lần là lãng phí và sẽ hiện
    // lỗi 401 đỏ lòm với người dùng không phải admin.
    // Nơi nhúng gọi reload() khi người dùng thực sự mở nhóm này ra.
    if (!widget.shrinkWrap) reload();
  }

  /// Cho phép nơi nhúng chủ động nạp lại (vd khi mở ExpansionTile).
  Future<void> reload() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('${await _baseUrl()}/admin/devices',
          options: Options(headers: await _headers()));
      final data = Map<String, dynamic>.from(resp.data);
      if (!mounted) return;
      setState(() {
        _devices = List<Map<String, dynamic>>.from(
          (data['devices'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _requireDeviceToken = data['require_device_token'] == true;
        _loading = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadedOnce = true;
        _error = _describe(e);
      });
    }
  }

  bool get hasLoaded => _loadedOnce;
  int get activeCount => _devices.where((d) => d['active'] == true).length;
  int get totalCount => _devices.length;

  Future<Map<String, String>> _headers() async {
    final token = await _settings.getSyncToken();
    return {
      if (token.isNotEmpty) 'X-iZii-Admin-Token': token,
      if (token.isNotEmpty) 'X-iZii-Server-Token': token,
      'Content-Type': 'application/json',
    };
  }

  Future<String> _baseUrl() async =>
      (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');

  Future<void> _revoke(Map<String, dynamic> device) async {
    final name = (device['device_name'] ?? '').toString();
    final id = device['device_id'].toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi thiết bị?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name.isEmpty ? id : '$name\n$id'),
            const SizedBox(height: 14),
            const Text(
              'Thiết bị này sẽ không đồng bộ được nữa. Dữ liệu đã đồng bộ trước '
              'đó vẫn giữ nguyên trên máy chủ.\n\n'
              'Muốn dùng lại thì phải đăng ký lại bằng mã QR hoặc thẻ NFC mới.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _dio.post('${await _baseUrl()}/admin/devices/$id/revoke',
          options: Options(headers: await _headers()));
      await reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thu hồi thiết bị.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_describe(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _describe(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) return 'Không có quyền admin. Kiểm tra Auth Token ở phần Sync Server.';
      if (code == 503) return 'Máy chủ chưa cấu hình IZIIAPP_ADMIN_SECRET.';
      if (code == 404) return 'Không tìm thấy thiết bị.';
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Không kết nối được máy chủ.';
      }
      return e.message ?? 'Lỗi kết nối.';
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_loadedOnce) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_loadedOnce && !_requireDeviceToken) _warningBanner(),
        if (_error != null) _errorBanner(_error!),

        if (_loadedOnce && _error == null && _devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Text(
              'Chưa có thiết bị nào đăng ký.\n'
              'Dùng "Cấp mã đăng ký" để tạo mã QR hoặc ghi thẻ NFC.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ),

        if (_devices.isNotEmpty)
          ListView.separated(
            // Hai dòng này là chìa khoá để nhúng được vào SingleChildScrollView.
            shrinkWrap: widget.shrinkWrap,
            physics: widget.shrinkWrap
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _devices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) => _tile(_devices[i]),
          ),

        if (_loadedOnce) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$activeCount đang hoạt động / $totalCount tổng',
                  style: const TextStyle(fontSize: 12)),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _loading ? null : reload,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Làm mới'),
                  ),
                  if (widget.onRequestNewCode != null)
                    TextButton.icon(
                      onPressed: widget.onRequestNewCode,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Cấp mã'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _warningBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'IZIIAPP_REQUIRE_DEVICE_TOKEN đang TẮT — máy chưa đăng ký vẫn '
                'đồng bộ được. Chỉ bật sau khi tất cả máy đã đăng ký xong.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _errorBanner(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 11, height: 1.4))),
          ],
        ),
      );

  Widget _tile(Map<String, dynamic> d) {
    final activeDevice = d['active'] == true;
    final name = (d['device_name'] ?? '').toString();
    final lastUsed = (d['last_used_at'] ?? '').toString();
    final personal = (d['profile'] ?? 'shared').toString() == 'personal';
    final ownerName = (d['owner_user_name'] ?? d['owner_user_id'] ?? '').toString();
    final maxHours = d['session_max_hours'];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: widget.shrinkWrap,
      leading: Icon(
        !activeDevice
            ? Icons.phonelink_erase_rounded
            : (personal ? Icons.phone_iphone_rounded : Icons.tablet_android_rounded),
        color: !activeDevice
            ? Colors.grey
            : (personal ? const Color(0xFF6366F1) : Colors.green),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(name.isEmpty ? d['device_id'].toString() : name,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
          // Nhãn chế độ: quản lý cần thấy ngay máy nào được miễn điểm danh,
          // vì đó là ngoại lệ của quy tắc an toàn chứ không phải mặc định.
          if (personal) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('CÁ NHÂN',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1))),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d['device_id'].toString(),
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          if (personal)
            Text(
              'Chủ máy: ${ownerName.isEmpty ? "(chưa khai)" : ownerName}'
              ' · ca ${maxHours == null ? "không giới hạn" : "$maxHours giờ"}'
              ' · không cần điểm danh',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1)),
            ),
          Text(
            activeDevice
                ? (lastUsed.isEmpty
                    ? 'Chưa đồng bộ lần nào'
                    : 'Hoạt động gần nhất: ${_shortTime(lastUsed)}')
                : 'Đã thu hồi ${_shortTime(d['revoked_at']?.toString() ?? '')}',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      trailing: activeDevice
          ? IconButton(
              tooltip: 'Thu hồi',
              icon: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _revoke(d),
            )
          : null,
    );
  }

  String _shortTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
