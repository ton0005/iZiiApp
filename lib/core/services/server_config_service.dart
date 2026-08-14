// lib/core/services/server_config_service.dart
//
// Quản lý server mà thiết bị đang kết nối tới (host, port, server_id, zone).
// Khớp với kiến trúc multi-server phía backend (server_config.py):
// mỗi server có server_id + zone riêng, thiết bị có thể chọn server nào để
// kết nối và đổi bất cứ lúc nào (vd nhân viên di chuyển giữa Plant M1 và M2).
//
// Service này KHÔNG phải BLoC — nó là data/persistence layer thuần tuý,
// được các BLoC khác (ServerSelectionBloc, và cả các BLoC sync dữ liệu
// khác của app) inject vào để biết đang nói chuyện với server nào.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Đại diện cho 1 server (đã lưu hoặc đang dùng).
class ServerInfo {
  final String serverId;
  final String zone;
  final String host;
  final int port;
  final String? version;

  /// `http` hoặc `https`. Trước đây [baseUrl] ghi cứng `http://`, nên mọi địa
  /// chỉ HTTPS (vd tunnel ra Internet) đều bị gọi sai giao thức.
  final String scheme;

  const ServerInfo({
    required this.serverId,
    required this.zone,
    required this.host,
    required this.port,
    this.version,
    this.scheme = 'http',
  });

  /// Base URL dùng cho mọi request HTTP tới server này.
  ///
  /// Bỏ cổng khi dùng cổng mặc định của giao thức — địa chỉ tunnel HTTPS
  /// không có cổng trong URL.
  String get baseUrl {
    final isDefaultPort =
        (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80);
    return isDefaultPort ? '$scheme://$host' : '$scheme://$host:$port';
  }

  ServerInfo copyWith({String? host, int? port, String? scheme}) => ServerInfo(
        serverId: serverId,
        zone: zone,
        host: host ?? this.host,
        port: port ?? this.port,
        version: version,
        scheme: scheme ?? this.scheme,
      );

  Map<String, dynamic> toJson() => {
        'serverId': serverId,
        'zone': zone,
        'host': host,
        'port': port,
        'version': version,
        'scheme': scheme,
      };

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        serverId: json['serverId'] as String,
        zone: json['zone'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        version: json['version'] as String?,
        scheme: (json['scheme'] as String?) ?? 'http',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerInfo &&
          serverId == other.serverId &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => Object.hash(serverId, host, port);

  @override
  String toString() => 'ServerInfo($serverId @ $host:$port, zone=$zone)';
}

/// Service singleton quản lý server đang được chọn làm mặc định.
class ServerConfigService {
  ServerConfigService._internal();
  static final ServerConfigService instance = ServerConfigService._internal();

  static const _prefsKey = 'iziiapp_selected_server';

  ServerInfo? _currentServer;
  ServerInfo? get currentServer => _currentServer;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _currentServer = ServerInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _currentServer = null;
      }
    }
    _initialized = true;
  }

  Future<void> setCurrentServer(ServerInfo server) async {
    _currentServer = server;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(server.toJson()));
  }

  Future<void> clearCurrentServer() async {
    _currentServer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  bool get hasSelectedServer => _currentServer != null;
}
