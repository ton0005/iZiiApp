import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:izii_app/core/theme/izii_colors.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors
import '../widgets/plant_map_widget.dart';
import '../services/harvest_plan_service.dart';
import '../services/harvest_plan_excel_service.dart';
import 'create_harvest_plan_screen.dart';

class ReviewHarvestPlanScreen extends StatefulWidget {
  final bool isDark;
  final String userRole; // Manager, Supervisor, Picker
  final Map<String, Map<String, dynamic>> localRooms;
  final Map<String, List<String>> roomCrews;

  const ReviewHarvestPlanScreen({
    super.key,
    required this.isDark,
    this.userRole = 'Manager',
    required this.localRooms,
    required this.roomCrews,
  });

  @override
  State<ReviewHarvestPlanScreen> createState() => _ReviewHarvestPlanScreenState();
}

class _ReviewHarvestPlanScreenState extends State<ReviewHarvestPlanScreen> {
  final HarvestPlanService _planService = HarvestPlanService();

  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;
  int _selectedPlanIndex = 0;
  String _activePlant = 'M2';

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final plans = await _planService.getHarvestPlans();

    // If SQLite is empty, seed demo plan data
    if (plans.isEmpty) {
      await _planService.saveHarvestPlan(
        planId: 'PLAN_20260724',
        planDate: DateTime(2026, 7, 24),
        zoneId: 'M2',
        status: 'published',
        roomAssignments: [
          {'roomName': 'Room 3', 'flush': 1, 'boxTarget': 1000, 'trolleyCount': 16, 'teams': 'IVORY & PEARL', 'instructions': ['CLUMPS (WASH TROLLEYS)']},
          {'roomName': 'Room 24', 'flush': 2, 'boxTarget': 600, 'trolleyCount': 16, 'teams': 'PURPLE', 'instructions': ['55, 50, Soft??']},
          {'roomName': 'Room 26', 'flush': 2, 'boxTarget': 800, 'trolleyCount': 16, 'teams': 'SAPPHIRE', 'instructions': ['Check One Box']},
          {'roomName': 'Room 42', 'flush': 2, 'boxTarget': 1000, 'trolleyCount': 16, 'teams': 'RUBY', 'instructions': ['55, 30, Keep moving bigger one from T/A']},
          {'roomName': 'Room 50', 'flush': 1, 'boxTarget': 1400, 'trolleyCount': 16, 'teams': 'JADE & AMBER', 'instructions': ['MYCOSENSE INSTRUCTION: 6,1,7']},
          {'roomName': 'Room 51', 'flush': 1, 'boxTarget': 1200, 'trolleyCount': 16, 'teams': 'VENUS & LIME', 'instructions': ['MYCOSENSE INSTRUCTION: 6,1,7']},
          {'roomName': 'Room 52', 'flush': 1, 'boxTarget': 600, 'trolleyCount': 8, 'teams': 'BLACK', 'instructions': ['MYCOSENSE INSTRUCTION: 5,7']},
        ],
      );
      final reloaded = await _planService.getHarvestPlans();
      setState(() {
        _plans = reloaded;
        _isLoading = false;
      });
    } else {
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    }
  }

  bool get _isManagerOrSupervisor {
    final role = widget.userRole.toLowerCase();
    return role.contains('manager') || role.contains('supervisor') || role.contains('admin');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
      case 'approved':
        return FarmColors.forestGreen;
      case 'rejected':
        return IZiiColors.error;
      case 'draft':
      default:
        return Colors.orange;
    }
  }

  Map<String, Color> _getHighlightedRoomsForPlan(Map<String, dynamic>? plan) {
    final highlights = <String, Color>{};
    if (plan == null) return highlights;

    final assignments = plan['assignments'] as List? ?? [];
    for (final a in assignments) {
      final rName = (a['roomName'] ?? a['roomId'] ?? '').toString();
      if (rName.isNotEmpty) {
        final status = (plan['status'] ?? 'draft').toString();
        highlights[rName] = _getStatusColor(status);
      }
    }

    return highlights;
  }

  Future<void> _approvePlan(String planId) async {
    await _planService.updatePlanStatus(planId, 'published');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan Approved & Published successfully!'),
        backgroundColor: FarmColors.forestGreen,
      ),
    );
    _loadPlans();
  }

  Future<void> _rejectPlan(String planId) async {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Harvest Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this harvest plan:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: IZiiColors.error),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              await _planService.updatePlanStatus(planId, 'rejected', rejectionReason: reason);
              if (ctx.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Harvest Plan rejected.'),
                  backgroundColor: IZiiColors.error,
                ),
              );
              _loadPlans();
            },
            child: const Text('Reject Plan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _editPlan(Map<String, dynamic> planData) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateHarvestPlanScreen(
          isDark: widget.isDark,
          localRooms: widget.localRooms,
          roomCrews: widget.roomCrews,
          initialPlanData: planData,
        ),
      ),
    );

    if (updated == true) {
      _loadPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final pageBg = isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground;
    final cardBg = isDark ? IZiiColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final activePlan = _plans.isNotEmpty ? _plans[_selectedPlanIndex.clamp(0, _plans.length - 1)] : null;
    final highlightedRooms = _getHighlightedRoomsForPlan(activePlan);
    final assignments = activePlan != null ? (activePlan['assignments'] as List) : [];

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REVIEW HARVEST PLANS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              'Manager approval, rejection, and floor map inspection',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          if (_isManagerOrSupervisor)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateHarvestPlanScreen(
                      isDark: isDark,
                      localRooms: widget.localRooms,
                      roomCrews: widget.roomCrews,
                    ),
                  ),
                );
                if (created == true) _loadPlans();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Create Harvest Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane: Plans List Selector
            SizedBox(
              width: 320,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HARVEST PLANS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _plans.length,
                        itemBuilder: (c, idx) {
                          final p = _plans[idx];
                          final isSelected = idx == _selectedPlanIndex;
                          final status = (p['status'] ?? 'draft').toString();
                          final statusColor = _getStatusColor(status);
                          final planDate = p['planDate'] is DateTime
                              ? p['planDate'] as DateTime
                              : DateTime.parse(p['planDate']);

                          return InkWell(
                            onTap: () => setState(() => _selectedPlanIndex = idx),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? FarmColors.forestGreen.withOpacity(0.12)
                                    : (isDark ? Colors.white10 : Colors.grey.shade50),
                                border: Border.all(
                                    color: isSelected ? FarmColors.forestGreen : Colors.transparent),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        p['id'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date: ${planDate.day}/${planDate.month}/${planDate.year} · ${p['totalTargetBoxes']} boxes',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
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

            // Right Pane: Active Plan Floor Map Highlight & Details
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: activePlan == null
                    ? const Center(child: Text('No Harvest Plans available.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Details & Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'PLAN: ${activePlan['id']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(activePlan['status']).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          (activePlan['status'] as String).toUpperCase(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: _getStatusColor(activePlan['status'])),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Total Boxes: ${activePlan['totalTargetBoxes']} · Created by: ${activePlan['createdBy']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              if (_isManagerOrSupervisor)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.file_download_rounded, size: 14, color: FarmColors.forestGreen),
                                      label: const Text('Export Excel', style: TextStyle(color: FarmColors.forestGreenText)),
                                      onPressed: () async {
                                        final file = await HarvestPlanExcelService().exportPlanToCsvFile(activePlan);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Exported to Excel CSV: ${file.path}'),
                                              backgroundColor: FarmColors.forestGreen,
                                              action: SnackBarAction(
                                                label: 'Share/Open',
                                                textColor: Colors.white,
                                                onPressed: () {
                                                  Share.shareXFiles([XFile(file.path)], text: 'Harvesting Plan CSV');
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit_rounded, size: 14),
                                      label: const Text('Edit Plan'),
                                      onPressed: () => _editPlan(activePlan),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: IZiiColors.error,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.close_rounded, size: 14),
                                      label: const Text('Reject'),
                                      onPressed: () => _rejectPlan(activePlan['id']),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: FarmColors.forestGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.check_circle_rounded, size: 14),
                                      label: const Text('Approve & Publish'),
                                      onPressed: () => _approvePlan(activePlan['id']),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Highlighted PlantMapWidget
                          SizedBox(
                            height: 240,
                            child: PlantMapWidget(
                              isDark: isDark,
                              activePlant: _activePlant,
                              localRooms: widget.localRooms,
                              roomCrews: widget.roomCrews,
                              selectedRoomNames: highlightedRooms.keys.toSet(),
                              highlightedRooms: highlightedRooms,
                              onRoomSelected: (rName) {},
                              onPlantChanged: (p) => setState(() => _activePlant = p),
                              showHeader: true,
                              showLegend: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Room Assignments Table
                          Text(
                            'ROOM HARVEST ASSIGNMENTS (${assignments.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: FarmColors.forestGreenText),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('ROOM#', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('BOX TARGET', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('TROLLEY', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('ASSIGNED TEAMS', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('INSTRUCTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: assignments.map((a) {
                                    final teamsList = a['teams'] as List? ?? [];
                                    final teamStr = teamsList.isNotEmpty
                                        ? teamsList.map((t) => t['teamColor'] ?? t.toString()).join(' & ')
                                        : '—';
                                    final instrs = a['instructions'] as List? ?? [];
                                    final instrStr = instrs.isNotEmpty ? instrs.join(', ') : '—';

                                    return DataRow(cells: [
                                      DataCell(Text(a['roomName'] as String, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text('${a['boxTarget']} boxes')),
                                      DataCell(Text('${a['trolleyCount']}')),
                                      DataCell(Text(teamStr, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(instrStr, style: TextStyle(color: instrStr.contains('MYCOSENSE') ? Colors.purple : Colors.black87))),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
