import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/app_database.dart';
import '../models/qc_cycle_count_models.dart';
import '../services/qc_inspection_service.dart';

class QcInspectionScreen extends StatefulWidget {
  final String? initialLotId;

  const QcInspectionScreen({super.key, this.initialLotId});

  @override
  State<QcInspectionScreen> createState() => _QcInspectionScreenState();
}

class _QcInspectionScreenState extends State<QcInspectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QcInspectionService _qcService = QcInspectionService();

  List<Map<String, dynamic>> _quarantineLots = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Selected item for inspection
  Map<String, dynamic>? _selectedLotItem;

  // Form State
  double _productTemperature = 3.2; // °C default cold store temp
  String _surfaceMoisture = 'normal'; // dry, normal, excess
  String _discolorationGrade = 'clean_white'; // clean_white, minor_blemish, spotted, severe
  String _veilOpening = 'closed'; // closed, slightly_open, flat_open
  String _packagingIntegrity = 'intact'; // intact, dented, torn, contaminated
  final TextEditingController _inspectorIdController =
      TextEditingController(text: 'QC-INSPECTOR-08');
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuarantineLots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inspectorIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadQuarantineLots() async {
    setState(() => _isLoading = true);
    final list = await _qcService.getQuarantineLots();
    setState(() {
      _quarantineLots = list;
      _isLoading = false;
      if (widget.initialLotId != null) {
        final match = list.firstWhere(
          (item) => (item['lot'] as StockLot).id == widget.initialLotId,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          _selectLotForInspection(match);
        }
      }
    });
  }

  void _selectLotForInspection(Map<String, dynamic> item) {
    setState(() {
      _selectedLotItem = item;
      _productTemperature = 3.2;
      _surfaceMoisture = 'normal';
      _discolorationGrade = 'clean_white';
      _veilOpening = 'closed';
      _packagingIntegrity = 'intact';
      _notesController.clear();
      _tabController.animateTo(1);
    });
  }

  Future<void> _submitDecision(String targetStatus) async {
    if (_selectedLotItem == null) return;

    final lot = _selectedLotItem!['lot'] as StockLot;
    final prod = _selectedLotItem!['product'] as Product?;
    final pallet = _selectedLotItem!['pallet'] as StockLpn?;

    final inspection = QcInspectionResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lotId: lot.id,
      lotNumber: lot.lotNumber,
      productId: lot.productId,
      productName: prod?.name ?? 'Mushroom Product',
      lpnId: pallet?.id,
      lpnCode: pallet?.lpnCode,
      productTemperature: _productTemperature,
      surfaceMoisture: _surfaceMoisture,
      discolorationGrade: _discolorationGrade,
      veilOpening: _veilOpening,
      packagingIntegrity: _packagingIntegrity,
      status: targetStatus,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      inspectedBy: _inspectorIdController.text.trim().isEmpty
          ? 'QC-OPERATOR'
          : _inspectorIdController.text.trim(),
      inspectedAt: DateTime.now(),
      passed: targetStatus == 'approved',
    );

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await _qcService.submitInspection(inspection);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final isApproved = targetStatus == 'approved';
      final isBlocked = targetStatus == 'blocked';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            isApproved ? Icons.verified : (isBlocked ? Icons.block : Icons.pause_circle_filled),
            color: isApproved ? Colors.green : (isBlocked ? Colors.red : Colors.orange),
            size: 48,
          ),
          title: Text(
            isApproved
                ? 'QC APPROVED (PASSED)'
                : (isBlocked ? 'LOT BLOCKED & QUARANTINED' : 'PLACED ON QC HOLD'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lot Number: ${lot.lotNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (pallet != null) Text('Pallet LPN: ${pallet.lpnCode}'),
              Text('Core Temperature: ${_productTemperature.toStringAsFixed(1)}°C'),
              const SizedBox(height: 8),
              Text(
                isApproved
                    ? 'Stock lot has been approved and unlocked for automated FEFO Outbound Allocation.'
                    : (isBlocked
                        ? 'Stock lot has been blocked and quarantined to location WH1-QUARANTINE. Outbound FEFO is blocked.'
                        : 'Stock lot is held under quarantine status pending supplementary inspection.'),
                style: TextStyle(
                  fontSize: 13,
                  color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _selectedLotItem = null;
                _loadQuarantineLots();
                _tabController.animateTo(0);
              },
              child: const Text('Confirm & Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inspection submission error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QC Quality Gate & Inspection Quarantine'),
        backgroundColor: const Color(0xFF0F766E),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          tabs: [
            Tab(
              icon: const Icon(Icons.hourglass_top),
              text: 'Quarantine Queue (${_quarantineLots.length})',
            ),
            const Tab(
              icon: Icon(Icons.rule),
              text: 'Detailed Inspection Sheet',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: _loadQuarantineLots,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuarantineQueueTab(),
          _buildInspectionChecklistTab(),
        ],
      ),
    );
  }

  Widget _buildQuarantineQueueTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quarantineLots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 72, color: Colors.green.shade400),
            const SizedBox(height: 16),
            const Text(
              'No lots awaiting QC inspection!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'All inbound and harvested inventory lots have been released.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _quarantineLots.length,
      itemBuilder: (context, index) {
        final item = _quarantineLots[index];
        final lot = item['lot'] as StockLot;
        final prod = item['product'] as Product?;
        final pallet = item['pallet'] as StockLpn?;
        final qty = item['quantity'] as double;
        final uom = item['uom'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.amber.shade300, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 4),
                          Text(
                            lot.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'EXP: ${lot.expiryDate.toLocal().toString().substring(0, 10)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepOrange),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  prod?.name ?? 'Mushroom Product',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Lot No: ', style: TextStyle(color: Colors.grey.shade600)),
                    Text(lot.lotNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (pallet != null) ...[
                      Text('Pallet: ', style: TextStyle(color: Colors.grey.shade600)),
                      Text(pallet.lpnCode, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Quantity: ', style: TextStyle(color: Colors.grey.shade600)),
                    Text('${qty.toStringAsFixed(0)} $uom', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('Location: ', style: TextStyle(color: Colors.grey.shade600)),
                    Text(pallet?.locationId ?? 'M1-STAGING', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _selectLotForInspection(item),
                    icon: const Icon(Icons.assignment_turned_in),
                    label: const Text('START INSPECTION (INSPECT)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInspectionChecklistTab() {
    if (_selectedLotItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No inspection lot selected!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('View Quarantine Queue'),
            ),
          ],
        ),
      );
    }

    final lot = _selectedLotItem!['lot'] as StockLot;
    final prod = _selectedLotItem!['product'] as Product?;
    final pallet = _selectedLotItem!['pallet'] as StockLpn?;

    // Live evaluation
    final eval = QcInspectionService.evaluateCriteria(
      productTemperature: _productTemperature,
      surfaceMoisture: _surfaceMoisture,
      discolorationGrade: _discolorationGrade,
      veilOpening: _veilOpening,
      packagingIntegrity: _packagingIntegrity,
    );
    final bool isPass = eval['passed'] as bool;
    final issues = eval['issues'] as List<String>;

    // Color code for temperature
    Color tempColor = Colors.green;
    String tempLabel = 'Optimal Cold-Chain (2°C - 4°C)';
    if (_productTemperature > 4.5) {
      tempColor = Colors.red;
      tempLabel = 'Warning: Over-temperature! Risk of microbial growth & cap opening';
    } else if (_productTemperature < 0.5) {
      tempColor = Colors.blue;
      tempLabel = 'Warning: Freeze damage risk (< 0.5°C)';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner summary of selected lot
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2, size: 40, color: Color(0xFF0F766E)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prod?.name ?? 'Mushroom Product',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text('Lot: ${lot.lotNumber} | Pallet: ${pallet?.lpnCode ?? "N/A"}'),
                      Text('EXP: ${lot.expiryDate.toLocal().toString().substring(0, 10)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Core Temperature Slider & Indicator
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Product Core Temperature (Core Temp):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tempColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tempColor),
                        ),
                        child: Text(
                          '${_productTemperature.toStringAsFixed(1)} °C',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: tempColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tempLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tempColor),
                  ),
                  Slider(
                    value: _productTemperature,
                    min: -2.0,
                    max: 12.0,
                    divisions: 140,
                    label: '${_productTemperature.toStringAsFixed(1)}°C',
                    activeColor: tempColor,
                    onChanged: (val) {
                      setState(() => _productTemperature = val);
                    },
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-2°C (Freeze)', style: TextStyle(fontSize: 10, color: Colors.blue)),
                      Text('2°C - 4°C (Optimal Cold Standard)', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                      Text('12°C (Spoiled)', style: TextStyle(fontSize: 10, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Produce Quality Checklist
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2. Sensory & Packaging Criteria:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Divider(),

                  // Surface Moisture
                  _buildDropdownRow(
                    label: 'Surface Moisture:',
                    value: _surfaceMoisture,
                    items: const [
                      DropdownMenuItem(value: 'dry', child: Text('Dry (Optimal)')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal (Acceptable)')),
                      DropdownMenuItem(value: 'excess', child: Text('Excess Moisture (Reject / Fail)')),
                    ],
                    onChanged: (v) => setState(() => _surfaceMoisture = v!),
                  ),
                  const SizedBox(height: 10),

                  // Discoloration Grade
                  _buildDropdownRow(
                    label: 'Discoloration & Blemishes:',
                    value: _discolorationGrade,
                    items: const [
                      DropdownMenuItem(value: 'clean_white', child: Text('Clean White (Grade 1 Premium)')),
                      DropdownMenuItem(value: 'minor_blemish', child: Text('Minor Blemish (Grade 2 Acceptable)')),
                      DropdownMenuItem(value: 'spotted', child: Text('Spotted / Brown Pits (Reject)')),
                      DropdownMenuItem(value: 'severe', child: Text('Severe Discoloration (Reject)')),
                    ],
                    onChanged: (v) => setState(() => _discolorationGrade = v!),
                  ),
                  const SizedBox(height: 10),

                  // Veil Opening
                  _buildDropdownRow(
                    label: 'Cap Veil Opening:',
                    value: _veilOpening,
                    items: const [
                      DropdownMenuItem(value: 'closed', child: Text('Closed Cup (Optimal Tight Veil)')),
                      DropdownMenuItem(value: 'slightly_open', child: Text('Slightly Open (Acceptable)')),
                      DropdownMenuItem(value: 'flat_open', child: Text('Flat Open (Over-mature / Reject)')),
                    ],
                    onChanged: (v) => setState(() => _veilOpening = v!),
                  ),
                  const SizedBox(height: 10),

                  // Packaging Integrity
                  _buildDropdownRow(
                    label: 'Packaging Integrity:',
                    value: _packagingIntegrity,
                    items: const [
                      DropdownMenuItem(value: 'intact', child: Text('Intact & Clean Label (Compliant)')),
                      DropdownMenuItem(value: 'dented', child: Text('Dented Corner (Minor Defect)')),
                      DropdownMenuItem(value: 'torn', child: Text('Torn Carton / Open Lid (Reject)')),
                      DropdownMenuItem(value: 'contaminated', child: Text('Contaminated / Stained (Reject)')),
                    ],
                    onChanged: (v) => setState(() => _packagingIntegrity = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Inspector Info & Notes
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('3. Inspector Information & Audit Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inspectorIdController,
                    decoration: const InputDecoration(
                      labelText: 'QC Inspector Badge ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Supplementary Inspection Notes',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Evaluation Recommendation Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPass ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isPass ? Colors.green : Colors.red, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isPass ? Icons.check_circle : Icons.warning, color: isPass ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      isPass ? 'RECOMMENDED DECISION: PASS (APPROVED)' : 'RECOMMENDED DECISION: FAIL (NON-COMPLIANT)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isPass ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
                if (issues.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...issues.map((iss) => Padding(
                        padding: const EdgeInsets.only(left: 28, top: 2),
                        child: Text('• $iss', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          if (_isSubmitting)
            const Center(child: CircularProgressIndicator())
          else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _submitDecision('approved'),
                icon: const Icon(Icons.verified),
                label: const Text(
                  '🟢 PASS & APPROVE FOR OUTBOUND',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitDecision('blocked'),
                    icon: const Icon(Icons.block, color: Colors.red),
                    label: const Text('🔴 REJECT & BLOCK LOT', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitDecision('hold'),
                    icon: const Icon(Icons.pause, color: Colors.orange),
                    label: const Text('🟡 HOLD FOR RE-INSPECTION', style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
