import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Low-level cryptographic operations built on the `cryptography` package.
///
/// Provides X25519 ECDH key agreement, AES-256-GCM authenticated encryption,
/// ED25519 digital signatures, and SHA-256 hashing. All byte inputs and outputs
/// use `List<int>` for interop with the `cryptography` package.
class CryptoService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  // ── Algorithm instances (reusable, stateless) ────────────────────────────
  final X25519 _x25519 = X25519();
  final Ed25519 _ed25519 = Ed25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();

  // ── Key generation ───────────────────────────────────────────────────────

  /// Generate an X25519 key pair for Diffie-Hellman key exchange.
  Future<SimpleKeyPair> generateX25519KeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    return await keyPair.extract();
  }

  /// Generate an ED25519 key pair for digital signatures.
  Future<SimpleKeyPair> generateEd25519KeyPair() async {
    final keyPair = await _ed25519.newKeyPair();
    return await keyPair.extract();
  }

  // ── ECDH shared secret ──────────────────────────────────────────────────

  /// Derive a shared secret via X25519(myPrivateKey, theirPublicKey).
  ///
  /// The returned bytes can be used directly as AES-256-GCM key material
  /// because X25519 produces exactly 32 bytes.
  Future<List<int>> deriveSharedSecret(
    List<int> myPrivateKeyBytes,
    List<int> theirPublicKeyBytes,
  ) async {
    final myPrivateKey = SimpleKeyPairData(
      myPrivateKeyBytes,
      publicKey: SimplePublicKey(theirPublicKeyBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    final theirPublicKey =
        SimplePublicKey(theirPublicKeyBytes, type: KeyPairType.x25519);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myPrivateKey,
      remotePublicKey: theirPublicKey,
    );
    return await sharedSecret.extractBytes();
  }

  // ── AES-256-GCM ─────────────────────────────────────────────────────────

  /// Encrypt [plaintext] with AES-256-GCM using the given [sharedSecret]
  /// (32 bytes). Returns a record with the ciphertext (including the
  /// appended GCM authentication tag) and the random 12-byte nonce.
  Future<({List<int> ciphertext, List<int> nonce})> encryptAesGcm(
    String plaintext,
    List<int> sharedSecret,
  ) async {
    final secretKey = SecretKey(sharedSecret);
    final plaintextBytes = utf8.encode(plaintext);

    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
    );

    // Combine ciphertext + MAC into a single blob for transport.
    final ciphertext = <int>[...secretBox.cipherText, ...secretBox.mac.bytes];
    final nonce = secretBox.nonce;

    return (ciphertext: ciphertext, nonce: nonce);
  }

  /// Decrypt AES-256-GCM [ciphertext] (ciphertext+MAC concatenated) using
  /// the provided [nonce] and [sharedSecret].
  Future<String> decryptAesGcm(
    List<int> ciphertext,
    List<int> nonce,
    List<int> sharedSecret,
  ) async {
    final secretKey = SecretKey(sharedSecret);

    // The last 16 bytes are the GCM authentication tag.
    const macLength = 16;
    final cipherTextOnly = ciphertext.sublist(0, ciphertext.length - macLength);
    final macBytes = ciphertext.sublist(ciphertext.length - macLength);

    final secretBox = SecretBox(
      cipherTextOnly,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(decrypted);
  }

  // ── ED25519 signing / verification ───────────────────────────────────────

  /// Sign [data] with an ED25519 private key.
  Future<List<int>> signEd25519(
    List<int> data,
    List<int> privateKeyBytes,
  ) async {
    // ED25519 private key seed is 32 bytes; the cryptography package will
    // derive the public key internally when we construct a KeyPairData.
    final keyPair = await _ed25519.newKeyPairFromSeed(privateKeyBytes);
    final signature = await _ed25519.sign(data, keyPair: keyPair);
    return signature.bytes;
  }

  /// Verify an ED25519 [signature] over [data] using the signer's
  /// [publicKeyBytes].
  Future<bool> verifyEd25519(
    List<int> data,
    List<int> signature,
    List<int> publicKeyBytes,
  ) async {
    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final sig = Signature(signature, publicKey: publicKey);
    return _ed25519.verify(data, signature: sig);
  }

  // ── Hashing ──────────────────────────────────────────────────────────────

  /// Compute SHA-256 of [data].
  Future<List<int>> sha256Hash(List<int> data) async {
    final hash = await _sha256.hash(data);
    return hash.bytes;
  }

  // ── Device ID derivation ─────────────────────────────────────────────────

  /// Derive a deterministic device ID from an X25519 public key:
  /// `"izii-d-"` + first 8 hex characters of `SHA-256(publicKeyBytes)`.
  Future<String> deriveDeviceId(List<int> publicKeyBytes) async {
    final hashBytes = await sha256Hash(publicKeyBytes);
    final hexString = hashBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'izii-d-${hexString.substring(0, 8)}';
  }

  // ── Utility helpers ──────────────────────────────────────────────────────

  /// Encode raw bytes to standard Base64.
  String bytesToBase64(List<int> bytes) => base64Encode(Uint8List.fromList(bytes));

  /// Decode standard Base64 to bytes.
  List<int> base64ToBytes(String encoded) => base64Decode(encoded);
}
