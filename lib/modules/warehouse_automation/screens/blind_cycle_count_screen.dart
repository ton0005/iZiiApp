import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/qc_cycle_count_models.dart';
import '../services/cycle_count_service.dart';

class BlindCycleCountScreen extends StatefulWidget {
  const BlindCycleCountScreen({super.key});

  @override
  State<BlindCycleCountScreen> createState() => _BlindCycleCountScreenState();
}

class _BlindCycleCountScreenState extends State<BlindCycleCountScreen> {
  final CycleCountService _countService = CycleCountService();

  // Step 1 Controllers
  final TextEditingController _locationController =
      TextEditingController(text: 'WH1-COLD-A01-L1');
  final TextEditingController _counterIdController =
      TextEditingController(text: 'TECH-FORKLIFT-01');

  // Step 2 Controllers (Blind Counting)
  final TextEditingController _scanBarcodeController = TextEditingController();
  final TextEditingController _physicalQtyController = TextEditingController(text: '72');

  // Step 3 Controllers (Supervisor Reconciliation)
  final TextEditingController _supervisorIdController =
      TextEditingController(text: 'MGR-SUPERVISOR-01');
  final TextEditingController _supervisorPinController =
      TextEditingController(text: '8888');

  CycleCountSession? _currentSession;
  bool _isLoading = false;
  String _activeTab = 'setup'; // 'setup', 'counting', 'review'

  @override
  void dispose() {
    _locationController.dispose();
    _counterIdController.dispose();
    _scanBarcodeController.dispose();
    _physicalQtyController.dispose();
    _supervisorIdController.dispose();
    _supervisorPinController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final loc = _locationController.text.trim();
    final counter = _counterIdController.text.trim();

    if (loc.isEmpty || counter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter location code and operator ID.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final session = await _countService.startBlindSession(
        locationCode: loc,
        countedBy: counter,
      );

      setState(() {
        _currentSession = session;
        _activeTab = 'counting';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize count session: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _recordCountedItem() async {
    if (_currentSession == null) return;

    final barcode = _scanBarcodeController.text.trim();
    final qty = double.tryParse(_physicalQtyController.text.trim());

    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter Pallet LPN / product barcode.')),
      );
      return;
    }

    if (qty == null || qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid physical count quantity.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final updated = await _countService.recordBlindCountItem(
        sessionId: _currentSession!.id,
        barcodeOrLpn: barcode,
        physicalQty: qty,
      );

      setState(() {
        _currentSession = updated;
        _scanBarcodeController.clear();
        _physicalQtyController.text = '72';
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Count recorded: $barcode -> ${qty.toStringAsFixed(0)} units'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record count: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _completeCountingStage() {
    if (_currentSession == null) return;

    final completed = _countService.completeCountStage(_currentSession!.id);
    setState(() {
      _currentSession = completed;
      _activeTab = 'review';
    });
  }

  Future<void> _reconcileWithSupervisor() async {
    if (_currentSession == null) return;

    final supId = _supervisorIdController.text.trim();
    final pin = _supervisorPinController.text.trim();

    if (supId.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Supervisor ID and authorization PIN.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      final reconciled = await _countService.reconcileDiscrepancies(
        sessionId: _currentSession!.id,
        supervisorId: supId,
        supervisorPin: pin,
      );

      setState(() {
        _currentSession = reconciled;
        _isLoading = false;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
          title: const Text('INVENTORY RECONCILIATION SUCCESSFUL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Count Session: ${reconciled.sessionNumber}'),
              Text('Location: ${reconciled.locationName}'),
              Text('Authorizing Supervisor: $supId'),
              const Divider(),
              Text('Total Line Items: ${reconciled.totalLines}'),
              Text('Matched Lines: ${reconciled.matchedLines}'),
              Text('Adjusted Discrepancies: ${reconciled.discrepancyLines}'),
              Text('Net Variance: ${reconciled.netVarianceQty >= 0 ? "+" : ""}${reconciled.netVarianceQty.toStringAsFixed(1)} units'),
              const SizedBox(height: 8),
              const Text(
                'System updated StockQuants and queued compensating StockMoves to Outbox Sync.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _currentSession = null;
                  _activeTab = 'setup';
                });
              },
              child: const Text('Close & New Session'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reconciliation error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perpetual Blind Cycle Count & Inventory Reconciliation'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          if (_currentSession != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _currentSession!.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeTab == 'setup') {
      return _buildSetupView();
    } else if (_activeTab == 'counting') {
      return _buildBlindCountingView();
    } else {
      return _buildReviewAndReconcileView();
    }
  }

  // ── 1. SETUP VIEW ─────────────────────────────────────────────────────────
  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_off_outlined, size: 36, color: Colors.blue.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blind Cycle Count Principle',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'System book quantities are completely hidden from the operator to ensure objective counting and prevent shrinkage concealment.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Location & Operator Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location / Aisle / Bin Code',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _counterIdController,
                    decoration: const InputDecoration(
                      labelText: 'Count Operator ID',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _startSession,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'START BLIND CYCLE COUNT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. BLIND COUNTING VIEW ────────────────────────────────────────────────
  Widget _buildBlindCountingView() {
    final session = _currentSession!;

    return Column(
      children: [
        // Privacy banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Colors.amber.shade100,
          child: Row(
            children: [
              Icon(Icons.lock, size: 20, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🔒 BLIND COUNT MODE: System book quantities are completely hidden.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),

        // Session info banner
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.sessionNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Location: ${session.locationName}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _completeCountingStage,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Complete Count Stage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Input entry card
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _scanBarcodeController,
                    decoration: InputDecoration(
                      labelText: 'Scan Barcode / Pallet LPN / Case ID',
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _scanBarcodeController.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _physicalQtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Physical Count Quantity (Boxes/Units)',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _recordCountedItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Record Count'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Counted Items List (Blind view: shows counted qty, but masks system qty)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: session.lines.length,
            itemBuilder: (context, index) {
              final line = session.lines[index];
              final hasCounted = line.countedQty > 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasCounted ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Icon(
                      hasCounted ? Icons.check : Icons.hourglass_empty,
                      color: hasCounted ? Colors.green.shade800 : Colors.grey,
                    ),
                  ),
                  title: Text(
                    line.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'LPN: ${line.lpnCode ?? "N/A"} | Lot: ${line.lotNumber ?? "N/A"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasCounted ? '${line.countedQty.toStringAsFixed(0)} ${line.uom}' : 'Pending Count',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: hasCounted ? Colors.green.shade800 : Colors.grey,
                        ),
                      ),
                      const Text(
                        'Book Qty: [CONFIDENTIAL]',
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 3. REVIEW & RECONCILE VIEW ────────────────────────────────────────────
  Widget _buildReviewAndReconcileView() {
    final session = _currentSession!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Row
          Row(
            children: [
              _buildMetricCard(
                title: 'Total Lines',
                value: session.totalLines.toString(),
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                title: 'Matched',
                value: session.matchedLines.toString(),
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                title: 'Discrepancy',
                value: session.discrepancyLines.toString(),
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                title: 'Net Variance',
                value: '${session.netVarianceQty >= 0 ? "+" : ""}${session.netVarianceQty.toStringAsFixed(0)}',
                color: session.netVarianceQty == 0 ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Discrepancy Table
          const Text(
            'Book vs. Physical Variance Analysis',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),

          ...session.lines.map((line) {
            final isMatch = line.varianceQty == 0;
            final isLoss = line.varianceQty < 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isMatch ? Colors.green.shade200 : (isLoss ? Colors.red.shade300 : Colors.orange.shade300),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            line.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMatch
                                ? Colors.green.shade100
                                : (isLoss ? Colors.red.shade100 : Colors.orange.shade100),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isMatch
                                ? 'MATCH (0)'
                                : '${line.varianceQty > 0 ? "+" : ""}${line.varianceQty.toStringAsFixed(0)} ${line.uom}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isMatch
                                  ? Colors.green.shade900
                                  : (isLoss ? Colors.red.shade900 : Colors.orange.shade900),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LPN: ${line.lpnCode ?? "N/A"} | Lot: ${line.lotNumber ?? "N/A"}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Book: ${line.systemQty.toStringAsFixed(0)} ${line.uom}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 20),
                        Text('Physical: ${line.countedQty.toStringAsFixed(0)} ${line.uom}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isMatch ? Colors.green.shade800 : Colors.blue.shade900,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Supervisor Authorization Panel
          Card(
            color: Colors.blueGrey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Color(0xFF1E293B)),
                      SizedBox(width: 8),
                      Text(
                        'Supervisor Reconciliation Authorization',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supervisorIdController,
                    decoration: const InputDecoration(
                      labelText: 'Warehouse Supervisor ID',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supervisorPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor Security PIN',
                      prefixIcon: Icon(Icons.password),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _reconcileWithSupervisor,
                      icon: const Icon(Icons.sync_alt),
                      label: const Text(
                        'AUTHORIZE & RECONCILE INVENTORY',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: color.shade900)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
