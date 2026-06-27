import 'dart:convert';
import 'dart:typed_data';

/// BLE Message types (similar to Bitchat MessageType)
enum BleMessageType {
  announce(0x01),
  keyExchange(0x02),
  leave(0x03),
  message(0x04),
  fragmentStart(0x05),
  fragmentContinue(0x06),
  fragmentEnd(0x07),
  syncRequest(0x08),
  syncResponse(0x09),
  shareRequest(0x0A),
  shareResponse(0x0B);

  final int value;
  const BleMessageType(this.value);

  static BleMessageType fromInt(int val) {
    return BleMessageType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => BleMessageType.message,
    );
  }
}

/// BLE Fragment representation for large payload transfers over limited MTU.
class BleFragment {
  final List<int> fragmentId; // 8 bytes random ID
  final BleMessageType type; // BleMessageType.fragmentStart / fragmentContinue / fragmentEnd
  final int index; // 2 bytes
  final int total; // 2 bytes
  final int originalType; // 1 byte
  final List<int> data;

  BleFragment({
    required this.fragmentId,
    required this.type,
    required this.index,
    required this.total,
    required this.originalType,
    required this.data,
  });

  /// Serialize fragment to raw byte array for BLE write
  List<int> toBytes() {
    final builder = BytesBuilder();
    builder.add(fragmentId); // 8 bytes
    builder.addByte(type.value); // 1 byte
    
    // Index (2 bytes, big-endian)
    builder.addByte((index >> 8) & 0xFF);
    builder.addByte(index & 0xFF);
    
    // Total (2 bytes, big-endian)
    builder.addByte((total >> 8) & 0xFF);
    builder.addByte(total & 0xFF);
    
    builder.addByte(originalType); // 1 byte
    builder.add(data); // remaining bytes
    return builder.toBytes();
  }

  /// Parse fragment from raw bytes received from BLE notification
  factory BleFragment.fromBytes(List<int> bytes) {
    if (bytes.length < 14) {
      throw FormatException('Invalid BLE fragment length: ${bytes.length}');
    }

    final fragmentId = bytes.sublist(0, 8);
    final typeVal = bytes[8];
    
    final index = (bytes[9] << 8) | bytes[10];
    final total = (bytes[11] << 8) | bytes[12];
    final originalType = bytes[13];
    
    final data = bytes.sublist(14);

    return BleFragment(
      fragmentId: fragmentId,
      type: BleMessageType.fromInt(typeVal),
      index: index,
      total: total,
      originalType: originalType,
      data: data,
    );
  }
}

/// A packet that flows through the local BLE mesh network.
class BleMeshPacket {
  final String messageId;
  final String senderDeviceId;
  final String? recipientDeviceId; // Null for public/broadcast
  final List<int> payload; // Encrypted or plain payload
  final int ttl;
  final BleMessageType messageType;
  final String? signatureBase64;

  BleMeshPacket({
    required this.messageId,
    required this.senderDeviceId,
    this.recipientDeviceId,
    required this.payload,
    required this.ttl,
    required this.messageType,
    this.signatureBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'sender_device_id': senderDeviceId,
      if (recipientDeviceId != null) 'recipient_device_id': recipientDeviceId,
      'payload': base64Encode(payload),
      'ttl': ttl,
      'message_type': messageType.value,
      if (signatureBase64 != null) 'signature': signatureBase64,
    };
  }

  factory BleMeshPacket.fromMap(Map<String, dynamic> map) {
    return BleMeshPacket(
      messageId: map['message_id'] as String,
      senderDeviceId: map['sender_device_id'] as String,
      recipientDeviceId: map['recipient_device_id'] as String?,
      payload: base64Decode(map['payload'] as String),
      ttl: map['ttl'] as int? ?? 3,
      messageType: BleMessageType.fromInt(map['message_type'] as int),
      signatureBase64: map['signature'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BleMeshPacket.fromJson(String source) =>
      BleMeshPacket.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Handshake connection status tracking for BLE peers.
enum BleHandshakeStatus {
  notStarted,
  initiating,
  responding,
  established,
  failed,
}
