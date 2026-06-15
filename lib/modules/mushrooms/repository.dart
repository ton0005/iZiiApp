import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';

class MushroomsRepository {
  final AppDatabase _db;

  MushroomsRepository([AppDatabase? database])
      : _db = database ?? AppDatabase();

  // === SEEDING ===

  Future<void> seedRoomsIfEmpty() async {
    try {
      final countQuery = _db.select(_db.mushroomRooms);
      final count = (await countQuery.get()).length;
      if (count == 0) {
        // Seed M2 standard Rooms 33 to 66
        for (int i = 33; i <= 66; i++) {
          await _db.into(_db.mushroomRooms).insert(MushroomRoomsCompanion.insert(
            id: const Uuid().v4(),
            name: 'Room $i',
            status: const Value('idle'),
            currentStage: const Value('idle'),
            dayInCycle: const Value(1),
          ));
        }
      }
    } catch (_) {}
  }

  // === ROOMS ===

  Future<List<Map<String, dynamic>>> getRooms() async {
    await seedRoomsIfEmpty();
    final query = _db.select(_db.mushroomRooms)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    final rooms = await query.get();
    
    return rooms.map((r) => <String, dynamic>{
      'id': r.id,
      'name': r.name,
      'status': r.status,
      'current_stage': r.currentStage,
      'day_in_cycle': r.dayInCycle,
      'created_at': r.createdAt.toIso8601String(),
    }).toList();
  }

  Future<void> addNewRoom(String name) async {
    await _db.into(_db.mushroomRooms).insert(MushroomRoomsCompanion.insert(
      id: const Uuid().v4(),
      name: name,
      status: const Value('idle'),
      currentStage: const Value('idle'),
      dayInCycle: const Value(1),
    ));
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
    }).toList();
  }

  Future<void> startNewCycle(String roomId, {String? wateringPlan, String? prochlorazRate}) async {
    // 1. Update room status and stage
    await (_db.update(_db.mushroomRooms)..where((tbl) => tbl.id.equals(roomId))).write(
      MushroomRoomsCompanion(
        status: const Value('active'),
        currentStage: const Value('filling'),
        dayInCycle: const Value(1),
        updatedAt: Value(DateTime.now()),
      ),
    );

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
      await _db.into(_db.mushroomJobs).insert(MushroomJobsCompanion.insert(
        id: const Uuid().v4(),
        roomId: roomId,
        jobType: step['type']!,
        name: step['name']!,
        status: Value(isFirst ? 'in_progress' : 'pending'),
        planDetails: step['type'] == 'watering' ? Value(wateringPlan ?? '2 Side 2L/m2') : const Value.absent(),
        prochlorazRate: step['type'] == 'prochloraz' ? Value(prochlorazRate ?? '1.3g/m2') : const Value.absent(),
      ));
    }
  }

  Future<void> addSpecialSoloJob(String roomId, String title, String assignee, int timeLimitMinutes) async {
    final jobId = const Uuid().v4();
    final room = await (_db.select(_db.mushroomRooms)..where((tbl) => tbl.id.equals(roomId))).getSingleOrNull();
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
      }

      await _db.into(_db.tasks).insert(TasksCompanion.insert(
        id: taskId,
        projectId: project.id,
        title: '$title ($roomName)',
        description: Value('Công việc làm một mình (Solo) tại phòng nuôi trồng. Giới hạn: $timeLimitMinutes phút. Người thực hiện: $assignee'),
        status: const Value('in_progress'),
        priority: const Value('high'),
      ));
    } catch (_) {}

    await _db.into(_db.mushroomJobs).insert(MushroomJobsCompanion.insert(
      id: jobId,
      roomId: roomId,
      jobType: 'special_solo',
      name: title,
      status: const Value('in_progress'),
      assignee: Value(assignee),
      isSoloJob: const Value(true),
      timeLimitMinutes: Value(timeLimitMinutes),
      startedAt: Value(DateTime.now()),
      alarmTriggered: const Value(false),
      linkedTaskId: Value(taskId),
    ));

    try {
      await _db.into(_db.mushroomJobSafetyConfigs).insert(
        MushroomJobSafetyConfigsCompanion.insert(
          id: const Uuid().v4(),
          jobId: jobId,
          checkInIntervalMinutes: Value(timeLimitMinutes),
          gracePeriodMinutes: const Value(5),
          escalationTarget: const Value('supervisor'),
          autoStartOnJobBegin: const Value(true),
          alarmType: const Value('push_inapp'),
        ),
      );

      await _db.into(_db.mushroomSafetyCheckinLogs).insert(
        MushroomSafetyCheckinLogsCompanion.insert(
          id: const Uuid().v4(),
          jobId: jobId,
          workerId: assignee,
          eventType: 'start',
          notes: Value('Solo job started with limit $timeLimitMinutes mins'),
          timestamp: Value(DateTime.now()),
        ),
      );
    } catch (_) {}

    // Update room stage to special_solo & active
    await (_db.update(_db.mushroomRooms)..where((tbl) => tbl.id.equals(roomId))).write(
      const MushroomRoomsCompanion(
        status: Value('active'),
        currentStage: Value('special_solo'),
      ),
    );
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

    // Sync status back to linked project task
    if (job.linkedTaskId != null && job.linkedTaskId!.isNotEmpty) {
      String taskStatus = 'todo';
      if (newStatus == 'in_progress') taskStatus = 'in_progress';
      if (newStatus == 'review') taskStatus = 'in_progress';
      if (newStatus == 'completed') taskStatus = 'done';
      try {
        await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(job.linkedTaskId!))).write(
          TasksCompanion(status: Value(taskStatus)),
        );
      } catch (_) {}
    }

    // Update room stage if it's in_progress
    if (newStatus == 'in_progress' && !job.isSoloJob) {
      await (_db.update(_db.mushroomRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
        MushroomRoomsCompanion(
          status: const Value('active'),
          currentStage: Value(job.jobType),
          updatedAt: Value(DateTime.now()),
        ),
      );
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

    final room = await (_db.select(_db.mushroomRooms)..where((tbl) => tbl.id.equals(roomId))).getSingleOrNull();
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
      } catch (_) {}
    }

    await _db.into(_db.mushroomJobs).insert(MushroomJobsCompanion.insert(
      id: jobId,
      roomId: roomId,
      jobType: jobType,
      name: name,
      status: const Value('todo'),
      assignee: Value(assignee),
      priority: Value(priority),
      scheduledAt: Value(scheduledAt),
      planDetails: Value(planDetails),
      prochlorazRate: Value(prochlorazRate),
      linkedTaskId: Value(taskId),
    ));
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
        await (_db.update(_db.mushroomRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
          MushroomRoomsCompanion(
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
          await (_db.update(_db.mushroomRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
            const MushroomRoomsCompanion(
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
      await (_db.update(_db.mushroomRooms)..where((tbl) => tbl.id.equals(job.roomId))).write(
        const MushroomRoomsCompanion(
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
    final activeSoloJobs = await (_db.select(_db.mushroomJobs)
          ..where((tbl) => tbl.isSoloJob.equals(true) & tbl.status.equals('in_progress') & tbl.alarmTriggered.equals(false)))
        .get();

    final now = DateTime.now();
    for (var job in activeSoloJobs) {
      if (job.startedAt != null && job.timeLimitMinutes != null) {
        final elapsed = now.difference(job.startedAt!).inMinutes;
        if (elapsed >= job.timeLimitMinutes!) {
          await triggerSafetyAlarm(job.id);
        }
      }
    }
  }

  Future<bool> isAnySoloAlarmActive() async {
    try {
      final activeAlarms = await (_db.select(_db.mushroomJobs)
            ..where((tbl) => tbl.isSoloJob.equals(true) & tbl.status.equals('in_progress') & tbl.alarmTriggered.equals(true)))
          .get();
      return activeAlarms.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> incrementActiveRoomsCycleDays() async {
    final activeRooms = await (_db.select(_db.mushroomRooms)..where((tbl) => tbl.status.equals('active'))).get();
    for (var room in activeRooms) {
      await (_db.update(_db.mushroomRooms)..where((tbl) => tbl.id.equals(room.id))).write(
        MushroomRoomsCompanion(dayInCycle: Value(room.dayInCycle + 1)),
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
}
