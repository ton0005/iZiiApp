import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class TasksTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final String? tasksSelectedRoomName;
  final String tasksViewMode;
  final Function(String) onRoomSelected;
  final Function(String) onViewModeChanged;
  final Function(String, dynamic, String) onJobStatusChanged;

  const TasksTabScreen({
    super.key,
    required this.isDark,
    required this.localRooms,
    required this.tasksSelectedRoomName,
    required this.tasksViewMode,
    required this.onRoomSelected,
    required this.onViewModeChanged,
    required this.onJobStatusChanged,
  });

  @override
  State<TasksTabScreen> createState() => _TasksTabScreenState();
}

class _TasksTabScreenState extends State<TasksTabScreen> {
  @override
  Widget build(BuildContext context) {
    final activeRoomName = widget.tasksSelectedRoomName ??
        (widget.localRooms.isNotEmpty ? widget.localRooms.keys.first : null);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Select room header & View switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('View tasks for Grow Room: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (activeRoomName != null)
                    DropdownButton<String>(
                      value: activeRoomName,
                      items: widget.localRooms.keys
                          .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.replaceAll('Room', 'Grow Room'))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          widget.onRoomSelected(val);
                        }
                      },
                    ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.tasksViewMode == 'kanban'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => widget.onViewModeChanged('kanban'),
                    child: const Text('Kanban'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.tasksViewMode == 'gantt'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => widget.onViewModeChanged('gantt'),
                    child: const Text('Gantt Timeline'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // View Mode renderer
          Expanded(
            child: activeRoomName != null
                ? (widget.tasksViewMode == 'kanban'
                    ? _buildKanbanView(widget.isDark, activeRoomName)
                    : _buildGanttView(widget.isDark, activeRoomName))
                : const Center(child: Text('No rooms available.')),
          )
        ],
      ),
    );
  }

  Widget _buildKanbanView(bool isDark, String roomName) {
    final room = widget.localRooms[roomName]!;
    final List<Map<String, dynamic>> jobs =
        List<Map<String, dynamic>>.from(room['jobs']);

    final todo = jobs.where((j) => j['status'] == 'todo').toList();
    final inprog = jobs.where((j) => j['status'] == 'inprog').toList();
    final review = jobs.where((j) => j['status'] == 'review').toList();
    final done = jobs.where((j) => j['status'] == 'done').toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKanbanCol('To Do', todo, Colors.grey, roomName),
        const SizedBox(width: 12),
        _buildKanbanCol('In Progress', inprog, Colors.blue, roomName),
        const SizedBox(width: 12),
        _buildKanbanCol('Review', review, Colors.orange, roomName),
        const SizedBox(width: 12),
        _buildKanbanCol('Done', done, Colors.green, roomName),
      ],
    );
  }

  Widget _buildKanbanCol(String title, List<Map<String, dynamic>> list,
      Color labelColor, String roomName) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FarmColors.borderLight),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: labelColor, width: 3))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${list.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: list.length,
                itemBuilder: (context, idx) {
                  final job = list[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(job['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(job['assignee']),
                      onTap: () => _showTaskDetailDialog(job, roomName),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showTaskDetailDialog(Map<String, dynamic> job, String roomName) {
    final status = job['status'] as String;
    final jobId = job['id'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(job['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Assignee: ${job['assignee']}'),
            const SizedBox(height: 6),
            Text('Notes: ${job['notes'] ?? ''}'),
          ],
        ),
        actions: [
          if (status != 'done')
            ElevatedButton(
              onPressed: () {
                String nextStatus = 'todo';
                if (status == 'todo') {
                  nextStatus = 'inprog';
                } else if (status == 'inprog') {
                  nextStatus = 'review';
                } else if (status == 'review') {
                  nextStatus = 'done';
                }
                widget.onJobStatusChanged(roomName, jobId, nextStatus);
                Navigator.pop(ctx);
              },
              child: const Text('Move to Next Stage'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Widget _buildGanttView(bool isDark, String roomName) {
    final room = widget.localRooms[roomName]!;
    final List<Map<String, dynamic>> jobs =
        List<Map<String, dynamic>>.from(room['jobs']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Colors.grey),
                SizedBox(width: 8),
                Text('Gantt Timeline Chart (Day 1 to 18)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            // Timeline numbers row
            Row(
              children: [
                const SizedBox(
                    width: 140,
                    child: Text('Jobs',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey))),
                Expanded(
                  child: Row(
                    children: List.generate(
                        18,
                        (idx) => Expanded(
                              child: Text('D${idx + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            )),
                  ),
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, idx) {
                  final job = jobs[idx];
                  final status = job['status'] as String;

                  final startDay = idx * 2;
                  final duration = 3;

                  Color barColor = Colors.grey.shade300;
                  if (status == 'done') {
                    barColor = const Color(0xFFC0DD97);
                  } else if (status == 'inprog') {
                    barColor = const Color(0xFF85B7EB);
                  } else if (status == 'review') {
                    barColor = const Color(0xFFFAC775);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Row(
                            children: [
                              Icon(job['icon'] as IconData? ?? Icons.task_alt,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(job['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              // Horizontal grid markers
                              Row(
                                children: List.generate(
                                    18,
                                    (idx) => Expanded(
                                          child: Container(
                                            height: 26,
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors
                                                            .grey.shade200))),
                                          ),
                                        )),
                              ),
                              // Positioned bar
                              LayoutBuilder(
                                builder: (context, box) {
                                  final totalWidth = box.maxWidth;
                                  final leftOffset =
                                      (startDay / 18) * totalWidth;
                                  final barWidth = (duration / 18) * totalWidth;

                                  return Positioned(
                                    left: leftOffset,
                                    width: barWidth,
                                    top: 3,
                                    height: 20,
                                    child: InkWell(
                                      onTap: () =>
                                          _showTaskDetailDialog(job, roomName),
                                      child: Container(
                                        decoration: BoxDecoration(
                                            color: barColor,
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        alignment: Alignment.center,
                                        child: Text(job['name'],
                                            style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87)),
                                      ),
                                    ),
                                  );
                                },
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
