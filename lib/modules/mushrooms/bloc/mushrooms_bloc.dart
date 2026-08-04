import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/grow_room_service.dart';
import '../services/job_list_service.dart';
import '../../../core/events/app_event_bus.dart';
import '../../../core/sync/sync_service.dart';

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
  final String? roomId;
  CompleteJobEvent(this.jobId, [this.roomId]);
}

class UpdateJobStatusEvent extends MushroomsEvent {
  final String jobId;
  final String? roomId;
  final String newStatus;
  UpdateJobStatusEvent(this.jobId, dynamic arg2, [String? arg3])
      : roomId = arg3 != null ? arg2 as String? : null,
        newStatus = arg3 != null ? arg3 : (arg2 as String);
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
  final String? roomId;
  CheckInSoloJobEvent(this.jobId, [this.roomId]);
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
  final String? roomId;
  final List<Map<String, dynamic>> jobs;
  RoomJobsUpdatedEvent(dynamic arg1, [List<Map<String, dynamic>>? arg2])
      : roomId = arg2 != null ? arg1 as String? : null,
        jobs = arg2 != null ? arg2 : (arg1 as List<Map<String, dynamic>>);
}

// === STATE ===

class MushroomsState {
  final List<Map<String, dynamic>> rooms;
  final Map<String, dynamic>? selectedRoom;
  final List<Map<String, dynamic>> roomJobs;
  final List<Map<String, dynamic>> selectedRoomJobs;
  final bool isLoading;
  final String? error;
  final String? selectedRoomId;
  final bool alarmActive;

  MushroomsState({
    this.rooms = const [],
    this.selectedRoom,
    this.roomJobs = const [],
    List<Map<String, dynamic>>? selectedRoomJobs,
    this.isLoading = false,
    this.error,
    this.selectedRoomId,
    this.alarmActive = false,
  }) : selectedRoomJobs = selectedRoomJobs ?? roomJobs;

  MushroomsState copyWith({
    List<Map<String, dynamic>>? rooms,
    Map<String, dynamic>? selectedRoom,
    List<Map<String, dynamic>>? roomJobs,
    List<Map<String, dynamic>>? selectedRoomJobs,
    bool? isLoading,
    String? error,
    String? selectedRoomId,
    bool? alarmActive,
    bool clearJobs = false,
  }) {
    // ── Ràng buộc: selectedRoomJobs LUÔN phải thuộc về selectedRoomId ────────
    // Trước đây dòng này là:
    //     selectedRoomJobs ?? roomJobs ?? this.selectedRoomJobs
    // nên khi đổi phòng mà không truyền jobs, danh sách job của phòng CŨ được
    // bê nguyên sang phòng MỚI → state tự mâu thuẫn (selectedRoomId = room_11
    // nhưng jobs vẫn là của room_10). Đó là lý do mọi Room trên Samsung đều
    // hiển thị Task của Room 10.
    //
    // Giờ: job truyền vào tường minh luôn được ưu tiên; nếu không có mà phòng
    // vừa đổi (hoặc caller yêu cầu clearJobs) thì trả danh sách rỗng thay vì
    // giữ dữ liệu của phòng khác.
    final explicitJobs = selectedRoomJobs ?? roomJobs;
    final bool roomChanged =
        selectedRoomId != null && selectedRoomId != this.selectedRoomId;
    final List<Map<String, dynamic>> effectiveJobs = explicitJobs ??
        ((clearJobs || roomChanged)
            ? const <Map<String, dynamic>>[]
            : this.selectedRoomJobs);
    return MushroomsState(
      rooms: rooms ?? this.rooms,
      selectedRoom: selectedRoom ?? this.selectedRoom,
      roomJobs: effectiveJobs,
      selectedRoomJobs: effectiveJobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedRoomId: selectedRoomId ?? this.selectedRoomId,
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
  StreamSubscription<AppDomainEvent>? _eventBusSubscription;
  StreamSubscription<SyncEvent>? _syncSubscription;

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

    // Subscribe to AppEventBus real-time domain events
    _eventBusSubscription = AppEventBus().stream.listen((event) {
      if (event.eventType.startsWith('mushroom.') ||
          event.eventType.startsWith('organization.')) {
        add(LoadRoomsEvent());
        if (state.selectedRoomId != null) {
          add(LoadRoomDetailsEvent(state.selectedRoomId!));
        }
      }
    });

    // Subscribe to SyncService events (triggered when WebSocket receives sync_trigger from server)
    _syncSubscription = SyncService().syncEventStream.listen((_) {
      add(LoadRoomsEvent());
      if (state.selectedRoomId != null) {
        add(LoadRoomDetailsEvent(state.selectedRoomId!));
      }
    });

    // Setup periodic background check for solo job alarms (every 30 seconds)
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      add(CheckAlarmsEvent());
    });
  }

  Future<void> _onLoadRooms(
      LoadRoomsEvent event, Emitter<MushroomsState> emit) async {
    _roomsSubscription?.cancel();
    _roomsSubscription = _roomService.watchRooms().listen((rooms) {
      add(RoomsUpdatedEvent(rooms));
    });
    final alarmActive = await _jobService.isAnySoloAlarmActive();
    emit(state.copyWith(alarmActive: alarmActive));
  }

  Future<void> _onLoadRoomDetails(
      LoadRoomDetailsEvent event, Emitter<MushroomsState> emit) async {
    _jobsSubscription?.cancel();

    // ⚠️ THỨ TỰ Ở ĐÂY LÀ QUAN TRỌNG — đừng đảo lại.
    //
    // Stream của Drift phát dữ liệu NGAY khi subscribe. Bản cũ subscribe trước
    // rồi mới `await isAnySoloAlarmActive()` và emit selectedRoomId sau cùng,
    // nên event đầu tiên (RoomJobsUpdatedEvent của phòng MỚI) tới lúc
    // state.selectedRoomId vẫn còn là phòng CŨ → bị _onRoomJobsUpdated vứt bỏ
    // im lặng. Stream không phát lại vì dữ liệu không đổi, nên phòng mới kẹt
    // vĩnh viễn với job của phòng cũ.
    //
    // Vì vậy: đổi selectedRoomId + xoá job phòng cũ TRƯỚC, subscribe SAU.
    //
    // Không truyền clearJobs ở đây: copyWith đã tự xoá khi phát hiện phòng
    // thay đổi. Nếu ép clearJobs=true thì mỗi lần sync_trigger nạp lại CÙNG
    // phòng (xem listener SyncService/AppEventBus ở constructor) danh sách sẽ
    // bị xoá rồi đổ lại → giao diện nhấp nháy không cần thiết.
    emit(state.copyWith(selectedRoomId: event.roomId));

    _jobsSubscription =
        _jobService.watchJobsByRoom(event.roomId).listen((jobs) {
      add(RoomJobsUpdatedEvent(event.roomId, jobs));
    });

    final alarmActive = await _jobService.isAnySoloAlarmActive();
    emit(state.copyWith(alarmActive: alarmActive));
  }

  void _onRoomsUpdated(RoomsUpdatedEvent event, Emitter<MushroomsState> emit) {
    emit(state.copyWith(rooms: event.rooms));
  }

  void _onRoomJobsUpdated(
      RoomJobsUpdatedEvent event, Emitter<MushroomsState> emit) {
    // Chỉ nhận dữ liệu của phòng đang chọn — chặn event đến muộn từ
    // subscription cũ đã cancel nhưng còn sự kiện nằm trong hàng đợi.
    if (event.roomId != state.selectedRoomId) {
      return;
    }
    // Lọc thêm một lớp theo room_id trong chính bản ghi, phòng trường hợp
    // truy vấn nguồn thay đổi hoặc trả về dữ liệu lẫn phòng.
    //
    // Fail-CLOSED: job không khai báo được thuộc phòng nào thì loại bỏ. Với
    // tính năng Alone Worker, hiển thị NHẦM job của phòng khác nguy hiểm hơn
    // nhiều so với không hiển thị gì.
    final jobs = event.jobs.where((j) {
      final jRoomId = j['room_id'] ?? j['roomId'];
      return jRoomId != null && jRoomId == event.roomId;
    }).toList();
    if (jobs.length != event.jobs.length) {
      debugPrint(
        '[MushroomsBloc] ⚠️ Loại ${event.jobs.length - jobs.length} job không '
        'khớp room_id với ${event.roomId} — kiểm tra lại nguồn dữ liệu job.',
      );
    }
    emit(state.copyWith(selectedRoomJobs: jobs));
  }

  Future<void> _onStartCycle(
      StartCycleEvent event, Emitter<MushroomsState> emit) async {
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

  Future<void> _onAddSoloJob(
      AddSoloJobEvent event, Emitter<MushroomsState> emit) async {
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

  Future<void> _onCompleteJob(
      CompleteJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.completeJob(event.jobId);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCheckAlarms(
      CheckAlarmsEvent event, Emitter<MushroomsState> emit) async {
    try {
      await _jobService.checkSoloJobsAlarms();
      final alarmActive = await _jobService.isAnySoloAlarmActive();
      emit(state.copyWith(alarmActive: alarmActive));
    } catch (_) {}
  }

  Future<void> _onCreateCustomRoom(
      CreateCustomRoomEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _roomService.addRoom(name: event.name, plantName: 'Plant M2');
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onUpdateJobStatus(
      UpdateJobStatusEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.updateJobStatus(event.jobId, event.newStatus);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onCheckInSoloJob(
      CheckInSoloJobEvent event, Emitter<MushroomsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _jobService.checkInSoloJob(event.jobId);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onDismissActiveAlarms(
      DismissActiveAlarmsEvent event, Emitter<MushroomsState> emit) async {
    try {
      final activeTriggeredJobs =
          await _jobService.getActiveTriggeredSoloJobs();
      for (var job in activeTriggeredJobs) {
        await _jobService.checkInSoloJob(job['id']);
      }
      final alarmActive = await _jobService.isAnySoloAlarmActive();
      emit(state.copyWith(alarmActive: alarmActive));
    } catch (_) {}
  }

  Future<void> _onCreateCustomJob(
      CreateCustomJobEvent event, Emitter<MushroomsState> emit) async {
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

  Future<void> _onResetRoom(
      ResetRoomEvent event, Emitter<MushroomsState> emit) async {
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
    _eventBusSubscription?.cancel();
    _syncSubscription?.cancel();
    return super.close();
  }
}
