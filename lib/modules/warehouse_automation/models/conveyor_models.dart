import 'dart:math';

enum ConveyorStation {
  infeed,
  metalDetector,
  visionCamera,
  checkWeigher,
  palletizer,
  airlockGate,
}

enum BoxStatus {
  infeed,
  metalInspected,
  visionInspected,
  weighed,
  palletized,
  divertedMetal,
  divertedVision,
  divertedWeight,
}

class MetalCheckResult {
  final bool hasMetal;
  final double signalUv; // Microvolt signal detected
  final bool isPassed;
  final String? rejectReason;

  const MetalCheckResult({
    required this.hasMetal,
    required this.signalUv,
    required this.isPassed,
    this.rejectReason,
  });

  factory MetalCheckResult.clean() {
    return const MetalCheckResult(
      hasMetal: false,
      signalUv: 12.5,
      isPassed: true,
    );
  }

  factory MetalCheckResult.contaminated({String reason = 'Ferrous particle detected >= 1.0mm'}) {
    return MetalCheckResult(
      hasMetal: true,
      signalUv: 840.0,
      isPassed: false,
      rejectReason: reason,
    );
  }
}

class VisionCheckResult {
  final String detectedGrade; // Button, Cup, Flat
  final double confidence; // e.g. 0.985
  final double capDiameterMm; // e.g. 52.4 mm
  final double surfaceBlemishPct; // e.g. 0.4%
  final bool isPassed;
  final String? anomalyNotes;

  const VisionCheckResult({
    required this.detectedGrade,
    required this.confidence,
    required this.capDiameterMm,
    required this.surfaceBlemishPct,
    required this.isPassed,
    this.anomalyNotes,
  });

  factory VisionCheckResult.standardCup() {
    final rand = Random();
    final diameter = 48.0 + (rand.nextDouble() * 12.0); // 48 - 60mm
    final blemish = rand.nextDouble() * 1.2;
    return VisionCheckResult(
      detectedGrade: 'Cup',
      confidence: 0.97 + (rand.nextDouble() * 0.028),
      capDiameterMm: double.parse(diameter.toStringAsFixed(1)),
      surfaceBlemishPct: double.parse(blemish.toStringAsFixed(2)),
      isPassed: true,
    );
  }

  factory VisionCheckResult.defective() {
    return const VisionCheckResult(
      detectedGrade: 'Flat',
      confidence: 0.72,
      capDiameterMm: 78.5,
      surfaceBlemishPct: 14.5,
      isPassed: false,
      anomalyNotes: 'Grade mismatch: Expected Cup, detected Flat with open veil (14.5% blemish)',
    );
  }
}

class CheckWeigherResult {
  final double netWeightKg;
  final double grossWeightKg;
  final double tareWeightKg;
  final double targetNetKg;
  final bool isWithinTolerance;
  final double variancePct;

  const CheckWeigherResult({
    required this.netWeightKg,
    required this.grossWeightKg,
    required this.tareWeightKg,
    required this.targetNetKg,
    required this.isWithinTolerance,
    required this.variancePct,
  });

  factory CheckWeigherResult.normal({double target = 4.0}) {
    final rand = Random();
    // Normal box: 4.0 kg +/- 0.04 kg
    final variance = (rand.nextDouble() - 0.5) * 0.08;
    final net = target + variance;
    const tare = 0.35; // Corrugated cardboard carton tare
    final gross = net + tare;
    final varPct = ((net - target) / target) * 100.0;

    return CheckWeigherResult(
      netWeightKg: double.parse(net.toStringAsFixed(3)),
      grossWeightKg: double.parse(gross.toStringAsFixed(3)),
      tareWeightKg: tare,
      targetNetKg: target,
      isWithinTolerance: varPct.abs() <= 2.5,
      variancePct: double.parse(varPct.toStringAsFixed(2)),
    );
  }
}

class ConveyorBox {
  final String boxId;
  final String productSku;
  final String productName;
  final String expectedGrade;
  final String roomCode;
  final String lotNumber;
  final DateTime timestamp;

  BoxStatus status;
  MetalCheckResult? metalCheck;
  VisionCheckResult? visionCheck;
  CheckWeigherResult? weigherResult;

  ConveyorBox({
    required this.boxId,
    required this.productSku,
    required this.productName,
    required this.expectedGrade,
    required this.roomCode,
    required this.lotNumber,
    required this.timestamp,
    this.status = BoxStatus.infeed,
    this.metalCheck,
    this.visionCheck,
    this.weigherResult,
  });
}

class GateWeighbridgeResult {
  final String lpnCode;
  final double upstreamAccumulatedNetKg;
  final double upstreamGrossKg; // accumulated net + 35kg wood pallet
  final double scaleMeasuredGrossKg;
  final double differenceKg;
  final double differencePct;
  final bool isDoorOpened;
  final String validationMessage;

  const GateWeighbridgeResult({
    required this.lpnCode,
    required this.upstreamAccumulatedNetKg,
    required this.upstreamGrossKg,
    required this.scaleMeasuredGrossKg,
    required this.differenceKg,
    required this.differencePct,
    required this.isDoorOpened,
    required this.validationMessage,
  });
}
