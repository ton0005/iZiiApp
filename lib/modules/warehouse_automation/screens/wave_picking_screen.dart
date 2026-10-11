import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/app_database.dart';
import '../models/wave_audit_models.dart';
import '../services/wave_picking_service.dart';

class WavePickingScreen extends StatefulWidget {
  const WavePickingScreen({super.key});

  @override
  State<WavePickingScreen> createState() => _WavePickingScreenState();
}

class _WavePickingScreenState extends State<WavePickingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WavePickingService _waveService = WavePickingService();

  List<StockPicking> _pendingPickings = [];
  final Set<String> _selectedPickingIds = {};
  StockWave? _activeWave;
  bool _isLoading = true;
  bool _isCreatingWave = false;

  String _dispatchWindow = 'Morning 08:00 - 10:00 (Dispatch Slot 1)';
  String _carrier = 'Linfox Cold-Chain Transport';
  final TextEditingController _driverIdController =
      TextEditingController(text: 'FORKLIFT-OPERATOR-02');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _driverIdController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingOrders() async {
    setState(() => _isLoading = true);
    final db = AppDatabase();
    final all = await (db.select(db.stockPickings)
          ..where((tbl) => tbl.pickingType.equals('outbound_sales')))
        .get();
    final pickings = all.where((p) => p.status != 'done' && p.status != 'cancelled').toList();

    setState(() {
      _pendingPickings = pickings;
      _selectedPickingIds.clear();
      for (final p in pickings) {
        _selectedPickingIds.add(p.id);
      }
      _isLoading = false;
    });
  }

  Future<void> _createWaveSession() async {
    if (_selectedPickingIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 outbound order to generate wave.')),
      );
      return;
    }

    setState(() => _isCreatingWave = true);
    HapticFeedback.mediumImpact();

    try {
      final wave = await _waveService.createWave(
        pickingIds: _selectedPickingIds.toList(),
        dispatchWindow: _dispatchWindow,
        carrier: _carrier,
        assignedDriver: _driverIdController.text.trim(),
      );

      setState(() {
        _activeWave = wave;
        _isCreatingWave = false;
        _tabController.animateTo(1);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully created ${wave.waveNumber} with optimized S-shape route!'),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    } catch (e) {
      setState(() => _isCreatingWave = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wave consolidation error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmPick(WavePickItem item) async {
    if (_activeWave == null) return;

    HapticFeedback.lightImpact();
    try {
      final updatedWave = await _waveService.confirmPickItem(
        waveId: _activeWave!.id,
        itemId: item.id,
        quantity: item.aggregatedQty,
        driverId: _driverIdController.text.trim(),
      );

      setState(() {
        _activeWave = updatedWave;
      });

      if (updatedWave.isCompleted && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
            title: const Text('WAVE PICKING COMPLETED'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wave ID: ${updatedWave.waveNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Carrier: ${updatedWave.carrier}'),
                Text('Dispatch Window: ${updatedWave.dispatchWindow}'),
                const Divider(),
                Text('Total Picked Quantity: ${updatedWave.totalPickedQty.toStringAsFixed(0)} cartons'),
                const SizedBox(height: 8),
                const Text(
                  'All items staged at DOCK-01-COLD and ready for Packout Scale Audit inspection.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _loadPendingOrders();
                  _tabController.animateTo(0);
                },
                child: const Text('Confirm & Complete'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Picking error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wave Picking Engine & Serpentine Routing'),
        backgroundColor: const Color(0xFF1E3A8A),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          tabs: [
            Tab(
              icon: const Icon(Icons.playlist_add_check),
              text: 'Wave Planning (${_pendingPickings.length})',
            ),
            Tab(
              icon: const Icon(Icons.route),
              text: _activeWave != null ? 'S-Shape Pick Path (${_activeWave!.items.length})' : 'Forklift Route',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWavePlanningTab(),
          _buildSRouteExecutionTab(),
        ],
      ),
    );
  }

  // ── TAB 1: WAVE PLANNING ──────────────────────────────────────────────────
  Widget _buildWavePlanningTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.alt_route, size: 36, color: Colors.blue.shade900),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wave Picking Engine & S-Shape Serpentine Route Optimization',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Consolidates multiple outbound orders by carrier and dispatch window; optimizes serpentine S-shape pick path so forklift operators traverse aisles without backtracking.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dispatch Options Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Dispatch Window & Carrier Setup', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _dispatchWindow,
                    decoration: const InputDecoration(labelText: 'Dispatch Slot Window', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Morning 08:00 - 10:00 (Dispatch Slot 1)', child: Text('Morning 08:00 - 10:00 (Dispatch Slot 1)')),
                      DropdownMenuItem(value: 'Midday 11:30 - 13:00 (Dispatch Slot 2)', child: Text('Midday 11:30 - 13:00 (Dispatch Slot 2)')),
                      DropdownMenuItem(value: 'Afternoon 15:00 - 17:00 (Dispatch Slot 3)', child: Text('Afternoon 15:00 - 17:00 (Dispatch Slot 3)')),
                    ],
                    onChanged: (v) => setState(() => _dispatchWindow = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _carrier,
                    decoration: const InputDecoration(labelText: 'Carrier / Logistics Fleet', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Linfox Cold-Chain Transport', child: Text('Linfox Cold-Chain Transport')),
                      DropdownMenuItem(value: 'Toll Global Cold Logistics', child: Text('Toll Global Cold Logistics')),
                      DropdownMenuItem(value: 'Costa Internal Cold Fleet', child: Text('Costa Internal Cold Fleet')),
                    ],
                    onChanged: (v) => setState(() => _carrier = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _driverIdController,
                    decoration: const InputDecoration(labelText: 'Assigned Forklift Driver ID', prefixIcon: Icon(Icons.forklift), border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pending Pickings Checklist Card
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
                      const Text('2. Select Outbound Orders for Wave', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedPickingIds.length == _pendingPickings.length) {
                              _selectedPickingIds.clear();
                            } else {
                              _selectedPickingIds.addAll(_pendingPickings.map((p) => p.id));
                            }
                          });
                        },
                        child: Text(_selectedPickingIds.length == _pendingPickings.length ? 'Deselect All' : 'Select All'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_pendingPickings.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('No pending outbound_sales orders awaiting dispatch.'),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: _seedDemoOrders,
                              icon: const Icon(Icons.add_shopping_cart),
                              label: const Text('Seed 3 sample B2B orders for Wave testing'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ..._pendingPickings.map((p) {
                      final isSelected = _selectedPickingIds.contains(p.id);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(p.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Doc: ${p.originDocument ?? "N/A"} | Notes: ${p.notes ?? "Supermarket Retailer"}'),
                        secondary: const Icon(Icons.local_shipping_outlined, color: Colors.indigo),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedPickingIds.add(p.id);
                            } else {
                              _selectedPickingIds.remove(p.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Button
          if (_isCreatingWave)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _pendingPickings.isEmpty ? null : _createWaveSession,
                icon: const Icon(Icons.alt_route),
                label: Text(
                  'GENERATE WAVE (${_selectedPickingIds.length} ORDERS) • S-SHAPE ROUTE',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── TAB 2: S-SHAPE ROUTE EXECUTION ────────────────────────────────────────
  Widget _buildSRouteExecutionTab() {
    if (_activeWave == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No active picking wave session!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Go to Wave Planning Tab'),
            ),
          ],
        ),
      );
    }

    final wave = _activeWave!;

    return Column(
      children: [
        // Wave Header & Progress
        Container(
          padding: const EdgeInsets.all(14),
          color: const Color(0xFF1E293B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    wave.waveNumber,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: wave.isCompleted ? Colors.green : Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      wave.isCompleted ? 'COMPLETED 100%' : 'PICKING IN PROGRESS',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Driver: ${wave.assignedDriver} | Staging Dock: ${wave.destinationDock}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: wave.progressPercentage,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Picked: ${wave.totalPickedQty.toStringAsFixed(0)} / ${wave.totalDemandQty.toStringAsFixed(0)} cartons',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${(wave.progressPercentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        // S-Shape Route Navigation Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.amber.shade100,
          child: Row(
            children: [
              Icon(Icons.fork_right, size: 20, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'S-Shape Pick Path: Odd aisles traverse forward (Bay 01 -> 10) | Even aisles reverse (Bay 10 -> 01)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),

        // Sequential Item List along S-route
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: wave.items.length,
            itemBuilder: (context, index) {
              final item = wave.items[index];
              final isOdd = (WavePickingService.parseLocationCoords(item.locationCode)['aisleIndex'] as int) % 2 != 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: item.isPicked ? Colors.green.shade300 : Colors.indigo.shade300,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: item.isPicked ? Colors.green : const Color(0xFF1E3A8A),
                            child: Text(
                              '${item.sequence}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.locationCode,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'Aisle ${item.aisle} (${isOdd ? "Forward ⬆" : "Reverse ⬇"}) • Bay ${item.bay} • Level ${item.level}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.isPicked ? Colors.green.shade100 : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.aggregatedQty.toStringAsFixed(0)} ${item.uom}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isPicked ? Colors.green.shade900 : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Lot: ${item.lotNumber ?? "All"} | Pallet LPN: ${item.lpnCode ?? "N/A"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),

                      // Order allocations breakdown
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Order Allocations:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ...item.allocations.map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('• ${a.orderCode} (${a.customerName})', style: const TextStyle(fontSize: 11)),
                                      Text('${a.quantity.toStringAsFixed(0)} cartons', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Confirm button
                      if (item.isPicked)
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                            SizedBox(width: 6),
                            Text('Item picked successfully', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmPick(item),
                            icon: const Icon(Icons.check),
                            label: Text('CONFIRM PICK ${item.aggregatedQty.toStringAsFixed(0)} CARTONS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                            ),
                          ),
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

  Future<void> _seedDemoOrders() async {
    final db = AppDatabase();

    // Create 3 demo outbound sales orders
    for (int i = 1; i <= 3; i++) {
      final pId = 'demo-pick-0$i';
      await db.into(db.stockPickings).insert(StockPickingsCompanion.insert(
        id: pId,
        code: 'OUT-2026-000$i',
        pickingType: 'outbound_sales',
        originDocument: Value('SO-COSTA-2026-00$i'),
        status: const Value('waiting'),
        notes: Value(i == 1 ? 'Woolworths DC Melbourne' : (i == 2 ? 'Coles DC Sydney' : 'Costco Wholesale Adelaide')),
      ));

      await db.into(db.stockPickingLines).insert(StockPickingLinesCompanion.insert(
        id: 'line-demo-0$i',
        pickingId: pId,
        productId: 'prod-cup-01',
        sourceLocationId: i == 1 ? 'WH1-COLD-A01-R01-L1' : (i == 2 ? 'WH1-COLD-A02-R03-L1' : 'WH1-COLD-A01-R05-L1'),
        destLocationId: 'DOCK-01-COLD',
        demandQty: Value(i * 24.0),
        uomId: 'box',
      ));
    }

    _loadPendingOrders();
  }
}
