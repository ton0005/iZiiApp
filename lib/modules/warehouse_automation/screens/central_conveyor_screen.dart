import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/app_database.dart';
import '../../supply_chain/repository.dart';
import '../models/conveyor_models.dart';
import '../services/central_conveyor_service.dart';

class CentralConveyorScreen extends StatefulWidget {
  const CentralConveyorScreen({super.key});

  @override
  State<CentralConveyorScreen> createState() => _CentralConveyorScreenState();
}

class _CentralConveyorScreenState extends State<CentralConveyorScreen> {
  final CentralConveyorService _conveyorService = CentralConveyorService();
  final SupplyChainRepository _supplyRepo = SupplyChainRepository();

  StreamSubscription<ConveyorBox>? _telemetrySub;

  // Live state
  ConveyorBox? _latestBox;
  final List<ConveyorBox> _recentEventLog = [];
  bool _isProcessingBatch = false;

  // Selected for Weighbridge Door Test
  StockLpn? _selectedPalletForGate;
  final TextEditingController _gateScaleInputController = TextEditingController();
  GateWeighbridgeResult? _gateResult;

  // Mushroom infeed config
  final String _selectedGrade = 'Cup';
  final String _roomCode = 'R33';
  final String _lotNumber = 'LOT-20261005-R33-CUP';

  @override
  void initState() {
    super.initState();
    _telemetrySub = _conveyorService.boxTelemetryStream.listen((box) {
      if (mounted) {
        setState(() {
          _latestBox = box;
          _recentEventLog.insert(0, box);
          if (_recentEventLog.length > 20) {
            _recentEventLog.removeLast();
          }
        });
      }
    });
    _loadInitialProducts();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _conveyorService.dispose();
    _gateScaleInputController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProducts() async {
    final prods = await _supplyRepo.getAllProducts();
    if (prods.isEmpty) {
      // Seed a default mushroom product for seamless demo
      await _supplyRepo.addProductWithStock(
        id: 'prod-cup-01',
        sku: 'MUSH-CUP-4KG',
        name: 'Cup Mushroom 4kg',
        price: 24.0,
        cost: 16.0,
        stock: 0,
        barcode: '9312345000017',
      );
    }
  }

  Future<void> _infeedSingleBox({
    bool simulateMetal = false,
    bool simulateVision = false,
    bool simulateWeight = false,
  }) async {
    HapticFeedback.lightImpact();
    await _conveyorService.processCartonOnConveyor(
      productSku: 'MUSH-${_selectedGrade.toUpperCase()}-4KG',
      productName: '$_selectedGrade Mushroom 4kg',
      expectedGrade: _selectedGrade,
      roomCode: _roomCode,
      lotNumber: _lotNumber,
      simulateMetalContamination: simulateMetal,
      simulateVisionDefect: simulateVision,
      simulateWeightOutlier: simulateWeight,
    );

    // If 72 boxes accumulated, auto finalize pallet!
    if (_conveyorService.currentPalletBoxCount >= CentralConveyorService.boxesPerPalletStandard) {
      await _finalizePallet();
    } else {
      setState(() {});
    }
  }

  Future<void> _runFullPalletBatch() async {
    setState(() => _isProcessingBatch = true);
    HapticFeedback.mediumImpact();

    // Stream 72 boxes in quick succession
    for (int i = 0; i < 72; i++) {
      await _conveyorService.processCartonOnConveyor(
        productSku: 'MUSH-${_selectedGrade.toUpperCase()}-4KG',
        productName: '$_selectedGrade Mushroom 4kg',
        expectedGrade: _selectedGrade,
        roomCode: _roomCode,
        lotNumber: _lotNumber,
      );
      if (i % 10 == 0) {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }

    final pallet = await _finalizePallet();
    setState(() {
      _isProcessingBatch = false;
      if (pallet != null) {
        _selectedPalletForGate = pallet;
        _gateScaleInputController.text = (pallet.grossWeightKg ?? 323.0).toStringAsFixed(1);
      }
    });

    if (mounted && pallet != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          content: Text(
            'PALLET COMPLETED: 72 cartons stacked successfully! LPN: ${pallet.lpnCode}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      );
    }
  }

  Future<StockLpn?> _finalizePallet() async {
    final pallet = await _conveyorService.finalizePalletAtCentralStation(
      plant: 'M1',
      customLotNumber: _lotNumber,
    );
    if (pallet != null && mounted) {
      setState(() {
        _selectedPalletForGate = pallet;
        _gateScaleInputController.text = (pallet.grossWeightKg ?? 323.0).toStringAsFixed(1);
      });
      HapticFeedback.vibrate();
    }
    return pallet;
  }

  Future<void> _testAirlockDoorScale() async {
    if (_selectedPalletForGate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or finalize a pallet LPN first.')),
      );
      return;
    }

    final weight = double.tryParse(_gateScaleInputController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weighbridge gross weight.')),
      );
      return;
    }

    final result = await _conveyorService.verifyPalletAtGateWeighbridge(
      lpnCode: _selectedPalletForGate!.lpnCode,
      scaleMeasuredGrossKg: weight,
    );

    setState(() => _gateResult = result);

    if (result.isDoorOpened) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CENTRAL INFEED CONVEYOR & WAREHOUSE INTAKE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Central Packhouse Line Telemetry & Airlock Scale',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: const Row(
              children: [
                Icon(Icons.play_circle_fill, color: Color(0xFF34D399), size: 16),
                SizedBox(width: 6),
                Text(
                  'SPEED: 24 m/min',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section 1: Line Infeed & Summary Bar ──
            _buildLineSummaryCard(),
            const SizedBox(height: 16),

            // ── Section 2: 3-Station Industrial Telemetry Line ──
            _buildTelemetryStationsRow(),
            const SizedBox(height: 16),

            // ── Section 3: Central Palletizing Station ──
            _buildCentralPalletizerCard(),
            const SizedBox(height: 16),

            // ── Section 4: Airlock Gate & In-Floor Weighbridge Door Trigger ──
            _buildAirlockGateSection(),
            const SizedBox(height: 16),

            // ── Section 5: Real-Time Event Stream Log ──
            _buildEventLogSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLineSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryMetric(
            'TOTAL INFEED',
            '${_conveyorService.totalBoxesProcessed}',
            Colors.white,
            Icons.conveyor_belt,
          ),
          _buildSummaryMetric(
            'PALLET QUEUE',
            '${_conveyorService.currentPalletBoxCount} / 72',
            Colors.amber,
            Icons.layers,
          ),
          _buildSummaryMetric(
            'METAL REJECTS',
            '${_conveyorService.metalRejectCount}',
            Colors.redAccent,
            Icons.warning_amber,
          ),
          _buildSummaryMetric(
            'VISION/SCALE REJECTS',
            '${_conveyorService.visionRejectCount + _conveyorService.weightRejectCount}',
            Colors.orangeAccent,
            Icons.camera_alt,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String val, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildTelemetryStationsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3-STATION INLINE TELEMETRY & QUALITY CONTROL',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station 1: Metal Detector
            Expanded(child: _buildStation1MetalDetectorCard()),
            const SizedBox(width: 10),
            // Station 2: AI Vision Camera
            Expanded(child: _buildStation2VisionCameraCard()),
            const SizedBox(width: 10),
            // Station 3: Dynamic Check-Weigher
            Expanded(child: _buildStation3CheckWeigherCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildStation1MetalDetectorCard() {
    final isClean = _latestBox?.metalCheck?.isPassed ?? true;
    final hasEvent = _latestBox?.metalCheck != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasEvent && !isClean ? Colors.red : Colors.white24,
          width: hasEvent && !isClean ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. METAL DETECTOR',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Icon(
                hasEvent && !isClean ? Icons.error : Icons.verified,
                color: hasEvent && !isClean ? Colors.red : const Color(0xFF10B981),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: hasEvent && !isClean ? Colors.red.withValues(alpha: 0.2) : const Color(0xFF065F46),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              hasEvent && !isClean ? 'REJECT (DIVERTER)' : 'PASS (CLEAN)',
              style: TextStyle(
                color: hasEvent && !isClean ? Colors.redAccent : const Color(0xFF34D399),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Sensitivity: Fe ≥1mm', style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: () => _infeedSingleBox(simulateMetal: true),
            child: const Text('Simulate Metal', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildStation2VisionCameraCard() {
    final v = _latestBox?.visionCheck;
    final isPass = v?.isPassed ?? true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: v != null && !isPass ? Colors.orange : Colors.white24,
          width: v != null && !isPass ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '2. VISION GRADING',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Icon(
                v != null && !isPass ? Icons.warning : Icons.camera_alt,
                color: v != null && !isPass ? Colors.orange : Colors.cyanAccent,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            v != null ? '${v.detectedGrade} (${v.capDiameterMm}mm)' : 'Cup (Awaiting scan)',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          ),
          Text(
            v != null ? 'Conf: ${(v.confidence * 100).toStringAsFixed(1)}%' : 'Target: Cup 45-65mm',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              side: const BorderSide(color: Colors.orangeAccent),
            ),
            onPressed: () => _infeedSingleBox(simulateVision: true),
            child: const Text('Simulate Defect', style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildStation3CheckWeigherCard() {
    final w = _latestBox?.weigherResult;
    final isPass = w?.isWithinTolerance ?? true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: w != null && !isPass ? Colors.purpleAccent : const Color(0xFF10B981),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3. CHECKWEIGHER',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Icon(Icons.scale, color: Colors.amber, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            w != null ? '${w.netWeightKg} kg' : '4.000 kg',
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            w != null ? '${w.variancePct >= 0 ? '+' : ''}${w.variancePct}%' : 'Tol: ±2.5%',
            style: TextStyle(
              color: isPass ? const Color(0xFF34D399) : Colors.purpleAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              side: const BorderSide(color: Colors.purpleAccent),
            ),
            onPressed: () => _infeedSingleBox(simulateWeight: true),
            child: const Text('Simulate Outlier', style: TextStyle(color: Colors.purpleAccent, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralPalletizerCard() {
    final count = _conveyorService.currentPalletBoxCount;
    final pct = (count / 72.0).clamp(0.0, 1.0);
    final netWeight = _conveyorService.currentAccumulatedBoxes.fold<double>(
      0.0,
      (sum, b) => sum + (b.weigherResult?.netWeightKg ?? 4.0),
    );
    final grossWeight = netWeight + (count > 0 ? 35.0 : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.cyanAccent, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'CENTRAL PALLETIZER STATION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PALLET: 1165x1165mm',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accumulated: $count / 72 Cartons (8 layers x 9 cartons)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('NET WEIGHT (TOTAL PRODUCT)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(
                    '${netWeight.toStringAsFixed(2)} kg',
                    style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('GROSS WEIGHT (+ 35kg TARE)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(
                    '${grossWeight.toStringAsFixed(2)} kg',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_box, size: 20),
                  label: const Text('+ 1 Carton Infeed'),
                  onPressed: _isProcessingBatch ? null : () => _infeedSingleBox(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isProcessingBatch
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.flash_on, size: 20),
                  label: Text(_isProcessingBatch ? 'Processing...' : 'Run 72-Carton Batch'),
                  onPressed: _isProcessingBatch ? null : _runFullPalletBatch,
                ),
              ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.qr_code),
                label: Text('Finalize & Mint LPN Now ($count cartons)'),
                onPressed: _finalizePallet,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAirlockGateSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _gateResult?.isDoorOpened == true ? const Color(0xFF10B981) : Colors.amber.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.door_sliding, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'AIRLOCK GATE & WEIGHBRIDGE SCALE TRIGGER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _gateResult?.isDoorOpened == true ? const Color(0xFF065F46) : Colors.red.shade900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _gateResult?.isDoorOpened == true ? 'DOOR: OPEN' : 'DOOR: LOCKED',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pallet selector
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  _selectedPalletForGate != null
                      ? 'Pallet: ${_selectedPalletForGate!.lpnCode} (${_selectedPalletForGate!.grossWeightKg} kg)'
                      : 'No pallet finalized yet.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _gateScaleInputController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'Weighbridge Gross (kg)',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.sensors, color: Colors.black),
              label: const Text(
                'VERIFY WEIGHBRIDGE & TRIGGER AUTO DOOR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _testAirlockDoorScale,
            ),
          ),

          if (_gateResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _gateResult!.isDoorOpened
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _gateResult!.isDoorOpened ? const Color(0xFF10B981) : Colors.red,
                ),
              ),
              child: Text(
                _gateResult!.isDoorOpened
                    ? 'GROSS WEIGHT VERIFIED (Variance: ${_gateResult!.differencePct.toStringAsFixed(2)}% <= 1.5%): Airlock gate opened. Forklift clear for intake to Cold Store.'
                    : 'WEIGHT DISCREPANCY DETECTED (Variance: ${_gateResult!.differencePct.toStringAsFixed(2)}% > 1.5%): Floor scale = ${_gateResult!.scaleMeasuredGrossKg.toStringAsFixed(1)} kg vs Infeed = ${_gateResult!.upstreamGrossKg.toStringAsFixed(1)} kg. Airlock gate locked; pallet inspection required.',
                style: TextStyle(
                  color: _gateResult!.isDoorOpened ? const Color(0xFF34D399) : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventLogSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'REAL-TIME CONVEYOR TELEMETRY LOG',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentEventLog.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No cartons processed on the conveyor yet.', style: TextStyle(color: Colors.white38)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentEventLog.length,
              separatorBuilder: (context, idx) => const Divider(color: Colors.white12),
              itemBuilder: (context, idx) {
                final b = _recentEventLog[idx];
                final isMetalReject = b.status == BoxStatus.divertedMetal;
                final isVisionReject = b.status == BoxStatus.divertedVision;
                final isWeightReject = b.status == BoxStatus.divertedWeight;
                final isPassed = !isMetalReject && !isVisionReject && !isWeightReject;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isPassed ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isPassed ? Icons.check_circle : Icons.cancel,
                        color: isPassed ? const Color(0xFF34D399) : Colors.redAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.boxId} - ${b.productName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Metal: ${b.metalCheck?.isPassed == true ? "PASS" : "REJECT"} | '
                            'Vision: ${b.visionCheck?.detectedGrade ?? "-"} | '
                            'Weight: ${b.weigherResult?.netWeightKg ?? "-"} kg',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        isPassed ? 'PALLETIZED' : 'DIVERTED',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: isPassed ? const Color(0xFF065F46) : Colors.red.shade900,
                      labelStyle: TextStyle(color: isPassed ? const Color(0xFF6EE7B7) : Colors.red.shade200),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
