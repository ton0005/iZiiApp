import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_service.dart';
import 'device_identity_service.dart';

/// Implements Noise Protocol XX handshake pattern (specifically `Noise_XX_25519_AESGCM_SHA256`).
/// Provides mutual authentication and establishes shared symmetric keys for E2EE chat over BLE.
class NoiseHandshakeService {
  static final NoiseHandshakeService _instance = NoiseHandshakeService._internal();
  factory NoiseHandshakeService() => _instance;
  NoiseHandshakeService._internal();

  final CryptoService _crypto = CryptoService();
  final DeviceIdentityService _identityService = DeviceIdentityService();

  // Noise protocol name
  static const String protocolName = 'Noise_XX_25519_AESGCM_SHA256';

  /// Active handshake states mapped by remote deviceId
  final Map<String, NoiseHandshakeState> _handshakes = {};

  /// Established symmetric keys mapped by remote deviceId
  final Map<String, NoiseSessionKeys> _sessions = {};

  bool isSessionEstablished(String deviceId) => _sessions.containsKey(deviceId);

  NoiseSessionKeys? getSessionKeys(String deviceId) => _sessions[deviceId];

  void clearSession(String deviceId) {
    _handshakes.remove(deviceId);
    _sessions.remove(deviceId);
  }

  void clearAllSessions() {
    _handshakes.clear();
    _sessions.clear();
  }

  /// Initialize handshaker as the Initiator
  Future<List<int>> initiateHandshake(String remoteDeviceId) async {
    clearSession(remoteDeviceId);

    final localIdentity = await _identityService.getOrCreateIdentity();
    
    // Generate fresh X25519 ephemeral keypair
    final ephemeralKeyPair = await _crypto.generateX25519KeyPair();
    final ephemeralPubBytes = (await ephemeralKeyPair.extractPublicKey()).bytes;

    final state = NoiseHandshakeState(
      role: NoiseRole.initiator,
      localStaticPublicKey: _crypto.base64ToBytes(localIdentity.publicKeyBase64),
      localEphemeralKeyPair: ephemeralKeyPair,
    );

    await state.initializeSymmetricState();
    
    // Mix ephemeral public key into hash state
    await state.mixHash(ephemeralPubBytes);
    
    _handshakes[remoteDeviceId] = state;
    
    // Message 1 payload is just the local ephemeral public key (32 bytes)
    return ephemeralPubBytes;
  }

  /// Process incoming handshake payload
  Future<List<int>?> processHandshakeMessage(String remoteDeviceId, List<int> payload) async {
    final state = _handshakes[remoteDeviceId];
    final localIdentity = await _identityService.getOrCreateIdentity();
    
    if (state == null) {
      // We are the Responder, starting a new handshake from an incoming Message 1
      if (payload.length != 32) return null; // Message 1 must be exactly 32 bytes (ephemeral key)
      
      final ephemeralKeyPair = await _crypto.generateX25519KeyPair();
      final ephemeralPubBytes = (await ephemeralKeyPair.extractPublicKey()).bytes;

      final newState = NoiseHandshakeState(
        role: NoiseRole.responder,
        localStaticPublicKey: _crypto.base64ToBytes(localIdentity.publicKeyBase64),
        localEphemeralKeyPair: ephemeralKeyPair,
        remoteEphemeralPublicKey: payload, // Message 1 is remote's ephemeral public key
      );

      await newState.initializeSymmetricState();
      
      // Mix initiator's ephemeral public key into hash state
      await newState.mixHash(payload);
      
      // Now write Message 2: <- e, ee, s, es
      // 1. Add our ephemeral public key to buffer
      await newState.mixHash(ephemeralPubBytes);

      // 2. DH between ephemerals (ee)
      final localEphemeralPriv = await newState.localEphemeralKeyPair.extractPrivateKeyBytes();
      final ee = await _crypto.deriveSharedSecret(localEphemeralPriv, newState.remoteEphemeralPublicKey!);
      await newState.mixKey(ee);

      // 3. Encrypt and mix static public key (s)
      final encryptedStaticPub = await newState.encryptAndHash(newState.localStaticPublicKey);

      // 4. DH between our static private and initiator's ephemeral (es)
      final localStaticPrivB64 = await _identityService.deriveSharedSecret(newState.remoteEphemeralPublicKey!);
      await newState.mixKey(localStaticPrivB64);

      _handshakes[remoteDeviceId] = newState;

      // Message 2 payload: e_bytes (32) + encrypted_s (32 + GCM tag)
      final message2 = <int>[...ephemeralPubBytes, ...encryptedStaticPub];
      return message2;
    }

    if (state.role == NoiseRole.initiator && state.step == 0) {
      // Process Message 2: <- e, ee, s, es
      if (payload.length < 48) return null; // 32 bytes ephemeral key + encrypted static key + MAC

      final remoteEphemeralPub = payload.sublist(0, 32);
      final encryptedStaticPub = payload.sublist(32);

      state.remoteEphemeralPublicKey = remoteEphemeralPub;
      await state.mixHash(remoteEphemeralPub);

      // DH between ephemerals (ee)
      final localEphemeralPriv = await state.localEphemeralKeyPair.extractPrivateKeyBytes();
      final ee = await _crypto.deriveSharedSecret(localEphemeralPriv, remoteEphemeralPub);
      await state.mixKey(ee);

      // Decrypt static public key (s)
      final remoteStaticPub = await state.decryptAndHash(encryptedStaticPub);
      state.remoteStaticPublicKey = remoteStaticPub;

      // DH between initiator's ephemeral and responder's static (es)
      final es = await _crypto.deriveSharedSecret(localEphemeralPriv, remoteStaticPub);
      await state.mixKey(es);

      state.step = 1;

      // Now write Message 3: -> s, se
      // 1. Encrypt and mix static public key (s)
      final encryptedStaticPubInit = await state.encryptAndHash(state.localStaticPublicKey);

      // 2. DH between initiator's static private and responder's ephemeral (se)
      final se = await _identityService.deriveSharedSecret(remoteEphemeralPub);
      await state.mixKey(se);

      // Complete handshake for Initiator, derive sessions keys
      final sessionKeys = await state.split();
      _sessions[remoteDeviceId] = sessionKeys;
      _handshakes.remove(remoteDeviceId);

      // Return Message 3 payload (encrypted static key + MAC)
      return encryptedStaticPubInit;
    }

    if (state.role == NoiseRole.responder && state.step == 0) {
      // Process Message 3: -> s, se
      final remoteStaticPubEncrypted = payload;
      
      // Decrypt initiator's static public key (s)
      final remoteStaticPub = await state.decryptAndHash(remoteStaticPubEncrypted);
      state.remoteStaticPublicKey = remoteStaticPub;

      // DH between responder's ephemeral and initiator's static (se)
      final localEphemeralPriv = await state.localEphemeralKeyPair.extractPrivateKeyBytes();
      final se = await _crypto.deriveSharedSecret(localEphemeralPriv, remoteStaticPub);
      await state.mixKey(se);

      // Complete handshake for Responder, derive sessions keys
      final sessionKeys = await state.split();
      _sessions[remoteDeviceId] = sessionKeys;
      _handshakes.remove(remoteDeviceId);

      return null; // Handshake complete
    }

    return null;
  }
}

enum NoiseRole { initiator, responder }

class NoiseHandshakeState {
  final NoiseRole role;
  final List<int> localStaticPublicKey;
  final SimpleKeyPair localEphemeralKeyPair;
  
  List<int>? remoteStaticPublicKey;
  List<int>? remoteEphemeralPublicKey;

  int step = 0;

  // Symmetric state
  late List<int> chainingKey;
  late List<int> hashState;
  List<int>? cipherKey;

  NoiseHandshakeState({
    required this.role,
    required this.localStaticPublicKey,
    required this.localEphemeralKeyPair,
    this.remoteStaticPublicKey,
    this.remoteEphemeralPublicKey,
  });

  Future<void> initializeSymmetricState() async {
    final nameBytes = utf8.encode(NoiseHandshakeService.protocolName);
    if (nameBytes.length <= 32) {
      hashState = List<int>.from(nameBytes)..addAll(List<int>.filled(32 - nameBytes.length, 0));
    } else {
      hashState = await sha256HashAsync(nameBytes);
    }
    chainingKey = List<int>.from(hashState);
  }

  Future<void> mixHash(List<int> data) async {
    final digest = BytesBuilder()
      ..add(hashState)
      ..add(data);
    hashState = await sha256HashAsync(digest.toBytes());
  }

  /// HKDF-based mixKey (asynchronous implementation)
  Future<void> mixKey(List<int> inputKeyMaterial) async {
    // HKDF Extract: tempKey = HMAC-SHA256(chainingKey, inputKeyMaterial)
    final tempKey = await hmacSha256Async(chainingKey, inputKeyMaterial);
    
    // HKDF Expand:
    // output1 = HMAC(tempKey, 0x01)
    // output2 = HMAC(tempKey, output1 + 0x02)
    final output1 = await hmacSha256Async(tempKey, [0x01]);
    final output2 = await hmacSha256Async(tempKey, [...output1, 0x02]);

    chainingKey = output1;
    cipherKey = output2;
  }

  Future<List<int>> encryptAndHash(List<int> plaintext) async {
    if (cipherKey == null) {
      await mixHash(plaintext);
      return plaintext;
    }
    
    // Encrypt with GCM (using hashState as Associated Data, and fixed nonce 0)
    final result = await encryptAesGcmSync(plaintext, cipherKey!, hashState);
    await mixHash(result);
    return result;
  }

  Future<List<int>> decryptAndHash(List<int> ciphertext) async {
    if (cipherKey == null) {
      await mixHash(ciphertext);
      return ciphertext;
    }

    final plaintext = await decryptAesGcmSync(ciphertext, cipherKey!, hashState);
    await mixHash(ciphertext);
    return plaintext;
  }

  /// Split symmetric state into dual cipher keys for encryption/decryption
  Future<NoiseSessionKeys> split() async {
    // tempKey = HMAC-SHA256(chainingKey, [])
    final tempKey = await hmacSha256Async(chainingKey, []);
    // c1 = HMAC(tempKey, 0x01)
    // c2 = HMAC(tempKey, c1 + 0x02)
    final c1 = await hmacSha256Async(tempKey, [0x01]);
    final c2 = await hmacSha256Async(tempKey, [...c1, 0x02]);

    // Initiator sends with c1, receives with c2. Responder does the opposite.
    return NoiseSessionKeys(
      encryptKey: role == NoiseRole.initiator ? c1 : c2,
      decryptKey: role == NoiseRole.initiator ? c2 : c1,
      remoteStaticPublicKey: remoteStaticPublicKey,
    );
  }

  // ── Sync Helper Cryptography Primitives ──────────────────────────────────

  Future<List<int>> sha256HashAsync(List<int> data) async {
    final hash = await Sha256().hash(data);
    return hash.bytes;
  }

  Future<List<int>> hmacSha256Async(List<int> key, List<int> data) async {
    final hmac = Hmac(Sha256());
    final mac = await hmac.calculateMac(data, secretKey: SecretKey(key));
    return mac.bytes;
  }

  Future<List<int>> encryptAesGcmSync(List<int> plaintext, List<int> key, List<int> ad) async {
    final aes = AesGcm.with256bits();
    // Use fixed nonce of 12 zeros for handshake messages as they are one-time per key
    final nonce = List<int>.filled(12, 0);
    final box = await aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: ad,
    );
    return [...box.cipherText, ...box.mac.bytes];
  }

  Future<List<int>> decryptAesGcmSync(List<int> ciphertext, List<int> key, List<int> ad) async {
    final aes = AesGcm.with256bits();
    final nonce = List<int>.filled(12, 0);
    
    final cipherTextOnly = ciphertext.sublist(0, ciphertext.length - 16);
    final macBytes = ciphertext.sublist(ciphertext.length - 16);
    
    final box = SecretBox(
      cipherTextOnly,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final decrypted = await aes.decrypt(box, secretKey: SecretKey(key), aad: ad);
    return decrypted;
  }
}

class NoiseSessionKeys {
  final List<int> encryptKey;
  final List<int> decryptKey;
  final List<int>? remoteStaticPublicKey;
  
  // Track message counter for nonce rotation in active chat session
  int encryptCounter = 0;
  int decryptCounter = 0;

  NoiseSessionKeys({
    required this.encryptKey,
    required this.decryptKey,
    this.remoteStaticPublicKey,
  });

  /// Encrypt payload using current counter as nonce
  Future<List<int>> encrypt(List<int> plaintext) async {
    final aes = AesGcm.with256bits();
    final nonce = _generateCounterNonce(encryptCounter++);
    final box = await aes.encrypt(
      plaintext,
      secretKey: SecretKey(encryptKey),
      nonce: nonce,
    );
    return [...box.cipherText, ...box.mac.bytes];
  }

  /// Decrypt payload using current counter as nonce
  Future<List<int>> decrypt(List<int> ciphertext) async {
    final aes = AesGcm.with256bits();
    final nonce = _generateCounterNonce(decryptCounter++);
    
    final cipherTextOnly = ciphertext.sublist(0, ciphertext.length - 16);
    final macBytes = ciphertext.sublist(ciphertext.length - 16);
    
    final box = SecretBox(
      cipherTextOnly,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final decrypted = await aes.decrypt(box, secretKey: SecretKey(decryptKey));
    return decrypted;
  }

  List<int> _generateCounterNonce(int counter) {
    // Generates a 12-byte counter-based nonce
    final nonce = ByteData(12);
    nonce.setUint64(4, counter, Endian.big);
    return nonce.buffer.asUint8List();
  }
}
