// test/modules/mushrooms/employee_service_test.dart

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/mushrooms/services/employee_service.dart';
import 'package:izii_app/modules/mushrooms/repository.dart';

void main() {
  late AppDatabase db;
  late EmployeeService service;

  setUp(() async {
    // Khởi tạo mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Khởi tạo database in-memory để chạy test độc lập cô lập
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    
    service = EmployeeServiceImpl(db);
    await service.seedDefaultData();
  });

  tearDown(() async {
    await db.close();
  });

  group('EmployeeService - Đăng nhập (Authentication)', () {
    test('Đăng nhập thành công với thông tin đúng của EMP001', () async {
      final success = await service.login('EMP001', 'password123');
      expect(success, isTrue);

      final currentId = await service.getCurrentEmployeeId();
      expect(currentId, equals('EMP001'));
    });

    test('Đăng nhập thành công với thông tin đúng của Vinh Phan (305629) và có quyền admin', () async {
      final success = await service.login('305629', 'password123');
      expect(success, isTrue);

      final currentId = await service.getCurrentEmployeeId();
      expect(currentId, equals('305629'));

      // Check admin/manager permission
      expect(await service.hasPermission('305629', 'addRoom'), isTrue);
      expect(await service.hasPermission('305629', 'createJob'), isTrue);
    });

    test('Thêm nhân viên mới (Manager/Supervisor) với mật khẩu tùy chỉnh và đăng nhập thành công', () async {
      final repo = MushroomsRepository(db);
      await repo.addEmployee('SUP888', 'Nam Tran (Supervisor)', 'Supervisor', 'Growing', 'mypassword123');

      final success = await service.login('sup888', 'mypassword123');
      expect(success, isTrue);

      final currentId = await service.getCurrentEmployeeId();
      expect(currentId, equals('SUP888'));
      expect(await service.hasPermission('SUP888', 'approveMaintenanceRequest'), isTrue);
    });

    test('Đăng nhập thất bại khi sai mật khẩu', () async {
      final success = await service.login('EMP001', 'wrong_pass');
      expect(success, isFalse);
    });

    test('Đăng nhập thất bại khi tài khoản không tồn tại', () async {
      final success = await service.login('EMP999', 'password123');
      expect(success, isFalse);
    });
  });

  group('EmployeeService - Phân quyền kế thừa (RBAC Roles)', () {
    test('EMP001 (Manager) có toàn quyền các thao tác nghiệp vụ', () async {
      expect(await service.hasPermission('EMP001', 'addRoom'), isTrue);
      expect(await service.hasPermission('EMP001', 'createJob'), isTrue);
      expect(await service.hasPermission('EMP001', 'updateJobStatus'), isTrue);
      expect(await service.hasPermission('EMP001', 'useChat'), isTrue);
    });

    test('EMP004 (Picker) không có quyền addRoom hoặc createJob', () async {
      expect(await service.hasPermission('EMP004', 'addRoom'), isFalse);
      expect(await service.hasPermission('EMP004', 'createJob'), isFalse);
    });

    test('EMP004 (Picker) có quyền updateJobStatus và useChat', () async {
      expect(await service.hasPermission('EMP004', 'updateJobStatus'), isTrue);
      expect(await service.hasPermission('EMP004', 'useChat'), isTrue);
    });
  });

  group('EmployeeService - Ngoại lệ phân quyền (Overrides)', () {
    test('Chèn đè ALLOW giúp Picker thực hiện được thao tác bị cấm', () async {
      // Mặc định Picker không được phép addRoom
      expect(await service.hasPermission('EMP004', 'addRoom'), isFalse);

      // Thiết lập override ALLOW
      await service.setPermissionOverride(
        employeeId: 'EMP004',
        permissionKey: 'addRoom',
        overrideType: 'allow',
      );

      // Xác nhận sau khi override đã được phép
      expect(await service.hasPermission('EMP004', 'addRoom'), isTrue);
    });

    test('Chèn đè DENY tước quyền của Manager đối với thao tác cụ thể', () async {
      // Mặc định Manager có quyền addRoom
      expect(await service.hasPermission('EMP001', 'addRoom'), isTrue);

      // Thiết lập override DENY
      await service.setPermissionOverride(
        employeeId: 'EMP001',
        permissionKey: 'addRoom',
        overrideType: 'deny',
      );

      // Xác nhận sau khi override đã bị cấm
      expect(await service.hasPermission('EMP001', 'addRoom'), isFalse);
    });

    test('Xóa Override khôi phục lại quyền mặc định của Role', () async {
      // Cấm Manager
      await service.setPermissionOverride(
        employeeId: 'EMP001',
        permissionKey: 'addRoom',
        overrideType: 'deny',
      );
      expect(await service.hasPermission('EMP001', 'addRoom'), isFalse);

      // Reset override về none
      await service.setPermissionOverride(
        employeeId: 'EMP001',
        permissionKey: 'addRoom',
        overrideType: 'none',
      );

      // Trở lại quyền mặc định (True)
      expect(await service.hasPermission('EMP001', 'addRoom'), isTrue);
    });
  });
}
