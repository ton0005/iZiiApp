import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/grow_room_service.dart';
import '../services/job_list_service.dart';

// === EVENTS ===

abstract class MushroomsEvent {}

class LoadRoomsEvent extends MushroomsEvent {}

class LoadRoomDetailsEvent extends MushroomsEvent {
  final String roomId;
  LoadRoomDetailsEvent(this.roomId);
}

class StartCycleEvent extends MushroomsEvent {
  final String roomId;
  final String? wateringPlan;
  final String? prochlorazRate;
  StartCycleEvent(this.roomId, {this.wateringPlan, this.prochlorazRate});
}

class AddSoloJobEvent extends MushroomsEvent {
  final String roomId;
  final String title;
  final String assignee;
  final int timeLimit;
  final double? coLevel;
  final double? co2Level;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  AddSoloJobEvent({
    required this.roomId,
    required this.title,
    required this.assignee,
    required this.timeLimit,
    this.coLevel,
    this.co2Level,
    this.checkInTime,
    this.checkOutTime,
  });
}

class CompleteJobEvent extends MushroomsEvent {
  final String jobId;
  final String roomId;
  CompleteJobEvent(this.jobId, this.roomId);
}

class UpdateJobStatusEvent extends MushroomsEvent {
  final String jobId;
  final String roomId;
  final String newStatus;
  UpdateJobStatusEvent(this.jobId, this.roomId, this.newStatus);
}

class CreateCustomJobEvent extends MushroomsEvent {
  final String roomId;
  final String name;
  final String jobType;
  final String assignee;
  final String priority;
  final DateTime? scheduledAt;
  final String? planDetails;
  final String? prochlorazRate;
  final String? notes;
  final String? projectName;

  CreateCustomJobEvent({
    required this.roomId,
    required this.name,
    required this.jobType,
    required this.assignee,
    required this.priority,
    this.scheduledAt,
    this.planDetails,
    this.prochlorazRate,
    this.notes,
    this.projectName,
  });
}

class CheckAlarmsEvent extends MushroomsEvent {}

class CreateCustomRoomEvent extends MushroomsEvent {
  final String name;
  CreateCustomRoomEvent(this.name);
}

class CheckInSoloJobEvent extends MushroomsEvent {
  final String jobId;
  final String roomId;
  CheckInSoloJobEvent(this.jobId, this.roomId);
}

class DismissActiveAlarmsEvent extends MushroomsEvent {}

class ResetRoomEvent extends MushroomsEvent {
  final String roomId;
  ResetRoomEvent(this.roomId);
}

class RoomsUpdatedEvent extends MushroomsEvent {
  final List<Map<String, dynamic>> rooms;
  RoomsUpdatedEvent(this.rooms);
}

class RoomJobsUpdatedEvent extends MushroomsEvent {
  final String roomId;
  final List<Map<String, dynamic>> jobs;
  RoomJobsUpdatedEvent(this.roomId, this.jobs);
}

// === STATE ===

class MushroomsState {
  final List<Map<String, dynamic>> rooms;
  final String? selectedRoomId;
  final List<Map<String, dynamic>> selectedRoomJobs;
  final bool isLoading;
  final String? error;
  final bool alarmActive;

  MushroomsState({
    this.rooms = const [],
    this.selectedRoomId,
    this.selectedRoomJobs = const [],
    this.isLoading = false,
    this.error,
    this.alarmActive = false,
  });

  MushroomsState copyWith({
    List<Map<String, dynamic>>? rooms,
    String? selectedRoomId,
    List<Map<String, dynamic>>? selectedRoomJobs,
    bool? isLoading,
    String? error,
    bool? alarmActive,
  }) {
    return MushroomsState(
      rooms: rooms ?? this.rooms,
      selectedRoomId: selectedRoomId ?? this.selectedRoomId,
      selectedRoomJobs: selectedRoomJobs ?? this.selectedRoomJobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      alarmActive: alarmActive ?? this.alarmActive,
    );
  }
}

// === BLOC ===

class MushroomsBloc extends Bloc<MushroomsEvent, MushroomsState> {
  final GrowRoomService _roomService;
  final JobListService _jobService;
  Timer? _alarmCheckTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _roomsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _jobsSubscription;

  MushroomsBloc({GrowRoomService? roomService, JobListService? jobService})
      : _roomService = roomService ?? GrowRoomServiceImpl(),
        _jobService = jobService ?? JobListServiceImpl(),
        super(MushroomsState()) {
    on<LoadRoomsEvent>(_onLoadRooms);
    on<LoadRoomDetailsEvent>(_onLoadRoomDetails);
    on<RoomsUpdatedEvent>(_onRoomsUpdated);
    on<RoomJobsUpdatedEvent>(_onRoomJobsUpdated);
    on<StartCycleEvent>(_onStartCycle);
    on<AddSoloJobEvent>(_onAddSoloJob);
    on<CompleteJobEvent>(_onCompleteJob);
    on<UpdateJobStatusEvent>(_onUpdateJobStatus);
    on<CreateCustomJobEvent>(_onCreateCustomJob);
    on<CheckAlarmsEvent>(_onCheckAlarms);
    on<CreateCustomRoomEvent>(_onCreateCustomRoom);
    on<CheckInSoloJobEvent>(_onCheckInSoloJob);
    on<DismissActiveAlarmsEvent>(_onDismissActiveAlarms);
    on<ResetRoomEvent>(_onResetRoom);

    // Setup periodic background check for solo job alarms (every 30 seconds)
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      add(CheckAlarmsEvent());
    });
  }

  Future<void> _onLoadRooms(LoadRoomsEvent event, Emitter<MushroomsState> emit) async {
    _roomsSubscription?.cancel();
    _roomsSubscription = _roomService.watchRooms().listen((rooms) {
      add(RoomsUpdatedEvent(rooms));
    });
    final alarmActive = await _jobService.isAnySoloAlarmActive();
    emit(state.copyWith(alarmActive: alarmActive));
  }

  Future<void> _onLoadRoomDetails(LoadRoomDetailsEvent event, Emitter<MushroomsState> emit) async {
    _jobsSubscription?.cancel();
    _jobsSubscription = _jobService.watchJobsByRoom(event.roomId).listen((jobs) {
      add(RoomJobsUpdatedEvent(event.roomId, jobs));
    });
    final alarmActive = await _jobService.isAnySoloAlarmActive();
    emit(state.copyWith(
      selectedRoomId: event.roomId,
      alarmActive: alarmActive,
    ));
  }

  void _onRoomsUpdated(RoomsUpdatedEvent event, Emitter<MushroomsState> emit) {
    emit(state.copyWith(rooms: event.rooms));
  }

  void _onRoomJobsUpdated(RoomJobsUpdatedEvent event, Emitter<MushroomsState> emit) {
    if (event.roomId == state.selectedRoomId) {
      emit(state.copyWith(selectedRoomJobs: event.jobs));
    }
  }

  Future<void> _onStartCycle(StartCycleEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _roomService.startNewCycle(
        event.roomId,
        wateringPlan: event.wateringPlan,
        prochlorazRate: event.prochlorazRate,
      );
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onAddSoloJob(AddSoloJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.addSpecialSoloJob(
        event.roomId,
        event.title,
        event.assignee,
        event.timeLimit,
        coLevel: event.coLevel,
        co2Level: event.co2Level,
        checkInTime: event.checkInTime,
        checkOutTime: event.checkOutTime,
      );
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCompleteJob(CompleteJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.completeJob(event.jobId);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCheckAlarms(CheckAlarmsEvent event, Emitter<MushroomsState> emit) async {
    try {
      await _jobService.checkSoloJobsAlarms();
      final alarmActive = await _jobService.isAnySoloAlarmActive();
      emit(state.copyWith(alarmActive: alarmActive));
    } catch (_) {}
  }

  Future<void> _onCreateCustomRoom(CreateCustomRoomEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _roomService.addRoom(name: event.name, plantName: 'Plant M2');
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onUpdateJobStatus(UpdateJobStatusEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.updateJobStatus(event.jobId, event.newStatus);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCheckInSoloJob(CheckInSoloJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.checkInSoloJob(event.jobId);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onDismissActiveAlarms(DismissActiveAlarmsEvent event, Emitter<MushroomsState> emit) async {
    try {
      final activeTriggeredJobs = await _jobService.getActiveTriggeredSoloJobs();
      for (var job in activeTriggeredJobs) {
        await _jobService.checkInSoloJob(job['id']);
      }
      final alarmActive = await _jobService.isAnySoloAlarmActive();
      emit(state.copyWith(alarmActive: alarmActive));
    } catch (_) {}
  }

  Future<void> _onCreateCustomJob(CreateCustomJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.addCustomMushroomJob(
        roomId: event.roomId,
        name: event.name,
        jobType: event.jobType,
        assignee: event.assignee,
        priority: event.priority,
        scheduledAt: event.scheduledAt,
        planDetails: event.planDetails,
        prochlorazRate: event.prochlorazRate,
        notes: event.notes,
        projectName: event.projectName,
      );
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onResetRoom(ResetRoomEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _roomService.resetRoom(event.roomId);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  @override
  Future<void> close() {
    _alarmCheckTimer?.cancel();
    _roomsSubscription?.cancel();
    _jobsSubscription?.cancel();
    return super.close();
  }
}
