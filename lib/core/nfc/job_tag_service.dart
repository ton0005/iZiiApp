import 'nfc_uri_service.dart';

/// Nội dung một **thẻ công việc** dán tại phòng trồng.
///
/// KHÁC VỚI THẺ ĐĂNG KÝ THIẾT BỊ:
///   • Thẻ đăng ký  → vé mời dùng MỘT LẦN, hết hạn sau vài phút
///   • Thẻ công việc → dán CỐ ĐỊNH ở cửa phòng, dùng lại mãi
///
/// VÌ SAO KHÔNG GHI job_id VÀO THẺ: công việc được tạo mới mỗi ngày (watering
/// hôm nay khác watering hôm qua). Nếu thẻ trỏ tới một job_id cụ thể thì hôm
/// sau phải ghi lại thẻ — không ai làm nổi với 66 phòng.
///
/// Thay vào đó thẻ mang **phòng + loại công việc**. Công nhân chạm thẻ ở cửa
/// Room 10 là app mở thẳng công việc Watering đang mở của phòng đó, hoặc tạo
/// mới nếu chưa có. Thẻ dán một lần dùng cả vụ.
class JobTag {
  final String roomId;      // room_10
  final String roomName;    // Room 10
  final String jobType;     // watering | prochloraz | alone_worker | ...
  final String label;       // nhãn tự do để in dán ngoài thẻ

  const JobTag({
    required this.roomId,
    required this.roomName,
    required this.jobType,
    this.label = '',
  });

  /// Chuỗi ghi lên thẻ. Dùng URI scheme để iOS đọc được cả khi app chưa mở.
  ///
  /// Giữ tham số THẬT NGẮN vì NTAG213 chỉ có 144 byte:
  ///   r  = room id, n = room name, t = job type, l = label
  String toUri() {
    final n = Uri.encodeComponent(roomName);
    final l = label.isEmpty ? '' : '&l=${Uri.encodeComponent(label)}';
    return 'izii://job?r=$roomId&n=$n&t=$jobType$l';
  }

  static JobTag? tryParse(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      // Chấp nhận cả izii://job và các URL http có cùng query, phòng khi thẻ
      // được ghi bằng công cụ NFC ngoài.
      final roomId = uri.queryParameters['r'];
      final jobType = uri.queryParameters['t'];
      if (roomId == null || roomId.isEmpty) return null;
      if (jobType == null || jobType.isEmpty) return null;

      return JobTag(
        roomId: roomId,
        roomName: Uri.decodeComponent(uri.queryParameters['n'] ?? roomId),
        jobType: jobType,
        label: Uri.decodeComponent(uri.queryParameters['l'] ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  /// Ước lượng dung lượng thẻ cần dùng, để cảnh báo TRƯỚC khi chạm thẻ thay vì
  /// để người dùng chạm rồi mới báo lỗi "thẻ quá nhỏ".
  ///
  /// Payload = 1 byte tiền tố URI + độ dài chuỗi; cộng ~8 byte header NDEF.
  int get estimatedBytes => toUri().length + 9;

  /// NTAG213 có 144 byte khả dụng.
  bool get fitsNtag213 => estimatedBytes <= 144;

  @override
  String toString() => '$roomName · $jobType${label.isEmpty ? '' : ' · $label'}';
}

/// Đọc/ghi thẻ công việc NTAG213 dán tại phòng.
class JobTagService {
  static const int ntag213Capacity = 144;

  static Future<bool> isAvailable() => NfcUriService.isAvailable();

  /// Ghi thẻ cho một công việc.
  static Future<void> write(
    JobTag tag, {
    void Function(String message)? onStatus,
  }) async {
    if (!tag.fitsNtag213) {
      throw NfcTagException(
        'Nội dung ${tag.estimatedBytes} byte, vượt quá $ntag213Capacity byte của '
        'NTAG213. Rút ngắn nhãn hoặc dùng thẻ NTAG215.',
      );
    }
    await NfcUriService.writeUri(tag.toUri(), onStatus: onStatus);
  }

  /// Đọc thẻ công việc. Ném lỗi nếu thẻ không phải thẻ công việc iZii.
  static Future<JobTag> read({void Function(String message)? onStatus}) async {
    final raw = await NfcUriService.readUri(onStatus: onStatus);
    final tag = JobTag.tryParse(raw);
    if (tag == null) {
      throw NfcTagException(
        'Thẻ này không phải thẻ công việc iZii. '
        'Có thể là thẻ đăng ký thiết bị hoặc thẻ của hệ thống khác.',
      );
    }
    return tag;
  }

  /// Xoá liên kết — "bỏ chọn thẻ".
  static Future<void> erase({void Function(String message)? onStatus}) =>
      NfcUriService.eraseTag(onStatus: onStatus);

  static Future<void> stop() => NfcUriService.stop();
}
