import 'package:flutter/widgets.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import 'manifest.dart';
import 'bloc/inventory_bloc.dart';
import 'screens/products_screen.dart';

class SupplyChainModule implements IZiiModule {
  @override
  ModuleManifest get manifest => supplyChainManifest;

  @override
  List<String> get tableNames => ['Products', 'StockQuants', 'StockMoves'];

  @override
  List<AgentTool> get agentTools => [
        AgentTool(
          name: 'check_stock',
          description: 'Kiểm tra số lượng tồn kho của một sản phẩm',
          parameters: {
            'type': 'object',
            'properties': {
              'product_name': {
                'type': 'string',
                'description': 'Tên sản phẩm cần kiểm tra'
              },
            },
            'required': ['product_name'],
          },
          execute: (args) async {
            final productName = args['product_name'] as String;
            final stock = await InventoryRepository().checkStock(productName);

            if (stock == -1) {
              return 'Không tìm thấy sản phẩm "$productName" trong kho.';
            }
            return 'Sản phẩm "$productName" hiện còn $stock cái trong kho chính.';
          },
        )
      ];

  @override
  Map<String, WidgetBuilder> get routes => {
        '/inventory': (context) => const Center(child: Text('Inventory')),
        '/inventory/products': (context) => const ProductsScreen(),
      };

  @override
  Widget? get dashboardWidget => const _SupplyChainDashboardWidget();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {}
}

class _SupplyChainDashboardWidget extends StatelessWidget {
  const _SupplyChainDashboardWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventory',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          Text('15 Lệnh xuất kho cần xử lý'),
        ],
      ),
    );
  }
}
