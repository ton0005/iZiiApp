import 'dart:async';
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
  final Function(
    String roomName,
    String jobType,
    String assignee,
    String notes,
    double? rate,
    double? area,
    String? wateringPlan,
    double? wateringVol, {
    int? timeLimit,
    double? coLevel,
    double? co2Level,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) onJobCreated;
  final Function(String roomName, dynamic jobId, bool done) onJobStatusChanged;
  final Function(String roomName, String viewMode) onSwitchToTasks;
  final Function(String roomName, String wateringPlan, String prochlorazRate) onStartCycle;

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
    required this.onStartCycle,
  });

  @override
  State<GrowingTabScreen> createState() => _GrowingTabScreenState();
}

class _GrowingTabScreenState extends State<GrowingTabScreen> {
  bool _isAscending = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

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

    int parseRoomNumber(String name) {
      final exp = RegExp(r'\d+');
      final match = exp.firstMatch(name);
      if (match != null) {
        return int.tryParse(match.group(0)!) ?? 0;
      }
      return 0;
    }

    roomsFiltered.sort((a, b) {
      final nameA = a['name'] as String? ?? '';
      final nameB = b['name'] as String? ?? '';
      final numA = parseRoomNumber(nameA);
      final numB = parseRoomNumber(nameB);
      if (_isAscending) {
        return numA.compareTo(numB);
      } else {
        return numB.compareTo(numA);
      }
    });

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
                label: const Text('Add New Job'),
                onPressed: () => _showNewJobDialog(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          // KPIs Grid Row
          Row(
            children: [
              _buildKpiCard(
                  'TOTAL ROOMS', '$totalCount', 'Room ${widget.activePlant}', false),
              const SizedBox(width: 12),
              _buildKpiCard('ACTIVE ROOMS', '$activeCount',
                  'In active cycle', false),
              const SizedBox(width: 12),
              _buildKpiCard('IDLE ROOMS', '$idleCount',
                  'Ready for new cycle', false),
              const SizedBox(width: 12),
              _buildKpiCard('SAFETY INCIDENTS', '0', 'Normal', false),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: FarmColors.borderLight)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildFilterBtn('All', 'all'),
                                const SizedBox(width: 4),
                                _buildFilterBtn('Active', 'active'),
                                const SizedBox(width: 4),
                                _buildFilterBtn('Idle', 'idle'),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _isAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 18,
                                color: FarmColors.forestGreen,
                              ),
                              tooltip: _isAscending ? 'Sort: Ascending' : 'Sort: Descending',
                              onPressed: () {
                                setState(() {
                                  _isAscending = !_isAscending;
                                });
                              },
                            ),
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
                            child: Text('Select a room to view details.')),
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
      name = 'WATERING';
    }
    if (stage == 'prochloraz') {
      bg = Colors.red;
      name = 'PROCHLORAZ';
    }
    if (stage == 'packuptree') {
      bg = Colors.orange;
      name = 'PACK UP TREE';
    }
    if (stage == 'cleanroom') {
      bg = Colors.green;
      name = 'CLEAN ROOM';
    }
    if (stage == 'idle') {
      bg = Colors.grey.shade400;
      name = 'IDLE';
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
                Text('Room $roomName',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Plant ${room['plant']} · Area: ${room['area']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            room['status'] == 'idle'
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Start New Cycle'),
                    onPressed: () => _showStartCycleDialog(context, roomName),
                  )
                : Row(
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
            _buildMetaInfoBox('CYCLE', room['cycle']),
            _buildMetaInfoBox(
                'DAY IN CYCLE', room['day_in_cycle'].toString()),
            _buildMetaInfoBox(
                'STAGE', room['current_stage'].toString().toUpperCase()),
            _buildMetaInfoBox('CYCLE PROGRESS', '${(progress * 100).toInt()}%'),
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
        const Text('PIPELINE JOB CHECKLIST',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, idx) {
              final job = jobs[idx];
              final done = job['status'] == 'done';
              final jobId = job['id'];

              String getTimerString() {
                if (job['status'] == 'completed' || job['status'] == 'done') {
                  return 'Completed';
                }
                if (job['started_at'] == null) {
                  return 'Pending';
                }
                final startedAt = DateTime.parse(job['started_at'] as String);
                final limitMins = job['time_limit_minutes'] as int;
                final deadline = startedAt.add(Duration(minutes: limitMins));
                final remaining = deadline.difference(DateTime.now());
                if (remaining.isNegative) {
                  return 'EXPIRED (ALARM)';
                }
                final mins = remaining.inMinutes;
                final secs = remaining.inSeconds % 60;
                return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
              }

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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (job['is_solo_job'] == true || job['job_type'] == 'alone_worker' || job['job_type'] == 'special_solo') ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (job['co_level'] != null) ...[
                                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber.shade700),
                                    const SizedBox(width: 4),
                                    Text('CO: ${job['co_level']} ppm', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(width: 12),
                                  ],
                                  if (job['co2_level'] != null) ...[
                                    Icon(Icons.cloud_queue_rounded, size: 12, color: Colors.blue.shade700),
                                    const SizedBox(width: 4),
                                    Text('CO₂: ${job['co2_level']} ppm', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(width: 12),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (job['check_in_time'] != null) ...[
                                    Text('Check In: ${DateTime.parse(job['check_in_time'] as String).toLocal().toString().substring(11, 16)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    const SizedBox(width: 12),
                                  ],
                                  if (job['check_out_time'] != null) ...[
                                    Text('Check Out: ${DateTime.parse(job['check_out_time'] as String).toLocal().toString().substring(11, 16)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Builder(
                                builder: (context) {
                                  final timerStr = getTimerString();
                                  final isExpired = timerStr.contains('EXPIRED');
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isExpired ? Colors.red.withOpacity(0.1) : FarmColors.forestGreenLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Time Remaining: $timerStr',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isExpired ? Colors.red : FarmColors.forestGreenText,
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ],
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

    // Alone worker fields
    int timeLimit = 45;
    double coLevel = 0.0;
    double co2Level = 0.0;
    DateTime checkInTime = DateTime.now();
    DateTime? checkOutTime;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final chemicalTotal = (rate * area).toStringAsFixed(1);
            return AlertDialog(
              title: const Text('Create New Growing Job',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Room'),
                        value: roomSelected,
                        items: widget.localRooms.keys
                            .where(
                                (k) => widget.localRooms[k]!['plant'] == widget.activePlant)
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text('Room $r')))
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
                            labelText: 'Job Type'),
                        value: jobType,
                        items: const [
                          DropdownMenuItem(
                              value: 'filling',
                              child: Text('Filling (Substrate Filling)')),
                          DropdownMenuItem(
                              value: 'airing',
                              child: Text('Airing (Plastic floor wet)')),
                          DropdownMenuItem(
                              value: 'watering',
                              child: Text('Watering')),
                          DropdownMenuItem(
                              value: 'prochloraz',
                              child: Text('Prochloraz (Chemical spray)')),
                          DropdownMenuItem(
                              value: 'packuptree',
                              child: Text('Pack Up Tree (Root cleanup)')),
                          DropdownMenuItem(
                              value: 'alone_worker',
                              child: Text('Alone Worker (Working alone)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => jobType = val);
                        },
                      ),
                      if (jobType == 'watering') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                              labelText: 'Watering Plan'),
                          value: wateringPlan,
                          items: const [
                            DropdownMenuItem(
                                value: '2side',
                                child: Text('2 Side Watering')),
                            DropdownMenuItem(
                                value: '1side',
                                child: Text('1 Side Watering')),
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
                              labelText: 'Water Volume (L/m²)'),
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
                                    labelText: 'Chemical Rate (g/m²)'),
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
                                    labelText: 'Area (m²)'),
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
                            'Total chemical to prepare: $chemicalTotal g',
                            style: const TextStyle(
                                color: FarmColors.forestGreenText,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        )
                      ],
                      if (jobType == 'alone_worker') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Time Limit (minutes)'),
                          initialValue: timeLimit.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            setDialogState(() =>
                                timeLimit = int.tryParse(val) ?? 45);
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'CO Level (ppm)'),
                                initialValue: coLevel.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setDialogState(() =>
                                      coLevel = double.tryParse(val) ?? 0.0);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'CO2 Level (ppm)'),
                                initialValue: co2Level.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  setDialogState(() =>
                                      co2Level = double.tryParse(val) ?? 0.0);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(checkInTime),
                                  );
                                  if (picked != null) {
                                    final now = DateTime.now();
                                    setDialogState(() {
                                      checkInTime = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        picked.hour,
                                        picked.minute,
                                      );
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                      labelText: 'Check In Time'),
                                  child: Text(
                                    '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(checkOutTime ?? DateTime.now().add(const Duration(minutes: 45))),
                                  );
                                  if (picked != null) {
                                    final now = DateTime.now();
                                    setDialogState(() {
                                      checkOutTime = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        picked.hour,
                                        picked.minute,
                                      );
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                      labelText: 'Check Out Time'),
                                  child: Text(
                                    checkOutTime != null
                                        ? '${checkOutTime!.hour.toString().padLeft(2, '0')}:${checkOutTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Not set',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration:
                            const InputDecoration(labelText: 'Assignee'),
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
                            const InputDecoration(labelText: 'Additional Notes'),
                        onChanged: (val) => notes = val,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
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
                      timeLimit: jobType == 'alone_worker' ? timeLimit : null,
                      coLevel: jobType == 'alone_worker' ? coLevel : null,
                      co2Level: jobType == 'alone_worker' ? co2Level : null,
                      checkInTime: jobType == 'alone_worker' ? checkInTime : null,
                      checkOutTime: jobType == 'alone_worker' ? checkOutTime : null,
                    );
                    Navigator.pop(dialogCtx);
                  },
                  child:
                      const Text('Create', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showStartCycleDialog(BuildContext context, String roomName) {
    String wateringPlan = '2 Side 2L/m2';
    String prochlorazRate = '1.3g/m2';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Start New Cycle - Room $roomName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Default Watering Plan'),
              initialValue: wateringPlan,
              onChanged: (val) => wateringPlan = val,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Default Prochloraz Spray Rate'),
              initialValue: prochlorazRate,
              onChanged: (val) => prochlorazRate = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
            onPressed: () {
              widget.onStartCycle(roomName, wateringPlan, prochlorazRate);
              Navigator.pop(ctx);
            },
            child: const Text('Start', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
