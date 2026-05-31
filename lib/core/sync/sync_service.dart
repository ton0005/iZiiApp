import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'outbox_queue.dart';

class SyncService {
  final OutboxQueue _outbox = OutboxQueue();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  void initialize() {
    // Lắng nghe thay đổi mạng
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _triggerSync();
      }
    });
    
    // Chạy định kỳ
    Timer.periodic(const Duration(minutes: 5), (_) => _triggerSync());
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final mutations = _outbox.getPendingMutations();
      if (mutations.isEmpty) {
        _isSyncing = false;
        return;
      }

      print('Starting sync of ${mutations.length} items...');

      for (var mutation in mutations) {
        // Giả lập gửi lên Server (Supabase/Firebase/Odoo)
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Đánh dấu thành công
        _outbox.markAsSynced(mutation['id']);
        print('Synced ${mutation['table']} ${mutation['operation']}');
      }

      _outbox.clearSynced();
      print('Sync complete!');
      
    } catch (e) {
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Gọi hàm này khi UI thực hiện thay đổi dữ liệu (VD: thêm Lead mới)
  void queueMutation(String table, String operation, Map<String, dynamic> data) {
    _outbox.addMutation(table, operation, data);
    _triggerSync(); // Thử sync ngay lập tức nếu có mạng
  }
}
