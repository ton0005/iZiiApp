// lib/modules/mushrooms/services/job_list_service.dart

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/core/sync/sync_service.dart';
import 'package:izii_app/modules/mushrooms/repository.dart';
import 'package:izii_app/core/session/work_session_service.dart';
import 'employee_service.dart';

abstract class JobListService {
  /// Stream of all jobs.
  Stream<List<Map<String, dynamic>>> watchJobs();

  /// Stream of jobs for a specific grow room.
  Stream<List<Map<String, dynamic>>> watchJobsByRoom(String roomId);

  /// Stream of jobs filtered by status/stage (e.g. pending, in_progress, review, completed).
  Stream<List<Map<String, dynamic>>> watchJobsByStage(String status);

  /// Retrieve all jobs.
  Future<List<Map<String, dynamic>>> getJobs();

  /// Retrieve jobs for a specific room.
  Future<List<Map<String, dynamic>>> getJobsByRoom(String roomId);

  /// Add a new job to general queue.
  Future<void> createJob(Map<String, dynamic> jobData);

  /// Add a job to a specific grow room, automatically calculating priority/sequence.
  Future<void> addJobToRoom({required String roomId, required Map<String, dynamic> jobData});

  /// Updates job status and syncs linked Task status.
  /// [onTimeOverride]: allows supervisor to manually override on-time/overdue status.
  Future<void> updateJobStatus(String jobId, String status, {bool? onTimeOverride});

  /// Mark a job as completed.
  Future<void> completeJob(String jobId, {bool? onTimeOverride});

  /// Check-in or exit alone worker mode.
  Future<void> checkInSoloJob(String jobId);

  /// Check if any safety alarms are active.
  Future<bool> isAnySoloAlarmActive();

  /// Periodically check for overdue solo jobs.
  Future<void> checkSoloJobsAlarms();

  /// Get list of active triggered solo jobs.
  Future<List<Map<String, dynamic>>> getActiveTriggeredSoloJobs();

  /// Assign alone worker job with safety parameters.
  Future<void> addSpecialSoloJob(
    String roomId,
    String title,
    String assignee,
    int timeLimitMinutes, {
    double? coLevel,
    double? co2Level,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String jobType,
  });

  /// Assign custom mushroom job.
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
  });
}

class JobListServiceImpl implements JobListService {
  final AppDatabase _db;
  final EmployeeService _employeeService;
  final MushroomsRepository _repository;

  JobListServiceImpl({AppDatabase? db, EmployeeService? employeeService, MushroomsRepository? repository})
      : _db = db ?? AppDatabase(),
        _employeeService = employeeService ?? EmployeeServiceImpl(),
        _repository = repository ?? MushroomsRepository(db ?? AppDatabase());

  Map<String, dynamic> _mapJob(MushroomJob j) {
    return <String, dynamic>{
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
      'sequence': j.sequence ?? 0,
      'co_level': j.coLevel,
      'co2_level': j.co2Level,
      'check_in_time': j.checkInTime?.toIso8601String(),
      'check_out_time': j.checkOutTime?.toIso8601String(),
      'created_at': j.createdAt.toIso8601String(),
      'updated_at': j.updatedAt?.toIso8601String(),
    };
  }

  @override
  Stream<List<Map<String, dynamic>>> watchJobs() {
    return (_db.select(_db.mushroomJobs)..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
        .watch()
        .map((list) => list.map(_mapJob).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> watchJobsByRoom(String roomId) {
    return (_db.select(_db.mushroomJobs)
          ..where((tbl) => tbl.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
        .watch()
        .map((list) => list.map(_mapJob).toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> watchJobsByStage(String status) {
    return (_db.select(_db.mushroomJobs)
          ..where((tbl) => tbl.status.equals(status))
          ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
        .watch()
        .map((list) => list.map(_mapJob).toList());
  }

  @override
  Future<List<Map<String, dynamic>>> getJobs() async {
    final list = await (_db.select(_db.mushroomJobs)..orderBy([(t) => OrderingTerm(expression: t.sequence)])).get();
    return list.map(_mapJob).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getJobsByRoom(String roomId) async {
    final list = await (_db.select(_db.mushroomJobs)
          ..where((tbl) => tbl.roomId.equals(roomId))
          ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
        .get();
    return list.map(_mapJob).toList();
  }

  @override
  Future<void> createJob(Map<String, dynamic> jobData) async {
    final String roomId = jobData['room_id'] ?? '';
    await addJobToRoom(roomId: roomId, jobData: jobData);
  }

  @override
  Future<void> addJobToRoom({required String roomId, required Map<String, dynamic> jobData}) async {
    final currentEmpId = await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm = await _employeeService.hasPermission(currentEmpId, 'createJob');
    if (!hasPerm) {
      throw Exception('Employee lacks permission to create job.');
    }

    final String jobId = jobData['id'] ?? const Uuid().v4();
    final String jobType = jobData['job_type'] ?? 'watering';
    final String name = jobData['name'] ?? 'Watering Job';
    final String status = jobData['status'] ?? 'pending';
    final String? assignee = jobData['assignee'];
    final String? planDetails = jobData['plan_details'];
    final String? prochlorazRate = jobData['prochloraz_rate'];
    final String? linkedTaskId = jobData['linked_task_id'];
    final bool isSoloJob = jobData['is_solo_job'] ?? false;
    final int? timeLimitMinutes = jobData['time_limit_minutes'];
    final DateTime? scheduledAt = jobData['scheduled_at'] != null ? DateTime.tryParse(jobData['scheduled_at']) : null;
    final String? priority = jobData['priority'];
    final double? coLevel = jobData['co_level'];
    final double? co2Level = jobData['co2_level'];

    await _db.transaction(() async {
      int seq;
      final existingJobs = await (_db.select(_db.mushroomJobs)
            ..where((tbl) => tbl.roomId.equals(roomId))
            ..orderBy([(t) => OrderingTerm(expression: t.sequence)]))
          .get();

      final int? targetSeq = jobData['sequence'];
      if (targetSeq != null) {
        seq = targetSeq;
        for (final job in existingJobs) {
          if (job.sequence != null && job.sequence! >= seq) {
            await (_db.update(_db.mushroomJobs)..where((tbl) => tbl.id.equals(job.id))).write(
              MushroomJobsCompanion(
                sequence: Value(job.sequence! + 1),
                updatedAt: Value(DateTime.now()),
              ),
            );
            await SyncService().queueMutation('mushroom_jobs', 'update', {
              'id': job.id,
              'sequence': job.sequence! + 1,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }
      } else {
        final maxSeq = existingJobs.isEmpty
            ? 0
            : existingJobs.map((e) => e.sequence ?? 0).reduce((a, b) => a > b ? a : b);
        seq = maxSeq + 1;
      }

      await _db.into(_db.mushroomJobs).insertOnConflictUpdate(MushroomJob(
        id: jobId,
        roomId: roomId,
        jobType: jobType,
        name: name,
        status: status,
        assignee: assignee,
        planDetails: planDetails,
        prochlorazRate: prochlorazRate,
        linkedTaskId: linkedTaskId,
        isSoloJob: isSoloJob,
        timeLimitMinutes: timeLimitMinutes,
        scheduledAt: scheduledAt,
        priority: priority ?? 'normal',
        sequence: seq,
        coLevel: coLevel,
        co2Level: co2Level,
        createdAt: DateTime.now(),
        alarmTriggered: false,
      ));

      await SyncService().queueMutation('mushroom_jobs', 'insert', {
        'id': jobId,
        'room_id': roomId,
        'job_type': jobType,
        'name': name,
        'status': status,
        'assignee': assignee,
        'plan_details': planDetails,
        'prochloraz_rate': prochlorazRate,
        'linked_task_id': linkedTaskId,
        'is_solo_job': isSoloJob,
        'time_limit_minutes': timeLimitMinutes,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'priority': priority ?? 'normal',
        'sequence': seq,
        'co_level': coLevel,
        'co2_level': co2Level,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (status == 'in_progress' || isSoloJob || jobType == 'alone_worker') {
        final stageStr = (isSoloJob || jobType == 'alone_worker') ? 'alone_worker' : jobType;
        await (_db.update(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).write(
          GrowRoomsCompanion(
            status: const Value('active'),
            currentStage: Value(stageStr),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final roomRecord = await (_db.select(_db.growRooms)..where((tbl) => tbl.id.equals(roomId))).getSingleOrNull();
        await SyncService().queueMutation('grow_rooms', 'update', {
          'id': roomId,
          if (roomRecord?.name != null && roomRecord!.name.trim().isNotEmpty) 'name': roomRecord.name.trim(),
          'status': 'active',
          'current_stage': stageStr,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  @override
  Future<void> updateJobStatus(String jobId, String status, {bool? onTimeOverride}) async {
    final currentEmpId = await _employeeService.getCurrentEmployeeId();
    if (currentEmpId == null) {
      throw Exception('Employee not logged in.');
    }
    final hasPerm = await _employeeService.hasPermission(currentEmpId, 'updateJobStatus');
    if (!hasPerm) {
      throw Exception('Employee lacks permission to update job status.');
    }
    await _repository.updateJobStatus(jobId, status, onTimeOverride: onTimeOverride);
  }

  @override
  Future<void> completeJob(String jobId, {bool? onTimeOverride}) async {
    final currentEmpId = await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm = await _employeeService.hasPermission(currentEmpId, 'updateJobStatus');
    if (!hasPerm) {
      throw Exception('Employee lacks permission to complete job.');
    }
    await _repository.completeJob(jobId, onTimeOverride: onTimeOverride);
  }

  @override
  Future<void> checkInSoloJob(String jobId) async {
    await _repository.checkInSoloJob(jobId);
  }

  @override
  Future<bool> isAnySoloAlarmActive() async {
    return _repository.isAnySoloAlarmActive();
  }

  @override
  Future<void> checkSoloJobsAlarms() async {
    await _repository.checkSoloJobsAlarms();
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveTriggeredSoloJobs() async {
    return _repository.getActiveTriggeredSoloJobs();
  }

  @override
  Future<void> addSpecialSoloJob(
    String roomId,
    String title,
    String assignee,
    int timeLimitMinutes, {
    double? coLevel,
    double? co2Level,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String jobType = 'alone_worker',
  }) async {
    final currentEmpId = await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm = await _employeeService.hasPermission(currentEmpId, 'createJob');
    if (!hasPerm) {
      throw Exception('Employee lacks permission to create job.');
    }
    final onShift = await WorkSessionService().isPersonOnShift(assignee);
    if (!onShift) {
      throw Exception('Employee "$assignee" has not checked in for shift. Cannot assign Alone Worker job.');
    }
    await _repository.addSpecialSoloJob(
      roomId,
      title,
      assignee,
      timeLimitMinutes,
      coLevel: coLevel,
      co2Level: co2Level,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      jobType: jobType,
    );
  }

  @override
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
    final currentEmpId = await _employeeService.getCurrentEmployeeId() ?? '555555';
    final hasPerm = await _employeeService.hasPermission(currentEmpId, 'createJob');
    if (!hasPerm) {
      throw Exception('Employee lacks permission to create job.');
    }
    await _repository.addCustomMushroomJob(
      roomId: roomId,
      name: name,
      jobType: jobType,
      assignee: assignee,
      priority: priority,
      scheduledAt: scheduledAt,
      planDetails: planDetails,
      prochlorazRate: prochlorazRate,
      notes: notes,
      projectName: projectName,
    );
  }
}
