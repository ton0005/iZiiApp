import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:izii_app/core/sync/sync_service.dart';
import 'package:cryptography/cryptography.dart';
import '../../core/database/app_database.dart';
import 'services/employee_service.dart';

class MushroomsRepository {
  final AppDatabase _db;

  MushroomsRepository([AppDatabase? database])
      : _db = database ?? AppDatabase();

  // === SEEDING ===

  Future<void> seedRoomsIfEmpty() async {
    try {
      final allRoomsToSeed = [
        // Plant M1
        'Room 1', 'Room 2', 'Room 3', 'Room 4', 'Room 5', 'Room 6', 'Room 6A', 'Room 6B',
        'Room 7', 'Room 8', 'Room 9', 'Room 10', 'Room 11', 'Room 12', 'Room 13', 'Room 14',
        'Room 15', 'Room 16', 'Room 17', 'Room 18', 'Room 19', 'Room 20', 'Room 21', 'Room 22',
        'Room 22A', 'Room 23', 'Room 24', 'Room 25', 'Room 26', 'Room 27', 'Room 28', 'Room 29',
        'Room 30', 'Room 31', 'Room 32',
        // Plant M2
        'Room 33', 'Room 34', 'Room 35', 'Room 36', 'Room 37', 'Room 38', 'Room 39', 'Room 40',
        'Room 41', 'Room 42', 'Room 43', 'Room 44', 'Room 45', 'Room 46', 'Room 47', 'Room 48',
        'Room 49', 'Room 50', 'Room 51', 'Room 52', 'Room 52A', 'Room 53', 'Room 54', 'Room 55',
        'Room 56', 'Room 57', 'Room 58', 'Room 59', 'Room 60', 'Room 61', 'Room 62', 'Room 63',
        'Room 64', 'Room 65', 'Room 66'
      ];

      // 1. Migrate any existing default rooms with random UUIDs to deterministic IDs
      for (final r in allRoomsToSeed) {
        final deterministicId = r.toLowerCase().replaceAll(' ', '_');
        final matchingWrongId = await (_db.select(_db.growRooms)
              ..where((tbl) => tbl.name.equals(r) & tbl.id.equals(deterministicId).not()))
            .get();
        if (matchingWrongId.isNotEmpty) {
          for (final oldRoom in matchingWrongId) {
            await (_db.delete(_db.growRooms)..where((tbl) => tbl.id.equals(oldRoom.id))).go();
            await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.roomId.equals(oldRoom.id))).write(
              MushroomJobsCompanion(roomId: Value(deterministicId)),
            );
          }
        }
      }

      // 2. Seed rooms if not present
      final existingRooms = await _db.select(_db.growRooms).get();
      final existingIds = existingRooms.map((r) => r.id).toSet();

      for (final r in allRoomsToSeed) {
        final deterministicId = r.toLowerCase().replaceAll(' ', '_');
        if (!existingIds.contains(deterministicId)) {
          await _db.into(_db.growRooms).insertOnConflictUpdate(GrowRoom(
            id: deterministicId,
            name: r,
            status: 'idle',
            currentStage: 'idle',
            dayInCycle: 1,
            targetYield: 0.0,
            pickedYield: 0.0,
            createdAt: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      print('Error seeding rooms: $e');
    }
  }

  Future<void> seedEmployeesIfEmpty() async {
    try {
      final existing = await _db.select(_db.mushroomEmployees).get();
      if (existing.isEmpty) {
        await EmployeeServiceImpl().seedDefaultData();
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    await seedEmployeesIfEmpty();
    final query = _db.select(_db.mushroomEmployees)
      ..orderBy([(t) => OrderingTerm(expression: t.id)]);
    final list = await query.get();
    return list.map((e) => {
      'id': e.id,
      'name': e.name,
      'role': e.role,
      'department': e.department,
      'pickerTeamColor': e.pickerTeamColor ?? (e.department?.toLowerCase().contains('harvest') == true ? 'NEW' : null),
      'employmentType': e.employmentType,
      'baseRate': e.baseRate,
      'defaultShed': e.defaultShed,
      'createdAt': e.createdAt.toIso8601String(),
    }).toList();
  }

  Future<List<String>> getTeams() async {
    final Set<String> teams = {
      'NEW', 'MANGO', 'LIME', 'PEACH', 'BLACK', 'PURPLE', 'IVORY', 'YELLOW',
      'GREY', 'AMBER', 'SAPPHIRE', 'PEARL', 'APPLE', 'PINK', 'RUBY', 'ALPHA',
      'JADE', 'INDIGO', 'OPAL', 'SUNSHINE', 'VENUS', 'SKY', 'GROUP 1'
    };
    try {
      final dbTeams = await _db.select(_db.mushroomPickerTeams).get();
      for (final t in dbTeams) {
        if (t.colorCode.trim().isNotEmpty) {
          teams.add(t.colorCode.trim());
        }
      }
    } catch (_) {}
    try {
      final emps = await _db.select(_db.mushroomEmployees).get();
      for (final e in emps) {
        if (e.pickerTeamColor != null && e.pickerTeamColor!.trim().isNotEmpty) {
          teams.add(e.pickerTeamColor!.trim());
        }
      }
    } catch (_) {}
    return teams.toList();
  }

  // === PICKER TEAMS MANAGEMENT ===

  Future<List<Map<String, dynamic>>> getPickerTeamsDetails() async {
    final defaultTeamsData = [
      {'name': 'MANGO', 'rate': 28.5},
      {'name': 'LIME', 'rate': 31.5},
      {'name': 'PEACH', 'rate': 30.3},
      {'name': 'BLACK', 'rate': 29.8},
      {'name': 'PURPLE', 'rate': 31.5},
      {'name': 'IVORY', 'rate': 28.7},
      {'name': 'YELLOW', 'rate': 31.0},
      {'name': 'GREY', 'rate': 31.9},
      {'name': 'AMBER', 'rate': 31.4},
      {'name': 'SAPPHIRE', 'rate': 35.6},
      {'name': 'PEARL', 'rate': 36.6},
      {'name': 'APPLE', 'rate': 30.3},
      {'name': 'PINK', 'rate': 32.8},
      {'name': 'RUBY', 'rate': 37.3},
      {'name': 'ALPHA', 'rate': 32.8},
      {'name': 'JADE', 'rate': 36.0},
      {'name': 'INDIGO', 'rate': 34.5},
      {'name': 'OPAL', 'rate': 28.3},
      {'name': 'SUNSHINE', 'rate': 25.4},
      {'name': 'VENUS', 'rate': 24.1},
      {'name': 'SKY', 'rate': 25.0},
      {'name': 'GROUP 1', 'rate': 25.0},
    ];
    try {
      final dbTeams = await _db.select(_db.mushroomPickerTeams).get();
      if (dbTeams.isEmpty) {
        for (final tData in defaultTeamsData) {
          final tName = tData['name'] as String;
          final tRate = tData['rate'] as double;
          final id = 'TEAM_${tName.replaceAll(' ', '_').toUpperCase()}';
          await _db.into(_db.mushroomPickerTeams).insertOnConflictUpdate(
            MushroomPickerTeam(
              id: id,
              planId: 'PLAN_DEFAULT',
              colorCode: tName,
              headcount: 0,
              rateEstimate: tRate,
            ),
          );
        }
      }

      final allTeams = await _db.select(_db.mushroomPickerTeams).get();
      final allEmployees = await _db.select(_db.mushroomEmployees).get();

      return allTeams.map((t) {
        final teamLeader = allEmployees.firstWhere(
          (e) => e.id == t.teamLeaderId,
          orElse: () => MushroomEmployee(
            id: '',
            name: 'Unassigned',
            role: '',
            passwordHash: '',
            status: 'active',
            createdAt: DateTime.now(),
          ),
        );

        final members = allEmployees
            .where((e) =>
                e.pickerTeamColor?.toLowerCase() == t.colorCode.toLowerCase())
            .map((e) => {
                  'id': e.id,
                  'name': e.name,
                  'role': e.role,
                  'department': e.department,
                })
            .toList();

        return {
          'id': t.id,
          'planId': t.planId,
          'colorCode': t.colorCode,
          'teamLeaderId': t.teamLeaderId,
          'teamLeaderName': teamLeader.name,
          'rateEstimate': t.rateEstimate,
          'headcount': members.length,
          'members': members,
        };
      }).toList();
    } catch (e) {
      print('Error getting picker teams details: $e');
      return [];
    }
  }

  Future<void> addPickerTeam({
    required String colorCode,
    String? teamLeaderId,
    double rateEstimate = 25.0,
  }) async {
    final id = 'TEAM_${DateTime.now().millisecondsSinceEpoch}';
    await _db.into(_db.mushroomPickerTeams).insertOnConflictUpdate(
      MushroomPickerTeam(
        id: id,
        planId: 'PLAN_DEFAULT',
        colorCode: colorCode,
        teamLeaderId: teamLeaderId,
        headcount: 0,
        rateEstimate: rateEstimate,
      ),
    );
    await SyncService().queueMutation('mushroom_picker_teams', 'insert', {
      'id': id,
      'plan_id': 'PLAN_DEFAULT',
      'color_code': colorCode,
      'team_leader_id': teamLeaderId,
      'rate_estimate': rateEstimate,
    });
  }

  Future<void> updatePickerTeam({
    required String id,
    required String colorCode,
    String? teamLeaderId,
    double rateEstimate = 25.0,
  }) async {
    await (_db.update(_db.mushroomPickerTeams)..where((t) => t.id.equals(id))).write(
      MushroomPickerTeamsCompanion(
        colorCode: Value(colorCode),
        teamLeaderId: Value(teamLeaderId),
        rateEstimate: Value(rateEstimate),
      ),
    );
    await SyncService().queueMutation('mushroom_picker_teams', 'update', {
      'id': id,
      'color_code': colorCode,
      'team_leader_id': teamLeaderId,
      'rate_estimate': rateEstimate,
    });
  }

  Future<void> deletePickerTeam(String id, String colorCode) async {
    final emps = await _db.select(_db.mushroomEmployees).get();
    for (final e in emps) {
      if (e.pickerTeamColor?.toLowerCase() == colorCode.toLowerCase()) {
        await (_db.update(_db.mushroomEmployees)..where((emp) => emp.id.equals(e.id))).write(
          const MushroomEmployeesCompanion(
            pickerTeamColor: Value('NEW'),
          ),
        );
      }
    }
    await (_db.delete(_db.mushroomPickerTeams)..where((t) => t.id.equals(id))).go();
    await SyncService().queueMutation('mushroom_picker_teams', 'delete', {
      'id': id,
    });
  }

  Future<void> upsertPickerTeams(List<Map<String, dynamic>> teams) async {
    for (final team in teams) {
      final name = team['name']?.toString() ?? team['colorCode']?.toString() ?? 'WHITE';
      final speed = (team['speedRateW'] as num?)?.toDouble() ?? (team['speed_rate_w'] as num?)?.toDouble() ?? 25.0;
      final headcount = (team['headcountHV'] as num?)?.toInt() ?? (team['headcount_hv'] as num?)?.toInt() ?? 0;

      final existing = await (_db.select(_db.mushroomPickerTeams)
            ..where((t) => t.colorCode.equals(name)))
          .getSingleOrNull();

      if (existing != null) {
        await (_db.update(_db.mushroomPickerTeams)..where((t) => t.id.equals(existing.id))).write(
          MushroomPickerTeamsCompanion(
            rateEstimate: Value(speed),
            headcount: Value(headcount),
          ),
        );
        await SyncService().queueMutation('mushroom_picker_teams', 'update', {
          'id': existing.id,
          'color_code': name,
          'rate_estimate': speed,
          'headcount': headcount,
        });
      } else {
        final id = 'TEAM_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}';
        await _db.into(_db.mushroomPickerTeams).insertOnConflictUpdate(
          MushroomPickerTeam(
            id: id,
            planId: 'PLAN_DEFAULT',
            colorCode: name,
            teamLeaderId: null,
            headcount: headcount,
            rateEstimate: speed,
          ),
        );
        await SyncService().queueMutation('mushroom_picker_teams', 'insert', {
          'id': id,
          'plan_id': 'PLAN_DEFAULT',
          'color_code': name,
          'rate_estimate': speed,
          'headcount': headcount,
        });
      }
    }
  }

  Future<void> assignEmployeesToTeam(String teamColorCode, List<String> employeeIds) async {
    for (final empId in employeeIds) {
      await (_db.update(_db.mushroomEmployees)..where((e) => e.id.equals(empId))).write(
        MushroomEmployeesCompanion(
          pickerTeamColor: Value(teamColorCode),
        ),
      );
    }
  }

  Future<void> addEmployee(String id, String name, String role, [String? department, String? password, String? status, String? pickerTeamColor]) async {
    final passwordToHash = (password != null && password.isNotEmpty) ? password : 'password123';
    final algorithm = Sha256();
    final hash = await algorithm.hash(utf8.encode(passwordToHash));
    final passwordHash = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final statusVal = (status != null && status.isNotEmpty) ? status : 'active';
    final teamVal = pickerTeamColor ?? (department?.toLowerCase().contains('harvest') == true ? 'NEW' : null);

    await _db.into(_db.mushroomEmployees).insertOnConflictUpdate(
      MushroomEmployeesCompanion.insert(
        id: id,
        name: name,
        role: role,
        department: Value(department),
        passwordHash: Value(passwordHash),
        status: Value(statusVal),
        pickerTeamColor: Value(teamVal),
        createdAt: Value(DateTime.now()),
      ),
    );

    String getRoleKey(String r) {
      final lower = r.toLowerCase();
      if (lower.contains('manager')) return 'manager';
      if (lower.contains('supervisor') || lower.contains('lead')) return 'supervisor';
      if (lower.contains('specialist')) return 'specialist';
      return 'picker';
    }

    final roleKey = getRoleKey(role);
    final roleBindId = 'bind_$id';
    await _db.into(_db.mushroomEmployeeDepartmentRoles).insertOnConflictUpdate(
      MushroomEmployeeDepartmentRole(
        id: roleBindId,
        employeeId: id,
        departmentId: 'DEP002',
        roleKey: roleKey,
        createdAt: DateTime.now(),
      ),
    );

    await SyncService().queueMutation('mushroom_employees', 'insert', {
      'id': id,
      'name': name,
      'role': role,
      'department': department,
      'status': statusVal,
      'picker_team_color': teamVal,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateEmployee(String id, String name, String role, [String? department, String? status, String? pickerTeamColor]) async {
    final statusVal = (status != null && status.isNotEmpty) ? status : 'active';
    final teamVal = pickerTeamColor ?? (department?.toLowerCase().contains('harvest') == true ? 'NEW' : null);

    await (_db.update(_db.mushroomEmployees)..where((e) => e.id.equals(id))).write(
      MushroomEmployeesCompanion(
        name: Value(name),
        role: Value(role),
        department: Value(department),
        status: Value(statusVal),
        pickerTeamColor: Value(teamVal),
      ),
    );
    await SyncService().queueMutation('mushroom_employees', 'update', {
      'id': id,
      'name': name,
      'role': role,
      'department': department,
      'status': statusVal,
      'picker_team_color': teamVal,
    });
  }

  // === DEPARTMENTS MANAGEMENT ===

  Future<File> _getDepartmentsFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File(p.join(docDir.path, 'mushroom_departments.json'));
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    try {
      final List<Map<String, dynamic>> results = [];
      final Set<String> seenNames = {};

      // 1. Query SQLite mushroomDepartments table
      try {
        final dbDepts = await _db.select(_db.mushroomDepartments).get();
        for (final d in dbDepts) {
          if (!seenNames.contains(d.name)) {
            seenNames.add(d.name);
            results.add({
              'id': d.id,
              'name': d.name,
              'description': d.description ?? '',
            });
          }
        }
      } catch (_) {}

      // 2. Query SQLite mushroomEmployees table for any distinct department values in DB
      try {
        final emps = await _db.select(_db.mushroomEmployees).get();
        for (final e in emps) {
          final deptName = e.department?.trim();
          if (deptName != null && deptName.isNotEmpty && !seenNames.contains(deptName)) {
            seenNames.add(deptName);
            results.add({
              'id': 'DEP_${deptName.toUpperCase().replaceAll(' ', '_')}',
              'name': deptName,
              'description': 'Database Department',
            });
          }
        }
      } catch (_) {}

      // 3. Fallback to JSON file if no database records found
      if (results.isEmpty) {
        final file = await _getDepartmentsFile();
        if (!await file.exists()) {
          final defaults = [
            {'id': 'DEP001', 'name': 'Harvest', 'description': 'Responsible for mushroom picking and grading'},
            {'id': 'DEP002', 'name': 'Growing', 'description': 'Responsible for watering, composting and climate control'},
            {'id': 'DEP003', 'name': 'Maintenance', 'description': 'Responsible for mechanical repairs and cleaning'},
            {'id': 'DEP004', 'name': 'Sales', 'description': 'Responsible for retail orders and shipping logistics'},
          ];
          await file.writeAsString(jsonEncode(defaults));
          return defaults;
        }
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(content) as List<dynamic>;
            final fileList = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            for (final item in fileList) {
              final name = item['name'] as String;
              if (!seenNames.contains(name)) {
                seenNames.add(name);
                results.add(item);
              }
            }
          } catch (_) {}
        }
      }

      return results;
    } catch (e) {
      print('Error loading departments: $e');
      return [];
    }
  }

  Future<void> saveDepartments(List<Map<String, dynamic>> depts) async {
    try {
      final file = await _getDepartmentsFile();
      await file.writeAsString(jsonEncode(depts));
    } catch (e) {
      print('Error saving departments: $e');
    }
  }

  Future<void> addDepartment(String id, String name, String description) async {
    final list = await getDepartments();
    list.add({
      'id': id,
      'name': name,
      'description': description,
    });
    await saveDepartments(list);
    try {
      await _db.into(_db.mushroomDepartments).insertOnConflictUpdate(
        MushroomDepartment(
          id: id,
          name: name,
          description: description,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
    await SyncService().queueMutation('mushroom_departments', 'insert', {
      'id': id,
      'name': name,
      'description': description,
    });
  }

  Future<void> updateDepartment(String id, String name, String description) async {
    final list = await getDepartments();
    final idx = list.indexWhere((element) => element['id'] == id);
    if (idx != -1) {
      list[idx] = {
        'id': id,
        'name': name,
        'description': description,
      };
      await saveDepartments(list);
      try {
        await (_db.update(_db.mushroomDepartments)..where((d) => d.id.equals(id))).write(
          MushroomDepartmentsCompanion(
            name: Value(name),
            description: Value(description),
          ),
        );
      } catch (_) {}
      await SyncService().queueMutation('mushroom_departments', 'update', {
        'id': id,
        'name': name,
        'description': description,
      });
    }
  }

  Future<void> deleteDepartment(String id) async {
    final list = await getDepartments();
    list.removeWhere((element) => element['id'] == id);
    await saveDepartments(list);
    try {
      await (_db.delete(_db.mushroomDepartments)..where((d) => d.id.equals(id))).go();
    } catch (_) {}
    await SyncService().queueMutation('mushroom_departments', 'delete', {
      'id': id,
    });
  }

  // === ROLES MANAGEMENT ===

  Future<File> _getRolesFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File(p.join(docDir.path, 'mushroom_roles.json'));
  }

  Future<List<Map<String, dynamic>>> getRolesWithLevels() async {
    try {
      final file = await _getRolesFile();
      if (!await file.exists()) {
        final defaults = [
          {'name': 'Harvest Picker', 'level': 0},
          {'name': 'Box Mover', 'level': 0},
          {'name': 'Growing Specialist', 'level': 1},
          {'name': 'Maintenance Specialist', 'level': 1},
          {'name': 'Growing Lead', 'level': 2},
          {'name': 'Harvest Supervisor', 'level': 2},
          {'name': 'Cool Room Manager', 'level': 2},
          {'name': 'Maintenance Lead', 'level': 2},
          {'name': 'Site Manager', 'level': 3},
        ];
        await file.writeAsString(jsonEncode(defaults));
        return defaults;
      }
      final content = await file.readAsString();
      final result = <Map<String, dynamic>>[];
      if (content.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(content) as List<dynamic>;
          for (final item in decoded) {
            if (item is String) {
              int level = 0;
              final r = item.toLowerCase();
              if (r.contains('manager') || r.contains('site manager')) {
                level = 3;
              } else if (r.contains('lead') || r.contains('supervisor')) {
                level = 2;
              } else if (r.contains('specialist')) {
                level = 1;
              }
              result.add({'name': item, 'level': level});
            } else if (item is Map) {
              result.add({
                'name': item['name'] as String,
                'level': item['level'] as int? ?? 0,
              });
            }
          }
        } catch (_) {}
      }
      return result;
    } catch (e) {
      print('Error loading roles: $e');
      return [];
    }
  }

  Future<List<String>> getRoles() async {
    final Set<String> rolesSet = {};
    final list = await getRolesWithLevels();
    for (final e in list) {
      if (e['name'] != null) {
        rolesSet.add(e['name'] as String);
      }
    }
    try {
      final emps = await _db.select(_db.mushroomEmployees).get();
      for (final emp in emps) {
        if (emp.role.trim().isNotEmpty) {
          rolesSet.add(emp.role.trim());
        }
      }
    } catch (_) {}
    return rolesSet.toList();
  }

  Future<void> saveRoles(List<Map<String, dynamic>> roles) async {
    try {
      final file = await _getRolesFile();
      await file.writeAsString(jsonEncode(roles));
    } catch (e) {
      print('Error saving roles: $e');
    }
  }

  Future<void> addRole(String roleName, {int level = 0}) async {
    final list = await getRolesWithLevels();
    if (!list.any((e) => e['name'] == roleName)) {
      list.add({'name': roleName, 'level': level});
      final file = await _getRolesFile();
      await file.writeAsString(jsonEncode(list));
      await SyncService().queueMutation('mushroom_roles', 'insert', {
        'name': roleName,
        'level': level,
      });
    }
  }

  Future<void> deleteRole(String roleName) async {
    final list = await getRolesWithLevels();
    list.removeWhere((e) => e['name'] == roleName);
    final file = await _getRolesFile();
    await file.writeAsString(jsonEncode(list));
    await SyncService().queueMutation('mushroom_roles', 'delete', {
      'name': roleName,
    });
  }

  // === ROOMS ===

  Future<List<Map<String, dynamic>>> getRooms() async {
    await seedRoomsIfEmpty();
    final query = _db.select(_db.growRooms)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    final rooms = await query.get();
    
    return rooms.map((r) => <String, dynamic>{
      'id': r.id,
      'name': r.name,
      'status': r.status,
      'current_stage': r.currentStage,
      'day_in_cycle': r.dayInCycle,
      'targetYield': r.targetYield,
      'pickedYield': r.pickedYield,
      'pickingPlanJson': r.pickingPlanJson,
      'created_at': r.createdAt.toIso8601String(),
    }).toList();
  }

  Future<void> addNewRoom(String name) async {
    final id = const Uuid().v4();
    await _db.into(_db.growRooms).insert(GrowRoomsCompanion.insert(
      id: id,
      name: name,
      status: const Value('idle'),
      currentStage: const Value('idle'),
      dayInCycle: const Value(1),
    ));
    await SyncService().queueMutation('grow_rooms', 'insert', {
      'id': id,
      'name': name,
      'status': 'idle',
      'current_stage': 'idle',
      'day_in_cycle': 1,
      'targetYield': 0.0,
      'pickedYield': 0.0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // === JOBS ===

  Future<List<Map<String, dynamic>>> getJobsForRoom(String roomId) async {
    final query = _db.select(_db.mushroomJobs)
      ..where((tbl) => tbl.roomId.equals(roomId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final jobs = await query.get();

    return jobs.map((j) => <String, dynamic>{
      'id': j.id,
      'room_id': j.roomId,
      'job_type': j.jobType,
      'name': j.name,
      'status': j.status,
      'assignee': j.assignee ?? '',
      'plan_details': j.planDetails ?? '',
      'prochloraz_rate': j.prochlorazRate ?? '',
      'completed_at': j.completedAt?.toIso8601String(),
      'linked_task_id': j.linkedTaskId ?? '',
      'is_solo_job': j.isSoloJob,
      'time_limit_minutes': j.timeLimitMinutes ?? 0,
      'started_at': j.startedAt?.toIso8601String(),
      'alarm_triggered': j.alarmTriggered,
      'scheduled_at': j.scheduledAt?.toIso8601String(),
      'priority': j.priority ?? 'normal',
      'created_at': j.createdAt.toIso8601String(),
      'co_level': j.coLevel,
      'co2_level': j.co2Level,
      'check_in_time': j.checkInTime?.toIso8601String(),
      'check_out_time': j.checkOutTime?.toIso8601String(),
    }).toList();
  }

  Future<void> resetRoom(String roomId) async {
    // 1. Update room status to idle and stage to idle
    await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
      const GrowRoomsCompanion(
        status: Value('idle'),
        currentStage: Value('idle'),
        dayInCycle: Value(1),
      ),
    );

    // Queue grow_rooms update mutation
    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      'status': 'idle',
      'current_stage': 'idle',
      'day_in_cycle': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 2. Set all jobs in this room to 'completed'
    final jobs = await (_db.select(_db.mushroomJobs)..where((tbl) => tbl.roomId.equals(roomId))).get();
    for (final job in jobs) {
      await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.id.equals(job.id))).write(
        MushroomJobsCompanion(
          status: const Value('completed'),
          completedAt: Value(DateTime.now()),
          alarmTriggered: const Value(false),
        ),
      );
      await SyncService().queueMutation('mushroom_jobs', 'update', {
        'id': job.id,
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'alarm_triggered': false,
      });

      // Update any linked Task status to 'done'
      if (job.linkedTaskId != null && job.linkedTaskId!.isNotEmpty) {
        try {
          await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(job.linkedTaskId!))).write(
            const TasksCompanion(status: Value('done')),
          );
          await SyncService().queueMutation('tasks', 'update', {
            'id': job.linkedTaskId,
            'status': 'done',
          });
        } catch (_) {}
      }
    }
  }

  Future<void> startNewCycle(String roomId, {String? wateringPlan, String? prochlorazRate}) async {
    // 1. Update room status and stage
    await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
      GrowRoomsCompanion(
        status: const Value('active'),
        currentStage: const Value('filling'),
        dayInCycle: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Queue grow_rooms update
    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      'status': 'active',
      'current_stage': 'filling',
      'day_in_cycle': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 2. Delete existing jobs for this room if any (clean start)
    await (_db.delete(_db.mushroomJobs)..where((tbl) => tbl.roomId.equals(roomId))).go();

    // 3. Define the pipeline steps
    final pipeline = [
      {'type': 'filling', 'name': 'Filling (New room)'},
      {'type': 'airing', 'name': 'Airing (Pack up, set up floor wet, Plastic)'},
      {'type': 'floor_wet', 'name': 'Pack up floor wet'},
      {'type': 'clean_room', 'name': 'Clean room (Handover to Harvest)'},
      {'type': 'watering', 'name': 'Watering'},
      {'type': 'clean_bed', 'name': 'Set up Clean bed'},
      {'type': 'prochloraz', 'name': 'Prochloraz (Rate 1.3g/m2)'},
      {'type': 'packup_tree', 'name': 'Pack up tree'},
    ];

    // 4. Insert jobs
    for (int i = 0; i < pipeline.length; i++) {
      final step = pipeline[i];
      final isFirst = i == 0;
      final jobId = const Uuid().v4();
      await _db.into(_db.mushroomJobs).insert(MushroomJobsCompanion.insert(
        id: jobId,
        roomId: roomId,
        jobType: step['type']!,
        name: step['name']!,
        status: Value(isFirst ? 'in_progress' : 'pending'),
        planDetails: step['type'] == 'watering' ? Value(wateringPlan ?? '2 Side 2L/m2') : const Value.absent(),
        prochlorazRate: step['type'] == 'prochloraz' ? Value(prochlorazRate ?? '1.3g/m2') : const Value.absent(),
      ));

      // Queue mushroom_jobs mutation
      await SyncService().queueMutation('mushroom_jobs', 'insert', {
        'id': jobId,
        'room_id': roomId,
        'job_type': step['type']!,
        'name': step['name']!,
        'status': isFirst ? 'in_progress' : 'pending',
        'plan_details': step['type'] == 'watering' ? (wateringPlan ?? '2 Side 2L/m2') : null,
        'prochloraz_rate': step['type'] == 'prochloraz' ? (prochlorazRate ?? '1.3g/m2') : null,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> addSpecialSoloJob(
    String roomId,
    String title,
    String assignee,
    int timeLimitMinutes, {
    double? coLevel,
    double? co2Level,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) async {
    final jobId = const Uuid().v4();
    final room = await (_db.select(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).getSingleOrNull();
    final roomName = room?.name ?? 'Room';
    
    // Create new Task in Project & Task module automatically as part of Odoo integration
    final taskId = const Uuid().v4();
    try {
      // Look for a general Costa M2 project, if not exist create one
      var project = await (_db.select(_db.projects)..where((tbl) => tbl.name.equals('Costa M2 Operations'))).getSingleOrNull();
      if (project == null) {
        final projectId = const Uuid().v4();
        await _db.into(_db.projects).insert(ProjectsCompanion.insert(
          id: projectId,
          name: 'Costa M2 Operations',
          description: const Value('Giám sát công việc tại Costa Mushroom M2'),
        ));
        project = await (_db.select(_db.projects)..where((tbl) => tbl.id.equals(projectId))).getSingle();
        
        await SyncService().queueMutation('projects', 'insert', {
          'id': project.id,
          'name': project.name,
          'description': project.description,
        });
      }

      await _db.into(_db.tasks).insert(TasksCompanion.insert(
        id: taskId,
        projectId: project.id,
        title: '$title ($roomName)',
        description: Value('Alone Worker (Solo) at Grow Room. Limit: $timeLimitMinutes mins. Operator: $assignee. CO: ${coLevel ?? 0} ppm, CO2: ${co2Level ?? 0} ppm'),
        status: const Value('in_progress'),
        priority: const Value('high'),
      ));

      await SyncService().queueMutation('tasks', 'insert', {
        'id': taskId,
        'project_id': project.id,
        'title': '$title ($roomName)',
        'description': 'Alone Worker (Solo) at Grow Room. Limit: $timeLimitMinutes mins. Operator: $assignee. CO: ${coLevel ?? 0} ppm, CO2: ${co2Level ?? 0} ppm',
        'status': 'in_progress',
        'priority': 'high',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    await _db.into(_db.mushroomJobs).insert(MushroomJobsCompanion.insert(
      id: jobId,
      roomId: roomId,
      jobType: 'alone_worker',
      name: title,
      status: const Value('in_progress'),
      assignee: Value(assignee),
      isSoloJob: const Value(true),
      timeLimitMinutes: Value(timeLimitMinutes),
      startedAt: Value(DateTime.now()),
      alarmTriggered: const Value(false),
      linkedTaskId: Value(taskId),
      coLevel: Value(coLevel),
      co2Level: Value(co2Level),
      checkInTime: Value(checkInTime),
      checkOutTime: Value(checkOutTime),
    ));

    await SyncService().queueMutation('mushroom_jobs', 'insert', {
      'id': jobId,
      'room_id': roomId,
      'job_type': 'alone_worker',
      'name': title,
      'status': 'in_progress',
      'assignee': assignee,
      'is_solo_job': true,
      'time_limit_minutes': timeLimitMinutes,
      'started_at': DateTime.now().toIso8601String(),
      'alarm_triggered': false,
      'linked_task_id': taskId,
      'co_level': coLevel,
      'co2_level': co2Level,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    try {
      final safetyConfigId = const Uuid().v4();
      await _db.into(_db.mushroomJobSafetyConfigs).insert(
        MushroomJobSafetyConfigsCompanion.insert(
          id: safetyConfigId,
          jobId: jobId,
          checkInIntervalMinutes: Value(timeLimitMinutes),
          gracePeriodMinutes: const Value(5),
          escalationTarget: const Value('supervisor'),
          autoStartOnJobBegin: const Value(true),
          alarmType: const Value('push_inapp'),
        ),
      );

      await SyncService().queueMutation('mushroom_job_safety_configs', 'insert', {
        'id': safetyConfigId,
        'job_id': jobId,
        'check_in_interval_minutes': timeLimitMinutes,
        'grace_period_minutes': 5,
        'escalation_target': 'supervisor',
        'auto_start_on_job_begin': true,
        'alarm_type': 'push_inapp',
        'created_at': DateTime.now().toIso8601String(),
      });

      final logId = const Uuid().v4();
      await _db.into(_db.mushroomSafetyCheckinLogs).insert(
        MushroomSafetyCheckinLogsCompanion.insert(
          id: logId,
          jobId: jobId,
          workerId: assignee,
          eventType: 'start',
          notes: Value('Alone Worker job started. Limit: $timeLimitMinutes mins. CO: $coLevel ppm, CO2: $co2Level ppm'),
          timestamp: Value(DateTime.now()),
        ),
      );

      await SyncService().queueMutation('mushroom_safety_checkin_logs', 'insert', {
        'id': logId,
        'job_id': jobId,
        'worker_id': assignee,
        'event_type': 'start',
        'notes': 'Alone Worker job started. Limit: $timeLimitMinutes mins. CO: $coLevel ppm, CO2: $co2Level ppm',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // Update room stage to alone_worker & active
    await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
      const GrowRoomsCompanion(
        status: Value('active'),
        currentStage: Value('alone_worker'),
      ),
    );

    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      'status': 'active',
      'current_stage': 'alone_worker',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateJobStatus(String jobId, String newStatus) async {
    final job = await (_db.select(_db.mushroomJobs)..where((tbl) => tbl.id.equals(jobId))).getSingleOrNull();
    if (job == null) return;

    await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.id.equals(jobId))).write(
      MushroomJobsCompanion(
        status: Value(newStatus),
        completedAt: Value(newStatus == 'completed' ? DateTime.now() : null),
        alarmTriggered: Value(newStatus == 'completed' ? false : job.alarmTriggered),
      ),
    );

    // Queue MushroomJob mutation
    await SyncService().queueMutation('mushroom_jobs', 'update', {
      'id': jobId,
      'status': newStatus,
      'completed_at': newStatus == 'completed' ? DateTime.now().toIso8601String() : null,
      'alarm_triggered': newStatus == 'completed' ? false : job.alarmTriggered,
    });

    // Sync status back to linked project task
    if (job.linkedTaskId != null && job.linkedTaskId!.isNotEmpty) {
      String taskStatus = 'todo';
      if (newStatus == 'in_progress') taskStatus = 'in_progress';
      if (newStatus == 'review') taskStatus = 'review';
      if (newStatus == 'completed') taskStatus = 'done';
      try {
        await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(job.linkedTaskId!))).write(
          TasksCompanion(status: Value(taskStatus)),
        );
        // Queue Task update mutation
        await SyncService().queueMutation('tasks', 'update', {
          'id': job.linkedTaskId,
          'status': taskStatus,
        });
      } catch (_) {}
    }

    // Update room stage if it's in_progress
    if (newStatus == 'in_progress' && !job.isSoloJob) {
      await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
        GrowRoomsCompanion(
          status: const Value('active'),
          currentStage: Value(job.jobType),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // Queue GrowRoom update mutation
      await SyncService().queueMutation('grow_rooms', 'update', {
        'id': job.roomId,
        'status': 'active',
        'current_stage': job.jobType,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else if (newStatus == 'completed' || newStatus == 'done' || newStatus == 'todo') {
      // Check if there are remaining in_progress jobs for this room
      final remainingInProgressJob = await (_db.select(_db.mushroomJobs)
            ..where((tbl) => tbl.roomId.equals(job.roomId) & tbl.status.equals('in_progress')))
          .getSingleOrNull();

      if (remainingInProgressJob != null) {
        final stageStr = remainingInProgressJob.isSoloJob ? 'alone_worker' : remainingInProgressJob.jobType;
        await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
          GrowRoomsCompanion(
            status: const Value('active'),
            currentStage: Value(stageStr),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await SyncService().queueMutation('grow_rooms', 'update', {
          'id': job.roomId,
          'status': 'active',
          'current_stage': stageStr,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // No remaining in_progress jobs -> Auto-reset room status to idle!
        await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
          GrowRoomsCompanion(
            status: const Value('idle'),
            currentStage: const Value('idle'),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await SyncService().queueMutation('grow_rooms', 'update', {
          'id': job.roomId,
          'status': 'idle',
          'current_stage': 'idle',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> addCustomMushroomJob({
    required String roomId,
    required String name,
    required String jobType,
    required String assignee,
    required String priority,
    required DateTime? scheduledAt,
    required String? planDetails,
    required String? prochlorazRate,
    required String? notes,
    required String? projectName,
  }) async {
    final jobId = const Uuid().v4();
    final taskId = const Uuid().v4();

    final room = await (_db.select(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).getSingleOrNull();
    final roomName = room?.name ?? 'Room';

    if (projectName != null && projectName.isNotEmpty) {
      try {
        var project = await (_db.select(_db.projects)..where((tbl) => tbl.name.equals(projectName))).getSingleOrNull();
        if (project == null) {
          final projectId = const Uuid().v4();
          await _db.into(_db.projects).insert(ProjectsCompanion.insert(
            id: projectId,
            name: projectName,
            description: Value('Project for mushroom cycle linked to $roomName'),
          ));
          project = await (_db.select(_db.projects)..where((tbl) => tbl.id.equals(projectId))).getSingle();
          
          await SyncService().queueMutation('projects', 'insert', {
            'id': project.id,
            'name': project.name,
            'description': project.description,
          });
        }

        String taskPriority = 'medium';
        if (priority == 'low') taskPriority = 'low';
        if (priority == 'high') taskPriority = 'high';
        if (priority == 'urgent') taskPriority = 'high';

        await _db.into(_db.tasks).insert(TasksCompanion.insert(
          id: taskId,
          projectId: project.id,
          title: '$name ($roomName)',
          description: Value(notes ?? 'Mushroom Operation job. Priority: $priority'),
          status: const Value('todo'),
          priority: Value(taskPriority),
          dueDate: Value(scheduledAt),
        ));

        await SyncService().queueMutation('tasks', 'insert', {
          'id': taskId,
          'project_id': project.id,
          'title': '$name ($roomName)',
          'description': notes ?? 'Mushroom Operation job. Priority: $priority',
          'status': 'todo',
          'priority': taskPriority,
          'due_date': scheduledAt?.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    await _db.into(_db.mushroomJobs).insert(MushroomJobsCompanion.insert(
      id: jobId,
      roomId: roomId,
      jobType: jobType,
      name: name,
      status: const Value('in_progress'),
      assignee: Value(assignee),
      priority: Value(priority),
      scheduledAt: Value(scheduledAt),
      planDetails: Value(planDetails),
      prochlorazRate: Value(prochlorazRate),
      linkedTaskId: Value(taskId),
      startedAt: Value(DateTime.now()),
    ));

    await SyncService().queueMutation('mushroom_jobs', 'insert', {
      'id': jobId,
      'room_id': roomId,
      'job_type': jobType,
      'name': name,
      'status': 'in_progress',
      'assignee': assignee,
      'priority': priority,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'plan_details': planDetails,
      'prochloraz_rate': prochlorazRate,
      'linked_task_id': taskId,
      'started_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    final stageStr = jobType == 'alone_worker' ? 'alone_worker' : jobType;
    await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
      GrowRoomsCompanion(
        status: const Value('active'),
        currentStage: Value(stageStr),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await SyncService().queueMutation('grow_rooms', 'update', {
      'id': roomId,
      'status': 'active',
      'current_stage': stageStr,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> completeJob(String jobId) async {
    final job = await (_db.select(_db.mushroomJobs)..where((tbl) => tbl.id.equals(jobId))).getSingleOrNull();
    if (job == null) return;

    await updateJobStatus(jobId, 'completed');

    if (job.isSoloJob) {
      try {
        await logSafetyCheckin(
          jobId: jobId,
          workerId: job.assignee ?? 'Solo Worker',
          eventType: 'complete',
          notes: 'Solo job completed and checked out safely.',
        );
      } catch (_) {}

      // Check if there is an active standard (non-solo) job in progress for this room
      final activeStandardJob = await (_db.select(_db.mushroomJobs)
            ..where((tbl) => tbl.roomId.equals(job.roomId) & tbl.isSoloJob.equals(false) & tbl.status.equals('in_progress')))
          .getSingleOrNull();

      if (activeStandardJob != null) {
        // Revert room stage to the active standard job's stage
        await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
          GrowRoomsCompanion(
            status: const Value('active'),
            currentStage: Value(activeStandardJob.jobType),
          ),
        );
      } else {
        // If no standard job is active, check if there are other active jobs (like other solo jobs)
        final activeJobs = await (_db.select(_db.mushroomJobs)
              ..where((tbl) => tbl.roomId.equals(job.roomId) & tbl.status.equals('in_progress')))
            .get();
        if (activeJobs.isEmpty) {
          await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
            const GrowRoomsCompanion(
              status: Value('idle'),
              currentStage: Value('idle'),
            ),
          );
        }
      }
      return;
    }

    final allJobs = await (_db.select(_db.mushroomJobs)
          ..where((tbl) => tbl.roomId.equals(job.roomId) & tbl.isSoloJob.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();

    final currentIndex = allJobs.indexWhere((j) => j.id == jobId);
    if (currentIndex != -1 && currentIndex < allJobs.length - 1) {
      final nextJob = allJobs[currentIndex + 1];
      await updateJobStatus(nextJob.id, 'in_progress');
    } else {
      await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
        const GrowRoomsCompanion(
          status: Value('idle'),
          currentStage: Value('idle'),
          dayInCycle: Value(1),
        ),
      );
    }
  }

  Future<void> triggerSafetyAlarm(String jobId) async {
    await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.id.equals(jobId))).write(
      const MushroomJobsCompanion(alarmTriggered: Value(true)),
    );
  }

  Future<void> checkSoloJobsAlarms() async {
    try {
      final activeSoloJobs = await (_db.select(_db.mushroomJobs)
            ..where((tbl) =>
                (tbl.isSoloJob.equals(true) | tbl.jobType.equals('alone_worker')) &
                (tbl.status.equals('in_progress') | tbl.status.equals('inprog'))))
          .get();

      final now = DateTime.now();
      for (var job in activeSoloJobs) {
        final startTime = job.startedAt ?? job.scheduledAt ?? job.createdAt;
        final limitMins = job.timeLimitMinutes ?? 45;
        final elapsed = now.difference(startTime).inMinutes;
        if (elapsed < limitMins) continue;

        if (job.alarmTriggered != true) {
          await triggerSafetyAlarm(job.id);
        }

        // ⚠️ SỬA LỖI SINH BẢN GHI VÔ HẠN
        //
        // Hàm này chạy mỗi 30 GIÂY (mushrooms_bloc.dart: _alarmCheckTimer).
        // Bản cũ ghi grow_rooms và đẩy mutation MỖI LẦN CHẠY, không kiểm phòng
        // đã ở trạng thái đó chưa — chỉ có `triggerSafetyAlarm` là được chặn
        // bằng cờ `alarmTriggered`, còn phần dưới thì không.
        //
        // Hậu quả: một công việc Alone Worker quá giờ mà không ai đóng sẽ sinh
        // 120 mutation mỗi giờ, tất cả nội dung y hệt nhau nhưng mỗi cái một
        // UUID mới nên server không gộp được. Đó là nguồn gốc của 15.272 bản
        // ghi `grow_rooms` trong /sync/status — tương đương khoảng 5 ngày với
        // một công việc kẹt.
        //
        // Chỉ ghi khi trạng thái THỰC SỰ đổi.
        final room = await (_db.select(_db.growRooms)
              ..where((tbl) => tbl.id.equals(job.roomId)))
            .getSingleOrNull();
        if (room == null) continue;
        if (room.currentStage == 'alone_timeout' && room.status == 'active') {
          continue; // đã báo động rồi, không ghi lại
        }

        await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(job.roomId)))
            .write(
          GrowRoomsCompanion(
            status: const Value('active'),
            currentStage: const Value('alone_timeout'),
            updatedAt: Value(now),
          ),
        );
        await SyncService().queueMutation('grow_rooms', 'update', {
          'id': job.roomId,
          'status': 'active',
          'current_stage': 'alone_timeout',
          'updated_at': now.toIso8601String(),
        });
      }
    } catch (_) {}
  }

  Future<bool> isAnySoloAlarmActive() async {
    try {
      final activeAlarms = await (_db.select(_db.mushroomJobs)
            ..where((tbl) =>
                (tbl.isSoloJob.equals(true) | tbl.jobType.equals('alone_worker')) &
                (tbl.status.equals('in_progress') | tbl.status.equals('inprog')) &
                tbl.alarmTriggered.equals(true)))
          .get();
      return activeAlarms.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> incrementActiveRoomsCycleDays() async {
    final activeRooms = await (_db.select(_db.growRooms)..where((tbl) => tbl.status.equals('active'))).get();
    for (var room in activeRooms) {
      await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(room.id))).write(
        GrowRoomsCompanion(dayInCycle: Value(room.dayInCycle + 1)),
      );
    }
  }

  Future<Map<String, dynamic>?> getSafetyConfig(String jobId) async {
    try {
      final config = await (_db.select(_db.mushroomJobSafetyConfigs)
            ..where((tbl) => tbl.jobId.equals(jobId)))
          .getSingleOrNull();
      if (config == null) return null;
      return {
        'id': config.id,
        'job_id': config.jobId,
        'check_in_interval_minutes': config.checkInIntervalMinutes,
        'grace_period_minutes': config.gracePeriodMinutes,
        'escalation_target': config.escalationTarget,
        'auto_start_on_job_begin': config.autoStartOnJobBegin,
        'alarm_type': config.alarmType,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSafetyConfig({
    required String jobId,
    required int interval,
    required int gracePeriod,
    required String escalationTarget,
    required bool autoStart,
    required String alarmType,
  }) async {
    final existing = await (_db.select(_db.mushroomJobSafetyConfigs)
          ..where((tbl) => tbl.jobId.equals(jobId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.mushroomJobSafetyConfigs)
            ..where((tbl) => tbl.id.equals(existing.id)))
          .write(MushroomJobSafetyConfigsCompanion(
        checkInIntervalMinutes: Value(interval),
        gracePeriodMinutes: Value(gracePeriod),
        escalationTarget: Value(escalationTarget),
        autoStartOnJobBegin: Value(autoStart),
        alarmType: Value(alarmType),
      ));
    } else {
      await _db.into(_db.mushroomJobSafetyConfigs).insert(
        MushroomJobSafetyConfigsCompanion.insert(
          id: const Uuid().v4(),
          jobId: jobId,
          checkInIntervalMinutes: Value(interval),
          gracePeriodMinutes: Value(gracePeriod),
          escalationTarget: Value(escalationTarget),
          autoStartOnJobBegin: Value(autoStart),
          alarmType: Value(alarmType),
        ),
      );
    }
  }

  Future<void> logSafetyCheckin({
    required String jobId,
    required String workerId,
    required String eventType,
    double? lat,
    double? lng,
    int? responseTimeSeconds,
    String? notes,
  }) async {
    await _db.into(_db.mushroomSafetyCheckinLogs).insert(
      MushroomSafetyCheckinLogsCompanion.insert(
        id: const Uuid().v4(),
        jobId: jobId,
        workerId: workerId,
        eventType: eventType,
        gpsLatitude: Value(lat),
        gpsLongitude: Value(lng),
        responseTimeSeconds: Value(responseTimeSeconds),
        notes: Value(notes),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getAllSafetyLogs() async {
    try {
      final query = _db.select(_db.mushroomSafetyCheckinLogs)
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]);
      final logs = await query.get();
      return logs.map((l) => {
        'id': l.id,
        'job_id': l.jobId,
        'worker_id': l.workerId,
        'event_type': l.eventType,
        'timestamp': l.timestamp.toIso8601String(),
        'notes': l.notes ?? '',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllSoloJobs() async {
    try {
      final query = _db.select(_db.mushroomJobs)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
      final jobs = await query.get();

      final rooms = await getRooms();
      final roomMap = {for (var r in rooms) r['id']: r['name']};

      return jobs
          .where((j) => j.isSoloJob == true || j.jobType == 'alone_worker')
          .map((j) => <String, dynamic>{
        'id': j.id,
        'room_id': j.roomId,
        'room_name': roomMap[j.roomId] ?? 'N/A',
        'job_type': j.jobType,
        'name': j.name,
        'status': j.status,
        'assignee': j.assignee ?? '',
        'plan_details': j.planDetails ?? '',
        'completed_at': j.completedAt?.toIso8601String(),
        'is_solo_job': j.isSoloJob,
        'time_limit_minutes': j.timeLimitMinutes ?? 0,
        'started_at': j.startedAt?.toIso8601String(),
        'alarm_triggered': j.alarmTriggered,
        'co_level': j.coLevel,
        'co2_level': j.co2Level,
        'check_in_time': j.checkInTime?.toIso8601String(),
        'check_out_time': j.checkOutTime?.toIso8601String(),
        'created_at': j.createdAt.toIso8601String(),
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSafetyLogs(String jobId) async {
    try {
      final query = _db.select(_db.mushroomSafetyCheckinLogs)
        ..where((tbl) => tbl.jobId.equals(jobId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]);
      final logs = await query.get();
      return logs.map((l) => {
        'id': l.id,
        'job_id': l.jobId,
        'worker_id': l.workerId,
        'event_type': l.eventType,
        'timestamp': l.timestamp.toIso8601String(),
        'gps_latitude': l.gpsLatitude,
        'gps_longitude': l.gpsLongitude,
        'response_time_seconds': l.responseTimeSeconds,
        'notes': l.notes ?? '',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveTriggeredSoloJobs() async {
    try {
      final query = _db.select(_db.mushroomJobs)
        ..where((tbl) => tbl.isSoloJob.equals(true) & tbl.status.equals('in_progress') & tbl.alarmTriggered.equals(true));
      final jobs = await query.get();
      return jobs.map((j) => {'id': j.id, 'roomId': j.roomId}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> checkInSoloJob(String jobId) async {
    final job = await (_db.select(_db.mushroomJobs)..where((tbl) => tbl.id.equals(jobId))).getSingleOrNull();
    if (job == null) return;

    await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.id.equals(jobId))).write(
      MushroomJobsCompanion(
        startedAt: Value(DateTime.now()),
        alarmTriggered: const Value(false),
      ),
    );

    try {
      await logSafetyCheckin(
        jobId: jobId,
        workerId: job.assignee ?? 'Solo Worker',
        eventType: 'safe',
        notes: 'Worker checked in safely, timer reset.',
      );
    } catch (_) {}
  }

  // === INVENTORY (StockQuants & Products from Supply Chain) ===

  Future<void> seedMushroomProducts() async {
    try {
      final existingProducts = await _db.select(_db.products).get();
      final existingSkus = existingProducts.map((p) => p.sku).toSet();

      final productsToSeed = [
        {'sku': 'mushrooms_button', 'name': 'Button Mushrooms', 'price': 10.0, 'cost': 5.0, 'qty': 120.0},
        {'sku': 'mushrooms_cup', 'name': 'Cup Mushrooms', 'price': 12.0, 'cost': 6.0, 'qty': 240.0},
        {'sku': 'mushrooms_flat', 'name': 'Flat Mushrooms', 'price': 8.0, 'cost': 4.0, 'qty': 95.0},
      ];

      for (final p in productsToSeed) {
        final sku = p['sku'] as String;
        if (!existingSkus.contains(sku)) {
          final productId = const Uuid().v4();
          await _db.into(_db.products).insert(ProductsCompanion.insert(
            id: productId,
            sku: sku,
            name: p['name'] as String,
            price: p['price'] as double,
            cost: p['cost'] as double,
          ));

          await _db.into(_db.stockQuants).insert(StockQuantsCompanion.insert(
            id: const Uuid().v4(),
            productId: productId,
            locationId: 'cool_room',
            quantity: p['qty'] as double,
          ));
        }
      }
    } catch (_) {}
  }

  Future<Map<String, double>> getMushroomStock() async {
    await seedMushroomProducts();
    final Map<String, double> stock = {
      'button': 0.0,
      'cup': 0.0,
      'flat': 0.0,
    };
    try {
      final products = await (_db.select(_db.products)
        ..where((tbl) => tbl.sku.isIn(['mushrooms_button', 'mushrooms_cup', 'mushrooms_flat'])))
        .get();
      for (final p in products) {
        final quants = await (_db.select(_db.stockQuants)
          ..where((tbl) => tbl.productId.equals(p.id) & tbl.locationId.equals('cool_room')))
          .get();
        double qty = 0.0;
        for (final q in quants) {
          qty += q.quantity;
        }
        if (p.sku == 'mushrooms_button') stock['button'] = qty;
        if (p.sku == 'mushrooms_cup') stock['cup'] = qty;
        if (p.sku == 'mushrooms_flat') stock['flat'] = qty;
      }
    } catch (_) {}
    return stock;
  }

  Future<void> updateMushroomStock(String size, double quantityDelta) async {
    try {
      final sku = 'mushrooms_$size';
      final product = await (_db.select(_db.products)..where((tbl) => tbl.sku.equals(sku))).getSingleOrNull();
      if (product != null) {
        final quant = await (_db.select(_db.stockQuants)
          ..where((tbl) => tbl.productId.equals(product.id) & tbl.locationId.equals('cool_room')))
          .getSingleOrNull();
        if (quant != null) {
          await (_db.update(_db.stockQuants)..where((tbl) => tbl.id.equals(quant.id))).write(
            StockQuantsCompanion(
              quantity: Value(quant.quantity + quantityDelta),
              updatedAt: Value(DateTime.now()),
            ),
          );
        } else {
          await _db.into(_db.stockQuants).insert(StockQuantsCompanion.insert(
            id: const Uuid().v4(),
            productId: product.id,
            locationId: 'cool_room',
            quantity: quantityDelta,
          ));
        }
      }
    } catch (_) {}
  }

  // === SALES DEALS (Orders from Sales CRM) ===

  Future<void> seedMushroomDeals() async {
    try {
      final existingDeals = await _db.select(_db.deals).get();
      final hasMushroomDeals = existingDeals.any((d) => d.title.startsWith('Monarto Order'));
      if (hasMushroomDeals) return;

      final contactsToSeed = [
        {'name': 'Aeon Mall', 'phone': '0123456789', 'email': 'info@aeon.vn'},
        {'name': 'Lotte Mart', 'phone': '0987654321', 'email': 'info@lotte.vn'},
        {'name': 'Costa Supply', 'phone': '0555555555', 'email': 'info@costa.vn'},
      ];
      final Map<String, String> contactIds = {};
      for (final c in contactsToSeed) {
        final name = c['name'] as String;
        var existingContact = await (_db.select(_db.contacts)..where((tbl) => tbl.name.equals(name))).getSingleOrNull();
        if (existingContact == null) {
          final contactId = const Uuid().v4();
          await _db.into(_db.contacts).insert(ContactsCompanion.insert(
            id: contactId,
            name: name,
            phone: Value(c['phone']),
            email: Value(c['email']),
            isCustomer: const Value(true),
          ));
          contactIds[name] = contactId;
        } else {
          contactIds[name] = existingContact.id;
        }
      }

      final dealsToSeed = [
        {
          'id': 'ORD-001',
          'title': 'Monarto Order Aeon Mall',
          'contactName': 'Aeon Mall',
          'amount': 1500.0,
          'stage': 'proposal',
        },
        {
          'id': 'ORD-002',
          'title': 'Monarto Order Lotte Mart',
          'contactName': 'Lotte Mart',
          'amount': 1100.0,
          'stage': 'proposal',
        },
        {
          'id': 'ORD-003',
          'title': 'Monarto Order Costa Supply',
          'contactName': 'Costa Supply',
          'amount': 500.0,
          'stage': 'closed_won',
        },
      ];

      for (final d in dealsToSeed) {
        final contactId = contactIds[d['contactName'] as String]!;
        await _db.into(_db.deals).insert(DealsCompanion.insert(
          id: d['id'] as String,
          title: d['title'] as String,
          contactId: contactId,
          amount: d['amount'] as double,
          stage: Value(d['stage'] as String),
        ));
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getMushroomOrders() async {
    await seedMushroomDeals();
    final List<Map<String, dynamic>> orders = [];
    try {
      final query = _db.select(_db.deals)
        ..where((tbl) => tbl.title.like('Monarto Order%'));
      final deals = await query.get();
      for (final d in deals) {
        final contact = await (_db.select(_db.contacts)..where((tbl) => tbl.id.equals(d.contactId))).getSingleOrNull();
        orders.add({
          'id': d.id,
          'customer': contact?.name ?? 'Customer',
          'req': d.id == 'ORD-001'
              ? 'Button: 50kg, Cup: 100kg'
              : d.id == 'ORD-002'
                  ? 'Cup: 80kg, Flat: 30kg'
                  : 'Flat: 50kg',
          'total': d.amount,
          'status': d.stage == 'closed_won' ? 'Delivered' : 'Pending',
        });
      }
    } catch (_) {}
    return orders;
  }

  Future<void> deliverMushroomOrder(String orderId) async {
    try {
      await (_db.update(_db.deals)..where((tbl) => tbl.id.equals(orderId))).write(
        const DealsCompanion(stage: Value('closed_won')),
      );
    } catch (_) {}
  }

  // === ROOM PLANS ===

  Future<void> updateRoomPickingPlan(String roomId, {double? targetYield, String? planJson}) async {
    try {
      await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
        GrowRoomsCompanion(
          targetYield: targetYield != null ? Value(targetYield) : const Value.absent(),
          pickedYield: targetYield != null ? const Value(0.0) : const Value.absent(),
          pickingPlanJson: planJson != null ? Value(planJson) : const Value.absent(),
        ),
      );
    } catch (_) {}
  }

  Future<void> updateRoomPickedYield(String roomId, double pickedYield) async {
    try {
      await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
        GrowRoomsCompanion(
          pickedYield: Value(pickedYield),
        ),
      );
    } catch (_) {}
  }

  Future<void> clearRoomPickingPlan(String roomId) async {
    try {
      await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
        const GrowRoomsCompanion(
          targetYield: Value(0.0),
          pickedYield: Value(0.0),
          pickingPlanJson: Value(null),
        ),
      );
    } catch (_) {}
  }

  // === YIELD SURVEYS & PLANNING ===

  Future<void> seedYieldSurveysIfEmpty() async {
    try {
      final list = await _db.select(_db.mushroomYieldSurveys).get();
      if (list.isEmpty) {
        final mockSurveys = [
          {'roomName': 'Room 1', 'strain': 'Button', 'cycle': 1, 'expectedYield': 80.0},
          {'roomName': 'Room 2', 'strain': 'Cup', 'cycle': 2, 'expectedYield': 110.0},
          {'roomName': 'Room 33', 'strain': 'Cup', 'cycle': 2, 'expectedYield': 120.0},
          {'roomName': 'Room 34', 'strain': 'Button', 'cycle': 1, 'expectedYield': 95.0},
          {'roomName': 'Room 35', 'strain': 'Flat', 'cycle': 3, 'expectedYield': 70.0},
          {'roomName': 'Room 52', 'strain': 'Cup', 'cycle': 1, 'expectedYield': 150.0},
        ];

        for (var s in mockSurveys) {
          final id = '${DateTime.now().millisecondsSinceEpoch}_${s['roomName']}';
          await _db.into(_db.mushroomYieldSurveys).insert(
            MushroomYieldSurveysCompanion.insert(
              id: id,
              roomName: s['roomName'] as String,
              strain: s['strain'] as String,
              cycle: s['cycle'] as int,
              expectedYield: s['expectedYield'] as double,
              surveyedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getYieldSurveys() async {
    await seedYieldSurveysIfEmpty();
    try {
      final query = _db.select(_db.mushroomYieldSurveys)
        ..orderBy([(t) => OrderingTerm(expression: t.roomName)]);
      final list = await query.get();
      return list.map((e) => {
        'id': e.id,
        'roomName': e.roomName,
        'strain': e.strain,
        'cycle': e.cycle,
        'expectedYield': e.expectedYield,
        'surveyedAt': e.surveyedAt.toIso8601String(),
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAllocatedRoomPlan(String roomName, double targetYield, String planJson) async {
    try {
      final roomQuery = await (_db.select(_db.growRooms)..where((tbl) => tbl.name.equals(roomName))).get();
      if (roomQuery.isNotEmpty) {
        final rId = roomQuery.first.id;
        await updateRoomPickingPlan(rId, targetYield: targetYield, planJson: planJson);
      }
    } catch (_) {}
  }

  Future<void> clearRoomPlanByName(String roomName) async {
    try {
      final roomQuery = await (_db.select(_db.growRooms)..where((tbl) => tbl.name.equals(roomName))).get();
      if (roomQuery.isNotEmpty) {
        await clearRoomPickingPlan(roomQuery.first.id);
      }
    } catch (_) {}
  }

  Future<void> addScheduledPickingJob({
    required String roomId,
    required String pickerName,
    required DateTime scheduledTime,
    required String notes,
  }) async {
    final jobId = const Uuid().v4();
    try {
      await _db.into(_db.mushroomJobs).insert(
        MushroomJobsCompanion.insert(
          id: jobId,
          roomId: roomId,
          jobType: 'picking',
          name: 'Manual Picking Task',
          status: const Value('pending'),
          assignee: Value(pickerName),
          scheduledAt: Value(scheduledTime),
          planDetails: Value(notes),
        ),
      );

      await SyncService().queueMutation('mushroom_jobs', 'insert', {
        'id': jobId,
        'room_id': roomId,
        'job_type': 'picking',
        'name': 'Manual Picking Task',
        'status': 'pending',
        'assignee': pickerName,
        'scheduled_at': scheduledTime.toIso8601String(),
        'plan_details': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // === MAINTENANCE TICKETS ===

  Future<List<Map<String, dynamic>>> getMaintenanceTickets() async {
    try {
      final tickets = await _db.select(_db.mushroomMaintenanceTickets).get();
      if (tickets.isEmpty) {
        final defaultTickets = [
          {
            'id': 'MNT-101',
            'title': 'Sterilize Exhaust Fan',
            'plant': 'M2',
            'room': '33',
            'assignee': 'Nam T.',
            'priority': 'normal',
            'status': 'inprog',
            'notes': 'Periodic bacteria filter maintenance.'
          },
          {
            'id': 'MNT-102',
            'title': 'Calibrate Humidity Sensor',
            'plant': 'M1',
            'room': '12',
            'assignee': 'Lợi P.',
            'priority': 'high',
            'status': 'todo',
            'notes': 'Sensor deviation of 5% compared to manual measurement.'
          }
        ];
        for (final t in defaultTickets) {
          await _db.into(_db.mushroomMaintenanceTickets).insert(MushroomMaintenanceTicketsCompanion.insert(
            id: t['id'] as String,
            title: t['title'] as String,
            plant: t['plant'] as String,
            room: t['room'] as String,
            assignee: t['assignee'] as String,
            priority: t['priority'] as String,
            status: Value(t['status'] as String),
            notes: Value(t['notes'] as String?),
          ));
        }
        return defaultTickets;
      }
      return tickets.map((t) => {
        'id': t.id,
        'title': t.title,
        'plant': t.plant,
        'room': t.room,
        'assignee': t.assignee,
        'priority': t.priority,
        'status': t.status,
        'notes': t.notes ?? '',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> createMaintenanceTicket({
    required String title,
    required String plant,
    required String room,
    required String assignee,
    required String priority,
    required String notes,
  }) async {
    try {
      final id = 'MNT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      await _db.into(_db.mushroomMaintenanceTickets).insert(MushroomMaintenanceTicketsCompanion.insert(
        id: id,
        title: title,
        plant: plant,
        room: room,
        assignee: assignee,
        priority: priority,
        status: const Value('todo'),
        notes: Value(notes),
      ));
    } catch (_) {}
  }

  Future<void> updateMaintenanceTicketStatus(String id, String status) async {
    try {
      await (_db.update(_db.mushroomMaintenanceTickets)..where((tbl) => tbl.id.equals(id))).write(
        MushroomMaintenanceTicketsCompanion(status: Value(status)),
      );
    } catch (_) {}
  }

  // === BLE CHAT MESSAGES ===

  Future<List<Map<String, String>>> getChatHistory(String contact) async {
    try {
      final query = _db.select(_db.mushroomChatMessages)
        ..where((tbl) => tbl.contact.equals(contact))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
      final msgs = await query.get();

      if (msgs.isEmpty) {
        final List<Map<String, String>> defaultMsgs = [];
        if (contact == 'Growing Crew') {
          defaultMsgs.addAll([
            {'sender': 'Minh T.', 'text': 'Completed watering room 33 this morning.', 'time': '08:30', 'role': 'Growing Specialist'},
            {'sender': 'Vinh', 'text': 'Great, please check the humidity of room 34 as well.', 'time': '08:45', 'role': 'Growing Lead'},
          ]);
        } else if (contact == 'Sarah (Sales)') {
          defaultMsgs.addAll([
            {'sender': 'Sarah', 'text': 'Aeon Mall urgently needs 150kg of medium (cup) mushrooms this afternoon, does the cold room have enough stock?', 'time': '09:15', 'role': 'Sales Lead'},
            {'sender': 'Trúc', 'text': 'Let me create an urgent picking plan to send to Harvest.', 'time': '09:20', 'role': 'Cool Room Manager'},
          ]);
        } else if (contact == 'Mike (Site Manager)') {
          defaultMsgs.addAll([
            {'sender': 'Mike', 'text': 'Updated the safety alarm system for the new branch.', 'time': '07:00', 'role': 'Site Manager'},
          ]);
        }
        for (final m in defaultMsgs) {
          await _db.into(_db.mushroomChatMessages).insert(MushroomChatMessagesCompanion.insert(
            id: const Uuid().v4(),
            sender: m['sender']!,
            contact: contact,
            textContent: m['text']!,
            timeString: m['time']!,
            role: m['role']!,
          ));
        }
        return defaultMsgs;
      }

      return msgs.map((m) => {
        'sender': m.sender,
        'text': m.textContent,
        'time': m.timeString,
        'role': m.role,
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> sendChatMessage({
    required String sender,
    required String contact,
    required String text,
    required String role,
  }) async {
    try {
      final timeStr = DateTime.now().toLocal().toString().substring(11, 16);
      await _db.into(_db.mushroomChatMessages).insert(MushroomChatMessagesCompanion.insert(
        id: const Uuid().v4(),
        sender: sender,
        contact: contact,
        textContent: text,
        timeString: timeStr,
        role: role,
      ));
    } catch (_) {}
  }

  // === ROOM CREWS ===

  Future<List<Map<String, String>>> getRoomCrews() async {
    try {
      final crews = await _db.select(_db.mushroomRoomCrews).get();
      return crews.map((c) => {
        'roomName': c.roomName,
        'empName': c.empName,
        'empId': c.empId,
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> checkInRoomCrew({
    required String roomName,
    required String empName,
    required String empId,
  }) async {
    try {
      await _db.into(_db.mushroomRoomCrews).insert(MushroomRoomCrewsCompanion.insert(
        id: const Uuid().v4(),
        roomName: roomName,
        empName: empName,
        empId: empId,
      ));
    } catch (_) {}
  }

  Future<void> checkOutRoomCrew({
    required String roomName,
    required String empId,
  }) async {
    try {
      await (_db.delete(_db.mushroomRoomCrews)
        ..where((tbl) => tbl.roomName.equals(roomName) & tbl.empId.equals(empId)))
        .go();
    } catch (_) {}
  }

  Future<void> clearRoomCrews() async {
    try {
      await _db.delete(_db.mushroomRoomCrews).go();
    } catch (_) {}
  }
}
