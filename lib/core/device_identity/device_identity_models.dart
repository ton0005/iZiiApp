import 'dart:convert';

/// Presence status of a remote device.
enum DevicePresenceStatus { online, idle, offline }

/// This device's cryptographic identity, derived from its X25519 and ED25519
/// key pairs. Created once on first launch and persisted in secure storage.
class DeviceIdentity {
  /// Deterministic device ID: "izii-d-" + first 8 hex chars of SHA-256(publicKey).
  final String deviceId;

  /// X25519 public key encoded as standard Base64.
  final String publicKeyBase64;

  /// ED25519 signing public key encoded as standard Base64.
  final String signingPublicKeyBase64;

  /// Human-readable device name, e.g. "Vinh's iPhone 15 Pro".
  final String deviceName;

  /// Platform token: 'ios' | 'android' | 'windows' | 'macos' | 'linux'.
  final String platform;

  /// Timestamp when this identity was first generated.
  final DateTime registeredAt;

  /// Short human-readable fingerprint derived from the public key.
  /// Format: first 8 hex chars of SHA-256(publicKey) in uppercase, e.g. "A3F2B91C".
  final String fingerprint;

  const DeviceIdentity({
    required this.deviceId,
    required this.publicKeyBase64,
    required this.signingPublicKeyBase64,
    required this.deviceName,
    required this.platform,
    required this.registeredAt,
    this.fingerprint = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'public_key_base64': publicKeyBase64,
      'signing_public_key_base64': signingPublicKeyBase64,
      'device_name': deviceName,
      'platform': platform,
      'registered_at': registeredAt.toIso8601String(),
      'fingerprint': fingerprint,
    };
  }

  factory DeviceIdentity.fromMap(Map<String, dynamic> map) {
    return DeviceIdentity(
      deviceId: map['device_id'] as String,
      publicKeyBase64: map['public_key_base64'] as String,
      signingPublicKeyBase64: map['signing_public_key_base64'] as String,
      deviceName: map['device_name'] as String,
      platform: map['platform'] as String,
      registeredAt: DateTime.parse(map['registered_at'] as String),
      fingerprint: map['fingerprint'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DeviceIdentity.fromJson(String source) =>
      DeviceIdentity.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'DeviceIdentity(deviceId: $deviceId, deviceName: $deviceName, platform: $platform, fingerprint: $fingerprint)';
}

/// A device belonging to another user (or the same user on a different machine)
/// as seen through the server's device registry.
class RemoteDevice {
  final String deviceId;
  final String userId;
  final String publicKeyBase64;
  final String signingPublicKeyBase64;
  final String deviceName;
  final String platform;
  final DateTime registeredAt;
  final DateTime? lastSeenAt;
  final bool isTrusted;
  final bool isRevoked;
  final DevicePresenceStatus status;

  /// Short human-readable fingerprint for device identification.
  final String fingerprint;

  const RemoteDevice({
    required this.deviceId,
    required this.userId,
    required this.publicKeyBase64,
    required this.signingPublicKeyBase64,
    required this.deviceName,
    required this.platform,
    required this.registeredAt,
    this.lastSeenAt,
    this.isTrusted = false,
    this.isRevoked = false,
    this.status = DevicePresenceStatus.offline,
    this.fingerprint = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'user_id': userId,
      'public_key_base64': publicKeyBase64,
      'signing_public_key_base64': signingPublicKeyBase64,
      'device_name': deviceName,
      'platform': platform,
      'registered_at': registeredAt.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'is_trusted': isTrusted,
      'is_revoked': isRevoked,
      'status': status.name,
      'fingerprint': fingerprint,
    };
  }

  /// Null-safe factory that handles missing fields gracefully.
  /// This prevents crashes when the server response doesn't include all fields.
  factory RemoteDevice.fromMap(Map<String, dynamic> map) {
    // Parse registered_at safely — server may return empty string or null
    DateTime registeredAt;
    final registeredAtRaw = map['registered_at'];
    if (registeredAtRaw != null && registeredAtRaw.toString().isNotEmpty) {
      try {
        registeredAt = DateTime.parse(registeredAtRaw.toString());
      } catch (_) {
        registeredAt = DateTime.now();
      }
    } else {
      registeredAt = DateTime.now();
    }

    return RemoteDevice(
      deviceId: map['device_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      publicKeyBase64: map['public_key_base64'] as String? ?? '',
      signingPublicKeyBase64: map['signing_public_key_base64'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? 'Unknown Device',
      platform: map['platform'] as String? ?? 'unknown',
      registeredAt: registeredAt,
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'].toString())
          : null,
      isTrusted: map['is_trusted'] as bool? ?? false,
      isRevoked: map['is_revoked'] as bool? ?? false,
      status: DevicePresenceStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'offline'),
        orElse: () => DevicePresenceStatus.offline,
      ),
      fingerprint: map['fingerprint'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RemoteDevice.fromJson(String source) =>
      RemoteDevice.fromMap(jsonDecode(source) as Map<String, dynamic>);

  RemoteDevice copyWith({
    String? deviceId,
    String? userId,
    String? publicKeyBase64,
    String? signingPublicKeyBase64,
    String? deviceName,
    String? platform,
    DateTime? registeredAt,
    DateTime? lastSeenAt,
    bool? isTrusted,
    bool? isRevoked,
    DevicePresenceStatus? status,
    String? fingerprint,
  }) {
    return RemoteDevice(
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      publicKeyBase64: publicKeyBase64 ?? this.publicKeyBase64,
      signingPublicKeyBase64:
          signingPublicKeyBase64 ?? this.signingPublicKeyBase64,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      registeredAt: registeredAt ?? this.registeredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isTrusted: isTrusted ?? this.isTrusted,
      isRevoked: isRevoked ?? this.isRevoked,
      status: status ?? this.status,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  @override
  String toString() =>
      'RemoteDevice(deviceId: $deviceId, userId: $userId, deviceName: $deviceName, status: ${status.name}, fingerprint: $fingerprint)';
}

/// An AES-256-GCM encrypted payload together with its ED25519 authentication
/// signature. This is the wire format exchanged between devices.
class EncryptedPayload {
  /// AES-256-GCM ciphertext encoded as standard Base64.
  final String ciphertextBase64;

  /// GCM nonce / IV encoded as standard Base64.
  final String nonceBase64;

  /// Device ID of the sender for key look-up.
  final String senderDeviceId;

  /// ED25519 signature of the SHA-256 hash of the ciphertext bytes.
  final String signatureBase64;

  /// Timestamp when the payload was created.
  final DateTime sentAt;

  const EncryptedPayload({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.senderDeviceId,
    required this.signatureBase64,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'ciphertext_base64': ciphertextBase64,
      'nonce_base64': nonceBase64,
      'sender_device_id': senderDeviceId,
      'signature_base64': signatureBase64,
      'sent_at': sentAt.toIso8601String(),
    };
  }

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) {
    return EncryptedPayload(
      ciphertextBase64: map['ciphertext_base64'] as String,
      nonceBase64: map['nonce_base64'] as String,
      senderDeviceId: map['sender_device_id'] as String,
      signatureBase64: map['signature_base64'] as String,
      sentAt: DateTime.parse(map['sent_at'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory EncryptedPayload.fromJson(String source) =>
      EncryptedPayload.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'EncryptedPayload(sender: $senderDeviceId, sentAt: $sentAt)';
}

/// An auditable trust-chain event that records lifecycle transitions for a
/// device (registration, trust, revocation). Each event is signed by the
/// acting device for tamper evidence.
class DeviceTrustEvent {
  final String id;

  /// One of: 'registered', 'trusted', 'revoked'.
  final String eventType;

  /// The device this event is about.
  final String deviceId;

  /// The device that performed the action (null for self-registration).
  final String? actorDeviceId;

  /// ED25519 signature from the actor device.
  final String signatureBase64;

  /// When this event occurred.
  final DateTime eventAt;

  const DeviceTrustEvent({
    required this.id,
    required this.eventType,
    required this.deviceId,
    this.actorDeviceId,
    required this.signatureBase64,
    required this.eventAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_type': eventType,
      'device_id': deviceId,
      'actor_device_id': actorDeviceId,
      'signature_base64': signatureBase64,
      'event_at': eventAt.toIso8601String(),
    };
  }

  factory DeviceTrustEvent.fromMap(Map<String, dynamic> map) {
    return DeviceTrustEvent(
      id: map['id'] as String,
      eventType: map['event_type'] as String,
      deviceId: map['device_id'] as String,
      actorDeviceId: map['actor_device_id'] as String?,
      signatureBase64: map['signature_base64'] as String,
      eventAt: DateTime.parse(map['event_at'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DeviceTrustEvent.fromJson(String source) =>
      DeviceTrustEvent.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'DeviceTrustEvent(id: $id, type: $eventType, device: $deviceId)';
}
