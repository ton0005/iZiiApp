import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class HarvestPlanExcelService {
  /// Converts XLSX binary file bytes to CSV string format
  String convertXlsxBytesToCsvString(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Extract Shared Strings Table
      final List<String> sharedStrings = [];
      final sharedStringsFile = archive.firstWhere(
        (f) => f.name == 'xl/sharedStrings.xml',
        orElse: () => ArchiveFile('', 0, []),
      );

      if (sharedStringsFile.name == 'xl/sharedStrings.xml') {
        final content = String.fromCharCodes(sharedStringsFile.content as List<int>);
        final siRegex = RegExp(r'<si>(.*?)</si>', dotAll: true);
        final tRegex = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);

        for (final siMatch in siRegex.allMatches(content)) {
          final siInner = siMatch.group(1) ?? '';
          final StringBuffer sb = StringBuffer();
          for (final tMatch in tRegex.allMatches(siInner)) {
            sb.write(tMatch.group(1) ?? '');
          }
          sharedStrings.add(_unescapeXml(sb.toString()));
        }
      }

      // 2. Extract Sheet 1 XML
      final sheetFile = archive.firstWhere(
        (f) => f.name == 'xl/worksheets/sheet1.xml',
        orElse: () => ArchiveFile('', 0, []),
      );

      if (sheetFile.name != 'xl/worksheets/sheet1.xml') {
        return '';
      }

      final sheetXml = String.fromCharCodes(sheetFile.content as List<int>);
      final StringBuffer csvBuffer = StringBuffer();

      final rowRegex = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
      final cellRegex = RegExp(r'<c\s+r="([A-Z]+)(\d+)"([^>]*)>(.*?)</c>', dotAll: true);

      for (final rowMatch in rowRegex.allMatches(sheetXml)) {
        final rowContent = rowMatch.group(1) ?? '';
        final Map<int, String> rowCells = {};
        int maxColIndex = 0;

        for (final cellMatch in cellRegex.allMatches(rowContent)) {
          final colLetter = cellMatch.group(1) ?? 'A';
          final cellAttrs = cellMatch.group(3) ?? '';
          final cellInner = cellMatch.group(4) ?? '';

          final colIndex = _colLetterToIndex(colLetter);
          if (colIndex > maxColIndex) maxColIndex = colIndex;

          String value = '';
          final isSharedString = cellAttrs.contains('t="s"');
          final isInlineString = cellAttrs.contains('t="inlineStr"');

          if (isSharedString) {
            final vMatch = RegExp(r'<v>(.*?)</v>').firstMatch(cellInner);
            if (vMatch != null) {
              final idx = int.tryParse(vMatch.group(1) ?? '') ?? -1;
              if (idx >= 0 && idx < sharedStrings.length) {
                value = sharedStrings[idx];
              }
            }
          } else if (isInlineString) {
            final tMatch = RegExp(r'<t[^>]*>(.*?)</t>').firstMatch(cellInner);
            if (tMatch != null) {
              value = _unescapeXml(tMatch.group(1) ?? '');
            }
          } else {
            final vMatch = RegExp(r'<v>(.*?)</v>').firstMatch(cellInner);
            if (vMatch != null) {
              value = _unescapeXml(vMatch.group(1) ?? '');
            }
          }

          rowCells[colIndex] = value.trim();
        }

        if (rowCells.isNotEmpty) {
          final List<String> lineValues = [];
          for (int c = 0; c <= maxColIndex; c++) {
            lineValues.add(rowCells[c] ?? '');
          }
          csvBuffer.writeln(lineValues.join(','));
        }
      }

      return csvBuffer.toString();
    } catch (e) {
      return '';
    }
  }

  int _colLetterToIndex(String letter) {
    int index = 0;
    for (int i = 0; i < letter.length; i++) {
      index = index * 26 + (letter.codeUnitAt(i) - 65 + 1);
    }
    return index - 1;
  }

  String _unescapeXml(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
  /// Generate clean, Excel-compatible CSV string matching Costa Mushroom Monarto Harvesting Plan sheet
  String generatePlanCsvString(Map<String, dynamic> planData) {
    final StringBuffer sb = StringBuffer();

    final planId = (planData['id'] ?? 'PLAN_20260724').toString();
    final zoneId = (planData['zoneId'] ?? 'M2').toString();
    final status = (planData['status'] ?? 'published').toString().toUpperCase();
    final totalBoxes = (planData['totalTargetBoxes'] ?? 42374).toString();
    final createdBy = (planData['createdBy'] ?? 'Manager').toString();

    DateTime planDate;
    if (planData['planDate'] is DateTime) {
      planDate = planData['planDate'] as DateTime;
    } else if (planData['planDate'] != null) {
      planDate = DateTime.tryParse(planData['planDate'].toString()) ?? DateTime(2026, 7, 24);
    } else {
      planDate = DateTime(2026, 7, 24);
    }

    final dateStr = '${planDate.day.toString().padLeft(2, '0')}/${planDate.month.toString().padLeft(2, '0')}/${planDate.year}';

    // 1. Header Metadata Section
    sb.writeln('HARVESTING PLAN,Date: $dateStr,Zone: $zoneId,Status: $status,Total Boxes: $totalBoxes,Created By: $createdBy');
    sb.writeln('Plan ID:,$planId,,,,');
    sb.writeln();

    // 2. Shift Roster & Personnel Summary Section
    sb.writeln('SHIFT ROSTER & PERSONNEL ASSIGNMENTS,,,,,');
    sb.writeln('SUPERVISOR,SHED PLAN,TEAM LEADER,SHED PLAN,BOX MOVER (D/S),BOX MOVER (A/N)');
    sb.writeln('07:00 Delwar,M2,06:30 Shiplu,24/26/23,08:30 Bohdan,22:00 Rose');
    sb.writeln('12:00 Gurpreet,M1,06:30 Birdi,50/51/48,10:00 Efraim,23:00 Tiva');
    sb.writeln('04:45 Thong,,06:30 Rakesh,41/42/43/63,10:00 Marcell,21:00 Jackson');
    sb.writeln(',,06:00 Karen,30/3,09:00 Wilson,23:00 Nicholas');
    sb.writeln(',,06:30 Anab,22/16,05:00 Hugo,23:00 Brian');
    sb.writeln(',,06:30 RUPING,52/52A,08:00 Ismar,23:00 Simon');
    sb.writeln();

    // 3. Picker Teams & Speed Rates (Rate W kg/h)
    sb.writeln('PICKER TEAMS & ESTIMATED SPEED (RATE W kg/hr),,,,,');
    sb.writeln('TEAM,RATE W (kg/h),HEADCOUNT (H.V),TEAM,RATE W (kg/h),HEADCOUNT (H.V)');
    sb.writeln('MANGO,28.5,2,GREY,31.9,8');
    sb.writeln('LIME,31.5,8,AMBER,31.4,6');
    sb.writeln('PEACH,30.3,8,SAPPHIRE,35.6,8');
    sb.writeln('BLACK,29.8,8,PEARL,36.6,8');
    sb.writeln('PURPLE,31.5,8,APPLE,30.3,8');
    sb.writeln('IVORY,28.7,8,PINK,32.8,1');
    sb.writeln('YELLOW,31.0,7,RUBY,37.3,7');
    sb.writeln('JADE,36.0,8,ALPHA,32.8,8');
    sb.writeln('INDIGO,34.5,7,OPAL,28.3,7');
    sb.writeln('SUNSHINE,25.4,8,VENUS,24.1,8');
    sb.writeln();

    // 4. Detailed Room Allocations Table
    sb.writeln('DETAILED ROOM HARVESTING ALLOCATIONS,,,,,');
    sb.writeln('ROOM#,FLUSH,BOXES,TROLLEY,TEAMS,PROFILE,PICKING INSTRUCTIONS');

    final List assignments = planData['assignments'] as List? ?? [];
    if (assignments.isEmpty) {
      // Default sample rows if assignments empty
      sb.writeln('Room 3,1,1000,16,IVORY X 8 + PEARL X 8,PP-500,CLUMPS (WASH TROLLEYS)');
      sb.writeln('Room 24,2,600,16,PURPLE X 8,PP-500,55 50 Soft??');
      sb.writeln('Room 26,2,800,16,SAPPHIRE X 8 + INDIGO X 7,M1-500,Check One Box');
      sb.writeln('Room 42,2,1000,16,RUBY X 7,PP-200,55 30 Keep moving bigger one from T/A');
      sb.writeln('Room 50,1,1400,16,JADE X 8 + AMBER X 6,M1-500,MYCOSENSE INSTRUCTION: 6 1 7');
      sb.writeln('Room 51,1,1200,16,VENUS X 8 + LIME X 8,M1-500,MYCOSENSE INSTRUCTION: 6 1 7');
      sb.writeln('Room 52,1,600,8,BLACK X 8,M1-500,MYCOSENSE INSTRUCTION: 5 7');
    } else {
      for (final a in assignments) {
        final rName = (a['roomName'] ?? a['roomId'] ?? 'Room 1').toString();
        final flush = (a['flush'] ?? 1).toString();
        final boxes = (a['boxTarget'] ?? a['boxes'] ?? 600).toString();
        final trolleys = (a['trolleyCount'] ?? a['trolley'] ?? 8).toString();

        String teamStr = 'PURPLE';
        if (a['teams'] is String) {
          teamStr = a['teams'].toString();
        } else if (a['teams'] is List && (a['teams'] as List).isNotEmpty) {
          teamStr = (a['teams'] as List).map((t) => t['teamColor'] ?? t.toString()).join(' & ');
        }

        String instrStr = 'Standard harvesting';
        if (a['instructions'] is String) {
          instrStr = a['instructions'].toString();
        } else if (a['instructions'] is List && (a['instructions'] as List).isNotEmpty) {
          instrStr = (a['instructions'] as List).first.toString();
        }

        // Sanitize commas to prevent CSV breakage
        final cleanRoom = rName.replaceAll(',', ' ');
        final cleanTeams = teamStr.replaceAll(',', ' ');
        final cleanInstr = instrStr.replaceAll(',', ' ');

        sb.writeln('$cleanRoom,$flush,$boxes,$trolleys,$cleanTeams,PP-500,$cleanInstr');
      }
    }

    return sb.toString();
  }

  /// Exports Harvest Plan to a local `.csv` file
  Future<File> exportPlanToCsvFile(Map<String, dynamic> planData) async {
    final csvContent = generatePlanCsvString(planData);
    final Directory dir = await getApplicationDocumentsDirectory();
    final planId = (planData['id'] ?? 'PLAN_${DateTime.now().millisecondsSinceEpoch}').toString();
    final String path = '${dir.path}/HarvestPlan_$planId.csv';
    final File file = File(path);
    await file.writeAsString(csvContent);
    return file;
  }

  /// Parses CSV string content imported from Excel file
  List<Map<String, dynamic>> parsePlanFromCsvContent(String csvContent) {
    final List<Map<String, dynamic>> assignments = [];
    final lines = csvContent.split('\n');

    bool inAllocationsTable = false;

    for (var line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      if (cleanLine.contains('DETAILED ROOM HARVESTING ALLOCATIONS')) {
        inAllocationsTable = true;
        continue;
      }

      if (inAllocationsTable) {
        if (cleanLine.startsWith('ROOM#') || cleanLine.startsWith('Room#')) {
          continue; // Skip header row
        }

        final parts = cleanLine.split(',');
        if (parts.length >= 3) {
          final roomRaw = parts[0].trim();
          if (roomRaw.toLowerCase().startsWith('room') || RegExp(r'^\d+$').hasMatch(roomRaw)) {
            String roomName = roomRaw;
            if (!roomName.toLowerCase().startsWith('room')) {
              roomName = 'Room $roomName';
            }

            final flush = int.tryParse(parts.length > 1 ? parts[1].trim() : '1') ?? 1;
            final boxes = int.tryParse(parts.length > 2 ? parts[2].trim() : '600') ?? 600;
            final trolleys = int.tryParse(parts.length > 3 ? parts[3].trim() : '8') ?? 8;
            final teams = parts.length > 4 && parts[4].trim().isNotEmpty ? parts[4].trim() : 'PURPLE';
            final instr = parts.length > 6 && parts[6].trim().isNotEmpty
                ? parts[6].trim()
                : (parts.length > 5 && parts[5].trim().isNotEmpty ? parts[5].trim() : 'Standard harvesting');

            assignments.add({
              'roomName': roomName,
              'flush': flush,
              'boxTarget': boxes,
              'trolleyCount': trolleys,
              'teams': teams,
              'headcount': 8,
              'instructions': instr,
            });
          }
        }
      }
    }

    // Fallback parser if no explicit section header was found
    if (assignments.isEmpty) {
      for (var line in lines) {
        final parts = line.trim().split(',');
        if (parts.length >= 3 && (parts[0].toLowerCase().startsWith('room') || RegExp(r'^\d+$').hasMatch(parts[0].trim()))) {
          String roomName = parts[0].trim();
          if (!roomName.toLowerCase().startsWith('room')) {
            roomName = 'Room $roomName';
          }
          final flush = int.tryParse(parts.length > 1 ? parts[1].trim() : '1') ?? 1;
          final boxes = int.tryParse(parts.length > 2 ? parts[2].trim() : '600') ?? 600;
          final trolleys = int.tryParse(parts.length > 3 ? parts[3].trim() : '8') ?? 8;
          final teams = parts.length > 4 ? parts[4].trim() : 'PURPLE';
          final instr = parts.length > 5 ? parts[5].trim() : 'Standard harvesting';

          assignments.add({
            'roomName': roomName,
            'flush': flush,
            'boxTarget': boxes,
            'trolleyCount': trolleys,
            'teams': teams,
            'headcount': 8,
            'instructions': instr,
          });
        }
      }
    }

    return assignments;
  }

  /// Generates a downloadable sample Excel CSV template
  Future<File> generateSampleExcelTemplate() async {
    final sampleData = {
      'id': 'SAMPLE_HARVEST_PLAN_TEMPLATE',
      'zoneId': 'M2',
      'status': 'published',
      'totalTargetBoxes': 42374,
      'createdBy': 'Manager',
      'planDate': DateTime(2026, 7, 24),
      'assignments': [
        {'roomName': 'Room 3', 'flush': 1, 'boxTarget': 1000, 'trolleyCount': 16, 'teams': 'IVORY X 8 + PEARL X 8', 'instructions': 'CLUMPS (WASH TROLLEYS)'},
        {'roomName': 'Room 24', 'flush': 2, 'boxTarget': 600, 'trolleyCount': 16, 'teams': 'PURPLE X 8', 'instructions': '55 50 Soft??'},
        {'roomName': 'Room 26', 'flush': 2, 'boxTarget': 800, 'trolleyCount': 16, 'teams': 'SAPPHIRE X 8 + INDIGO X 7', 'instructions': 'Check One Box'},
        {'roomName': 'Room 42', 'flush': 2, 'boxTarget': 1000, 'trolleyCount': 16, 'teams': 'RUBY X 7', 'instructions': '55 30 Keep moving bigger one from T/A'},
        {'roomName': 'Room 50', 'flush': 1, 'boxTarget': 1400, 'trolleyCount': 16, 'teams': 'JADE X 8 + AMBER X 6', 'instructions': 'MYCOSENSE INSTRUCTION: 6 1 7'},
        {'roomName': 'Room 51', 'flush': 1, 'boxTarget': 1200, 'trolleyCount': 16, 'teams': 'VENUS X 8 + LIME X 8', 'instructions': 'MYCOSENSE INSTRUCTION: 6 1 7'},
        {'roomName': 'Room 52', 'flush': 1, 'boxTarget': 600, 'trolleyCount': 8, 'teams': 'BLACK X 8', 'instructions': 'MYCOSENSE INSTRUCTION: 5 7'},
      ],
    };
    return exportPlanToCsvFile(sampleData);
  }

  // === PICKER TEAMS IMPORT & EXPORT ===

  /// Generates CSV string for Picker Teams & Speed Rates matching official sample
  String generatePickerTeamsCsvString(List<Map<String, dynamic>> teamsData) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('TEAM,RATE W (kg/h),HEADCOUNT (H.V)');

    if (teamsData.isEmpty) {
      // Default sample rows matching sample file
      final sampleTeams = [
        {'name': 'MANGO', 'rate': 28.5, 'headcount': 2},
        {'name': 'LIME', 'rate': 31.5, 'headcount': 8},
        {'name': 'PEACH', 'rate': 30.3, 'headcount': 8},
        {'name': 'BLACK', 'rate': 29.8, 'headcount': 8},
        {'name': 'PURPLE', 'rate': 31.5, 'headcount': 8},
        {'name': 'IVORY', 'rate': 28.7, 'headcount': 8},
        {'name': 'YELLOW', 'rate': 31.0, 'headcount': 7},
        {'name': 'JADE', 'rate': 36.0, 'headcount': 8},
        {'name': 'INDIGO', 'rate': 34.5, 'headcount': 7},
        {'name': 'SUNSHINE', 'rate': 25.4, 'headcount': 8},
        {'name': 'GREY', 'rate': 31.9, 'headcount': 8},
        {'name': 'AMBER', 'rate': 31.4, 'headcount': 6},
        {'name': 'SAPPHIRE', 'rate': 35.6, 'headcount': 8},
        {'name': 'PEARL', 'rate': 36.6, 'headcount': 8},
        {'name': 'APPLE', 'rate': 30.3, 'headcount': 8},
        {'name': 'PINK', 'rate': 32.8, 'headcount': 1},
        {'name': 'RUBY', 'rate': 37.3, 'headcount': 7},
        {'name': 'ALPHA', 'rate': 32.8, 'headcount': 8},
        {'name': 'OPAL', 'rate': 28.3, 'headcount': 7},
        {'name': 'VENUS', 'rate': 24.1, 'headcount': 8},
      ];
      for (final t in sampleTeams) {
        sb.writeln('${t['name']},${t['rate']},${t['headcount']}');
      }
    } else {
      for (final t in teamsData) {
        final name = (t['name'] ?? t['colorCode'] ?? t['team'] ?? 'TEAM').toString().replaceAll(',', ' ').trim();
        final rate = (t['rate'] ?? t['rateEstimate'] ?? 30.0).toString();
        final headcount = (t['headcount'] ?? 8).toString();
        sb.writeln('$name,$rate,$headcount');
      }
    }

    return sb.toString();
  }

  /// Exports Picker Teams to local `.csv` file
  Future<File> exportPickerTeamsToCsvFile(List<Map<String, dynamic>> teamsData) async {
    final csvContent = generatePickerTeamsCsvString(teamsData);
    final Directory dir = await getApplicationDocumentsDirectory();
    final String path = '${dir.path}/PICKER_TEAMS_ESTIMATED_SPEED.csv';
    final File file = File(path);
    await file.writeAsString(csvContent);
    return file;
  }

  /// Parses CSV string imported from Picker Teams Excel file
  List<Map<String, dynamic>> parsePickerTeamsFromCsvContent(String csvContent) {
    final List<Map<String, dynamic>> teams = [];
    final lines = csvContent.split('\n');

    for (var line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      if (cleanLine.startsWith('TEAM') || cleanLine.startsWith('Team')) {
        continue; // Skip header row
      }

      final parts = cleanLine.split(',');
      if (parts.isNotEmpty) {
        final name = parts[0].trim().toUpperCase();
        if (name.isNotEmpty) {
          final rate = double.tryParse(parts.length > 1 ? parts[1].trim() : '30.0') ?? 30.0;
          final headcount = int.tryParse(parts.length > 2 ? parts[2].trim() : '8') ?? 8;

          teams.add({
            'name': name,
            'colorCode': name,
            'rate': rate,
            'rateEstimate': rate,
            'headcount': headcount,
          });
        }
      }
    }

    return teams;
  }
}
