import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents a 4x4 RGBA visual color matrix generated from a shared secret.
class VisualIdenticonMatrix {
  final List<List<int>> matrixColorsHex; // 16 RGBA color ints (4x4)
  final String verificationCode;         // 4-character visual hex code (e.g., "7F2A")

  const VisualIdenticonMatrix({
    required this.matrixColorsHex,
    required this.verificationCode,
  });

  Map<String, dynamic> toMap() => {
        'matrixColorsHex': matrixColorsHex,
        'verificationCode': verificationCode,
      };
}

/// Image-Key KDF Engine (`ImageKeyKdfEngine`)
///
/// Implements the cryptographic foundation of the **iZii Visual Zero-Knowledge Protocol (iZii-VZKP)**:
/// 1. Extracts high-entropy seeds from raw user secret images using HKDF-SHA256 / Argon2id.
/// 2. Generates Ed25519 key pairs (for transaction signing) and X25519 key pairs (for ECDH key exchange).
/// 3. Computes 4x4 RGBA visual identicon matrices for mutual 2-user visual verification.
/// 4. Stores encrypted seeds in device hardware enclave via [FlutterSecureStorage].
class ImageKeyKdfEngine {
  final FlutterSecureStorage _secureStorage;
  final Hkdf _hkdf = Hkdf(
    hmac: Hmac(Sha256()),
    outputLength: 32,
  );
  final Ed25519 _ed25519 = Ed25519();
  final X25519 _x25519 = X25519();

  ImageKeyKdfEngine({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _kSeedStoragePrefix = 'izii_visual_seed_';

  /// Derives a deterministic 32-byte Master Seed from raw image bytes and a salt.
  Future<Uint8List> deriveMasterSeedFromImage(
    Uint8List imageBytes,
    String salt,
  ) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }

    final saltBytes = utf8.encode('iZiiApp_Visual_Salt_$salt');
    final derivedSecret = await _hkdf.deriveKey(
      secretKey: SecretKey(imageBytes),
      nonce: saltBytes,
    );

    final bytes = await derivedSecret.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Derives a memory-hard Master Seed using Argon2id for high-security environments.
  Future<Uint8List> deriveMasterSeedArgon2id(
    Uint8List imageBytes,
    String salt,
  ) async {
    final argon2id = Argon2id(
      parallelism: 1,
      memory: 65536, // 64MB RAM
      iterations: 3,
      hashLength: 32,
    );

    final saltBytes = utf8.encode('iZiiApp_Argon2_Salt_$salt');
    final derivedKey = await argon2id.deriveKeyFromPassword(
      password: String.fromCharCodes(imageBytes),
      nonce: saltBytes,
    );

    final bytes = await derivedKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Generates an Ed25519 signing KeyPair deterministically from a 32-byte master seed.
  Future<SimpleKeyPair> generateEd25519KeyPair(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be exactly 32 bytes');
    }
    return _ed25519.newKeyPairFromSeed(seed);
  }

  /// Generates an X25519 key exchange KeyPair deterministically from a 32-byte master seed.
  Future<SimpleKeyPair> generateX25519KeyPair(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be exactly 32 bytes');
    }
    return _x25519.newKeyPairFromSeed(seed);
  }

  /// Computes a 4x4 RGBA visual color matrix + 4-char hex verification code from a shared secret.
  /// Used for mutual 2-user visual verification on screen.
  Future<VisualIdenticonMatrix> generateVisualIdenticonMatrix(List<int> sharedSecretBytes) async {
    if (sharedSecretBytes.isEmpty) {
      throw ArgumentError('Shared secret bytes cannot be empty');
    }

    final hashObj = await Sha256().hash(sharedSecretBytes);
    final hash = hashObj.bytes;

    // 4-character visual hex code (e.g. "7F2A")
    final verificationCode = hash
        .sublist(0, 2)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();

    // Generate 4x4 RGBA color matrix (16 colors)
    final matrixColors = <List<int>>[];
    for (int i = 0; i < 16; i++) {
      final r = (hash[i % hash.length] * (i + 1)) % 256;
      final g = (hash[(i + 5) % hash.length] * (i + 2)) % 256;
      final b = (hash[(i + 11) % hash.length] * (i + 3)) % 256;
      const a = 255; // Fully opaque
      matrixColors.add([r, g, b, a]);
    }

    return VisualIdenticonMatrix(
      matrixColorsHex: matrixColors,
      verificationCode: verificationCode,
    );
  }

  /// Clears corrupted secure storage keys and resets the Master Vault Key.
  Future<void> resetSecureVault() async {
    try {
      await _secureStorage.deleteAll();
      print('✅ Secure storage vault reset successfully.');
    } catch (e) {
      print('⚠️ Error resetting secure storage vault: $e');
    }
  }

  /// Securely persists the master seed in encrypted device storage.
  Future<void> saveMasterSeed(String userId, Uint8List seed) async {
    final hexString = seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    try {
      await _secureStorage.write(
        key: '$_kSeedStoragePrefix$userId',
        value: hexString,
      );
    } catch (e) {
      print('[ImageKeyKdfEngine] SecureStorage write failed ($e). Auto-clearing corrupted vault...');
      try {
        await _secureStorage.deleteAll();
        await _secureStorage.write(
          key: '$_kSeedStoragePrefix$userId',
          value: hexString,
        );
      } catch (_) {}
    }
  }

  /// Loads the master seed from encrypted device storage if available.
  Future<Uint8List?> loadMasterSeed(String userId) async {
    try {
      final hexString = await _secureStorage.read(key: '$_kSeedStoragePrefix$userId');
      if (hexString == null || hexString.isEmpty) return null;

      final bytes = <int>[];
      for (int i = 0; i < hexString.length; i += 2) {
        bytes.add(int.parse(hexString.substring(i, i + 2), radix: 16));
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('[ImageKeyKdfEngine] SecureStorage read failed ($e). Auto-clearing corrupted vault key...');
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  /// Deletes the stored master seed for a user.
  Future<void> clearMasterSeed(String userId) async {
    await _secureStorage.delete(key: '$_kSeedStoragePrefix$userId');
  }
}
