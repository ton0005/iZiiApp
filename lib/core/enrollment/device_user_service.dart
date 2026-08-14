import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../device_identity/device_identity_service.dart';
import '../settings/settings_service.dart';

/// Biến danh tính THIẾT BỊ thành User của Chat / Services / Products.
///
/// MÔ HÌNH: **một thiết bị = một User**.
///
/// Thay cho các User demo cứng trong code (Quill Phan, Trần Thị Bích...), mỗi
/// máy đã đăng ký trở thành một danh tính thật:
///
///   User.id   = device_id  (do DeviceIdentityService sinh, server xác thực)
///   User.name = device_name (đặt lúc đăng ký, sửa được)
///
/// VÌ SAO DÙNG device_id LÀM User.id: `/sync/push` nay lấy `actor_device_id`
/// TỪ TOKEN chứ không tin giá trị client tự khai. Nghĩa là mọi tin nhắn, đơn
/// hàng, dịch vụ do máy này tạo ra đều truy được về đúng thiết bị — điều mà
/// User demo không làm được vì ai cũng có thể tự nhận là bất kỳ ai.
///
/// ⚠️ GIỚI HẠN CẦN BIẾT: mô hình này giả định mỗi người dùng một máy riêng.
/// Nếu một tablet được nhiều ca dùng chung thì cả hai ca sẽ hiện là CÙNG MỘT
/// người. Khi đó phải bổ sung lớp "check-in đầu ca" tách user khỏi device —
/// đặc biệt quan trọng với cảnh báo Alone Worker, vì cảnh báo cần nói được AI
/// đang trong phòng chứ không phải máy nào.
class DeviceUserService {
  static final DeviceUserService _instance = DeviceUserService._internal();
  factory DeviceUserService() => _instance;
  DeviceUserService._internal();

  final AppDatabase _db = AppDatabase();
  final SettingsService _settings = SettingsService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));

  /// Đảm bảo máy này có một User tương ứng và đang là user hoạt động.
  ///
  /// Gọi lúc khởi động app và sau mỗi lần đăng ký thành công.
  /// Trả về userId (= deviceId), hoặc null nếu chưa lấy được danh tính.
  Future<String?> ensureLocalUser() async {
    try {
      final identity = await DeviceIdentityService().getOrCreateIdentity();
      final deviceId = identity.deviceId;
      final name = identity.deviceName.isNotEmpty ? identity.deviceName : deviceId;

      await _db.into(_db.users).insertOnConflictUpdate(
            User(
              id: deviceId,
              name: name,
              type: 'both',
              kycStatus: 'verified',
              createdAt: DateTime.now(),
            ),
          );

      await _settings.saveActiveUserId(deviceId);

      // Đã có người đăng nhập từ phiên trước → khôi phục tên của họ.
      final saved = await _settings.getLoggedInDisplayName();
      if (saved.isNotEmpty) {
        await applyLoggedInName(saved);
      }
      return deviceId;
    } catch (e) {
      // ignore: avoid_print
      print('[DeviceUser] Không tạo được User từ thiết bị: $e');
      return null;
    }
  }

  /// Gắn tên người đang đăng nhập vào danh tính của máy này.
  ///
  /// ⚠️ CHỈ ĐỔI TÊN, TUYỆT ĐỐI KHÔNG ĐỔI `User.id`.
  ///
  /// `User.id` = `device_id` là khoá định tuyến của cả hệ thống:
  ///   • `/call/ws/{id}` — socket tín hiệu WebRTC
  ///   • `target_id` trong mọi gói call_invite / sdp / ice
  ///   • khoá lưu device token (`getDeviceToken(serverUrl)`)
  ///   • `actor_device_id` mà server lấy TỪ TOKEN khi ghi audit
  ///
  /// Đổi id giữa chừng làm lệch toàn bộ những thứ trên. Đó chính là lỗi đã
  /// gặp: đăng nhập xong, socket vẫn nằm dưới `izii-d-1093d407` trong khi gói
  /// tín hiệu mang `user_quill_phan` — không bao giờ khớp, mọi cuộc gọi im
  /// lặng mà không báo lỗi gì.
  ///
  /// Tên hiển thị dạng "Trần Thị Bích · iPad phòng M1" để người nhận biết cả
  /// người lẫn máy — quan trọng khi một người dùng nhiều máy.
  Future<void> applyLoggedInName(String employeeName) async {
    final name = employeeName.trim();
    if (name.isEmpty) return;
    try {
      final identity = await DeviceIdentityService().getOrCreateIdentity();
      final deviceLabel = identity.deviceName.trim();
      final display =
          deviceLabel.isEmpty || deviceLabel == identity.deviceId
              ? name
              : '$name · $deviceLabel';

      await (_db.update(_db.users)..where((u) => u.id.equals(identity.deviceId)))
          .write(UsersCompanion(name: Value(display)));

      await _settings.saveLoggedInDisplayName(name);

      // Đẩy tên mới lên server để các máy khác thấy trong danh bạ.
      await _pushDisplayName(identity.deviceId, display);

      // ignore: avoid_print
      print('[DeviceUser] Danh tính giữ nguyên ${identity.deviceId}, '
          'tên hiển thị → "$display"');
    } catch (e) {
      // ignore: avoid_print
      print('[DeviceUser] Không đặt được tên hiển thị: $e');
    }
  }

  /// Xoá tên người đăng nhập, quay về tên máy. Gọi khi đăng xuất / kết ca.
  Future<void> clearLoggedInName() async {
    try {
      final identity = await DeviceIdentityService().getOrCreateIdentity();
      final fallback = identity.deviceName.isNotEmpty
          ? identity.deviceName
          : identity.deviceId;
      await (_db.update(_db.users)..where((u) => u.id.equals(identity.deviceId)))
          .write(UsersCompanion(name: Value(fallback)));
      await _settings.saveLoggedInDisplayName('');
      await _pushDisplayName(identity.deviceId, fallback);
    } catch (_) {}
  }

  /// Báo tên hiển thị mới cho server. Thất bại không sao — tên local vẫn đúng,
  /// lần đăng ký lại hoặc heartbeat sau sẽ đồng bộ.
  Future<void> _pushDisplayName(String deviceId, String displayName) async {
    try {
      final url =
          (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');
      if (url.isEmpty) return;
      final token = await _settings.getDeviceToken(url);
      await _dio.post(
        '$url/api/v1/devices/display-name',
        data: {'device_id': deviceId, 'display_name': displayName},
        options: Options(headers: {
          if (token != null && token.isNotEmpty) 'X-iZii-Device-Token': token,
        }),
      );
    } catch (_) {}
  }

  /// Kéo danh bạ thiết bị từ server và ghi vào bảng `users` local.
  ///
  /// Trả về số liên hệ đã đồng bộ. Trả 0 nếu server không hỗ trợ endpoint này
  /// (bản cũ) hoặc mất mạng — khi đó Chat vẫn dùng danh bạ đang có.
  Future<int> syncDirectory() async {
    try {
      final url = (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');
      if (url.isEmpty) return 0;

      final deviceToken = await _settings.getDeviceToken(url);
      final resp = await _dio.get(
        '$url/devices/directory',
        options: Options(headers: {
          if (deviceToken != null && deviceToken.isNotEmpty)
            'X-iZii-Device-Token': deviceToken,
        }),
      );

      final data = Map<String, dynamic>.from(resp.data);
      final list = (data['devices'] as List?) ?? const [];
      final myId = (await DeviceIdentityService().getOrCreateIdentity()).deviceId;

      var count = 0;
      for (final raw in list) {
        final d = Map<String, dynamic>.from(raw as Map);
        final id = (d['device_id'] ?? '').toString();
        if (id.isEmpty) continue;

        final name = (d['device_name'] ?? '').toString();
        await _db.into(_db.users).insertOnConflictUpdate(
              User(
                id: id,
                // Máy của chính mình thì gắn nhãn cho dễ nhận ra trong danh bạ.
                name: id == myId
                    ? '${name.isEmpty ? id : name} (máy này)'
                    : (name.isEmpty ? id : name),
                type: 'both',
                kycStatus: 'verified',
                createdAt: DateTime.now(),
              ),
            );
        count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Danh bạ để hiển thị: mọi User trừ chính mình.
  Future<List<User>> getContacts() async {
    final myId = await _settings.getActiveUserId();
    final all = await _db.select(_db.users).get();
    return all.where((u) => u.id != myId).toList();
  }

  /// Máy này đã đăng ký với server đang chọn chưa.
  Future<bool> isEnrolled() async {
    final url = (await _settings.getSyncServerUrl()).replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) return false;
    final t = await _settings.getDeviceToken(url);
    return t != null && t.isNotEmpty;
  }

  /// Đổi tên hiển thị của máy này trong danh bạ.
  Future<void> renameLocalUser(String newName) async {
    final identity = await DeviceIdentityService().getOrCreateIdentity();
    await (_db.update(_db.users)..where((t) => t.id.equals(identity.deviceId)))
        .write(UsersCompanion(name: Value(newName)));
  }
}
