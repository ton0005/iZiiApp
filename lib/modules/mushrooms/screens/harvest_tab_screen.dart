import 'package:drift/drift.dart' as d;
import 'package:izii_app/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository.dart';
import '../bloc/mushrooms_bloc.dart';
import 'continuous_scanner_screen.dart';

class HarvestTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final Map<String, List<String>> roomCrews;
  final List<Map<String, dynamic>> pickingPlans;
  final Function(String, String) onCheckIn;
  final Function(String, String) onCheckOut;
  final Function(String, double) onPickedYieldUpdated;
  final Function(String) onSafetyContact;

  final String activePlant;
  final Function(String) onPlantChanged;

  const HarvestTabScreen({
    super.key,
    required this.isDark,
    required this.localRooms,
    required this.roomCrews,
    required this.pickingPlans,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onPickedYieldUpdated,
    required this.onSafetyContact,
    required this.activePlant,
    required this.onPlantChanged,
  });

  @override
  State<HarvestTabScreen> createState() => _HarvestTabScreenState();
}

class _HarvestTabScreenState extends State<HarvestTabScreen> {
  final TextEditingController _empIdController = TextEditingController();
  late String _roomSelected;

  String _subMode = 'active'; // 'active', 'planning', or 'orders'
  List<Map<String, dynamic>> _yieldSurveys = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoadingPlanning = false;

  // Manual Allocation inputs
  final Map<String, TextEditingController> _allocControllers = {};
  final Map<String, String> _allocTypes = {};

  // Orders Management state
  Map<String, dynamic>? _selectedOrderToAllocate;
  final Map<String, Map<String, TextEditingController>> _orderAllocControllers = {};

  // Manual Scheduling assignments
  final Map<String, String> _scheduledAssignments = {};

  // Available time slots
  final List<String> _timeSlots = ['06:00', '08:00', '10:00', '12:00', '14:00'];

  final ScrollController _ganttSchedHorizController = ScrollController();
  final ScrollController _ganttSchedVertController = ScrollController();

  @override
  void initState() {
    super.initState();
    _roomSelected = widget.localRooms.keys.firstWhere(
        (k) => widget.localRooms[k]!['plant'] == widget.activePlant,
        orElse: () => widget.localRooms.keys.first);
    _loadPlanningData();
  }

  Future<void> _loadPlanningData() async {
    setState(() => _isLoadingPlanning = true);
    final repo = MushroomsRepository();
    final surveys = await repo.getYieldSurveys();
    final emps = await repo.getEmployees();

    _allocControllers.clear();
    _allocTypes.clear();
    for (final roomKey in widget.localRooms.keys) {
      if (widget.localRooms[roomKey]!['plant'] == widget.activePlant) {
        final currentTarget = widget.localRooms[roomKey]!['targetYield'] ?? 0.0;
        _allocControllers[roomKey] = TextEditingController(
          text: currentTarget > 0 ? currentTarget.toInt().toString() : '',
        );
        
        final currentPlanJson = widget.localRooms[roomKey]!['pickingPlanJson']?.toString();
        String currentType = 'White';
        if (currentPlanJson != null && currentPlanJson.isNotEmpty) {
          try {
            final parsed = jsonDecode(currentPlanJson);
            currentType = parsed['mushroomType']?.toString() ?? 'White';
          } catch (_) {}
        }
        _allocTypes[roomKey] = currentType;
      }
    }

    setState(() {
      _yieldSurveys = surveys;
      _employees = emps;
      _isLoadingPlanning = false;
    });
  }

  Map<String, dynamic> _findYieldSurvey(String roomName) {
    for (final s in _yieldSurveys) {
      if (s['roomName'] == roomName) {
        return s;
      }
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _findEmployee(String code) {
    for (final e in _employees) {
      if (e['id']?.toString().toUpperCase() == code.toUpperCase()) {
        return e;
      }
    }
    return <String, dynamic>{};
  }

  @override
  void didUpdateWidget(covariant HarvestTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePlant != widget.activePlant) {
      _roomSelected = widget.localRooms.keys.firstWhere(
          (k) => widget.localRooms[k]!['plant'] == widget.activePlant,
          orElse: () => widget.localRooms.keys.first);
      _loadPlanningData();
    }
  }

  String _getPlantFromRoomName(String roomName) {
    final clean = roomName.replaceAll(RegExp(r'\D'), '');
    final num = int.tryParse(clean) ?? 1;
    return num >= 33 ? 'M2' : 'M1';
  }

  @override
  void dispose() {
    _empIdController.dispose();
    for (final c in _allocControllers.values) {
      c.dispose();
    }
    _ganttSchedHorizController.dispose();
    _ganttSchedVertController.dispose();
    super.dispose();
  }

  void _showScanCardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Employee Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 40),
                      SizedBox(height: 10),
                      Text('[ CAMERA VIEWFINDER LIVE ]',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace')),
                      SizedBox(height: 6),
                      Text('Align employee card barcode in frame',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                  Positioned(
                    top: 40,
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: CustomPaint(
                      painter: _BorderPainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Align the worker badge or card to the scanner frame to auto-detect ID.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.forestGreen),
            onPressed: () {
              final harvestEmployees = _employees
                  .where((e) => e['department']?.toString().toLowerCase().contains('harvest') ?? false)
                  .toList();
              final empId = harvestEmployees.isNotEmpty ? (harvestEmployees.first['id'] as String) : 'EMP003';
              setState(() {
                _empIdController.text = empId;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Successfully scanned Employee ID: $empId')),
              );
            },
            child: const Text('Simulate Scan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if any room has only 1 picker checked in
    String? soloRoom;
    String? soloWorker;

    widget.localRooms.forEach((rName, rData) {
      final crew = widget.roomCrews[rName] ?? [];
      if (crew.length == 1) {
        soloRoom = rName;
        soloWorker = crew[0];
      }
    });

    final activeRooms = widget.localRooms.values.where((r) {
      final crew = widget.roomCrews[r['name']] ?? [];
      final target = r['targetYield'] ?? 0.0;
      return crew.isNotEmpty || target > 0.0;
    }).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plant Selection Buttons (M1 / M2) & Sub-Tab segment toggler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.activePlant == 'M2'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => widget.onPlantChanged('M2'),
                    child: const Text('Plant M2 (Rooms 33-66)'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.activePlant == 'M1'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => widget.onPlantChanged('M1'),
                    child: const Text('Plant M1 (Rooms 1-32)'),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildSubTabButton('active', 'Active Harvesting', Icons.dns_rounded),
                    _buildSubTabButton('planning', 'Harvest Planning', Icons.analytics_rounded),
                    _buildSubTabButton('orders', 'Orders Management', Icons.shopping_basket_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Solo Warning banner
          if (soloRoom != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: widget.isDark ? FarmColors.forestGreen : Colors.red.shade100,
                  border: Border.all(color: widget.isDark ? FarmColors.forestGreen : Colors.redAccent),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: widget.isDark ? Colors.white : Colors.red),
                      const SizedBox(width: 8),
                      Text(
                          'Warning: Worker performing Solo Picking at $soloRoom (${soloWorker})!',
                          style: TextStyle(
                              color: widget.isDark ? Colors.white : Colors.red,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    onPressed: () => widget.onSafetyContact(soloRoom!),
                    child: const Text('Emergency Contact'),
                  )
                ],
              ),
            ),

          Expanded(
            child: _subMode == 'active'
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: Checkin form & Picking plan list
                      SizedBox(
                        width: 340,
                        child: Column(
                          children: [
                            // Check-in card
                            _buildCheckinCard(widget.isDark),
                            const SizedBox(height: 16),
                            // Picking plans list card
                            Expanded(
                              child: _buildPickingPlansCard(widget.isDark),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right: Active rooms table
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            border: Border.all(color: FarmColors.borderLight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Active Harvesting Rooms',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: activeRooms.isEmpty
                                    ? const Center(
                                        child: Text(
                                            'No rooms currently in harvest stage.'))
                                    : _buildActiveRoomsTable(activeRooms),
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  )
                : (_subMode == 'planning' ? _buildPlanningView() : _buildOrdersManagementView()),
          )
        ],
      ),
    );
  }

  Widget _buildCheckinCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grow Room Check-in / Check-out',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _empIdController,
            decoration: InputDecoration(
                labelText: 'Employee ID',
                hintText: 'EMP003',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner,
                      color: FarmColors.forestGreen),
                  tooltip: 'Scan ID Card',
                  onPressed: _showScanCardDialog,
                )),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Grow Room'),
            value: _roomSelected,
            items: widget.localRooms.keys
                .where((k) => widget.localRooms[k]!['plant'] == widget.activePlant)
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    final code = _empIdController.text.trim().toUpperCase();
                    final emp = _findEmployee(code);
                    if (emp.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Employee ID not found!')),
                      );
                      return;
                    }
                    final dept = emp['department']?.toString().toLowerCase() ?? '';
                    if (!dept.contains('harvest')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Only Harvest department employees can check-in to Harvest rooms.')),
                      );
                      return;
                    }
                    widget.onCheckIn(code, _roomSelected);
                  },
                  child: const Text('Check In'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    final code = _empIdController.text.trim().toUpperCase();
                    final emp = _findEmployee(code);
                    if (emp.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Employee ID not found!')),
                      );
                      return;
                    }
                    final dept = emp['department']?.toString().toLowerCase() ?? '';
                    if (!dept.contains('harvest')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Only Harvest department employees can check-out of Harvest rooms.')),
                      );
                      return;
                    }
                    widget.onCheckOut(code, _roomSelected);
                  },
                  child: const Text('Check Out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.autorenew_rounded),
              label: const Text('Continuous Scan Check In/Out'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: FarmColors.forestGreen),
                foregroundColor: FarmColors.forestGreenText,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContinuousScannerScreen(
                      localRooms: widget.localRooms,
                      activePlant: widget.activePlant,
                      onCheckIn: widget.onCheckIn,
                      onCheckOut: widget.onCheckOut,
                      isDark: widget.isDark,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickingPlansCard(bool isDark) {
    final filteredPlans = widget.pickingPlans
        .where((plan) => plan['plant'] == widget.activePlant)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Picking Request from Cool Room',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (filteredPlans.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filteredPlans.length} Pending',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredPlans.isEmpty
                ? const Center(
                    child: Text('No active picking requests.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.builder(
                    itemCount: filteredPlans.length,
                    itemBuilder: (context, idx) {
                      final plan = filteredPlans[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade50,
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.inventory_2_rounded, size: 14, color: FarmColors.coolBlue),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${plan['roomName'].toString().replaceAll('Room', 'Grow Room')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Sent at: ${plan['sentAt'] ?? 'Today'}',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (plan['mushroomType'] ?? 'White') == 'Brown' ? Colors.brown.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    border: Border.all(color: (plan['mushroomType'] ?? 'White') == 'Brown' ? Colors.brown : Colors.grey),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    plan['mushroomType'] ?? 'White',
                                    style: TextStyle(color: (plan['mushroomType'] ?? 'White') == 'Brown' ? Colors.brown : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (plan['button'] > 0)
                                  _buildPlanBadge('Button', plan['button'], Colors.orange),
                                if (plan['medium'] > 0)
                                  _buildPlanBadge('Cup', plan['medium'], Colors.purple),
                                if (plan['open'] > 0)
                                  _buildPlanBadge('Flat', plan['open'], Colors.blue),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildPlanBadge(String name, int qty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$name: ${qty}kg',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOrdersManagementView() {
    final filteredPlans = widget.pickingPlans
        .where((plan) => plan['plant'] == widget.activePlant)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Pending orders list
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border.all(color: FarmColors.borderLight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Incoming Picking Orders',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Requests from Cool Room / Sales Module',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (filteredPlans.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filteredPlans.length} Pending',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: filteredPlans.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_basket_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No pending picking orders.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredPlans.length,
                          itemBuilder: (context, idx) {
                            final plan = filteredPlans[idx];
                            final isSelected = _selectedOrderToAllocate?['id'] == plan['id'];

                            return Card(
                              color: isSelected
                                  ? FarmColors.forestGreen.withOpacity(0.08)
                                  : (widget.isDark ? Colors.white10 : Colors.grey.shade50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? FarmColors.forestGreen
                                      : (widget.isDark ? Colors.white24 : Colors.grey.shade300),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Order #${plan['id'].toString().substring(plan['id'].toString().length - 4)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          'Sent: ${plan['sentAt'] ?? 'N/A'}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (plan['mushroomType'] ?? 'White') == 'Brown' ? Colors.brown.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                            border: Border.all(color: (plan['mushroomType'] ?? 'White') == 'Brown' ? Colors.brown : Colors.grey),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            plan['mushroomType'] ?? 'White',
                                            style: TextStyle(color: (plan['mushroomType'] ?? 'White') == 'Brown' ? Colors.brown : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (plan['button'] > 0)
                                          _buildPlanBadge('Button', plan['button'], Colors.orange),
                                        if (plan['medium'] > 0)
                                          _buildPlanBadge('Cup', plan['medium'], Colors.purple),
                                        if (plan['open'] > 0)
                                          _buildPlanBadge('Flat', plan['open'], Colors.blue),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.flash_on, size: 14),
                                          label: const Text('Auto Allocate', style: TextStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                            side: const BorderSide(color: Colors.blue),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          onPressed: () => _autoAllocateOrder(plan),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.arrow_forward, size: 14),
                                          label: const Text('Manual Allocate', style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: FarmColors.forestGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _selectedOrderToAllocate = plan;
                                              _initOrderAllocControllers(plan);
                                            });
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right Column: Allocation & Room distribution
        Expanded(
          flex: 7,
          child: _selectedOrderToAllocate == null
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_ind_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No order selected for manual allocation.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Select an order from the left column to distribute to Grow Rooms.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _buildManualOrderAllocationView(),
        ),
      ],
    );
  }

  void _initOrderAllocControllers(Map<String, dynamic> plan) {
    _orderAllocControllers.clear();
    final activePlantRooms = widget.localRooms.keys
        .where((k) => widget.localRooms[k]!['plant'] == widget.activePlant)
        .toList();

    for (final roomName in activePlantRooms) {
      _orderAllocControllers[roomName] = {
        'allocated': TextEditingController(),
      };
    }
  }

  Widget _buildManualOrderAllocationView() {
    final plan = _selectedOrderToAllocate!;
    final type = plan['mushroomType'] ?? 'White';
    final buttonQty = plan['button'] ?? 0;
    final mediumQty = plan['medium'] ?? 0;
    final openQty = plan['open'] ?? 0;
    final totalOrderQty = buttonQty + mediumQty + openQty;

    final activePlantRooms = widget.localRooms.keys
        .where((k) => widget.localRooms[k]!['plant'] == widget.activePlant)
        .toList();

    // Sum currently entered allocation
    int currentSum = 0;
    _orderAllocControllers.forEach((roomName, controllers) {
      final text = controllers['allocated']?.text.trim() ?? '';
      currentSum += int.tryParse(text) ?? 0;
    });

    final remainingQty = totalOrderQty - currentSum;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allocating Order #${plan['id'].toString().substring(plan['id'].toString().length - 4)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _selectedOrderToAllocate = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: type == 'Brown' ? Colors.brown.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
              border: Border.all(color: type == 'Brown' ? Colors.brown.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mushroom Type: $type', style: TextStyle(fontWeight: FontWeight.bold, color: type == 'Brown' ? Colors.brown : Colors.grey.shade800)),
                    const SizedBox(height: 4),
                    Text('Total Order Requirement: ${totalOrderQty}kg', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Allocated: ${currentSum}kg / ${totalOrderQty}kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      remainingQty == 0
                          ? 'Perfect Match!'
                          : (remainingQty > 0 ? '$remainingQty kg remaining' : '${remainingQty.abs()} kg over-allocated'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: remainingQty == 0
                            ? Colors.green
                            : (remainingQty > 0 ? Colors.orange : Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          const Text('Distribute to Grow Rooms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: activePlantRooms.length,
              itemBuilder: (context, idx) {
                final rName = activePlantRooms[idx];
                final survey = _findYieldSurvey(rName);
                final strain = survey.isNotEmpty ? survey['strain'] as String : 'Cup';
                final expected = survey.isNotEmpty ? (survey['expectedYield'] as double).toInt() : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rName.replaceAll('Room', 'Grow Room '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('$strain — Yield Survey: ${expected}kg expected', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 36,
                          child: TextFormField(
                            controller: _orderAllocControllers[rName]?['allocated'],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '0',
                              labelText: 'Allocate (kg)',
                              floatingLabelBehavior: FloatingLabelBehavior.never,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onChanged: (_) {
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _confirmManualOrderAllocation(plan),
              child: const Text('Confirm Manual Allocation', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmManualOrderAllocation(Map<String, dynamic> plan) async {
    final repo = MushroomsRepository();
    final type = plan['mushroomType'] ?? 'White';

    int totalAllocated = 0;
    _orderAllocControllers.forEach((roomName, controllers) {
      final val = int.tryParse(controllers['allocated']?.text.trim() ?? '') ?? 0;
      totalAllocated += val;
    });

    if (totalAllocated <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Please allocate at least some quantity to Grow Rooms.')),
      );
      return;
    }

    for (final roomName in _orderAllocControllers.keys) {
      final val = int.tryParse(_orderAllocControllers[roomName]?['allocated']?.text.trim() ?? '') ?? 0;
      if (val > 0) {
        final survey = _findYieldSurvey(roomName);
        final strain = survey.isNotEmpty ? survey['strain'] as String : 'Cup';

        final planMap = {
          'id': '${DateTime.now().millisecondsSinceEpoch}_$roomName',
          'roomName': roomName,
          'plant': widget.activePlant,
          'button': (strain == 'Button') ? val : 0,
          'medium': (strain == 'Cup') ? val : 0,
          'open': (strain == 'Flat') ? val : 0,
          'mushroomType': type,
          'sentAt': DateTime.now().toLocal().toString().substring(11, 16)
        };

        await repo.saveAllocatedRoomPlan(roomName, val.toDouble(), jsonEncode(planMap));
      }
    }

    setState(() {
      widget.pickingPlans.removeWhere((p) => p['id'] == plan['id']);
      _selectedOrderToAllocate = null;
    });

    _loadPlanningData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully distributed & allocated ${totalAllocated}kg of $type mushrooms to Grow Rooms!')),
    );
  }

  void _autoAllocateOrder(Map<String, dynamic> plan) async {
    final repo = MushroomsRepository();
    final type = plan['mushroomType'] ?? 'White';
    final buttonQty = plan['button'] ?? 0;
    final mediumQty = plan['medium'] ?? 0;
    final openQty = plan['open'] ?? 0;
    final totalOrderQty = buttonQty + mediumQty + openQty;

    final activePlantRooms = widget.localRooms.keys
        .where((k) => widget.localRooms[k]!['plant'] == widget.activePlant)
        .toList();

    int totalExpectedSurveyYield = 0;
    for (final rName in activePlantRooms) {
      final s = _findYieldSurvey(rName);
      if (s.isNotEmpty) {
        totalExpectedSurveyYield += (s['expectedYield'] as double).toInt();
      }
    }

    if (totalExpectedSurveyYield <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No expected yield survey reference data to auto-allocate.')),
      );
      return;
    }

    int remainingToAllocate = totalOrderQty;
    int successfullyAllocated = 0;

    for (int i = 0; i < activePlantRooms.length; i++) {
      final rName = activePlantRooms[i];
      final s = _findYieldSurvey(rName);
      if (s.isNotEmpty) {
        final expected = (s['expectedYield'] as double).toInt();
        int allocatedRoomVal = ((expected / totalExpectedSurveyYield) * totalOrderQty).round();
        if (i == activePlantRooms.length - 1) {
          allocatedRoomVal = remainingToAllocate;
        }

        if (allocatedRoomVal > 0) {
          allocatedRoomVal = allocatedRoomVal.clamp(0, remainingToAllocate);
          remainingToAllocate -= allocatedRoomVal;
          successfullyAllocated += allocatedRoomVal;

          final strain = s['strain'] as String;
          final planMap = {
            'id': '${DateTime.now().millisecondsSinceEpoch}_$rName',
            'roomName': rName,
            'plant': widget.activePlant,
            'button': (strain == 'Button') ? allocatedRoomVal : 0,
            'medium': (strain == 'Cup') ? allocatedRoomVal : 0,
            'open': (strain == 'Flat') ? allocatedRoomVal : 0,
            'mushroomType': type,
            'sentAt': DateTime.now().toLocal().toString().substring(11, 16)
          };

          await repo.saveAllocatedRoomPlan(rName, allocatedRoomVal.toDouble(), jsonEncode(planMap));
        }
      }
    }

    setState(() {
      widget.pickingPlans.removeWhere((p) => p['id'] == plan['id']);
      if (_selectedOrderToAllocate?['id'] == plan['id']) {
        _selectedOrderToAllocate = null;
      }
    });

    _loadPlanningData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Auto-allocated ${successfullyAllocated}kg of $type mushrooms to grow rooms proportionally!')),
    );
  }

  Widget _buildSubTabButton(String mode, String title, IconData icon) {
    final isActive = _subMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _subMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (widget.isDark ? FarmColors.forestGreen : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive && !widget.isDark
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? (widget.isDark ? Colors.white : FarmColors.forestGreenText) : Colors.grey),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? (widget.isDark ? Colors.white : FarmColors.forestGreenText) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanningView() {
    if (_isLoadingPlanning) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: _buildAllocationPanel(),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: _buildSchedulePanel(),
        ),
      ],
    );
  }

  Widget _buildAllocationPanel() {
    final activePlantRooms = widget.localRooms.keys
        .where((k) => widget.localRooms[k]!['plant'] == widget.activePlant)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Allocation Panel',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Distribute picking requests based on yield surveys',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: widget.isDark ? Colors.white10 : Colors.grey.shade100,
                  foregroundColor: widget.isDark ? Colors.white : Colors.black87,
                ),
                onPressed: _loadPlanningData,
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Yield Survey Reference (Surveyor Logs)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: FarmColors.forestGreenText),
          ),
          const SizedBox(height: 8),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white10 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade200),
            ),
            child: _yieldSurveys.isEmpty
                ? const Center(child: Text('No yield surveys recorded.', style: TextStyle(fontSize: 11, color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _yieldSurveys.length,
                    itemBuilder: (c, idx) {
                      final s = _yieldSurveys[idx];
                      final isCurrentPlant = _getPlantFromRoomName(s['roomName']) == widget.activePlant;
                      if (!isCurrentPlant) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s['roomName'].toString().replaceAll('Room', 'Grow Room'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              '${s['strain']} — Cycle ${s['cycle']}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: FarmColors.forestGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${s['expectedYield'].toInt()} kg expected',
                                style: const TextStyle(color: FarmColors.forestGreenText, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Input Manual Allocation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: activePlantRooms.length,
              itemBuilder: (c, idx) {
                final rName = activePlantRooms[idx];
                final survey = _findYieldSurvey(rName);
                final strain = survey.isNotEmpty ? survey['strain'] as String : 'Cup';
                final cycle = survey.isNotEmpty ? survey['cycle'] as int : 1;

                if (!_allocControllers.containsKey(rName)) {
                  _allocControllers[rName] = TextEditingController();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rName.replaceAll('Room', 'Grow Room'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              '$strain (Cycle $cycle)',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 36,
                          child: DropdownButtonFormField<String>(
                            value: _allocTypes[rName] ?? 'White',
                            items: const [
                              DropdownMenuItem(value: 'White', child: Text('White', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: 'Brown', child: Text('Brown', style: TextStyle(fontSize: 11))),
                            ],
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _allocTypes[rName] = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 36,
                          child: TextFormField(
                            controller: _allocControllers[rName],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '0',
                              labelText: 'Allocation (kg)',
                              floatingLabelBehavior: FloatingLabelBehavior.never,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _onConfirmAllocation,
              child: const Text('Confirm Allocation', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _onConfirmAllocation() async {
    final repo = MushroomsRepository();
    final db = AppDatabase();
    int totalAllocated = 0;

    for (final roomName in _allocControllers.keys) {
      final textVal = _allocControllers[roomName]?.text.trim() ?? '';
      final val = double.tryParse(textVal) ?? 0.0;
      if (val > 0) {
        totalAllocated += val.toInt();
      }
    }

    if (totalAllocated > 0) {
      final today = DateTime.now();
      final planId = 'PLAN_${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

      // 1. Upsert Harvest Plan for today
      await db.into(db.mushroomHarvestPlans).insertOnConflictUpdate(
        MushroomHarvestPlansCompanion.insert(
          id: planId,
          planDate: today,
          zoneId: d.Value(widget.activePlant),
          status: const d.Value('published'),
          totalTargetBoxes: d.Value(totalAllocated ~/ 4),
        ),
      );

      for (final roomName in _allocControllers.keys) {
        final textVal = _allocControllers[roomName]?.text.trim() ?? '';
        final val = double.tryParse(textVal) ?? 0.0;
        final cleanRoomName = roomName.toLowerCase().replaceAll(' ', '_');

        if (val > 0) {
          final survey = _findYieldSurvey(roomName);
          final strain = survey.isNotEmpty ? survey['strain'] as String : 'Cup';

          final planMap = {
            'id': '${DateTime.now().millisecondsSinceEpoch}_$roomName',
            'roomName': roomName,
            'plant': widget.activePlant,
            'button': (strain == 'Button') ? val.toInt() : 0,
            'medium': (strain == 'Cup') ? val.toInt() : 0,
            'open': (strain == 'Flat') ? val.toInt() : 0,
            'mushroomType': _allocTypes[roomName] ?? 'White',
            'sentAt': DateTime.now().toLocal().toString().substring(11, 16)
          };

          await repo.saveAllocatedRoomPlan(roomName, val, jsonEncode(planMap));

          // 2. Upsert Room Assignments
          final targetBoxes = (val.toInt() ~/ 4).clamp(1, 1000);
          await db.into(db.mushroomRoomAssignments).insertOnConflictUpdate(
            MushroomRoomAssignmentsCompanion.insert(
              id: '${planId}_$cleanRoomName',
              planId: planId,
              roomId: cleanRoomName,
              boxTarget: d.Value(targetBoxes),
              trolleyCount: d.Value((targetBoxes ~/ 50).clamp(1, 15)),
              teamAssignmentsJson: d.Value(jsonEncode([
                {
                  'teamColor': _allocTypes[roomName] ?? 'White',
                  'headcount': 6
                }
              ])),
              pickingInstructionsJson: d.Value(jsonEncode([strain])),
              notes: d.Value('Yield survey expected: $val kg'),
            ),
          );
        } else {
          await repo.clearRoomPlanByName(roomName);
          // Delete Room Assignment if allocation cleared
          await (db.delete(db.mushroomRoomAssignments)
                ..where((t) => t.id.equals('${planId}_$cleanRoomName')))
              .go();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully confirmed manual allocation of $totalAllocated kg and synchronized to SQLite!')),
      );
      try {
        final bloc = BlocProvider.of<MushroomsBloc>(context);
        bloc.add(LoadRoomsEvent());
      } catch (_) {}
      _loadPlanningData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter positive yield allocation numbers first.')),
      );
    }
  }

  Widget _buildSchedulePanel() {
    final allocatedRooms = widget.localRooms.keys
        .where((k) => widget.localRooms[k]!['plant'] == widget.activePlant &&
                      (widget.localRooms[k]!['targetYield'] ?? 0.0) > 0.0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Schedule Planning',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Assign pickers to rooms and shift time slots',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (allocatedRooms.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                  label: Text('Approve & Notify (${_scheduledAssignments.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.forestGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _onApproveSchedule,
                ),
            ],
          ),
          const Divider(height: 24),
          if (allocatedRooms.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No allocated rooms available for scheduling.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please allocate targets in the left panel first.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Pickers',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _employees.length,
                            itemBuilder: (c, idx) {
                              final emp = _employees[idx];
                              final name = emp['name'] as String;
                              final dept = emp['department']?.toString().toLowerCase() ?? '';
                              final isHarvestDept = dept.contains('harvest');
                              if (!isHarvestDept) return const SizedBox.shrink();

                              final shifts = _scheduledAssignments.values.where((v) => v == name).length;
                              final isOverloaded = shifts >= 2;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isOverloaded ? Colors.amber : Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '$shifts shifts assigned',
                                            style: const TextStyle(fontSize: 8, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 16),
                  Expanded(
                    child: Scrollbar(
                      controller: _ganttSchedHorizController,
                      thumbVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 1,
                      child: Scrollbar(
                        controller: _ganttSchedVertController,
                        thumbVisibility: true,
                        notificationPredicate: (notif) => notif.depth == 0,
                        child: SingleChildScrollView(
                          controller: _ganttSchedHorizController,
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _ganttSchedVertController,
                            child: Table(
                              defaultColumnWidth: const FixedColumnWidth(100),
                              border: TableBorder.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: widget.isDark ? Colors.white10 : Colors.grey.shade100),
                                  children: [
                                    const TableCell(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text('Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                    ..._timeSlots.map((slot) => TableCell(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(slot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        )),
                                  ],
                                ),
                                ...allocatedRooms.map((roomName) {
                                  return TableRow(
                                    children: [
                                      TableCell(
                                        verticalAlignment: TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            roomName.replaceAll('Room', 'Room '),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ),
                                      ..._timeSlots.map((slot) {
                                        final assignmentKey = '${roomName}_$slot';
                                        final pickerName = _scheduledAssignments[assignmentKey];
                                        final isAssigned = pickerName != null;

                                        return TableCell(
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            height: 42,
                                            child: isAssigned
                                                ? Container(
                                                    decoration: BoxDecoration(
                                                      color: FarmColors.forestGreen,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            pickerName,
                                                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _scheduledAssignments.remove(assignmentKey);
                                                            });
                                                          },
                                                          child: const Icon(Icons.close, size: 10, color: Colors.white70),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      side: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                    ),
                                                    onPressed: () => _showPickerAssignmentDialog(roomName, slot),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: const [
                                                        Icon(Icons.add, size: 10),
                                                        SizedBox(width: 2),
                                                        Text('Assign', style: TextStyle(fontSize: 8)),
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPickerAssignmentDialog(String roomName, String slot) {
    final pickers = _employees
        .where((e) => e['department']?.toString().toLowerCase().contains('harvest') ?? false)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Picker to ${roomName.replaceAll('Room', 'Grow Room')} at $slot'),
        content: SizedBox(
          width: 300,
          child: pickers.isEmpty
              ? const Text('No pickers found in registry.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pickers.length,
                  itemBuilder: (c, idx) {
                    final picker = pickers[idx];
                    final name = picker['name'] as String;
                    final shifts = _scheduledAssignments.values.where((v) => v == name).length;

                    return ListTile(
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Current workload: $shifts shifts', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        setState(() {
                          _scheduledAssignments['${roomName}_$slot'] = name;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _onApproveSchedule() async {
    if (_scheduledAssignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No schedule assignments to approve.')),
      );
      return;
    }

    final repo = MushroomsRepository();
    final db = AppDatabase();
    int count = 0;
    final now = DateTime.now();
    final planId = 'PLAN_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    for (final key in _scheduledAssignments.keys) {
      final parts = key.split('_');
      final roomName = parts[0];
      final slot = parts[1];
      final pickerName = _scheduledAssignments[key]!;

      final room = widget.localRooms[roomName];
      if (room == null) continue;
      final roomId = room['id'] as String;

      final timeParts = slot.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 8;
      final min = int.tryParse(timeParts[1]) ?? 0;
      final scheduledTime = DateTime(now.year, now.month, now.day, hour, min);

      await repo.addScheduledPickingJob(
        roomId: roomId,
        pickerName: pickerName,
        scheduledTime: scheduledTime,
        notes: 'Picking target allocated: ${room['targetYield']?.toInt() ?? 0} kg',
      );

      // Sync assignment to MushroomShifts database table
      final employee = _employees.firstWhere((e) => e['name'] == pickerName, orElse: () => {});
      final empId = employee['id']?.toString() ?? 'EMP_UNKNOWN';

      await db.into(db.mushroomShifts).insertOnConflictUpdate(
        MushroomShiftsCompanion.insert(
          id: 'SHIFT_${empId}_${slot.replaceAll(':', '')}_${DateTime.now().millisecondsSinceEpoch}',
          planId: planId,
          role: 'Picker',
          employeeId: empId,
          startTime: d.Value(scheduledTime),
          shedRoomListJson: d.Value(jsonEncode([roomName])),
        ),
      );

      await repo.sendChatMessage(
        sender: 'Mike (Site Manager)',
        contact: 'Growing Crew',
        text: 'ASSIGNMENT: $pickerName has been assigned to harvest ${roomName.replaceAll('Room', 'Grow Room')} at $slot.',
        role: 'Manager',
      );

      count++;
    }

    try {
      final bloc = BlocProvider.of<MushroomsBloc>(context);
      bloc.add(LoadRoomsEvent());
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully approved schedule and synchronized $count shifts to SQLite!')),
    );

    setState(() {
      _scheduledAssignments.clear();
    });
  }

  Widget _buildActiveRoomsTable(List<Map<String, dynamic>> activeRooms) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Grow Room')),
          DataColumn(label: Text('Cycle')),
          DataColumn(label: Text('Crew')),
          DataColumn(label: Text('Target (kg)')),
          DataColumn(label: Text('Harvested (kg)')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Safety')),
        ],
        rows: activeRooms.map((room) {
          final name = room['name'] as String;
          final crew = widget.roomCrews[name] ?? [];
          final isSolo = crew.length == 1;

          final targetVal = room['targetYield'] ?? 0.0;
          final pickedVal = room['pickedYield'] ?? 0.0;
          final done = targetVal > 0 && pickedVal >= targetVal;

          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (isSolo) {
                return widget.isDark
                    ? FarmColors.forestGreen.withOpacity(0.35)
                    : Colors.red.shade50;
              }
              return null;
            }),
            cells: [
              DataCell(Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(room['cycle'] ?? 'Cycle 1')),
              DataCell(Text(crew.isNotEmpty ? crew.join(', ') : 'Empty')),
              DataCell(Text('${targetVal.toInt()} kg')),
              DataCell(
                TextFormField(
                  initialValue: pickedVal.toString(),
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(contentPadding: EdgeInsets.zero),
                  onFieldSubmitted: (val) {
                    final input = double.tryParse(val) ?? 0.0;
                    widget.onPickedYieldUpdated(name, input);
                  },
                ),
              ),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color:
                          done ? Colors.green.shade100 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(done ? 'Completed' : 'Picking',
                      style: TextStyle(
                          color: done
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(
                Icon(
                  isSolo
                      ? Icons.warning_amber_rounded
                      : (crew.isEmpty
                          ? Icons.remove
                          : Icons.check_circle_outline),
                  color: isSolo
                      ? Colors.red
                      : (crew.isEmpty ? Colors.grey : Colors.green),
                ),
              )
            ],
          );
        }).toList(),
      ),
    );
  }

}

class _BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      // Top Left Corner
      ..moveTo(0, 20)
      ..lineTo(0, 0)
      ..lineTo(20, 0)
      // Top Right Corner
      ..moveTo(size.width - 20, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 20)
      // Bottom Right Corner
      ..moveTo(size.width, size.height - 20)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - 20, size.height)
      // Bottom Left Corner
      ..moveTo(20, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - 20);

    canvas.drawPath(path, paint);

    // Draw scanning laser
    final laserPaint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width, size.height / 2), laserPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
