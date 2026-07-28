import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/mushrooms/services/harvest_plan_excel_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HarvestPlanExcelService Verification', () {
    late HarvestPlanExcelService service;

    setUp(() {
      service = HarvestPlanExcelService();
    });

    test('Generates Excel-compatible CSV string with Costa Mushroom Monarto layout', () {
      final planData = {
        'id': 'PLAN_20260724',
        'zoneId': 'M2',
        'status': 'published',
        'totalTargetBoxes': 42374,
        'createdBy': 'Manager',
        'planDate': DateTime(2026, 7, 24),
        'assignments': [
          {
            'roomName': 'Room 50',
            'flush': 1,
            'boxTarget': 1400,
            'trolleyCount': 16,
            'teams': 'JADE & AMBER',
            'instructions': 'MYCOSENSE INSTRUCTION: 6 1 7',
          },
          {
            'roomName': 'Room 51',
            'flush': 1,
            'boxTarget': 1200,
            'trolleyCount': 16,
            'teams': 'VENUS & LIME',
            'instructions': 'MYCOSENSE INSTRUCTION: 6 1 7',
          },
        ],
      };

      final csvStr = service.generatePlanCsvString(planData);

      expect(csvStr, contains('HARVESTING PLAN'));
      expect(csvStr, contains('Date: 24/07/2026'));
      expect(csvStr, contains('DETAILED ROOM HARVESTING ALLOCATIONS'));
      expect(csvStr, contains('Room 50,1,1400,16,JADE & AMBER,PP-500,MYCOSENSE INSTRUCTION: 6 1 7'));
      expect(csvStr, contains('Room 51,1,1200,16,VENUS & LIME,PP-500,MYCOSENSE INSTRUCTION: 6 1 7'));
    });

    test('Parses CSV content imported from Excel file into room assignments', () {
      const mockContent = '''
HARVESTING PLAN,Date: 24/07/2026,Zone: M2,Status: PUBLISHED
DETAILED ROOM HARVESTING ALLOCATIONS,,,,,
ROOM#,FLUSH,BOXES,TROLLEY,TEAMS,PROFILE,PICKING INSTRUCTIONS
Room 3,1,1000,16,IVORY & PEARL,PP-500,CLUMPS (WASH TROLLEYS)
Room 50,1,1400,16,JADE & AMBER,M1-500,MYCOSENSE INSTRUCTION: 6 1 7
Room 52,1,600,8,BLACK,M1-500,MYCOSENSE INSTRUCTION: 5 7
''';

      final assignments = service.parsePlanFromCsvContent(mockContent);

      expect(assignments.length, equals(3));

      expect(assignments[0]['roomName'], equals('Room 3'));
      expect(assignments[0]['flush'], equals(1));
      expect(assignments[0]['boxTarget'], equals(1000));
      expect(assignments[0]['trolleyCount'], equals(16));
      expect(assignments[0]['teams'], equals('IVORY & PEARL'));
      expect(assignments[0]['instructions'], equals('CLUMPS (WASH TROLLEYS)'));

      expect(assignments[1]['roomName'], equals('Room 50'));
      expect(assignments[1]['boxTarget'], equals(1400));
      expect(assignments[1]['teams'], equals('JADE & AMBER'));

      expect(assignments[2]['roomName'], equals('Room 52'));
      expect(assignments[2]['boxTarget'], equals(600));
      expect(assignments[2]['trolleyCount'], equals(8));
    });

    test('Parses Picker Teams & Speed Rates CSV matching sample file format', () {
      const mockPickerTeamsCsv = '''
TEAM,RATE W (kg/h),HEADCOUNT (H.V)
MANGO,28.5,2
LIME,31.5,8
JADE,36.0,8
''';

      final teams = service.parsePickerTeamsFromCsvContent(mockPickerTeamsCsv);

      expect(teams.length, equals(3));
      expect(teams[0]['name'], equals('MANGO'));
      expect(teams[0]['rate'], equals(28.5));
      expect(teams[0]['headcount'], equals(2));

      expect(teams[1]['name'], equals('LIME'));
      expect(teams[1]['rate'], equals(31.5));
      expect(teams[1]['headcount'], equals(8));

      expect(teams[2]['name'], equals('JADE'));
      expect(teams[2]['rate'], equals(36.0));
      expect(teams[2]['headcount'], equals(8));
    });

    test('Generates Picker Teams & Speed Rates CSV matching sample file header', () {
      final teamsData = [
        {'name': 'MANGO', 'rate': 28.5, 'headcount': 2},
        {'name': 'LIME', 'rate': 31.5, 'headcount': 8},
      ];

      final csvStr = service.generatePickerTeamsCsvString(teamsData);

      expect(csvStr, contains('TEAM,RATE W (kg/h),HEADCOUNT (H.V)'));
      expect(csvStr, contains('MANGO,28.5,2'));
      expect(csvStr, contains('LIME,31.5,8'));
    });

    test('Decodes binary XLSX file from user directory and parses room assignments', () {
      final sampleFile = File(r'C:\Users\CHANH\OneDrive\Documents\Downloads\Window iZiiApp\UI\Harvest Plan\HarvestPlan_PLAN_20260729.xlsx');
      if (sampleFile.existsSync()) {
        final bytes = sampleFile.readAsBytesSync();
        final csvContent = service.convertXlsxBytesToCsvString(bytes);

        expect(csvContent, contains('HARVESTING PLAN'));
        expect(csvContent, contains('DETAILED ROOM HARVESTING ALLOCATIONS'));

        final assignments = service.parsePlanFromCsvContent(csvContent);
        expect(assignments.isNotEmpty, isTrue);
        expect(assignments.any((a) => a['roomName'] == 'Room 50'), isTrue);
      }
    });
  });
}
