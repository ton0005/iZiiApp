import 'dart:convert';

enum ChatMessageType {
  text,
  file,
  recordLink,
  location,
  sos,
}

class ChatMessageContent {
  final String? text;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? recordType; // 'lead' | 'deal' | 'job' | 'service'
  final String? recordId;
  final double? latitude;
  final double? longitude;
  final String? alertMessage;

  ChatMessageContent({
    this.text,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.recordType,
    this.recordId,
    this.latitude,
    this.longitude,
    this.alertMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      if (text != null) 'text': text,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (recordType != null) 'recordType': recordType,
      if (recordId != null) 'recordId': recordId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (alertMessage != null) 'alertMessage': alertMessage,
    };
  }

  factory ChatMessageContent.fromMap(Map<String, dynamic> map) {
    return ChatMessageContent(
      text: map['text'] as String?,
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as int?,
      recordType: map['recordType'] as String?,
      recordId: map['recordId'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      alertMessage: map['alertMessage'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatMessageContent.fromJson(String source) =>
      ChatMessageContent.fromMap(json.decode(source) as Map<String, dynamic>);
}

enum ChatPresenceState {
  onlineSynced,
  syncPaused,
  offline,
  private,
}

extension ChatPresenceStateExtension on ChatPresenceState {
  String get value {
    switch (this) {
      case ChatPresenceState.onlineSynced:
        return 'online_synced';
      case ChatPresenceState.syncPaused:
        return 'sync_paused';
      case ChatPresenceState.offline:
        return 'offline';
      case ChatPresenceState.private:
        return 'private';
    }
  }

  static ChatPresenceState fromString(String value) {
    switch (value) {
      case 'online_synced':
        return ChatPresenceState.onlineSynced;
      case 'sync_paused':
        return ChatPresenceState.syncPaused;
      case 'private':
        return ChatPresenceState.private;
      default:
        return ChatPresenceState.offline;
    }
  }
}

class ChatWebSocketEvent {
  final String event;
  final Map<String, dynamic> data;

  ChatWebSocketEvent({
    required this.event,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'event': event,
      'data': data,
    };
  }

  factory ChatWebSocketEvent.fromMap(Map<String, dynamic> map) {
    return ChatWebSocketEvent(
      event: map['event'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatWebSocketEvent.fromJson(String source) =>
      ChatWebSocketEvent.fromMap(json.decode(source) as Map<String, dynamic>);
}

// ============================================================
// Track 3: E2EE Messaging Models
// ============================================================

/// Represents an encrypted chat message ready for device-level delivery.
/// The server sees only ciphertext and cannot read the plaintext.
class EncryptedChatMessage {
  final String messageId;
  final String conversationId;
  final String senderDeviceId;
  final String recipientDeviceId;
  final String encryptedContentBase64; // AES-256-GCM ciphertext
  final String nonceBase64;            // GCM nonce/IV
  final String signatureBase64;        // ED25519 signature of ciphertext hash
  final DateTime sentAt;

  EncryptedChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    required this.encryptedContentBase64,
    required this.nonceBase64,
    required this.signatureBase64,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'conversation_id': conversationId,
      'sender_device_id': senderDeviceId,
      'recipient_device_id': recipientDeviceId,
      'encrypted_content': encryptedContentBase64,
      'nonce': nonceBase64,
      'signature': signatureBase64,
      'sent_at': sentAt.toIso8601String(),
    };
  }

  factory EncryptedChatMessage.fromMap(Map<String, dynamic> map) {
    return EncryptedChatMessage(
      messageId: map['message_id'] as String,
      conversationId: map['conversation_id'] as String,
      senderDeviceId: map['sender_device_id'] as String,
      recipientDeviceId: map['recipient_device_id'] as String,
      encryptedContentBase64: map['encrypted_content'] as String,
      nonceBase64: map['nonce'] as String,
      signatureBase64: map['signature'] as String,
      sentAt: DateTime.parse(map['sent_at'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory EncryptedChatMessage.fromJson(String source) =>
      EncryptedChatMessage.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// Envelope for multi-device message delivery.
/// Contains one encrypted copy per recipient device.
class DeviceChatEnvelope {
  final String conversationId;
  final String senderDeviceId;
  final Map<String, EncryptedChatMessage> payloadsPerDevice; // deviceId -> encrypted msg

  DeviceChatEnvelope({
    required this.conversationId,
    required this.senderDeviceId,
    required this.payloadsPerDevice,
  });

  Map<String, dynamic> toMap() {
    final payloadsMap = <String, dynamic>{};
    for (final entry in payloadsPerDevice.entries) {
      payloadsMap[entry.key] = {
        'ciphertext': entry.value.encryptedContentBase64,
        'nonce': entry.value.nonceBase64,
        'signature': entry.value.signatureBase64,
      };
    }
    return {
      'conversation_id': conversationId,
      'sender_device_id': senderDeviceId,
      'payloads': payloadsMap,
    };
  }

  factory DeviceChatEnvelope.fromMap(Map<String, dynamic> map) {
    final payloadsRaw = Map<String, dynamic>.from(map['payloads'] as Map);
    final payloads = <String, EncryptedChatMessage>{};
    for (final entry in payloadsRaw.entries) {
      final p = Map<String, dynamic>.from(entry.value as Map);
      payloads[entry.key] = EncryptedChatMessage(
        messageId: map['message_id'] as String? ?? '',
        conversationId: map['conversation_id'] as String,
        senderDeviceId: map['sender_device_id'] as String,
        recipientDeviceId: entry.key,
        encryptedContentBase64: p['ciphertext'] as String,
        nonceBase64: p['nonce'] as String,
        signatureBase64: p['signature'] as String,
        sentAt: DateTime.tryParse(map['sent_at'] as String? ?? '') ?? DateTime.now(),
      );
    }
    return DeviceChatEnvelope(
      conversationId: map['conversation_id'] as String,
      senderDeviceId: map['sender_device_id'] as String,
      payloadsPerDevice: payloads,
    );
  }

  String toJson() => json.encode(toMap());

  factory DeviceChatEnvelope.fromJson(String source) =>
      DeviceChatEnvelope.fromMap(json.decode(source) as Map<String, dynamic>);
}
