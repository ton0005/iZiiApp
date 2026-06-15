import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository.dart';

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
  AddSoloJobEvent({
    required this.roomId,
    required this.title,
    required this.assignee,
    required this.timeLimit,
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
  final MushroomsRepository _repository;
  Timer? _alarmCheckTimer;

  MushroomsBloc({MushroomsRepository? repository})
      : _repository = repository ?? MushroomsRepository(),
        super(MushroomsState()) {
    on<LoadRoomsEvent>(_onLoadRooms);
    on<LoadRoomDetailsEvent>(_onLoadRoomDetails);
    on<StartCycleEvent>(_onStartCycle);
    on<AddSoloJobEvent>(_onAddSoloJob);
    on<CompleteJobEvent>(_onCompleteJob);
    on<UpdateJobStatusEvent>(_onUpdateJobStatus);
    on<CreateCustomJobEvent>(_onCreateCustomJob);
    on<CheckAlarmsEvent>(_onCheckAlarms);
    on<CreateCustomRoomEvent>(_onCreateCustomRoom);
    on<CheckInSoloJobEvent>(_onCheckInSoloJob);
    on<DismissActiveAlarmsEvent>(_onDismissActiveAlarms);

    // Setup periodic background check for solo job alarms (every 30 seconds)
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      add(CheckAlarmsEvent());
    });
  }

  Future<void> _onLoadRooms(LoadRoomsEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final rooms = await _repository.getRooms();
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(rooms: rooms, alarmActive: alarmActive, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onLoadRoomDetails(LoadRoomDetailsEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final jobs = await _repository.getJobsForRoom(event.roomId);
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        selectedRoomId: event.roomId,
        selectedRoomJobs: jobs,
        alarmActive: alarmActive,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onStartCycle(StartCycleEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.startNewCycle(
        event.roomId,
        wateringPlan: event.wateringPlan,
        prochlorazRate: event.prochlorazRate,
      );
      final rooms = await _repository.getRooms();
      final jobs = await _repository.getJobsForRoom(event.roomId);
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomId: event.roomId,
        selectedRoomJobs: jobs,
        alarmActive: alarmActive,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onAddSoloJob(AddSoloJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.addSpecialSoloJob(
        event.roomId,
        event.title,
        event.assignee,
        event.timeLimit,
      );
      final rooms = await _repository.getRooms();
      final jobs = await _repository.getJobsForRoom(event.roomId);
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomId: event.roomId,
        selectedRoomJobs: jobs,
        alarmActive: alarmActive,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCompleteJob(CompleteJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.completeJob(event.jobId);
      final rooms = await _repository.getRooms();
      final jobs = await _repository.getJobsForRoom(event.roomId);
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomId: event.roomId,
        selectedRoomJobs: jobs,
        alarmActive: alarmActive,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCheckAlarms(CheckAlarmsEvent event, Emitter<MushroomsState> emit) async {
    try {
      await _repository.checkSoloJobsAlarms();
      final rooms = await _repository.getRooms();
      final alarmActive = await _repository.isAnySoloAlarmActive();
      
      List<Map<String, dynamic>> currentRoomJobs = state.selectedRoomJobs;
      if (state.selectedRoomId != null) {
        currentRoomJobs = await _repository.getJobsForRoom(state.selectedRoomId!);
      }
      
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomJobs: currentRoomJobs,
        alarmActive: alarmActive,
      ));
    } catch (_) {}
  }

  Future<void> _onCreateCustomRoom(CreateCustomRoomEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.addNewRoom(event.name);
      final rooms = await _repository.getRooms();
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(rooms: rooms, alarmActive: alarmActive, isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onUpdateJobStatus(UpdateJobStatusEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      if (event.newStatus == 'completed') {
        await _repository.completeJob(event.jobId);
      } else {
        await _repository.updateJobStatus(event.jobId, event.newStatus);
      }
      final rooms = await _repository.getRooms();
      final jobs = await _repository.getJobsForRoom(event.roomId);
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomId: event.roomId,
        selectedRoomJobs: jobs,
        alarmActive: alarmActive,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCheckInSoloJob(CheckInSoloJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.checkInSoloJob(event.jobId);
      final rooms = await _repository.getRooms();
      final jobs = await _repository.getJobsForRoom(event.roomId);
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomId: event.roomId,
        selectedRoomJobs: jobs,
        alarmActive: alarmActive,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onDismissActiveAlarms(DismissActiveAlarmsEvent event, Emitter<MushroomsState> emit) async {
    try {
      final activeTriggeredJobs = await _repository.getActiveTriggeredSoloJobs();
      for (var job in activeTriggeredJobs) {
        await _repository.checkInSoloJob(job['id']);
      }
      final rooms = await _repository.getRooms();
      List<Map<String, dynamic>> currentRoomJobs = state.selectedRoomJobs;
      if (state.selectedRoomId != null) {
        currentRoomJobs = await _repository.getJobsForRoom(state.selectedRoomId!);
      }
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomJobs: currentRoomJobs,
        alarmActive: alarmActive,
      ));
    } catch (_) {}
  }

  Future<void> _onCreateCustomJob(CreateCustomJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _repository.addCustomMushroomJob(
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
      final rooms = await _repository.getRooms();
      final jobs = await _repository.getJobsForRoom(event.roomId);
      final alarmActive = await _repository.isAnySoloAlarmActive();
      emit(state.copyWith(
        rooms: rooms,
        selectedRoomId: event.roomId,
        selectedRoomJobs: jobs,
        alarmActive: alarmActive,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  @override
  Future<void> close() {
    _alarmCheckTimer?.cancel();
    return super.close();
  }
}
