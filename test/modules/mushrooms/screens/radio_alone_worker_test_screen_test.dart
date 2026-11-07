import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/mushrooms/screens/radio_alone_worker_test_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    await db.into(db.mushroomEmployees).insert(MushroomEmployeesCompanion.insert(
          id: 'EMP507', name: 'Andrew', role: 'Growing Specialist', department: const drift.Value('Growing')));
    await db.into(db.mushroomEmployees).insert(MushroomEmployeesCompanion.insert(
          id: 'EMP100', name: 'Bao', role: 'Picker'));
    await db.into(db.growRooms).insert(GrowRoomsCompanion.insert(id: 'room_6a', name: 'Room 6A'));
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('pre-selects Andrew and radio 507, shows the five steps', (tester) async {
    // Đủ cao để ListView dựng cả 5 bước.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: RadioAloneWorkerTestScreen()));
      // Đợi đọc DB cục bộ (server không có trong test: các lời gọi mạng thất bại im lặng).
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('Andrew (EMP507)'), findsOneWidget);
    expect(find.widgetWithText(TextField, '507'), findsOneWidget);
    expect(find.text('Room 6A'), findsOneWidget);
    for (final title in [
      'Check the worker in',
      'Register the radio for this shift',
      'Is Lone Worker on at the radio?',
      'Start an Alone Worker job',
      'After time out: is radio 507 notified?',
    ]) {
      expect(find.text(title, skipOffstage: false), findsOneWidget, reason: title);
    }
    expect(find.text('Start a job in step 4 first.', skipOffstage: false), findsOneWidget);

    // Gỡ màn hình để huỷ Timer định kỳ.
    await tester.pumpWidget(const SizedBox());
  });
}
