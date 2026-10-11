import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wave_audit_models.dart';
import '../services/packout_weight_audit_service.dart';

class PackoutScaleAuditScreen extends StatefulWidget {
  final String? initialLpnCode;

  const PackoutScaleAuditScreen({super.key, this.initialLpnCode});

  @override
  State<PackoutScaleAuditScreen> createState() => _PackoutScaleAuditScreenState();
}

class _PackoutScaleAuditScreenState extends State<PackoutScaleAuditScreen> {
  final PackoutWeightAuditService _auditService = PackoutWeightAuditService();

  final TextEditingController _lpnScanController =
      TextEditingController(text: 'LPN-2026-M1-001248');
  final TextEditingController _scaleWeightController =
      TextEditingController(text: '355.4');
  final TextEditingController _auditorIdController =
      TextEditingController(text: 'AUDITOR-DOCK-01');

  PackoutWeightAuditResult? _auditResult;
  Map<String, dynamic>? _bomPreview;
  bool _isAuditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLpnCode != null) {
      _lpnScanController.text = widget.initialLpnCode!;
    }
    _fetchBomPreview();
  }

  @override
  void dispose() {
    _lpnScanController.dispose();
    _scaleWeightController.dispose();
    _auditorIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchBomPreview() async {
    final lpn = _lpnScanController.text.trim();
    if (lpn.isEmpty) return;

    try {
      final bom = await _auditService.calculateTheoreticalBom(lpn);
      setState(() {
        _bomPreview = bom;
        // Pre-fill scale reading with theoretical weight for convenience
        _scaleWeightController.text = (bom['theoreticalGrossKg'] as double).toStringAsFixed(1);
      });
    } catch (_) {
      setState(() {
        _bomPreview = null;
      });
    }
  }

  Future<void> _runWeightAudit() async {
    final lpn = _lpnScanController.text.trim();
    final weight = double.tryParse(_scaleWeightController.text.trim());
    final auditor = _auditorIdController.text.trim();

    if (lpn.isEmpty || weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Pallet LPN and actual gross weight.')),
      );
      return;
    }

    setState(() => _isAuditing = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _auditService.auditPalletWeight(
        lpnCode: lpn,
        actualGrossKg: weight,
        auditedBy: auditor.isEmpty ? 'AUDITOR-DOCK' : auditor,
      );

      setState(() {
        _auditResult = result;
        _isAuditing = false;
      });

      if (!mounted) return;
      if (result.isPassed) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🟢 GROSS WEIGHT VERIFIED (Variance: ${result.variancePercentage.toStringAsFixed(2)}% <= ±1.5%)'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } else {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔴 GROSS WEIGHT ANOMALY ALARM! Variance ${result.variancePercentage.toStringAsFixed(2)}% exceeds tolerance!'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isAuditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weight audit error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _simulateScaleValue(double weight) {
    setState(() {
      _scaleWeightController.text = weight.toStringAsFixed(1);
    });
    _runWeightAudit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packout Gross-Weight Verification Station & Tolerance Audit'),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBomPreview,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Industrial Station Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.scale, size: 40, color: Colors.cyanAccent),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OUTBOUND DOCK BOM GROSS-WEIGHT AUDIT STATION',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Allowable tolerance: ±1.5%. Exceeding variance threshold triggers audible alarm and interlocks dispatch dock door.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Pallet LPN Input
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Scan Pallet LPN at Outbound Dock:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lpnScanController,
                            decoration: const InputDecoration(
                              labelText: 'Pallet LPN Barcode',
                              prefixIcon: Icon(Icons.qr_code_2),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _fetchBomPreview(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _fetchBomPreview,
                          icon: const Icon(Icons.search),
                          label: const Text('Lookup BOM'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Digital Floor Scale Terminal Card
            Card(
              elevation: 3,
              color: const Color(0xFF020617),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.monitor_weight, color: Colors.greenAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'DIGITAL FLOOR SCALE TERMINAL (DOCK SCALE)',
                              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('STABLE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Big Scale Reading Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.shade700, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _scaleWeightController.text.isEmpty ? '0.0' : _scaleWeightController.text,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            'GROSS WEIGHT (KG)',
                            style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Weight Input and Quick Simulation Buttons
                    TextField(
                      controller: _scaleWeightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Scale Reading / Actual Gross Weight (kg)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Simulation Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: () => _simulateScaleValue(355.4),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.greenAccent, side: const BorderSide(color: Colors.greenAccent)),
                          child: const Text('Simulate: Nominal BOM (355.4 kg)'),
                        ),
                        OutlinedButton(
                          onPressed: () => _simulateScaleValue(366.0),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                          child: const Text('Simulate: Overweight +3% (366.0 kg)'),
                        ),
                        OutlinedButton(
                          onPressed: () => _simulateScaleValue(340.0),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent)),
                          child: const Text('Simulate: Underweight -4.3% (340.0 kg)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Theoretical BOM Breakdown Card
            if (_bomPreview != null) ...[
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
                          const Text('3. Theoretical BOM Weight Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${(_bomPreview!['theoreticalGrossKg'] as double).toStringAsFixed(1)} kg',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildBomRow('Product SKU', _bomPreview!['productName'] as String),
                      _buildBomRow('Carton Count', '${(_bomPreview!['cartonCount'] as double).toStringAsFixed(0)} boxes'),
                      _buildBomRow('Product Net Weight', '${(_bomPreview!['productNetKg'] as double).toStringAsFixed(1)} kg'),
                      _buildBomRow('Carton Tare Weight', '${(_bomPreview!['totalBoxTareKg'] as double).toStringAsFixed(1)} kg (${(_bomPreview!['cartonTareKg'] as double).toStringAsFixed(2)} kg/box)'),
                      _buildBomRow('AS 4068 Wooden Pallet Tare', '${(_bomPreview!['palletTareKg'] as double).toStringAsFixed(1)} kg'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. Audit Button
            if (_isAuditing)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _runWeightAudit,
                  icon: const Icon(Icons.rule),
                  label: const Text(
                    'VERIFY GROSS WEIGHT & TOLERANCE AUDIT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 5. Audit Result Banner
            if (_auditResult != null) _buildAuditResultBanner(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditResultBanner() {
    final res = _auditResult!;
    final isPassed = res.isPassed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPassed ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPassed ? Colors.green : Colors.red, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPassed ? Icons.verified : Icons.warning_amber_rounded,
                color: isPassed ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPassed ? 'GROSS WEIGHT VERIFIED (AUDIT PASSED)' : 'WEIGHT DISCREPANCY DETECTED (ANOMALY ALARM)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isPassed ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                    Text(
                      'Variance: ${res.variancePercentage >= 0 ? "+" : ""}${res.variancePercentage.toStringAsFixed(2)}% '
                      '(${res.varianceKg >= 0 ? "+" : ""}${res.varianceKg.toStringAsFixed(1)} kg) '
                      '[Tolerance: ±${res.maxAllowedVariancePercentage}%]',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPassed ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPassed) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONTAINER LOADING DISPATCH PERMIT (MANIFEST PERMIT):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    res.manifestAuthorizationCode ?? 'N/A',
                    style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      icon: const Icon(Icons.print, size: 48, color: Colors.green),
                      title: const Text('CONTAINER DISPATCH MANIFEST ISSUED'),
                      content: Text('Pallet ${res.lpnCode} authorized for container loading. Status: STAGED_FOR_DISPATCH.'),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Complete'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.local_shipping),
                label: const Text('AUTHORIZE DISPATCH & PRINT MANIFEST'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              ),
            ),
          ] else ...[
            Text(
              res.anomalyMessage ?? 'Weight variance exceeds allowable tolerance threshold.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DISPATCH DOCK INTERLOCKED. Manual physical recount required before dispatch authorization.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBomRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
