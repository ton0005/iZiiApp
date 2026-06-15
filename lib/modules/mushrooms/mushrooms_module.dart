import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import '../../core/localization/app_localizations.dart';
import 'bloc/mushrooms_bloc.dart';
import 'repository.dart';
import 'screens/mushrooms_dashboard_screen.dart';

const mushroomsManifest = ModuleManifest(
  id: 'izii.mushrooms',
  name: 'Costa Mushrooms',
  description:
      'Quản lý 33 phòng nuôi trồng nấm Costa Mushroom M2 và hệ thống an toàn Solo Job.',
  version: '1.0.0',
  category: 'Operations',
  tags: ['mushrooms', 'costa', 'operations', 'solo_safety'],
);

class MushroomsModule implements IZiiModule {
  @override
  ModuleManifest get manifest => mushroomsManifest;

  @override
  List<String> get tableNames => ['MushroomRooms', 'MushroomJobs'];

  @override
  List<AgentTool> get agentTools => [
        AgentTool(
          name: 'get_mushroom_rooms',
          description:
              'Lấy danh sách và trạng thái hiện tại của tất cả các phòng nuôi trồng nấm Costa M2.',
          parameters: {
            'type': 'object',
            'properties': {},
          },
          execute: (args) async {
            final repo = MushroomsRepository();
            final rooms = await repo.getRooms();
            if (rooms.isEmpty) {
              return 'Không tìm thấy phòng nuôi trồng nào.';
            }
            final buffer = StringBuffer();
            buffer.writeln('Danh sách phòng nấm Costa M2:');
            for (var r in rooms) {
              buffer.writeln(
                  '- ${r['name']}: Trạng thái: ${r['status']}, Giai đoạn: ${r['current_stage']}, Ngày chu kỳ: ${r['day_in_cycle']}');
            }
            return buffer.toString();
          },
        ),
        AgentTool(
          name: 'start_mushroom_cycle',
          description:
              'Bắt đầu một chu kỳ nuôi trồng mới (8 bước pipeline) cho một phòng nấm.',
          parameters: {
            'type': 'object',
            'properties': {
              'room_id': {
                'type': 'string',
                'description': 'ID của phòng nuôi trồng nấm',
              },
              'watering_plan': {
                'type': 'string',
                'description': 'Kế hoạch tưới nước (ví dụ: "2 Side 2L/m2")',
              },
              'prochloraz_rate': {
                'type': 'string',
                'description': 'Liều lượng Prochloraz (ví dụ: "1.3g/m2")',
              },
            },
            'required': ['room_id'],
          },
          requiresConfirmation: true,
          execute: (args) async {
            final roomId = args['room_id'] as String;
            final wateringPlan = args['watering_plan'] as String?;
            final prochlorazRate = args['prochloraz_rate'] as String?;

            final repo = MushroomsRepository();
            await repo.startNewCycle(
              roomId,
              wateringPlan: wateringPlan,
              prochlorazRate: prochlorazRate,
            );
            return 'Đã khởi động chu kỳ 8 bước thành công cho phòng nấm.';
          },
        ),
        AgentTool(
          name: 'assign_mushroom_solo_job',
          description:
              'Giao một công việc làm một mình (Solo Job) đặc biệt trong phòng nấm kèm thời gian giới hạn và hệ thống cảnh báo an toàn.',
          parameters: {
            'type': 'object',
            'properties': {
              'room_id': {
                'type': 'string',
                'description': 'ID của phòng nuôi trồng nấm',
              },
              'title': {
                'type': 'string',
                'description': 'Tên công việc (ví dụ: "Sửa đường ống nước", "Kiểm tra khay nấm")',
              },
              'assignee': {
                'type': 'string',
                'description': 'Tên người thực hiện công việc',
              },
              'time_limit_minutes': {
                'type': 'integer',
                'description': 'Thời gian giới hạn an toàn bằng phút',
              },
            },
            'required': ['room_id', 'title', 'assignee', 'time_limit_minutes'],
          },
          requiresConfirmation: true,
          execute: (args) async {
            final roomId = args['room_id'] as String;
            final title = args['title'] as String;
            final assignee = args['assignee'] as String;
            final timeLimitMinutes = (args['time_limit_minutes'] as num).toInt();

            final repo = MushroomsRepository();
            await repo.addSpecialSoloJob(
              roomId,
              title,
              assignee,
              timeLimitMinutes,
            );
            return 'Đã phân công Solo Job "$title" cho $assignee trong $timeLimitMinutes phút thành công.';
          },
        ),
        AgentTool(
          name: 'complete_mushroom_job',
          description:
              'Đánh dấu hoàn thành một công việc trong phòng nấm để chuyển sang bước tiếp theo.',
          parameters: {
            'type': 'object',
            'properties': {
              'job_id': {
                'type': 'string',
                'description': 'ID của công việc cần hoàn thành',
              },
            },
            'required': ['job_id'],
          },
          execute: (args) async {
            final jobId = args['job_id'] as String;
            final repo = MushroomsRepository();
            await repo.completeJob(jobId);
            return 'Đã đánh dấu hoàn thành công việc thành công.';
          },
        ),
      ];

  @override
  Map<String, WidgetBuilder> get routes => {
        '/mushrooms': (context) => BlocProvider(
              create: (context) => MushroomsBloc()..add(LoadRoomsEvent()),
              child: const MushroomsDashboardScreen(),
            ),
      };

  @override
  Widget? get dashboardWidget => const _MushroomsDashboardWidget();

  @override
  Future<void> initialize() async {
    // Register translation keys
    AppLocalizations.registerModuleTranslations('vi', {
      'module_mushrooms_title': 'Costa Mushrooms',
      'mushrooms_desc': 'Quản lý phòng nuôi trồng nấm M2',
      'solo_safety_alarm': 'Cảnh báo Solo Job',
      'active_rooms': 'Phòng Đang Hoạt Động',
      'active_alarms': 'Cảnh Báo An Toàn',
    });
    AppLocalizations.registerModuleTranslations('en', {
      'module_mushrooms_title': 'Costa Mushrooms',
      'mushrooms_desc': 'Costa Mushroom M2 Management',
      'solo_safety_alarm': 'Solo Job Alarm',
      'active_rooms': 'Active Grow Rooms',
      'active_alarms': 'Active Alarms',
    });

    // Run auto-seeding
    await MushroomsRepository().seedRoomsIfEmpty();
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {}
}

class _MushroomsDashboardWidget extends StatelessWidget {
  const _MushroomsDashboardWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('module_mushrooms_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(context.tr('mushrooms_desc')),
        ],
      ),
    );
  }
}
