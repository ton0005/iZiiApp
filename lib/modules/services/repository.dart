import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import 'daos/service_items_dao.dart';
import 'daos/service_bookings_dao.dart';

class ServicesRepository {
  final AppDatabase _db;
  late final ServiceItemsDao serviceItemsDao;
  late final ServiceBookingsDao serviceBookingsDao;

  ServicesRepository([AppDatabase? database])
      : _db = database ?? AppDatabase() {
    serviceItemsDao = ServiceItemsDao(_db);
    serviceBookingsDao = ServiceBookingsDao(_db);
  }

  // --- JSON helpers (same pattern as CRM/Supply Chain) ---

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

  // === SERVICE ITEMS ===

  Future<List<Map<String, dynamic>>> getServiceItems() async {
    final items = await serviceItemsDao.getAllServiceItems();
    return items
        .map((item) => {
              'id': item.id,
              'name': item.name,
              'category': item.category,
              'hourly_rate': item.hourlyRate,
              'estimated_hours': item.estimatedHours,
              'description': item.description ?? '',
              'is_active': item.isActive,
              'custom_fields': _decodeCustomFields(item.customFields),
              'created_at': item.createdAt.toIso8601String(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getServiceItemsByCategory(
      String category) async {
    final items = await serviceItemsDao.getServiceItemsByCategory(category);
    return items
        .map((item) => {
              'id': item.id,
              'name': item.name,
              'category': item.category,
              'hourly_rate': item.hourlyRate,
              'estimated_hours': item.estimatedHours,
              'description': item.description ?? '',
              'is_active': item.isActive,
              'custom_fields': _decodeCustomFields(item.customFields),
            })
        .toList();
  }

  Future<void> addServiceItem(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();
    await serviceItemsDao.insertServiceItem(ServiceItemsCompanion.insert(
      id: id,
      name: data['name'],
      category: Value(data['category'] ?? 'other'),
      hourlyRate: (data['hourly_rate'] as num).toDouble(),
      estimatedHours: Value(data['estimated_hours'] != null
          ? (data['estimated_hours'] as num).toDouble()
          : 1.0),
      description: Value(data['description']),
      customFields: Value(_encodeCustomFields(data['custom_fields'])),
    ));
  }

  Future<void> updateServiceItem(Map<String, dynamic> data) async {
    final item = await serviceItemsDao.getServiceItemById(data['id']);
    if (item == null) throw Exception('Service not found: ${data['id']}');

    // Merge custom fields
    String updatedCustomFields;
    if (data['custom_fields'] != null) {
      final existing = _decodeCustomFields(item.customFields);
      final incoming = data['custom_fields'] is Map
          ? Map<String, dynamic>.from(data['custom_fields'] as Map)
          : <String, dynamic>{};
      existing.addAll(incoming);
      updatedCustomFields = _encodeCustomFields(existing);
    } else {
      updatedCustomFields = item.customFields;
    }

    await serviceItemsDao.updateServiceItem(item.copyWith(
      name: data['name'] ?? item.name,
      category: data['category'] ?? item.category,
      hourlyRate: data['hourly_rate'] != null
          ? (data['hourly_rate'] as num).toDouble()
          : item.hourlyRate,
      estimatedHours: data['estimated_hours'] != null
          ? (data['estimated_hours'] as num).toDouble()
          : item.estimatedHours,
      description: Value(data['description'] ?? item.description),
      isActive: data['is_active'] ?? item.isActive,
      customFields: updatedCustomFields,
    ));
  }

  // === BOOKINGS ===

  Future<List<Map<String, dynamic>>> getBookings() async {
    final bookings = await serviceBookingsDao.getAllBookings();
    final result = <Map<String, dynamic>>[];

    for (final b in bookings) {
      // Get service name
      final service = await serviceItemsDao.getServiceItemById(b.serviceItemId);
      result.add({
        'id': b.id,
        'service_item_id': b.serviceItemId,
        'service_name': service?.name ?? 'Dịch vụ không xác định',
        'service_category': service?.category ?? 'other',
        'hourly_rate': service?.hourlyRate ?? 0,
        'customer_name': b.customerName,
        'customer_phone': b.customerPhone ?? '',
        'scheduled_at': b.scheduledAt?.toIso8601String(),
        'actual_hours': b.actualHours,
        'total_amount': b.totalAmount,
        'status': b.status,
        'notes': b.notes ?? '',
        'custom_fields': _decodeCustomFields(b.customFields),
        'created_at': b.createdAt.toIso8601String(),
      });
    }

    return result;
  }

  Future<void> addBooking(Map<String, dynamic> data) async {
    final id = data['id'] ?? const Uuid().v4();

    // Calculate estimated total
    double totalAmount = 0;
    if (data['service_item_id'] != null) {
      final service =
          await serviceItemsDao.getServiceItemById(data['service_item_id']);
      if (service != null) {
        final hours = data['estimated_hours'] ?? service.estimatedHours;
        totalAmount = service.hourlyRate * (hours as num).toDouble();
      }
    }

    await serviceBookingsDao.insertBooking(ServiceBookingsCompanion.insert(
      id: id,
      serviceItemId: data['service_item_id'],
      customerName: data['customer_name'],
      customerPhone: Value(data['customer_phone']),
      scheduledAt: Value(data['scheduled_at'] != null
          ? DateTime.parse(data['scheduled_at'])
          : null),
      totalAmount: Value(totalAmount),
      notes: Value(data['notes']),
      customFields: Value(_encodeCustomFields(data['custom_fields'])),
    ));
  }

  Future<void> updateBookingStatus(String bookingId, String status,
      {double? actualHours}) async {
    final booking = await serviceBookingsDao.getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found: $bookingId');

    double totalAmount = booking.totalAmount;
    if (actualHours != null) {
      final service =
          await serviceItemsDao.getServiceItemById(booking.serviceItemId);
      if (service != null) {
        totalAmount = service.hourlyRate * actualHours;
      }
    }

    await serviceBookingsDao.updateBooking(booking.copyWith(
      status: status,
      actualHours: Value(actualHours ?? booking.actualHours),
      totalAmount: totalAmount,
    ));
  }

  // === AI AGENT ===

  Future<Map<String, dynamic>?> getServiceItemByName(String serviceName) async {
    final items = await serviceItemsDao.getAllServiceItems();
    for (final item in items) {
      if (item.name.toLowerCase().contains(serviceName.toLowerCase())) {
        return {
          'id': item.id,
          'name': item.name,
          'category': item.category,
          'hourly_rate': item.hourlyRate,
          'estimated_hours': item.estimatedHours,
          'description': item.description ?? '',
          'is_active': item.isActive,
          'custom_fields': _decodeCustomFields(item.customFields),
        };
      }
    }
    return null;
  }

  Future<String> getServiceInfo(String serviceName) async {
    final items = await serviceItemsDao.getAllServiceItems();
    for (final item in items) {
      if (item.name.toLowerCase().contains(serviceName.toLowerCase())) {
        return 'Dịch vụ "${item.name}" - Loại: ${_categoryLabel(item.category)} - Đơn giá: ${item.hourlyRate.toStringAsFixed(0)} VNĐ/giờ - Ước tính: ${item.estimatedHours} giờ';
      }
    }
    return 'Không tìm thấy dịch vụ "$serviceName".';
  }

  String _categoryLabel(String category) {
    const labels = {
      'repair': 'Sửa chữa',
      'installation': 'Lắp đặt',
      'delivery': 'Vận chuyển',
      'cleaning': 'Dọn dẹp',
      'electrical': 'Điện',
      'plumbing': 'Nước',
      'other': 'Khác',
    };
    return labels[category] ?? category;
  }
}
