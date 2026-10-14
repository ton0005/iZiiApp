import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../supply_chain/repository.dart';
import '../../supply_chain/services/lpn_service.dart';
import '../models/conveyor_models.dart';

class CentralConveyorService {
  final AppDatabase _db;
  final SupplyChainRepository _supplyRepo;

  // Active conveyor state
  bool isRunning = true;
  double lineSpeedMPerMin = 24.0; // 24 meters / minute standard packhouse conveyor speed
  int totalBoxesProcessed = 0;
  int metalRejectCount = 0;
  int visionRejectCount = 0;
  int weightRejectCount = 0;

  // Central Palletizer Accumulator (72 boxes / pallet)
  final List<ConveyorBox> _accumulatedBoxes = [];
  final List<StockLpn> completedPallets = [];

  // Stream controller for live telemetry broadcasts
  final StreamController<ConveyorBox> _boxStreamController =
      StreamController<ConveyorBox>.broadcast();
  Stream<ConveyorBox> get boxTelemetryStream => _boxStreamController.stream;

  CentralConveyorService([AppDatabase? database, SupplyChainRepository? repo])
      : _db = database ?? AppDatabase(),
        _supplyRepo = repo ?? SupplyChainRepository(database);

  List<ConveyorBox> get currentAccumulatedBoxes => List.unmodifiable(_accumulatedBoxes);
  int get currentPalletBoxCount => _accumulatedBoxes.length;
  static const int boxesPerPalletStandard = 72; // 8 layers x 9 cartons (Australian standard)

  /// Feeds and processes a single carton through the complete 3-station telemetry line
  Future<ConveyorBox> processCartonOnConveyor({
    required String productSku,
    required String productName,
    required String expectedGrade,
    required String roomCode,
    required String lotNumber,
    bool simulateMetalContamination = false,
    bool simulateVisionDefect = false,
    bool simulateWeightOutlier = false,
  }) async {
    totalBoxesProcessed++;
    final boxId = 'BOX-${DateTime.now().millisecondsSinceEpoch % 10000000}';

    final box = ConveyorBox(
      boxId: boxId,
      productSku: productSku,
      productName: productName,
      expectedGrade: expectedGrade,
      roomCode: roomCode,
      lotNumber: lotNumber,
      timestamp: DateTime.now(),
    );

    // ── Station 1: Inline Metal Detector ─────────────────────────────────────
    if (simulateMetalContamination) {
      box.metalCheck = MetalCheckResult.contaminated();
      box.status = BoxStatus.divertedMetal;
      metalRejectCount++;
      _recordTelemetrySensorReading(
        deviceId: 'DEV-CONVEYOR-METAL-01',
        metric: 'metal_detect',
        value: 1.0, // 1 = metal detected
        unit: 'bool',
      );
      _boxStreamController.add(box);
      return box;
    } else {
      box.metalCheck = MetalCheckResult.clean();
      box.status = BoxStatus.metalInspected;
    }

    // ── Station 2: AI Vision Camera Inspection ───────────────────────────────
    if (simulateVisionDefect) {
      box.visionCheck = VisionCheckResult.defective();
      box.status = BoxStatus.divertedVision;
      visionRejectCount++;
      _boxStreamController.add(box);
      return box;
    } else {
      box.visionCheck = VisionCheckResult.standardCup();
      box.status = BoxStatus.visionInspected;
    }

    // ── Station 3: Dynamic In-Line Check-Weigher ─────────────────────────────
    if (simulateWeightOutlier) {
      box.weigherResult = const CheckWeigherResult(
        netWeightKg: 3.25, // Significantly underweight
        grossWeightKg: 3.60,
        tareWeightKg: 0.35,
        targetNetKg: 4.0,
        isWithinTolerance: false,
        variancePct: -18.75,
      );
      box.status = BoxStatus.divertedWeight;
      weightRejectCount++;
      _boxStreamController.add(box);
      return box;
    } else {
      box.weigherResult = CheckWeigherResult.normal(target: 4.0);
      box.status = BoxStatus.weighed;
    }

    // Log dynamic carton weight to SensorReadings
    _recordTelemetrySensorReading(
      deviceId: 'DEV-CONVEYOR-SCALE-01',
      metric: 'weight_kg',
      value: box.weigherResult!.netWeightKg,
      unit: 'kg',
    );

    // ── Station 4: Accumulate onto Central Pallet ────────────────────────────
    box.status = BoxStatus.palletized;
    _accumulatedBoxes.add(box);
    _boxStreamController.add(box);

    return box;
  }

  /// Automatically mints and registers an LPN Pallet when 72 boxes are reached (or manually requested)
  Future<StockLpn?> finalizePalletAtCentralStation({
    String plant = 'M1',
    String? customLotNumber,
    String? productId,
  }) async {
    if (_accumulatedBoxes.isEmpty) return null;

    final firstBox = _accumulatedBoxes.first;
    final lotNum = customLotNumber ?? firstBox.lotNumber;

    // Resolve or find Product ID
    String prodId = productId ?? '';
    if (prodId.isEmpty) {
      final prods = await _supplyRepo.getAllProducts();
      final match = prods.where((p) =>
          p.sku.toUpperCase() == firstBox.productSku.toUpperCase() ||
          p.name.toUpperCase().contains(firstBox.expectedGrade.toUpperCase())).firstOrNull;
      prodId = match?.id ?? (prods.isNotEmpty ? prods.first.id : 'prod-cup-01');
    }

    // Ensure Lot exists
    StockLot? lot = await _supplyRepo.getLotByNumber(lotNum);
    lot ??= await _supplyRepo.createLot(
        productId: prodId,
        lotNumber: lotNum,
        productionDate: DateTime.now(),
        bestBeforeDate: DateTime.now().add(const Duration(days: 5)),
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        status: 'approved',
        notes: 'Đóng pallet tự động tại trạm trung tâm băng tải ($plant)',
      );

    // Calculate aggregated net weight from all individual check-weigher readings
    final totalNetWeight = _accumulatedBoxes.fold<double>(
      0.0,
      (sum, b) => sum + (b.weigherResult?.netWeightKg ?? 4.0),
    );
    const palletWoodTareKg = 35.0; // Australian standard timber pallet + strapping
    final totalGrossWeight = totalNetWeight + palletWoodTareKg;
    final boxCount = _accumulatedBoxes.length;

    // Mint Pallet LPN and SSCC-18
    final lpnCode = LpnService.generateLpnCode(plant: plant);
    final sscc18 = LpnService.generateSscc18(
      serialNumber: DateTime.now().millisecondsSinceEpoch % 1000000,
    );

    final pallet = await _supplyRepo.createPalletLpn(
      lpnCode: lpnCode,
      locationId: '$plant-STAGING',
      productId: prodId,
      lotId: lot.id,
      quantity: boxCount.toDouble(),
      uomId: 'box',
      grossWeightKg: double.parse(totalGrossWeight.toStringAsFixed(2)),
      tareWeightKg: palletWoodTareKg,
      netWeightKg: double.parse(totalNetWeight.toStringAsFixed(2)),
      customFields: {
        'sscc_18': sscc18,
        'conveyor_source': 'Central Conveyor Line #01',
        'box_count': boxCount,
        'average_box_net_kg': double.parse((totalNetWeight / boxCount).toStringAsFixed(3)),
      },
    );

    completedPallets.insert(0, pallet);
    _accumulatedBoxes.clear(); // Reset accumulator for next pallet

    return pallet;
  }

  /// Station 5: In-Floor Scale (Weighbridge) at Cold Store High-Speed Door
  /// Verifies gross pallet weight against the sum of upstream box check-weigher weights.
  Future<GateWeighbridgeResult> verifyPalletAtGateWeighbridge({
    required String lpnCode,
    required double scaleMeasuredGrossKg,
  }) async {
    final pallet = await _supplyRepo.getLpnByCode(lpnCode);
    if (pallet == null) {
      throw ArgumentError('Không tìm thấy pallet với mã $lpnCode');
    }

    final upstreamGross = pallet.grossWeightKg ?? 323.0;
    final upstreamNet = pallet.netWeightKg ?? 288.0;

    final diffKg = (scaleMeasuredGrossKg - upstreamGross).abs();
    final diffPct = (diffKg / upstreamGross) * 100.0;

    // Tolerance check: +/- 1.5% between upstream check-weigher accumulation and weighbridge
    final isWithinGateTolerance = diffPct <= 1.5;

    String msg;
    if (isWithinGateTolerance) {
      msg = 'TẢI TRỌNG HỢP LỆ (Lệch ${diffPct.toStringAsFixed(2)}% <= 1.5%): '
          'Cửa tự động mở. Mời xe nâng đưa pallet vào Kho lạnh.';

      // Record Automation Event for Fast-Action Door Trigger
      final eventId = const Uuid().v4();
      await _db.into(_db.automationEvents).insert(
            AutomationEventsCompanion.insert(
              id: eventId,
              ruleId: 'RULE-DOOR-AUTO-OPEN-01',
              locationId: const Value('WH1-COLD-GATE'),
              triggeringValue: Value(scaleMeasuredGrossKg),
              status: const Value('executed'),
              resultRecordType: const Value('stock_lpns'),
              resultRecordId: Value(pallet.id),
            ),
          );

      SyncService().queueMutation('automation_events', 'insert', {
        'id': eventId,
        'rule_id': 'RULE-DOOR-AUTO-OPEN-01',
        'location_id': 'WH1-COLD-GATE',
        'triggering_value': scaleMeasuredGrossKg,
        'status': 'executed',
        'action': 'door_open',
      });
    } else {
      msg = 'CẢNH BÁO LỆCH TẢI TRỌNG (Lệch ${diffPct.toStringAsFixed(2)}% > 1.5%): '
          'Cân sàn = ${scaleMeasuredGrossKg.toStringAsFixed(1)} kg vs Băng tải = ${upstreamGross.toStringAsFixed(1)} kg. '
          'Cửa kho lạnh bị khóa, yêu cầu kiểm định pallet.';
    }

    return GateWeighbridgeResult(
      lpnCode: lpnCode,
      upstreamAccumulatedNetKg: upstreamNet,
      upstreamGrossKg: upstreamGross,
      scaleMeasuredGrossKg: scaleMeasuredGrossKg,
      differenceKg: double.parse(diffKg.toStringAsFixed(2)),
      differencePct: double.parse(diffPct.toStringAsFixed(2)),
      isDoorOpened: isWithinGateTolerance,
      validationMessage: msg,
    );
  }

  void _recordTelemetrySensorReading({
    required String deviceId,
    required String metric,
    required double value,
    required String unit,
  }) {
    final readingId = const Uuid().v4();
    _db.into(_db.sensorReadings).insert(
          SensorReadingsCompanion.insert(
            id: readingId,
            deviceId: deviceId,
            locationId: const Value('M1-CENTRAL-CONVEYOR'),
            metric: metric,
            value: value,
            unit: unit,
            measuredAt: DateTime.now(),
            quality: const Value('ok'),
          ),
        );
  }

  void dispose() {
    _boxStreamController.close();
  }
}
