import '../../../core/database/app_database.dart';

class PutawayRecommendation {
  final Location targetLocation;
  final double score;
  final String slotReason;
  final double palletGrossWeightKg;
  final double availableCapacityKg;
  final double currentOccupiedWeightKg;
  final String navigationPath;

  const PutawayRecommendation({
    required this.targetLocation,
    required this.score,
    required this.slotReason,
    required this.palletGrossWeightKg,
    required this.availableCapacityKg,
    required this.currentOccupiedWeightKg,
    required this.navigationPath,
  });
}

class FefoAllocationLine {
  final String quantId;
  final String? lpnId;
  final String? lpnCode;
  final String locationCode;
  final String locationName;
  final String lotId;
  final String lotNumber;
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final double allocatedQty;
  final String uom;

  const FefoAllocationLine({
    required this.quantId,
    this.lpnId,
    this.lpnCode,
    required this.locationCode,
    required this.locationName,
    required this.lotId,
    required this.lotNumber,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.allocatedQty,
    this.uom = 'box',
  });
}

class FefoAllocationResult {
  final String productId;
  final String productName;
  final double requestedQuantity;
  final double allocatedQuantity;
  final double unfulfilledQuantity;
  final bool isFullyAllocated;
  final List<FefoAllocationLine> lines;
  final DateTime? earliestExpiry;
  final String summaryNotes;

  const FefoAllocationResult({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.allocatedQuantity,
    required this.unfulfilledQuantity,
    required this.isFullyAllocated,
    required this.lines,
    this.earliestExpiry,
    required this.summaryNotes,
  });
}
