import 'dart:async';

import 'package:dio/dio.dart';

import '../database/app_database.dart';
import '../settings/settings_service.dart';
import 'device_identity_models.dart';
import 'device_identity_service.dart';

/// Network service for device registration, presence heartbeats,
/// device discovery, and encrypted message relay via the iZii sync server.
class DeviceDiscoveryService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final DeviceDiscoveryService _instance =
      DeviceDiscoveryService._internal();
  factory DeviceDiscoveryService() => _instance;
  DeviceDiscoveryService._internal();

  final DeviceIdentityService _identityService = DeviceIdentityService();
  final SettingsService _settingsService = SettingsService();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Timer? _heartbeatTimer;

  // ── Device registration ──────────────────────────────────────────────────

  Future<String> _getActiveUserId() async {
    try {
      return await _settingsService.getActiveUserId();
    } catch (_) {
      return 'default_user';
    }
  }

  /// Register this device's identity (public keys, platform, name) with the
  /// sync server.
  ///
  /// Endpoint: `POST /api/v1/devices/register`
  Future<bool> registerDevice() async {
    try {
      final identity = await _identityService.getOrCreateIdentity();
      final baseUrl = await _settingsService.getSyncServerUrl();
      final userId = await _getActiveUserId();

      final response = await _dio.post(
        '$baseUrl/api/v1/devices/register',
        data: {
          ...identity.toMap(),
          'user_id': userId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log('✅ Device registered: ${identity.deviceId}');
        return true;
      }

      _log('⚠️ Registration returned HTTP ${response.statusCode}');
      return false;
    } on DioException catch (e) {
      _log('❌ Registration failed: ${_dioErrorMessage(e)}');
      return false;
    } catch (e) {
      _log('❌ Registration error: $e');
      return false;
    }
  }

  // ── Heartbeat / Presence ─────────────────────────────────────────────────

  /// Send a single heartbeat to the server so it knows this device is online.
  ///
  /// Endpoint: `POST /api/v1/devices/heartbeat`
  Future<void> sendHeartbeat() async {
    try {
      final identity = await _identityService.getOrCreateIdentity();
      final baseUrl = await _settingsService.getSyncServerUrl();

      await _dio.post(
        '$baseUrl/api/v1/devices/heartbeat',
        data: {
          'device_id': identity.deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on DioException catch (e) {
      _log('⚠️ Heartbeat failed: ${_dioErrorMessage(e)}');
    } catch (e) {
      _log('⚠️ Heartbeat error: $e');
    }
  }

  /// Start a periodic heartbeat every 30 seconds.
  void startHeartbeat() {
    stopHeartbeat();
    _log('Starting heartbeat (every 30s)');
    // Send an immediate heartbeat, then schedule recurring ones.
    sendHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => sendHeartbeat(),
    );
  }

  /// Stop the periodic heartbeat timer.
  void stopHeartbeat() {
    if (_heartbeatTimer != null) {
      _heartbeatTimer!.cancel();
      _heartbeatTimer = null;
      _log('Heartbeat stopped');
    }
  }

  // ── Device discovery ─────────────────────────────────────────────────────

  /// Fetch all currently-online devices from the server.
  ///
  /// Endpoint: `GET /api/v1/devices/online`
  Future<List<RemoteDevice>> getOnlineDevices() async {
    try {
      final baseUrl = await _settingsService.getSyncServerUrl();
      final identity = await _identityService.getOrCreateIdentity();

      final response = await _dio.get(
        '$baseUrl/api/v1/devices/online',
        queryParameters: {
          'exclude_device_id': identity.deviceId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final list = response.data['devices'] as List<dynamic>? ?? [];
        return list
            .map((d) =>
                RemoteDevice.fromMap(Map<String, dynamic>.from(d as Map)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _log('❌ Failed to fetch online devices: ${_dioErrorMessage(e)}');
      return [];
    } catch (e) {
      _log('❌ Error fetching online devices: $e');
      return [];
    }
  }

  /// Fetch a specific device's public keys and metadata.
  ///
  /// Endpoint: `GET /api/v1/devices/{deviceId}/key`
  Future<RemoteDevice?> getDeviceInfo(String deviceId) async {
    try {
      final baseUrl = await _settingsService.getSyncServerUrl();

      final response = await _dio.get(
        '$baseUrl/api/v1/devices/$deviceId/key',
      );

      if (response.statusCode == 200 && response.data != null) {
        return RemoteDevice.fromMap(
            Map<String, dynamic>.from(response.data as Map));
      }
      return null;
    } on DioException catch (e) {
      _log('❌ Failed to get device info for $deviceId: ${_dioErrorMessage(e)}');
      return null;
    } catch (e) {
      _log('❌ Error getting device info: $e');
      return null;
    }
  }

  // ── Encrypted message relay ──────────────────────────────────────────────

  /// Send per-device encrypted payloads to the server for relay.
  ///
  /// Each entry in [payloadsPerDevice] maps a recipient device ID to its
  /// individually-encrypted [EncryptedPayload].
  ///
  /// Endpoint: `POST /api/v1/messages/send`
  Future<bool> sendEncryptedMessage({
    required String conversationId,
    required List<String> recipientDeviceIds,
    required Map<String, EncryptedPayload> payloadsPerDevice,
  }) async {
    try {
      final baseUrl = await _settingsService.getSyncServerUrl();

      final payloadMaps = payloadsPerDevice.map(
        (deviceId, payload) => MapEntry(deviceId, payload.toMap()),
      );

      final response = await _dio.post(
        '$baseUrl/api/v1/messages/send',
        data: {
          'conversation_id': conversationId,
          'recipient_device_ids': recipientDeviceIds,
          'payloads': payloadMaps,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log('✅ Encrypted message sent to ${recipientDeviceIds.length} device(s)');
        return true;
      }

      _log('⚠️ Send returned HTTP ${response.statusCode}');
      return false;
    } on DioException catch (e) {
      _log('❌ Failed to send message: ${_dioErrorMessage(e)}');
      return false;
    } catch (e) {
      _log('❌ Error sending message: $e');
      return false;
    }
  }

  /// Pull pending encrypted messages addressed to this device.
  ///
  /// Endpoint: `GET /api/v1/messages/pending?device_id=xxx`
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    try {
      final identity = await _identityService.getOrCreateIdentity();
      final baseUrl = await _settingsService.getSyncServerUrl();

      final response = await _dio.get(
        '$baseUrl/api/v1/messages/pending',
        queryParameters: {'device_id': identity.deviceId},
      );

      if (response.statusCode == 200 && response.data != null) {
        final list = response.data['messages'] as List<dynamic>? ?? [];
        return list
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _log('❌ Failed to pull pending messages: ${_dioErrorMessage(e)}');
      return [];
    } catch (e) {
      _log('❌ Error pulling messages: $e');
      return [];
    }
  }

  /// Acknowledge that the given [messageIds] have been received and
  /// decrypted successfully.
  ///
  /// Endpoint: `POST /api/v1/messages/ack`
  Future<void> acknowledgeMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return;

    try {
      final identity = await _identityService.getOrCreateIdentity();
      final baseUrl = await _settingsService.getSyncServerUrl();

      await _dio.post(
        '$baseUrl/api/v1/messages/ack',
        data: {
          'device_id': identity.deviceId,
          'message_ids': messageIds,
        },
      );

      _log('✅ Acknowledged ${messageIds.length} message(s)');
    } on DioException catch (e) {
      _log('⚠️ Ack failed: ${_dioErrorMessage(e)}');
    } catch (e) {
      _log('⚠️ Ack error: $e');
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Release resources (heartbeat timer, dio connections).
  void dispose() {
    stopHeartbeat();
    _dio.close(force: true);
  }

  // ── Logging / helpers ────────────────────────────────────────────────────

  void _log(String message) {
    print('[DeviceDiscovery] $message');
  }

  String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.connectionError:
        return 'Connection error – is the server running?';
      default:
        return e.message ?? e.toString();
    }
  }
}
