import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../repository.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class ContinuousScannerScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> localRooms;
  final String activePlant;
  final Function(String, String) onCheckIn;
  final Function(String, String) onCheckOut;
  final bool isDark;

  const ContinuousScannerScreen({
    super.key,
    required this.localRooms,
    required this.activePlant,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.isDark,
  });

  @override
  State<ContinuousScannerScreen> createState() => _ContinuousScannerScreenState();
}

class _ContinuousScannerScreenState extends State<ContinuousScannerScreen>
    with SingleTickerProviderStateMixin {
  late String _roomSelected;
  late String _plantSelected;
  String _scanAction = 'checkin'; // 'checkin' or 'checkout'
  List<Map<String, dynamic>> _employees = [];
  final List<String> _scannedHistory = [];
  bool _isLoading = true;
  final TextEditingController _manualIdController = TextEditingController();

  // Mobile Scanner Controllers
  final MobileScannerController _controller = MobileScannerController(
    cameraResolution: const Size(1280, 720),
  );
  late AnimationController _animationController;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _plantSelected = widget.activePlant;
    _roomSelected = widget.localRooms.keys.firstWhere(
        (k) => widget.localRooms[k]!['plant'] == _plantSelected,
        orElse: () => widget.localRooms.keys.first);
    _loadEmployees();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _onPlantChanged(String plant) {
    setState(() {
      _plantSelected = plant;
      _roomSelected = widget.localRooms.keys.firstWhere(
          (k) => widget.localRooms[k]!['plant'] == plant,
          orElse: () => widget.localRooms.keys.first);
    });
  }

  @override
  void dispose() {
    _manualIdController.dispose();
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final repo = MushroomsRepository();
    final emps = await repo.getEmployees();
    setState(() {
      _employees = emps;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _findEmployee(String code) {
    for (final e in _employees) {
      if (e['id']?.toString().toUpperCase() == code.toUpperCase()) {
        return e;
      }
    }
    return <String, dynamic>{};
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    // Pause scanner temporarily
    await _controller.stop();

    if (!mounted) return;
    _processScannedCode(code);
  }

  void _processScannedCode(String code) {
    final emp = _findEmployee(code);
    if (emp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Employee ID not found!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      _resumeScanner();
      return;
    }

    final dept = emp['department']?.toString().toLowerCase() ?? '';
    if (!dept.contains('harvest')) {
      final actString = _scanAction == 'checkin' ? 'check-in to' : 'check-out of';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Only Harvest department employees can $actString Harvest rooms.'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
      _resumeScanner();
      return;
    }

    final name = emp['name'] as String;
    if (_scanAction == 'checkin') {
      widget.onCheckIn(code, _roomSelected);
      setState(() {
        _scannedHistory.insert(0, 'Checked In: $name ($code)');
      });
    } else {
      widget.onCheckOut(code, _roomSelected);
      setState(() {
        _scannedHistory.insert(0, 'Checked Out: $name ($code)');
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully processed scan for: $name ($code)'),
        duration: const Duration(milliseconds: 800),
      ),
    );
    _resumeScanner();
  }

  void _resumeScanner() async {
    setState(() {
      _isProcessing = false;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final harvestEmployees = _employees
        .where((e) => e['department']?.toString().toLowerCase().contains('harvest') ?? false)
        .toList();

    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Continuous Harvest Scanner'),
        backgroundColor: FarmColors.forestGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Controls Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: Border.all(color: FarmColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Plant Selection (M1 vs M2)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Target Plant:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Plant M1'),
                                  selected: _plantSelected == 'M1',
                                  onSelected: (val) {
                                    if (val) _onPlantChanged('M1');
                                  },
                                  selectedColor: FarmColors.forestGreen.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _plantSelected == 'M1' ? FarmColors.forestGreenText : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ChoiceChip(
                                  label: const Text('Plant M2'),
                                  selected: _plantSelected == 'M2',
                                  onSelected: (val) {
                                    if (val) _onPlantChanged('M2');
                                  },
                                  selectedColor: FarmColors.forestGreen.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _plantSelected == 'M2' ? FarmColors.forestGreenText : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Room Selection Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Target Grow Room',
                            border: OutlineInputBorder(),
                          ),
                          value: _roomSelected,
                          items: widget.localRooms.keys
                              .where((k) => widget.localRooms[k]!['plant'] == _plantSelected)
                              .map((r) => DropdownMenuItem(
                                  value: r, child: Text(r.replaceAll('Room', 'Grow Room'))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _roomSelected = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Action Selection (Check In vs Check Out)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Scan Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Check In'),
                                  selected: _scanAction == 'checkin',
                                  onSelected: (val) {
                                    if (val) setState(() => _scanAction = 'checkin');
                                  },
                                  selectedColor: FarmColors.forestGreen.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _scanAction == 'checkin' ? FarmColors.forestGreenText : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ChoiceChip(
                                  label: const Text('Check Out'),
                                  selected: _scanAction == 'checkout',
                                  onSelected: (val) {
                                    if (val) setState(() => _scanAction = 'checkout');
                                  },
                                  selectedColor: Colors.red.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _scanAction == 'checkout' ? Colors.red.shade800 : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _manualIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Manual ID Scan/Type',
                                  hintText: 'e.g. EMP001',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onPressed: () {
                                final code = _manualIdController.text.trim().toUpperCase();
                                if (code.isEmpty) return;
                                final emp = _findEmployee(code);
                                if (emp.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Employee ID not found!')),
                                  );
                                  return;
                                }
                                final dept = emp['department']?.toString().toLowerCase() ?? '';
                                if (!dept.contains('harvest')) {
                                  final actString = _scanAction == 'checkin' ? 'check-in to' : 'check-out of';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: Only Harvest department employees can $actString Harvest rooms.')),
                                  );
                                  return;
                                }
                                final name = emp['name'] as String;
                                if (_scanAction == 'checkin') {
                                  widget.onCheckIn(code, _roomSelected);
                                  setState(() {
                                    _scannedHistory.insert(0, 'Checked In: $name ($code)');
                                  });
                                } else {
                                  widget.onCheckOut(code, _roomSelected);
                                  setState(() {
                                    _scannedHistory.insert(0, 'Checked Out: $name ($code)');
                                  });
                                }
                                _manualIdController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Successfully processed scan for: $name ($code)'),
                                    duration: const Duration(milliseconds: 800),
                                  ),
                                );
                              },
                              child: const Text('Scan'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Scanning Viewfinder
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FarmColors.forestGreen, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Mobile Camera Scan View
                            MobileScanner(
                              controller: _controller,
                              onDetect: _onDetect,
                            ),
                            // 2. Corner Viewfinder overlay
                            Positioned(
                              top: 20,
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: CustomPaint(
                                painter: _ViewportPainter(),
                              ),
                            ),
                            // 3. Red Scanning Line overlay
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Positioned(
                                  top: _animationController.value * 200,
                                  left: 24,
                                  right: 24,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.red,
                                          Colors.transparent
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withValues(alpha: 0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // 4. Torch and Flip controls overlay
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                                        color: _isTorchOn ? Colors.amber : Colors.white70,
                                      ),
                                      onPressed: () async {
                                        await _controller.toggleTorch();
                                        setState(() {
                                          _isTorchOn = !_isTorchOn;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
                                      onPressed: () => _controller.switchCamera(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Simulation trigger
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Simulate Next Badge Scan (Harvest Crew Only)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (harvestEmployees.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No Harvest department employees found!')),
                        );
                        return;
                      }

                      final nextIndex = _scannedHistory.length % harvestEmployees.length;
                      final emp = harvestEmployees[nextIndex];
                      final id = emp['id'] as String;
                      final name = emp['name'] as String;

                      if (_scanAction == 'checkin') {
                        widget.onCheckIn(id, _roomSelected);
                        setState(() {
                          _scannedHistory.insert(0, 'Checked In: $name ($id)');
                        });
                      } else {
                        widget.onCheckOut(id, _roomSelected);
                        setState(() {
                          _scannedHistory.insert(0, 'Checked Out: $name ($id)');
                        });
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Scanned successfully: $name ($id)'),
                          duration: const Duration(milliseconds: 800),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Scanned history list
                  const Text(
                    'Scanned History (Current Session)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white10 : Colors.white,
                        border: Border.all(color: FarmColors.borderLight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _scannedHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No scans in this session yet.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _scannedHistory.length,
                              itemBuilder: (c, idx) {
                                return Card(
                                  color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.check_circle, color: Colors.green),
                                    title: Text(
                                      _scannedHistory[idx],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    subtitle: Text(
                                      'Target: ${_roomSelected.replaceAll('Room', 'Grow Room ')}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Done Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Scanning session ended. Processed ${_scannedHistory.length} actions.')),
                      );
                    },
                    child: const Text('Done / Finish Scanning', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ViewportPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      // Top Left Corner
      ..moveTo(0, 30)
      ..lineTo(0, 0)
      ..lineTo(30, 0)
      // Top Right Corner
      ..moveTo(size.width - 30, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 30)
      // Bottom Right Corner
      ..moveTo(size.width, size.height - 30)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - 30, size.height)
      // Bottom Left Corner
      ..moveTo(30, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - 30);

    canvas.drawPath(path, paint);

    // Laser Line
    final laserPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), laserPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
