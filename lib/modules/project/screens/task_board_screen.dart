import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/responsive_kanban_board.dart';
import '../bloc/project_bloc.dart';

class TaskBoardScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const TaskBoardScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  static const _statuses = ['todo', 'in_progress', 'done'];

  static const _statusColors = {
    'todo': Color(0xFF94A3B8), // Slate gray
    'in_progress': Color(0xFF6366F1), // Indigo
    'done': Color(0xFF10B981), // Emerald green
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProjectBloc()..add(LoadTasksEvent(widget.projectId)),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.projectName, style: const TextStyle(fontWeight: FontWeight.bold)),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<ProjectBloc>().add(LoadTasksEvent(widget.projectId));
                  },
                ),
              ],
            ),
            body: BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null) {
                  return Center(child: Text('${context.tr('error')}: ${state.error}'));
                }

                // Group tasks by status
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final status in _statuses) {
                  grouped[status] = [];
                }
                for (final task in state.tasks) {
                  final s = task['status'] as String? ?? 'todo';
                  grouped[s]?.add(task);
                }

                return ResponsiveKanbanBoard<Map<String, dynamic>>(
                  laneKeys: _statuses,
                  laneTitle: (key, ctx) => _getStatusLabel(key, ctx),
                  laneColor: (key) => _statusColors[key] ?? Colors.grey,
                  groupedData: grouped,
                  itemKey: (task) => task['id']?.toString() ?? '',
                  itemLane: (task) => task['status']?.toString() ?? 'todo',
                  emptyLaneHint: context.tr('crm_deal_pipeline_drag_hint'),
                  onItemMoved: (task, newStatus) {
                    context.read<ProjectBloc>().add(UpdateTaskStatusEvent(task['id'], newStatus));
                  },
                  cardBuilder: (ctx, task, laneColor, mode, dragHandle) {
                    return _buildTaskCard(ctx, task, laneColor, mode, dragHandle);
                  },
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              heroTag: 'add_task',
              onPressed: () => _showAddTaskDialog(context),
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          );
        }
      ),
    );
  }

  String _getStatusLabel(String status, BuildContext context) {
    switch (status) {
      case 'todo':
        return context.tr('project_status_todo');
      case 'in_progress':
        return context.tr('project_status_in_progress');
      case 'done':
        return context.tr('project_status_done');
      default:
        return status;
    }
  }

  Widget _buildTaskCard(
    BuildContext context,
    Map<String, dynamic> task,
    Color laneColor,
    KanbanLayoutMode mode,
    Widget dragHandle,
  ) {
    final priority = task['priority'] as String? ?? 'medium';
    final priorityColor = _getPriorityColor(priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.08)),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                dragHandle,
              ],
            ),
            const SizedBox(height: 6),
            Text(
              task['title'] ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task['description'],
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      default:
        return Colors.blue;
    }
  }

  void _showAddTaskDialog(BuildContext context) {
    final bloc = context.read<ProjectBloc>();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          title: Text(dialogContext.tr('project_task_add_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: '${dialogContext.tr('project_task_title_label')} *',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: dialogContext.tr('inv_description'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                items: [
                  DropdownMenuItem(value: 'low', child: Text(dialogContext.tr('project_priority_low'))),
                  DropdownMenuItem(value: 'medium', child: Text(dialogContext.tr('project_priority_medium'))),
                  DropdownMenuItem(value: 'high', child: Text(dialogContext.tr('project_priority_high'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setStateDialog(() {
                      priority = val;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: dialogContext.tr('project_priority_label'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(dialogContext.tr('cancel'))),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                bloc.add(AddTaskEvent({
                  'id': const Uuid().v4(),
                  'project_id': widget.projectId,
                  'title': title,
                  'description': descController.text.trim(),
                  'status': 'todo',
                  'priority': priority,
                  'due_date': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
                }));
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              child: Text(dialogContext.tr('save')),
            ),
          ],
        ),
      ),
    );
  }
}
