import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors and shared definitions
import '../bloc/mushrooms_bloc.dart';
import '../repository.dart';

class GrowingTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final Map<String, List<String>> roomCrews;
  final String activePlant;
  final String roomFilter;
  final String? selectedRoomName;
  final List<Map<String, dynamic>> employees;
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
  final Function(String roomName, String wateringPlan, String prochlorazRate)
      onStartCycle;
  final Function(String roomName) onResetRoom;

  const GrowingTabScreen({
    super.key,
    required this.isDark,
    required this.localRooms,
    required this.roomCrews,
    required this.activePlant,
    required this.roomFilter,
    required this.selectedRoomName,
    required this.employees,
    required this.onPlantChanged,
    required this.onRoomFilterChanged,
    required this.onRoomSelected,
    required this.onJobCreated,
    required this.onJobStatusChanged,
    required this.onSwitchToTasks,
    required this.onStartCycle,
    required this.onResetRoom,
  });

  @override
  State<GrowingTabScreen> createState() => _GrowingTabScreenState();
}

class _GrowingTabScreenState extends State<GrowingTabScreen> {
  // Layout representation grids
  static const List<String?> m2TopRow = [
    'Room 33',
    'Room 34',
    'Room 35',
    'Room 36',
    'Room 37',
    'Room 38',
    'Room 39',
    'Room 40',
    'Room 41',
    'Room 42',
    'Room 43',
    'Room 44',
    'corridor',
    'Room 45',
    'Room 46',
    'Room 47',
    'Room 48',
    'Room 49',
    'Room 50',
    'Room 51',
    'Room 52',
    'Room 52A'
  ];

  static const List<String?> m2BottomRow = [
    'Room 66',
    'Room 65',
    'Room 64',
    'Room 63',
    'Room 62',
    'Room 61',
    'Room 60',
    'Room 59',
    'Room 58',
    null,
    null,
    null,
    'corridor',
    null,
    null,
    null,
    null,
    'Room 57',
    'Room 56',
    'Room 55',
    'Room 54',
    'Room 53'
  ];

  static const List<String?> m1TopRow = [
    'Room 1',
    'Room 2',
    'Room 3',
    'Room 4',
    'Room 5',
    'Room 6',
    'Room 6A',
    'Room 6B',
    null,
    null,
    'corridor',
    'Room 7',
    'Room 8',
    'Room 9',
    'Room 10',
    'Room 11',
    'Room 12',
    'Room 13',
    'Room 14',
    null
  ];

  static const List<String?> m1BottomRow = [
    'Room 32',
    'Room 31',
    'Room 30',
    'Room 29',
    'Room 28',
    'Room 27',
    'Room 26',
    'Room 25',
    'Room 24',
    'Room 23',
    'corridor',
    'Room 22A',
    'Room 22',
    'Room 21',
    'Room 20',
    'Room 19',
    'Room 18',
    'Room 17',
    'Room 16',
    'Room 15'
  ];

  bool _isAscending = true;
  Timer? _countdownTimer;
  bool _isMapMaximized = false;
  final ScrollController _horizontalScrollController = ScrollController();

  bool _isAlarmDialogOpen = false;
  Timer? _alarmAudioTimer;
  DateTime? _snoozeUntil;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        try {
          context.read<MushroomsBloc>().add(CheckAlarmsEvent());
        } catch (_) {}
        _checkAlarms();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _alarmAudioTimer?.cancel();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getTimedOutRooms() {
    final list = <Map<String, dynamic>>[];
    for (final room in widget.localRooms.values) {
      final List<Map<String, dynamic>> jobs = room['jobs'] != null
          ? List<Map<String, dynamic>>.from(room['jobs'])
          : [];
      final activeSoloJob = jobs.firstWhere(
        (j) =>
            j['job_type'] == 'alone_worker' &&
            (j['status'] == 'in_progress' || j['status'] == 'inprog'),
        orElse: () => {},
      );
      if (activeSoloJob.isNotEmpty) {
        final startedAtStr =
            activeSoloJob['started_at'] ?? activeSoloJob['scheduled_at'];
        if (startedAtStr != null) {
          final startedAt = DateTime.parse(startedAtStr.toString());
          final limitMins = (activeSoloJob['time_limit_minutes'] ?? 45) as int;
          final deadline = startedAt.add(Duration(minutes: limitMins));
          if (DateTime.now().isAfter(deadline)) {
            list.add({
              'roomName': room['name'],
              'roomId': room['id'],
              'job': activeSoloJob,
            });
          }
        }
      }
    }
    return list;
  }

  void _checkAlarms() {
    final timedOut = _getTimedOutRooms();
    for (final t in timedOut) {
      final rName = t['roomName'] as String?;
      if (rName != null && widget.localRooms.containsKey(rName)) {
        widget.localRooms[rName]!['current_stage'] = 'alone_timeout';
      }
    }
    if (timedOut.isNotEmpty) {
      if (_snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!)) {
        _alarmAudioTimer?.cancel();
        _alarmAudioTimer = null;
        return;
      }

      if (_alarmAudioTimer == null) {
        HapticFeedback.vibrate();
        SystemSound.play(SystemSoundType.alert);
        _alarmAudioTimer =
            Timer.periodic(const Duration(milliseconds: 1500), (timer) {
          HapticFeedback.vibrate();
          SystemSound.play(SystemSoundType.alert);
        });
      }

      if (!_isAlarmDialogOpen) {
        _isAlarmDialogOpen = true;
        _showSirenAlarmDialog(timedOut);
      }
    } else {
      _alarmAudioTimer?.cancel();
      _alarmAudioTimer = null;
      _snoozeUntil = null;
    }
  }

  void _showSirenAlarmDialog(List<Map<String, dynamic>> timedOutRooms) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
              widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 64,
          ),
          title: const Text(
            '🚨 ALARM: ALONE WORKER TIMEOUT',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Alone working time limit has expired! Please check the employee immediately.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: timedOutRooms.map((room) {
                    final job = room['job'];
                    final roomName = room['roomName'] as String;
                    final assignee = job['assignee'] ?? 'Unknown Worker';
                    final limit = job['time_limit_minutes'] ?? 45;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            roomName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          Text(
                            'Employee: $assignee (Limit: ${limit}m)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.snooze, color: Colors.orange),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isAlarmDialogOpen = false;
                    setState(() {
                      _snoozeUntil =
                          DateTime.now().add(const Duration(minutes: 5));
                    });
                    _alarmAudioTimer?.cancel();
                    _alarmAudioTimer = null;
                  },
                  label: const Text(
                    'SNOOZE 5 MINS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isAlarmDialogOpen = false;
                    setState(() {
                      // Grace period of 10 seconds to allow the database update to sync
                      _snoozeUntil =
                          DateTime.now().add(const Duration(seconds: 10));
                    });
                    _alarmAudioTimer?.cancel();
                    _alarmAudioTimer = null;
                    try {
                      context
                          .read<MushroomsBloc>()
                          .add(DismissActiveAlarmsEvent());
                    } catch (_) {}
                  },
                  label: const Text(
                    'CONFIRM SAFETY',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ).then((_) => _isAlarmDialogOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    // KPI Data
    final plantRooms = widget.localRooms.values
        .where((r) => r['plant'] == widget.activePlant)
        .toList();
    final totalCount = plantRooms.length;
    final activeCount = plantRooms.where((r) => r['status'] == 'active').length;
    final idleCount = plantRooms.where((r) => r['status'] == 'idle').length;
    final harvestCount = plantRooms.where((r) {
      final stage = (r['current_stage'] ?? '').toString().toLowerCase();
      return stage == 'harvest' || stage == 'harvesting' || stage == 'picking';
    }).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          (() {
            final timedOut = _getTimedOutRooms();
            if (timedOut.isEmpty) return const SizedBox.shrink();
            final isSnoozed =
                _snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!);

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSnoozed ? Colors.orange.shade700 : Colors.red.shade600,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: (isSnoozed ? Colors.orange : Colors.red)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                      isSnoozed
                          ? Icons.snooze_rounded
                          : Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSnoozed
                              ? '⏸️ ALARM SNOOZED'
                              : '🚨 SIREN ALARM WARNING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          isSnoozed
                              ? '${_snoozeUntil!.difference(DateTime.now()).inSeconds} seconds remaining to check rooms: ${timedOut.map((r) => r['roomName']).join(', ')}'
                              : 'Alone worker timeout in rooms: ${timedOut.map((r) => '${r['roomName']} (${r['job']['assignee']})').join(', ')}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isSnoozed
                          ? Colors.orange.shade800
                          : Colors.red.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        // Grace period of 10 seconds to allow the database update to sync
                        _snoozeUntil =
                            DateTime.now().add(const Duration(seconds: 10));
                      });
                      _alarmAudioTimer?.cancel();
                      _alarmAudioTimer = null;
                      try {
                        context
                            .read<MushroomsBloc>()
                            .add(DismissActiveAlarmsEvent());
                      } catch (_) {}
                    },
                    label: const Text(
                      'CONFIRM SAFETY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          })(),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Wrap(
                spacing: 10,
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
              _buildKpiCard('TOTAL ROOMS', '$totalCount',
                  'Room ${widget.activePlant}', false),
              const SizedBox(width: 12),
              _buildKpiCard('ACTIVE CYCLE', '$activeCount', 'Growing', false),
              const SizedBox(width: 12),
              _buildKpiCard('IDLE ROOMS', '$idleCount', 'Ready to Seed', false),
              const SizedBox(width: 12),
              _buildKpiCard(
                  'PENDING HARVEST', '$harvestCount', 'Ready to Pick', false),
            ],
          ),
          const SizedBox(height: 16),
          // Split Pane Layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Visual Floor Map (Expanded)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      border: Border.all(color: FarmColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildFloorMap(),
                  ),
                ),
                if (!_isMapMaximized) ...[
                  const SizedBox(width: 16),
                  // Right: Details Panel (Fixed width 400)
                  Container(
                    width: 400,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      border: Border.all(color: FarmColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: widget.selectedRoomName != null
                        ? _buildRoomDetailsPanel(
                            widget.isDark, widget.selectedRoomName!)
                        : const Center(
                            child: Text(
                              'Select a room from the floor map to view details.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFloorMap() {
    final topRow = widget.activePlant == 'M2' ? m2TopRow : m1TopRow;
    final bottomRow = widget.activePlant == 'M2' ? m2BottomRow : m1BottomRow;
    final int columnCount = topRow.length;

    // Calculate width of each column (max of top cell width and bottom cell width)
    final List<double> columnWidths = List.generate(columnCount, (i) {
      final topName = topRow[i];
      final bottomName = bottomRow[i];

      final topWidth = _getRoomBaseWidth(topName);
      final bottomWidth = _getRoomBaseWidth(bottomName);

      return topWidth > bottomWidth ? topWidth : bottomWidth;
    });

    // Total width is sum of each column's width + 12px horizontal margin (6px left, 6px right)
    final double totalCorridorWidth =
        columnWidths.fold(0.0, (sum, w) => sum + w + 12.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & Filter Status summary
        _buildFloorMapHeader(),
        // Scrollable physical layout
        Expanded(
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 10, bottom: 24),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top Line of Rooms
                    Row(
                      children: List.generate(columnCount, (i) {
                        return _buildCell(topRow[i], columnWidths[i], true);
                      }),
                    ),
                    const SizedBox(height: 12),
                    // Central Walkway Corridor (Running horizontally through the whole plant)
                    _buildCentralCorridor(totalCorridorWidth),
                    const SizedBox(height: 12),
                    // Bottom Line of Rooms
                    Row(
                      children: List.generate(columnCount, (i) {
                        return _buildCell(bottomRow[i], columnWidths[i], false);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Stage color Legend at the bottom
        _buildLegend(),
      ],
    );
  }

  Widget _buildFloorMapHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_rounded,
                  color: FarmColors.forestGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Plant ${widget.activePlant} Floor Map Layout',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterBtn('All', 'all'),
              const SizedBox(width: 4),
              _buildFilterBtn('Active', 'active'),
              const SizedBox(width: 4),
              _buildFilterBtn('Idle', 'idle'),
              const SizedBox(width: 12),
              const SizedBox(
                height: 20,
                child: VerticalDivider(width: 1, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isMapMaximized
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: FarmColors.forestGreen,
                  size: 20,
                ),
                tooltip:
                    _isMapMaximized ? 'Exit Full Screen' : 'Full Screen Map',
                onPressed: () {
                  setState(() {
                    _isMapMaximized = !_isMapMaximized;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCentralCorridor(double corridorWidth) {
    return Container(
      width: corridorWidth,
      height: 28,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF222222) : Colors.grey.shade200,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed logistics center line using CustomPaint
          CustomPaint(
            size: Size(corridorWidth, 2),
            painter: DashedLinePainter(
              color: Colors.amber.withOpacity(0.5),
            ),
          ),
          // Logistics walkway text label
          Positioned(
            left: 20,
            child: Text(
              'MAIN LOGISTICS TRANSPORT CORRIDOR',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: widget.isDark ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
          Positioned(
            right: 20,
            child: Text(
              'MAIN LOGISTICS TRANSPORT CORRIDOR',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: widget.isDark ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String? roomName, double colW, bool isTopLine) {
    if (roomName == null) {
      // Blank layout space
      return Container(
        width: colW,
        height: 115,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.transparent),
        ),
      );
    }

    if (roomName == 'corridor') {
      // Vertical MID corridor separating the line segments
      return Container(
        width: colW,
        height: 115,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          border: Border.all(color: FarmColors.borderStrong, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            'MID WALKWAY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white24 : Colors.black26,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }

    // Room Lookup
    final room = widget.localRooms[roomName];
    if (room == null) return const SizedBox.shrink();

    // Check filter matching
    final isFilterMatch = widget.roomFilter == 'all' ||
        (widget.roomFilter == 'active' && room['status'] == 'active') ||
        (widget.roomFilter == 'idle' && room['status'] == 'idle');

    final double opacity = isFilterMatch ? 1.0 : 0.15;
    final isSelected = widget.selectedRoomName == roomName;
    final stage = (room['current_stage'] ?? 'idle') as String;

    final bool stageIsAlone = stage.toLowerCase() == 'alone_worker';
    final bool stageIsTimeout = stage.toLowerCase() == 'alone_timeout';

    // Check if there is an active alone worker in this room
    final List<Map<String, dynamic>> jobs = room['jobs'] != null
        ? List<Map<String, dynamic>>.from(room['jobs'])
        : [];
    final activeSoloJob = jobs.firstWhere(
      (j) =>
          j['job_type'] == 'alone_worker' &&
          (j['status'] == 'in_progress' || j['status'] == 'inprog'),
      orElse: () => {},
    );

    bool isAloneWorker =
        activeSoloJob.isNotEmpty || stageIsAlone || stageIsTimeout;
    bool isSoloTimedOut = stageIsTimeout;
    String displayStage = stage;

    if (activeSoloJob.isNotEmpty) {
      displayStage = 'alone_worker';
      final startedAtStr =
          activeSoloJob['started_at'] ?? activeSoloJob['scheduled_at'];
      if (startedAtStr != null) {
        final startedAt = DateTime.parse(startedAtStr.toString());
        final limitMins = (activeSoloJob['time_limit_minutes'] ?? 45) as int;
        final deadline = startedAt.add(Duration(minutes: limitMins));
        if (DateTime.now().isAfter(deadline)) {
          isSoloTimedOut = true;
          displayStage = 'alone_timeout';
        }
      }
    } else if (stageIsAlone || stageIsTimeout) {
      displayStage = stageIsTimeout ? 'alone_timeout' : 'alone_worker';
    }

    Color stageColor;
    if (isSoloTimedOut) {
      stageColor = Colors.red;
    } else if (isAloneWorker) {
      stageColor = Colors.orange;
    } else {
      stageColor = _getStageColor(stage);
    }

    // Pickers Checked-In
    final crew = widget.roomCrews[roomName] ?? [];
    final hasCrew = crew.isNotEmpty;

    final double roomWidth = _isSmallRoom(roomName) ? 48.0 : 96.0;

    return Container(
      width: colW,
      height: 115,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: roomWidth,
          height: 115,
          child: InkWell(
            onTap: isFilterMatch ? () => widget.onRoomSelected(roomName) : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSoloTimedOut
                    ? (widget.isDark
                        ? Colors.red.withOpacity(0.15)
                        : Colors.red.shade50)
                    : (isAloneWorker
                        ? (widget.isDark
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.orange.shade50)
                        : (isSelected
                            ? (widget.isDark
                                ? const Color(0xFF2A2A2A)
                                : Colors.amber.shade50)
                            : (widget.isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white))),
                border: Border.all(
                  color: isSoloTimedOut
                      ? Colors.red
                      : (isAloneWorker
                          ? Colors.orange
                          : (isSelected
                              ? FarmColors.forestGreen
                              : FarmColors.borderLight)),
                  width:
                      (isSelected || isSoloTimedOut || isAloneWorker) ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: (isSelected || isSoloTimedOut || isAloneWorker)
                    ? [
                        BoxShadow(
                            color: (isSoloTimedOut
                                    ? Colors.red
                                    : (isAloneWorker
                                        ? Colors.orange
                                        : FarmColors.forestGreen))
                                .withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top section: Room number & select state indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          roomName.replaceAll('Room ', ''),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: FarmColors.forestGreen, size: 12),
                    ],
                  ),
                  const Spacer(),

                  // Real-time Pickers Count Badge
                  if (hasCrew)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_alt_rounded,
                              color: Colors.white, size: 8),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${crew.length}${roomWidth < 60 ? 'p' : ' pickers'}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 7),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bottom section: Stage Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(0.15),
                      border: Border.all(color: stageColor, width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      displayStage.toUpperCase().replaceAll('_', ' '),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: roomWidth < 60 ? 6 : 8,
                        fontWeight: FontWeight.bold,
                        color: stageColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isSmallRoom(String roomName) {
    final cleanName = roomName.replaceAll('Room ', '');
    const smalls = {
      '6A',
      '6B',
      '12',
      '13',
      '14',
      '15',
      '22A',
      '40',
      '41',
      '46',
      '47',
      '52',
      '52A',
      '55',
      '56',
      '57'
    };
    return smalls.contains(cleanName);
  }

  double _getRoomBaseWidth(String? name) {
    if (name == null) return 0.0;
    if (name == 'corridor') return 60.0;
    return _isSmallRoom(name) ? 48.0 : 96.0;
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white10 : Colors.grey.shade50,
        border: const Border(top: BorderSide(color: FarmColors.borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'STAGE LEGEND:',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('Filling', const Color(0xFFF59E0B)),
                _buildLegendItem('Airing', const Color(0xFF06B6D4)),
                _buildLegendItem('Watering', const Color(0xFF3B82F6)),
                _buildLegendItem('Prochloraz', const Color(0xFF8B5CF6)),
                _buildLegendItem('Harvest', const Color(0xFFEF4444)),
                _buildLegendItem('Clean room', const Color(0xFF10B981)),
                _buildLegendItem('Idle', const Color(0xFF6B7280)),
                _buildLegendItem('Alone Worker', Colors.orange),
                _buildLegendItem('Alone Timeout', Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _getStageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'filling':
        return const Color(0xFFF59E0B); // Amber
      case 'airing':
        return const Color(0xFF06B6D4); // Cyan
      case 'watering':
        return const Color(0xFF3B82F6); // Blue
      case 'prochloraz':
        return const Color(0xFF8B5CF6); // Purple
      case 'clean room':
      case 'clean':
        return const Color(0xFF10B981); // Emerald Green
      case 'picking':
      case 'harvesting':
      case 'harvest':
        return const Color(0xFFEF4444); // Red/Rose
      case 'alone_worker':
        return Colors.orange;
      case 'alone_timeout':
        return Colors.red;
      case 'idle':
      default:
        return const Color(0xFF6B7280); // Grey
    }
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
                Text(roomName.replaceAll('Room', 'Grow Room'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Plant ${room['plant']} · Area: ${room['area']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            room['status'] == 'idle'
                ? Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FarmColors.forestGreen,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Start New Cycle'),
                        onPressed: () =>
                            _showStartCycleDialog(context, roomName),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Reset Room',
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        onPressed: () =>
                            _showResetRoomConfirmDialog(context, roomName),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.view_kanban,
                            color: Colors.grey, size: 16),
                        label: const Text('Kanban',
                            style: TextStyle(color: Colors.grey)),
                        onPressed: () =>
                            widget.onSwitchToTasks(roomName, 'kanban'),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh,
                            color: Colors.red, size: 16),
                        label: const Text('Reset',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () =>
                            _showResetRoomConfirmDialog(context, roomName),
                      ),
                    ],
                  )
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetaInfoBox('CYCLE', room['cycle']),
            _buildMetaInfoBox('DAY IN CYCLE', room['day_in_cycle'].toString()),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: done,
                            onChanged: (val) {
                              widget.onJobStatusChanged(
                                  roomName, jobId, val ?? false);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
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
                                if (job['is_solo_job'] == true ||
                                    job['job_type'] == 'alone_worker' ||
                                    job['job_type'] == 'special_solo') ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (job['co_level'] != null) ...[
                                        Icon(Icons.warning_amber_rounded,
                                            size: 12, color: Colors.amber.shade700),
                                        const SizedBox(width: 4),
                                        Text('CO: ${job['co_level']} ppm',
                                            style: const TextStyle(
                                                fontSize: 11, color: Colors.grey)),
                                        const SizedBox(width: 12),
                                      ],
                                      if (job['co2_level'] != null) ...[
                                        Icon(Icons.cloud_queue_rounded,
                                            size: 12, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text('CO₂: ${job['co2_level']} ppm',
                                            style: const TextStyle(
                                                fontSize: 11, color: Colors.grey)),
                                        const SizedBox(width: 12),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (job['check_in_time'] != null) ...[
                                        Text(
                                            'Check In: ${DateTime.parse(job['check_in_time'] as String).toLocal().toString().substring(11, 16)}',
                                            style: const TextStyle(
                                                fontSize: 10, color: Colors.grey)),
                                        const SizedBox(width: 12),
                                      ],
                                      if (job['check_out_time'] != null) ...[
                                        Text(
                                            'Check Out: ${DateTime.parse(job['check_out_time'] as String).toLocal().toString().substring(11, 16)}',
                                            style: const TextStyle(
                                                fontSize: 10, color: Colors.grey)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Builder(builder: (context) {
                                    final timerStr = getTimerString();
                                    final isExpired = timerStr.contains('EXPIRED');
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? Colors.red.withOpacity(0.1)
                                            : FarmColors.forestGreenLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Time Remaining: $timerStr',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isExpired
                                              ? Colors.red
                                              : FarmColors.forestGreenText,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
    final growingEmployees = widget.employees
        .where((e) => e['department']?.toString().toLowerCase() == 'growing')
        .toList();
    String jobType = 'filling';
    String roomSelected = (widget.selectedRoomName != null &&
            widget.localRooms.containsKey(widget.selectedRoomName))
        ? widget.selectedRoomName!
        : widget.localRooms.keys.firstWhere(
            (k) => widget.localRooms[k]!['plant'] == widget.activePlant);
    String assignee = growingEmployees.isNotEmpty
        ? (growingEmployees.first['name'] as String)
        : 'Minh T.';
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
                        decoration:
                            const InputDecoration(labelText: 'GrowRoom'),
                        value: roomSelected,
                        items: widget.localRooms.keys
                            .where((k) =>
                                widget.localRooms[k]!['plant'] ==
                                widget.activePlant)
                            .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.replaceAll('Room', 'Grow Room'))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => roomSelected = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration:
                            const InputDecoration(labelText: 'Job Type'),
                        value: jobType,
                        items: const [
                          DropdownMenuItem(
                              value: 'filling',
                              child: Text('Filling (Substrate Filling)')),
                          DropdownMenuItem(
                              value: 'airing',
                              child: Text('Airing (Plastic floor wet)')),
                          DropdownMenuItem(
                              value: 'watering', child: Text('Watering')),
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
                          decoration:
                              const InputDecoration(labelText: 'Watering Plan'),
                          value: wateringPlan,
                          items: const [
                            DropdownMenuItem(
                                value: '2side', child: Text('2 Side Watering')),
                            DropdownMenuItem(
                                value: '1side', child: Text('1 Side Watering')),
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
                            setDialogState(
                                () => timeLimit = int.tryParse(val) ?? 45);
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
                                    initialTime:
                                        TimeOfDay.fromDateTime(checkInTime),
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
                                    initialTime: TimeOfDay.fromDateTime(
                                        checkOutTime ??
                                            DateTime.now().add(
                                                const Duration(minutes: 45))),
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
                        items: growingEmployees.isNotEmpty
                            ? growingEmployees
                                .map((e) => DropdownMenuItem<String>(
                                      value: e['name'] as String,
                                      child:
                                          Text('${e['name']} (${e['role']})'),
                                    ))
                                .toList()
                            : const [
                                DropdownMenuItem(
                                    value: 'Minh T.',
                                    child: Text('Minh T. (Default)')),
                              ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => assignee = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Additional Notes'),
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
                      checkInTime:
                          jobType == 'alone_worker' ? checkInTime : null,
                      checkOutTime:
                          jobType == 'alone_worker' ? checkOutTime : null,
                    );
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Create',
                      style: TextStyle(color: Colors.white)),
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
        title: Text(
            'Start New Cycle - ${roomName.replaceAll('Room', 'Grow Room')}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration:
                  const InputDecoration(labelText: 'Default Watering Plan'),
              initialValue: wateringPlan,
              onChanged: (val) => wateringPlan = val,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(
                  labelText: 'Default Prochloraz Spray Rate'),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.forestGreen),
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

  void _showResetRoomConfirmDialog(BuildContext context, String roomName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset ${roomName.replaceAll('Room', 'Grow Room')}'),
        content: const Text(
          'Are you sure you want to reset this room? This will set the room status and stage to Idle, clear all active alarms, and complete all jobs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.onResetRoom(roomName);
              Navigator.pop(ctx);
            },
            child:
                const Text('Reset Room', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;

    const double dashWidth = 8;
    const double dashSpace = 8;
    double startX = 4;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2),
          Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
