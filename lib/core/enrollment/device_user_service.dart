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
      return deviceId;
    } catch (e) {
      // Không chặn khởi động app chỉ vì tạo User thất bại — Chat sẽ rơi về
      // danh bạ demo như cũ.
      // ignore: avoid_print
      print('[DeviceUser] Không tạo được User từ thiết bị: $e');
      return null;
    }
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
