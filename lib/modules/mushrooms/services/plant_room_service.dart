// lib/modules/mushrooms/services/plant_room_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:izii_app/core/database/app_database.dart';

class PlantModel {
  final String code; // e.g. 'M1', 'M2', 'M3'
  final String name; // e.g. 'Plant M1', 'Plant M2'
  final String description;
  final bool isActive;
  final int sortOrder;
  final String colorHex;
  final DateTime createdAt;

  PlantModel({
    required this.code,
    required this.name,
    this.description = '',
    this.isActive = true,
    this.sortOrder = 0,
    this.colorHex = '#2D6A4F',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'description': description,
        'is_active': isActive,
        'sort_order': sortOrder,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };

  factory PlantModel.fromJson(Map<String, dynamic> json) => PlantModel(
        code: (json['code'] as String? ?? 'M1').toUpperCase().trim(),
        name: json['name'] as String? ?? 'Plant ${json['code'] ?? 'M1'}',
        description: json['description'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        sortOrder: json['sort_order'] as int? ?? 0,
        colorHex: json['color_hex'] as String? ?? '#2D6A4F',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
      );

  PlantModel copyWith({
    String? code,
    String? name,
    String? description,
    bool? isActive,
    int? sortOrder,
    String? colorHex,
  }) {
    return PlantModel(
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt,
    );
  }
}

class PlantRoomService {
  static final PlantRoomService _instance = PlantRoomService._internal();
  factory PlantRoomService([AppDatabase? db]) {
    if (db != null) {
      _instance._db = db;
    }
    return _instance;
  }

  PlantRoomService._internal() : _db = AppDatabase();

  AppDatabase _db;

  static const String _keyPlantsCatalog = 'mushrooms_plants_catalog';
  static const String _keyRoomAssignments = 'mushrooms_room_plant_assignments';

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<void> get watchChanges => _changesController.stream;

  // In-memory cache for fast sync resolution
  Map<String, String>? _cachedAssignments;
  List<PlantModel>? _cachedPlants;

  /// Default Monarto Plants
  static List<PlantModel> get defaultPlants => [
        PlantModel(
          code: 'M1',
          name: 'Plant M1',
          description: 'Monarto Plant 1 (Phòng 1-32, 6A, 6B, 22A)',
          isActive: true,
          sortOrder: 1,
          colorHex: '#2D6A4F',
        ),
        PlantModel(
          code: 'M2',
          name: 'Plant M2',
          description: 'Monarto Plant 2 (Phòng 33-66, 52A)',
          isActive: true,
          sortOrder: 2,
          colorHex: '#7C3AED',
        ),
      ];

  /// Sắp xếp tên phòng theo thứ tự số tự nhiên và hậu tố: 1, 2, 3, 4, 5, 6, 6A, 6B, 7, 8, ..., 22, 22A, 23, ..., 52, 52A, 53, ...
  static int compareRoomNames(String a, String b) {
    if (a == b) return 0;
    final regExp = RegExp(r'(\d+)\s*([A-Za-z]*)');
    final matchA = regExp.firstMatch(a);
    final matchB = regExp.firstMatch(b);

    if (matchA != null && matchB != null) {
      final numA = int.tryParse(matchA.group(1) ?? '') ?? 0;
      final numB = int.tryParse(matchB.group(1) ?? '') ?? 0;
      if (numA != numB) {
        return numA.compareTo(numB);
      }
      final suffixA = (matchA.group(2) ?? '').trim().toUpperCase();
      final suffixB = (matchB.group(2) ?? '').trim().toUpperCase();
      if (suffixA != suffixB) {
        return suffixA.compareTo(suffixB);
      }
    } else if (matchA != null) {
      return -1;
    } else if (matchB != null) {
      return 1;
    }

    return a.compareTo(b);
  }

  /// Giải quyết nhà máy mặc định dựa theo số phòng (Monarto Standard)
  /// M1: Phòng 1-32, 6A, 6B, 22A
  /// M2: Phòng 33-66, 52A
  static String resolveDefaultPlantCode(String roomName) {
    final clean = roomName.replaceAll('Room ', '').trim();
    if (clean == '6A' || clean == '6B' || clean == '22A') {
      return 'M1';
    }
    final regExp = RegExp(r'(\d+)');
    final match = regExp.firstMatch(roomName);
    if (match != null) {
      final num = int.tryParse(match.group(1)!);
      if (num != null && num >= 33) {
        return 'M2';
      }
    }
    return 'M1';
  }

  // --- Plant Catalog Management (CRUD) ---

  Future<List<PlantModel>> getPlants() async {
    if (_cachedPlants != null) {
      return List<PlantModel>.from(_cachedPlants!);
    }

    try {
      final row = await (_db.select(_db.appSettings)
            ..where((tbl) => tbl.key.equals(_keyPlantsCatalog)))
          .getSingleOrNull();

      if (row == null || row.value.trim().isEmpty) {
        final initial = defaultPlants;
        await _savePlantsList(initial);
        _cachedPlants = initial;
        return List<PlantModel>.from(initial);
      }

      final dynamic decoded = jsonDecode(row.value);
      if (decoded is List) {
        final list = decoded
            .map((item) => PlantModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _cachedPlants = list;
        return list;
      }
    } catch (_) {}

    _cachedPlants = defaultPlants;
    return List<PlantModel>.from(defaultPlants);
  }

  Future<void> _savePlantsList(List<PlantModel> plants) async {
    final jsonStr = jsonEncode(plants.map((p) => p.toJson()).toList());
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSetting(key: _keyPlantsCatalog, value: jsonStr),
        );
    _cachedPlants = List<PlantModel>.from(plants);
    _changesController.add(null);
  }

  Future<void> savePlant(PlantModel plant) async {
    final list = await getPlants();
    final index = list.indexWhere(
        (p) => p.code.toUpperCase() == plant.code.toUpperCase());

    if (index >= 0) {
      list[index] = plant;
    } else {
      list.add(plant);
    }
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _savePlantsList(list);
  }

  Future<void> deletePlant(String code) async {
    final cleanCode = code.toUpperCase().trim();
    final list = await getPlants();
    list.removeWhere((p) => p.code == cleanCode);
    await _savePlantsList(list);

    // Xóa các phân bổ phòng trỏ tới plant đã xóa
    final assignments = await getRoomAssignments();
    var hasChange = false;
    assignments.removeWhere((roomId, pCode) {
      if (pCode == cleanCode) {
        hasChange = true;
        return true;
      }
      return false;
    });

    if (hasChange) {
      await _saveAssignmentsMap(assignments);
    }
  }

  // --- Room to Plant Assignment Management ---

  Future<Map<String, String>> getRoomAssignments() async {
    if (_cachedAssignments != null) {
      return Map<String, String>.from(_cachedAssignments!);
    }

    try {
      final row = await (_db.select(_db.appSettings)
            ..where((tbl) => tbl.key.equals(_keyRoomAssignments)))
          .getSingleOrNull();

      if (row != null && row.value.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(row.value);
        if (decoded is Map) {
          final map = <String, String>{};
          decoded.forEach((k, v) {
            map[k.toString()] = v.toString().toUpperCase();
          });
          _cachedAssignments = map;
          return map;
        }
      }
    } catch (_) {}

    _cachedAssignments = <String, String>{};
    return <String, String>{};
  }

  Future<void> _saveAssignmentsMap(Map<String, String> map) async {
    final jsonStr = jsonEncode(map);
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSetting(key: _keyRoomAssignments, value: jsonStr),
        );
    _cachedAssignments = Map<String, String>.from(map);
    _changesController.add(null);
  }

  /// Lấy mã nhà máy cho một phòng cụ thể (ví dụ: 'M1' hoặc 'M2').
  /// Tự động tra cứu cấu hình tùy chỉnh trước, nếu chưa có thì áp dụng quy chuẩn Monarto.
  String getPlantForRoomSync({required String roomId, required String roomName}) {
    if (_cachedAssignments != null) {
      final byId = _cachedAssignments![roomId];
      if (byId != null && byId.isNotEmpty) return byId;

      final byName = _cachedAssignments![roomName];
      if (byName != null && byName.isNotEmpty) return byName;
    }

    return resolveDefaultPlantCode(roomName);
  }

  /// Phiên bản bất đồng bộ đảm bảo cache được tải
  Future<String> getPlantForRoom(
      {required String roomId, required String roomName}) async {
    if (_cachedAssignments == null) {
      await getRoomAssignments();
    }
    return getPlantForRoomSync(roomId: roomId, roomName: roomName);
  }

  /// Gán phòng vào một nhà máy cụ thể
  Future<void> assignRoomToPlant({
    required String roomId,
    required String plantCode,
    String? roomName,
  }) async {
    final cleanPlant = plantCode.toUpperCase().trim();
    final assignments = await getRoomAssignments();
    assignments[roomId] = cleanPlant;
    if (roomName != null && roomName.trim().isNotEmpty) {
      assignments[roomName.trim()] = cleanPlant;
    }
    await _saveAssignmentsMap(assignments);
  }

  /// Gán hàng loạt phòng vào một nhà máy
  Future<void> batchAssignRooms(List<String> roomIds, String plantCode) async {
    final cleanPlant = plantCode.toUpperCase().trim();
    final assignments = await getRoomAssignments();
    for (final id in roomIds) {
      assignments[id] = cleanPlant;
    }
    await _saveAssignmentsMap(assignments);
  }
}
