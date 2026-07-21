// lib/core/services/server_discovery_service.dart
//
// Quét mDNS trong mạng LAN để tìm các iZiiApp server đang chạy — khớp
// đúng service type và TXT record với phía backend (server_discovery.py):
//
//   Service type : _iziiapp._tcp.local.
//   TXT record   : server_id, zone, version
//
// Dùng package `multicast_dns` (thuần Dart, không cần platform channel
// riêng, hoạt động ổn định trên cả iOS/iPad/Android):
//
//   dependencies:
//     multicast_dns: ^0.3.2+6
//
// LƯU Ý iOS: từ iOS 14 trở lên, quét mDNS cần khai báo quyền Local Network
// trong Info.plist:
//   <key>NSLocalNetworkUsageDescription</key>
//   <string>Ứng dụng cần quét mạng LAN để tìm server iZiiApp gần bạn.</string>
//   <key>NSBonjourServices</key>
//   <array>
//     <string>_iziiapp._tcp</string>
//   </array>
//
// LƯU Ý Android: cần quyền ACCESS_WIFI_STATE + CHANGE_WIFI_MULTICAST_STATE
// trong AndroidManifest.xml:
//   <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
//   <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />

import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import 'server_config_service.dart';

const String kIziiAppServiceType = '_iziiapp._tcp.local';
const Duration kDefaultScanTimeout = Duration(seconds: 5);

class ServerDiscoveryService {
  /// Quét mDNS trong [timeout], trả về danh sách server tìm được.
  /// Tự loại trùng theo server_id (nếu 1 server trả lời qua nhiều interface
  /// mạng, chỉ giữ 1 bản ghi).
  Future<List<ServerInfo>> scan({Duration timeout = kDefaultScanTimeout}) async {
    final MDnsClient client = MDnsClient();
    final Map<String, ServerInfo> found = {};

    try {
      await client.start();

      final ptrStream = client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(kIziiAppServiceType),
      );

      await for (final PtrResourceRecord ptr in ptrStream.timeout(
        timeout,
        onTimeout: (sink) => sink.close(),
      )) {
        // Với mỗi service tìm thấy, resolve tiếp SRV (host+port) và TXT
        // (server_id, zone, version).
        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          String? serverId;
          String? zone;
          String? version;

          await for (final TxtResourceRecord txt in client
              .lookup<TxtResourceRecord>(
                ResourceRecordQuery.text(ptr.domainName),
              )
              .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
            final parsed = _parseTxtRecord(txt.text);
            serverId = parsed['server_id'];
            zone = parsed['zone'];
            version = parsed['version'];
          }

          // Resolve địa chỉ IP thật của host
          await for (final IPAddressResourceRecord ip in client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
            if (serverId == null) continue; // Không có TXT record hợp lệ -> bỏ qua

            final info = ServerInfo(
              serverId: serverId,
              zone: zone ?? 'unknown',
              host: ip.address.address,
              port: srv.port,
              version: version,
            );
            found[info.serverId] = info; // dedupe theo server_id
          }
        }
      }
    } finally {
      client.stop();
    }

    return found.values.toList();
  }

  /// TXT record trả về dạng "key=value" từng dòng nối bởi ký tự \x00 hoặc
  /// đôi khi thư viện đã tách sẵn theo dòng \n tuỳ version — parse phòng thủ
  /// cho cả 2 trường hợp.
  Map<String, String> _parseTxtRecord(String raw) {
    final result = <String, String>{};
    final parts = raw.split(RegExp(r'[\n\x00]')).where((s) => s.isNotEmpty);
    for (final part in parts) {
      final idx = part.indexOf('=');
      if (idx == -1) continue;
      result[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return result;
  }

  /// Kiểm tra 1 server còn phản hồi không, dùng cho:
  /// - Xác nhận server trước khi lưu làm mặc định
  /// - Failover: khi server đang dùng không phản hồi, thử ping lại trước
  ///   khi quét lại toàn bộ mạng (nhanh hơn quét mDNS từ đầu)
  ///
  /// Gọi GET /health — endpoint dành riêng cho thiết bị (KHÔNG dùng
  /// /peer-sync/health, endpoint đó chỉ dành cho server-to-server).
  Future<bool> isServerReachable(ServerInfo server, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final client = HttpClient()..connectionTimeout = timeout;
      final request = await client.getUrl(Uri.parse('${server.baseUrl}/health')).timeout(timeout);
      final response = await request.close().timeout(timeout);
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
