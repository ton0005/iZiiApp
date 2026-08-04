// lib/modules/mushrooms/services/grow_room_service.dart

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/core/sync/sync_service.dart';
import 'package:izii_app/modules/mushrooms/repository.dart';
import 'employee_service.dart';

abstract class GrowRoomService {
  /// Stream phát ra danh sách tất cả các phòng trồng sắp xếp theo tên.
  Stream<List<Map<String, dynamic>>> watchRooms();

  /// Stream theo dõi thông tin chi tiết của một phòng trồng cụ thể theo ID.
  Stream<Map<String, dynamic>?> watchRoomById(String roomId);

  /// Stream theo dõi danh sách các phòng thuộc một nhà máy cụ thể (Plant M1 hoặc M2).
  Stream<List<Map<String, dynamic>>> watchRoomsByPlant(String plantName);

  /// Lấy danh sách tất cả các phòng trồng tại thời điểm hiện tại.
  Future<List<Map<String, dynamic>>> getRooms();

  /// Lấy thông tin phòng trồng cụ thể theo ID.
  Future<Map<String, dynamic>?> getRoomById(String roomId);

  /// Thêm một phòng trồng mới.
  /// Thực hiện validate chống trùng tên trong cùng một nhà máy (Plant).
  Future<void> addRoom({required String name, required String plantName});

  /// Cập nhật giai đoạn hiện tại (Stage) của phòng trồng (e.g. filling, casing, watering, alone_worker).
  Future<void> updateRoomStage(String roomId, String stage);

  /// Đưa phòng về trạng thái trống (Idle), hoàn thành toàn bộ công việc đang chạy.
  Future<void> resetRoom(String roomId);

  /// Bắt đầu chu kỳ nuôi trồng mới (8 bước pipeline)
  Future<void> startNewCycle(String roomId, {String? wateringPlan, String? prochlorazRate});
}

class GrowRoomServiceImpl implements GrowRoomService {
  final AppDatabase _db;
  final EmployeeService _employeeService;
  final MushroomsRepository _repository;

  GrowRoomServiceImpl({AppDatabase? db, EmployeeService? employeeService, MushroomsRepository? repository})
      : _db = db ?? AppDatabase(),
        _employeeService = employeeService ?? EmployeeServiceImpl(),
        _repository = repository ?? MushroomsRepository(db ?? AppDatabase());

  Map<String, dynamic> _mapRoom(GrowRoom r) {
    return <String, dynamic>{
      'id': r.id,
      'name': r.name,
      'status': r.status,
      'current_stage': r.currentStage,
      'day_in_cycle': r.dayInCycle,
      'target_yield': r.targetYield,
      'picked_yield': r.pickedYield,
      'picking_plan_json': r.pickingPlanJson,
      'created_at': r.createdAt.toIso8601String(),
      'updated_at': r.updatedAt?.toIso8601String(),
    };
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRooms() {
    return (_db.select(_db.growRooms)..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch()
        .map((list) => list.map(_mapRoom).toList());
  }

  @override
  Stream<Map<String, dynamic>?> watchRoomById(String roomId) {
    return (_db.select(_db.growRooms)..where((tbl) => tbl.id.equals(roomId)))
        .watchSingleOrNull()
        .map((r) => r != null ? _mapRoom(r) : null);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRoomsByPlant(String plantName) {
    return watchRooms().map((list) {
      return list.where((room) {
        final name = room['name'] as String;
        final isM2 = _isRoomInPlantM2(name);
        if (plantName == 'Plant M2') return isM2;
        return !isM2;
      }).toList();
    });
  }

  bool _isRoomInPlantM2(String roomName) {
    final numMatch = RegExp(r'\d+').firstMatch(roomName);
    if (numMatch != null) {
      final roomNum = int.tryParse(numMatch.group(0)!);
      if (roomNum != null && roomNum >= 33) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> getRooms() async {
    final list = await (_db.select(_db.growRooms)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
    return list.map(_mapRoom).toList();
  }

  @override
  Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    final r = await (_db.select(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).getSingleOrNull();
    return r != null ? _mapRoom(r) : null;
  }

  @override
  Future<void> addRoom({required String name, required String plantName}) async {
    final currentEmpId = await _employeeService.getCurrentEmployeeId();
    if (currentEmpId == null) {
      throw Exception('Chưa đăng nhập nhân viên.');
    }
    final hasPerm = await _employeeService.hasPermission(currentEmpId, 'addRoom');
    if (!hasPerm) {
      throw Exception('Nhân viên không có quyền thêm phòng trồng.');
    }

    final deterministicId = name.toLowerCase().replaceAll(' ', '_');
    
    // Check duplication by ID and name
    final existing = await getRoomById(deterministicId);
    if (existing != null) {
      throw Exception('Phòng trồng đã tồn tại.');
    }

    final allRooms = await getRooms();
    final duplicateName = allRooms.any((r) => (r['name'] as String).trim().toLowerCase() == name.trim().toLowerCase());
    if (duplicateName) {
      throw Exception('Phòng trồng với tên/số này đã tồn tại.');
    }

    await _db.into(_db.growRooms).insertOnConflictUpdate(GrowRoom(
      id: deterministicId,
      name: name,
      status: 'idle',
      currentStage: 'idle',
      dayInCycle: 1,
      targetYield: 0.0,
      pickedYield: 0.0,
      createdAt: DateTime.now(),
    ));

    await SyncService().queueMutation('grow_rooms', 'insert', {
      'id': deterministicId,
      'name': name,
      'status': 'idle',
      'current_stage': 'idle',
      'day_in_cycle': 1,
      'target_yield': 0.0,
      'picked_yield': 0.0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateRoomStage(String roomId, String stage) async {
    await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
      GrowRoomsCompanion(
        currentStage: Value(stage),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      'current_stage': stage,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> resetRoom(String roomId) async {
    final currentEmpId = await _employeeService.getCurrentEmployeeId();
    if (currentEmpId == null) {
      throw Exception('Chưa đăng nhập nhân viên.');
    }
    await _repository.resetRoom(roomId);
  }

  @override
  Future<void> startNewCycle(String roomId, {String? wateringPlan, String? prochlorazRate}) async {
    final currentEmpId = await _employeeService.getCurrentEmployeeId();
    if (currentEmpId == null) {
      throw Exception('Chưa đăng nhập nhân viên.');
    }
    final hasPerm = await _employeeService.hasPermission(currentEmpId, 'createJob');
    if (!hasPerm) {
      throw Exception('Nhân viên không có quyền khởi chạy chu kỳ nuôi trồng.');
    }
    await _repository.startNewCycle(roomId, wateringPlan: wateringPlan, prochlorazRate: prochlorazRate);
  }
}
