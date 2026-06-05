import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../settings/settings_service.dart';
import 'outbox_queue.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OutboxQueue _outbox = OutboxQueue();
  final SettingsService _settingsService = SettingsService();
  final Connectivity _connectivity = Connectivity();
  final AppDatabase _db = AppDatabase();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  Timer? _periodicTimer;

  // Real-time synchronization log stream for UI feedback
  final _syncLogController = StreamController<String>.broadcast();
  Stream<String> get syncLogStream => _syncLogController.stream;

  bool get isSyncing => _isSyncing;

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _log('Kết nối mạng được thiết lập. Tự động đồng bộ...');
        triggerSync();
      } else {
        _log('Thiết bị mất kết nối mạng. Chế độ Ngoại tuyến (Offline).');
      }
    });

    _periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) => triggerSync());
    _log('Sync Service đã được khởi tạo.');
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    _syncLogController.close();
  }

  void _log(String message) {
    print('[SyncService] $message');
    if (!_syncLogController.isClosed) {
      _syncLogController.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
    }
  }

  Future<bool> triggerSync() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final url = await _settingsService.getSyncServerUrl();
      final token = await _settingsService.getSyncToken();
      final lastSync = await _settingsService.getLastSyncTimestamp();

      _log('Đang kết nối tới server: $url ...');

      // ── PUSH: gửi các mutations lên server ──
      final mutations = await _outbox.getPendingMutations();
      if (mutations.isEmpty) {
        _log('Không có thay đổi nào cần đồng bộ lên server.');
      } else {
        _log('Đang gửi ${mutations.length} thay đổi lên server...');
        for (var m in mutations) {
          _log('   📦 ${m['table']} → ${m['operation']}');
        }

        final payload = mutations.map((m) => {
          'id': m['id'],
          'table': m['table'],
          'operation': m['operation'],
          'data': m['data'],
          'timestamp': m['timestamp'],
        }).toList();

        final response = await _dio.post(
          '$url/sync/push',
          data: {'mutations': payload},
          options: Options(headers: {
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          _log('✅ PUSH thành công! Server đã nhận ${mutations.length} thay đổi.');
          for (var mutation in mutations) {
            await _outbox.markAsSynced(mutation['id']);
          }
          await _outbox.clearSynced();
        } else {
          _log('❌ Server phản hồi lỗi: HTTP ${response.statusCode}');
          return false;
        }
      }

      // ── PULL: kéo dữ liệu mới từ server về ──
      await _pullServerChanges(url, token, lastSync);

      await _settingsService.saveLastSyncTimestamp(DateTime.now().toIso8601String());
      _log('🎉 Hoàn thành đồng bộ dữ liệu đa nền tảng!');
      return true;

    } on DioException catch (e) {
      final url = await _settingsService.getSyncServerUrl();
      _log('❌ Lỗi kết nối tới server ($url):');
      if (e.type == DioExceptionType.connectionTimeout) {
        _log('   → Hết thời gian chờ kết nối (Connection Timeout).');
      } else if (e.type == DioExceptionType.connectionError) {
        _log('   → Không thể kết nối. Kiểm tra lại URL và đảm bảo server đang chạy.');
      } else {
        _log('   → ${e.message}');
      }
      _log('💡 Gợi ý: Nếu dùng USB, hãy đảm bảo đã chạy "adb reverse tcp:8080 tcp:8080"');
      _log('   và Server URL đang là http://127.0.0.1:8080');
      return false;
    } catch (e) {
      _log('❌ Lỗi đồng bộ không xác định: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pullServerChanges(String url, String token, String? lastSync) async {
    _log('Đang kiểm tra cập nhật mới từ Server...');
    try {
      final response = await _dio.get(
        '$url/sync/pull',
        queryParameters: {if (lastSync != null) 'since': lastSync},
        options: Options(headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['updates'] != null) {
          final updatesList = data['updates'] as List;
          if (updatesList.isEmpty) {
            _log('Không có cập nhật mới từ Server.');
            return;
          }
          _log('📥 Nhận được ${updatesList.length} cập nhật từ Server. Đang ghi vào database...');

          int applied = 0;
          int skipped = 0;
          for (final update in updatesList) {
            try {
              final updateMap = update is Map<String, dynamic>
                  ? update
                  : Map<String, dynamic>.from(update as Map);
              final wasApplied = await _applyServerUpdate(updateMap);
              if (wasApplied) {
                applied++;
              } else {
                skipped++;
              }
            } catch (e) {
              skipped++;
              _log('   ⚠️ Lỗi áp dụng 1 cập nhật: $e');
            }
          }
          _log('✅ Đã ghi $applied bản ghi vào database local (bỏ qua $skipped).');
        } else {
          _log('Không có cập nhật mới từ Server.');
        }
      }
    } on DioException catch (e) {
      _log('⚠️ Không thể kéo dữ liệu từ Server: ${e.message}');
    }
  }

  /// Apply a single server update to the local database (upsert)
  Future<bool> _applyServerUpdate(Map<String, dynamic> update) async {
    final table = update['table'] as String?;
    final operation = update['operation'] as String?;
    final rawData = update['data'];

    if (table == null || rawData == null) return false;

    final data = rawData is Map<String, dynamic>
        ? rawData
        : Map<String, dynamic>.from(rawData as Map);

    _log('   🔄 $table → ${operation ?? 'upsert'}: id=${data['id'] ?? 'N/A'}');

    switch (table) {
      case 'leads':
        return _upsertLead(data);
      case 'products':
        return _upsertProduct(data);
      case 'contacts':
        return _upsertContact(data);
      case 'deals':
        return _upsertDeal(data);
      case 'service_items':
        return _upsertServiceItem(data);
      case 'service_bookings':
        return _upsertServiceBooking(data);
      default:
        _log('   ⚠️ Bảng "$table" chưa được hỗ trợ đồng bộ PULL.');
        return false;
    }
  }

  // ──────────────── UPSERT methods for each table ────────────────

  Future<bool> _upsertLead(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    String customFields = '{}';
    if (data['custom_fields'] != null) {
      customFields = data['custom_fields'] is String
          ? data['custom_fields']
          : jsonEncode(data['custom_fields']);
    }

    await _db.into(_db.leads).insertOnConflictUpdate(
      LeadsCompanion(
        id: Value(id),
        title: Value(data['title'] as String? ?? 'Untitled'),
        contactId: Value(data['contact_id'] as String?),
        status: Value(data['status'] as String? ?? 'new'),
        expectedRevenue: Value((data['expected_revenue'] as num?)?.toDouble() ?? 0.0),
        notes: Value(data['name'] as String?),
        customFields: Value(customFields),
      ),
    );
    return true;
  }

  Future<bool> _upsertProduct(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    String customFields = '{}';
    if (data['custom_fields'] != null) {
      customFields = data['custom_fields'] is String
          ? data['custom_fields']
          : jsonEncode(data['custom_fields']);
    }

    await _db.into(_db.products).insertOnConflictUpdate(
      ProductsCompanion(
        id: Value(id),
        sku: Value(data['sku'] as String? ?? 'SKU-${id.substring(0, 8)}'),
        name: Value(data['name'] as String? ?? 'Unnamed Product'),
        price: Value((data['price'] as num?)?.toDouble() ?? 0.0),
        cost: Value((data['cost'] as num?)?.toDouble() ?? 0.0),
        type: Value(data['type'] as String? ?? 'product'),
        barcode: Value(data['barcode'] as String?),
        customFields: Value(customFields),
      ),
    );
    return true;
  }

  Future<bool> _upsertContact(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    await _db.into(_db.contacts).insertOnConflictUpdate(
      ContactsCompanion(
        id: Value(id),
        name: Value(data['name'] as String? ?? 'Unknown'),
        phone: Value(data['phone'] as String?),
        email: Value(data['email'] as String?),
        address: Value(data['address'] as String?),
        company: Value(data['company'] as String?),
        isCustomer: Value(data['is_customer'] as bool? ?? true),
      ),
    );
    return true;
  }

  Future<bool> _upsertDeal(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    await _db.into(_db.deals).insertOnConflictUpdate(
      DealsCompanion(
        id: Value(id),
        title: Value(data['title'] as String? ?? 'Untitled Deal'),
        leadId: Value(data['lead_id'] as String?),
        contactId: Value(data['contact_id'] as String? ?? ''),
        amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
        stage: Value(data['stage'] as String? ?? 'proposal'),
        expectedCloseDate: data['expected_close_date'] != null
            ? Value(DateTime.tryParse(data['expected_close_date'].toString()))
            : const Value(null),
      ),
    );
    return true;
  }

  Future<bool> _upsertServiceItem(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    String customFields = '{}';
    if (data['custom_fields'] != null) {
      customFields = data['custom_fields'] is String
          ? data['custom_fields']
          : jsonEncode(data['custom_fields']);
    }

    await _db.into(_db.serviceItems).insertOnConflictUpdate(
      ServiceItemsCompanion(
        id: Value(id),
        name: Value(data['name'] as String? ?? 'Unnamed Service'),
        category: Value(data['category'] as String? ?? 'other'),
        hourlyRate: Value((data['hourly_rate'] as num?)?.toDouble() ?? 0.0),
        estimatedHours: Value((data['estimated_hours'] as num?)?.toDouble() ?? 1.0),
        description: Value(data['description'] as String?),
        isActive: Value(data['is_active'] as bool? ?? true),
        customFields: Value(customFields),
      ),
    );
    return true;
  }

  Future<bool> _upsertServiceBooking(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    String customFields = '{}';
    if (data['custom_fields'] != null) {
      customFields = data['custom_fields'] is String
          ? data['custom_fields']
          : jsonEncode(data['custom_fields']);
    }

    await _db.into(_db.serviceBookings).insertOnConflictUpdate(
      ServiceBookingsCompanion(
        id: Value(id),
        serviceItemId: Value(data['service_item_id'] as String? ?? ''),
        customerName: Value(data['customer_name'] as String? ?? 'Unknown'),
        customerPhone: Value(data['customer_phone'] as String?),
        scheduledAt: data['scheduled_at'] != null
            ? Value(DateTime.tryParse(data['scheduled_at'].toString()))
            : const Value(null),
        actualHours: Value((data['actual_hours'] as num?)?.toDouble()),
        totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0.0),
        status: Value(data['status'] as String? ?? 'pending'),
        notes: Value(data['notes'] as String?),
        customFields: Value(customFields),
      ),
    );
    return true;
  }

  /// Queue a local mutation to be synchronized later
  Future<void> queueMutation(String table, String operation, Map<String, dynamic> data) async {
    await _outbox.addMutation(table, operation, data);
    _log('📝 Đã lưu ngoại tuyến thay đổi: $table -> $operation');
  }
}


