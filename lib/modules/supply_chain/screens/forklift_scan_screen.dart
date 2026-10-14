import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/app_database.dart';
import '../repository.dart';
import '../services/gs1_barcode_parser.dart';
import '../../warehouse_automation/models/putaway_fefo_models.dart';
import '../../warehouse_automation/services/directed_putaway_engine.dart';

class ForkliftScanScreen extends StatefulWidget {
  const ForkliftScanScreen({super.key});

  @override
  State<ForkliftScanScreen> createState() => _ForkliftScanScreenState();
}

class _ForkliftScanScreenState extends State<ForkliftScanScreen> {
  final SupplyChainRepository _repo = SupplyChainRepository();
  final DirectedPutawayEngine _putawayEngine = DirectedPutawayEngine();
  final TextEditingController _lpnInputController = TextEditingController();
  final TextEditingController _locInputController = TextEditingController();

  bool _isLoading = true;
  bool _isProcessingMove = false;

  // Selected state
  Map<String, dynamic>? _scannedLpnDetails;
  PutawayRecommendation? _putawayRecommendation;
  String? _selectedDestLocationCode;
  List<Location> _availableLocations = [];
  List<StockLpn> _stagedPallets = [];
  List<Map<String, dynamic>> _recentMoves = [];

  // Vehicle & Operator config
  final String _activeForklift = 'FL-01 (Toyota Reach Truck)';
  final String _activeOperator = 'Driver #08 (Cold Chain Shift A)';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _lpnInputController.dispose();
    _locInputController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final locs = await _repo.getAvailableLocations();
      final allLpns = await _repo.getAllLpns();
      final staged = allLpns.where((l) => l.status == 'staged' || l.locationId.contains('STAGING')).toList();
      final moves = await _repo.getRecentPalletMoves(limit: 6);

      setState(() {
        _availableLocations = locs;
        _stagedPallets = staged;
        _recentMoves = moves;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _lookupLpn(String rawBarcode) async {
    final cleanInput = rawBarcode.trim();
    if (cleanInput.isEmpty) return;

    // Check if input is GS1-128 / SSCC formatted
    String targetCode = cleanInput;
    if (cleanInput.contains('(00)') || cleanInput.contains('(01)')) {
      final parsed = Gs1BarcodeParser.parse(cleanInput);
      if (parsed.sscc != null) {
        targetCode = parsed.sscc!;
      } else if (parsed.lotNumber != null) {
        targetCode = parsed.lotNumber!;
      }
    }

    final details = await _repo.getLpnFullDetails(targetCode);
    if (details != null) {
      final lpnCode = (details['pallet'] as StockLpn).lpnCode;
      final rec = await _putawayEngine.calculateOptimalPutaway(lpnCode);
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _scannedLpnDetails = details;
          _putawayRecommendation = rec;
          _lpnInputController.text = lpnCode;
        });
      }
    } else {
      // Try finding by prefix or partial
      final allLpns = await _repo.getAllLpns();
      final matched = allLpns.where((l) =>
          l.lpnCode.toUpperCase().contains(cleanInput.toUpperCase()) ||
          l.id.startsWith(cleanInput)).firstOrNull;

      if (matched != null) {
        final fullDetails = await _repo.getLpnFullDetails(matched.lpnCode);
        final rec = await _putawayEngine.calculateOptimalPutaway(matched.lpnCode);
        if (mounted) {
          setState(() {
            _scannedLpnDetails = fullDetails;
            _putawayRecommendation = rec;
            _lpnInputController.text = matched.lpnCode;
          });
          HapticFeedback.mediumImpact();
        }
      } else {
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              content: Text(
                'KHÔNG TÌM THẤY LPN "$cleanInput"!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmPalletRelocation() async {
    if (_scannedLpnDetails == null) {
      _showWarning('Vui lòng quét hoặc chọn Pallet LPN trước.');
      return;
    }
    if (_selectedDestLocationCode == null || _selectedDestLocationCode!.isEmpty) {
      _showWarning('Vui lòng chọn Vị Trí Đích (Destination Rack/Gate).');
      return;
    }

    final pallet = _scannedLpnDetails!['pallet'] as StockLpn;
    if (pallet.locationId == _selectedDestLocationCode) {
      _showWarning('Pallet đã ở vị trí này rồi ($_selectedDestLocationCode).');
      return;
    }

    setState(() => _isProcessingMove = true);

    try {
      await _repo.movePalletLpn(
        lpnCode: pallet.lpnCode,
        destLocationId: _selectedDestLocationCode!,
        transportType: _activeForklift,
      );

      HapticFeedback.vibrate();

      if (mounted) {
        final destCode = _selectedDestLocationCode;
        final lpnCode = pallet.lpnCode;

        // Reset state for next scan
        setState(() {
          _scannedLpnDetails = null;
          _putawayRecommendation = null;
          _selectedDestLocationCode = null;
          _lpnInputController.clear();
          _locInputController.clear();
        });

        await _loadInitialData();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'THÀNH CÔNG: Chuyển $lpnCode vào $destCode',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('Lỗi di chuyển pallet: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingMove = false);
      }
    }
  }

  void _showWarning(String msg) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.orange.shade900,
        content: Text(msg, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showStagedPalletsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PALLET CHỜ CHUYỂN (STAGING)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: _stagedPallets.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có pallet nào ở khu vực tập kết.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _stagedPallets.length,
                        itemBuilder: (context, idx) {
                          final p = _stagedPallets[idx];
                          return Card(
                            color: const Color(0xFF334155),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF10B981),
                                child: Icon(Icons.inventory_2, color: Colors.white),
                              ),
                              title: Text(
                                p.lpnCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              subtitle: Text(
                                'Vị trí: ${p.locationId} | Gross: ${p.grossWeightKg?.toStringAsFixed(1) ?? '0.0'} kg',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Colors.amber),
                              onTap: () {
                                Navigator.pop(context);
                                _lookupLpn(p.lpnCode);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Industrial Slate-900 high contrast
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
        title: Row(
          children: [
            const Icon(Icons.forklift, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TERMINAL XE NÂNG (FORKLIFT)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '$_activeForklift // $_activeOperator',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loadInitialData,
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: Colors.amber),
            tooltip: 'Xem Pallet Staging',
            onPressed: _showStagedPalletsModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- STEP 1: SCAN LPN BARCODE ---
                  _buildStepHeader(
                    stepNumber: '1',
                    title: 'QUÉT HOẶC CHỌN PALLET (LPN)',
                    actionButton: TextButton.icon(
                      icon: const Icon(Icons.list_alt, color: Colors.amber, size: 20),
                      label: Text(
                        'Staging (${_stagedPallets.length})',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showStagedPalletsModal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLpnScanInput(),
                  const SizedBox(height: 12),

                  if (_scannedLpnDetails != null) ...[
                    _buildLpnSummaryCard(_scannedLpnDetails!),
                    const SizedBox(height: 12),
                    if (_putawayRecommendation != null) ...[
                      _buildPutawayRecommendationCard(_putawayRecommendation!),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                  ],

                  // --- STEP 2: SELECT DESTINATION ---
                  _buildStepHeader(
                    stepNumber: '2',
                    title: 'CHỈ ĐỊNH VỊ TRÍ ĐÍCH (DESTINATION)',
                  ),
                  const SizedBox(height: 8),
                  _buildDestinationPresets(),
                  const SizedBox(height: 24),

                  // --- STEP 3: ACTION CONFIRM BUTTON ---
                  _buildConfirmActionButton(),
                  const SizedBox(height: 24),

                  // --- RECENT MOVES SECTION ---
                  _buildRecentMovesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStepHeader({
    required String stepNumber,
    required String title,
    Widget? actionButton,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (actionButton != null) actionButton,
      ],
    );
  }

  Widget _buildLpnScanInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _lpnInputController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                hintText: 'Quét barcode GS1-128 / LPN...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
                border: InputBorder.none,
              ),
              onSubmitted: _lookupLpn,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => _lookupLpn(_lpnInputController.text),
            child: const Text('TÌM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLpnSummaryCard(Map<String, dynamic> data) {
    final pallet = data['pallet'] as StockLpn;
    final gross = (data['gross_weight'] as double).toStringAsFixed(1);
    final net = (data['net_weight'] as double).toStringAsFixed(1);
    final qty = (data['total_quantity'] as double).toInt();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pallet.lpnCode,
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade800,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'STATUS: ${pallet.status.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['product_name'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lô: ${data['lot_number']} | Đóng gói: $qty ${data['uom']}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailMetric('VỊ TRÍ HIỆN TẠI', data['location_code'] as String, Colors.cyan),
              _buildDetailMetric('NET WEIGHT', '$net kg', Colors.amber),
              _buildDetailMetric('GROSS WEIGHT', '$gross kg', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPutawayRecommendationCard(PutawayRecommendation rec) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B), // High contrast deep emerald
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34D399), width: 2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assistant_direction, color: Color(0xFF34D399), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'CHỈ ĐỊNH VỊ TRÍ TỰ ĐỘNG (3D DIRECTED PUTAWAY)',
                    style: TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SCORE: ${rec.score.toInt()}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VỊ TRÍ ĐỀ XUẤT TỐI ƯU:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      rec.targetLocation.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      rec.targetLocation.name,
                      style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34D399),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check_circle, size: 18, color: Colors.black),
                label: const Text('CHỌN Ô NÀY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedDestLocationCode = rec.targetLocation.code);
                },
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Text(
            '💡 ${rec.slotReason}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            'Lộ trình: ${rec.navigationPath}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildDestinationPresets() {
    final presets = [
      {'code': 'WH1-COLD-GATE', 'name': 'CỬA KHO LẠNH #01 (DOCK)', 'icon': Icons.door_sliding},
      {'code': 'WH1-COLD-A01-R01-L1', 'name': 'DÃY A KỆ 01 TẦNG 1', 'icon': Icons.table_rows},
      {'code': 'WH1-COLD-A01-R01-L2', 'name': 'DÃY A KỆ 01 TẦNG 2', 'icon': Icons.vertical_align_top},
      {'code': 'WH1-COLD-A02-R01-L1', 'name': 'DÃY A2 (FAST-MOVING)', 'icon': Icons.flash_on},
      {'code': 'WH1-QUARANTINE', 'name': 'KHU CÁCH LY QC', 'icon': Icons.warning_amber},
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: presets.length,
          itemBuilder: (context, idx) {
            final p = presets[idx];
            final code = p['code'] as String;
            final isSelected = _selectedDestLocationCode == code;

            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedDestLocationCode = code);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.cyanAccent : Colors.white24,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(p['icon'] as IconData, color: isSelected ? Colors.white : Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p['name'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            code,
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : Colors.white38,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          ),
          icon: const Icon(Icons.location_searching, size: 18, color: Colors.cyanAccent),
          label: Text(
            _selectedDestLocationCode != null
                ? 'Đã chọn: $_selectedDestLocationCode (Bấm để đổi vị trí khác)'
                : 'Chọn vị trí khác trong kho (${_availableLocations.length} vị trí)...',
            style: const TextStyle(fontSize: 13),
          ),
          onPressed: _showAllLocationsModal,
        ),
      ],
    );
  }

  void _showAllLocationsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TẤT CẢ VỊ TRÍ KHO HÀNG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableLocations.length,
                  itemBuilder: (context, idx) {
                    final loc = _availableLocations[idx];
                    final isSelected = _selectedDestLocationCode == loc.code;
                    return ListTile(
                      leading: Icon(
                        loc.type == 'dock'
                            ? Icons.door_sliding
                            : loc.type == 'bin'
                                ? Icons.table_rows
                                : Icons.place,
                        color: isSelected ? Colors.cyanAccent : Colors.white70,
                      ),
                      title: Text(
                        loc.name,
                        style: TextStyle(
                          color: isSelected ? Colors.cyanAccent : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${loc.code} (${loc.type}) - ${loc.path}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.cyanAccent)
                          : null,
                      onTap: () {
                        setState(() => _selectedDestLocationCode = loc.code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfirmActionButton() {
    final canConfirm = _scannedLpnDetails != null &&
        _selectedDestLocationCode != null &&
        !_isProcessingMove;

    return SizedBox(
      height: 64,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canConfirm ? const Color(0xFF059669) : const Color(0xFF334155),
          foregroundColor: Colors.white,
          elevation: canConfirm ? 6 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: canConfirm ? _confirmPalletRelocation : null,
        child: _isProcessingMove
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(width: 14),
                  Text(
                    'ĐANG XÁC NHẬN LỆNH...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 32),
                  SizedBox(width: 12),
                  Text(
                    'XÁC NHẬN CHUYỂN PALLET // CONFIRM MOVE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRecentMovesSection() {
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
                'LỊCH SỬ DI CHUYỂN GẦN ĐÂY (TERMINAL AUDIT)',
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
          if (_recentMoves.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chưa có lệnh di chuyển nào.', style: TextStyle(color: Colors.white38)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentMoves.length,
              separatorBuilder: (context, idx) => const Divider(color: Colors.white12),
              itemBuilder: (context, idx) {
                final m = _recentMoves[idx];
                final lpn = m['lpn_code'] as String;
                final src = m['source'] as String;
                final dst = m['dest'] as String;
                final prod = m['product_name'] as String;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.forklift, color: Color(0xFF34D399), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lpn,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$prod ($src → $dst)',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Chip(
                        label: Text('DONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: Color(0xFF065F46),
                        labelStyle: TextStyle(color: Color(0xFF6EE7B7)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
