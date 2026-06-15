import 'package:flutter/material.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import '../../core/localization/app_localizations.dart';
import 'repository.dart';
import 'screens/project_list_screen.dart';
import 'screens/task_board_screen.dart';

class ProjectModule implements IZiiModule {
  @override
  ModuleManifest get manifest => const ModuleManifest(
        id: 'izii.project_management',
        name: 'Project & Tasks',
        description: 'Quản lý dự án, Kanban board và công việc hiệu quả.',
        version: '1.0.0',
        category: 'productivity',
      );

  @override
  List<String> get tableNames => ['Projects', 'Tasks'];

  @override
  List<AgentTool> get agentTools => [
        AgentTool(
          name: 'get_projects_list',
          description: 'Lấy danh sách các dự án hiện có trong hệ thống.',
          parameters: {'type': 'object', 'properties': {}},
          execute: (args) async {
            final projects = await ProjectRepository().getProjects();
            if (projects.isEmpty) return 'Chưa có dự án nào.';
            return projects
                .map((p) =>
                    '${p['name']} (ID: ${p['id']}) - Status: ${p['status']}')
                .join('\n');
          },
        ),
        AgentTool(
          name: 'create_project',
          description:
              'Tạo một dự án mới trong hệ thống (cần tên dự án name, và mô tả description). Yêu cầu xác nhận.',
          parameters: {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'Tên dự án'},
              'description': {'type': 'string', 'description': 'Mô tả dự án'},
            },
            'required': ['name'],
          },
          requiresConfirmation: true,
          execute: (args) async {
            final name = args['name'] as String;
            final desc = args['description']?.toString() ?? '';
            final data = {
              'name': name,
              'description': desc,
              'status': 'active'
            };
            await ProjectRepository().addProject(data);
            return 'Đã tạo dự án "$name" thành công.';
          },
        ),
        AgentTool(
          name: 'create_task',
          description:
              'Tạo một công việc mới trong dự án (cần project_id, tiêu đề title, và mô tả description). Yêu cầu xác nhận.',
          parameters: {
            'type': 'object',
            'properties': {
              'project_id': {
                'type': 'string',
                'description': 'ID của dự án chứa công việc'
              },
              'title': {'type': 'string', 'description': 'Tiêu đề công việc'},
              'description': {
                'type': 'string',
                'description': 'Mô tả công việc'
              },
              'priority': {
                'type': 'string',
                'description': 'Độ ưu tiên: low, medium, high'
              },
            },
            'required': ['project_id', 'title'],
          },
          requiresConfirmation: true,
          execute: (args) async {
            final projectId = args['project_id'] as String;
            final title = args['title'] as String;
            final desc = args['description']?.toString() ?? '';
            final priority = args['priority']?.toString() ?? 'medium';
            final data = {
              'project_id': projectId,
              'title': title,
              'description': desc,
              'status': 'todo',
              'priority': priority,
            };
            await ProjectRepository().addTask(data);
            return 'Đã tạo công việc "$title" thành công trong dự án.';
          },
        ),
      ];

  @override
  Map<String, WidgetBuilder> get routes => {
        '/project/list': (context) => const ProjectListScreen(),
        '/project/tasks': (context) {
          final uri = ModalRoute.of(context)!.settings.arguments as Uri?;
          final projId = uri?.queryParameters['projectId'] ?? '';
          final projName = uri?.queryParameters['projectName'] ?? 'Tasks';
          return TaskBoardScreen(projectId: projId, projectName: projName);
        },
      };

  @override
  Widget? get dashboardWidget => const _ProjectDashboardWidget();

  @override
  Future<void> initialize() async {
    AppLocalizations.registerModuleTranslations('vi', {
      'module_izii.project_management_name': 'Dự án & Công việc',
      'module_izii.project_management_desc':
          'Quản lý dự án, theo dõi tiến độ công việc.',
      'project_list_title': 'Danh sách Dự án',
      'project_add_btn': 'Thêm dự án',
      'project_add_title': 'Tạo dự án mới',
      'project_name_label': 'Tên dự án',
      'project_no_projects': 'Chưa có dự án nào',
      'project_status_todo': 'Cần làm',
      'project_status_in_progress': 'Đang làm',
      'project_status_done': 'Hoàn thành',
      'project_task_add_title': 'Thêm công việc',
      'project_task_title_label': 'Tiêu đề công việc',
      'project_priority_label': 'Độ ưu tiên',
      'project_priority_low': 'Thấp',
      'project_priority_medium': 'Trung bình',
      'project_priority_high': 'Cao',
      'project_action_list': 'Dự án',
      'project_action_list_sub': 'Danh sách dự án',
      'project_overview_desc': 'Xem trạng thái tiến độ các công việc hiện tại.',
    });
    AppLocalizations.registerModuleTranslations('en', {
      'module_izii.project_management_name': 'Project & Tasks',
      'module_izii.project_management_desc':
          'Manage projects and track task progress.',
      'project_list_title': 'Projects List',
      'project_add_btn': 'Add Project',
      'project_add_title': 'Create New Project',
      'project_name_label': 'Project Name',
      'project_no_projects': 'No projects yet',
      'project_status_todo': 'Todo',
      'project_status_in_progress': 'In Progress',
      'project_status_done': 'Done',
      'project_task_add_title': 'Add Task',
      'project_task_title_label': 'Task Title',
      'project_priority_label': 'Priority',
      'project_priority_low': 'Low',
      'project_priority_medium': 'Medium',
      'project_priority_high': 'High',
      'project_action_list': 'Projects',
      'project_action_list_sub': 'Projects list',
      'project_overview_desc': 'Track overall task status and progress.',
    });
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {}
}

class _ProjectDashboardWidget extends StatefulWidget {
  const _ProjectDashboardWidget();

  @override
  State<_ProjectDashboardWidget> createState() =>
      _ProjectDashboardWidgetState();
}

class _ProjectDashboardWidgetState extends State<_ProjectDashboardWidget> {
  int _todoCount = 0;
  int _progressCount = 0;
  int _doneCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final tasks = await ProjectRepository().getAllTasks();
    int todo = 0;
    int progress = 0;
    int done = 0;
    for (final t in tasks) {
      if (t['status'] == 'todo') todo++;
      if (t['status'] == 'in_progress') progress++;
      if (t['status'] == 'done') done++;
    }
    if (mounted) {
      setState(() {
        _todoCount = todo;
        _progressCount = progress;
        _doneCount = done;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    }

    final total = _todoCount + _progressCount + _doneCount;
    final percent =
        total > 0 ? (_doneCount / total * 100).toStringAsFixed(0) : '0';

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('module_izii.project_management_name'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('$percent% Done',
                    style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(context.tr('project_status_todo'), _todoCount,
                  const Color(0xFF94A3B8)),
              _statItem(context.tr('project_status_in_progress'),
                  _progressCount, const Color(0xFF6366F1)),
              _statItem(context.tr('project_status_done'), _doneCount,
                  const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
