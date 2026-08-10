import 'nfc_uri_service.dart';

/// Thẻ nhân viên NFC — dùng để điểm danh đầu ca (G1).
///
/// ĐÂY LÀ LOẠI THẺ THỨ BA trong hệ thống, đừng nhầm với hai loại kia:
///
///   | Loại thẻ        | Nội dung              | Vòng đời                    |
///   |-----------------|-----------------------|-----------------------------|
///   | Đăng ký thiết bị| vé mời                | dùng MỘT LẦN, hết hạn 10 phút|
///   | Công việc phòng | phòng + loại việc     | dán cố định ở cửa phòng      |
///   | **Nhân viên**   | mã + tên nhân viên    | **cấp cho từng người, dùng lâu dài** |
///
/// Thẻ nhân viên là cách điểm danh nhanh nhất khi đang đeo găng — chạm máy vào
/// thẻ là xong, không phải cuộn tìm tên trong danh sách hàng trăm người.
///
/// ⚠️ THẺ NÀY KHÔNG PHẢI GIẤY TỜ TUỲ THÂN. Nó chỉ chứa mã nhân viên, không chứa
/// bí mật nào. Ai nhặt được thẻ cũng đọc được mã — nhưng mã nhân viên vốn không
/// phải bí mật. Nếu tổ cần chống mạo danh thì dùng thêm PIN.
class EmployeeBadge {
  final String userId;
  final String userName;
  final String department;

  const EmployeeBadge({
    required this.userId,
    this.userName = '',
    this.department = '',
  });

  /// Chuỗi ghi lên thẻ. Tham số viết tắt để vừa NTAG213 (144 byte).
  String toUri() {
    final n = userName.isEmpty ? '' : '&n=${Uri.encodeComponent(userName)}';
    final d = department.isEmpty ? '' : '&d=${Uri.encodeComponent(department)}';
    return 'izii://staff?u=${Uri.encodeComponent(userId)}$n$d';
  }

  static EmployeeBadge? tryParse(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      final userId = uri.queryParameters['u'];
      if (userId == null || userId.isEmpty) return null;
      return EmployeeBadge(
        userId: Uri.decodeComponent(userId),
        userName: Uri.decodeComponent(uri.queryParameters['n'] ?? ''),
        department: Uri.decodeComponent(uri.queryParameters['d'] ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  int get estimatedBytes => toUri().length + 9;
  bool get fitsNtag213 => estimatedBytes <= 144;

  String get displayName => userName.isNotEmpty ? userName : userId;

  @override
  String toString() =>
      '$displayName${department.isEmpty ? '' : ' · $department'}';
}

/// Đọc/ghi thẻ nhân viên.
class EmployeeBadgeService {
  static const int ntag213Capacity = 144;

  static Future<bool> isAvailable() => NfcUriService.isAvailable();

  /// Ghi thẻ cho một nhân viên. Quản lý làm một lần khi cấp thẻ.
  static Future<void> write(
    EmployeeBadge badge, {
    void Function(String message)? onStatus,
  }) async {
    if (badge.fitsNtag213 == false) {
      throw NfcTagException(
        'Nội dung ${badge.estimatedBytes} byte, vượt quá $ntag213Capacity byte của '
        'NTAG213. Rút ngắn tên hoặc bỏ tên phòng ban.',
      );
    }
    await NfcUriService.writeUri(badge.toUri(), onStatus: onStatus);
  }

  /// Đọc thẻ nhân viên khi điểm danh.
  static Future<EmployeeBadge> read({
    void Function(String message)? onStatus,
  }) async {
    final raw = await NfcUriService.readUri(onStatus: onStatus);
    final badge = EmployeeBadge.tryParse(raw);
    if (badge == null) {
      // Phân biệt rõ với hai loại thẻ kia để công nhân không loay hoay.
      if (raw.contains('izii://enroll')) {
        throw NfcTagException(
          'Đây là thẻ ĐĂNG KÝ THIẾT BỊ, không phải thẻ nhân viên.',
        );
      }
      if (raw.contains('izii://job')) {
        throw NfcTagException(
          'Đây là thẻ CÔNG VIỆC dán ở cửa phòng, không phải thẻ nhân viên.',
        );
      }
      throw NfcTagException('Thẻ này không phải thẻ nhân viên iZii.');
    }
    return badge;
  }

  static Future<void> stop() => NfcUriService.stop();
}
