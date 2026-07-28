import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/mushrooms/services/harvest_plan_excel_service.dart';

void main() {
  test('Full XLSX Parsing Test', () {
    final file = File(r'C:\Users\CHANH\OneDrive\Documents\Downloads\Window iZiiApp\UI\Harvest Plan\HarvestPlan_PLAN_20260729.xlsx');
    final bytes = file.readAsBytesSync();

    final service = HarvestPlanExcelService();
    final csvContent = service.convertXlsxBytesToCsvString(bytes);

    print('Converted XLSX to CSV:');
    print(csvContent);

    final assignments = service.parsePlanFromCsvContent(csvContent);
    print('\nParsed Assignments count: ${assignments.length}');
    for (final a in assignments) {
      print(' - ${a['roomName']}: ${a['boxTarget']} boxes, ${a['trolleyCount']} trolleys, teams: ${a['teams']}');
    }

    expect(assignments.isNotEmpty, isTrue);
  });
}
