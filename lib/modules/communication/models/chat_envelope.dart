import 'dart:convert';

/// Loại sự kiện đi trong một phong bì E2EE.
///
/// Tất cả — kể cả sửa, thu hồi, thả cảm xúc, ghim — đều đi trong CÙNG kênh mã
/// hoá với tin nhắn, nên server chỉ thấy bản mã, không biết đó là tin hay là
/// một lượt thả tim.
enum ChatEnvelopeKind { message, edit, revoke, reaction, pin }

/// Nội dung được mã hoá cho từng thiết bị nhận (trường `plaintext` của E2EE).
///
/// `conversationId` nằm TRONG phần mã hoá và được bên nhận đối chiếu với
/// `conversation_id` server báo: hàng đợi server là bên không tin cậy, nếu
/// không có đối chiếu này nó có thể chuyển bản mã của hội thoại X sang Y.
class ChatEnvelope {
  static const int version = 1;

  final ChatEnvelopeKind kind;
  final String conversationId;

  /// `message`: id tin nhắn (do người gửi sinh, giữ nguyên ở mọi thiết bị).
  /// Loại khác: id của chính sự kiện, dùng để khử trùng lặp khi gửi lại.
  final String id;

  /// Tin bị tác động — bắt buộc với edit/revoke/reaction/pin.
  final String? targetId;

  final DateTime ts;

  // message
  final String? type;
  final Map<String, dynamic>? content;
  final String? replyToId;
  final String? forwardedFromId;

  // edit
  final String? newText;

  // reaction — chuỗi rỗng nghĩa là gỡ cảm xúc
  final String? emoji;

  // pin
  final bool? pinned;

  const ChatEnvelope._({
    required this.kind,
    required this.conversationId,
    required this.id,
    required this.ts,
    this.targetId,
    this.type,
    this.content,
    this.replyToId,
    this.forwardedFromId,
    this.newText,
    this.emoji,
    this.pinned,
  });

  factory ChatEnvelope.message({
    required String id,
    required String conversationId,
    required String type,
    required Map<String, dynamic> content,
    required DateTime ts,
    String? replyToId,
    String? forwardedFromId,
  }) =>
      ChatEnvelope._(
        kind: ChatEnvelopeKind.message,
        conversationId: conversationId,
        id: id,
        ts: ts,
        type: type,
        content: content,
        replyToId: replyToId,
        forwardedFromId: forwardedFromId,
      );

  factory ChatEnvelope.edit({
    required String id,
    required String conversationId,
    required String targetId,
    required String newText,
    required DateTime ts,
  }) =>
      ChatEnvelope._(
        kind: ChatEnvelopeKind.edit,
        conversationId: conversationId,
        id: id,
        ts: ts,
        targetId: targetId,
        newText: newText,
      );

  factory ChatEnvelope.revoke({
    required String id,
    required String conversationId,
    required String targetId,
    required DateTime ts,
  }) =>
      ChatEnvelope._(
        kind: ChatEnvelopeKind.revoke,
        conversationId: conversationId,
        id: id,
        ts: ts,
        targetId: targetId,
      );

  factory ChatEnvelope.reaction({
    required String id,
    required String conversationId,
    required String targetId,
    required String emoji,
    required DateTime ts,
  }) =>
      ChatEnvelope._(
        kind: ChatEnvelopeKind.reaction,
        conversationId: conversationId,
        id: id,
        ts: ts,
        targetId: targetId,
        emoji: emoji,
      );

  factory ChatEnvelope.pin({
    required String id,
    required String conversationId,
    required String targetId,
    required bool pinned,
    required DateTime ts,
  }) =>
      ChatEnvelope._(
        kind: ChatEnvelopeKind.pin,
        conversationId: conversationId,
        id: id,
        ts: ts,
        targetId: targetId,
        pinned: pinned,
      );

  String toJson() => jsonEncode({
        'v': version,
        'k': kind.name,
        'c': conversationId,
        'id': id,
        'ts': ts.toUtc().toIso8601String(),
        if (targetId != null) 'target': targetId,
        if (type != null) 'type': type,
        if (content != null) 'content': content,
        if (replyToId != null) 'reply_to': replyToId,
        if (forwardedFromId != null) 'fwd': forwardedFromId,
        if (newText != null) 'text': newText,
        if (emoji != null) 'emoji': emoji,
        if (pinned != null) 'pinned': pinned,
      });

  /// Ném [FormatException] nếu không phải phong bì hợp lệ.
  ///
  /// Bản app cũ gửi thẳng chuỗi văn bản thuần — các chuỗi đó không phải JSON có
  /// trường `v`/`k`, nên bị từ chối ở đây thay vì bị hiểu nhầm thành tin.
  factory ChatEnvelope.fromJson(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('Phong bì không phải JSON');
    }
    if (decoded is! Map) throw const FormatException('Phong bì không phải object');
    final m = Map<String, dynamic>.from(decoded);

    if (m['v'] != version) {
      throw FormatException('Phiên bản phong bì không hỗ trợ: ${m['v']}');
    }
    final kindName = m['k'];
    final kind = ChatEnvelopeKind.values.where((k) => k.name == kindName);
    if (kind.isEmpty) throw FormatException('Loại phong bì lạ: $kindName');

    String req(String key) {
      final v = m[key];
      if (v is! String || v.isEmpty) throw FormatException('Thiếu trường "$key"');
      return v;
    }

    final ts = DateTime.tryParse(m['ts']?.toString() ?? '');
    if (ts == null) throw const FormatException('Thiếu hoặc sai "ts"');

    final k = kind.first;
    final base = (
      conversationId: req('c'),
      id: req('id'),
    );

    switch (k) {
      case ChatEnvelopeKind.message:
        final content = m['content'];
        if (content is! Map) throw const FormatException('Thiếu "content"');
        return ChatEnvelope._(
          kind: k,
          conversationId: base.conversationId,
          id: base.id,
          ts: ts,
          type: (m['type'] as String?) ?? 'text',
          content: Map<String, dynamic>.from(content),
          replyToId: m['reply_to'] as String?,
          forwardedFromId: m['fwd'] as String?,
        );
      case ChatEnvelopeKind.edit:
        return ChatEnvelope._(
          kind: k,
          conversationId: base.conversationId,
          id: base.id,
          ts: ts,
          targetId: req('target'),
          newText: m['text'] as String? ?? '',
        );
      case ChatEnvelopeKind.revoke:
        return ChatEnvelope._(
          kind: k,
          conversationId: base.conversationId,
          id: base.id,
          ts: ts,
          targetId: req('target'),
        );
      case ChatEnvelopeKind.reaction:
        return ChatEnvelope._(
          kind: k,
          conversationId: base.conversationId,
          id: base.id,
          ts: ts,
          targetId: req('target'),
          emoji: m['emoji'] as String? ?? '',
        );
      case ChatEnvelopeKind.pin:
        return ChatEnvelope._(
          kind: k,
          conversationId: base.conversationId,
          id: base.id,
          ts: ts,
          targetId: req('target'),
          pinned: m['pinned'] == true,
        );
    }
  }
}
