import 'dart:async';

import 'package:dio/dio.dart';

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
      // 404 = "Device not found in registry". Máy có danh tính nhưng server
      // không biết nó — thường do database server bị reset. Trước đây client
      // cứ nhịp tim đều đặn và nhận 404 mãi (64 lần trong một phiên test),
      // nên /devices/online luôn trống và danh bạ hiện sai trạng thái.
      if (e.response?.statusCode == 404) {
        _log('ℹ️ Server chưa biết thiết bị này — đăng ký lại rồi thử lại.');
        try {
          await registerDevice();
        } catch (_) {}
        return;
      }
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

  /// Bộ nhớ đệm khoá công khai theo device_id.
  ///
  /// Khoá của một thiết bị KHÔNG đổi trong suốt vòng đời của nó (đổi khoá =
  /// đăng ký lại = device_id mới). Không đệm thì mỗi tin nhắn nhận về là một
  /// request riêng: log ngày 11/08 ghi nhận 9.286 lần gọi `/key` cho đúng một
  /// thiết bị, tất cả đều trả 200 với cùng một nội dung.
  final Map<String, RemoteDevice> _deviceKeyCache = {};

  /// Xoá đệm khi thiết bị đăng ký lại hoặc bị thu hồi.
  void invalidateDeviceCache([String? deviceId]) {
    if (deviceId == null) {
      _deviceKeyCache.clear();
    } else {
      _deviceKeyCache.remove(deviceId);
    }
  }

  /// Fetch a specific device's public keys and metadata.
  ///
  /// Endpoint: `GET /api/v1/devices/{deviceId}/key`
  Future<RemoteDevice?> getDeviceInfo(String deviceId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _deviceKeyCache[deviceId];
      if (cached != null) return cached;
    }

    try {
      final baseUrl = await _settingsService.getSyncServerUrl();

      final response = await _dio.get(
        '$baseUrl/api/v1/devices/$deviceId/key',
      );

      if (response.statusCode == 200 && response.data != null) {
        final device = RemoteDevice.fromMap(
            Map<String, dynamic>.from(response.data as Map));
        _deviceKeyCache[deviceId] = device;
        return device;
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
      final identity = await _identityService.getOrCreateIdentity();

      final payloadMaps = payloadsPerDevice.map(
        (deviceId, payload) => MapEntry(deviceId, payload.toMap()),
      );

      _log('📤 Sending E2EE to $baseUrl/api/v1/messages/send');
      _log('   conversation_id: $conversationId');
      _log('   sender_device_id: ${identity.deviceId}');
      _log('   recipients: ${recipientDeviceIds.length}');
      for (final entry in payloadMaps.entries) {
        _log('   payload keys for ${entry.key}: ${(entry.value as Map).keys.toList()}');
      }

      final response = await _dio.post(
        '$baseUrl/api/v1/messages/send',
        data: {
          'conversation_id': conversationId,
          'sender_device_id': identity.deviceId,
          'recipient_device_ids': recipientDeviceIds,
          'payloads': payloadMaps,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log(
            '✅ Encrypted message sent to ${recipientDeviceIds.length} device(s)');
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
  /// Server còn tin chưa giao sau lô vừa lấy hay không.
  ///
  /// Dùng để poll tiếp ngay thay vì đợi hết chu kỳ 5 giây — hàng đợi tồn đọng
  /// vẫn thoát nhanh dù mỗi lô nhỏ.
  bool lastPullHasMore = false;

  Future<List<Map<String, dynamic>>> getPendingMessages({int limit = 50}) async {
    try {
      final identity = await _identityService.getOrCreateIdentity();
      final baseUrl = await _settingsService.getSyncServerUrl();

      final response = await _dio.get(
        '$baseUrl/api/v1/messages/pending',
        queryParameters: {'device_id': identity.deviceId, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final list = response.data['messages'] as List<dynamic>? ?? [];
        lastPullHasMore = response.data['has_more'] == true;
        return list.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      }
      lastPullHasMore = false;
      return [];
    } on DioException catch (e) {
      lastPullHasMore = false;
      _log('❌ Failed to pull pending messages: ${_dioErrorMessage(e)}');
      return [];
    } catch (e) {
      lastPullHasMore = false;
      _log('❌ Error pulling messages: $e');
      return [];
    }
  }

  /// Báo cho server biết kết quả xử lý một lô tin.
  ///
  /// [messageIds] đã giải mã xong. [failedIds] thử mà không được — PHẢI báo,
  /// nếu không server tưởng chưa giao và gửi lại vô hạn. Đây chính là cơ chế
  /// đã làm hàng đợi kẹt 1173 tin trong lần test iPad ↔ Laptop.
  Future<void> acknowledgeMessages(
    List<String> messageIds, {
    List<String> failedIds = const [],
    String? failedReason,
  }) async {
    if (messageIds.isEmpty && failedIds.isEmpty) return;

    try {
      final identity = await _identityService.getOrCreateIdentity();
      final baseUrl = await _settingsService.getSyncServerUrl();

      await _dio.post(
        '$baseUrl/api/v1/messages/ack',
        data: {
          'device_id': identity.deviceId,
          'message_ids': messageIds,
          if (failedIds.isNotEmpty) 'failed_ids': failedIds,
          if (failedReason != null) 'failed_reason': failedReason,
        },
      );

      _log('✅ Ack ${messageIds.length} tin'
          '${failedIds.isEmpty ? '' : ', báo lỗi ${failedIds.length} tin'}');
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
