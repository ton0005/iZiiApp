import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors and shared definitions

class GrowingTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final String activePlant;
  final String roomFilter;
  final String? selectedRoomName;
  final Function(String) onPlantChanged;
  final Function(String) onRoomFilterChanged;
  final Function(String?) onRoomSelected;
  final Function(String roomName, String jobType, String assignee, String notes, double? rate, double? area, String? wateringPlan, double? wateringVol) onJobCreated;
  final Function(String roomName, int jobId, bool done) onJobStatusChanged;
  final Function(String roomName, String viewMode) onSwitchToTasks;

  const GrowingTabScreen({
    super.key,
    required this.isDark,
    required this.localRooms,
    required this.activePlant,
    required this.roomFilter,
    required this.selectedRoomName,
    required this.onPlantChanged,
    required this.onRoomFilterChanged,
    required this.onRoomSelected,
    required this.onJobCreated,
    required this.onJobStatusChanged,
    required this.onSwitchToTasks,
  });

  @override
  State<GrowingTabScreen> createState() => _GrowingTabScreenState();
}

class _GrowingTabScreenState extends State<GrowingTabScreen> {
  @override
  Widget build(BuildContext context) {
    // KPI Data
    final totalCount = widget.localRooms.values
        .where((r) => r['plant'] == widget.activePlant)
        .length;
    final activeCount = widget.localRooms.values
        .where((r) => r['plant'] == widget.activePlant && r['status'] == 'active')
        .length;
    final idleCount = widget.localRooms.values
        .where((r) => r['plant'] == widget.activePlant && r['status'] == 'idle')
        .length;

    // Filters
    final roomsFiltered = widget.localRooms.values.where((r) {
      if (r['plant'] != widget.activePlant) return false;
      if (widget.roomFilter == 'active') return r['status'] == 'active';
      if (widget.roomFilter == 'idle') return r['status'] == 'idle';
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Control buttons Row
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
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.forestGreen,
                  foregroundColor: Colors.white,
                ),
                label: const Text('Thêm Job Mới'),
                onPressed: () => _showNewJobDialog(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          // KPIs Grid Row
          Row(
            children: [
              _buildKpiCard(
                  'TỔNG SỐ PHÒNG', '$totalCount', 'Phòng ${widget.activePlant}', false),
              const SizedBox(width: 12),
              _buildKpiCard('ĐANG HOẠT ĐỘNG', '$activeCount',
                  'Có chu kỳ hoạt động', false),
              const SizedBox(width: 12),
              _buildKpiCard('ĐANG TRỐNG (IDLE)', '$idleCount',
                  'Có thể bắt đầu vụ mới', false),
              const SizedBox(width: 12),
              _buildKpiCard('SỰ CỐ AN TOÀN', '0', 'Bình thường', false),
            ],
          ),
          const SizedBox(height: 16),
          // Split Pane Layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Rooms grid
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: FarmColors.borderLight)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFilterBtn('Tất cả', 'all'),
                            _buildFilterBtn('Chạy', 'active'),
                            _buildFilterBtn('Trống', 'idle'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: roomsFiltered.length,
                          itemBuilder: (context, idx) {
                            final room = roomsFiltered[idx];
                            final name = room['name'] as String;
                            final isSel = widget.selectedRoomName == name;
                            final stage = room['current_stage'] as String;

                            return ListTile(
                              selected: isSel,
                              selectedColor: FarmColors.forestGreenText,
                              selectedTileColor:
                                  FarmColors.forestGreenLight.withOpacity(0.4),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              trailing: _buildStageBadge(stage),
                              onTap: () => widget.onRoomSelected(name),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right: Details Panel
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: Border.all(color: FarmColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: widget.selectedRoomName != null
                        ? _buildRoomDetailsPanel(widget.isDark, widget.selectedRoomName!)
                        : const Center(
                            child: Text('Hãy chọn một phòng để xem chi tiết.')),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String label, String value) {
    final active = widget.roomFilter == value;
    return InkWell(
      onTap: () => widget.onRoomFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? FarmColors.forestGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStageBadge(String stage) {
    Color bg = Colors.grey;
    Color fg = Colors.white;
    String name = stage.toUpperCase();
    if (stage == 'filling') {
      bg = Colors.blue;
      name = 'FILLING';
    }
    if (stage == 'airing') {
      bg = Colors.purple;
      name = 'AIRING';
    }
    if (stage == 'watering') {
      bg = Colors.cyan;
      name = 'TƯỚI NƯỚC';
    }
    if (stage == 'prochloraz') {
      bg = Colors.red;
      name = 'PHUN NẤM';
    }
    if (stage == 'packuptree') {
      bg = Colors.orange;
      name = 'DỌN RỄ';
    }
    if (stage == 'cleanroom') {
      bg = Colors.green;
      name = 'DỌN PHÒNG';
    }
    if (stage == 'idle') {
      bg = Colors.grey.shade400;
      name = 'TRỐNG';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(name,
          style:
              TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRoomDetailsPanel(bool isDark, String roomName) {
    final room = widget.localRooms[roomName]!;
    final List<Map<String, dynamic>> jobs =
        List<Map<String, dynamic>>.from(room['jobs']);
    final doneCount = jobs.where((j) => j['status'] == 'done').length;
    final progress = jobs.isNotEmpty ? doneCount / jobs.length : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phòng $roomName',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Plant ${room['plant']} · Diện tích: ${room['area']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  icon:
                      const Icon(Icons.timeline, color: Colors.grey, size: 16),
                  label: const Text('Timeline',
                      style: TextStyle(color: Colors.grey)),
                  onPressed: () => widget.onSwitchToTasks(roomName, 'gantt'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.view_kanban,
                      color: Colors.grey, size: 16),
                  label: const Text('Kanban',
                      style: TextStyle(color: Colors.grey)),
                  onPressed: () => widget.onSwitchToTasks(roomName, 'kanban'),
                )
              ],
            )
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetaInfoBox('CHU KỲ', room['cycle']),
            _buildMetaInfoBox(
                'NGÀY TRONG CHU KỲ', room['day_in_cycle'].toString()),
            _buildMetaInfoBox(
                'GIAI ĐOẠN', room['current_stage'].toString().toUpperCase()),
            _buildMetaInfoBox('TIẾN ĐỘ CHU KỲ', '${(progress * 100).toInt()}%'),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor:
                const AlwaysStoppedAnimation<Color>(FarmColors.forestGreen),
          ),
        ),
        const SizedBox(height: 24),
        const Text('DANH SÁCH PIPELINE CÔNG VIỆC',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, idx) {
              final job = jobs[idx];
              final done = job['status'] == 'done';
              final jobId = job['id'] as int;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF2E2E2E) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: done,
                          onChanged: (val) {
                            widget.onJobStatusChanged(roomName, jobId, val ?? false);
                          },
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job['name'],
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null)),
                            Text(job['notes'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(job['assignee'],
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    )
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildMetaInfoBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildKpiCard(
      String label, String value, String subText, bool isDanger) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDanger ? const Color(0xFFFEE2E2) : Colors.white,
          border: Border.all(
              color: isDanger
                  ? Colors.redAccent.withOpacity(0.5)
                  : FarmColors.borderLight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDanger ? Colors.red : Colors.black87)),
            const SizedBox(height: 4),
            Text(subText,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Dialog: Add New Job
  void _showNewJobDialog(BuildContext context) {
    String jobType = 'filling';
    String roomSelected = widget.localRooms.keys
        .firstWhere((k) => widget.localRooms[k]!['plant'] == widget.activePlant);
    String assignee = 'Minh T.';
    String notes = '';

    // Watering fields
    String wateringPlan = '2side';
    double wateringVol = 2.0;

    // Prochloraz fields
    double rate = 1.3;
    double area = 112.0;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final chemicalTotal = (rate * area).toStringAsFixed(1);
            return AlertDialog(
              title: const Text('Tạo Job Trồng Trọt Mới',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Phòng'),
                        value: roomSelected,
                        items: widget.localRooms.keys
                            .where(
                                (k) => widget.localRooms[k]!['plant'] == widget.activePlant)
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text('Phòng $r')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => roomSelected = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: 'Loại công việc (Job Type)'),
                        value: jobType,
                        items: const [
                          DropdownMenuItem(
                              value: 'filling',
                              child: Text('Filling (Nạp giá thể)')),
                          DropdownMenuItem(
                              value: 'airing',
                              child: Text('Airing (Plastic floor wet)')),
                          DropdownMenuItem(
                              value: 'watering',
                              child: Text('Watering (Tưới nước)')),
                          DropdownMenuItem(
                              value: 'prochloraz',
                              child: Text('Prochloraz (Phun nấm)')),
                          DropdownMenuItem(
                              value: 'packuptree',
                              child: Text('Pack Up Tree (Dọn rễ)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => jobType = val);
                        },
                      ),
                      if (jobType == 'watering') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                              labelText: 'Phương án tưới'),
                          value: wateringPlan,
                          items: const [
                            DropdownMenuItem(
                                value: '2side',
                                child: Text('Tưới 2 bên giường (2 Side)')),
                            DropdownMenuItem(
                                value: '1side',
                                child: Text('Tưới 1 bên giường (1 Side)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => wateringPlan = val);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Lượng nước (L/m²)'),
                          initialValue: wateringVol.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setDialogState(() =>
                                wateringVol = double.tryParse(val) ?? 2.0);
                          },
                        )
                      ],
                      if (jobType == 'prochloraz') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'Tỷ lệ hóa chất (g/m²)'),
                                initialValue: rate.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setDialogState(
                                      () => rate = double.tryParse(val) ?? 1.3);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'Diện tích (m²)'),
                                initialValue: area.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setDialogState(() =>
                                      area = double.tryParse(val) ?? 112.0);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: FarmColors.forestGreenLight,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            'Tổng hóa chất cần chuẩn bị: $chemicalTotal g',
                            style: const TextStyle(
                                color: FarmColors.forestGreenText,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        )
                      ],
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration:
                            const InputDecoration(labelText: 'Người phụ trách'),
                        value: assignee,
                        items: const [
                          DropdownMenuItem(
                              value: 'Minh T.', child: Text('Minh T.')),
                          DropdownMenuItem(
                              value: 'Lan N.', child: Text('Lan N.')),
                          DropdownMenuItem(
                              value: 'Hùng V.', child: Text('Hùng V.')),
                          DropdownMenuItem(
                              value: 'Phúc D.', child: Text('Phúc D.')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => assignee = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Ghi chú thêm'),
                        onChanged: (val) => notes = val,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen),
                  onPressed: () {
                    widget.onJobCreated(
                      roomSelected,
                      jobType,
                      assignee,
                      notes,
                      jobType == 'prochloraz' ? rate : null,
                      jobType == 'prochloraz' ? area : null,
                      jobType == 'watering' ? wateringPlan : null,
                      jobType == 'watering' ? wateringVol : null,
                    );
                    Navigator.pop(dialogCtx);
                  },
                  child:
                      const Text('Tạo', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }
}
