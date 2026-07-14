import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../settings/settings_service.dart';
import 'outbox_queue.dart';
import 'sync_config_repository.dart';
import '../device_identity/ble_device_discovery_service.dart';
import 'ble_sync_manager.dart';

class SyncEvent {
  final List<String> updatedTables;
  SyncEvent(this.updatedTables);
}

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

  // Sync completion event stream to notify UI BLoCs
  final _syncEventController = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get syncEventStream => _syncEventController.stream;

  bool get isSyncing => _isSyncing;

  Future<String> _getActiveUserId() async {
    try {
      return await _settingsService.getActiveUserId();
    } catch (_) {
      return 'default_user';
    }
  }

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _log('Kết nối mạng được thiết lập. Tự động đồng bộ...');
        triggerSync(isManual: false);
      } else {
        _log('Thiết bị mất kết nối mạng. Chế độ Ngoại tuyến (Offline).');
      }
    });

    _periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) => triggerSync(isManual: false));
    _log('Sync Service đã được khởi tạo.');
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    _syncLogController.close();
    _syncEventController.close();
  }

  void _log(String message) {
    print('[SyncService] $message');
    if (!_syncLogController.isClosed) {
      _syncLogController.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
    }
  }

  Future<bool> triggerSync({bool isManual = false}) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final url = await _settingsService.getSyncServerUrl();
      final token = await _settingsService.getSyncToken();
      final lastSync = await _settingsService.getLastSyncTimestamp();

      _log('Đang kết nối tới server: $url ...');

      final userId = await _getActiveUserId();
      final syncConfigRepo = SyncConfigRepository();
      final configs = await syncConfigRepo.getConfigsForUser(userId);
      final configMap = {for (var c in configs) c.moduleKey: c};

      // ── PUSH: gửi các mutations lên server ──
      final mutations = await _outbox.getPendingMutations();
      if (mutations.isEmpty) {
        _log('Không có thay đổi nào cần đồng bộ lên server.');
      } else {
        final filteredMutations = <Map<String, dynamic>>[];
        for (var m in mutations) {
          final tableName = m['table'] as String;
          final moduleKey = SyncConfigRepository.tableToModuleMap[tableName];
          
          if (moduleKey == null) {
            filteredMutations.add(m);
            continue;
          }

          final config = configMap[moduleKey];
          if (config == null || !config.isEnabled) {
            continue; // Skip disabled modules
          }

          if (!isManual && config.syncGranularity == 'manual') {
            continue; // Skip manual-only modules in background sync
          }

          if (config.syncGranularity == 'selective' && config.selectiveEntities != null) {
            try {
              final selective = List<String>.from(jsonDecode(config.selectiveEntities!));
              if (!selective.contains(tableName)) {
                continue; // Skip disabled sub-entities
              }
            } catch (_) {}
          }

          filteredMutations.add(m);
        }

        if (filteredMutations.isEmpty) {
          _log('Không có thay đổi nào thuộc các module được bật cần đồng bộ.');
        } else {
          _log('Đang gửi ${filteredMutations.length} thay đổi lên server...');
          for (var m in filteredMutations) {
            _log('   📦 ${m['table']} → ${m['operation']}');
          }

          final payload = filteredMutations.map((m) => {
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
            _log('✅ PUSH thành công! Server đã nhận ${filteredMutations.length} thay đổi.');
            for (var mutation in filteredMutations) {
              await _outbox.markAsSynced(mutation['id']);
            }
            await _outbox.clearSynced();
          } else {
            _log('❌ Server phản hồi lỗi: HTTP ${response.statusCode}');
            return false;
          }
        }
      }

      // ── PULL: kéo dữ liệu mới từ server về ──
      final serverTimestamp = await _pullServerChanges(url, token, lastSync, configMap, isManual);

      if (serverTimestamp != null) {
        await _settingsService.saveLastSyncTimestamp(serverTimestamp);
      } else {
        await _settingsService.saveLastSyncTimestamp(DateTime.now().toIso8601String());
      }
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
      return false;
    } catch (e) {
      _log('❌ Lỗi đồng bộ không xác định: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<String?> _pullServerChanges(
    String url,
    String token,
    String? lastSync,
    Map<String, UserSyncConfig> configMap,
    bool isManual,
  ) async {
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
          final serverTimestamp = data['timestamp'] as String?;
          if (updatesList.isEmpty) {
            _log('Không có cập nhật mới từ Server.');
            return serverTimestamp;
          }
          _log('📥 Nhận được ${updatesList.length} cập nhật từ Server. Đang lọc và áp dụng...');

          int applied = 0;
          int skipped = 0;
          final updatedTables = <String>{};
          for (final update in updatesList) {
            try {
              final updateMap = update is Map<String, dynamic>
                  ? update
                  : Map<String, dynamic>.from(update as Map);
              final wasApplied = await _applyServerUpdate(updateMap, configMap, isManual);
              if (wasApplied) {
                applied++;
                if (updateMap['table'] != null) {
                  updatedTables.add(updateMap['table'] as String);
                }
              } else {
                skipped++;
              }
            } catch (e) {
              skipped++;
              _log('   ⚠️ Lỗi áp dụng 1 cập nhật: $e');
            }
          }
          _log('✅ Đã ghi $applied bản ghi vào database local (bỏ qua/lọc $skipped).');
          if (applied > 0 && updatedTables.isNotEmpty) {
            if (!_syncEventController.isClosed) {
              _syncEventController.add(SyncEvent(updatedTables.toList()));
            }
          }
          return serverTimestamp;
        } else {
          _log('Không có cập nhật mới từ Server.');
        }
      }
    } on DioException catch (e) {
      _log('⚠️ Không thể kéo dữ liệu từ Server: ${e.message}');
    }
    return null;
  }

  /// Public wrapper to apply updates from offline sync channels (e.g. BLE P2P).
  Future<bool> applySyncUpdate(Map<String, dynamic> update, {bool force = false}) async {
    try {
      if (force) {
        return await _applyServerUpdate(update, {}, true, force: true);
      }
      final userId = await _getActiveUserId();
      final syncConfigRepo = SyncConfigRepository();
      final configs = await syncConfigRepo.getConfigsForUser(userId);
      final configMap = {for (var c in configs) c.moduleKey: c};
      return await _applyServerUpdate(update, configMap, true);
    } catch (e) {
      _log('⚠️ Lỗi áp dụng cập nhật P2P: $e');
      return false;
    }
  }

  /// Apply a single server update to the local database (upsert)
  Future<bool> _applyServerUpdate(
    Map<String, dynamic> update,
    Map<String, UserSyncConfig> configMap,
    bool isManual, {
    bool force = false,
  }) async {
    final table = update['table'] as String?;
    final operation = update['operation'] as String?;
    final rawData = update['data'];

    if (table == null || rawData == null) return false;

    // Filter incoming updates by module status
    if (!force) {
      final moduleKey = SyncConfigRepository.tableToModuleMap[table];
      if (moduleKey != null) {
        final config = configMap[moduleKey];
        if (config == null || !config.isEnabled) {
          return false;
        }
        if (!isManual && config.syncGranularity == 'manual') {
          return false;
        }
        if (config.syncGranularity == 'selective' && config.selectiveEntities != null) {
          try {
            final selective = List<String>.from(jsonDecode(config.selectiveEntities!));
            if (!selective.contains(table)) {
              return false;
            }
          } catch (_) {}
        }
      }
    }

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
      case 'projects':
        return _upsertProject(data);
      case 'tasks':
        return _upsertTask(data);
      case 'purchase_orders':
        return _upsertPurchaseOrder(data);
      case 'purchase_order_lines':
        return _upsertPurchaseOrderLine(data);
      case 'chat_conversations':
        return _upsertChatConversation(data);
      case 'chat_participants':
        return _upsertChatParticipant(data);
      case 'chat_messages':
        return _upsertChatMessage(data);
      case 'grow_rooms':
        return _upsertGrowRoom(data);
      case 'mushroom_jobs':
        return _upsertMushroomJob(data);
      case 'mushroom_job_safety_configs':
        return _upsertMushroomJobSafetyConfig(data);
      case 'mushroom_safety_checkin_logs':
        return _upsertMushroomSafetyCheckinLog(data);
      case 'mushroom_maintenance_tickets':
        return _upsertMushroomMaintenanceTicket(data);
      case 'mushroom_chat_messages':
        return _upsertMushroomChatMessage(data);
      case 'mushroom_room_crews':
        return _upsertMushroomRoomCrew(data);
      case 'mushroom_employees':
        return _upsertMushroomEmployee(data);
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

    final activeUserId = await _getActiveUserId();
    final ownerId = data['owner_id'] as String? ?? activeUserId;

    await _db.into(_db.leads).insertOnConflictUpdate(
      LeadsCompanion(
        id: Value(id),
        title: Value(data['title'] as String? ?? 'Untitled'),
        contactId: Value(data['contact_id'] as String?),
        status: Value(data['status'] as String? ?? 'new'),
        expectedRevenue: Value((data['expected_revenue'] as num?)?.toDouble() ?? 0.0),
        notes: Value(data['name'] as String?),
        source: Value(data['source'] as String? ?? 'direct'),
        ownerId: Value(ownerId),
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

    final activeUserId = await _getActiveUserId();
    final ownerId = data['owner_id'] as String? ?? activeUserId;

    await _db.into(_db.deals).insertOnConflictUpdate(
      DealsCompanion(
        id: Value(id),
        title: Value(data['title'] as String? ?? 'Untitled Deal'),
        leadId: Value(data['lead_id'] as String?),
        contactId: Value(data['contact_id'] as String? ?? ''),
        amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
        stage: Value(data['stage'] as String? ?? 'proposal'),
        source: Value(data['source'] as String? ?? 'direct'),
        ownerId: Value(ownerId),
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

  Future<bool> _upsertProject(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    String customFields = '{}';
    if (data['custom_fields'] != null) {
      customFields = data['custom_fields'] is String
          ? data['custom_fields']
          : jsonEncode(data['custom_fields']);
    }

    await _db.into(_db.projects).insertOnConflictUpdate(
      ProjectsCompanion(
        id: Value(id),
        name: Value(data['name'] as String? ?? 'Untitled Project'),
        description: Value(data['description'] as String?),
        status: Value(data['status'] as String? ?? 'active'),
        createdAt: data['created_at'] != null
            ? Value(DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now())
            : Value(DateTime.now()),
        customFields: Value(customFields),
      ),
    );
    return true;
  }

  Future<bool> _upsertTask(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    // Check if the record already exists to perform a delta update vs complete insert
    final existing = await (_db.select(_db.tasks)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      String? customFields;
      if (data['custom_fields'] != null) {
        customFields = data['custom_fields'] is String
            ? data['custom_fields'] as String
            : jsonEncode(data['custom_fields']);
      }

      await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(id))).write(
        TasksCompanion(
          projectId: data['project_id'] != null ? Value(data['project_id'] as String) : const Value.absent(),
          title: data['title'] != null ? Value(data['title'] as String) : const Value.absent(),
          description: data.containsKey('description') ? Value(data['description'] as String?) : const Value.absent(),
          status: data['status'] != null ? Value(data['status'] as String) : const Value.absent(),
          priority: data['priority'] != null ? Value(data['priority'] as String) : const Value.absent(),
          dueDate: data.containsKey('due_date')
              ? Value(data['due_date'] != null ? DateTime.tryParse(data['due_date'].toString()) : null)
              : const Value.absent(),
          createdAt: data['created_at'] != null
              ? Value(DateTime.tryParse(data['created_at'].toString()) ?? existing.createdAt)
              : const Value.absent(),
          customFields: customFields != null ? Value(customFields) : const Value.absent(),
        ),
      );
    } else {
      String customFields = '{}';
      if (data['custom_fields'] != null) {
        customFields = data['custom_fields'] is String
            ? data['custom_fields'] as String
            : jsonEncode(data['custom_fields']);
      }

      await _db.into(_db.tasks).insert(
        TasksCompanion.insert(
          id: id,
          projectId: data['project_id'] as String? ?? '',
          title: data['title'] as String? ?? 'Untitled Task',
          description: Value(data['description'] as String?),
          status: Value(data['status'] as String? ?? 'todo'),
          priority: Value(data['priority'] as String? ?? 'medium'),
          dueDate: Value(data['due_date'] != null ? DateTime.tryParse(data['due_date'].toString()) : null),
          createdAt: Value(data['created_at'] != null ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
          customFields: Value(customFields),
        ),
      );
    }

    // Sync task status changes to linked local MushroomJobs
    try {
      final status = data['status'] as String? ?? 'todo';
      final nextJobStatus = status == 'done' ? 'completed' : status;
      await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.linkedTaskId.equals(id))).write(
        MushroomJobsCompanion(
          status: Value(nextJobStatus),
          completedAt: status == 'done' ? Value(DateTime.now()) : const Value.absent(),
        ),
      );
    } catch (_) {}

    return true;
  }


  Future<bool> _upsertPurchaseOrder(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    String customFields = '{}';
    if (data['custom_fields'] != null) {
      customFields = data['custom_fields'] is String
          ? data['custom_fields']
          : jsonEncode(data['custom_fields']);
    }

    await _db.into(_db.purchaseOrders).insertOnConflictUpdate(
      PurchaseOrdersCompanion(
        id: Value(id),
        orderNumber: Value(data['order_number'] as String? ?? 'PO-${id.substring(0, 8)}'),
        partnerName: Value(data['partner_name'] as String? ?? 'Unknown'),
        orderDate: data['order_date'] != null
            ? Value(DateTime.tryParse(data['order_date'].toString()) ?? DateTime.now())
            : Value(DateTime.now()),
        totalAmount: Value((data['total_amount'] as num?)?.toDouble() ?? 0.0),
        status: Value(data['status'] as String? ?? 'draft'),
        createdAt: data['created_at'] != null
            ? Value(DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now())
            : Value(DateTime.now()),
        customFields: Value(customFields),
      ),
    );
    return true;
  }

  Future<bool> _upsertPurchaseOrderLine(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    final qty = (data['quantity'] as num?)?.toDouble() ?? 1.0;
    final price = (data['unit_price'] as num?)?.toDouble() ?? 0.0;

    await _db.into(_db.purchaseOrderLines).insertOnConflictUpdate(
      PurchaseOrderLinesCompanion(
        id: Value(id),
        purchaseOrderId: Value(data['purchase_order_id'] as String? ?? ''),
        productName: Value(data['product_name'] as String? ?? 'Unnamed Product'),
        quantity: Value(qty),
        unitPrice: Value(price),
        totalPrice: Value((data['total_price'] as num?)?.toDouble() ?? (qty * price)),
        createdAt: data['created_at'] != null
            ? Value(DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now())
            : Value(DateTime.now()),
      ),
    );
    return true;
  }

  Future<bool> _upsertChatConversation(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    await _db.into(_db.chatConversations).insertOnConflictUpdate(
      ChatConversationsCompanion(
        id: Value(id),
        type: Value(data['type'] as String? ?? 'direct'),
        recordType: Value(data['record_type'] as String?),
        recordId: Value(data['record_id'] as String?),
        createdBy: Value(data['created_by'] as String? ?? ''),
        createdAt: data['created_at'] != null
            ? Value(DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now())
            : Value(DateTime.now()),
        lastMessageAt: data['last_message_at'] != null
            ? Value(DateTime.tryParse(data['last_message_at'].toString()) ?? DateTime.now())
            : Value(DateTime.now()),
      ),
    );
    return true;
  }

  Future<bool> _upsertChatParticipant(Map<String, dynamic> data) async {
    final convoId = data['conversation_id'] as String?;
    final userId = data['user_id'] as String?;
    if (convoId == null || userId == null) return false;
    await _db.into(_db.chatParticipants).insertOnConflictUpdate(
      ChatParticipant(
        conversationId: convoId,
        userId: userId,
        joinedAt: data['joined_at'] != null
            ? DateTime.tryParse(data['joined_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        muted: data['muted'] as bool? ?? false,
      ),
    );
    return true;
  }

  Future<bool> _upsertChatMessage(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    
    final chatMsg = ChatMessage(
      id: id,
      conversationId: data['conversation_id'] as String? ?? '',
      senderId: data['sender_id'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      content: data['content'] is String ? data['content'] as String : jsonEncode(data['content'] ?? {}),
      sentAt: data['sent_at'] != null
          ? DateTime.tryParse(data['sent_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deliveredAt: data['delivered_at'] != null
          ? DateTime.tryParse(data['delivered_at'].toString())
          : null,
      readAt: data['read_at'] != null
          ? DateTime.tryParse(data['read_at'].toString())
          : null,
      isDeleted: data['is_deleted'] as bool? ?? false,
    );
    
    await _db.into(_db.chatMessages).insertOnConflictUpdate(chatMsg);
    return true;
  }

  /// Queue a local mutation to be synchronized later
  Future<void> queueMutation(String table, String operation, Map<String, dynamic> data) async {
    await _outbox.addMutation(table, operation, data);
    _log('📝 Đã lưu ngoại tuyến thay đổi: $table -> $operation');

    // Trigger instant BLE sync for any connected peers
    try {
      final bleDiscovery = BleDeviceDiscoveryService();
      final syncManager = BleSyncManager();
      final connectedIds = bleDiscovery.getConnectedDeviceIds();
      for (final deviceId in connectedIds) {
        final userId = bleDiscovery.getUserIdForDevice(deviceId);
        if (userId != null) {
          _log('🔗 Kích hoạt đồng bộ BLE cho $table -> $operation tới peer: $userId ($deviceId)');
          unawaited(syncManager.syncOutboxWithPeer(
            remoteDeviceId: deviceId,
            remoteUserId: userId,
            sendBleBytes: (_) {},
          ));
        }
      }
    } catch (e) {
      _log('⚠️ Lỗi kích hoạt đồng bộ BLE tức thời: $e');
    }
  }

  // ──────────────── UPSERT methods for Mushroom Farm module ────────────────

  Future<bool> _upsertGrowRoom(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    final existing = await (_db.select(_db.growRooms)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

    await _db.into(_db.growRooms).insertOnConflictUpdate(
      GrowRoom(
        id: id,
        name: data['name'] as String? ?? existing?.name ?? '',
        status: data['status'] as String? ?? existing?.status ?? 'idle',
        currentStage: data['current_stage'] as String? ?? existing?.currentStage ?? 'idle',
        dayInCycle: (data['day_in_cycle'] as num?)?.toInt() ?? existing?.dayInCycle ?? 1,
        targetYield: (data['targetYield'] as num?)?.toDouble() ?? existing?.targetYield ?? 0.0,
        pickedYield: (data['pickedYield'] as num?)?.toDouble() ?? existing?.pickedYield ?? 0.0,
        pickingPlanJson: data['pickingPlanJson'] as String? ?? existing?.pickingPlanJson,
        createdAt: data['created_at'] != null 
            ? DateTime.tryParse(data['created_at'].toString()) ?? existing?.createdAt ?? DateTime.now() 
            : existing?.createdAt ?? DateTime.now(),
        updatedAt: data['updated_at'] != null ? DateTime.tryParse(data['updated_at'].toString()) : DateTime.now(),
      ),
    );
    return true;
  }

  Future<bool> _upsertMushroomJob(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;

    // Check if the record already exists to perform a delta update vs complete insert
    final existing = await (_db.select(_db.mushroomJobs)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      dynamic getVal(String camel, String snake) {
        return data[camel] ?? data[snake];
      }
      bool hasKey(String camel, String snake) {
        return data.containsKey(camel) || data.containsKey(snake);
      }

      await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.id.equals(id))).write(
        MushroomJobsCompanion(
          roomId: hasKey('roomId', 'room_id') ? Value(getVal('roomId', 'room_id') as String) : const Value.absent(),
          jobType: hasKey('jobType', 'job_type') ? Value(getVal('jobType', 'job_type') as String) : const Value.absent(),
          name: data.containsKey('name') ? Value(data['name'] as String) : const Value.absent(),
          status: data.containsKey('status') ? Value(data['status'] as String) : const Value.absent(),
          assignee: data.containsKey('assignee') ? Value(data['assignee'] as String?) : const Value.absent(),
          planDetails: hasKey('planDetails', 'plan_details') ? Value(getVal('planDetails', 'plan_details') as String?) : const Value.absent(),
          prochlorazRate: hasKey('prochlorazRate', 'prochloraz_rate') ? Value(getVal('prochlorazRate', 'prochloraz_rate') as String?) : const Value.absent(),
          completedAt: hasKey('completedAt', 'completed_at')
              ? Value(getVal('completedAt', 'completed_at') != null ? DateTime.tryParse(getVal('completedAt', 'completed_at').toString()) : null)
              : const Value.absent(),
          linkedTaskId: hasKey('linkedTaskId', 'linked_task_id') ? Value(getVal('linkedTaskId', 'linked_task_id') as String?) : const Value.absent(),
          isSoloJob: hasKey('isSoloJob', 'is_solo_job') ? Value(getVal('isSoloJob', 'is_solo_job') as bool) : const Value.absent(),
          timeLimitMinutes: hasKey('timeLimitMinutes', 'time_limit_minutes')
              ? Value(getVal('timeLimitMinutes', 'time_limit_minutes') != null ? (getVal('timeLimitMinutes', 'time_limit_minutes') as num).toInt() : null)
              : const Value.absent(),
          startedAt: hasKey('startedAt', 'started_at')
              ? Value(getVal('startedAt', 'started_at') != null ? DateTime.tryParse(getVal('startedAt', 'started_at').toString()) : null)
              : const Value.absent(),
          alarmTriggered: hasKey('alarmTriggered', 'alarm_triggered') ? Value(getVal('alarmTriggered', 'alarm_triggered') as bool) : const Value.absent(),
          scheduledAt: hasKey('scheduledAt', 'scheduled_at')
              ? Value(getVal('scheduledAt', 'scheduled_at') != null ? DateTime.tryParse(getVal('scheduledAt', 'scheduled_at').toString()) : null)
              : const Value.absent(),
          priority: data.containsKey('priority') ? Value(data['priority'] as String) : const Value.absent(),
          coLevel: hasKey('co_level', 'coLevel')
              ? Value(getVal('coLevel', 'co_level') != null ? (getVal('coLevel', 'co_level') as num).toDouble() : null)
              : const Value.absent(),
          co2Level: hasKey('co2_level', 'co2Level')
              ? Value(getVal('co2Level', 'co2_level') != null ? (getVal('co2Level', 'co2_level') as num).toDouble() : null)
              : const Value.absent(),
          checkInTime: hasKey('check_in_time', 'checkInTime')
              ? Value(getVal('checkInTime', 'check_in_time') != null ? DateTime.tryParse(getVal('checkInTime', 'check_in_time').toString()) : null)
              : const Value.absent(),
          checkOutTime: hasKey('check_out_time', 'checkOutTime')
              ? Value(getVal('checkOutTime', 'check_out_time') != null ? DateTime.tryParse(getVal('checkOutTime', 'check_out_time').toString()) : null)
              : const Value.absent(),
          createdAt: hasKey('created_at', 'createdAt')
              ? Value(getVal('createdAt', 'created_at') != null ? DateTime.tryParse(getVal('createdAt', 'created_at').toString()) ?? existing.createdAt : existing.createdAt)
              : const Value.absent(),
          updatedAt: hasKey('updated_at', 'updatedAt')
              ? Value(getVal('updatedAt', 'updated_at') != null ? DateTime.tryParse(getVal('updatedAt', 'updated_at').toString()) : null)
              : const Value.absent(),
        ),
      );
    } else {
      await _db.into(_db.mushroomJobs).insert(
        MushroomJob(
          id: id,
          roomId: (data['roomId'] ?? data['room_id']) as String? ?? '',
          jobType: (data['jobType'] ?? data['job_type']) as String? ?? '',
          name: data['name'] as String? ?? '',
          status: data['status'] as String? ?? 'pending',
          assignee: data['assignee'] as String?,
          planDetails: (data['planDetails'] ?? data['plan_details']) as String?,
          prochlorazRate: (data['prochlorazRate'] ?? data['prochloraz_rate']) as String?,
          completedAt: (data['completedAt'] ?? data['completed_at']) != null ? DateTime.tryParse((data['completedAt'] ?? data['completed_at']).toString()) : null,
          linkedTaskId: (data['linkedTaskId'] ?? data['linked_task_id']) as String?,
          isSoloJob: (data['isSoloJob'] ?? data['is_solo_job']) as bool? ?? false,
          timeLimitMinutes: (data['timeLimitMinutes'] ?? data['time_limit_minutes']) != null ? ((data['timeLimitMinutes'] ?? data['time_limit_minutes']) as num).toInt() : null,
          startedAt: (data['startedAt'] ?? data['started_at']) != null ? DateTime.tryParse((data['startedAt'] ?? data['started_at']).toString()) : null,
          alarmTriggered: (data['alarmTriggered'] ?? data['alarm_triggered']) as bool? ?? false,
          scheduledAt: (data['scheduledAt'] ?? data['scheduled_at']) != null ? DateTime.tryParse((data['scheduledAt'] ?? data['scheduled_at']).toString()) : null,
          priority: data['priority'] as String? ?? 'normal',
          coLevel: (data['co_level'] ?? data['coLevel']) != null ? ((data['co_level'] ?? data['coLevel']) as num).toDouble() : null,
          co2Level: (data['co2_level'] ?? data['co2Level']) != null ? ((data['co2_level'] ?? data['co2Level']) as num).toDouble() : null,
          checkInTime: (data['check_in_time'] ?? data['checkInTime']) != null ? DateTime.tryParse((data['check_in_time'] ?? data['checkInTime']).toString()) : null,
          checkOutTime: (data['check_out_time'] ?? data['checkOutTime']) != null ? DateTime.tryParse((data['check_out_time'] ?? data['checkOutTime']).toString()) : null,
          createdAt: (data['created_at'] ?? data['createdAt']) != null ? DateTime.tryParse((data['created_at'] ?? data['createdAt']).toString()) ?? DateTime.now() : DateTime.now(),
          updatedAt: (data['updated_at'] ?? data['updatedAt']) != null ? DateTime.tryParse((data['updated_at'] ?? data['updatedAt']).toString()) : null,
        ),
      );
    }

    // Sync status to local Tasks if linked
    try {
      final status = data['status'] as String? ?? 'pending';
      final taskStatus = status == 'completed' ? 'done' : status;
      if (data['linkedTaskId'] != null && (data['linkedTaskId'] as String).isNotEmpty) {
        await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(data['linkedTaskId'] as String))).write(
          TasksCompanion(
            status: Value(taskStatus),
          ),
        );
      }
    } catch (_) {}

    return true;
  }


  Future<bool> _upsertMushroomJobSafetyConfig(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    await _db.into(_db.mushroomJobSafetyConfigs).insertOnConflictUpdate(
      MushroomJobSafetyConfig(
        id: id,
        jobId: data['jobId'] as String? ?? '',
        checkInIntervalMinutes: (data['checkInIntervalMinutes'] as num?)?.toInt() ?? 30,
        gracePeriodMinutes: (data['gracePeriodMinutes'] as num?)?.toInt() ?? 5,
        escalationTarget: data['escalationTarget'] as String? ?? 'supervisor',
        autoStartOnJobBegin: data['autoStartOnJobBegin'] as bool? ?? true,
        alarmType: data['alarmType'] as String? ?? 'push_inapp',
        createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      ),
    );
    return true;
  }

  Future<bool> _upsertMushroomSafetyCheckinLog(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    await _db.into(_db.mushroomSafetyCheckinLogs).insertOnConflictUpdate(
      MushroomSafetyCheckinLog(
        id: id,
        jobId: data['jobId'] as String? ?? '',
        workerId: data['workerId'] as String? ?? '',
        eventType: data['eventType'] as String? ?? 'safe',
        timestamp: data['timestamp'] != null ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now() : DateTime.now(),
        gpsLatitude: (data['gpsLatitude'] as num?)?.toDouble(),
        gpsLongitude: (data['gpsLongitude'] as num?)?.toDouble(),
        responseTimeSeconds: (data['responseTimeSeconds'] as num?)?.toInt(),
        notes: data['notes'] as String?,
      ),
    );
    return true;
  }

  Future<bool> _upsertMushroomMaintenanceTicket(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    await _db.into(_db.mushroomMaintenanceTickets).insertOnConflictUpdate(
      MushroomMaintenanceTicket(
        id: id,
        title: data['title'] as String? ?? '',
        plant: data['plant'] as String? ?? '',
        room: data['room'] as String? ?? '',
        assignee: data['assignee'] as String? ?? '',
        priority: data['priority'] as String? ?? '',
        status: data['status'] as String? ?? 'todo',
        notes: data['notes'] as String?,
      ),
    );
    return true;
  }

  Future<bool> _upsertMushroomChatMessage(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    await _db.into(_db.mushroomChatMessages).insertOnConflictUpdate(
      MushroomChatMessage(
        id: id,
        sender: data['sender'] as String? ?? '',
        contact: data['contact'] as String? ?? '',
        textContent: data['textContent'] as String? ?? '',
        timeString: data['timeString'] as String? ?? '',
        role: data['role'] as String? ?? '',
        createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      ),
    );
    return true;
  }

  Future<bool> _upsertMushroomRoomCrew(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    await _db.into(_db.mushroomRoomCrews).insertOnConflictUpdate(
      MushroomRoomCrew(
        id: id,
        roomName: data['roomName'] as String? ?? '',
        empName: data['empName'] as String? ?? '',
        empId: data['empId'] as String? ?? '',
      ),
    );
    return true;
  }

  Future<bool> _upsertMushroomEmployee(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) return false;
    await _db.into(_db.mushroomEmployees).insertOnConflictUpdate(
      MushroomEmployee(
        id: id,
        name: data['name'] as String? ?? '',
        role: data['role'] as String? ?? '',
        department: data['department'] as String?,
        createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      ),
    );
    return true;
  }
}


