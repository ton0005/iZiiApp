import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'image_key_kdf_engine.dart';

/// Sealed packet structure exchanged over BLE for visual P2P mutual authentication.
class P2pHandshakePacket {
  final String senderDeviceId;
  final String nonce;
  final List<int> ephemeralX25519PublicKeyBytes;
  final List<int> ed25519PublicKeyBytes;
  final List<int>? signatureBytes;
  final int timestamp;

  const P2pHandshakePacket({
    required this.senderDeviceId,
    required this.nonce,
    required this.ephemeralX25519PublicKeyBytes,
    required this.ed25519PublicKeyBytes,
    this.signatureBytes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'senderDeviceId': senderDeviceId,
        'nonce': nonce,
        'ephemeralX25519PublicKeyBytes': ephemeralX25519PublicKeyBytes,
        'ed25519PublicKeyBytes': ed25519PublicKeyBytes,
        'signatureBytes': signatureBytes,
        'timestamp': timestamp,
      };

  factory P2pHandshakePacket.fromMap(Map<String, dynamic> map) {
    return P2pHandshakePacket(
      senderDeviceId: map['senderDeviceId'] as String,
      nonce: map['nonce'] as String,
      ephemeralX25519PublicKeyBytes: List<int>.from(map['ephemeralX25519PublicKeyBytes'] as List),
      ed25519PublicKeyBytes: List<int>.from(map['ed25519PublicKeyBytes'] as List),
      signatureBytes: map['signatureBytes'] != null
          ? List<int>.from(map['signatureBytes'] as List)
          : null,
      timestamp: map['timestamp'] as int,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory P2pHandshakePacket.fromJson(String source) =>
      P2pHandshakePacket.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// BleP2pHandshakeService (`BleP2pHandshakeService`)
///
/// Implements mutual 2-user visual verification over BLE P2P mesh network:
/// 1. Initiates ephemeral X25519 ECDH key exchange.
/// 2. Derives identical 4x4 visual identicon matrix on both devices for screen verification.
/// 3. Signs & verifies transaction payloads with Ed25519.
class BleP2pHandshakeService {
  final X25519 _x25519 = X25519();
  final Ed25519 _ed25519 = Ed25519();
  final ImageKeyKdfEngine _kdfEngine;

  BleP2pHandshakeService({ImageKeyKdfEngine? kdfEngine})
      : _kdfEngine = kdfEngine ?? ImageKeyKdfEngine();

  /// Generates a fresh ephemeral X25519 KeyPair for ECDH.
  Future<SimpleKeyPair> generateEphemeralX25519KeyPair() async {
    return _x25519.newKeyPair();
  }

  /// Computes the Diffie-Hellman Shared Secret Key from my X25519 keypair and remote X25519 public key.
  Future<SecretKey> computeSharedSecret({
    required SimpleKeyPair myX25519KeyPair,
    required SimplePublicKey remoteX25519PublicKey,
  }) async {
    return _x25519.sharedSecretKey(
      keyPair: myX25519KeyPair,
      remotePublicKey: remoteX25519PublicKey,
    );
  }

  /// Derives the mutual [VisualIdenticonMatrix] from the shared secret.
  /// Both user devices will render the exact same color matrix pattern and verification code.
  Future<VisualIdenticonMatrix> deriveMutualVisualToken(SecretKey sharedSecret) async {
    final secretBytes = await sharedSecret.extractBytes();
    return _kdfEngine.generateVisualIdenticonMatrix(secretBytes);
  }

  /// Signs a transaction/handshake payload using the user's Ed25519 keypair derived from their Visual Secret.
  Future<Signature> signTransactionPayload({
    required SimpleKeyPair myEd25519KeyPair,
    required Uint8List payload,
  }) async {
    return _ed25519.sign(
      payload,
      keyPair: myEd25519KeyPair,
    );
  }

  /// Verifies a remote peer's signature against their Ed25519 public key.
  Future<bool> verifyTransactionSignature({
    required SimplePublicKey peerEd25519Public,
    required Uint8List payload,
    required Signature signature,
  }) async {
    return _ed25519.verify(
      payload,
      signature: signature,
    );
  }

  /// Helper to convert raw bytes to [SimplePublicKey] for X25519.
  SimplePublicKey parseX25519PublicKey(List<int> bytes) {
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  /// Helper to convert raw bytes to [SimplePublicKey] for Ed25519.
  SimplePublicKey parseEd25519PublicKey(List<int> bytes) {
    return SimplePublicKey(bytes, type: KeyPairType.ed25519);
  }
}
