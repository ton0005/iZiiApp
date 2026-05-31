class OutboxQueue {
  static final OutboxQueue _instance = OutboxQueue._internal();
  factory OutboxQueue() => _instance;
  OutboxQueue._internal();

  final List<Map<String, dynamic>> _queue = [];

  void addMutation(String table, String operation, Map<String, dynamic> data) {
    _queue.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'table': table,
      'operation': operation, // insert, update, delete
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
    // Trong thực tế sẽ lưu xuống SQLite table tên `OutboxMutations`
  }

  List<Map<String, dynamic>> getPendingMutations() {
    return _queue.where((m) => m['status'] == 'pending').toList();
  }

  void markAsSynced(String mutationId) {
    final index = _queue.indexWhere((m) => m['id'] == mutationId);
    if (index != -1) {
      _queue[index]['status'] = 'synced';
    }
  }

  void clearSynced() {
    _queue.removeWhere((m) => m['status'] == 'synced');
  }
}
