// test/modules/mushrooms/services/mushrooms_shared_services_test.dart

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/mushrooms/services/employee_service.dart';
import 'package:izii_app/modules/mushrooms/services/grow_room_service.dart';
import 'package:izii_app/modules/mushrooms/services/job_list_service.dart';

void main() {
  late AppDatabase db;
  late EmployeeService employeeService;
  late GrowRoomService growRoomService;
  late JobListService jobListService;

  setUp(() async {
    // Setup Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // In-memory isolated database
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;

    employeeService = EmployeeServiceImpl(db);
    growRoomService = GrowRoomServiceImpl(db: db, employeeService: employeeService);
    jobListService = JobListServiceImpl(db: db, employeeService: employeeService);

    await employeeService.seedDefaultData();
  });

  tearDown(() async {
    await db.close();
  });

  group('GrowRoomService & JobListService - Reactive Streams and Auth Checks', () {
    test('addRoom requires authentication & appropriate permission (addRoom)', () async {
      // 1. Unauthenticated -> fails
      await employeeService.logout();
      expect(
        () => growRoomService.addRoom(name: 'Room 99', plantName: 'Plant M2'),
        throwsException,
      );

      // 2. Login as Picker (EMP004) -> fails (no addRoom permission by default)
      var success = await employeeService.login('EMP004', 'password123');
      expect(success, isTrue);
      expect(
        () => growRoomService.addRoom(name: 'Room 99', plantName: 'Plant M2'),
        throwsException,
      );

      // 3. Login as Manager (EMP001) -> succeeds
      success = await employeeService.login('EMP001', 'password123');
      expect(success, isTrue);
      await growRoomService.addRoom(name: 'Room 99', plantName: 'Plant M2');

      final room = await growRoomService.getRoomById('room_99');
      expect(room, isNotNull);
      expect(room!['name'], equals('Room 99'));
    });

    test('watchRooms emits updated lists reactively upon room additions', () async {
      await employeeService.login('EMP001', 'password123');
      
      final events = <List<Map<String, dynamic>>>[];
      final subscription = growRoomService.watchRooms().listen(events.add);
      
      await Future.delayed(Duration.zero);
      await growRoomService.addRoom(name: 'Room 80', plantName: 'Plant M2');
      await Future.delayed(Duration.zero);
      
      subscription.cancel();

      expect(events.length, greaterThanOrEqualTo(2));
      final lastEvent = events.last;
      final hasRoom80 = lastEvent.any((r) => r['name'] == 'Room 80');
      expect(hasRoom80, isTrue);
    });

    test('watchRoomsByPlant correctly filters and reactively watches Plant M2 rooms', () async {
      await employeeService.login('EMP001', 'password123');
      
      // Seed two rooms
      await growRoomService.addRoom(name: 'Room 12', plantName: 'Plant M1');
      await growRoomService.addRoom(name: 'Room 45', plantName: 'Plant M2');

      final plantM2List = await growRoomService.watchRoomsByPlant('Plant M2').first;
      
      final hasRoom45 = plantM2List.any((r) => r['name'] == 'Room 45');
      final hasRoom12 = plantM2List.any((r) => r['name'] == 'Room 12');

      expect(hasRoom45, isTrue);
      expect(hasRoom12, isFalse);
    });

    test('JobListService - addJobToRoom auto-calculates sequence numbers (push at the end)', () async {
      await employeeService.login('EMP001', 'password123');

      // Add three sequential jobs to a room
      await jobListService.addJobToRoom(
        roomId: 'room_33',
        jobData: {'name': 'Watering 1', 'job_type': 'watering'},
      );
      await jobListService.addJobToRoom(
        roomId: 'room_33',
        jobData: {'name': 'Watering 2', 'job_type': 'watering'},
      );
      await jobListService.addJobToRoom(
        roomId: 'room_33',
        jobData: {'name': 'Watering 3', 'job_type': 'watering'},
      );

      final jobs = await jobListService.getJobsByRoom('room_33');
      expect(jobs.length, equals(3));

      // Assert they are ordered by sequence (1, 2, 3)
      expect(jobs[0]['name'], equals('Watering 1'));
      expect(jobs[0]['sequence'], equals(1));

      expect(jobs[1]['name'], equals('Watering 2'));
      expect(jobs[1]['sequence'], equals(2));

      expect(jobs[2]['name'], equals('Watering 3'));
      expect(jobs[2]['sequence'], equals(3));
    });

    test('JobListService - addJobToRoom supports inserting job in the middle (auto-shifting)', () async {
      await employeeService.login('EMP001', 'password123');

      // 1. Seed two sequential jobs (seq 1, seq 2)
      await jobListService.addJobToRoom(
        roomId: 'room_33',
        jobData: {'name': 'Job A', 'job_type': 'watering'},
      );
      await jobListService.addJobToRoom(
        roomId: 'room_33',
        jobData: {'name': 'Job C', 'job_type': 'watering'},
      );

      // 2. Insert Job B at sequence 2 (which pushes Job C to sequence 3)
      await jobListService.addJobToRoom(
        roomId: 'room_33',
        jobData: {'name': 'Job B', 'job_type': 'watering', 'sequence': 2},
      );

      final jobs = await jobListService.getJobsByRoom('room_33');
      expect(jobs.length, equals(3));

      expect(jobs[0]['name'], equals('Job A'));
      expect(jobs[0]['sequence'], equals(1));

      expect(jobs[1]['name'], equals('Job B'));
      expect(jobs[1]['sequence'], equals(2));

      expect(jobs[2]['name'], equals('Job C'));
      expect(jobs[2]['sequence'], equals(3));
    });

    test('JobListService - updateJobStatus updates job status reactively', () async {
      await employeeService.login('EMP001', 'password123');

      await jobListService.addJobToRoom(
        roomId: 'room_33',
        jobData: {'id': 'job_x', 'name': 'Task X', 'job_type': 'watering'},
      );

      final events = <List<Map<String, dynamic>>>[];
      final subscription = jobListService.watchJobsByRoom('room_33').listen(events.add);

      await Future.delayed(Duration.zero);
      await jobListService.updateJobStatus('job_x', 'in_progress');
      await Future.delayed(Duration.zero);

      subscription.cancel();

      expect(events.length, greaterThanOrEqualTo(2));
      final lastEvent = events.last;
      final jobX = lastEvent.firstWhere((j) => j['id'] == 'job_x');
      expect(jobX['status'], equals('in_progress'));
    });
  });
}
