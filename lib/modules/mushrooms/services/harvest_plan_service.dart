import 'dart:convert';
import 'package:drift/drift.dart' as d;
import 'package:izii_app/core/database/app_database.dart';
import '../repository.dart';

class HarvestPlanService {
  final AppDatabase _db = AppDatabase();
  final MushroomsRepository _repo = MushroomsRepository();

  /// Upsert Harvest Plan, Room Assignments, and Picker Teams into SQLite
  Future<String> saveHarvestPlan({
    String? planId,
    required DateTime planDate,
    required String zoneId,
    required String status, // draft, published, in_progress, closed, rejected
    required List<Map<String, dynamic>> roomAssignments,
    List<Map<String, dynamic>>? pickerTeams,
    String? createdBy,
    String? rejectionReason,
  }) async {
    final cleanPlanId = planId ??
        'PLAN_${planDate.year}${planDate.month.toString().padLeft(2, '0')}${planDate.day.toString().padLeft(2, '0')}';

    int totalBoxes = 0;
    for (final ra in roomAssignments) {
      final boxes = (ra['boxTarget'] ?? ra['boxes'] ?? 0) as int;
      totalBoxes += boxes;
    }

    // 1. Upsert MushroomHarvestPlans
    await _db.into(_db.mushroomHarvestPlans).insertOnConflictUpdate(
          MushroomHarvestPlansCompanion.insert(
            id: cleanPlanId,
            planDate: planDate,
            zoneId: d.Value(zoneId),
            createdBy: d.Value(createdBy ?? 'Manager'),
            status: d.Value(status),
            totalTargetBoxes: d.Value(totalBoxes),
          ),
        );

    // 2. Delete existing room assignments for this plan to prevent stale entries
    await (_db.delete(_db.mushroomRoomAssignments)
          ..where((t) => t.planId.equals(cleanPlanId)))
        .go();

    // 3. Insert Room Assignments
    for (final ra in roomAssignments) {
      final roomName = ra['roomName'] ?? ra['room'] ?? ra['roomId'];
      final cleanRoom = roomName.toString().toLowerCase().replaceAll(' ', '_');
      final boxes = (ra['boxTarget'] ?? ra['boxes'] ?? 0) as int;
      final trolleys = (ra['trolleyCount'] ?? ra['trolley'] ?? 0) as int;
      final teams = ra['teams'];
      final instructions = ra['instructions'] ?? ra['instr'];

      String teamJson;
      if (teams is String) {
        teamJson = jsonEncode([
          {'teamColor': teams, 'headcount': ra['headcount'] ?? 8}
        ]);
      } else if (teams is List) {
        teamJson = jsonEncode(teams);
      } else {
        teamJson = jsonEncode([
          {'teamColor': 'PURPLE', 'headcount': 8}
        ]);
      }

      String instrJson;
      if (instructions is List) {
        instrJson = jsonEncode(instructions);
      } else if (instructions != null && instructions.toString().isNotEmpty) {
        instrJson = jsonEncode([instructions.toString()]);
      } else {
        instrJson = jsonEncode([]);
      }

      await _db.into(_db.mushroomRoomAssignments).insertOnConflictUpdate(
            MushroomRoomAssignmentsCompanion.insert(
              id: '${cleanPlanId}_$cleanRoom',
              planId: cleanPlanId,
              roomId: roomName.toString(),
              boxTarget: d.Value(boxes),
              trolleyCount: d.Value(trolleys),
              teamAssignmentsJson: d.Value(teamJson),
              pickingInstructionsJson: d.Value(instrJson),
              notes: d.Value(rejectionReason ?? ra['notes']?.toString()),
            ),
          );
    }

    // 4. Save Picker Teams if provided
    if (pickerTeams != null) {
      for (final pt in pickerTeams) {
        final teamColor = (pt['colorCode'] ?? pt['color'] ?? 'PURPLE').toString();
        final teamId = 'TEAM_${cleanPlanId}_${teamColor.toUpperCase()}';
        final members = pt['memberIdsJson'] ?? jsonEncode(pt['members'] ?? []);

        await _db.into(_db.mushroomPickerTeams).insertOnConflictUpdate(
              MushroomPickerTeamsCompanion.insert(
                id: teamId,
                planId: cleanPlanId,
                colorCode: teamColor,
                headcount: d.Value((pt['headcount'] ?? 8) as int),
                rateEstimate: d.Value((pt['rateEstimate'] ?? pt['rate'] ?? 28.5) as double),
                memberIdsJson: d.Value(members.toString()),
              ),
            );
      }
    }

    return cleanPlanId;
  }

  /// Update plan status (e.g. approve = published, reject = rejected)
  Future<void> updatePlanStatus(
    String planId,
    String status, {
    String? rejectionReason,
  }) async {
    await (_db.update(_db.mushroomHarvestPlans)
          ..where((t) => t.id.equals(planId)))
        .write(MushroomHarvestPlansCompanion(
      status: d.Value(status),
    ));

    if (rejectionReason != null) {
      final assignments = await (_db.select(_db.mushroomRoomAssignments)
            ..where((t) => t.planId.equals(planId)))
          .get();

      for (final a in assignments) {
        await (_db.update(_db.mushroomRoomAssignments)
              ..where((t) => t.id.equals(a.id)))
            .write(MushroomRoomAssignmentsCompanion(
          notes: d.Value('Rejected: $rejectionReason'),
        ));
      }
    }
  }

  /// Retrieve all Harvest Plans from SQLite
  Future<List<Map<String, dynamic>>> getHarvestPlans() async {
    final plans = await _db.select(_db.mushroomHarvestPlans).get();
    final result = <Map<String, dynamic>>[];

    for (final p in plans) {
      final assignments = await (_db.select(_db.mushroomRoomAssignments)
            ..where((t) => t.planId.equals(p.id)))
          .get();

      final teams = await (_db.select(_db.mushroomPickerTeams)
            ..where((t) => t.planId.equals(p.id)))
          .get();

      final mappedAssignments = assignments.map((a) {
        final List teamsList =
            a.teamAssignmentsJson != null ? jsonDecode(a.teamAssignmentsJson!) : [];
        final List instrList =
            a.pickingInstructionsJson != null ? jsonDecode(a.pickingInstructionsJson!) : [];

        return {
          'id': a.id,
          'roomId': a.roomId,
          'roomName': a.roomId.replaceAll('room_', 'Room '),
          'boxTarget': a.boxTarget,
          'trolleyCount': a.trolleyCount,
          'teams': teamsList,
          'instructions': instrList,
          'notes': a.notes,
        };
      }).toList();

      result.add({
        'id': p.id,
        'planDate': p.planDate,
        'zoneId': p.zoneId ?? 'M2',
        'status': p.status,
        'totalTargetBoxes': p.totalTargetBoxes,
        'createdBy': p.createdBy ?? 'Manager',
        'assignments': mappedAssignments,
        'teams': teams.map((t) => t.toJson()).toList(),
      });
    }

    return result;
  }
}
