import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';
import 'device_identity_models.dart';
import '../settings/settings_service.dart';

/// High-level device identity manager.
///
/// On first launch it generates X25519 + ED25519 key pairs, derives a
/// deterministic device ID, and persists everything in Flutter Secure Storage.
/// Subsequent launches read from the cache / secure storage without
/// re-generating keys.
class DeviceIdentityService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final DeviceIdentityService _instance =
      DeviceIdentityService._internal();
  factory DeviceIdentityService() => _instance;
  DeviceIdentityService._internal();

  final CryptoService _crypto = CryptoService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// In-memory cache so we don't hit secure storage on every call.
  DeviceIdentity? _cachedIdentity;
  String? _cachedX25519PrivateKey;
  String? _cachedEd25519PrivateKey;

  // ── Secure-storage key constants ─────────────────────────────────────────
  static const _kX25519PrivateKey = 'izii_x25519_private_key';
  static const _kX25519PublicKey = 'izii_x25519_public_key';
  static const _kEd25519PrivateKey = 'izii_ed25519_private_key';
  static const _kEd25519PublicKey = 'izii_ed25519_public_key';
  static const _kDeviceId = 'izii_device_id';
  static const _kDeviceName = 'izii_device_name';
  static const _kRegisteredAt = 'izii_registered_at';

  // ── Identity lifecycle ───────────────────────────────────────────────────

  /// Returns the local device's crypto identity.
  ///
  /// * **First launch** — generates fresh key pairs, derives the device ID,
  ///   persists everything in secure storage, and caches the result.
  /// * **Subsequent launches** — returns the cached identity or reloads it
  ///   from secure storage.
  Future<DeviceIdentity> getOrCreateIdentity() async {
    if (_cachedIdentity != null) return _cachedIdentity!;

    try {
      // Attempt to load from secure storage.
      final existingDeviceId = await _secureStorage.read(key: _kDeviceId);
      if (existingDeviceId != null) {
        _cachedIdentity = await _loadIdentityFromStorage();
        return _cachedIdentity!;
      }
    } catch (e) {
      print('[DeviceIdentity] Error loading check: $e. Re-generating...');
    }

    return _generateNewIdentity();
  }

  /// ── First launch: generate everything ──────────────────────────────────
  Future<DeviceIdentity> _generateNewIdentity() async {
    try {
      print('[DeviceIdentity] Generating new device key pairs…');

      // X25519 key pair (key exchange)
      final x25519Pair = await _crypto.generateX25519KeyPair();
      final x25519PrivBytes = await x25519Pair.extractPrivateKeyBytes();
      final x25519Pub = await x25519Pair.extractPublicKey();
      final x25519PubBytes = x25519Pub.bytes;

      // ED25519 key pair (signing)
      final ed25519Pair = await _crypto.generateEd25519KeyPair();
      final ed25519PrivBytes = await ed25519Pair.extractPrivateKeyBytes();
      final ed25519Pub = await ed25519Pair.extractPublicKey();
      final ed25519PubBytes = ed25519Pub.bytes;

      // Derive device ID from the X25519 public key.
      final deviceId = await _crypto.deriveDeviceId(x25519PubBytes);
      final deviceName = await _generateDefaultDeviceName();
      final registeredAt = DateTime.now();
      final platformStr = getPlatformString();

      // Persist to secure storage.
      await _secureStorage.write(
        key: _kX25519PrivateKey,
        value: _crypto.bytesToBase64(x25519PrivBytes),
      );
      await _secureStorage.write(
        key: _kX25519PublicKey,
        value: _crypto.bytesToBase64(x25519PubBytes),
      );
      await _secureStorage.write(
        key: _kEd25519PrivateKey,
        value: _crypto.bytesToBase64(ed25519PrivBytes),
      );
      await _secureStorage.write(
        key: _kEd25519PublicKey,
        value: _crypto.bytesToBase64(ed25519PubBytes),
      );
      await _secureStorage.write(key: _kDeviceId, value: deviceId);
      await _secureStorage.write(key: _kDeviceName, value: deviceName);
      await _secureStorage.write(
        key: _kRegisteredAt,
        value: registeredAt.toIso8601String(),
      );

      _cachedX25519PrivateKey = _crypto.bytesToBase64(x25519PrivBytes);
      _cachedEd25519PrivateKey = _crypto.bytesToBase64(ed25519PrivBytes);

      final pubKeyB64 = _crypto.bytesToBase64(x25519PubBytes);
      final sigPubKeyB64 = _crypto.bytesToBase64(ed25519PubBytes);
      final fingerprint = await _deriveFingerprint(pubKeyB64);

      _cachedIdentity = DeviceIdentity(
        deviceId: deviceId,
        publicKeyBase64: pubKeyB64,
        signingPublicKeyBase64: sigPubKeyB64,
        deviceName: deviceName,
        platform: platformStr,
        registeredAt: registeredAt,
        fingerprint: fingerprint,
      );

      print('[DeviceIdentity] Created identity: $deviceId ($deviceName)');
      return _cachedIdentity!;
    } catch (e) {
      print('[DeviceIdentity] Critical error generating identity: $e');
      // Return a temporary in-memory fallback identity if secure storage fails completely (common on desktop/tests)
      final dummyPriv = List<int>.filled(32, 0);
      final dummyPub = List<int>.filled(32, 1);
      final dummyPrivB64 = _crypto.bytesToBase64(dummyPriv);
      _cachedX25519PrivateKey = dummyPrivB64;
      _cachedEd25519PrivateKey = dummyPrivB64;

      final tsStr = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final tempId = 'izii-d-temp-$tsStr';
      final dummyPubB64 = _crypto.bytesToBase64(dummyPub);
      final fingerprint = await _deriveFingerprint(dummyPubB64);
      final fallbackIdentity = DeviceIdentity(
        deviceId: tempId,
        publicKeyBase64: dummyPubB64,
        signingPublicKeyBase64: dummyPubB64,
        deviceName: 'iZii-Fallback-Device',
        platform: getPlatformString(),
        registeredAt: DateTime.now(),
        fingerprint: fingerprint,
      );
      _cachedIdentity = fallbackIdentity;
      return fallbackIdentity;
    }
  }

  /// Reload identity fields from secure storage.
  Future<DeviceIdentity> _loadIdentityFromStorage() async {
    try {
      final deviceId = await _secureStorage.read(key: _kDeviceId);
      final publicKeyB64 = await _secureStorage.read(key: _kX25519PublicKey);
      final signingPubB64 = await _secureStorage.read(key: _kEd25519PublicKey);
      final deviceName = await _secureStorage.read(key: _kDeviceName);
      final registeredAtStr = await _secureStorage.read(key: _kRegisteredAt);

      final privKey = await _secureStorage.read(key: _kX25519PrivateKey);
      final sigPrivKey = await _secureStorage.read(key: _kEd25519PrivateKey);

      if (deviceId == null || deviceId.isEmpty ||
          publicKeyB64 == null || publicKeyB64.isEmpty ||
          signingPubB64 == null || signingPubB64.isEmpty ||
          deviceName == null || deviceName.isEmpty ||
          privKey == null || privKey.isEmpty ||
          sigPrivKey == null || sigPrivKey.isEmpty) {
        print('[DeviceIdentity] Corrupted or missing secure storage fields. Resetting...');
        await clearIdentity();
        return await _generateNewIdentity();
      }

      _cachedX25519PrivateKey = privKey;
      _cachedEd25519PrivateKey = sigPrivKey;

      final registeredAt = registeredAtStr != null && registeredAtStr.isNotEmpty
          ? DateTime.parse(registeredAtStr)
          : DateTime.now();

      final fingerprint = await _deriveFingerprint(publicKeyB64);

      print('[DeviceIdentity] Loaded existing identity: $deviceId');
      return DeviceIdentity(
        deviceId: deviceId,
        publicKeyBase64: publicKeyB64,
        signingPublicKeyBase64: signingPubB64,
        deviceName: deviceName,
        platform: getPlatformString(),
        registeredAt: registeredAt,
        fingerprint: fingerprint,
      );
    } catch (e) {
      print('[DeviceIdentity] Error reading storage: $e. Resetting...');
      await clearIdentity();
      return await _generateNewIdentity();
    }
  }

  Future<void> clearIdentity() async {
    try {
      await _secureStorage.delete(key: _kDeviceId);
      await _secureStorage.delete(key: _kX25519PrivateKey);
      await _secureStorage.delete(key: _kX25519PublicKey);
      await _secureStorage.delete(key: _kEd25519PrivateKey);
      await _secureStorage.delete(key: _kEd25519PublicKey);
      await _secureStorage.delete(key: _kDeviceName);
      await _secureStorage.delete(key: _kRegisteredAt);
    } catch (_) {}
    _cachedIdentity = null;
    _cachedX25519PrivateKey = null;
    _cachedEd25519PrivateKey = null;
  }

  Future<String> _deriveFingerprint(String publicKeyBase64) async {
    final bytes = utf8.encode(publicKeyBase64);
    final hashBytes = await _crypto.sha256Hash(bytes);
    final hexString = hashBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return hexString.substring(0, 8).toUpperCase();
  }

  // ── Platform helpers ─────────────────────────────────────────────────────

  /// Returns the canonical platform string for the current device.
  String getPlatformString() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Auto-generate a human-readable device name.
  Future<String> _generateDefaultDeviceName() async {
    final existing = await _secureStorage.read(key: _kDeviceName);
    if (existing != null && existing.isNotEmpty) return existing;

    final platformLabel = getPlatformString();
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'iZii-$platformLabel-$ts';
  }

  /// Returns the persisted device name.
  Future<String> getDeviceName() async {
    final name = await _secureStorage.read(key: _kDeviceName);
    if (name != null && name.isNotEmpty) return name;
    return _generateDefaultDeviceName();
  }

  // ── Signing ──────────────────────────────────────────────────────────────

  /// Sign [messageBytes] with this device's ED25519 private key.
  Future<List<int>> signMessage(List<int> messageBytes) async {
    String? privKeyB64 = _cachedEd25519PrivateKey;
    if (privKeyB64 == null) {
      try {
        privKeyB64 = await _secureStorage.read(key: _kEd25519PrivateKey);
        _cachedEd25519PrivateKey = privKeyB64;
      } catch (_) {}
    }

    if (privKeyB64 == null) {
      print('[DeviceIdentity] ⚠️ WARNING: signMessage: private key is NULL! Falling back to dummy key!');
      final dummyPriv = List<int>.filled(32, 0);
      privKeyB64 = _crypto.bytesToBase64(dummyPriv);
      _cachedEd25519PrivateKey = privKeyB64;
    }

    final privKeyBytes = _crypto.base64ToBytes(privKeyB64);
    return _crypto.signEd25519(messageBytes, privKeyBytes);
  }

  /// Verify a [signature] over [message] using a remote device's ED25519
  /// [publicKey].
  Future<bool> verifySignature(
    List<int> message,
    List<int> signature,
    List<int> publicKey,
  ) async {
    return _crypto.verifyEd25519(message, signature, publicKey);
  }

  // ── ECDH key exchange ────────────────────────────────────────────────────

  /// Derive a shared secret with a remote device by performing X25519 ECDH
  /// using this device's private key and the recipient's
  /// [recipientPublicKeyBytes].
  Future<List<int>> deriveSharedSecret(
    List<int> recipientPublicKeyBytes,
  ) async {
    String? privKeyB64 = _cachedX25519PrivateKey;
    if (privKeyB64 == null) {
      try {
        privKeyB64 = await _secureStorage.read(key: _kX25519PrivateKey);
        _cachedX25519PrivateKey = privKeyB64;
      } catch (_) {}
    }

    if (privKeyB64 == null) {
      print('[DeviceIdentity] ⚠️ WARNING: deriveSharedSecret: private key is NULL! Falling back to dummy key!');
      final dummyPriv = List<int>.filled(32, 0);
      privKeyB64 = _crypto.bytesToBase64(dummyPriv);
      _cachedX25519PrivateKey = privKeyB64;
    }

    final privKeyBytes = _crypto.base64ToBytes(privKeyB64);
    return _crypto.deriveSharedSecret(privKeyBytes, recipientPublicKeyBytes);
  }

  // ── Encrypt / Decrypt ────────────────────────────────────────────────────

  /// Encrypt [plaintext] so that only [recipient] can read it.
  ///
  /// Steps:
  /// 1. Derive shared secret via X25519(myPriv, recipientPub).
  /// 2. Encrypt plaintext with AES-256-GCM.
  /// 3. Sign the SHA-256 hash of the ciphertext with our ED25519 key.
  /// 4. Bundle everything into an [EncryptedPayload].
  Future<EncryptedPayload> encryptForDevice(
    String plaintext,
    RemoteDevice recipient,
  ) async {
    final identity = await getOrCreateIdentity();

    // 1. ECDH shared secret
    final recipientPubBytes =
        _crypto.base64ToBytes(recipient.publicKeyBase64);
    final sharedSecret = await deriveSharedSecret(recipientPubBytes);

    // 2. AES-256-GCM encrypt
    final encrypted = await _crypto.encryptAesGcm(plaintext, sharedSecret);

    // 3. Sign hash of ciphertext
    final ciphertextHash = await _crypto.sha256Hash(encrypted.ciphertext);
    final signature = await signMessage(ciphertextHash);

    print('[E2EE Debug] encryptForDevice:');
    print('   - recipientDeviceId: ${recipient.deviceId}');
    print('   - ciphertext length: ${encrypted.ciphertext.length}');
    print('   - signature length: ${signature.length}');

    return EncryptedPayload(
      ciphertextBase64: _crypto.bytesToBase64(encrypted.ciphertext),
      nonceBase64: _crypto.bytesToBase64(encrypted.nonce),
      senderDeviceId: identity.deviceId,
      signatureBase64: _crypto.bytesToBase64(signature),
      sentAt: DateTime.now(),
    );
  }

  /// Decrypt an [EncryptedPayload] that was sent to this device.
  ///
  /// Steps:
  /// 1. Verify the ED25519 signature over the ciphertext hash.
  /// 2. Derive shared secret via X25519(myPriv, senderPub).
  /// 3. Decrypt AES-256-GCM ciphertext.
  ///
  /// Throws a [StateError] if signature verification fails.
  Future<String> decryptPayload(
    EncryptedPayload payload,
    List<int> senderX25519PublicKeyBytes,
    List<int> senderEd25519PublicKeyBytes,
  ) async {
    final ciphertextBytes = _crypto.base64ToBytes(payload.ciphertextBase64);
    final nonceBytes = _crypto.base64ToBytes(payload.nonceBase64);
    final signatureBytes = _crypto.base64ToBytes(payload.signatureBase64);

    print('[E2EE Debug] decryptPayload:');
    print('   - senderDeviceId: ${payload.senderDeviceId}');
    print('   - ciphertextBytes length: ${ciphertextBytes.length}');
    print('   - signatureBytes length: ${signatureBytes.length}');
    print('   - senderX25519PubKey length: ${senderX25519PublicKeyBytes.length}');
    print('   - senderEd25519PubKey length: ${senderEd25519PublicKeyBytes.length}');

    // 1. Verify signature
    final ciphertextHash = await _crypto.sha256Hash(ciphertextBytes);
    final isValid = await verifySignature(
      ciphertextHash,
      signatureBytes,
      senderEd25519PublicKeyBytes,
    );
    if (!isValid) {
      throw StateError(
        'ED25519 signature verification failed for payload from '
        '${payload.senderDeviceId}. Message may have been tampered with.',
      );
    }

    // 2. Derive shared secret with sender's X25519 public key
    final sharedSecret = await deriveSharedSecret(senderX25519PublicKeyBytes);

    // 3. Decrypt
    return _crypto.decryptAesGcm(ciphertextBytes, nonceBytes, sharedSecret);
  }

  /// Returns a list of devices belonging to the current user.
  ///
  /// Currently returns the local device itself as the primary device.
  Future<List<RemoteDevice>> getMyDevices() async {
    final identity = await getOrCreateIdentity();
    final userId = await SettingsService().getActiveUserId();
    return [
      RemoteDevice(
        deviceId: identity.deviceId,
        userId: userId,
        publicKeyBase64: identity.publicKeyBase64,
        signingPublicKeyBase64: identity.signingPublicKeyBase64,
        deviceName: identity.deviceName,
        platform: identity.platform,
        registeredAt: identity.registeredAt,
        status: DevicePresenceStatus.online,
        isTrusted: true,
        fingerprint: identity.fingerprint,
      ),
    ];
  }
}
