import 'package:flutter/material.dart';
import '../../core/modules/module_interface.dart';
import '../../core/modules/module_manifest.dart';
import '../../core/ai_agent/models/chat_models.dart';
import 'manifest.dart';
import 'repository.dart';
import 'screens/services_screen.dart';
import 'screens/bookings_screen.dart';

class ServicesModule implements IZiiModule {
  @override
  ModuleManifest get manifest => servicesManifest;

  @override
  List<String> get tableNames => ['ServiceItems', 'ServiceBookings'];

  @override
  List<AgentTool> get agentTools => [
        AgentTool(
          name: 'get_service_info',
          description:
              'Tra cứu thông tin và đơn giá của một dịch vụ (sửa chữa, lắp đặt, vận chuyển, dọn dẹp, điện nước...)',
          parameters: {
            'type': 'object',
            'properties': {
              'service_name': {
                'type': 'string',
                'description': 'Tên dịch vụ cần tra cứu',
              },
            },
            'required': ['service_name'],
          },
          execute: (args) async {
            final serviceName = args['service_name'] as String;
            return await ServicesRepository().getServiceInfo(serviceName);
          },
        ),
        AgentTool(
          name: 'create_service_booking',
          description:
              'Chuẩn bị tạo đơn booking dịch vụ theo tên dịch vụ, thông tin khách hàng và ngày giờ. Yêu cầu xác nhận trước khi thực hiện.',
          parameters: {
            'type': 'object',
            'properties': {
              'service_name': {
                'type': 'string',
                'description': 'Tên dịch vụ muốn đặt',
              },
              'customer_name': {
                'type': 'string',
                'description': 'Tên khách hàng',
              },
              'customer_phone': {
                'type': 'string',
                'description': 'Số điện thoại liên hệ của khách hàng',
              },
              'scheduled_date': {
                'type': 'string',
                'description':
                    'Ngày giờ lên lịch dịch vụ theo ISO 8601 hoặc định dạng dễ đọc',
              },
              'customer_address': {
                'type': 'string',
                'description': 'Địa chỉ thực hiện dịch vụ (nếu có)',
              },
              'notes': {
                'type': 'string',
                'description': 'Ghi chú bổ sung cho booking',
              },
            },
            'required': ['service_name', 'customer_name', 'customer_phone'],
          },
          requiresConfirmation: true,
          execute: (args) async {
            final serviceName = args['service_name']?.toString().trim() ?? '';
            final customerName = args['customer_name']?.toString().trim() ?? '';
            final customerPhone =
                args['customer_phone']?.toString().trim() ?? '';
            final scheduledAt = args['scheduled_date']?.toString().trim();
            final customerAddress = args['customer_address']?.toString().trim();
            final notes = args['notes']?.toString().trim();
            final hasCustomerAddress = customerAddress?.isNotEmpty == true;
            final hasNotes = notes?.isNotEmpty == true;

            if (serviceName.isEmpty) {
              return 'Vui lòng cung cấp tên dịch vụ để tạo booking.';
            }
            if (customerName.isEmpty) {
              return 'Vui lòng cung cấp tên khách hàng để tạo booking.';
            }
            if (customerPhone.isEmpty) {
              return 'Vui lòng cung cấp số điện thoại khách hàng để liên hệ.';
            }

            final service =
                await ServicesRepository().getServiceItemByName(serviceName);
            if (service == null) {
              return 'Không tìm thấy dịch vụ phù hợp với tên "$serviceName". Vui lòng thử lại với tên dịch vụ rõ ràng hơn.';
            }

            String? normalizedSchedule;
            if (scheduledAt != null && scheduledAt.isNotEmpty) {
              try {
                final parsedDate = DateTime.parse(scheduledAt);
                normalizedSchedule = parsedDate.toIso8601String();
              } catch (_) {
                normalizedSchedule = scheduledAt;
              }
            }

            final bookingData = {
              'service_item_id': service['id'],
              'customer_name': customerName,
              'customer_phone': customerPhone,
              'scheduled_at': normalizedSchedule,
              'notes': notes,
              'custom_fields': {
                if (hasCustomerAddress) 'customer_address': customerAddress,
                if (hasNotes) 'notes': notes,
                'created_by': 'ai_chat',
              },
            };
            await ServicesRepository().addBooking(bookingData);

            final summary = <String>[];
            summary.add('Dịch vụ: ${service['name']}');
            summary.add('Khách hàng: $customerName');
            summary.add('SĐT: $customerPhone');
            if (normalizedSchedule != null) {
              summary.add('Thời gian: $normalizedSchedule');
            }
            if (hasCustomerAddress) {
              summary.add('Địa chỉ: $customerAddress');
            }
            if (hasNotes) {
              summary.add('Ghi chú: $notes');
            }

            return 'Đã tạo booking dịch vụ thành công: ${summary.join(' • ')}';
          },
        ),
        AgentTool(
          name: 'add_service',
          description:
              'Tạo mới một dịch vụ trong hệ thống Services (name, category, hourly_rate, estimated_hours, description, custom_fields).',
          parameters: {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'Tên dịch vụ'},
              'category': {
                'type': 'string',
                'description':
                    'Loại dịch vụ (repair, installation, delivery, cleaning, electrical, other)'
              },
              'hourly_rate': {
                'type': ['number', 'string'],
                'description': 'Đơn giá theo giờ (số) hoặc chuỗi có đơn vị'
              },
              'estimated_hours': {
                'type': ['number', 'string'],
                'description': 'Ước tính số giờ'
              },
              'description': {'type': 'string', 'description': 'Mô tả ngắn'},
              'custom_fields': {
                'type': 'object',
                'description': 'Các trường bổ sung dưới dạng object'
              },
            },
            'required': ['name', 'hourly_rate']
          },
          requiresConfirmation: true,
          execute: (args) async {
            // Normalize numeric fields
            double parseNum(dynamic v, [double fallback = 0]) {
              if (v == null) return fallback;
              if (v is num) return v.toDouble();
              final s = v.toString().replaceAll(RegExp(r'[^0-9\.]'), '');
              return double.tryParse(s) ?? fallback;
            }

            final data = <String, dynamic>{};
            data['name'] = args['name'];
            data['category'] = args['category'] ?? 'other';
            data['hourly_rate'] = parseNum(args['hourly_rate']);
            data['estimated_hours'] = parseNum(args['estimated_hours'], 1.0);
            data['description'] = args['description']?.toString();
            data['custom_fields'] = args['custom_fields'] ?? {};

            await ServicesRepository().addServiceItem(data);
            return 'Đã tạo dịch vụ "${data['name']}" thành công.';
          },
        ),
      ];

  @override
  Map<String, WidgetBuilder> get routes => {
        '/services': (context) => const Center(child: Text('Services')),
        '/services/list': (context) => const ServicesScreen(),
        '/services/bookings': (context) => const BookingsScreen(),
      };

  @override
  Widget? get dashboardWidget => const _ServicesDashboardWidget();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onCustomize(Map<String, dynamic> customization) async {}
}

class _ServicesDashboardWidget extends StatelessWidget {
  const _ServicesDashboardWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quản lý Dịch vụ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          Text('Sửa chữa • Lắp đặt • Vận chuyển • Dọn dẹp • Điện nước'),
        ],
      ),
    );
  }
}
