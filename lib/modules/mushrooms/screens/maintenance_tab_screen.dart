import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class MaintenanceTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final List<Map<String, dynamic>> maintenanceJobs;
  final Function(String title, String plant, String room, String assignee,
      String priority, String notes) onCreateMaintenanceJob;
  final Function(String jobId, String newStatus) onUpdateMaintStatus;

  const MaintenanceTabScreen({
    super.key,
    required this.isDark,
    required this.localRooms,
    required this.maintenanceJobs,
    required this.onCreateMaintenanceJob,
    required this.onUpdateMaintStatus,
  });

  @override
  State<MaintenanceTabScreen> createState() => _MaintenanceTabScreenState();
}

class _MaintenanceTabScreenState extends State<MaintenanceTabScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _plantSelected = 'M2';
  late String _roomSelected;
  String _priority = 'normal';
  String _assignee = 'Nam T.';

  @override
  void initState() {
    super.initState();
    _roomSelected = 'Room 33';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Create Ticket Form
          SizedBox(
            width: 340,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildCreateForm(widget.isDark),
            ),
          ),
          const SizedBox(width: 16),
          // Right: Maintenance Board
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
                    child: Text('Active Maintenance Tickets',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.maintenanceJobs.length,
                      itemBuilder: (context, idx) {
                        final mnt = widget.maintenanceJobs[idx];
                        final status = mnt['status'] as String;
                        final priority = mnt['priority'] as String;

                        Color priorityBg = priority == 'high' ? Colors.red.shade100 : Colors.amber.shade100;
                        Color priorityText = priority == 'high' ? Colors.red : Colors.orange;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                            border: Border.all(color: FarmColors.borderLight),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mnt['title'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Plant ${mnt['plant']} · ${mnt['room'].toString().replaceAll('Room', 'Grow Room')}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (mnt['notes'] != null && mnt['notes'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Notes: ${mnt['notes']}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: priorityBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          priority.toUpperCase(),
                                          style: TextStyle(
                                            color: priorityText,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildMaintStatusBadge(status),
                                    ],
                                  ),
                                  if (status != 'done') ...[
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        onPressed: () {
                                          String nextStatus = 'todo';
                                          if (status == 'todo') {
                                            nextStatus = 'inprog';
                                          } else if (status == 'inprog') {
                                            nextStatus = 'done';
                                          }
                                          widget.onUpdateMaintStatus(mnt['id'], nextStatus);
                                        },
                                        child: Text(
                                          status == 'todo' ? 'Start' : 'Complete',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ],
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
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMaintStatusBadge(String status) {
    if (status == 'done') {
      return const Text('Resolved',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
    if (status == 'inprog') {
      return const Text('In Progress',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold));
    }
    return const Text('Pending', style: TextStyle(color: Colors.grey));
  }

  Widget _buildCreateForm(bool isDark) {
    return StatefulBuilder(
      builder: (context, setMaintState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Maintenance Ticket',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Device / Issue Description',
                  hintText: 'e.g. Fix jammed exhaust fan'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Area / Location'),
                    value: _plantSelected,
                    items: const [
                      DropdownMenuItem(value: 'M1', child: Text('Plant M1')),
                      DropdownMenuItem(value: 'M2', child: Text('Plant M2')),
                      DropdownMenuItem(
                          value: 'CoolRoom', child: Text('Cold Room')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setMaintState(() {
                          _plantSelected = val;
                          if (val == 'CoolRoom') {
                            _roomSelected = 'CR1';
                          } else {
                            _roomSelected = widget.localRooms.keys.firstWhere(
                                (k) => widget.localRooms[k]!['plant'] == val);
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Grow Room'),
                    value: _roomSelected,
                    items: _plantSelected == 'CoolRoom'
                        ? const <DropdownMenuItem<String>>[
                            DropdownMenuItem(value: 'CR1', child: Text('CR 1')),
                            DropdownMenuItem(value: 'CR2', child: Text('CR 2'))
                          ]
                        : widget.localRooms.keys
                            .where((k) =>
                                widget.localRooms[k]!['plant'] ==
                                _plantSelected)
                            .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.replaceAll('Room', 'Grow Room'))))
                            .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setMaintState(() => _roomSelected = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Assignee'),
              value: _assignee,
              items: const [
                DropdownMenuItem(
                    value: 'Nam T.', child: Text('Nam T. (Maintenance)')),
                DropdownMenuItem(
                    value: 'Lợi P.', child: Text('Lợi P. (Maintenance)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setMaintState(() => _assignee = val);
                }
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Priority'),
              value: _priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('High')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setMaintState(() => _priority = val);
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                  labelText: 'Detailed Error Description'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.maintenanceOrange,
                    foregroundColor: Colors.white),
                onPressed: () {
                  final title = _titleController.text.trim();
                  final notes = _notesController.text.trim();
                  widget.onCreateMaintenanceJob(title, _plantSelected,
                      _roomSelected, _assignee, _priority, notes);
                  _titleController.clear();
                  _notesController.clear();
                },
                child: const Text('Create Ticket'),
              ),
            )
          ],
        );
      },
    );
  }
}
