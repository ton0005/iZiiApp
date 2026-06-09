import 'package:flutter/widgets.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import '../../core/localization/app_localizations.dart';
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
    AppLocalizations.registerModuleTranslations('vi', {
      'module_sales_title': 'Sales & CRM',
      'module_sales_leads': 'Leads',
      'module_sales_deals': 'Deals',
      'module_sales_pipeline': 'Pipeline',
      'crm_new_leads': 'Leads mới',
      'crm_active_deals': 'Deals hoạt động',
    });
    AppLocalizations.registerModuleTranslations('en', {
      'module_sales_title': 'Sales & CRM',
      'module_sales_leads': 'Leads',
      'module_sales_deals': 'Deals',
      'module_sales_pipeline': 'Pipeline',
      'crm_new_leads': 'New Leads',
      'crm_active_deals': 'Active Deals',
    });
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('module_sales_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('3 ${context.tr('crm_new_leads')} • 5 ${context.tr('crm_active_deals')}'),
        ],
      ),
    );
  }
}
