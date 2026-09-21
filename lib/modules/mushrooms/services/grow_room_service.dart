// lib/modules/mushrooms/services/grow_room_service.dart

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/core/sync/sync_service.dart';
import 'package:izii_app/modules/mushrooms/repository.dart';
import 'employee_service.dart';
import 'plant_room_service.dart';

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
  /// Thực hiện validate chống trùng tên và gán nhà máy (Plant).
  Future<void> addRoom({
    required String name,
    required String plantName,
    double targetYield = 0.0,
  });

  /// Chỉnh sửa thông tin phòng trồng (Tên, Nhà máy, Giai đoạn, Năng suất, v.v.).
  Future<void> updateRoom({
    required String roomId,
    required String name,
    required String plantName,
    String? status,
    String? currentStage,
    double? targetYield,
    int? dayInCycle,
  });

  /// Đổi nhanh nhà máy của phòng trồng (ví dụ: chuyển sang M1 hoặc M2).
  Future<void> reassignRoomPlant(String roomId, String newPlantCode);

  /// Xóa một phòng trồng khỏi hệ thống.
  Future<void> deleteRoom(String roomId);

  /// Cập nhật giai đoạn hiện tại (Stage) của phòng trồng (e.g. filling, casing, watering, alone_worker).
  Future<void> updateRoomStage(String roomId, String stage);

  /// Đưa phòng về trạng thái trống (Idle), hoàn thành toàn bộ công việc đang chạy.
  Future<void> resetRoom(String roomId);

  /// Bắt đầu chu kỳ nuôi trồng mới (8 bước pipeline)
  Future<void> startNewCycle(String roomId,
      {String? wateringPlan, String? prochlorazRate});
}

class GrowRoomServiceImpl implements GrowRoomService {
  final AppDatabase _db;
  final EmployeeService _employeeService;
  final MushroomsRepository _repository;
  final PlantRoomService _plantRoomService;

  GrowRoomServiceImpl({
    AppDatabase? db,
    EmployeeService? employeeService,
    MushroomsRepository? repository,
    PlantRoomService? plantRoomService,
  })  : _db = db ?? AppDatabase(),
        _employeeService = employeeService ?? EmployeeServiceImpl(),
        _repository = repository ?? MushroomsRepository(db ?? AppDatabase()),
        _plantRoomService = plantRoomService ?? PlantRoomService();

  Map<String, dynamic> _mapRoom(GrowRoom r) {
    final plantCode =
        _plantRoomService.getPlantForRoomSync(roomId: r.id, roomName: r.name);
    return <String, dynamic>{
      'id': r.id,
      'name': r.name,
      'plant': plantCode,
      'plant_name': 'Plant $plantCode',
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
    return _db.select(_db.growRooms)
        .watch()
        .map((list) {
          final mapped = list.map(_mapRoom).toList();
          mapped.sort((a, b) => PlantRoomService.compareRoomNames(
              a['name'] as String? ?? '', b['name'] as String? ?? ''));
          return mapped;
        });
  }

  @override
  Stream<Map<String, dynamic>?> watchRoomById(String roomId) {
    return (_db.select(_db.growRooms)..where((tbl) => tbl.id.equals(roomId)))
        .watchSingleOrNull()
        .map((r) => r != null ? _mapRoom(r) : null);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRoomsByPlant(String plantName) {
    final targetCode =
        plantName.replaceAll('Plant ', '').trim().toUpperCase();

    return watchRooms().map((list) {
      return list.where((room) {
        final id = room['id'] as String? ?? '';
        final name = room['name'] as String? ?? '';
        final pCode = _plantRoomService
            .getPlantForRoomSync(roomId: id, roomName: name)
            .toUpperCase();
        return pCode == targetCode;
      }).toList();
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getRooms() async {
    final list = await _db.select(_db.growRooms).get();
    final mapped = list.map(_mapRoom).toList();
    mapped.sort((a, b) => PlantRoomService.compareRoomNames(
        a['name'] as String? ?? '', b['name'] as String? ?? ''));
    return mapped;
  }

  @override
  Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    final r = await (_db.select(_db.growRooms)
          ..where((tbl) => tbl.id.equals(roomId)))
        .getSingleOrNull();
    return r != null ? _mapRoom(r) : null;
  }

  @override
  Future<void> addRoom({
    required String name,
    required String plantName,
    double targetYield = 0.0,
  }) async {
    final currentEmpId =
        await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm =
        await _employeeService.hasPermission(currentEmpId, 'addRoom');
    if (!hasPerm) {
      throw Exception('Không có quyền thêm phòng trồng.');
    }

    final deterministicId = name.toLowerCase().replaceAll(' ', '_');

    // Check duplication by ID and name
    final existing = await getRoomById(deterministicId);
    if (existing != null) {
      throw Exception('Phòng đã tồn tại trong hệ thống.');
    }

    final allRooms = await getRooms();
    final duplicateName = allRooms.any((r) =>
        (r['name'] as String).trim().toLowerCase() ==
        name.trim().toLowerCase());
    if (duplicateName) {
      throw Exception('Tên phòng này đã tồn tại.');
    }

    final cleanPlant =
        plantName.replaceAll('Plant ', '').trim().toUpperCase();

    await _db.into(_db.growRooms).insertOnConflictUpdate(GrowRoom(
          id: deterministicId,
          name: name,
          status: 'idle',
          currentStage: 'idle',
          dayInCycle: 1,
          targetYield: targetYield,
          pickedYield: 0.0,
          createdAt: DateTime.now(),
        ));

    await _plantRoomService.assignRoomToPlant(
      roomId: deterministicId,
      plantCode: cleanPlant,
      roomName: name,
    );

    await SyncService().queueMutation('grow_rooms', 'insert', {
      'id': deterministicId,
      'name': name,
      'plant': cleanPlant,
      'status': 'idle',
      'current_stage': 'idle',
      'day_in_cycle': 1,
      'target_yield': targetYield,
      'picked_yield': 0.0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateRoom({
    required String roomId,
    required String name,
    required String plantName,
    String? status,
    String? currentStage,
    double? targetYield,
    int? dayInCycle,
  }) async {
    final currentEmpId =
        await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm =
        await _employeeService.hasPermission(currentEmpId, 'addRoom');
    if (!hasPerm) {
      throw Exception('Không có quyền chỉnh sửa phòng trồng.');
    }

    final cleanPlant =
        plantName.replaceAll('Plant ', '').trim().toUpperCase();

    await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId)))
        .write(GrowRoomsCompanion(
      name: Value(name),
      updatedAt: Value(DateTime.now()),
      status: status != null ? Value(status) : const Value.absent(),
      currentStage:
          currentStage != null ? Value(currentStage) : const Value.absent(),
      targetYield:
          targetYield != null ? Value(targetYield) : const Value.absent(),
      dayInCycle:
          dayInCycle != null ? Value(dayInCycle) : const Value.absent(),
    ));

    await _plantRoomService.assignRoomToPlant(
      roomId: roomId,
      plantCode: cleanPlant,
      roomName: name,
    );

    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      'name': name,
      'plant': cleanPlant,
      if (status != null) 'status': status,
      if (currentStage != null) 'current_stage': currentStage,
      if (targetYield != null) 'target_yield': targetYield,
      if (dayInCycle != null) 'day_in_cycle': dayInCycle,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> reassignRoomPlant(String roomId, String newPlantCode) async {
    final room = await getRoomById(roomId);
    if (room == null) return;
    final name = room['name'] as String;
    final cleanPlant =
        newPlantCode.replaceAll('Plant ', '').trim().toUpperCase();

    await _plantRoomService.assignRoomToPlant(
      roomId: roomId,
      plantCode: cleanPlant,
      roomName: name,
    );

    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      'name': name,
      'plant': cleanPlant,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    final currentEmpId =
        await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm =
        await _employeeService.hasPermission(currentEmpId, 'addRoom');
    if (!hasPerm) {
      throw Exception('Không có quyền xóa phòng trồng.');
    }

    // Check if there are active jobs in this room
    final activeJobs = await (_db.select(_db.mushroomJobs)
          ..where((tbl) =>
              tbl.roomId.equals(roomId) & tbl.status.equals('in_progress')))
        .get();
    if (activeJobs.isNotEmpty) {
      throw Exception(
          'Không thể xóa phòng đang có ${activeJobs.length} công việc đang thực hiện.');
    }

    await (_db.delete(_db.growRooms)..where((tbl) => tbl.id.equals(roomId)))
        .go();

    await SyncService().queueMutation('grow_rooms', 'delete', {
      'id': roomId,
    });
  }

  @override
  Future<void> updateRoomStage(String roomId, String stage) async {
    await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId)))
        .write(
      GrowRoomsCompanion(
        currentStage: Value(stage),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final room = await getRoomById(roomId);
    final roomName = (room?['name'] as String? ?? '').trim();

    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      if (roomName.isNotEmpty) 'name': roomName,
      'current_stage': stage,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> resetRoom(String roomId) async {
    final currentEmpId =
        await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm =
        await _employeeService.hasPermission(currentEmpId, 'addRoom');
    if (!hasPerm) {
      throw Exception('Nhân viên không có quyền reset phòng.');
    }
    await _repository.resetRoom(roomId);
  }

  @override
  Future<void> startNewCycle(String roomId,
      {String? wateringPlan, String? prochlorazRate}) async {
    final currentEmpId =
        await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm =
        await _employeeService.hasPermission(currentEmpId, 'createJob');
    if (!hasPerm) {
      throw Exception(
          'Can not start new cycle: employee does not have permission.');
    }
    await _repository.startNewCycle(roomId,
        wateringPlan: wateringPlan, prochlorazRate: prochlorazRate);
  }
}
