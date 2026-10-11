// Models for Wave Picking Engine & Packout Scale Verification Station
// Part of Phase 3, Sprint 7 (Industrial WMS & Logistics Automation)

class OrderAllocation {
  final String pickingId;
  final String orderCode; // e.g. SO-2026-0012
  final String customerName;
  final double quantity;
  final String uom;

  const OrderAllocation({
    required this.pickingId,
    required this.orderCode,
    required this.customerName,
    required this.quantity,
    this.uom = 'box',
  });

  Map<String, dynamic> toJson() => {
        'picking_id': pickingId,
        'order_code': orderCode,
        'customer_name': customerName,
        'quantity': quantity,
        'uom': uom,
      };
}

class WavePickItem {
  final String id;
  final String waveId;
  final int sequence; // 1, 2, 3... along optimized S-shape path
  final String locationCode; // e.g. WH1-COLD-A01-R01-L1
  final String locationName;
  final String aisle; // e.g. A01
  final int bay; // e.g. 1
  final int level; // e.g. 1
  final String productId;
  final String productName;
  final String? lotId;
  final String? lotNumber;
  final String? lpnId;
  final String? lpnCode;
  final double aggregatedQty;
  final double pickedQty;
  final String uom;
  final bool isPicked;
  final List<OrderAllocation> allocations;

  const WavePickItem({
    required this.id,
    required this.waveId,
    required this.sequence,
    required this.locationCode,
    required this.locationName,
    required this.aisle,
    required this.bay,
    required this.level,
    required this.productId,
    required this.productName,
    this.lotId,
    this.lotNumber,
    this.lpnId,
    this.lpnCode,
    required this.aggregatedQty,
    this.pickedQty = 0.0,
    this.uom = 'box',
    this.isPicked = false,
    this.allocations = const [],
  });

  WavePickItem copyWith({
    double? pickedQty,
    bool? isPicked,
    int? sequence,
  }) {
    return WavePickItem(
      id: id,
      waveId: waveId,
      sequence: sequence ?? this.sequence,
      locationCode: locationCode,
      locationName: locationName,
      aisle: aisle,
      bay: bay,
      level: level,
      productId: productId,
      productName: productName,
      lotId: lotId,
      lotNumber: lotNumber,
      lpnId: lpnId,
      lpnCode: lpnCode,
      aggregatedQty: aggregatedQty,
      pickedQty: pickedQty ?? this.pickedQty,
      uom: uom,
      isPicked: isPicked ?? this.isPicked,
      allocations: allocations,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'wave_id': waveId,
        'sequence': sequence,
        'location_code': locationCode,
        'location_name': locationName,
        'aisle': aisle,
        'bay': bay,
        'level': level,
        'product_id': productId,
        'product_name': productName,
        'lot_id': lotId,
        'lot_number': lotNumber,
        'lpn_id': lpnId,
        'lpn_code': lpnCode,
        'aggregated_qty': aggregatedQty,
        'picked_qty': pickedQty,
        'uom': uom,
        'is_picked': isPicked,
        'allocations': allocations.map((a) => a.toJson()).toList(),
      };
}

class StockWave {
  final String id;
  final String waveNumber; // e.g. WAVE-20261005-001
  final String dispatchWindow; // e.g. "Morning 08:00 - 10:00"
  final String carrier; // e.g. "Linfox Cold-Chain Transport"
  final String destinationDock; // e.g. "DOCK-02-COLD"
  final String status; // 'draft', 'released', 'in_progress', 'completed', 'cancelled'
  final List<String> pickingIds;
  final int totalOrders;
  final double totalDemandQty;
  final double totalPickedQty;
  final String? assignedDriver;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<WavePickItem> items;

  const StockWave({
    required this.id,
    required this.waveNumber,
    required this.dispatchWindow,
    required this.carrier,
    this.destinationDock = 'DOCK-01-COLD',
    this.status = 'draft',
    this.pickingIds = const [],
    required this.totalOrders,
    required this.totalDemandQty,
    this.totalPickedQty = 0.0,
    this.assignedDriver,
    required this.createdAt,
    this.completedAt,
    this.items = const [],
  });

  bool get isCompleted =>
      items.isNotEmpty && items.every((item) => item.isPicked);

  double get progressPercentage => totalDemandQty > 0
      ? (totalPickedQty / totalDemandQty).clamp(0.0, 1.0)
      : 0.0;

  StockWave copyWith({
    String? status,
    double? totalPickedQty,
    String? assignedDriver,
    DateTime? completedAt,
    List<WavePickItem>? items,
  }) {
    return StockWave(
      id: id,
      waveNumber: waveNumber,
      dispatchWindow: dispatchWindow,
      carrier: carrier,
      destinationDock: destinationDock,
      status: status ?? this.status,
      pickingIds: pickingIds,
      totalOrders: totalOrders,
      totalDemandQty: totalDemandQty,
      totalPickedQty: totalPickedQty ?? this.totalPickedQty,
      assignedDriver: assignedDriver ?? this.assignedDriver,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'wave_number': waveNumber,
        'dispatch_window': dispatchWindow,
        'carrier': carrier,
        'destination_dock': destinationDock,
        'status': status,
        'picking_ids': pickingIds,
        'total_orders': totalOrders,
        'total_demand_qty': totalDemandQty,
        'total_picked_qty': totalPickedQty,
        'assigned_driver': assignedDriver,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class PackoutWeightAuditResult {
  final String id;
  final String lpnId;
  final String lpnCode;
  final String productId;
  final String productName;
  final double cartonCount;
  final double palletTareKg; // Tare of empty wooden/plastic pallet (e.g. 35kg)
  final double cartonTareKg; // Tare per empty box (e.g. 0.45kg)
  final double productNetKg; // Total net mushroom weight (e.g. 72 * 4kg = 288kg)
  final double theoreticalGrossKg; // tare + boxes + net
  final double actualGrossKg; // Read from dock scale
  final double varianceKg; // actual - theoretical
  final double variancePercentage; // (actual - theoretical) / theoretical * 100%
  final double maxAllowedVariancePercentage; // Default 1.5%
  final bool isPassed;
  final String status; // 'verified', 'alarm_triggered', 'recount_required'
  final String? anomalyMessage;
  final String auditedBy;
  final DateTime auditedAt;
  final String? manifestAuthorizationCode;

  const PackoutWeightAuditResult({
    required this.id,
    required this.lpnId,
    required this.lpnCode,
    required this.productId,
    required this.productName,
    required this.cartonCount,
    required this.palletTareKg,
    required this.cartonTareKg,
    required this.productNetKg,
    required this.theoreticalGrossKg,
    required this.actualGrossKg,
    required this.varianceKg,
    required this.variancePercentage,
    this.maxAllowedVariancePercentage = 1.5,
    required this.isPassed,
    required this.status,
    this.anomalyMessage,
    required this.auditedBy,
    required this.auditedAt,
    this.manifestAuthorizationCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'lpn_id': lpnId,
        'lpn_code': lpnCode,
        'product_id': productId,
        'product_name': productName,
        'carton_count': cartonCount,
        'pallet_tare_kg': palletTareKg,
        'carton_tare_kg': cartonTareKg,
        'product_net_kg': productNetKg,
        'theoretical_gross_kg': theoreticalGrossKg,
        'actual_gross_kg': actualGrossKg,
        'variance_kg': varianceKg,
        'variance_percentage': variancePercentage,
        'max_allowed_variance_percentage': maxAllowedVariancePercentage,
        'is_passed': isPassed,
        'status': status,
        'anomaly_message': anomalyMessage,
        'audited_by': auditedBy,
        'audited_at': auditedAt.toIso8601String(),
        'manifest_authorization_code': manifestAuthorizationCode,
      };
}
