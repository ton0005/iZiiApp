import '../../../core/device_identity/device_discovery_service.dart';
import '../../../core/device_identity/device_identity_models.dart';
import '../../../core/device_identity/device_identity_service.dart';
import '../models/chat_envelope.dart';
import '../repository/chat_repository.dart';

/// Tìm thiết bị nhận của một đối tác (kèm khoá công khai).
typedef ResolveRecipients = Future<List<RemoteDevice>> Function(String peerId);

/// Mã hoá [plaintext] cho một thiết bị nhận.
typedef EncryptForDevice = Future<EncryptedPayload> Function(
    String plaintext, RemoteDevice recipient);

/// Đẩy bản mã lên server. true = server nhận.
typedef RelayEncrypted = Future<bool> Function({
  required String conversationId,
  required List<String> recipientDeviceIds,
  required Map<String, EncryptedPayload> payloads,
});

class IncomingResult {
  /// null khi bị từ chối — xem [rejectReason].
  final ChatEnvelope? envelope;
  final EnvelopeOutcome? outcome;
  final String? rejectReason;

  /// Id dùng làm `senderId` khi lưu — chính là id nằm trong tên hội thoại.
  final String? senderId;

  const IncomingResult.accepted(this.envelope, this.outcome, this.senderId)
      : rejectReason = null;
  const IncomingResult.rejected(this.rejectReason)
      : envelope = null,
        outcome = null,
        senderId = null;

  bool get isRejected => rejectReason != null;
}

/// Kênh gửi/nhận tin 1-1 bằng E2EE.
///
/// Quy tắc cốt lõi: **không bao giờ rơi về plaintext**. Chưa gửi được (mất
/// mạng, chưa có khoá người nhận) thì phong bì nằm chờ trong [E2eeOutbox] và
/// được gửi lại ở lần [flush] sau.
class DirectE2eeChannel {
  final ChatRepository _repo;
  final ResolveRecipients _resolve;
  final EncryptForDevice _encrypt;
  final RelayEncrypted _relay;
  bool _flushing = false;

  DirectE2eeChannel({
    required ChatRepository repo,
    ResolveRecipients? resolveRecipients,
    EncryptForDevice? encrypt,
    RelayEncrypted? relay,
  })  : _repo = repo,
        _resolve = resolveRecipients ?? _defaultResolve,
        _encrypt = encrypt ?? _defaultEncrypt,
        _relay = relay ?? _defaultRelay;

  static bool isDirect(String conversationId) =>
      conversationId.startsWith('direct_');

  // ── Mặc định dùng dịch vụ thật ───────────────────────────────────────────

  static Future<List<RemoteDevice>> _defaultResolve(String peerId) async {
    final discovery = DeviceDiscoveryService();
    // Khoá hội thoại 1-1 chính là device_id của đối tác.
    final direct = await discovery.getDeviceInfo(peerId);
    if (direct != null) return direct.isRevoked ? const [] : [direct];

    // Hội thoại cũ tạo bằng mã người dùng thay vì device_id: gửi tới mọi thiết
    // bị đang online của người đó.
    final online = await discovery.getOnlineDevices();
    return online.where((d) => d.userId == peerId && !d.isRevoked).toList();
  }

  static Future<EncryptedPayload> _defaultEncrypt(
          String plaintext, RemoteDevice recipient) =>
      DeviceIdentityService().encryptForDevice(plaintext, recipient);

  static Future<bool> _defaultRelay({
    required String conversationId,
    required List<String> recipientDeviceIds,
    required Map<String, EncryptedPayload> payloads,
  }) =>
      DeviceDiscoveryService().sendEncryptedMessage(
        conversationId: conversationId,
        recipientDeviceIds: recipientDeviceIds,
        payloadsPerDevice: payloads,
      );

  // ── Gửi ──────────────────────────────────────────────────────────────────

  /// Xếp phong bì vào hàng đợi rồi thử gửi ngay. Luôn trả về — thất bại không
  /// ném lỗi, phong bì ở lại hàng đợi.
  Future<void> send(ChatEnvelope envelope, {required String myId}) async {
    await _repo.enqueueE2ee(envelope);
    await flush(myId: myId);
  }

  /// Gửi các phong bì đang chờ, cũ trước. Trả về số phong bì đã gửi được.
  ///
  /// Một phong bì lỗi chặn các phong bì SAU NÓ CỦA CÙNG HỘI THOẠI (giữ thứ
  /// tự: sửa/thu hồi không được tới trước tin gốc) nhưng không chặn hội thoại
  /// khác.
  Future<int> flush({required String myId}) async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final blocked = <String>{};
      for (final row in await _repo.pendingE2ee()) {
        if (blocked.contains(row.conversationId)) continue;

        final peer = ChatRepository.directPeer(row.conversationId, myId);
        if (peer == null) {
          // Không phải hội thoại của máy này (ví dụ đổi tài khoản) — bỏ, giữ lại
          // sẽ kẹt hàng đợi vĩnh viễn.
          await _repo.removeE2ee(row.id);
          continue;
        }

        final String plaintext = row.envelope;
        try {
          final recipients = await _resolve(peer);
          if (recipients.isEmpty) {
            await _repo.markE2eeFailed(row.id, 'Chưa có khoá của $peer');
            blocked.add(row.conversationId);
            continue;
          }

          final payloads = <String, EncryptedPayload>{};
          for (final r in recipients) {
            payloads[r.deviceId] = await _encrypt(plaintext, r);
          }
          final ok = await _relay(
            conversationId: row.conversationId,
            recipientDeviceIds: payloads.keys.toList(),
            payloads: payloads,
          );
          if (ok) {
            await _repo.removeE2ee(row.id);
            sent++;
          } else {
            await _repo.markE2eeFailed(row.id, 'Server không nhận');
            blocked.add(row.conversationId);
          }
        } catch (e) {
          await _repo.markE2eeFailed(row.id, e.toString());
          blocked.add(row.conversationId);
        }
      }
    } finally {
      _flushing = false;
    }
    return sent;
  }

  // ── Nhận ─────────────────────────────────────────────────────────────────

  /// Xử lý một phong bì ĐÃ GIẢI MÃ.
  ///
  /// [conversationId] là giá trị server báo kèm bản mã. Server không đáng tin,
  /// nên phong bì (nằm trong phần mã hoá) phải tự khai cùng hội thoại — nếu
  /// không, server có thể lái bản mã sang hội thoại khác.
  ///
  /// [senderIds]/[myIds]: các danh tính có thể xuất hiện trong tên hội thoại
  /// (device_id, và mã người dùng đăng ký của thiết bị đó với hội thoại cũ).
  Future<IncomingResult> processIncoming({
    required String conversationId,
    required String plaintext,
    required Set<String> senderIds,
    required Set<String> myIds,
    DateTime? receivedAt,
  }) async {
    final ChatEnvelope envelope;
    try {
      envelope = ChatEnvelope.fromJson(plaintext);
    } on FormatException catch (e) {
      return IncomingResult.rejected('malformed: ${e.message}');
    }

    if (envelope.conversationId != conversationId) {
      return const IncomingResult.rejected('conversation_mismatch');
    }
    if (!isDirect(conversationId)) {
      return const IncomingResult.rejected('not_direct');
    }

    String? senderId;
    for (final id in senderIds) {
      if (ChatRepository.isDirectMember(conversationId, id)) {
        senderId = id;
        break;
      }
    }
    final iAmMember =
        myIds.any((id) => ChatRepository.isDirectMember(conversationId, id));
    if (senderId == null || !iAmMember) {
      return const IncomingResult.rejected('not_member');
    }
    // Người gửi và người nhận phải là HAI đầu khác nhau của hội thoại.
    if (myIds.contains(senderId)) {
      return const IncomingResult.rejected('self_loop');
    }

    final outcome = await _repo.applyEnvelope(envelope,
        senderId: senderId, receivedAt: receivedAt);
    return IncomingResult.accepted(envelope, outcome, senderId);
  }
}
