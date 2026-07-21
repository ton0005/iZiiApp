// lib/core/services/server_discovery_service.dart
//
// Quét mDNS trong mạng LAN để tìm các iZiiApp server đang chạy — khớp
// đúng service type và TXT record với phía backend (server_discovery.py):
//
//   Service type : _iziiapp._tcp.local.
//   TXT record   : server_id, zone, version

import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import 'server_config_service.dart';

const String kIziiAppServiceType = '_iziiapp._tcp.local';
const Duration kDefaultScanTimeout = Duration(seconds: 5);

class ServerDiscoveryService {
  /// Quét mDNS trong [timeout], trả về danh sách server tìm được.
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

          await for (final IPAddressResourceRecord ip in client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
            if (serverId == null) continue;

            final info = ServerInfo(
              serverId: serverId,
              zone: zone ?? 'unknown',
              host: ip.address.address,
              port: srv.port,
              version: version,
            );
            found[info.serverId] = info;
          }
        }
      }
    } finally {
      client.stop();
    }

    return found.values.toList();
  }

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
