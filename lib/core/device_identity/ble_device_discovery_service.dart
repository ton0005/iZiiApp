import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'device_identity_service.dart';
import 'noise_handshake_service.dart';
import '../../modules/communication/models/ble_models.dart';
import '../../modules/communication/services/ble_transport_service.dart';

/// Service managing BLE Central (scanning/connecting) and Peripheral (advertising) roles.
/// Automates discovery, Noise protocol handshakes, and SQLite peer registry updates.
class BleDeviceDiscoveryService {
  static final BleDeviceDiscoveryService _instance =
      BleDeviceDiscoveryService._internal();
  factory BleDeviceDiscoveryService() => _instance;
  BleDeviceDiscoveryService._internal();

  final DeviceIdentityService _identityService = DeviceIdentityService();
  final NoiseHandshakeService _handshakeService = NoiseHandshakeService();
  final BleTransportService _transportService = BleTransportService();
  final AppDatabase _db = AppDatabase();

  static const String serviceUuid = 'f47b5e2d-4a9e-4c5a-9b3f-8e1d2c3a4b5c';
  static const String charUuid = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';

  bool _isScanning = false;
  bool _isAdvertising = false;

  StreamSubscription? _scanSubscription;
  final _nearbyPeersController =
      StreamController<List<LocalBlePeer>>.broadcast();

  Stream<List<LocalBlePeer>> get nearbyPeersStream =>
      _nearbyPeersController.stream;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;

  /// Starts advertising this device's iZii BLE P2P Service.
  /// Works on Android/iOS (Peripheral role).
  Future<void> startAdvertising() async {
    if (_isAdvertising) return;

    try {
      final identity = await _identityService.getOrCreateIdentity();

      final AdvertiseData advertiseData = AdvertiseData(
        serviceUuid: serviceUuid,
        localName: identity.deviceName,
        includeDeviceName: true,
      );

      await FlutterBlePeripheral().start(advertiseData: advertiseData);
      _isAdvertising = true;
      print(
          '[BleDiscovery] Started BLE Advertising. Service UUID: $serviceUuid');
    } catch (e) {
      print('[BleDiscovery] Failed to start BLE Advertising: $e');
    }
  }

  /// Stops BLE Advertising.
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    try {
      await FlutterBlePeripheral().stop();
      _isAdvertising = false;
      print('[BleDiscovery] Stopped BLE Advertising.');
    } catch (e) {
      print('[BleDiscovery] Failed to stop BLE Advertising: $e');
    }
  }

  /// Starts scanning for nearby iZii P2P BLE devices.
  Future<void> startScanning() async {
    if (_isScanning) return;

    // Check BLE permissions & support
    if (await FlutterBluePlus.isSupported == false) {
      print('[BleDiscovery] Bluetooth is not supported on this device.');
      return;
    }

    _isScanning = true;
    print('[BleDiscovery] Starting BLE Scan for service UUID: $serviceUuid');

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.advertisementData.serviceUuids.contains(Guid(serviceUuid)) ||
              r.advertisementData.localName.startsWith('iZii')) {
            await _handleDiscoveredDevice(r);
          }
        }

        // Query database and emit updated peers list
        final peers = await _db.select(_db.localBlePeers).get();
        _nearbyPeersController.add(peers);
      });
    } catch (e) {
      print('[BleDiscovery] Error starting scan: $e');
      _isScanning = false;
    }
  }

  /// Stops scanning.
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      print('[BleDiscovery] BLE Scan stopped.');
    } catch (e) {
      print('[BleDiscovery] Error stopping scan: $e');
    }
  }

  /// Process discovered device, saving/updating it in the SQLite LocalBlePeers table.
  Future<void> _handleDiscoveredDevice(ScanResult result) async {
    final deviceName = result.advertisementData.localName.isNotEmpty
        ? result.advertisementData.localName
        : result.device.platformName;

    // Generate a temporary DID or extract from advertisement if possible
    // For standard flow, we save peer and execute Noise XX Handshake upon connection.
    final String deviceId =
        'izii-d-ble-${result.device.remoteId.str.replaceAll(':', '').toLowerCase()}';

    final companion = LocalBlePeersCompanion.insert(
      deviceId: deviceId,
      deviceName: deviceName,
      publicKey: '', // Will be updated after Noise handshake
      signingPublicKey: '', // Will be updated after Noise handshake
      rssi: result.rssi,
      lastSeenAt: Value(DateTime.now()),
    );

    // Upsert into local_ble_peers
    await _db.into(_db.localBlePeers).insertOnConflictUpdate(companion);
    print(
        '[BleDiscovery] Discovered peer: $deviceName ($deviceId) RSSI: ${result.rssi}');
  }

  /// Connects to a remote peer and performs the Noise XX Handshake.
  Future<bool> connectAndAuthenticate(String deviceAddress) async {
    final device = BluetoothDevice.fromId(deviceAddress);

    try {
      print('[BleDiscovery] Connecting to BLE device: $deviceAddress...');
      await device.connect(timeout: const Duration(seconds: 10));

      print('[BleDiscovery] Connected. Discovering services...');
      final List<BluetoothService> services = await device.discoverServices();

      BluetoothCharacteristic? p2pChar;
      for (var s in services) {
        if (s.uuid == Guid(serviceUuid)) {
          for (var c in s.characteristics) {
            if (c.uuid == Guid(charUuid)) {
              p2pChar = c;
              break;
            }
          }
        }
      }

      if (p2pChar == null) {
        throw Exception(
            'iZii BLE P2P Characteristic not found on target device.');
      }

      print('[BleDiscovery] Starting Noise Handshake...');
      final initiator =
          'ble-${deviceAddress.replaceAll(':', '').toLowerCase()}';

      // Step 1: Write Message 1 (Initiator Ephemeral Public Key)
      final msg1 = await _handshakeService.initiateHandshake(initiator);
      await p2pChar.write(msg1);

      // Step 2: Subscribe and wait for Message 2 response
      await p2pChar.setNotifyValue(true);

      final Completer<List<int>> responseCompleter = Completer<List<int>>();
      final subscription = p2pChar.onValueReceived.listen((bytes) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.complete(bytes);
        }
      });

      // Wait for Message 2
      final msg2 =
          await responseCompleter.future.timeout(const Duration(seconds: 10));
      subscription.cancel();

      // Step 3: Process Message 2 and write Message 3
      final msg3 =
          await _handshakeService.processHandshakeMessage(initiator, msg2);
      if (msg3 == null) {
        throw Exception('Noise Handshake failed at Message 2 processing.');
      }

      await p2pChar.write(msg3);
      print(
          '[BleDiscovery] Noise Handshake established successfully with $deviceAddress.');

      // Handshake established. Retrieve peer keys and update registry
      final state = _handshakeService.getSessionKeys(initiator);
      if (state != null) {
        // Query target device identity details if handshake exposed them
        // Update LocalBlePeers table with actual Public Key from handshake
        final String peerDeviceId =
            'izii-d-ble-${deviceAddress.replaceAll(':', '').toLowerCase()}';
        await (_db.update(_db.localBlePeers)
              ..where((t) => t.deviceId.equals(peerDeviceId)))
            .write(LocalBlePeersCompanion(
          publicKey: Value(base64Encode(
              msg2.sublist(32, 64))), // Extracted static X25519 public key
        ));
      }

      return true;
    } catch (e) {
      print('[BleDiscovery] Connection or authentication failed: $e');
      await device.disconnect();
      return false;
    }
  }

  void dispose() {
    stopScanning();
    stopAdvertising();
    _nearbyPeersController.close();
  }
}
