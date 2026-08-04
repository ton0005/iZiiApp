import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:izii_app/core/security/image_key_kdf_engine.dart';
import 'package:izii_app/core/security/ble_p2p_handshake_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  late ImageKeyKdfEngine kdfEngine;
  late BleP2pHandshakeService handshakeService;

  setUp(() {
    kdfEngine = ImageKeyKdfEngine();
    handshakeService = BleP2pHandshakeService(kdfEngine: kdfEngine);
  });

  group('ImageKeyKdfEngine Tests', () {
    test('deriveMasterSeedFromImage is deterministic for identical inputs', () async {
      final imageBytes = Uint8List.fromList(List.generate(100, (i) => i * 2));
      const salt = 'user_alice_salt_123';

      final seed1 = await kdfEngine.deriveMasterSeedFromImage(imageBytes, salt);
      final seed2 = await kdfEngine.deriveMasterSeedFromImage(imageBytes, salt);

      expect(seed1.length, 32);
      expect(seed1, equals(seed2));
    });

    test('different image bytes produce different master seeds', () async {
      final imageBytes1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final imageBytes2 = Uint8List.fromList([1, 2, 3, 4, 6]);
      const salt = 'same_salt';

      final seed1 = await kdfEngine.deriveMasterSeedFromImage(imageBytes1, salt);
      final seed2 = await kdfEngine.deriveMasterSeedFromImage(imageBytes2, salt);

      expect(seed1, isNot(equals(seed2)));
    });

    test('generateEd25519KeyPair & generateX25519KeyPair from seed', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i));

      final ed25519Key = await kdfEngine.generateEd25519KeyPair(seed);
      final x25519Key = await kdfEngine.generateX25519KeyPair(seed);

      expect(ed25519Key, isNotNull);
      expect(x25519Key, isNotNull);

      final edPublic = await ed25519Key.extractPublicKey();
      expect(edPublic.bytes.length, 32);
    });

    test('generateVisualIdenticonMatrix produces 4x4 matrix and 4-char code', () async {
      final sharedSecretBytes = List.generate(32, (i) => i + 10);
      final identicon = await kdfEngine.generateVisualIdenticonMatrix(sharedSecretBytes);

      expect(identicon.verificationCode.length, 4);
      expect(identicon.matrixColorsHex.length, 16);
      for (final color in identicon.matrixColorsHex) {
        expect(color.length, 4); // R, G, B, A
        expect(color[0], greaterThanOrEqualTo(0));
        expect(color[0], lessThanOrEqualTo(255));
      }
    });

    test('saveMasterSeed & loadMasterSeed with FlutterSecureStorage', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i + 5));
      const userId = 'user_test_456';

      await kdfEngine.saveMasterSeed(userId, seed);
      final loaded = await kdfEngine.loadMasterSeed(userId);

      expect(loaded, isNotNull);
      expect(loaded, equals(seed));
    });
  });

  group('BleP2pHandshakeService & iZii-VZKP Tests', () {
    test('Mutual X25519 Diffie-Hellman Key Exchange produces matching Shared Secrets & Visual Identicons', () async {
      // Alice KeyPair
      final aliceEphemeral = await handshakeService.generateEphemeralX25519KeyPair();
      final alicePublic = await aliceEphemeral.extractPublicKey();

      // Bob KeyPair
      final bobEphemeral = await handshakeService.generateEphemeralX25519KeyPair();
      final bobPublic = await bobEphemeral.extractPublicKey();

      // Alice computes Shared Secret with Bob's Public Key
      final aliceSharedSecret = await handshakeService.computeSharedSecret(
        myX25519KeyPair: aliceEphemeral,
        remoteX25519PublicKey: bobPublic,
      );

      // Bob computes Shared Secret with Alice's Public Key
      final bobSharedSecret = await handshakeService.computeSharedSecret(
        myX25519KeyPair: bobEphemeral,
        remoteX25519PublicKey: alicePublic,
      );

      final aliceSecretBytes = await aliceSharedSecret.extractBytes();
      final bobSecretBytes = await bobSharedSecret.extractBytes();

      // Verify Shared Secrets are identical
      expect(aliceSecretBytes, equals(bobSecretBytes));

      // Derive Mutual Visual Identicons
      final aliceVisualToken = await handshakeService.deriveMutualVisualToken(aliceSharedSecret);
      final bobVisualToken = await handshakeService.deriveMutualVisualToken(bobSharedSecret);

      // Verify Visual Identicon Code & Matrix Match 100%
      expect(aliceVisualToken.verificationCode, equals(bobVisualToken.verificationCode));
      expect(aliceVisualToken.matrixColorsHex, equals(bobVisualToken.matrixColorsHex));
    });

    test('Ed25519 Zero-Knowledge Transaction Signing & Verification', () async {
      final seed = Uint8List.fromList(List.generate(32, (i) => i + 100));
      final aliceSigningKey = await kdfEngine.generateEd25519KeyPair(seed);
      final alicePublic = await aliceSigningKey.extractPublicKey();

      final payload = utf8.encode('TRANSFER_100_MUSHROOM_POINTS_TO_BOB');

      // Alice signs payload
      final signature = await handshakeService.signTransactionPayload(
        myEd25519KeyPair: aliceSigningKey,
        payload: Uint8List.fromList(payload),
      );

      // Bob verifies signature using Alice's Public Key
      final isValid = await handshakeService.verifyTransactionSignature(
        peerEd25519Public: alicePublic,
        payload: Uint8List.fromList(payload),
        signature: signature,
      );

      expect(isValid, isTrue);

      // Verify tampered payload fails signature check
      final tamperedPayload = utf8.encode('TRANSFER_999_MUSHROOM_POINTS_TO_BOB');
      final isTamperedValid = await handshakeService.verifyTransactionSignature(
        peerEd25519Public: alicePublic,
        payload: Uint8List.fromList(tamperedPayload),
        signature: signature,
      );

      expect(isTamperedValid, isFalse);
    });
  });
}
