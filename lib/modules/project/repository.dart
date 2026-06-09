import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_service.dart';

class ProjectRepository {
  final AppDatabase _db;

  ProjectRepository([AppDatabase? database])
      : _db = database ?? AppDatabase();

  Map<String, dynamic> _decodeCustomFields(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  String _encodeCustomFields(dynamic fields) {
    if (fields == null) return '{}';
    if (fields is Map) {
      if (fields.isEmpty) return '{}';
      return jsonEncode(Map<String, dynamic>.from(fields));
    }
    return '{}';
  }

  // === PROJECTS ===

  Future<List<Map<String, dynamic>>> getProjects() async {
    final query = _db.select(_db.projects);
    final projects = await query.get();
    return projects.map((p) => <String, dynamic>{
      'id': p.id,
      'name': p.name,
      'description': p.description ?? '',
      'status': p.status,
      'created_at': p.createdAt.toIso8601String(),
      'custom_fields': _decodeCustomFields(p.customFields),
    }).toList();
  }

  Future<void> addProject(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();
    await _db.into(_db.projects).insert(ProjectsCompanion.insert(
      id: id,
      name: data['name'],
      description: Value(data['description']),
      status: Value(data['status'] ?? 'active'),
      customFields: Value(_encodeCustomFields(data['custom_fields'])),
    ));

    SyncService().queueMutation('projects', 'insert', {
      'id': id,
      'name': data['name'],
      'description': data['description'],
      'status': data['status'] ?? 'active',
      'custom_fields': data['custom_fields'] ?? {},
    });
  }

  Future<void> updateProject(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final p = await (_db.select(_db.projects)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (p == null) throw Exception('Project not found: $id');

    String updatedCustomFields = p.customFields;
    if (data['custom_fields'] != null) {
      final existing = _decodeCustomFields(p.customFields);
      final incoming = data['custom_fields'] is Map
          ? Map<String, dynamic>.from(data['custom_fields'] as Map)
          : <String, dynamic>{};
      existing.addAll(incoming);
      updatedCustomFields = _encodeCustomFields(existing);
    }

    await (_db.update(_db.projects)..where((tbl) => tbl.id.equals(id))).write(ProjectsCompanion(
      name: Value(data['name'] ?? p.name),
      description: Value(data['description'] ?? p.description),
      status: Value(data['status'] ?? p.status),
      customFields: Value(updatedCustomFields),
    ));

    SyncService().queueMutation('projects', 'update', {
      'id': id,
      'name': data['name'] ?? p.name,
      'description': data['description'] ?? p.description,
      'status': data['status'] ?? p.status,
      'custom_fields': _decodeCustomFields(updatedCustomFields),
    });
  }

  // === TASKS ===

  Future<List<Map<String, dynamic>>> getTasks(String projectId) async {
    final query = _db.select(_db.tasks)..where((tbl) => tbl.projectId.equals(projectId));
    final tasks = await query.get();
    return tasks.map((t) => <String, dynamic>{
      'id': t.id,
      'project_id': t.projectId,
      'title': t.title,
      'description': t.description ?? '',
      'status': t.status,
      'priority': t.priority,
      'due_date': t.dueDate?.toIso8601String(),
      'created_at': t.createdAt.toIso8601String(),
      'custom_fields': _decodeCustomFields(t.customFields),
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final query = _db.select(_db.tasks);
    final tasks = await query.get();
    return tasks.map((t) => <String, dynamic>{
      'id': t.id,
      'project_id': t.projectId,
      'title': t.title,
      'description': t.description ?? '',
      'status': t.status,
      'priority': t.priority,
      'due_date': t.dueDate?.toIso8601String(),
      'created_at': t.createdAt.toIso8601String(),
      'custom_fields': _decodeCustomFields(t.customFields),
    }).toList();
  }

  Future<void> addTask(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();
    await _db.into(_db.tasks).insert(TasksCompanion.insert(
      id: id,
      projectId: data['project_id'],
      title: data['title'],
      description: Value(data['description']),
      status: Value(data['status'] ?? 'todo'),
      priority: Value(data['priority'] ?? 'medium'),
      dueDate: Value(data['due_date'] != null ? DateTime.parse(data['due_date']) : null),
      customFields: Value(_encodeCustomFields(data['custom_fields'])),
    ));

    SyncService().queueMutation('tasks', 'insert', {
      'id': id,
      'project_id': data['project_id'],
      'title': data['title'],
      'description': data['description'],
      'status': data['status'] ?? 'todo',
      'priority': data['priority'] ?? 'medium',
      'due_date': data['due_date'],
      'custom_fields': data['custom_fields'] ?? {},
    });
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    final id = taskId;
    final t = await (_db.select(_db.tasks)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (t == null) throw Exception('Task not found: $id');

    await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(id))).write(TasksCompanion(
      status: Value(status),
    ));

    SyncService().queueMutation('tasks', 'update', {
      'id': id,
      'status': status,
    });
  }
}
