// Models for Quality Control Gate (QC) & Perpetual Blind Cycle Counting
// Part of Phase 2, Sprint 6 (Industrial WMS & Logistics Automation)

class QcInspectionResult {
  final String id;
  final String lotId;
  final String lotNumber;
  final String productId;
  final String productName;
  final String? lpnId;
  final String? lpnCode;
  final double productTemperature; // e.g. 2.8°C
  final String surfaceMoisture; // 'dry', 'normal', 'excess'
  final String discolorationGrade; // 'clean_white', 'minor_blemish', 'spotted', 'severe'
  final String veilOpening; // 'closed', 'slightly_open', 'flat_open'
  final String packagingIntegrity; // 'intact', 'dented', 'torn', 'contaminated'
  final String status; // 'approved', 'blocked', 'hold'
  final String? notes;
  final String inspectedBy;
  final DateTime inspectedAt;
  final bool passed;

  const QcInspectionResult({
    required this.id,
    required this.lotId,
    required this.lotNumber,
    required this.productId,
    required this.productName,
    this.lpnId,
    this.lpnCode,
    required this.productTemperature,
    required this.surfaceMoisture,
    required this.discolorationGrade,
    required this.veilOpening,
    required this.packagingIntegrity,
    required this.status,
    this.notes,
    required this.inspectedBy,
    required this.inspectedAt,
    required this.passed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'lot_id': lotId,
        'lot_number': lotNumber,
        'product_id': productId,
        'product_name': productName,
        'lpn_id': lpnId,
        'lpn_code': lpnCode,
        'product_temperature': productTemperature,
        'surface_moisture': surfaceMoisture,
        'discoloration_grade': discolorationGrade,
        'veil_opening': veilOpening,
        'packaging_integrity': packagingIntegrity,
        'status': status,
        'notes': notes,
        'inspected_by': inspectedBy,
        'inspected_at': inspectedAt.toIso8601String(),
        'passed': passed,
      };

  factory QcInspectionResult.fromJson(Map<String, dynamic> json) =>
      QcInspectionResult(
        id: json['id'] as String,
        lotId: json['lot_id'] as String,
        lotNumber: json['lot_number'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String? ?? 'N/A',
        lpnId: json['lpn_id'] as String?,
        lpnCode: json['lpn_code'] as String?,
        productTemperature: (json['product_temperature'] as num).toDouble(),
        surfaceMoisture: json['surface_moisture'] as String,
        discolorationGrade: json['discoloration_grade'] as String,
        veilOpening: json['veil_opening'] as String,
        packagingIntegrity: json['packaging_integrity'] as String,
        status: json['status'] as String,
        notes: json['notes'] as String?,
        inspectedBy: json['inspected_by'] as String,
        inspectedAt: DateTime.parse(json['inspected_at'] as String),
        passed: json['passed'] as bool? ?? false,
      );
}

/// Cycle count line representation
class CycleCountLine {
  final String id;
  final String sessionId;
  final String locationId;
  final String productId;
  final String productName;
  final String? lotId;
  final String? lotNumber;
  final String? lpnId;
  final String? lpnCode;
  final double systemQty; // Expected book qty (hidden during blind count)
  final double countedQty; // Physical count
  final double varianceQty; // countedQty - systemQty
  final String uom;
  final String status; // 'pending', 'matched', 'discrepancy', 'reconciled'
  final String? notes;

  const CycleCountLine({
    required this.id,
    required this.sessionId,
    required this.locationId,
    required this.productId,
    required this.productName,
    this.lotId,
    this.lotNumber,
    this.lpnId,
    this.lpnCode,
    required this.systemQty,
    required this.countedQty,
    required this.varianceQty,
    this.uom = 'box',
    this.status = 'pending',
    this.notes,
  });

  CycleCountLine copyWith({
    double? countedQty,
    double? varianceQty,
    String? status,
    String? notes,
  }) {
    return CycleCountLine(
      id: id,
      sessionId: sessionId,
      locationId: locationId,
      productId: productId,
      productName: productName,
      lotId: lotId,
      lotNumber: lotNumber,
      lpnId: lpnId,
      lpnCode: lpnCode,
      systemQty: systemQty,
      countedQty: countedQty ?? this.countedQty,
      varianceQty: varianceQty ?? this.varianceQty,
      uom: uom,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson({bool maskSystemQty = false}) => {
        'id': id,
        'session_id': sessionId,
        'location_id': locationId,
        'product_id': productId,
        'product_name': productName,
        'lot_id': lotId,
        'lot_number': lotNumber,
        'lpn_id': lpnId,
        'lpn_code': lpnCode,
        'system_qty': maskSystemQty ? null : systemQty,
        'counted_qty': countedQty,
        'variance_qty': maskSystemQty ? null : varianceQty,
        'uom': uom,
        'status': status,
        'notes': notes,
      };
}

/// Perpetual Cycle Count Session
class CycleCountSession {
  final String id;
  final String sessionNumber; // e.g. CC-20261005-001
  final String locationId; // Target location or zone code
  final String locationName;
  final String status; // 'in_progress', 'completed', 'reconciled', 'cancelled'
  final String countedBy;
  final String? approvedBy;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? reconciledAt;
  final List<CycleCountLine> lines;
  final String? notes;

  const CycleCountSession({
    required this.id,
    required this.sessionNumber,
    required this.locationId,
    required this.locationName,
    required this.status,
    required this.countedBy,
    this.approvedBy,
    required this.startedAt,
    this.completedAt,
    this.reconciledAt,
    this.lines = const [],
    this.notes,
  });

  int get totalLines => lines.length;

  int get matchedLines =>
      lines.where((l) => l.varianceQty == 0 && l.countedQty > 0).length;

  int get discrepancyLines =>
      lines.where((l) => l.varianceQty != 0).length;

  double get netVarianceQty =>
      lines.fold(0.0, (sum, l) => sum + l.varianceQty);

  CycleCountSession copyWith({
    String? status,
    String? approvedBy,
    DateTime? completedAt,
    DateTime? reconciledAt,
    List<CycleCountLine>? lines,
    String? notes,
  }) {
    return CycleCountSession(
      id: id,
      sessionNumber: sessionNumber,
      locationId: locationId,
      locationName: locationName,
      status: status ?? this.status,
      countedBy: countedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      reconciledAt: reconciledAt ?? this.reconciledAt,
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson({bool maskSystemQty = false}) => {
        'id': id,
        'session_number': sessionNumber,
        'location_id': locationId,
        'location_name': locationName,
        'status': status,
        'counted_by': countedBy,
        'approved_by': approvedBy,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'reconciled_at': reconciledAt?.toIso8601String(),
        'total_lines': totalLines,
        'discrepancy_lines': discrepancyLines,
        'net_variance_qty': netVarianceQty,
        'lines': lines.map((l) => l.toJson(maskSystemQty: maskSystemQty)).toList(),
        'notes': notes,
      };
}
