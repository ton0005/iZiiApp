import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide CharacteristicProperties;
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:drift/drift.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import 'device_identity_service.dart';
import 'noise_handshake_service.dart';
import '../settings/settings_service.dart';
import '../navigation/app_router.dart';
import '../sync/sync_service.dart';
import '../../modules/communication/models/ble_models.dart';
import '../../modules/communication/services/ble_transport_service.dart';
import '../sync/ble_sync_manager.dart';

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

  bool _isAdvertising = false;
  bool _isBlePeripheralInitialized = false;

  StreamSubscription? _scanSubscription;
  final Map<String, BluetoothDevice> _discoveredDevicesCache = {};

  Stream<List<LocalBlePeer>> get nearbyPeersStream =>
      _db.select(_db.localBlePeers).watch();
  bool get isScanning => FlutterBluePlus.isScanningNow;
  bool get isAdvertising => _isAdvertising;

  final Map<String, BluetoothCharacteristic> _activeClientCharacteristics = {};
  final Map<String, StreamSubscription> _activeClientSubscriptions = {};
  final Map<String, String> _deviceToUserMap = {}; // remoteDeviceId -> remoteUserId
  final Set<String> _connectingDevices = {}; // deviceId currently connecting

  final _messageReceivedController = StreamController<BleMeshPacket>.broadcast();
  Stream<BleMeshPacket> get messageReceivedStream => _messageReceivedController.stream;

  final _shareCompletedController = StreamController<String>.broadcast();
  Stream<String> get shareCompletedStream => _shareCompletedController.stream;

  String? getConnectedDeviceIdForUser(String userId) {
    for (final entry in _deviceToUserMap.entries) {
      if (entry.value == userId) return entry.key;
    }
    return null;
  }

  Future<void> _ensureInitialized() async {
    if (_isBlePeripheralInitialized) return;
    try {
      await BlePeripheral.initialize();
      _isBlePeripheralInitialized = true;
      print('[BleDiscovery] BlePeripheral initialized successfully.');

      // Wait for Bluetooth to be powered on using FlutterBluePlus.adapterState (extremely reliable on both iOS & Android)
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        print('[BleDiscovery] Waiting for Bluetooth adapter to be powered on...');
        await FlutterBluePlus.adapterState
            .where((state) => state == BluetoothAdapterState.on)
            .first
            .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[BleDiscovery] Timeout waiting for Bluetooth adapter state.');
            return BluetoothAdapterState.unknown;
          },
        );
      }

      // Give the system a brief 500ms delay to warm up the peripheral manager after power on
      await Future.delayed(const Duration(milliseconds: 500));
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
      BlePeripheral.setConnectionStateChangeCallback((deviceId, connected) {
        if (!connected) {
          // A client disconnected from our GATT server
          final cleanId = 'izii-d-ble-${deviceId.replaceAll(':', '').replaceAll('-', '').toLowerCase()}';
          _activeClientCharacteristics.remove(deviceId);
          _activeClientSubscriptions[deviceId]?.cancel();
          _activeClientSubscriptions.remove(deviceId);
          _deviceToUserMap.remove(deviceId);
          _handshakeService.clearSession(deviceId);
          _handshakeService.clearSession(cleanId);
          final macAddress = _getDeviceAddressFromId(deviceId);
          final macId = 'ble-${macAddress.replaceAll(':', '').toLowerCase()}';
          _handshakeService.clearSession(macId);
          print('[BleDiscovery] GATT Server client disconnected: $deviceId. Cleaned up cache.');
        }
      });
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
    
    if (_handshakeService.isSessionEstablished(deviceId)) {
      _handleIncomingData(deviceId, value);
    } else {
      _processIncomingHandshake(deviceId, value);
    }

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
          
          await _upsertPeer(
            deviceId: dbDeviceId,
            deviceName: 'iZii Peer ($remoteDeviceId)',
            publicKey: base64Encode(session.remoteStaticPublicKey!),
          );
          print('[BleDiscovery] Saved peer static public key to database: $dbDeviceId');

          // Immediately send announce packet as Responder
          await sendAnnounce(remoteDeviceId);
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

      // On Android, BLE advertising packet limit is 31 bytes.
      // 128-bit service UUID (16 bytes) + Flags/overhead (5 bytes) leaves only 10 bytes for name.
      // Advertising a long custom localName will cause ADVERTISE_FAILED_DATA_TOO_LARGE and advertising fails.
      // Passing localName as null on Android prevents this.
      final localName = Platform.isAndroid ? null : identity.deviceName;

      await BlePeripheral.startAdvertising(
        services: [serviceUuid],
        localName: localName,
      );
      _isAdvertising = true;
      print(
          '[BleDiscovery] Started BLE Advertising. Service UUID: $serviceUuid, localName: $localName');
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
    if (FlutterBluePlus.isScanningNow) return;

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

      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          final hasService = r.advertisementData.serviceUuids.any((uuid) =>
              uuid.toString().toLowerCase() == serviceUuid.toLowerCase());
          final hasName = r.advertisementData.localName.startsWith('iZii') ||
              r.device.platformName.startsWith('iZii');
          if (hasService || hasName) {
            await _handleDiscoveredDevice(r);
          }
        }
      });

      print('[BleDiscovery] Starting BLE Scan for service UUID: $serviceUuid');

      // Do NOT use withServices filter: Android ble_peripheral may place
      // the 128-bit custom service UUID in the scan response rather than the
      // main advertisement packet. iOS CoreBluetooth withServices filter only
      // matches the main packet, so Android devices become invisible.
      // Instead, we filter results manually below.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      print('[BleDiscovery] Error starting scan: $e');
    }
  }

  /// Stops scanning.
  Future<void> stopScanning() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      await _scanSubscription?.cancel();
      _scanSubscription = null;
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

    await _upsertPeer(
      deviceId: deviceId,
      deviceName: deviceName,
      rssi: result.rssi,
    );
    print(
        '[BleDiscovery] Discovered peer: $deviceName ($deviceId) RSSI: ${result.rssi}');

    // Auto-reconnect to known authenticated peers if disconnected
    try {
      final existing = await (_db.select(_db.localBlePeers)
            ..where((t) => t.deviceId.equals(deviceId)))
          .getSingleOrNull();
      if (existing != null && existing.publicKey.isNotEmpty) {
        if (!_activeClientCharacteristics.containsKey(deviceId) && 
            !_connectingDevices.contains(deviceId) && 
            !result.device.isConnected) {
          print('[BleDiscovery] Discovered known authenticated peer $deviceId. Auto-connecting...');
          // Run in background without blocking scan thread
          connectAndAuthenticate(deviceId).then((success) {
            if (success) {
              print('[BleDiscovery] Auto-connected and authenticated known peer: $deviceId');
            }
          });
        }
      }
    } catch (e) {
      print('[BleDiscovery] Error during auto-reconnect check: $e');
    }
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
    if (clean.length == 32) {
      final p1 = clean.substring(0, 8);
      final p2 = clean.substring(8, 12);
      final p3 = clean.substring(12, 16);
      final p4 = clean.substring(16, 20);
      final p5 = clean.substring(20, 32);
      return '$p1-$p2-$p3-$p4-$p5'.toLowerCase();
    }
    return clean;
  }

  String _getPeripheralDeviceId(String remoteDeviceId) {
    final raw = _getDeviceAddressFromId(remoteDeviceId);
    if (raw.contains('-') && raw.length == 36) {
      return raw.toUpperCase();
    }
    return raw;
  }

  /// Performs a brief re-scan to refresh CoreBluetooth's peripheral reference
  /// on iOS. Returns the refreshed BluetoothDevice if found, null otherwise.
  Future<BluetoothDevice?> _reScanForDevice(String deviceId) async {
    print('[BleDiscovery] Re-scanning to refresh peripheral reference for $deviceId...');
    final Completer<BluetoothDevice?> completer = Completer<BluetoothDevice?>();

    StreamSubscription? sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final scannedId = 'izii-d-ble-${r.device.remoteId.str.replaceAll(':', '').toLowerCase()}';
        if (scannedId == deviceId) {
          _discoveredDevicesCache[deviceId] = r.device;
          if (!completer.isCompleted) {
            completer.complete(r.device);
          }
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (_) {}

    // Wait for device found or timeout
    final device = await completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => null,
    );

    await sub.cancel();
    return device;
  }

  /// Connects to a remote peer and performs the Noise XX Handshake.
  Future<bool> connectAndAuthenticate(String deviceId) async {
    if (_connectingDevices.contains(deviceId)) {
      print('[BleDiscovery] Connection to $deviceId already in progress. Skipping.');
      return false;
    }
    _connectingDevices.add(deviceId);

    // 1. Stop scanning first before attempting connection (Apple best practice to prevent connection timeouts/failures)
    await stopScanning();

    BluetoothDevice? device = _discoveredDevicesCache[deviceId];
    if (device == null) {
      final realAddress = _getDeviceAddressFromId(deviceId);
      device = BluetoothDevice.fromId(realAddress);
    }

    final realAddress = device.remoteId.str;

    try {
      print('[BleDiscovery] Connecting to BLE device: $realAddress (ID: $deviceId)...');
      if (!device.isConnected) {
        try {
          await device.connect(timeout: const Duration(seconds: 10));
        } on PlatformException catch (e) {
          // On iOS, CoreBluetooth may have released the CBPeripheral reference
          // after the scan timed out. Re-scan briefly to refresh it.
          if (e.code == 'connect' && (Platform.isIOS || Platform.isMacOS)) {
            print('[BleDiscovery] Peripheral reference lost. Re-scanning...');
            final refreshedDevice = await _reScanForDevice(deviceId);
            if (refreshedDevice != null) {
              device = refreshedDevice;
              // Stop the scan we just started in _reScanForDevice before connecting
              await stopScanning();
              await device.connect(timeout: const Duration(seconds: 10));
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
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
        final initiatorId = 'ble-${realAddress.replaceAll(':', '').toLowerCase()}';
        if (!_handshakeService.isSessionEstablished(initiatorId)) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(bytes);
          }
        } else {
          _handleIncomingData(deviceId, bytes);
        }
      });
      _activeClientSubscriptions[deviceId] = subscription;

      // Enable notifications on characteristic
      await p2pChar.setNotifyValue(true);

      // Step 2: Write Message 1 (Initiator Ephemeral Public Key)
      final msg1 = await _handshakeService.initiateHandshake(initiator);
      await p2pChar.write(msg1);

      // Wait for Message 2
      final msg2 =
          await responseCompleter.future.timeout(const Duration(seconds: 10));

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

      // Save active client characteristic
      _activeClientCharacteristics[deviceId] = p2pChar;

      // Monitor connection state to clean up on disconnect
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _activeClientCharacteristics.remove(deviceId);
          _activeClientSubscriptions[deviceId]?.cancel();
          _activeClientSubscriptions.remove(deviceId);
          _deviceToUserMap.remove(deviceId);
          print('[BleDiscovery] Client device disconnected: $deviceId. Cleaned up cache.');
        }
      });

      // Immediately send announce packet as Initiator
      await sendAnnounce(deviceId);

      // Resume scanning in background (Apple best practice)
      startScanning();
      return true;
    } catch (e) {
      print('[BleDiscovery] Connection or authentication failed: $e');
      _activeClientSubscriptions[deviceId]?.cancel();
      _activeClientSubscriptions.remove(deviceId);
      await device?.disconnect();
      // Resume scanning in background
      startScanning();
      return false;
    } finally {
      _connectingDevices.remove(deviceId);
    }
  }

  NoiseSessionKeys? _getSessionKeysForDevice(String deviceId) {
    if (_handshakeService.isSessionEstablished(deviceId)) {
      return _handshakeService.getSessionKeys(deviceId);
    }
    final macAddress = _getDeviceAddressFromId(deviceId);
    final macId = 'ble-${macAddress.replaceAll(':', '').toLowerCase()}';
    if (_handshakeService.isSessionEstablished(macId)) {
      return _handshakeService.getSessionKeys(macId);
    }
    return null;
  }

  Future<void> sendAnnounce(String remoteDeviceId) async {
    try {
      final identity = await _identityService.getOrCreateIdentity();
      final activeUserId = await SettingsService().getActiveUserId();
      
      final announceData = {
        'user_id': activeUserId,
        'user_name': identity.deviceName,
        'device_id': identity.deviceId,
      };
      
      final payloadBytes = utf8.encode(jsonEncode(announceData));
      
      final packet = BleMeshPacket(
        messageId: 'announce-${DateTime.now().millisecondsSinceEpoch}',
        senderDeviceId: identity.deviceId,
        recipientDeviceId: remoteDeviceId,
        payload: payloadBytes,
        ttl: 1,
        messageType: BleMessageType.announce,
      );
      
      print('[BleDiscovery] Sending announce packet to $remoteDeviceId...');
      await sendPacket(remoteDeviceId, packet);
    } catch (e) {
      print('[BleDiscovery] Failed to send announce packet: $e');
    }
  }

  /// Sends a BleMeshPacket to a specific connected peer.
  /// Handles encryption, GZIP compression, packet serialization, and fragmentation automatically.
  Future<bool> sendPacket(String remoteDeviceId, BleMeshPacket packet) async {
    final session = _getSessionKeysForDevice(remoteDeviceId);
    if (session == null) {
      print('[BleDiscovery] No active authenticated session for $remoteDeviceId. Cannot send.');
      return false;
    }

    try {
      // Encrypt the payload using session key
      final encryptedPayload = await session.encrypt(packet.payload);
      
      final encryptedPacket = BleMeshPacket(
        messageId: packet.messageId,
        senderDeviceId: packet.senderDeviceId,
        recipientDeviceId: packet.recipientDeviceId,
        payload: encryptedPayload,
        ttl: packet.ttl,
        messageType: packet.messageType,
        signatureBase64: packet.signatureBase64,
      );

      final serialized = encryptedPacket.toJson();
      final packetBytes = utf8.encode(serialized);

      final clientChar = _activeClientCharacteristics[remoteDeviceId];
      
      final sendBytesCallback = (List<int> bytes) async {
        if (clientChar != null) {
          // Client (Initiator) role: Write directly to the discovered characteristic
          await clientChar.write(Uint8List.fromList(bytes), withoutResponse: true);
        } else {
          // Server (Responder) role: Update the local characteristic and notify
          await BlePeripheral.updateCharacteristic(
            characteristicId: charUuid,
            value: Uint8List.fromList(bytes),
          );
        }
      };

      final fragments = _transportService.fragmentPayload(packetBytes, packet.messageType);
      if (fragments.isEmpty) {
        await sendBytesCallback(packetBytes);
      } else {
        for (var i = 0; i < fragments.length; i++) {
          if (i > 0) {
            await Future.delayed(const Duration(milliseconds: 15)); // Short delay to prevent buffer overflow
          }
          await sendBytesCallback(fragments[i].toBytes());
        }
      }
      return true;
    } catch (e) {
      print('[BleDiscovery] Error sending BLE packet to $remoteDeviceId: $e');
      return false;
    }
  }

  Future<void> _handleIncomingData(String remoteDeviceId, List<int> bytes) async {
    BleMeshPacket? packet;
    
    try {
      // 1. Try parsing as complete JSON packet first (unfragmented)
      final jsonStr = utf8.decode(bytes);
      if (jsonStr.startsWith('{') && jsonStr.endsWith('}')) {
        packet = BleMeshPacket.fromJson(jsonStr);
      }
    } catch (_) {}

    if (packet == null) {
      // 2. Try parsing as fragment
      try {
        final fragment = BleFragment.fromBytes(bytes);
        final reassembled = _transportService.addFragment(fragment);
        if (reassembled != null) {
          final jsonStr = utf8.decode(reassembled.payload);
          packet = BleMeshPacket.fromJson(jsonStr);
        }
      } catch (e) {
        print('[BleDiscovery] Error parsing fragment: $e');
      }
    }

    if (packet == null) return;

    // 3. Decrypt payload
    final session = _getSessionKeysForDevice(remoteDeviceId);
    if (session == null) {
      print('[BleDiscovery] Received packet but no active session for $remoteDeviceId. Dropping.');
      return;
    }

    try {
      final decryptedPayload = await session.decrypt(packet.payload);
      
      final decryptedPacket = BleMeshPacket(
        messageId: packet.messageId,
        senderDeviceId: packet.senderDeviceId,
        recipientDeviceId: packet.recipientDeviceId,
        payload: decryptedPayload,
        ttl: packet.ttl,
        messageType: packet.messageType,
        signatureBase64: packet.signatureBase64,
      );

      // 4. Route packet by type
      await _routeIncomingPacket(remoteDeviceId, decryptedPacket);
    } catch (e) {
      print('[BleDiscovery] Error decrypting or routing BLE packet: $e');
    }
  }

  Future<void> _routeIncomingPacket(String remoteDeviceId, BleMeshPacket packet) async {
    print('[BleDiscovery] Routing incoming packet: type=${packet.messageType.name} from $remoteDeviceId');
    
    switch (packet.messageType) {
      case BleMessageType.announce:
        try {
          final jsonStr = utf8.decode(packet.payload);
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final remoteUserId = data['user_id'] as String;
          final remoteDeviceName = data['user_name'] as String;
          
          _deviceToUserMap[remoteDeviceId] = remoteUserId;
          print('[BleDiscovery] Registered BLE user mapping: $remoteDeviceId -> $remoteUserId ($remoteDeviceName)');
          
          // Save peer to local database if not already
          final dbDeviceId = 'izii-d-ble-${remoteDeviceId.replaceAll(':', '').replaceAll('-', '').toLowerCase()}';
          final session = _getSessionKeysForDevice(remoteDeviceId);
          if (session != null && session.remoteStaticPublicKey != null) {
            await _upsertPeer(
              deviceId: dbDeviceId,
              deviceName: remoteDeviceName,
              publicKey: base64Encode(session.remoteStaticPublicKey!),
            );
          }

          // Trigger outbox sync automatically!
          importSyncManagerAndSync(remoteDeviceId, remoteUserId);
        } catch (e) {
          print('[BleDiscovery] Error processing announce packet: $e');
        }
        break;
        
      case BleMessageType.syncRequest:
      case BleMessageType.syncResponse:
        try {
          final syncManager = BleSyncManager();
          await syncManager.handleIncomingSyncPacket(packet);
        } catch (e) {
          print('[BleDiscovery] Error handling sync packet: $e');
        }
        break;
        
      case BleMessageType.message:
        if (!_messageReceivedController.isClosed) {
          _messageReceivedController.add(packet);
        }
        break;

      case BleMessageType.shareRequest:
        try {
          await _handleIncomingShareRequest(packet);
        } catch (e) {
          print('[BleDiscovery] Error routing shareRequest: $e');
        }
        break;
        
      case BleMessageType.shareResponse:
        try {
          await _handleIncomingShareResponse(packet);
        } catch (e) {
          print('[BleDiscovery] Error routing shareResponse: $e');
        }
        break;
        
      default:
        print('[BleDiscovery] Unhandled packet type: ${packet.messageType}');
    }
  }

  Future<void> importSyncManagerAndSync(String remoteDeviceId, String remoteUserId) async {
    try {
      final syncManager = BleSyncManager();
      await syncManager.syncOutboxWithPeer(
        remoteDeviceId: remoteDeviceId,
        remoteUserId: remoteUserId,
        sendBleBytes: (_) {},
      );
    } catch (e) {
      print('[BleDiscovery] Error running sync: $e');
    }
  }

  Future<void> _upsertPeer({
    required String deviceId,
    required String deviceName,
    String? publicKey,
    String? signingPublicKey,
    int? rssi,
  }) async {
    try {
      final existing = await (_db.select(_db.localBlePeers)
            ..where((t) => t.deviceId.equals(deviceId)))
          .getSingleOrNull();

      if (existing == null) {
        final companion = LocalBlePeersCompanion.insert(
          deviceId: deviceId,
          deviceName: deviceName,
          publicKey: publicKey ?? '',
          signingPublicKey: signingPublicKey ?? '',
          rssi: rssi ?? -100,
          lastSeenAt: Value(DateTime.now()),
        );
        await _db.into(_db.localBlePeers).insert(companion);
      } else {
        await (_db.update(_db.localBlePeers)
              ..where((t) => t.deviceId.equals(deviceId)))
            .write(LocalBlePeersCompanion(
              deviceName: Value(deviceName),
              lastSeenAt: Value(DateTime.now()),
              publicKey: publicKey != null ? Value(publicKey) : const Value.absent(),
              signingPublicKey: signingPublicKey != null ? Value(signingPublicKey) : const Value.absent(),
              rssi: rssi != null ? Value(rssi) : const Value.absent(),
            ));
      }
    } catch (e) {
      print('[BleDiscovery] Error upserting peer $deviceId: $e');
    }
  }

  List<String> getConnectedDeviceIds() {
    return _deviceToUserMap.keys.toList();
  }

  String? getUserIdForDevice(String deviceId) {
    return _deviceToUserMap[deviceId];
  }

  bool isUserConnectedBle(String userId) {
    return _deviceToUserMap.containsValue(userId);
  }

  Future<List<Map<String, String>>> getConnectedPeersList() async {
    final list = <Map<String, String>>[];
    for (final deviceId in _deviceToUserMap.keys) {
      final dbDeviceId = 'izii-d-ble-${deviceId.replaceAll(':', '').replaceAll('-', '').toLowerCase()}';
      final peer = await (_db.select(_db.localBlePeers)
            ..where((t) => t.deviceId.equals(dbDeviceId)))
          .getSingleOrNull();
      list.add({
        'deviceId': deviceId,
        'name': peer?.deviceName ?? 'Thiết bị ngoại tuyến',
        'userId': _deviceToUserMap[deviceId] ?? '',
      });
    }
    return list;
  }

  Future<void> resetBleRegistry() async {
    print('[BleDiscovery] Resetting BLE Registry...');
    try {
      // 1. Clear sessions in HandshakeService
      _handshakeService.clearAllSessions();
      
      // 2. Clear in-memory caches
      _activeClientCharacteristics.clear();
      for (final sub in _activeClientSubscriptions.values) {
        await sub.cancel();
      }
      _activeClientSubscriptions.clear();
      _deviceToUserMap.clear();
      _connectingDevices.clear();
      
      // 3. Clear database LocalBlePeers
      await _db.delete(_db.localBlePeers).go();
      
      // 4. Restart advertising and scanning
      await stopAdvertising();
      await stopScanning();
      await startAdvertising();
      await startScanning();
      print('[BleDiscovery] BLE Registry reset successfully.');
    } catch (e) {
      print('[BleDiscovery] Error resetting BLE Registry: $e');
    }
  }

  Future<void> _handleIncomingShareRequest(BleMeshPacket packet) async {
    try {
      final decompressedBytes = _transportService.parsePayload(packet.payload);
      final jsonStr = utf8.decode(decompressedBytes);
      final Map<String, dynamic> shareData = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final senderName = shareData['sender_name'] as String? ?? 'Ai đó';
      final senderUserId = shareData['sender_user_id'] as String? ?? 'unknown_sender';
      final table = shareData['table'] as String;
      final recordData = Map<String, dynamic>.from(shareData['data'] as Map);
      
      final recordName = recordData['name'] ?? recordData['title'] ?? 'Bản ghi không tên';
      final recordTypeLabel = table == 'leads' ? 'Cơ hội' : 'Dịch vụ';
      
      print('[BleDiscovery] Incoming share request from $senderName for $recordTypeLabel: $recordName');
      
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        print('[BleDiscovery] Cannot show share dialog: context is null.');
        return;
      }
      
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            '📥 Chia sẻ ngoại tuyến',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '$senderName muốn chia sẻ $recordTypeLabel "$recordName" với bạn qua kết nối Bluetooth.\n\nBạn có muốn nhận bản ghi này không?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Không cần', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Chấp nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ).then((approved) async {
        final status = approved == true ? 'approved' : 'ignored';
        print('[BleDiscovery] User decision for shared record: $status');
        
        if (approved == true) {
          final syncService = SyncService();
          final Map<String, dynamic> localRecordData = {
            ...recordData,
            if (table == 'leads' || table == 'deals') 'visibility': 'team',
          };
          
          await syncService.applySyncUpdate({
            'table': table,
            'operation': 'insert',
            'data': localRecordData,
          }, force: true);
          print('[BleDiscovery] Shared record applied locally: $table ID: ${recordData['id']}');
          
          // Grant explicit permission locally for 'team' visibility records
          if (table == 'leads' || table == 'deals' || table == 'service_items') {
            try {
              final activeUserId = await SettingsService().getActiveUserId();
              final db = AppDatabase();
              await db.into(db.recordSharingPermissions).insert(
                RecordSharingPermissionsCompanion.insert(
                  id: const Uuid().v4(),
                  recordType: table,
                  recordId: recordData['id'] as String,
                  sharedWith: activeUserId,
                  sharedBy: senderUserId,
                  permissionLevel: const Value('edit'),
                ),
                mode: InsertMode.insertOrReplace,
              );
              print('[BleDiscovery] Granted explicit local permission for shared record ID: ${recordData['id']}');
            } catch (e) {
              print('[BleDiscovery] Error granting sharing permission locally: $e');
            }
          }
          
          _shareCompletedController.add(table);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                content: Text('🎉 Đã chấp nhận và lưu $recordTypeLabel "$recordName"!'),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🚫 Đã bỏ qua bản ghi chia sẻ từ $senderName.'),
              ),
            );
          }
        }
        
        final responseData = {
          'table': table,
          'id': recordData['id'],
          'status': status,
        };
        
        final identity = await _identityService.getOrCreateIdentity();
        final responsePayload = _transportService.preparePayload(utf8.encode(jsonEncode(responseData)));
        final responsePacket = BleMeshPacket(
          messageId: 'share-resp-${DateTime.now().millisecondsSinceEpoch}',
          senderDeviceId: identity.deviceId,
          recipientDeviceId: packet.senderDeviceId,
          payload: responsePayload,
          ttl: 1,
          messageType: BleMessageType.shareResponse,
        );
        
        await sendPacket(packet.senderDeviceId, responsePacket);
      });
    } catch (e) {
      print('[BleDiscovery] Error handling incoming share request: $e');
    }
  }

  Future<void> _handleIncomingShareResponse(BleMeshPacket packet) async {
    try {
      final decompressedBytes = _transportService.parsePayload(packet.payload);
      final jsonStr = utf8.decode(decompressedBytes);
      final Map<String, dynamic> responseData = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final table = responseData['table'] as String;
      final status = responseData['status'] as String;
      final recordTypeLabel = table == 'leads' ? 'Cơ hội' : 'Dịch vụ';
      
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        if (status == 'approved') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('✅ Người nhận đã CHẤP NHẬN chia sẻ $recordTypeLabel!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text('❌ Người nhận đã BỎ QUA chia sẻ $recordTypeLabel.'),
            ),
          );
        }
      }
    } catch (e) {
      print('[BleDiscovery] Error handling incoming share response: $e');
    }
  }

  Future<bool> shareRecordWithPeer({
    required String remoteDeviceId,
    required String table,
    required Map<String, dynamic> recordData,
  }) async {
    try {
      final identity = await _identityService.getOrCreateIdentity();
      final currentUserId = await SettingsService().getActiveUserId();
      final shareData = {
        'sender_name': identity.deviceName,
        'sender_user_id': currentUserId,
        'table': table,
        'data': recordData,
      };
      
      final payloadBytes = utf8.encode(jsonEncode(shareData));
      final compressedPayload = _transportService.preparePayload(payloadBytes);
      
      final packet = BleMeshPacket(
        messageId: 'share-req-${DateTime.now().millisecondsSinceEpoch}',
        senderDeviceId: identity.deviceId,
        recipientDeviceId: remoteDeviceId,
        payload: compressedPayload,
        ttl: 1,
        messageType: BleMessageType.shareRequest,
      );
      
      print('[BleDiscovery] Triggering share request for $table to $remoteDeviceId...');
      return await sendPacket(remoteDeviceId, packet);
    } catch (e) {
      print('[BleDiscovery] Failed to share record: $e');
      return false;
    }
  }

  void dispose() {
    stopScanning();
    stopAdvertising();
    for (final sub in _activeClientSubscriptions.values) {
      sub.cancel();
    }
    _activeClientSubscriptions.clear();
    _activeClientCharacteristics.clear();
    _messageReceivedController.close();
    _shareCompletedController.close();
  }
}
