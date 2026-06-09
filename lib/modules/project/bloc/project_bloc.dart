import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repository.dart';

// === Events ===

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();
  @override
  List<Object?> get props => [];
}

class LoadProjectsEvent extends ProjectEvent {}

class LoadTasksEvent extends ProjectEvent {
  final String projectId;
  const LoadTasksEvent(this.projectId);
  @override
  List<Object?> get props => [projectId];
}

class AddProjectEvent extends ProjectEvent {
  final Map<String, dynamic> data;
  const AddProjectEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class AddTaskEvent extends ProjectEvent {
  final Map<String, dynamic> data;
  const AddTaskEvent(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdateTaskStatusEvent extends ProjectEvent {
  final String taskId;
  final String status;
  const UpdateTaskStatusEvent(this.taskId, this.status);
  @override
  List<Object?> get props => [taskId, status];
}

// === State ===

class ProjectState extends Equatable {
  final bool isLoading;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> tasks;
  final String? error;

  const ProjectState({
    this.isLoading = false,
    this.projects = const [],
    this.tasks = const [],
    this.error,
  });

  ProjectState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? projects,
    List<Map<String, dynamic>>? tasks,
    String? error,
  }) {
    return ProjectState(
      isLoading: isLoading ?? this.isLoading,
      projects: projects ?? this.projects,
      tasks: tasks ?? this.tasks,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, projects, tasks, error];
}

// === Repository Wrapper ===

class ProjectModuleRepository {
  static final ProjectModuleRepository _instance = ProjectModuleRepository._internal();
  factory ProjectModuleRepository() => _instance;
  ProjectModuleRepository._internal();

  final _repo = ProjectRepository();

  Future<List<Map<String, dynamic>>> getProjects() => _repo.getProjects();
  Future<List<Map<String, dynamic>>> getTasks(String projectId) => _repo.getTasks(projectId);
  Future<List<Map<String, dynamic>>> getAllTasks() => _repo.getAllTasks();
  Future<void> addProject(Map<String, dynamic> data) => _repo.addProject(data);
  Future<void> updateProject(Map<String, dynamic> data) => _repo.updateProject(data);
  Future<void> addTask(Map<String, dynamic> data) => _repo.addTask(data);
  Future<void> updateTaskStatus(String taskId, String status) => _repo.updateTaskStatus(taskId, status);
}

// === BLoC ===

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  ProjectBloc() : super(const ProjectState()) {
    on<LoadProjectsEvent>(_onLoadProjects);
    on<LoadTasksEvent>(_onLoadTasks);
    on<AddProjectEvent>(_onAddProject);
    on<AddTaskEvent>(_onAddTask);
    on<UpdateTaskStatusEvent>(_onUpdateTaskStatus);
  }

  Future<void> _onLoadProjects(LoadProjectsEvent event, Emitter<ProjectState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final projects = await ProjectModuleRepository().getProjects();
      emit(state.copyWith(isLoading: false, projects: projects));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadTasks(LoadTasksEvent event, Emitter<ProjectState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final tasks = await ProjectModuleRepository().getTasks(event.projectId);
      emit(state.copyWith(isLoading: false, tasks: tasks));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddProject(AddProjectEvent event, Emitter<ProjectState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await ProjectModuleRepository().addProject(event.data);
      final projects = await ProjectModuleRepository().getProjects();
      emit(state.copyWith(isLoading: false, projects: projects));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddTask(AddTaskEvent event, Emitter<ProjectState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await ProjectModuleRepository().addTask(event.data);
      final tasks = await ProjectModuleRepository().getTasks(event.data['project_id']);
      emit(state.copyWith(isLoading: false, tasks: tasks));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdateTaskStatus(UpdateTaskStatusEvent event, Emitter<ProjectState> emit) async {
    // Optimistic update
    final updatedTasks = state.tasks.map((t) {
      if (t['id'] == event.taskId) {
        return {...t, 'status': event.status};
      }
      return t;
    }).toList();
    emit(state.copyWith(tasks: updatedTasks));

    try {
      await ProjectModuleRepository().updateTaskStatus(event.taskId, event.status);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
