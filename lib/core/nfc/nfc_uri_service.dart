import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

/// Lớp đọc/ghi URI lên thẻ NDEF dùng chung.
///
/// Tách riêng khỏi luồng đăng ký thiết bị vì nay có HAI loại thẻ khác nhau:
///   • Thẻ đăng ký thiết bị  → NfcEnrollmentService
///   • Thẻ công việc phòng   → JobTagService
///
/// Cả hai đều chỉ cần "ghi một URI" / "đọc một URI", nên phần NDEF thô nằm ở
/// đây thay vì chép lại hai lần.
///
/// ⚠️ Mô hình THẺ, không phải chạm hai điện thoại — Android Beam đã gỡ từ
/// Android 14 và iOS chưa bao giờ mở P2P NFC cho app bên thứ ba.
class NfcUriService {
  /// Thiết bị có NFC và đang bật không.
  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.checkAvailability() == NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  /// Ghi một URI lên thẻ.
  ///
  /// Ném [NfcTagException] với thông điệp tiếng Việt dễ hiểu — người dùng cuối
  /// là công nhân, không phải lập trình viên.
  static Future<void> writeUri(
    String uri, {
    void Function(String message)? onStatus,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<void>();
    onStatus?.call('Đưa thẻ NFC lại gần mặt sau máy...');

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            throw NfcTagException('Thẻ này không hỗ trợ NDEF. Dùng thẻ NTAG213/215.');
          }
          if (!ndef.isWritable) {
            throw NfcTagException('Thẻ đang khoá chỉ đọc, không ghi được.');
          }

          final message = NdefMessage(records: [createUriRecord(uri)]);
          if (ndef.maxSize < message.byteLength) {
            throw NfcTagException(
              'Nội dung ${message.byteLength} byte nhưng thẻ chỉ chứa được '
              '${ndef.maxSize} byte. Dùng NTAG215 hoặc rút ngắn nhãn.',
            );
          }

          await ndef.write(message: message);
          onStatus?.call('✅ Đã ghi thẻ.');
          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return completer.future.timeout(timeout, onTimeout: () async {
      await NfcManager.instance.stopSession();
      throw NfcTagException('Hết thời gian chờ thẻ. Thử lại và giữ máy lâu hơn.');
    });
  }

  /// Đọc URI đầu tiên tìm được trên thẻ.
  static Future<String> readUri({
    void Function(String message)? onStatus,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<String>();
    onStatus?.call('Chạm máy vào thẻ...');

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          final message = await ndef?.read();
          if (message == null || message.records.isEmpty) {
            throw NfcTagException('Thẻ trống hoặc không đọc được.');
          }

          String? found;
          for (final record in message.records) {
            final raw = decodeRecord(record);
            if (raw != null && raw.isNotEmpty) {
              found = raw;
              break;
            }
          }
          if (found == null) {
            throw NfcTagException('Không đọc được nội dung trên thẻ.');
          }

          onStatus?.call('✅ Đã đọc thẻ.');
          if (!completer.isCompleted) completer.complete(found);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return completer.future.timeout(timeout, onTimeout: () async {
      await NfcManager.instance.stopSession();
      throw NfcTagException('Hết thời gian chờ thẻ.');
    });
  }

  /// Xoá nội dung thẻ — dùng khi "bỏ chọn thẻ" cho một công việc.
  static Future<void> eraseTag({
    void Function(String message)? onStatus,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Ghi đè bằng một record rỗng thay vì format lại thẻ: nhanh hơn và không
    // làm hỏng cấu trúc NDEF, thẻ vẫn ghi lại được sau này.
    await writeUri('izii://empty', onStatus: onStatus, timeout: timeout);
  }

  static Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  // ── NDEF thô ──────────────────────────────────────────────────────────────

  /// URI record với byte tiền tố 0x00 (URI đầy đủ, không rút gọn).
  static NdefRecord createUriRecord(String uri) {
    final uriBytes = Uint8List.fromList(uri.codeUnits);
    final payload = Uint8List(1 + uriBytes.length);
    payload[0] = 0x00;
    payload.setRange(1, payload.length, uriBytes);

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]), // 'U'
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  /// Giải mã record về chuỗi. Xử lý cả URI record lẫn Text record.
  static String? decodeRecord(NdefRecord record) {
    try {
      final payload = record.payload;
      if (payload.isEmpty) return null;
      final type = String.fromCharCodes(record.type);

      if (type == 'U') {
        return _uriPrefix(payload[0]) + String.fromCharCodes(payload.sublist(1));
      }
      if (type == 'T') {
        final langLen = payload[0] & 0x3F;
        return String.fromCharCodes(payload.sublist(1 + langLen));
      }
      return String.fromCharCodes(payload);
    } catch (_) {
      return null;
    }
  }

  static String _uriPrefix(int code) {
    const prefixes = <int, String>{
      0x00: '',
      0x01: 'http://www.',
      0x02: 'https://www.',
      0x03: 'http://',
      0x04: 'https://',
    };
    return prefixes[code] ?? '';
  }
}

/// Lỗi thẻ NFC với thông điệp đã sẵn sàng hiển thị cho người dùng cuối.
class NfcTagException implements Exception {
  final String message;
  NfcTagException(this.message);
  @override
  String toString() => message;
}
