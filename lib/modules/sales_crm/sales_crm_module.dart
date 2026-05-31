import 'package:flutter/widgets.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import 'manifest.dart';
import 'agent_tools/crm_tools.dart';
import 'screens/leads_screen.dart';
import 'ui/deal_pipeline.dart';

class SalesCrmModule implements IZiiModule {
  @override
  ModuleManifest get manifest => salesCrmManifest;

  @override
  List<String> get tableNames => ['Contacts', 'Leads', 'Deals'];

  @override
  List<AgentTool> get agentTools => getCrmAgentTools();

  @override
  Map<String, WidgetBuilder> get routes => {
        '/sales': (context) => const Center(child: Text('Sales')),
        '/crm/leads': (context) => const LeadsScreen(),
        '/crm/deals': (context) => const DealPipelineScreen(),
      };

  @override
  Widget? get dashboardWidget => const _SalesDashboardWidget();

  @override
  Future<void> initialize() async {
    // Logic khởi tạo module: kiểm tra database, sync...
  }

  @override
  Future<void> dispose() async {
    // Dọn dẹp tài nguyên
  }

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {
    // AI Agent sẽ gọi hàm này khi người dùng yêu cầu chỉnh sửa (VD: thêm trường "Nguồn khách hàng")
  }
}

class _SalesDashboardWidget extends StatelessWidget {
  const _SalesDashboardWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales & CRM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          Text('3 New Leads • 5 Active Deals'),
        ],
      ),
    );
  }
}
