import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../modules/communication/models/ble_models.dart';
import '../../modules/communication/services/ble_transport_service.dart';
import 'outbox_queue.dart';
import 'sync_service.dart';

/// Manages offline-first data synchronization (Track 2 Selective Share) over P2P BLE.
class BleSyncManager {
  static final BleSyncManager _instance = BleSyncManager._internal();
  factory BleSyncManager() => _instance;
  BleSyncManager._internal();

  final OutboxQueue _outbox = OutboxQueue();
  final AppDatabase _db = AppDatabase();
  final BleTransportService _transport = BleTransportService();

  /// Scans the local Outbox and sends eligible shared mutations to the connected BLE peer.
  Future<void> syncOutboxWithPeer({
    required String remoteDeviceId,
    required String remoteUserId,
    required Function(List<int> bytes) sendBleBytes,
  }) async {
    print('[BleSync] Starting outbox sync with peer: $remoteUserId ($remoteDeviceId)');
    
    final mutations = await _outbox.getPendingMutations();
    if (mutations.isEmpty) {
      print('[BleSync] No pending mutations to sync.');
      return;
    }

    final List<Map<String, dynamic>> eligibleMutations = [];

    for (final m in mutations) {
      final String recordId = m['data']?['id'] ?? '';
      final String tableName = m['table'] as String;

      // 1. Check if record has shared visibility (team or community)
      final isShareable = await _isRecordSharedWithUser(
        tableName: tableName,
        recordId: recordId,
        remoteUserId: remoteUserId,
      );

      if (isShareable) {
        eligibleMutations.add(m);
      }
    }

    if (eligibleMutations.isEmpty) {
      print('[BleSync] No eligible shared mutations found for peer: $remoteUserId');
      return;
    }

    print('[BleSync] Syncing ${eligibleMutations.length} mutations to peer...');

    // Package mutations as a JSON array
    final payloadJson = jsonEncode(eligibleMutations);
    final rawBytes = utf8.encode(payloadJson);

    // Compress payload
    final preparedPayload = _transport.preparePayload(rawBytes);

    // Create BLE Mesh packet
    final packet = BleMeshPacket(
      messageId: 'sync-${DateTime.now().millisecondsSinceEpoch}-${remoteUserId.hashCode}',
      senderDeviceId: 'local-device', // Will be filled with actual device ID
      recipientDeviceId: remoteDeviceId,
      payload: preparedPayload,
      ttl: 1, // Directly connected, no mesh hops needed
      messageType: BleMessageType.syncResponse,
    );

    final serialized = packet.toJson();
    final packetBytes = utf8.encode(serialized);

    // Handle BLE fragmenting
    final fragments = _transport.fragmentPayload(packetBytes, BleMessageType.syncResponse);
    if (fragments.isEmpty) {
      sendBleBytes(packetBytes);
    } else {
      for (final fragment in fragments) {
        sendBleBytes(fragment.toBytes());
      }
    }
  }

  /// Handles incoming BLE sync packet containing database mutations from a peer.
  Future<void> handleIncomingSyncPacket(BleMeshPacket packet) async {
    try {
      print('[BleSync] Received sync packet from device: ${packet.senderDeviceId}');
      
      // Decompress
      final decompressedBytes = _transport.parsePayload(packet.payload);
      final jsonStr = utf8.decode(decompressedBytes);
      final List<dynamic> mutations = jsonDecode(jsonStr) as List<dynamic>;

      print('[BleSync] Applying ${mutations.length} mutations from peer...');

      final syncService = SyncService();
      
      for (final m in mutations) {
        final mutationMap = Map<String, dynamic>.from(m as Map);
        final table = mutationMap['table'] as String;
        final operation = mutationMap['operation'] as String;
        final data = Map<String, dynamic>.from(mutationMap['data'] as Map);

        // Apply mutation locally
        final success = await syncService.applySyncUpdate({
          'table': table,
          'operation': operation,
          'data': data,
        });

        if (success) {
          print('[BleSync] Applied mutation successfully: $table -> $operation (id=${data['id']})');
        } else {
          print('[BleSync] Failed to apply mutation: $table -> $operation');
        }
      }
    } catch (e) {
      print('[BleSync] Error processing incoming sync packet: $e');
    }
  }

  /// Verifies if a record is shared with a remote user via SQLite tables
  Future<bool> _isRecordSharedWithUser({
    required String tableName,
    required String recordId,
    required String remoteUserId,
  }) async {
    if (recordId.isEmpty) return false;

    try {
      // 1. Check permissions in RecordSharingPermissions table
      final permissions = await (_db.select(_db.recordSharingPermissions)
            ..where((tbl) => tbl.recordId.equals(recordId) &
                (tbl.sharedWith.equals(remoteUserId) | tbl.sharedWith.equals('community'))))
          .get();

      if (permissions.isNotEmpty) {
        return true;
      }
    } catch (e) {
      print('[BleSync] Error querying sharing permissions: $e');
    }

    return false;
  }
}
