// lib/modules/mushrooms/models/purchasing_models.dart

class PurchaseRequestModel {
  final String id;
  final String requestNo; // e.g. "PR-2026-001"
  final DateTime requestDate;
  final DateTime requiredDate;
  final String partNo; // Mã phụ tùng / linh kiện
  final String productName; // Tên sản phẩm / vật tư
  final double quantity;
  final String unit; // Chai, Thùng, Cái, Can, Bộ, Kg, Mét...
  final String purpose; // Dùng cho việc gì (ví dụ: Bảo trì phòng 34, Phun sương M2...)
  final String department; // Growing, Harvest, Cool Room, Maintenance...
  final String? plant; // M1, M2 hoặc ALL
  final String? roomName; // Ví dụ: "Room 34"
  final String priority; // 'low', 'normal', 'high', 'urgent'
  final String status; // 'pending', 'sourcing', 'approved', 'ordered', 'received', 'rejected'
  final String requesterId;
  final String requesterName;
  final String? notes;

  // Purchasing assignment fields
  final String? supplierId;
  final String? supplierName;
  final double? estimatedCost;
  final double? actualCost;
  final String? poNumber; // e.g. "PO-M1-2026-088"
  final DateTime? expectedDeliveryDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PurchaseRequestModel({
    required this.id,
    required this.requestNo,
    required this.requestDate,
    required this.requiredDate,
    required this.partNo,
    required this.productName,
    required this.quantity,
    this.unit = 'Cái',
    required this.purpose,
    required this.department,
    this.plant,
    this.roomName,
    this.priority = 'normal',
    this.status = 'pending',
    required this.requesterId,
    required this.requesterName,
    this.notes,
    this.supplierId,
    this.supplierName,
    this.estimatedCost,
    this.actualCost,
    this.poNumber,
    this.expectedDeliveryDate,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'request_no': requestNo,
        'request_date': requestDate.toIso8601String(),
        'required_date': requiredDate.toIso8601String(),
        'part_no': partNo,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'purpose': purpose,
        'department': department,
        'plant': plant,
        'room_name': roomName,
        'priority': priority,
        'status': status,
        'requester_id': requesterId,
        'requester_name': requesterName,
        'notes': notes,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'estimated_cost': estimatedCost,
        'actual_cost': actualCost,
        'po_number': poNumber,
        'expected_delivery_date': expectedDeliveryDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory PurchaseRequestModel.fromJson(Map<String, dynamic> json) =>
      PurchaseRequestModel(
        id: json['id'] as String,
        requestNo: json['request_no'] as String? ?? 'PR-000',
        requestDate: json['request_date'] != null
            ? DateTime.tryParse(json['request_date'] as String) ?? DateTime.now()
            : DateTime.now(),
        requiredDate: json['required_date'] != null
            ? DateTime.tryParse(json['required_date'] as String) ??
                DateTime.now().add(const Duration(days: 3))
            : DateTime.now().add(const Duration(days: 3)),
        partNo: json['part_no'] as String? ?? '',
        productName: json['product_name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: json['unit'] as String? ?? 'Cái',
        purpose: json['purpose'] as String? ?? '',
        department: json['department'] as String? ?? 'Growing',
        plant: json['plant'] as String?,
        roomName: json['room_name'] as String?,
        priority: json['priority'] as String? ?? 'normal',
        status: json['status'] as String? ?? 'pending',
        requesterId: json['requester_id'] as String? ?? '',
        requesterName: json['requester_name'] as String? ?? 'Manager',
        notes: json['notes'] as String?,
        supplierId: json['supplier_id'] as String?,
        supplierName: json['supplier_name'] as String?,
        estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
        actualCost: (json['actual_cost'] as num?)?.toDouble(),
        poNumber: json['po_number'] as String?,
        expectedDeliveryDate: json['expected_delivery_date'] != null
            ? DateTime.tryParse(json['expected_delivery_date'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  PurchaseRequestModel copyWith({
    String? id,
    String? requestNo,
    DateTime? requestDate,
    DateTime? requiredDate,
    String? partNo,
    String? productName,
    double? quantity,
    String? unit,
    String? purpose,
    String? department,
    String? plant,
    String? roomName,
    String? priority,
    String? status,
    String? requesterId,
    String? requesterName,
    String? notes,
    String? supplierId,
    String? supplierName,
    double? estimatedCost,
    double? actualCost,
    String? poNumber,
    DateTime? expectedDeliveryDate,
    DateTime? updatedAt,
  }) {
    return PurchaseRequestModel(
      id: id ?? this.id,
      requestNo: requestNo ?? this.requestNo,
      requestDate: requestDate ?? this.requestDate,
      requiredDate: requiredDate ?? this.requiredDate,
      partNo: partNo ?? this.partNo,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purpose: purpose ?? this.purpose,
      department: department ?? this.department,
      plant: plant ?? this.plant,
      roomName: roomName ?? this.roomName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      notes: notes ?? this.notes,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      poNumber: poNumber ?? this.poNumber,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class SupplierModel {
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final List<String> categories;
  final double rating;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.categories = const [],
    this.rating = 5.0,
    this.notes,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contact_person': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'categories': categories,
        'rating': rating,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        contactPerson: json['contact_person'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  SupplierModel copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    List<String>? categories,
    double? rating,
    String? notes,
    bool? isActive,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      categories: categories ?? this.categories,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
