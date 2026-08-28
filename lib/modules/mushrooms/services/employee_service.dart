// lib/modules/mushrooms/services/employee_service.dart

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/core/sync/sync_service.dart';
import 'package:izii_app/core/settings/settings_service.dart';

abstract class EmployeeService {
  /// Đăng nhập tài khoản Nhân viên (Hỗ trợ Online & Offline)
  Future<bool> login(String employeeId, String password);

  /// Đăng xuất tài khoản Nhân viên
  Future<void> logout();

  /// Lấy ID của nhân viên đang đăng nhập hiện tại
  Future<String?> getCurrentEmployeeId();

  /// Lấy thông tin chi tiết nhân viên hiện tại
  Future<MushroomEmployee?> getCurrentEmployee();

  /// Kiểm tra quyền thực hiện hành động dựa trên Roles + Overrides
  Future<bool> hasPermission(String employeeId, String permissionKey);

  /// Manager cấu hình ngoại lệ (Override) cho nhân viên cụ thể
  /// [overrideType]: 'allow' (cho phép), 'deny' (cấm), hoặc 'none' (xóa override)
  Future<void> setPermissionOverride({
    required String employeeId,
    required String permissionKey,
    required String overrideType,
  });

  /// Lấy danh sách toàn bộ các phòng ban nhân viên tham gia
  Future<List<MushroomDepartment>> getEmployeeDepartments(String employeeId);

  /// Lấy danh sách vai trò phân bổ theo phòng ban
  Future<List<MushroomEmployeeDepartmentRole>> getEmployeeRoles(String employeeId);

  /// Đổi mật khẩu cho nhân viên
  Future<bool> changePassword({
    required String employeeId,
    required String oldPassword,
    required String newPassword,
  });

  /// Seed dữ liệu phòng ban, nhân viên và phân vai trò mẫu ban đầu
  Future<void> seedDefaultData();

  /// Đăng ký tài khoản Nhân viên mới
  Future<bool> registerEmployee({
    required String employeeId,
    required String name,
    required String role,
    required String department,
    required String password,
  });
}

class EmployeeServiceImpl implements EmployeeService {
  final AppDatabase _db;
  static const String _currentEmployeeIdKey = 'current_mushroom_employee_id';

  EmployeeServiceImpl([AppDatabase? db]) : _db = db ?? AppDatabase();

  // Mã hóa mật khẩu sử dụng SHA-256 qua package cryptography
  Future<String> _hashPassword(String password) async {
    final algorithm = Sha256();
    final hash = await algorithm.hash(utf8.encode(password));
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<bool> registerEmployee({
    required String employeeId,
    required String name,
    required String role,
    required String department,
    required String password,
  }) async {
    try {
      final trimmedId = employeeId.trim();

      // Check if employee ID already exists using .get() to avoid getSingleOrNull issues
      final existingList = await (_db.select(_db.mushroomEmployees)
            ..where((e) => e.id.equals(trimmedId)))
          .get();

      if (existingList.isNotEmpty) {
        print('⚠️ Employee ID $trimmedId already exists (${existingList.length} records).');
        return false;
      }

      final passwordHash = await _hashPassword(password);
      final newEmployee = MushroomEmployee(
        id: trimmedId,
        name: name.trim(),
        role: role,
        department: department,
        passwordHash: passwordHash,
        status: 'active',
        createdAt: DateTime.now(),
      );

      await _db.into(_db.mushroomEmployees).insertOnConflictUpdate(newEmployee);

      // Also sync to Users table for Chat
      try {
        await _db.into(_db.users).insertOnConflictUpdate(
          User(
            id: newEmployee.id,
            name: newEmployee.name,
            type: 'both',
            kycStatus: 'none',
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}

      // Save login session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentEmployeeIdKey, newEmployee.id);

      print('✅ Registered new employee: ${newEmployee.id} - ${newEmployee.name}');
      return true;
    } catch (e) {
      print('❌ Register employee failed: $e');
      return false;
    }
  }

  @override
  Future<bool> login(String employeeId, String password) async {
    try {
      final trimmedId = employeeId.trim();
      final trimmedPass = password.trim();
      print('=== LOGIN DEBUG ===');
      print('Attempting login for ID: "$trimmedId"');

      // Seed default data only on first run (silent, never blocks login)
      try {
        await seedDefaultData();
      } catch (_) {}

      final inputHash = await _hashPassword(trimmedPass);

      // Fetch all employees
      final allEmployees = await _db.select(_db.mushroomEmployees).get();
      print('DB has ${allEmployees.length} employees: ${allEmployees.map((e) => e.id).toList()}');

      // Find by ID (exact, case-insensitive)
      var employee = allEmployees.cast<MushroomEmployee?>().firstWhere(
        (e) => e != null && e.id.trim().toLowerCase() == trimmedId.toLowerCase(),
        orElse: () => null,
      );

      // Auto-seed Admin 555555 if not found
      if (employee == null && trimmedId == '555555') {
        final adminHash = await _hashPassword('Admin@123');
        final adminEmp = MushroomEmployee(
          id: '555555',
          name: 'System Admin',
          role: 'Manager',
          department: 'Growing',
          passwordHash: adminHash,
          status: 'active',
          createdAt: DateTime.now(),
        );
        await _db.into(_db.mushroomEmployees).insertOnConflictUpdate(adminEmp);
        employee = adminEmp;
        print('Auto-seeded Admin 555555.');
      }

      if (employee == null) {
        print('❌ Employee NOT found for: $trimmedId');
        return false;
      }

      print('Found: ${employee.id} / ${employee.name}');

      // ── Password verification ──────────────────────────────────
      // Direct hash match
      final bool isMatch = (employee.passwordHash == inputHash) ||
          // Admin 555555 always passes (escape hatch)
          (employee.id == '555555');

      print('Password match: $isMatch');

      if (!isMatch) {
        return false;
      }

      // Save session
      try {
        await _db.into(_db.users).insertOnConflictUpdate(
          User(
            id: employee.id,
            name: employee.name,
            type: 'both',
            kycStatus: 'none',
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentEmployeeIdKey, employee.id);
      await SettingsService().saveActiveUserId(employee.id);
      print('✅ Login success: ${employee.id}');
      return true;
    } catch (e) {
      print('❌ Login error: $e');
      // Return false instead of rethrow — never crash the UI
      return false;
    }
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentEmployeeIdKey);
  }

  @override
  Future<bool> changePassword({
    required String employeeId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final oldHash = await _hashPassword(oldPassword);
    final newHash = await _hashPassword(newPassword);

    final query = _db.select(_db.mushroomEmployees)
      ..where((e) => e.id.equals(employeeId) & e.status.equals('active'));
    final employee = await query.getSingleOrNull();

    if (employee == null || employee.passwordHash != oldHash) {
      return false;
    }

    await (_db.update(_db.mushroomEmployees)
          ..where((e) => e.id.equals(employeeId)))
        .write(MushroomEmployeesCompanion(passwordHash: Value(newHash)));

    return true;
  }

  @override
  Future<String?> getCurrentEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_currentEmployeeIdKey);
    if (id != null && id.isNotEmpty) return id;

    try {
      final activeId = await SettingsService().getActiveUserId();
      if (activeId.isNotEmpty) {
        return activeId;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<MushroomEmployee?> getCurrentEmployee() async {
    final id = await getCurrentEmployeeId();
    if (id == null) return null;
    final query = _db.select(_db.mushroomEmployees)..where((e) => e.id.equals(id));
    return query.getSingleOrNull();
  }

  @override
  Future<bool> hasPermission(String employeeId, String permissionKey) async {
    // 0. Escape hatch cho Admin/Manager cố định
    final lowerId = employeeId.trim().toLowerCase();
    if (lowerId == '555555' ||
        lowerId == '305629' ||
        lowerId == '333333' ||
        lowerId == 'admin') {
      return true;
    }

    // 1. Kiểm tra Override ngoại lệ (Độ ưu tiên cao nhất)
    final overrideQuery = _db.select(_db.mushroomPermissionOverrides)
      ..where((o) => o.employeeId.equals(employeeId) & o.permissionKey.equals(permissionKey));
    final overrides = await overrideQuery.get();
    
    if (overrides.isNotEmpty) {
      // Nếu bị cấm (deny), lập tức trả về false
      final hasDeny = overrides.any((o) => o.type == 'deny');
      if (hasDeny) return false;

      // Nếu được cho phép (allow), lập tức trả về true
      final hasAllow = overrides.any((o) => o.type == 'allow');
      if (hasAllow) return true;
    }

    // 2. Phân tích quyền kế thừa từ tất cả các Role của nhân viên
    final roleQuery = _db.select(_db.mushroomEmployeeDepartmentRoles)
      ..where((r) => r.employeeId.equals(employeeId));
    final roles = await roleQuery.get();

    for (final r in roles) {
      final permissions = _getPermissionsForRole(r.roleKey);
      if (permissions.contains(permissionKey)) {
        return true;
      }
    }

    // 3. Fallback: Kiểm tra trực tiếp từ bảng mushroomEmployees nếu chưa có role-bind
    try {
      final emp = await (_db.select(_db.mushroomEmployees)..where((e) => e.id.equals(employeeId))).getSingleOrNull();
      if (emp != null) {
        final role = emp.role.toLowerCase();
        if (role.contains('manager') || role.contains('admin')) {
          return true;
        }
        final permissions = _getPermissionsForRole(role);
        if (permissions.contains(permissionKey)) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  List<String> _getPermissionsForRole(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'manager':
        return [
          'createJob',
          'addJobToRoom',
          'addRoom',
          'updateJobStatus',
          'useChat',
          'createMaintenanceRequest',
          'approveMaintenanceRequest',
        ];
      case 'supervisor':
        return [
          'addJobToRoom',
          'updateJobStatus',
          'useChat',
          'createMaintenanceRequest',
          'approveMaintenanceRequest',
        ];
      case 'specialist':
        return [
          'updateJobStatus',
          'useChat',
          'createMaintenanceRequest',
        ];
      case 'picker':
        return [
          'updateJobStatus',
          'useChat',
          'createMaintenanceRequest',
        ];
      default:
        return [];
    }
  }

  @override
  Future<void> setPermissionOverride({
    required String employeeId,
    required String permissionKey,
    required String overrideType,
  }) async {
    final id = const Uuid().v4();
    
    // Xóa override cũ của nhân viên tương ứng với quyền này
    await (_db.delete(_db.mushroomPermissionOverrides)
      ..where((o) => o.employeeId.equals(employeeId) & o.permissionKey.equals(permissionKey))).go();

    if (overrideType != 'none') {
      await _db.into(_db.mushroomPermissionOverrides).insert(
        MushroomPermissionOverridesCompanion.insert(
          id: id,
          employeeId: employeeId,
          permissionKey: permissionKey,
          type: overrideType,
        ),
      );
    }

    await SyncService().queueMutation('mushroom_permission_overrides', 'insert_or_replace', {
      'id': id,
      'employee_id': employeeId,
      'permission_key': permissionKey,
      'type': overrideType,
    });
  }

  @override
  Future<List<MushroomDepartment>> getEmployeeDepartments(String employeeId) async {
    final rolesQuery = _db.select(_db.mushroomEmployeeDepartmentRoles)
      ..where((r) => r.employeeId.equals(employeeId));
    final roles = await rolesQuery.get();
    
    final deptIds = roles.map((r) => r.departmentId).toList();
    if (deptIds.isEmpty) return [];

    final deptQuery = _db.select(_db.mushroomDepartments)
      ..where((d) => d.id.isIn(deptIds));
    return deptQuery.get();
  }

  @override
  Future<List<MushroomEmployeeDepartmentRole>> getEmployeeRoles(String employeeId) async {
    final query = _db.select(_db.mushroomEmployeeDepartmentRoles)
      ..where((r) => r.employeeId.equals(employeeId));
    return query.get();
  }

  @override
  Future<void> seedDefaultData() async {
    // Seed Departments
    final depts = [
      MushroomDepartment(id: 'DEP001', name: 'Harvest', description: 'Responsible for mushroom picking and grading', createdAt: DateTime.now()),
      MushroomDepartment(id: 'DEP002', name: 'Growing', description: 'Responsible for watering, composting and climate control', createdAt: DateTime.now()),
      MushroomDepartment(id: 'DEP003', name: 'Maintenance', description: 'Responsible for mechanical repairs and cleaning', createdAt: DateTime.now()),
    ];

    for (final d in depts) {
      await _db.into(_db.mushroomDepartments).insertOnConflictUpdate(d);
    }

    // Seed default Employees (Mật khẩu mặc định: password123)
    final defaultPasswordHash = await _hashPassword('password123');
    final customUserHash = await _hashPassword('Costa@123');
    final adminUserHash = await _hashPassword('Admin@123');

    final employees = [
      MushroomEmployee(
        id: 'EMP001',
        name: 'Minh T. (Manager)',
        role: 'Growing Specialist',
        department: 'Growing',
        passwordHash: defaultPasswordHash,
        status: 'active',
        createdAt: DateTime.now(),
      ),
      MushroomEmployee(
        id: 'EMP002',
        name: 'Lan N. (Supervisor)',
        role: 'Growing Specialist',
        department: 'Growing',
        passwordHash: defaultPasswordHash,
        status: 'active',
        createdAt: DateTime.now(),
      ),
      MushroomEmployee(
        id: 'EMP003',
        name: 'Hùng V. (Specialist)',
        role: 'Harvest Picker',
        department: 'Harvest',
        passwordHash: defaultPasswordHash,
        status: 'active',
        createdAt: DateTime.now(),
      ),
      MushroomEmployee(
        id: 'EMP004',
        name: 'Phúc D. (Picker)',
        role: 'Harvest Picker',
        department: 'Harvest',
        passwordHash: defaultPasswordHash,
        status: 'active',
        createdAt: DateTime.now(),
      ),
      MushroomEmployee(
        id: '305629',
        name: 'Vinh Phan',
        role: 'Manager',
        department: 'Growing',
        passwordHash: defaultPasswordHash,
        status: 'active',
        createdAt: DateTime.now(),
      ),
      MushroomEmployee(
        id: '333333',
        name: 'Costa User',
        role: 'Manager',
        department: 'Growing',
        passwordHash: customUserHash,
        status: 'active',
        createdAt: DateTime.now(),
      ),
      MushroomEmployee(
        id: '555555',
        name: 'System Admin',
        role: 'Manager',
        department: 'Growing',
        passwordHash: adminUserHash,
        status: 'active',
        createdAt: DateTime.now(),
      ),
    ];

    for (final e in employees) {
      await _db.into(_db.mushroomEmployees).insertOnConflictUpdate(e);
    }

    // Bind roles to departments
    final roleBinds = [
      MushroomEmployeeDepartmentRole(id: 'bind_1', employeeId: 'EMP001', departmentId: 'DEP002', roleKey: 'manager', createdAt: DateTime.now()),
      MushroomEmployeeDepartmentRole(id: 'bind_2', employeeId: 'EMP002', departmentId: 'DEP002', roleKey: 'supervisor', createdAt: DateTime.now()),
      MushroomEmployeeDepartmentRole(id: 'bind_3', employeeId: 'EMP003', departmentId: 'DEP002', roleKey: 'specialist', createdAt: DateTime.now()),
      MushroomEmployeeDepartmentRole(id: 'bind_4', employeeId: 'EMP004', departmentId: 'DEP001', roleKey: 'picker', createdAt: DateTime.now()),
      MushroomEmployeeDepartmentRole(id: 'bind_vinh_phan', employeeId: '305629', departmentId: 'DEP002', roleKey: 'manager', createdAt: DateTime.now()),
      MushroomEmployeeDepartmentRole(id: 'bind_costa_user', employeeId: '333333', departmentId: 'DEP002', roleKey: 'manager', createdAt: DateTime.now()),
      MushroomEmployeeDepartmentRole(id: 'bind_system_admin', employeeId: '555555', departmentId: 'DEP002', roleKey: 'manager', createdAt: DateTime.now()),
    ];

    for (final b in roleBinds) {
      await _db.into(_db.mushroomEmployeeDepartmentRoles).insertOnConflictUpdate(b);
    }
  }
}
