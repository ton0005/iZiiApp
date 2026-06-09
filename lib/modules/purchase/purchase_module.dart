import 'package:flutter/material.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import '../../core/localization/app_localizations.dart';
import 'repository.dart';
import 'screens/purchase_orders_list_screen.dart';
import 'screens/purchase_order_form_screen.dart';

class PurchaseModule implements IZiiModule {
  @override
  ModuleManifest get manifest => ModuleManifest(
        id: 'izii.purchase_management',
        name: 'Purchasing',
        description: 'Quản lý đơn mua hàng, theo dõi chi tiêu và nhà cung cấp.',
        version: '1.0.0',
        category: 'operations',
      );

  @override
  List<String> get tableNames => ['PurchaseOrders', 'PurchaseOrderLines'];

  @override
  List<AgentTool> get agentTools => [
        AgentTool(
          name: 'get_purchase_orders',
          description: 'Lấy danh sách các đơn mua hàng hiện có trong hệ thống.',
          parameters: {'type': 'object', 'properties': {}},
          execute: (args) async {
            final orders = await PurchaseRepository().getPurchaseOrders();
            if (orders.isEmpty) return 'Chưa có đơn mua hàng nào.';
            return orders
                .map((o) =>
                    '${o['order_number']} - Supplier: ${o['partner_name']} - Total: ${o['total_amount']} VNĐ - Status: ${o['status']}')
                .join('\n');
          },
        ),
        AgentTool(
          name: 'create_purchase_order',
          description:
              'Tạo một đơn mua hàng mới trong hệ thống. Cần tên nhà cung cấp partner_name và danh sách các mặt hàng lines (mỗi mặt hàng có product_name, quantity, unit_price). Yêu cầu xác nhận.',
          parameters: {
            'type': 'object',
            'properties': {
              'partner_name': {
                'type': 'string',
                'description': 'Tên nhà cung cấp'
              },
              'lines': {
                'type': 'array',
                'description': 'Danh sách chi tiết đơn hàng',
                'items': {
                  'type': 'object',
                  'properties': {
                    'product_name': {
                      'type': 'string',
                      'description': 'Tên sản phẩm'
                    },
                    'quantity': {'type': 'number', 'description': 'Số lượng'},
                    'unit_price': {'type': 'number', 'description': 'Đơn giá'}
                  },
                  'required': ['product_name', 'quantity', 'unit_price']
                }
              }
            },
            'required': ['partner_name', 'lines'],
          },
          requiresConfirmation: true,
          execute: (args) async {
            final partnerName = args['partner_name'] as String;
            final rawLines = args['lines'] as List;
            final lines = rawLines
                .map((l) => Map<String, dynamic>.from(l as Map))
                .toList();
            final orderData = {'partner_name': partnerName, 'status': 'draft'};
            await PurchaseRepository().addPurchaseOrder(orderData, lines);
            return 'Đã tạo đơn mua hàng từ nhà cung cấp "$partnerName" thành công.';
          },
        ),
      ];

  @override
  Map<String, WidgetBuilder> get routes => {
        '/purchase/list': (context) => const PurchaseOrdersListScreen(),
        '/purchase/create': (context) => const PurchaseOrderFormScreen(),
      };

  @override
  Widget? get dashboardWidget => const _PurchaseDashboardWidget();

  @override
  Future<void> initialize() async {
    AppLocalizations.registerModuleTranslations('vi', {
      'module_izii.purchase_management_name': 'Mua hàng & Nhà cung cấp',
      'module_izii.purchase_management_desc':
          'Quản lý đơn mua hàng, theo dõi chi tiêu.',
      'purchase_orders_title': 'Đơn mua hàng',
      'purchase_no_orders': 'Chưa có đơn mua hàng nào',
      'purchase_create_title': 'Tạo đơn mua hàng',
      'purchase_status_draft': 'Nháp',
      'purchase_status_sent': 'Đã gửi',
      'purchase_status_approved': 'Đã duyệt',
      'purchase_status_received': 'Đã nhận',
      'purchase_status_cancelled': 'Đã hủy',
      'purchase_partner_label': 'Nhà cung cấp',
      'purchase_line_add_title': 'Thêm chi tiết',
      'purchase_select_product_hint': 'Chọn sản phẩm',
      'purchase_manual_input': 'Nhập tay sản phẩm mới',
      'purchase_line_add_btn': 'Thêm dòng',
      'purchase_total_spent': 'Tổng chi tiêu',
      'purchase_overview_desc': 'Xem trạng thái các đơn mua hàng và chi tiêu.',
    });
    AppLocalizations.registerModuleTranslations('en', {
      'module_izii.purchase_management_name': 'Purchase Management',
      'module_izii.purchase_management_desc':
          'Manage purchase orders and expenses.',
      'purchase_orders_title': 'Purchase Orders',
      'purchase_no_orders': 'No purchase orders yet',
      'purchase_create_title': 'Create Purchase Order',
      'purchase_status_draft': 'Draft',
      'purchase_status_sent': 'Sent',
      'purchase_status_approved': 'Approved',
      'purchase_status_received': 'Received',
      'purchase_status_cancelled': 'Cancelled',
      'purchase_partner_label': 'Supplier',
      'purchase_line_add_title': 'Add Purchase Line',
      'purchase_select_product_hint': 'Select Product',
      'purchase_manual_input': 'Manual product entry',
      'purchase_line_add_btn': 'Add line',
      'purchase_total_spent': 'Total Spent',
      'purchase_overview_desc': 'Track purchase orders and statistics.',
    });
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {}
}

class _PurchaseDashboardWidget extends StatefulWidget {
  const _PurchaseDashboardWidget();

  @override
  State<_PurchaseDashboardWidget> createState() =>
      _PurchaseDashboardWidgetState();
}

class _PurchaseDashboardWidgetState extends State<_PurchaseDashboardWidget> {
  double _totalSpent = 0.0;
  int _orderCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final orders = await PurchaseRepository().getPurchaseOrders();
    double total = 0.0;
    for (final o in orders) {
      if (o['status'] != 'cancelled') {
        total += (o['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    if (mounted) {
      setState(() {
        _totalSpent = total;
        _orderCount = orders.length;
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

    final formattedSpent = _totalSpent.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('module_izii.purchase_management_name'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_orderCount Orders',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('purchase_total_spent'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formattedSpent VNĐ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.trending_up_rounded,
                color: Color(0xFF10B981),
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
