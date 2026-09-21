// lib/modules/mushrooms/services/purchasing_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/core/sync/sync_service.dart';
import '../models/purchasing_models.dart';

class MushroomPurchasingService {
  static final MushroomPurchasingService _instance =
      MushroomPurchasingService._internal();

  factory MushroomPurchasingService([AppDatabase? db]) {
    if (db != null) {
      _instance._db = db;
    }
    return _instance;
  }

  MushroomPurchasingService._internal() : _db = AppDatabase();

  AppDatabase _db;

  static const String _keyPurchaseRequests = 'mushrooms_purchase_requests_store';
  static const String _keySuppliersCatalog = 'mushrooms_suppliers_catalog_store';

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  Stream<void> get watchChanges => _changesController.stream;

  List<PurchaseRequestModel>? _cachedRequests;
  List<SupplierModel>? _cachedSuppliers;

  // --- Seed Data For Costa Mushrooms Monarto Farm ---

  static List<SupplierModel> get defaultSuppliers => [
        SupplierModel(
          id: 'SUP-001',
          name: 'Costa Farm Supplies Adelaide',
          contactPerson: 'David Miller',
          phone: '+61 8 8234 5678',
          email: 'orders.sa@costagroup.com.au',
          address: 'Monarto Industrial Park, SA 5254',
          categories: ['Chemicals & Treatments', 'Mushroom Trays', 'Harvesting Tools'],
          rating: 4.9,
          notes: 'Internal primary supplier for Costa Group, 24h dispatch guarantee.',
        ),
        SupplierModel(
          id: 'SUP-002',
          name: 'Enviro Air Filters Australia P/L',
          contactPerson: 'Sarah Jenkins',
          phone: '+61 8 8345 1200',
          email: 'sales@envirofilter.com.au',
          address: 'Wingfield, Adelaide, SA 5013',
          categories: ['HEPA Filters', 'Bacterial Filter Bags', 'Ventilation Ducts'],
          rating: 4.8,
          notes: 'Specializes in cleanroom & AHU filtration for Grow Rooms 1-66.',
        ),
        SupplierModel(
          id: 'SUP-003',
          name: 'AgriTech Fungicide Solutions',
          contactPerson: 'Dr. Robert Nguyen',
          phone: '+61 2 9876 5432',
          email: 'robert@agritechsolutions.com.au',
          address: 'Silverwater, Sydney, NSW 2128',
          categories: ['Chemicals & Treatments', 'Prochloraz', 'Disinfectants'],
          rating: 4.7,
          notes: 'Exclusive distributor for Prochloraz 450g/L EC fungicide.',
        ),
        SupplierModel(
          id: 'SUP-004',
          name: 'Monarto Industrial Hardware & Seals',
          contactPerson: 'Brett Taylor',
          phone: '+61 8 8532 9911',
          email: 'brett@monartohardware.com.au',
          address: 'Murray Bridge Commercial Rd, SA 5253',
          categories: ['Mechanical Parts & Pumps', 'Solenoid Valves', 'Trolley Wheels', 'Maintenance Supplies'],
          rating: 4.6,
          notes: 'Supplies replacement pump seals, pressure valves, and hardware fittings.',
        ),
        SupplierModel(
          id: 'SUP-005',
          name: 'EcoPack Australia Packaging',
          contactPerson: 'Elena Rossi',
          phone: '+61 3 9450 7890',
          email: 'packaging@ecopack.com.au',
          address: 'Dandenong South, VIC 3175',
          categories: ['Packaging & Trays', 'Cling Wrap', '4kg/10kg Cartons'],
          rating: 4.5,
          notes: 'Supplies cartons and punnet plastics for Button, Medium, and Cup mushrooms.',
        ),
      ];

  static List<PurchaseRequestModel> get defaultPurchaseRequests => [
        PurchaseRequestModel(
          id: 'PR-2026-001',
          requestNo: 'PR-2026-001',
          requestDate: DateTime.now().subtract(const Duration(days: 2)),
          requiredDate: DateTime.now().add(const Duration(days: 2)),
          partNo: 'PROCH-450-5L',
          productName: 'Prochloraz 450g/L Emulsifiable Concentrate (5L Can)',
          quantity: 4,
          unit: 'Canister (5L/20L)',
          purpose: 'Surface treatment for Rooms 34 and 35 new cropping cycle',
          department: 'Growing',
          plant: 'M2',
          roomName: 'Room 34',
          priority: 'urgent',
          status: 'ordered',
          requesterId: 'MGR-VINH',
          requesterName: 'Vinh (Growing Lead)',
          notes: 'Urgent before the 22nd to match casing and watering schedule',
          supplierId: 'SUP-003',
          supplierName: 'AgriTech Fungicide Solutions',
          estimatedCost: 1280.0,
          actualCost: 1250.0,
          poNumber: 'PO-M2-2026-042',
          expectedDeliveryDate: DateTime.now().add(const Duration(days: 1)),
        ),
        PurchaseRequestModel(
          id: 'PR-2026-002',
          requestNo: 'PR-2026-002',
          requestDate: DateTime.now().subtract(const Duration(days: 1)),
          requiredDate: DateTime.now().add(const Duration(days: 4)),
          partNo: 'HEPA-FLT-600X600',
          productName: 'HEPA Filter H14 High Flow 610x610x292mm',
          quantity: 6,
          unit: 'Unit / Piece',
          purpose: 'Routine replacement of AHU air filtration for Grow Rooms 33 & 36',
          department: 'Maintenance',
          plant: 'M2',
          roomName: 'Room 33',
          priority: 'high',
          status: 'sourcing',
          requesterId: 'MGR-NAM',
          requesterName: 'Nam (Maintenance Lead)',
          notes: 'Differential pressure sensor exceeded 250Pa warning threshold',
          supplierId: 'SUP-002',
          supplierName: 'Enviro Air Filters Australia P/L',
          estimatedCost: 2100.0,
        ),
        PurchaseRequestModel(
          id: 'PR-2026-003',
          requestNo: 'PR-2026-003',
          requestDate: DateTime.now(),
          requiredDate: DateTime.now().add(const Duration(days: 5)),
          partNo: 'PUNNET-200G-CL',
          productName: 'Clear Mushroom Punnet 200g (Carton of 500)',
          quantity: 20,
          unit: 'Box / Carton',
          purpose: 'Packaging for Coles & Woolworths supermarket deliveries next week',
          department: 'Harvest',
          plant: 'M1',
          roomName: null,
          priority: 'normal',
          status: 'pending',
          requesterId: 'MGR-HAI',
          requesterName: 'Hai (Harvest Supervisor)',
          notes: 'Packing shed M1 stock is down to 5 cartons buffer',
        ),
      ];

  // --- Purchase Requests CRUD ---

  Future<List<PurchaseRequestModel>> getPurchaseRequests({
    String? status,
    String? department,
    String? searchQuery,
  }) async {
    if (_cachedRequests == null) {
      await _loadRequestsFromDb();
    }

    var list = List<PurchaseRequestModel>.from(_cachedRequests!);

    if (status != null && status.isNotEmpty && status != 'all') {
      list = list.where((r) => r.status.toLowerCase() == status.toLowerCase()).toList();
    }

    if (department != null && department.isNotEmpty && department != 'all') {
      list = list
          .where((r) => r.department.toLowerCase() == department.toLowerCase())
          .toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((r) {
        return r.requestNo.toLowerCase().contains(q) ||
            r.partNo.toLowerCase().contains(q) ||
            r.productName.toLowerCase().contains(q) ||
            r.purpose.toLowerCase().contains(q) ||
            r.requesterName.toLowerCase().contains(q) ||
            (r.supplierName ?? '').toLowerCase().contains(q) ||
            (r.roomName ?? '').toLowerCase().contains(q);
      }).toList();
    }

    // Sắp xếp: Ưu tiên urgent/high lên trước, sau đó theo ngày cần hàng gần nhất
    list.sort((a, b) {
      final priorityWeight = {'urgent': 4, 'high': 3, 'normal': 2, 'low': 1};
      final pA = priorityWeight[a.priority] ?? 2;
      final pB = priorityWeight[b.priority] ?? 2;
      if (pA != pB) {
        return pB.compareTo(pA);
      }
      return a.requiredDate.compareTo(b.requiredDate);
    });

    return list;
  }

  Future<void> _loadRequestsFromDb() async {
    try {
      final row = await (_db.select(_db.appSettings)
            ..where((tbl) => tbl.key.equals(_keyPurchaseRequests)))
          .getSingleOrNull();

      if (row == null || row.value.trim().isEmpty) {
        final initial = defaultPurchaseRequests;
        await _saveRequestsList(initial);
        _cachedRequests = initial;
        return;
      }

      final dynamic decoded = jsonDecode(row.value);
      if (decoded is List) {
        _cachedRequests = decoded
            .map((item) =>
                PurchaseRequestModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        return;
      }
    } catch (e) {
      debugPrint('[PurchasingService] Error loading requests: $e');
    }

    _cachedRequests = List.from(defaultPurchaseRequests);
  }

  Future<void> _saveRequestsList(List<PurchaseRequestModel> requests) async {
    final jsonStr = jsonEncode(requests.map((r) => r.toJson()).toList());
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSetting(key: _keyPurchaseRequests, value: jsonStr),
        );
    _cachedRequests = List<PurchaseRequestModel>.from(requests);
    _changesController.add(null);

    // Kích hoạt outbox sync ngầm
    SyncService().debounceFlushOutbox();
  }

  Future<String> generateNextRequestNo() async {
    final list = await getPurchaseRequests();
    final year = DateTime.now().year;
    final prefix = 'PR-$year-';
    var maxIndex = 0;

    for (final r in list) {
      if (r.requestNo.startsWith(prefix)) {
        final suffix = r.requestNo.substring(prefix.length);
        final val = int.tryParse(suffix);
        if (val != null && val > maxIndex) {
          maxIndex = val;
        }
      }
    }

    final nextSeq = (maxIndex + 1).toString().padLeft(3, '0');
    return '$prefix$nextSeq';
  }

  Future<void> createPurchaseRequest(PurchaseRequestModel request) async {
    final list = await getPurchaseRequests();
    list.insert(0, request);
    await _saveRequestsList(list);
  }

  Future<void> updatePurchaseRequest(PurchaseRequestModel updatedRequest) async {
    final list = await getPurchaseRequests();
    final index = list.indexWhere((r) => r.id == updatedRequest.id);
    if (index >= 0) {
      list[index] = updatedRequest.copyWith(updatedAt: DateTime.now());
      await _saveRequestsList(list);
    }
  }

  Future<void> deletePurchaseRequest(String id) async {
    final list = await getPurchaseRequests();
    list.removeWhere((r) => r.id == id);
    await _saveRequestsList(list);
  }

  Future<void> assignSupplierToRequest(
    String requestId,
    SupplierModel supplier, {
    double? estimatedCost,
    String? poNumber,
    DateTime? expectedDeliveryDate,
  }) async {
    final list = await getPurchaseRequests();
    final index = list.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      final current = list[index];
      final newStatus = (current.status == 'pending') ? 'sourcing' : current.status;
      list[index] = current.copyWith(
        supplierId: supplier.id,
        supplierName: supplier.name,
        estimatedCost: estimatedCost ?? current.estimatedCost,
        poNumber: poNumber ?? current.poNumber,
        expectedDeliveryDate: expectedDeliveryDate ?? current.expectedDeliveryDate,
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await _saveRequestsList(list);
    }
  }

  Future<void> updateRequestStatus(String requestId, String newStatus) async {
    final list = await getPurchaseRequests();
    final index = list.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      final current = list[index];
      list[index] = current.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await _saveRequestsList(list);
    }
  }

  // --- Suppliers CRUD ---

  Future<List<SupplierModel>> getSuppliers({
    String? searchQuery,
    String? category,
  }) async {
    if (_cachedSuppliers == null) {
      await _loadSuppliersFromDb();
    }

    var list = List<SupplierModel>.from(_cachedSuppliers!);

    if (category != null && category.isNotEmpty && category != 'all') {
      list = list.where((s) => s.categories.contains(category)).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            (s.contactPerson ?? '').toLowerCase().contains(q) ||
            (s.phone ?? '').toLowerCase().contains(q) ||
            (s.email ?? '').toLowerCase().contains(q) ||
            s.categories.any((c) => c.toLowerCase().contains(q));
      }).toList();
    }

    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _loadSuppliersFromDb() async {
    try {
      final row = await (_db.select(_db.appSettings)
            ..where((tbl) => tbl.key.equals(_keySuppliersCatalog)))
          .getSingleOrNull();

      if (row == null || row.value.trim().isEmpty) {
        final initial = defaultSuppliers;
        await _saveSuppliersList(initial);
        _cachedSuppliers = initial;
        return;
      }

      final dynamic decoded = jsonDecode(row.value);
      if (decoded is List) {
        _cachedSuppliers = decoded
            .map((item) =>
                SupplierModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        return;
      }
    } catch (e) {
      debugPrint('[PurchasingService] Error loading suppliers: $e');
    }

    _cachedSuppliers = List.from(defaultSuppliers);
  }

  Future<void> _saveSuppliersList(List<SupplierModel> suppliers) async {
    final jsonStr = jsonEncode(suppliers.map((s) => s.toJson()).toList());
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSetting(key: _keySuppliersCatalog, value: jsonStr),
        );
    _cachedSuppliers = List<SupplierModel>.from(suppliers);
    _changesController.add(null);
    SyncService().debounceFlushOutbox();
  }

  Future<void> saveSupplier(SupplierModel supplier) async {
    final list = await getSuppliers();
    final index = list.indexWhere((s) => s.id == supplier.id);
    if (index >= 0) {
      list[index] = supplier;
    } else {
      list.add(supplier);
    }
    await _saveSuppliersList(list);
  }

  Future<void> deleteSupplier(String id) async {
    final list = await getSuppliers();
    list.removeWhere((s) => s.id == id);
    await _saveSuppliersList(list);
  }
}
