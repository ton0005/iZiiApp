import 'package:flutter/widgets.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import 'manifest.dart';
import 'bloc/inventory_bloc.dart';
import 'repository.dart';
import 'screens/products_screen.dart';
import 'screens/barcode_scanner_screen.dart';

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
        ),
        AgentTool(
          name: 'search_products',
          description:
              'Tìm kiếm sản phẩm theo tên và trả về danh sách sản phẩm khớp cùng tồn kho.',
          parameters: {
            'type': 'object',
            'properties': {
              'product_query': {
                'type': 'string',
                'description': 'Tên hoặc một phần tên sản phẩm cần tìm'
              },
            },
            'required': ['product_query'],
          },
          execute: (args) async {
            final query = args['product_query'] as String;
            final allProducts =
                await SupplyChainRepository().getProductsWithStock();
            final matches = allProducts.where((product) {
              final name = (product['name'] as String).toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();

            if (matches.isEmpty) {
              return 'Không tìm thấy sản phẩm nào phù hợp với "$query".';
            }

            final result = matches.map((product) {
              final name = product['name'];
              final stock = product['stock'];
              final price = product['price'];
              return '• $name — tồn kho: $stock, giá: ${price.toStringAsFixed(0)} VNĐ';
            }).join('\n');
            return 'Tìm thấy ${matches.length} sản phẩm:\n$result';
          },
        ),
        AgentTool(
          name: 'list_all_products',
          description:
              'Hiển thị danh sách tất cả sản phẩm có trong kho cùng số lượng.',
          parameters: const {
            'type': 'object',
            'properties': {},
          },
          execute: (args) async {
            final allProducts =
                await SupplyChainRepository().getProductsWithStock();
            if (allProducts.isEmpty) {
              return 'Hiện tại không có sản phẩm nào trong kho.';
            }
            final result = allProducts.map((product) {
              final name = product['name'];
              final stock = product['stock'];
              final price = product['price'];
              return '• $name — tồn kho: $stock, giá: ${price.toStringAsFixed(0)} VNĐ';
            }).join('\n');
            return 'Danh sách sản phẩm hiện có:\n$result';
          },
        )
      ];

  @override
  Map<String, WidgetBuilder> get routes => {
        '/inventory': (context) => const Center(child: Text('Inventory')),
        '/inventory/products': (context) => const ProductsScreen(),
        '/inventory/scan': (context) => const BarcodeScannerScreen(),
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
