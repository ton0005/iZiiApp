import 'dart:collection';
import '../models/ble_models.dart';

/// Handles BLE Mesh routing, packet deduplication, and TTL expiration.
/// Inspired by Bitchat's BloomFilter-based mesh relay routing.
class BleMeshRoutingService {
  static final BleMeshRoutingService _instance = BleMeshRoutingService._internal();
  factory BleMeshRoutingService() => _instance;
  BleMeshRoutingService._internal();

  /// Maximum size of deduplication cache to prevent memory leaks
  static const int maxCacheSize = 5000;

  /// Cache of recently seen message IDs (acting as our Bloom Filter)
  final Queue<String> _seenMessageIdsQueue = Queue<String>();
  final Set<String> _seenMessageIdsSet = <String>{};

  /// Registers a message ID in the deduplication cache.
  /// Returns `true` if the message is fresh (never seen before).
  /// Returns `false` if it is a duplicate (should be dropped).
  bool registerMessageId(String messageId) {
    if (_seenMessageIdsSet.contains(messageId)) {
      return false; // Duplicate packet, drop it
    }

    // Add to cache
    _seenMessageIdsSet.add(messageId);
    _seenMessageIdsQueue.addLast(messageId);

    // Evict old entries if cache is full
    if (_seenMessageIdsSet.length > maxCacheSize) {
      final oldest = _seenMessageIdsQueue.removeFirst();
      _seenMessageIdsSet.remove(oldest);
    }

    return true; // Fresh packet
  }

  /// Evaluates whether a packet should be processed and/or relayed.
  /// Returns a modified [BleMeshPacket] with decremented TTL if it should be relayed.
  /// Returns `null` if the packet should be dropped (seen before, or TTL <= 1).
  BleMeshPacket? processAndPrepareRelay(BleMeshPacket packet) {
    // 1. Deduplicate
    final isNew = registerMessageId(packet.messageId);
    if (!isNew) {
      print('[MeshRouting] Packet ${packet.messageId} is a duplicate. Dropping.');
      return null;
    }

    // 2. Check TTL
    if (packet.ttl <= 1) {
      print('[MeshRouting] Packet ${packet.messageId} reached TTL = 0. Dropping.');
      return null;
    }

    // 3. Prepare relay packet with decremented TTL
    return BleMeshPacket(
      messageId: packet.messageId,
      senderDeviceId: packet.senderDeviceId,
      recipientDeviceId: packet.recipientDeviceId,
      payload: packet.payload,
      ttl: packet.ttl - 1,
      messageType: packet.messageType,
      signatureBase64: packet.signatureBase64,
    );
  }

  /// Clears the seen packet cache.
  void clearCache() {
    _seenMessageIdsQueue.clear();
    _seenMessageIdsSet.clear();
  }
}
