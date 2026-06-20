import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import '../models/ble_models.dart';

/// Handles packet compression (GZIP) and fragmentation / reassembly (MTU compatibility) for BLE P2P.
class BleTransportService {
  static final BleTransportService _instance = BleTransportService._internal();
  factory BleTransportService() => _instance;
  BleTransportService._internal();

  static const int maxFragmentSize =
      480; // Leaving room for header within 512 bytes MTU
  static const int compressionThreshold =
      100; // Compress if payload > 100 bytes

  /// In-memory fragment buffer for incoming packets
  /// Maps fragmentId (hex string) -> Map of index to fragment data
  final Map<String, Map<int, List<int>>> _fragmentsBuffer = {};

  /// Maps fragmentId (hex string) -> Total expected fragments
  final Map<String, int> _expectedCount = {};

  /// Maps fragmentId (hex string) -> Original Message Type
  final Map<String, int> _originalTypes = {};

  /// Compresses payload with GZIP if it exceeds threshold.
  /// Prepends 1 byte header flag: 1 = compressed, 0 = uncompressed.
  List<int> preparePayload(List<int> data) {
    if (data.length < compressionThreshold) {
      // Prepend uncompressed flag (0)
      return [0, ...data];
    }
    try {
      final compressed = gzip.encode(data);
      if (compressed.length < data.length) {
        // Prepend compressed flag (1)
        return [1, ...compressed];
      }
    } catch (e) {
      print('[BleTransport] Compression failed, sending raw: $e');
    }
    return [0, ...data];
  }

  /// Decompresses payload. Reads the 1 byte header flag first.
  List<int> parsePayload(List<int> payload) {
    if (payload.isEmpty) return [];
    final isCompressed = payload[0] == 1;
    final data = payload.sublist(1);

    if (!isCompressed) return data;

    try {
      return gzip.decode(data);
    } catch (e) {
      throw FormatException('GZIP decompression failed: $e');
    }
  }

  /// Fragments a large payload if it exceeds [maxFragmentSize].
  /// Returns a list of [BleFragment]s, or empty list if no fragmentation is needed.
  List<BleFragment> fragmentPayload(
      List<int> payload, BleMessageType originalType) {
    if (payload.length <= maxFragmentSize) {
      return [];
    }

    // Generate random 8-byte fragment ID
    final random = Random.secure();
    final fragmentId = List<int>.generate(8, (_) => random.nextInt(256));

    final chunks = <List<int>>[];
    for (var i = 0; i < payload.length; i += maxFragmentSize) {
      final end = (i + maxFragmentSize < payload.length)
          ? i + maxFragmentSize
          : payload.length;
      chunks.add(payload.sublist(i, end));
    }

    final total = chunks.length;
    final List<BleFragment> fragments = [];

    for (var i = 0; i < total; i++) {
      BleMessageType type;
      if (i == 0) {
        type = BleMessageType.fragmentStart;
      } else if (i == total - 1) {
        type = BleMessageType.fragmentEnd;
      } else {
        type = BleMessageType.fragmentContinue;
      }

      fragments.add(BleFragment(
        fragmentId: fragmentId,
        type: type,
        index: i,
        total: total,
        originalType: originalType.value,
        data: chunks[i],
      ));
    }

    return fragments;
  }

  /// Adds an incoming BLE fragment to the collector.
  /// If reassembly is complete, returns the combined raw payload and original type.
  /// Otherwise, returns null.
  ({List<int> payload, BleMessageType type})? addFragment(
      BleFragment fragment) {
    final fragmentIdHex = fragment.fragmentId
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    if (!_fragmentsBuffer.containsKey(fragmentIdHex)) {
      _fragmentsBuffer[fragmentIdHex] = {};
      _expectedCount[fragmentIdHex] = fragment.total;
      _originalTypes[fragmentIdHex] = fragment.originalType;
    }

    final buffer = _fragmentsBuffer[fragmentIdHex]!;
    buffer[fragment.index] = fragment.data;

    // Check if we received all fragments
    final expected = _expectedCount[fragmentIdHex]!;
    if (buffer.length == expected) {
      // Reassemble
      final combined = BytesBuilder();
      for (var i = 0; i < expected; i++) {
        if (buffer.containsKey(i)) {
          combined.add(buffer[i]!);
        } else {
          print(
              '[BleTransport] Error: Missing fragment index $i in group $fragmentIdHex');
          return null;
        }
      }

      final originalTypeVal = _originalTypes[fragmentIdHex]!;

      // Clean up buffers
      _fragmentsBuffer.remove(fragmentIdHex);
      _expectedCount.remove(fragmentIdHex);
      _originalTypes.remove(fragmentIdHex);

      return (
        payload: combined.toBytes(),
        type: BleMessageType.fromInt(originalTypeVal)
      );
    }

    return null;
  }
}
