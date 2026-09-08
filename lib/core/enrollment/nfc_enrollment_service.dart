import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'enrollment_service.dart';

/// Đọc/ghi vé mời đăng ký qua thẻ NFC (B4).
///
/// ⚠️ QUAN TRỌNG VỀ GIỚI HẠN NỀN TẢNG
///
/// Đây là mô hình **THẺ NFC**, không phải "chạm hai điện thoại vào nhau":
///   • Android Beam (NFC P2P) deprecated từ Android 10, **gỡ hoàn toàn ở
///     Android 14**.
///   • iOS chưa bao giờ mở P2P NFC cho ứng dụng bên thứ ba — Core NFC chỉ
///     đọc/ghi thẻ.
///
/// Luồng đúng: máy quản lý GHI vé lên thẻ NTAG → máy công nhân CHẠM vào thẻ.
/// Thẻ NTAG213 (144 byte) là đủ; NTAG215 nếu muốn dư chỗ.
///
/// NFC chỉ là một cách TRUYỀN khác của cùng vé mời dùng ở luồng QR — toàn bộ
/// logic đổi vé lấy token nằm trong [EnrollmentService].
class NfcEnrollmentService {
  /// Thiết bị có NFC và đang bật không.
  Future<bool> isAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  /// Ghi vé mời lên thẻ. Gọi ở máy quản lý.
  ///
  /// [onStatus] báo tiến trình để hiển thị cho người dùng ("Đưa thẻ lại gần...").
  Future<void> writeTicket(
    EnrollmentTicket ticket, {
    void Function(String message)? onStatus,
  }) async {
    final completer = Completer<void>();

    onStatus?.call('Take NFC card near the back of the device...');

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            throw Exception('The card does not support NDEF. Please use an NTAG213/215 card.');
          }
          if (!ndef.isWritable) {
            throw Exception('The card is in read-only mode, and cannot be written to.');
          }

          // Dùng URI record thay vì text record: iOS đọc được thẻ ngay cả khi
          // app chưa mở, và Android tự gợi ý mở app tương ứng.
          final message = NdefMessage(records: [
            _createUriRecord(Uri.parse(ticket.toUri())),
          ]);

          if (ndef.maxSize < _messageSize(message)) {
            throw Exception(
              'The card is too small (${ndef.maxSize} byte). Please use an NTAG213 or higher.',
            );
          }

          await ndef.write(message: message);
          onStatus?.call('✅ Successfully wrote enrollment ticket to NFC card.');
          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () async {
        await NfcManager.instance.stopSession();
        throw Exception('Timeout waiting for NFC card.');
      },
    );
  }

  /// Đọc vé mời từ thẻ. Gọi ở máy công nhân.
  ///
  /// Trả về [EnrollmentTicket] đã phân tích, hoặc ném lỗi nếu thẻ không chứa
  /// dữ liệu iZii hợp lệ.
  Future<EnrollmentTicket> readTicket({
    void Function(String message)? onStatus,
  }) async {
    final completer = Completer<EnrollmentTicket>();

    onStatus?.call('Touch the device to the NFC card...');

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          final message = await ndef?.read();
          if (message == null || message.records.isEmpty) {
            throw Exception('The card is empty or cannot be read.');
          }

          EnrollmentTicket? ticket;
          for (final record in message.records) {
            final raw = _decodeRecord(record);
            if (raw == null) continue;
            ticket = EnrollmentTicket.tryParse(raw);
            if (ticket != null) break;
          }

          if (ticket == null) {
            throw Exception('The card is not an iZii enrollment card.');
          }

          onStatus?.call('✅ Successfully read enrollment ticket.');
          if (!completer.isCompleted) completer.complete(ticket);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () async {
        await NfcManager.instance.stopSession();
        throw Exception('Timeout waiting for NFC card.');
      },
    );
  }

  /// Tạo NDEF URI record.
  NdefRecord _createUriRecord(Uri uri) {
    final uriBytes = Uint8List.fromList(uri.toString().codeUnits);
    final payload = Uint8List(1 + uriBytes.length);
    payload[0] = 0x00; // 0x00 = full URI string
    payload.setRange(1, payload.length, uriBytes);

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]), // ASCII 'U'
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  /// Giải mã một NDEF record về chuỗi.
  ///
  /// URI record có byte đầu là mã tiền tố viết tắt (0x00 = không rút gọn,
  /// 0x03 = "http://", 0x04 = "https://"...). Với scheme tuỳ biến `izii://`
  /// thì mã luôn là 0x00, nhưng vẫn xử lý các mã phổ biến để đọc được cả thẻ
  /// ghi dạng URL thường.
  String? _decodeRecord(NdefRecord record) {
    try {
      final payload = record.payload;
      if (payload.isEmpty) return null;

      // TNF 1 = Well Known. Type 'U' = URI, 'T' = Text.
      final type = String.fromCharCodes(record.type);

      if (type == 'U') {
        final prefixCode = payload[0];
        final rest = String.fromCharCodes(payload.sublist(1));
        return _uriPrefix(prefixCode) + rest;
      }

      if (type == 'T') {
        // Byte đầu: bit 0-5 là độ dài mã ngôn ngữ.
        final langLen = payload[0] & 0x3F;
        return String.fromCharCodes(payload.sublist(1 + langLen));
      }

      // Loại khác — thử đọc thô, có thể là thẻ ghi bằng công cụ ngoài.
      return String.fromCharCodes(payload);
    } catch (_) {
      return null;
    }
  }

  String _uriPrefix(int code) {
    const prefixes = <int, String>{
      0x00: '',
      0x01: 'http://www.',
      0x02: 'https://www.',
      0x03: 'http://',
      0x04: 'https://',
    };
    return prefixes[code] ?? '';
  }

  int _messageSize(NdefMessage message) {
    return message.byteLength;
  }

  Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}

/// Tiện ích nhỏ để tránh cảnh báo unused import khi build web.
typedef NfcBytes = Uint8List;

