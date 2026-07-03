import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class MaintenanceTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final List<Map<String, dynamic>> maintenanceJobs;
  final Function(String title, String plant, String room, String assignee, String priority, String notes) onCreateMaintenanceJob;
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
                    child: Text('Lệnh bảo trì đang thực hiện',
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
                        return ListTile(
                          title: Text(mnt['title'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Vị trí: Plant ${mnt['plant']} · Phòng ${mnt['room']} · Ghi chú: ${mnt['notes']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: mnt['priority'] == 'high'
                                      ? Colors.red.shade100
                                      : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    mnt['priority'].toString().toUpperCase(),
                                    style: TextStyle(
                                        color: mnt['priority'] == 'high'
                                            ? Colors.red
                                            : Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              _buildMaintStatusBadge(status),
                              const SizedBox(width: 10),
                              if (status != 'done')
                                ElevatedButton(
                                  onPressed: () {
                                    String nextStatus = 'todo';
                                    if (status == 'todo') {
                                      nextStatus = 'inprog';
                                    } else if (status == 'inprog') {
                                      nextStatus = 'done';
                                    }
                                    widget.onUpdateMaintStatus(mnt['id'], nextStatus);
                                  },
                                  child: Text(status == 'todo'
                                      ? 'Bắt đầu'
                                      : 'Hoàn tất'),
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
          )
        ],
      ),
    );
  }

  Widget _buildMaintStatusBadge(String status) {
    if (status == 'done') {
      return const Text('Đã sửa xong',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
    if (status == 'inprog') {
      return const Text('Đang tiến hành',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold));
    }
    return const Text('Chờ xử lý', style: TextStyle(color: Colors.grey));
  }

  Widget _buildCreateForm(bool isDark) {
    return StatefulBuilder(
      builder: (context, setMaintState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tạo lệnh bảo trì thiết bị',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Tên thiết bị / Sự cố',
                  hintText: 'VD: Sửa quạt gió bị kẹt'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Khu vực'),
                    value: _plantSelected,
                    items: const [
                      DropdownMenuItem(value: 'M1', child: Text('Plant M1')),
                      DropdownMenuItem(value: 'M2', child: Text('Plant M2')),
                      DropdownMenuItem(
                          value: 'CoolRoom', child: Text('Kho Lạnh')),
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
                    decoration: const InputDecoration(labelText: 'Phòng'),
                    value: _roomSelected,
                    items: _plantSelected == 'CoolRoom'
                        ? const [
                            DropdownMenuItem(value: 'CR1', child: Text('CR 1')),
                            DropdownMenuItem(value: 'CR2', child: Text('CR 2'))
                          ]
                        : widget.localRooms.keys
                            .where((k) =>
                                widget.localRooms[k]!['plant'] == _plantSelected)
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text('Room $r')))
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
              decoration: const InputDecoration(labelText: 'Người thực hiện'),
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
              decoration: const InputDecoration(labelText: 'Độ ưu tiên'),
              value: _priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Thấp (Low)')),
                DropdownMenuItem(
                    value: 'normal', child: Text('Bình thường (Normal)')),
                DropdownMenuItem(value: 'high', child: Text('Cao (High)')),
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
              decoration:
                  const InputDecoration(labelText: 'Mô tả chi tiết lỗi'),
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
                  widget.onCreateMaintenanceJob(title, _plantSelected, _roomSelected, _assignee, _priority, notes);
                  _titleController.clear();
                  _notesController.clear();
                },
                child: const Text('Tạo Lệnh Bảo Trì'),
              ),
            )
          ],
        );
      },
    );
  }
}
