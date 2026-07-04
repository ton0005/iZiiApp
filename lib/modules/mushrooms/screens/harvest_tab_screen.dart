import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class HarvestTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final Map<String, List<String>> roomCrews;
  final List<Map<String, dynamic>> pickingPlans;
  final Function(String, String) onCheckIn;
  final Function(String, String) onCheckOut;
  final Function(String, double) onPickedYieldUpdated;
  final Function(String) onSafetyContact;

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
  });

  @override
  State<HarvestTabScreen> createState() => _HarvestTabScreenState();
}

class _HarvestTabScreenState extends State<HarvestTabScreen> {
  final TextEditingController _empIdController = TextEditingController();
  late String _roomSelected;

  @override
  void initState() {
    super.initState();
    _roomSelected = widget.localRooms.keys.first;
  }

  @override
  void dispose() {
    _empIdController.dispose();
    super.dispose();
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
        children: [
          // Solo Warning banner
          if (soloRoom != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                          'Warning: Worker performing Solo Picking at Room $soloRoom (${soloWorker})!',
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
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
            child: Row(
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
                      color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
            ),
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
          const Text('Room Check-in / Check-out',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _empIdController,
            decoration: const InputDecoration(
                labelText: 'Employee ID',
                hintText: 'EMP003',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Work Room'),
            value: _roomSelected,
            items: widget.localRooms.keys
                .map((r) =>
                    DropdownMenuItem(value: r, child: Text('Room $r')))
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
                    widget.onCheckOut(code, _roomSelected);
                  },
                  child: const Text('Check Out'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPickingPlansCard(bool isDark) {
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
          const Text('Picking Request from Cool Room',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Expanded(
            child: widget.pickingPlans.isEmpty
                ? const Center(
                    child: Text('No active picking requests.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.builder(
                    itemCount: widget.pickingPlans.length,
                    itemBuilder: (context, idx) {
                      final plan = widget.pickingPlans[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Room ${plan['roomName']} (Plant ${plan['plant']})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                                'Mushrooms: Button: ${plan['button']}kg, Cup: ${plan['medium']}kg, Flat: ${plan['open']}kg',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
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

  Widget _buildActiveRoomsTable(List<Map<String, dynamic>> activeRooms) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Room')),
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
              if (isSolo) return Colors.red.shade50;
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
