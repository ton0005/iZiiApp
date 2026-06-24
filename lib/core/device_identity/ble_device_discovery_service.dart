import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide CharacteristicProperties;
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:drift/drift.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _isBlePeripheralInitialized = false;
  Completer<bool>? _blePeripheralReadyCompleter;

  StreamSubscription? _scanSubscription;
  final Map<String, BluetoothDevice> _discoveredDevicesCache = {};
  final _nearbyPeersController =
      StreamController<List<LocalBlePeer>>.broadcast();

  Stream<List<LocalBlePeer>> get nearbyPeersStream =>
      _nearbyPeersController.stream;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;

  Future<void> _ensureInitialized() async {
    if (_isBlePeripheralInitialized) return;
    try {
      _blePeripheralReadyCompleter = Completer<bool>();
      
      BlePeripheral.setBleStateChangeCallback((poweredOn) {
        print('[BleDiscovery] BlePeripheral state change: poweredOn=$poweredOn');
        if (poweredOn && _blePeripheralReadyCompleter != null && !_blePeripheralReadyCompleter!.isCompleted) {
          _blePeripheralReadyCompleter!.complete(true);
        }
      });

      await BlePeripheral.initialize();
      _isBlePeripheralInitialized = true;
      print('[BleDiscovery] BlePeripheral initialized successfully.');

      if (Platform.isIOS || Platform.isMacOS) {
        print('[BleDiscovery] Waiting for BlePeripheral to be powered on...');
        await _blePeripheralReadyCompleter!.future.timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            print('[BleDiscovery] Timeout waiting for BlePeripheral state change.');
            return false;
          },
        );
      }
    } catch (e) {
      print('[BleDiscovery] Failed to initialize BlePeripheral: $e');
    }
  }

  Future<void> _setupGattServer() async {
    await _ensureInitialized();
    try {
      await BlePeripheral.clearServices();

      final bleService = BleService(
        uuid: serviceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: charUuid,
            properties: [
              CharacteristicProperties.write.index,
              CharacteristicProperties.writeWithoutResponse.index,
              CharacteristicProperties.notify.index,
            ],
            permissions: [
              AttributePermissions.writeable.index,
            ],
          ),
        ],
      );

      try {
        await BlePeripheral.addService(bleService);
      } catch (addError) {
        print('[BleDiscovery] First attempt to add service failed: $addError. Retrying in 1 second...');
        await Future.delayed(const Duration(seconds: 1));
        await BlePeripheral.addService(bleService);
      }
      
      BlePeripheral.setWriteRequestCallback(_handleWriteRequest);
      BlePeripheral.setAdvertisingStatusUpdateCallback((advertising, error) {
        _isAdvertising = advertising;
        print('[BleDiscovery] Advertising status update: advertising=$advertising, error=$error');
      });
      
      print('[BleDiscovery] GATT Server configured with service: $serviceUuid');
    } catch (e) {
      print('[BleDiscovery] Failed to setup GATT Server: $e');
      rethrow;
    }
  }

  WriteRequestResult? _handleWriteRequest(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    if (characteristicId.toLowerCase() != charUuid.toLowerCase() || value == null || value.isEmpty) {
      return WriteRequestResult(status: 0);
    }

    print('[BleDiscovery] GATT Write received from $deviceId, length: ${value.length}');
    _processIncomingHandshake(deviceId, value);

    return WriteRequestResult(status: 0);
  }

  Future<void> _processIncomingHandshake(String remoteDeviceId, Uint8List payload) async {
    try {
      print('[BleDiscovery] Processing incoming Noise handshake message (length: ${payload.length})...');
      
      final msg2 = await _handshakeService.processHandshakeMessage(remoteDeviceId, payload);
      
      if (msg2 != null) {
        print('[BleDiscovery] Message 1 processed. Sending Message 2 to $remoteDeviceId...');
        await BlePeripheral.updateCharacteristic(
          characteristicId: charUuid,
          value: Uint8List.fromList(msg2),
        );
      } else {
        final session = _handshakeService.getSessionKeys(remoteDeviceId);
        if (session != null && session.remoteStaticPublicKey != null) {
          print('[BleDiscovery] Noise Handshake established as Responder with $remoteDeviceId.');
          
          final dbDeviceId = 'izii-d-ble-${remoteDeviceId.replaceAll(':', '').replaceAll('-', '').toLowerCase()}';
          
          final companion = LocalBlePeersCompanion(
            deviceId: Value(dbDeviceId),
            deviceName: Value('iZii Peer ($remoteDeviceId)'),
            publicKey: Value(base64Encode(session.remoteStaticPublicKey!)),
            lastSeenAt: Value(DateTime.now()),
          );
          
          await _db.into(_db.localBlePeers).insertOnConflictUpdate(companion);
          print('[BleDiscovery] Saved peer static public key to database: $dbDeviceId');
        } else {
          print('[BleDiscovery] Noise Handshake processing completed, no session established yet.');
        }
      }
    } catch (e) {
      print('[BleDiscovery] Error processing handshake in GATT write: $e');
    }
  }

  /// Starts advertising this device's iZii BLE P2P Service.
  /// Works on Android/iOS (Peripheral role).
  Future<void> startAdvertising() async {
    if (_isAdvertising) return;

    try {
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ].request();

        final advGranted = statuses[Permission.bluetoothAdvertise]?.isGranted ?? false;
        final connGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;

        if (!advGranted || !connGranted) {
          print('[BleDiscovery] BLE advertising permissions not granted.');
          return;
        }
      }

      final identity = await _identityService.getOrCreateIdentity();

      await _setupGattServer();

      await BlePeripheral.startAdvertising(
        services: [serviceUuid],
        localName: identity.deviceName,
      );
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
      await BlePeripheral.stopAdvertising();
      _isAdvertising = false;
      print('[BleDiscovery] Stopped BLE Advertising.');
    } catch (e) {
      print('[BleDiscovery] Failed to stop BLE Advertising: $e');
    }
  }

  /// Starts scanning for nearby iZii P2P BLE devices.
  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
        final connGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
        final locGranted = statuses[Permission.location]?.isGranted ?? false;

        if (!scanGranted || !connGranted || !locGranted) {
          print('[BleDiscovery] BLE scanning permissions not granted.');
          return;
        }
      }

      // Check BLE permissions & support
      if (await FlutterBluePlus.isSupported == false) {
        print('[BleDiscovery] Bluetooth is not supported on this device.');
        return;
      }

      _isScanning = true;
      print('[BleDiscovery] Starting BLE Scan for service UUID: $serviceUuid');

      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: const Duration(seconds: 15),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          final hasService = r.advertisementData.serviceUuids.any((uuid) =>
              uuid.toString().toLowerCase() == serviceUuid.toLowerCase());
          final hasName = r.advertisementData.localName.startsWith('iZii') ||
              r.device.platformName.startsWith('iZii');
          // If scanning withServices filter, iOS/macOS might return device without populating serviceUuids
          // in advertisementData due to overflow, so we accept any match on iOS/macOS.
          if (hasService || hasName || Platform.isIOS || Platform.isMacOS) {
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
    final rawName = result.advertisementData.localName.isNotEmpty
        ? result.advertisementData.localName
        : result.device.platformName;
    final deviceName = rawName.isNotEmpty ? rawName : 'iZii Peer';

    // Generate a temporary DID or extract from advertisement if possible
    // For standard flow, we save peer and execute Noise XX Handshake upon connection.
    final String deviceId =
        'izii-d-ble-${result.device.remoteId.str.replaceAll(':', '').toLowerCase()}';

    _discoveredDevicesCache[deviceId] = result.device;

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

  String _getDeviceAddressFromId(String deviceId) {
    if (!deviceId.startsWith('izii-d-ble-')) return deviceId;
    final clean = deviceId.replaceFirst('izii-d-ble-', '');
    if (clean.length == 12) {
      final List<String> parts = [];
      for (int i = 0; i < 12; i += 2) {
        parts.add(clean.substring(i, i + 2).toUpperCase());
      }
      return parts.join(':');
    }
    return clean;
  }

  /// Connects to a remote peer and performs the Noise XX Handshake.
  Future<bool> connectAndAuthenticate(String deviceId) async {
    final cachedDevice = _discoveredDevicesCache[deviceId];
    final BluetoothDevice device;
    if (cachedDevice != null) {
      device = cachedDevice;
    } else {
      final realAddress = _getDeviceAddressFromId(deviceId);
      device = BluetoothDevice.fromId(realAddress);
    }

    final realAddress = device.remoteId.str;

    try {
      print('[BleDiscovery] Connecting to BLE device: $realAddress (ID: $deviceId)...');
      if (!device.isConnected) {
        await device.connect(timeout: const Duration(seconds: 10));
      }

      // Request MTU right after connection to prevent packet truncation on Android
      if (Platform.isAndroid) {
        try {
          print('[BleDiscovery] Requesting MTU 256 for Android...');
          await device.requestMtu(256);
        } catch (mtuErr) {
          print('[BleDiscovery] Failed to request MTU: $mtuErr');
        }
      }

      print('[BleDiscovery] Connected. Discovering services...');
      List<BluetoothService> services = await device.discoverServices();

      BluetoothCharacteristic? p2pChar;
      BluetoothCharacteristic? findChar(List<BluetoothService> serviceList) {
        for (var s in serviceList) {
          if (s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
            for (var c in s.characteristics) {
              if (c.uuid.toString().toLowerCase() == charUuid.toLowerCase()) {
                return c;
              }
            }
          }
        }
        return null;
      }

      p2pChar = findChar(services);

      if (p2pChar == null && Platform.isAndroid) {
        print('[BleDiscovery] iZii BLE P2P Characteristic not found. Clearing GATT cache and retrying...');
        try {
          await device.clearGattCache();
          services = await device.discoverServices();
          p2pChar = findChar(services);
        } catch (e) {
          print('[BleDiscovery] Failed to clear GATT cache or rediscover: $e');
        }
      }

      if (p2pChar == null) {
        throw Exception(
            'iZii BLE P2P Characteristic not found on target device.');
      }

      print('[BleDiscovery] Starting Noise Handshake...');
      final initiator =
          'ble-${realAddress.replaceAll(':', '').toLowerCase()}';

      // Step 1: Subscribe to notifications FIRST to avoid race conditions
      final Completer<List<int>> responseCompleter = Completer<List<int>>();
      final subscription = p2pChar.onValueReceived.listen((bytes) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.complete(bytes);
        }
      });

      // Enable notifications on characteristic
      await p2pChar.setNotifyValue(true);

      // Step 2: Write Message 1 (Initiator Ephemeral Public Key)
      final msg1 = await _handshakeService.initiateHandshake(initiator);
      await p2pChar.write(msg1);

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
          '[BleDiscovery] Noise Handshake established successfully with $realAddress.');

      // Handshake established. Retrieve peer keys and update registry
      final session = _handshakeService.getSessionKeys(initiator);
      if (session != null && session.remoteStaticPublicKey != null) {
        // Update LocalBlePeers table with actual static public key from handshake
        await (_db.update(_db.localBlePeers)
              ..where((t) => t.deviceId.equals(deviceId)))
            .write(LocalBlePeersCompanion(
          publicKey: Value(base64Encode(session.remoteStaticPublicKey!)),
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
