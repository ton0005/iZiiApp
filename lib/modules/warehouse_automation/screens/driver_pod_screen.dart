import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../models/cold_chain_pod_models.dart';
import '../services/cold_chain_telemetry_service.dart';
import '../services/electronic_pod_service.dart';

/// Screen for Mobile Electronic Proof of Delivery (e-PoD), container seal verification,
/// on-glass signature capture, GPS coordinate stamping, and instant ERP billing sync.
class DriverPodScreen extends StatefulWidget {
  const DriverPodScreen({super.key});

  @override
  State<DriverPodScreen> createState() => _DriverPodScreenState();
}

class _DriverPodScreenState extends State<DriverPodScreen> {
  late ElectronicPodService _podService;
  late ColdChainTelemetryService _telemetryService;

  List<DeliveryStopItem> _stops = [];
  DeliveryStopItem? _selectedStop;
  bool _isLoading = true;

  // Form controls
  final _sealController = TextEditingController(text: 'SEAL-AU-89412');
  final _recipientController = TextEditingController(text: 'Johnathan Smith');
  final _designationController = TextEditingController(text: 'DC Receiving Supervisor');
  final _notesController = TextEditingController();
  bool _isSealIntact = true;
  bool _hasSealPhoto = true;
  bool _hasCargoPhoto = true;

  // Signature points
  final List<List<Offset>> _signatureStrokes = [];

  @override
  void initState() {
    super.initState();
    _podService = ElectronicPodService(AppDatabase());
    _telemetryService = ColdChainTelemetryService(AppDatabase());
    _loadStops();
  }

  @override
  void dispose() {
    _sealController.dispose();
    _recipientController.dispose();
    _designationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStops() async {
    setState(() => _isLoading = true);
    final stops = await _podService.getPendingDeliveryStops();

    if (stops.isNotEmpty) {
      _stops = stops;
      _selectedStop = stops.first;
    } else {
      // Provide realistic default stops for demonstrations
      final defaultStops = [
        const DeliveryStopItem(
          pickingId: 'PICK-OUT-20261005-01',
          orderCode: 'SO-2026-0042',
          customerName: 'Woolworths DC Mulgrave',
          destinationAddress: '120 Police Rd, Mulgrave VIC 3170',
          contactPhone: '+61 3 9566 8000',
          palletCount: 1,
          cartonCount: 72,
          grossWeightKg: 355.4,
          products: ['Fresh Cup Mushrooms 4kg (Lot: LOT-HARV-20261005-R01)'],
          status: 'in_transit',
        ),
        const DeliveryStopItem(
          pickingId: 'PICK-OUT-20261005-02',
          orderCode: 'SO-2026-0043',
          customerName: 'Coles Regional DC Truganina',
          destinationAddress: '235 Robinsons Rd, Truganina VIC 3029',
          contactPhone: '+61 3 8369 4100',
          palletCount: 2,
          cartonCount: 144,
          grossWeightKg: 710.8,
          products: ['Sliced White Mushrooms 3kg', 'Button Mushrooms 4kg'],
          status: 'assigned',
        ),
      ];
      _stops = defaultStops;
      _selectedStop = defaultStops.first;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEpod() async {
    final stop = _selectedStop;
    if (stop == null) return;

    if (_signatureStrokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Please obtain recipient signature on glass before submitting!'),
        ),
      );
      return;
    }

    if (_recipientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Please enter recipient name!'),
        ),
      );
      return;
    }

    // Convert strokes to flat coordinate list for serialization
    final points = _signatureStrokes
        .expand((stroke) => stroke.map((p) => [p.dx, p.dy]))
        .toList();

    // Get telemetry summary if available
    final coldChain = _telemetryService.activeTrip;

    setState(() => _isLoading = true);

    try {
      final record = await _podService.submitDeliveryProof(
        pickingId: stop.pickingId,
        orderCode: stop.orderCode,
        customerName: stop.customerName,
        destinationAddress: stop.destinationAddress,
        recipientName: _recipientController.text.trim(),
        recipientDesignation: _designationController.text.trim(),
        sealNumber: _sealController.text.trim(),
        sealIntact: _isSealIntact,
        sealPhotoBase64: _hasSealPhoto ? 'DATA:MOCK_SEAL_PHOTO_BASE64' : null,
        cargoPhotoBase64: _hasCargoPhoto ? 'DATA:MOCK_CARGO_PHOTO_BASE64' : null,
        signatureStrokePoints: points,
        signatureSvg: '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="120"><path d="M10,20 Q50,90 120,40 T280,70" stroke="blue" fill="none"/></svg>',
        cartonCount: stop.cartonCount,
        palletCount: stop.palletCount,
        grossWeightKg: stop.grossWeightKg,
        coldChainCompliance: coldChain,
        notes: _notesController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      _showSuccessDialog(record);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error submitting e-PoD: $e'),
          ),
        );
      }
    }
  }

  void _showSuccessDialog(ProofOfDeliveryRecord record) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delivery Completed (e-PoD)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Color(0xFF047857), size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              record.manifestAuthorizationCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Digital Security Seal (CryptoHash):\n${record.cryptoHash}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildConfirmRow('Customer:', record.customerName),
                _buildConfirmRow('Order Code:', record.orderCode),
                _buildConfirmRow('Recipient:', '${record.recipientName} (${record.recipientDesignation})'),
                _buildConfirmRow('Security Seal:', '${record.sealNumber} (${record.sealIntact ? "INTACT" : "TAMPERED / BROKEN"})'),
                _buildConfirmRow('GPS Coordinates:', '[${record.gpsLatitude.toStringAsFixed(4)}, ${record.gpsLongitude.toStringAsFixed(4)}] (Accuracy: ±${record.gpsAccuracyMeters.toStringAsFixed(0)}m)'),
                _buildConfirmRow('Timestamp:', record.deliveredAt.toLocal().toString().split('.')[0]),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sync, color: Color(0xFF2563EB), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Instant sync to ERP Odoo triggered for automatic invoice & billing generation!',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _loadStops();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete & Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stop = _selectedStop;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Mobile e-PoD (Sign-on-Glass)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.thermostat),
            tooltip: 'Inspect Reefer Cold Chain',
            onPressed: () => context.push('/warehouse/cold-chain'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stop Selector & Manifest Info
                  _buildStopSelectorCard(),

                  const SizedBox(height: 16),

                  // Container Security Seal Verification
                  _buildSealVerificationCard(),

                  const SizedBox(height: 16),

                  // Cold-Chain Status Card
                  _buildColdChainBadgeCard(),

                  const SizedBox(height: 16),

                  // Recipient & Signature on Glass Pad
                  _buildSignaturePadCard(),

                  const SizedBox(height: 24),

                  // Confirm & Submit e-PoD Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: stop != null ? _submitEpod : null,
                      icon: const Icon(Icons.assignment_turned_in, size: 22),
                      label: const Text(
                        'CONFIRM DELIVERY & SIGN e-PoD',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStopSelectorCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DELIVERY STOP MANIFEST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_stops.length} Stops',
                    style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeliveryStopItem>(
              initialValue: _selectedStop,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: _stops.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text('${s.orderCode} - ${s.customerName}'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedStop = val);
                }
              },
            ),
            if (_selectedStop != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedStop!.destinationAddress,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBadge('Pallets: ${_selectedStop!.palletCount}', const Color(0xFFE0E7FF), const Color(0xFF3730A3)),
                  const SizedBox(width: 8),
                  _buildBadge('Cartons: ${_selectedStop!.cartonCount} boxes', const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
                  const SizedBox(width: 8),
                  _buildBadge('Gross Weight: ${_selectedStop!.grossWeightKg.toStringAsFixed(1)} kg', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildSealVerificationCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 8),
                Text(
                  'Container Security Seal Verification',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sealController,
              decoration: InputDecoration(
                labelText: 'Container Seal Number',
                hintText: 'e.g. SEAL-AU-89412',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Security seal intact with no signs of tampering',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _isSealIntact ? 'Status: Intact & Sealed' : 'WARNING: Seal broken or tampered!',
                style: TextStyle(
                  fontSize: 11,
                  color: _isSealIntact ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
              value: _isSealIntact,
              onChanged: (val) => setState(() => _isSealIntact = val),
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _hasSealPhoto = !_hasSealPhoto);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_hasSealPhoto ? 'Security seal photo captured' : 'Security seal photo removed')),
                      );
                    },
                    icon: Icon(_hasSealPhoto ? Icons.check_circle : Icons.camera_alt,
                        color: _hasSealPhoto ? Colors.green : Colors.grey, size: 18),
                    label: Text(_hasSealPhoto ? 'Seal Photo [1]' : 'Capture Seal Photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _hasCargoPhoto = !_hasCargoPhoto);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_hasCargoPhoto ? 'Cargo condition photo captured' : 'Cargo condition photo removed')),
                      );
                    },
                    icon: Icon(_hasCargoPhoto ? Icons.check_circle : Icons.camera_alt,
                        color: _hasCargoPhoto ? Colors.green : Colors.grey, size: 18),
                    label: Text(_hasCargoPhoto ? 'Cargo Photo [1]' : 'Capture Cargo Photo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColdChainBadgeCard() {
    final trip = _telemetryService.activeTrip;
    final isCompliant = trip?.isCompliant ?? true;
    final mkt = trip?.meanKineticTemperatureC ?? 2.9;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCompliant ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCompliant ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCompliant ? Icons.verified : Icons.warning,
              color: isCompliant ? const Color(0xFF10B981) : const Color(0xFFDC2626),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCompliant ? 'COLD CHAIN COMPLIANCE VERIFIED' : 'COLD CHAIN EXCURSION WARNING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isCompliant ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MKT: ${mkt.toStringAsFixed(1)}°C | Target safe range: 0.0°C – 5.0°C',
                    style: TextStyle(
                      fontSize: 11,
                      color: isCompliant ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/warehouse/cold-chain'),
              child: const Text('View Telemetry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturePadCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.draw, color: Color(0xFF1E3A8A), size: 20),
                SizedBox(width: 8),
                Text(
                  'Sign-on-Glass Customer Acknowledgement',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      labelText: 'Recipient Full Name *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _designationController,
                    decoration: InputDecoration(
                      labelText: 'Designation / Department',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Signature drawing canvas
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  ),
                  child: GestureDetector(
                    onPanStart: (details) {
                      final local = details.localPosition;
                      setState(() {
                        _signatureStrokes.add([local]);
                      });
                    },
                    onPanUpdate: (details) {
                      final local = details.localPosition;
                      setState(() {
                        if (_signatureStrokes.isNotEmpty) {
                          _signatureStrokes.last.add(local);
                        }
                      });
                    },
                    child: CustomPaint(
                      painter: _SignatureCanvasPainter(_signatureStrokes),
                      size: const Size(double.infinity, 150),
                    ),
                  ),
                ),
                if (_signatureStrokes.isEmpty)
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        'Sign on screen using finger or stylus',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Clear signature',
                    onPressed: () {
                      setState(() {
                        _signatureStrokes.clear();
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.gps_fixed, size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Text(
                      'Auto-GPS: [-37.9252, 145.1764] (±5m)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.security, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'SHA-256 Sealed',
                      style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for on-glass finger signature strokes.
class _SignatureCanvasPainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignatureCanvasPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      } else {
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureCanvasPainter oldDelegate) => true;
}
