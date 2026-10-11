import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../repository.dart';
import '../services/lpn_service.dart';
import '../services/uom_converter.dart';

class PalletScaleStationScreen extends StatefulWidget {
  const PalletScaleStationScreen({super.key});

  @override
  State<PalletScaleStationScreen> createState() => _PalletScaleStationScreenState();
}

class _PalletScaleStationScreenState extends State<PalletScaleStationScreen> {
  final SupplyChainRepository _repo = SupplyChainRepository();

  // State
  List<Product> _products = [];
  Product? _selectedProduct;
  bool _isLoading = true;

  // Pallet Packaging Config
  final String _plant = 'M1';
  String _roomCode = 'R33';
  int _boxCount = 72; // Standard 8 layers x 9 boxes
  final double _standardBoxNetKg = 4.0;
  final double _palletTareWeightKg = 35.0; // Wood pallet + strapping tare

  // Live Scale simulation state
  double _currentGrossWeightKg = 323.2; // 288.2 net + 35.0 tare
  final bool _isScaleStabilized = true;

  late String _currentLotNumber;
  late DateTime _expiryDate;

  @override
  void initState() {
    super.initState();
    _initDefaultLot();
    _loadProducts();
  }

  void _initDefaultLot() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final grade = _selectedProduct?.name ?? 'CUP';
    _currentLotNumber = 'LOT-$dateStr-$_roomCode-$grade';
    _expiryDate = now.add(const Duration(days: 7));
  }

  Future<void> _loadProducts() async {
    final prods = await _repo.getAllProducts();
    setState(() {
      _products = prods;
      if (prods.isNotEmpty) {
        _selectedProduct = prods.first;
      }
      _initDefaultLot();
      _isLoading = false;
    });
  }

  double get _theoreticalNetWeight => _boxCount * _standardBoxNetKg;
  double get _actualNetWeight => (_currentGrossWeightKg - _palletTareWeightKg).clamp(0.0, 9999.0);
  double get _weightVariancePct {
    if (_theoreticalNetWeight == 0) return 0.0;
    return ((_actualNetWeight - _theoreticalNetWeight) / _theoreticalNetWeight) * 100.0;
  }

  bool get _isWeightValid => _weightVariancePct.abs() <= 2.0; // Within +/- 2%

  Future<void> _finalizeAndPrintPallet() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sản phẩm.')),
      );
      return;
    }

    final lpnCode = LpnService.generateLpnCode(plant: _plant);
    final sscc18 = LpnService.generateSscc18(
      serialNumber: DateTime.now().millisecondsSinceEpoch % 1000000,
    );

    // Create Lot first if needed
    final lot = await _repo.createLot(
      productId: _selectedProduct!.id,
      lotNumber: _currentLotNumber,
      productionDate: DateTime.now(),
      bestBeforeDate: DateTime.now().add(const Duration(days: 5)),
      expiryDate: _expiryDate,
      status: 'approved',
      notes: 'Đóng pallet tại trạm cân xưởng $_plant',
    );

    // Create Pallet LPN
    final pallet = await _repo.createPalletLpn(
      lpnCode: lpnCode,
      locationId: '$_plant-STAGING',
      productId: _selectedProduct!.id,
      lotId: lot.id,
      quantity: _boxCount.toDouble(),
      uomId: 'box',
      grossWeightKg: _currentGrossWeightKg,
      tareWeightKg: _palletTareWeightKg,
      netWeightKg: _actualNetWeight,
      customFields: {
        'sscc18': sscc18,
        'roomCode': _roomCode,
        'variancePct': _weightVariancePct.toStringAsFixed(2),
      },
    );

    if (!mounted) return;

    // Show GS1 Thermal Label Preview
    _showLpnLabelDialog(pallet, sscc18);
  }

  void _showLpnLabelDialog(StockLpn pallet, String sscc18) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.print, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Tem Nhãn GS1 LPN (Pallet Label)', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('COSTA MUSHROOMS — PLANT $_plant',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                          const Text('LOGISTICS SSCC',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 1.5),
                      Text('SẢN PHẨM: ${_selectedProduct?.name.toUpperCase()}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                      Text('MÃ SKU: ${_selectedProduct?.sku}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      Text('SỐ LÔ (LOT): $_currentLotNumber',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                      Text('HẠN DÙNG (EXPIRY): ${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('SỐ THÙNG: $_boxCount boxes',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('TỊNH (NET): ${_actualNetWeight.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('TỔNG (GROSS): ${_currentGrossWeightKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 1),
                      const SizedBox(height: 6),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              height: 50,
                              width: double.infinity,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: Text(
                                '|||||||||||||||||||||||||||||||||||||||||||||||||||||\n${pallet.lpnCode}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('(00) $sscc18',
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text('Xác nhận & In nhiệt'),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text('✅ Đã tạo Pallet [${pallet.lpnCode}] & gửi lệnh in tem Zebra ZPL!'),
                  ),
                );
                // Reset for next pallet
                setState(() {
                  _initDefaultLot();
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final packagingBreakdown = UomConverter.decomposePackaging(
      totalUnits: _boxCount,
      unitsPerBox: 1,
      boxesPerPallet: 72,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạm Cân & Đóng Pallet (LPN Scale Station)'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          Chip(
            backgroundColor: _isScaleStabilized ? Colors.green.shade800 : Colors.orange.shade800,
            label: Text(
              _isScaleStabilized ? 'CÂN ỔN ĐỊNH' : 'ĐANG DAO ĐỘNG',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP LCD WEIGHING DISPLAY
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DIGITAL SCALE — BENCH WEIGHBRIDGE #01',
                        style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.2),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                            tooltip: 'Zero / Tare Cân',
                            onPressed: () {
                              setState(() {
                                _currentGrossWeightKg = _palletTareWeightKg;
                              });
                            },
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _currentGrossWeightKg += 1.0;
                              });
                            },
                            child: const Text('+1kg', style: TextStyle(color: Colors.cyanAccent)),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _currentGrossWeightKg -= 1.0;
                              });
                            },
                            child: const Text('-1kg', style: TextStyle(color: Colors.cyanAccent)),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _currentGrossWeightKg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'KG (GROSS)',
                        style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('BÌ PALLET (TARE)', '${_palletTareWeightKg.toStringAsFixed(1)} kg'),
                      _buildMetricItem('TỊNH THỰC TẾ (NET)', '${_actualNetWeight.toStringAsFixed(1)} kg',
                          color: Colors.cyanAccent),
                      _buildMetricItem('ĐỊNH MỨC (THEORY)', '${_theoreticalNetWeight.toStringAsFixed(1)} kg'),
                      _buildMetricItem(
                        'SAI LỆCH (VARIANCE)',
                        '${_weightVariancePct >= 0 ? '+' : ''}${_weightVariancePct.toStringAsFixed(2)}%',
                        color: _isWeightValid ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // FORM CONFIGURATION SECTION
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Thông tin Hàng hóa & Đóng gói',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Product>(
                            initialValue: _selectedProduct,
                            decoration: const InputDecoration(
                              labelText: 'Chủng loại / Sản phẩm',
                              border: OutlineInputBorder(),
                            ),
                            items: _products.map((p) {
                              return DropdownMenuItem(value: p, child: Text(p.name));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedProduct = val;
                                _initDefaultLot();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _roomCode,
                            decoration: const InputDecoration(
                              labelText: 'Phòng trồng (Grow Room)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _roomCode = val;
                                _initDefaultLot();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(_currentLotNumber),
                            initialValue: _currentLotNumber,
                            decoration: const InputDecoration(
                              labelText: 'Mã số Lô (Lot Number)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => _currentLotNumber = val,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _boxCount.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số thùng trên Pallet (Boxes)',
                              border: OutlineInputBorder(),
                              suffixText: 'thùng',
                            ),
                            onChanged: (val) {
                              final count = int.tryParse(val) ?? 72;
                              setState(() {
                                _boxCount = count;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Quy cách pallet: ${packagingBreakdown['pallets']} Pallet chuẩn (${_boxCount ~/ 9} lớp × 9 thùng) + '
                              '${packagingBreakdown['boxes']} Thùng lẻ. '
                              'Tự động gán vị trí Staging: [$_plant-STAGING].',
                              style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // SUBMIT BUTTON
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWeightValid ? const Color(0xFF10B981) : Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.print_outlined, size: 28),
                label: Text(
                  _isWeightValid
                      ? 'HOÀN TẤT & IN TEM LPN PALLET'
                      : 'CẢNH BÁO TRỌNG LƯỢNG LỆCH (${_weightVariancePct.toStringAsFixed(1)}%) — VẪN IN',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _finalizeAndPrintPallet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
