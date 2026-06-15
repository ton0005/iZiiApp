import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/izii_colors.dart';
import '../bloc/mushrooms_bloc.dart';
import '../../../core/localization/app_localizations.dart';

class MushroomsDashboardScreen extends StatefulWidget {
  const MushroomsDashboardScreen({super.key});

  @override
  State<MushroomsDashboardScreen> createState() =>
      _MushroomsDashboardScreenState();
}

class _MushroomsDashboardScreenState extends State<MushroomsDashboardScreen> {
  String _activeFilter = 'all'; // all, active, idle, alerts
  late MushroomsBloc _bloc;
  Timer? _alarmAudioTimer;
  bool _isAlarmDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _bloc = MushroomsBloc()..add(LoadRoomsEvent());
  }

  @override
  void dispose() {
    _alarmAudioTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg =
        isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: primaryBg,
        appBar: AppBar(
          title: Text(context.tr('mushrooms_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF334155), Color(0xFF0F172A)],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _bloc.add(LoadRoomsEvent()),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('mushrooms_new_job'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showNewJobDialog(context),
            ),
            const SizedBox(width: 14),
          ],
        ),
        body: BlocConsumer<MushroomsBloc, MushroomsState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${context.tr('error')}: ${state.error}')),
              );
            }
            if (state.alarmActive) {
              if (_alarmAudioTimer == null) {
                // Play immediately
                HapticFeedback.vibrate();
                SystemSound.play(SystemSoundType.alert);
                // Start playing every 1.5 seconds for persistent alarm effect
                _alarmAudioTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
                  HapticFeedback.vibrate();
                  SystemSound.play(SystemSoundType.alert);
                });
              }
              if (!_isAlarmDialogOpen) {
                _isAlarmDialogOpen = true;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
                    title: Text(context.tr('mushrooms_alarm_title'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    content: Text(
                      context.tr('mushrooms_alarm_content'),
                      textAlign: TextAlign.center,
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _isAlarmDialogOpen = false;
                          context.read<MushroomsBloc>().add(DismissActiveAlarmsEvent());
                        },
                        child: Text(context.tr('mushrooms_alarm_dismiss'), style: const TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                ).then((_) => _isAlarmDialogOpen = false);
              }
            } else {
              _alarmAudioTimer?.cancel();
              _alarmAudioTimer = null;
              if (_isAlarmDialogOpen) {
                Navigator.of(context, rootNavigator: true).pop();
                _isAlarmDialogOpen = false;
              }
            }
          },
          builder: (context, state) {
            if (state.isLoading && state.rooms.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Calculations
            final activeRoomsCount =
                state.rooms.where((r) => r['status'] == 'active').length;
            final idleRoomsCount =
                state.rooms.where((r) => r['status'] == 'idle').length;

            final filteredRooms = state.rooms.where((r) {
              if (_activeFilter == 'active') return r['status'] == 'active';
              if (_activeFilter == 'idle') return r['status'] == 'idle';
              // 'alerts' filter will show rooms currently in special_solo or active stages that have alerts (for demo we filter by active solo alarm status)
              return true;
            }).toList();

            return Column(
              children: [
                // --- Industry Stats Header Panel ---
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(context.tr('mushrooms_total_rooms'), '${state.rooms.length}',
                          Icons.warehouse_rounded, Colors.blue),
                      _buildStatItem(context.tr('mushrooms_active_rooms'), '$activeRoomsCount',
                          Icons.play_circle_outline_rounded, Colors.green),
                      _buildStatItem(context.tr('mushrooms_idle_rooms'), '$idleRoomsCount',
                          Icons.pause_circle_outline_rounded, Colors.grey),
                    ],
                  ),
                ),

                // --- Room Custom Add & Filter Bar ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Filter Buttons
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                  context.tr('mushrooms_filter_all'), 'all', Icons.grid_view_rounded),
                              const SizedBox(width: 8),
                              _buildFilterChip(context.tr('mushrooms_filter_active'), 'active',
                                  Icons.play_arrow_rounded),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                  context.tr('mushrooms_filter_idle'), 'idle', Icons.pause_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add Grow Room Button
                      IconButton(
                        icon: const Icon(Icons.add_home_rounded,
                            color: Colors.blue),
                        tooltip: context.tr('mushrooms_add_room'),
                        onPressed: () => _showAddRoomDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- Room Grid ---
                Expanded(
                  child: filteredRooms.isEmpty
                      ? Center(
                          child: Text(context.tr('mushrooms_no_rooms_found'),
                              style: TextStyle(color: Colors.grey.shade500)))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.35,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = filteredRooms[index];
                            final isRoomActive = room['status'] == 'active';
                            final currentStage =
                                room['current_stage'] as String;

                            // Custom color coding based on stage
                            Color statusColor = Colors.grey;
                            if (isRoomActive) {
                              if (currentStage == 'special_solo') {
                                statusColor = Colors.red;
                              } else {
                                statusColor = Colors.green;
                              }
                            }

                            return GestureDetector(
                              onTap: () => _openRoomDetails(context, room),
                              child: Card(
                                color: cardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: currentStage == 'special_solo'
                                        ? Colors.redAccent
                                            .withValues(alpha: 0.6)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            room['name'] as String,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          // Stage status indicator badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isRoomActive
                                                  ? currentStage.toUpperCase()
                                                  : 'IDLE',
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const SizedBox(height: 8),
                                      // Secondary details
                                      if (isRoomActive) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.calendar_today_rounded,
                                                size: 12,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              context.tr('mushrooms_day_in_cycle').replaceAll('{day}', room['day_in_cycle'].toString()),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        if (currentStage == 'special_solo')
                                          Row(
                                            children: [
                                              const Icon(Icons.warning_amber_rounded,
                                                  size: 14,
                                                  color: Colors.orange),
                                              const SizedBox(width: 4),
                                              Text(
                                                context.tr('mushrooms_has_solo_job'),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          )
                                        else
                                          Text(
                                            context.tr('mushrooms_running_cycle'),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                      ] else ...[
                                        Text(context.tr('mushrooms_ready_for_cycle'),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                                fontStyle: FontStyle.italic)),
                                      ],
                                      const SizedBox(height: 4),
                                      // Progress line
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: isRoomActive
                                              ? (currentStage == 'packup_tree'
                                                  ? 1.0
                                                  : 0.5)
                                              : 0.0,
                                          backgroundColor: Colors.grey
                                              .withValues(alpha: 0.1),
                                          valueColor: AlwaysStoppedAnimation<
                                                  Color>(
                                              currentStage == 'special_solo'
                                                  ? Colors.orange
                                                  : const Color(0xFF0EA5E9)),
                                          minHeight: 4,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter, IconData icon) {
    final isSelected = _activeFilter == filter;
    final color = isSelected ? const Color(0xFF0EA5E9) : Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
      label: Text(label,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : Colors.black87))),
      selected: isSelected,
      selectedColor: const Color(0xFF0EA5E9),
      onSelected: (val) {
        if (val) {
          setState(() => _activeFilter = filter);
        }
      },
    );
  }

  void _openRoomDetails(BuildContext context, Map<String, dynamic> room) {
    final roomId = room['id'] as String;
    final roomName = room['name'] as String;

    _bloc.add(LoadRoomDetailsEvent(roomId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: _bloc),
          ],
          child: _RoomDetailsSheet(roomId: roomId, roomName: roomName),
        );
      },
    );
  }

  void _showAddRoomDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('mushrooms_dialog_add_room_title')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: ctx.tr('mushrooms_dialog_room_name_label'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9)),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _bloc.add(CreateCustomRoomEvent(controller.text));
                Navigator.pop(ctx);
              }
            },
            child: Text(ctx.tr('mushrooms_add'), style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showNewJobDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: _bloc),
          ],
          child: _NewJobDialogContent(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// New Job Dialog Content
// ═══════════════════════════════════════════════════════════
class _NewJobDialogContent extends StatefulWidget {
  @override
  State<_NewJobDialogContent> createState() => _NewJobDialogContentState();
}

class _NewJobDialogContentState extends State<_NewJobDialogContent> {
  String? _selectedRoomId;
  String _selectedJobType =
      'filling'; // filling, airing, floor_wet, clean_room, watering, clean_bed, prochloraz, packup_tree, special_solo

  // Watering
  String _wateringPlan = '2side'; // 2side, 1side, custom
  double _wateringVol = 2.0;

  // Prochloraz
  double _prochlorazRate = 1.3;
  double _prochlorazArea = 112.0;

  // Schedule
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);

  // General fields
  final _titleController = TextEditingController();
  final _assigneeController = TextEditingController();
  final _notesController = TextEditingController();
  final _projectLinkController = TextEditingController(text: 'M2-Cycle-3');
  String _priority = 'normal'; // low, normal, high, urgent
  int _soloTimeLimit = 45;

  @override
  void dispose() {
    _titleController.dispose();
    _assigneeController.dispose();
    _notesController.dispose();
    _projectLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<MushroomsBloc, MushroomsState>(
      builder: (context, state) {
        final rooms = state.rooms;
        if (_selectedRoomId == null && rooms.isNotEmpty) {
          _selectedRoomId = rooms.first['id'] as String;
        }

        double prochlorazTotal = _prochlorazRate * _prochlorazArea;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(context.tr('mushrooms_dialog_new_job_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Select Room
                DropdownButtonFormField<String>(
                  initialValue: _selectedRoomId,
                  decoration: InputDecoration(
                      labelText: context.tr('mushrooms_dialog_select_room'),
                      border: const OutlineInputBorder()),
                  items: rooms
                      .map((r) => DropdownMenuItem<String>(
                            value: r['id'] as String,
                            child: Text(r['name'] as String),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedRoomId = val),
                ),
                const SizedBox(height: 12),

                // Job Type selection
                Text(context.tr('mushrooms_dialog_select_job_type'),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedJobType,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(
                        value: 'filling',
                        child: Text(context.tr('mushrooms_job_filling'))),
                    DropdownMenuItem(
                        value: 'airing',
                        child: Text(context.tr('mushrooms_job_airing'))),
                    DropdownMenuItem(
                        value: 'floor_wet',
                        child: Text(context.tr('mushrooms_job_floor_wet'))),
                    DropdownMenuItem(
                        value: 'clean_room',
                        child: Text(context.tr('mushrooms_job_clean_room'))),
                    DropdownMenuItem(
                        value: 'watering',
                        child: Text(context.tr('mushrooms_job_watering'))),
                    DropdownMenuItem(
                        value: 'clean_bed',
                        child: Text(context.tr('mushrooms_job_clean_bed'))),
                    DropdownMenuItem(
                        value: 'prochloraz',
                        child: Text(context.tr('mushrooms_job_prochloraz'))),
                    DropdownMenuItem(
                        value: 'packup_tree',
                        child: Text(context.tr('mushrooms_job_packup_tree'))),
                    DropdownMenuItem(
                        value: 'special_solo',
                        child: Text(context.tr('mushrooms_job_special_solo'))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedJobType = val;
                        if (val == 'special_solo') {
                          _titleController.text = 'Việc Solo đặc biệt';
                        } else {
                          _titleController.text = '';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Specialized fields
                if (_selectedJobType == 'watering') ...[
                  DropdownButtonFormField<String>(
                    initialValue: _wateringPlan,
                    decoration: InputDecoration(
                        labelText: context.tr('mushrooms_dialog_watering_plan'),
                        border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(
                          value: '2side', child: Text(context.tr('mushrooms_watering_2side'))),
                      DropdownMenuItem(
                          value: '1side', child: Text(context.tr('mushrooms_watering_1side'))),
                      DropdownMenuItem(
                          value: 'custom', child: Text(context.tr('mushrooms_custom'))),
                    ],
                    onChanged: (val) =>
                        setState(() => _wateringPlan = val ?? '2side'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _wateringVol.toString(),
                    decoration: InputDecoration(
                        labelText: context.tr('mushrooms_dialog_watering_volume'),
                        border: const OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => setState(
                        () => _wateringVol = double.tryParse(val) ?? 2.0),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_selectedJobType == 'prochloraz') ...[
                  TextFormField(
                    initialValue: _prochlorazRate.toString(),
                    decoration: InputDecoration(
                        labelText: context.tr('mushrooms_dialog_prochloraz_rate'),
                        border: const OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => setState(
                        () => _prochlorazRate = double.tryParse(val) ?? 1.3),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _prochlorazArea.toString(),
                    decoration: InputDecoration(
                        labelText: context.tr('mushrooms_dialog_prochloraz_area'),
                        border: const OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => setState(
                        () => _prochlorazArea = double.tryParse(val) ?? 112.0),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr('mushrooms_dialog_prochloraz_total').replaceAll('{total}', prochlorazTotal.toStringAsFixed(1)),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_selectedJobType == 'special_solo') ...[
                  TextFormField(
                    initialValue: _soloTimeLimit.toString(),
                    decoration: InputDecoration(
                        labelText: context.tr('mushrooms_dialog_solo_time_limit'),
                        border: const OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => setState(
                        () => _soloTimeLimit = int.tryParse(val) ?? 45),
                  ),
                  const SizedBox(height: 12),
                ],

                // Scheduled Date & Time
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        child: Text(
                            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name / Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                      labelText: context.tr('mushrooms_dialog_title_label'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Assignee
                TextFormField(
                  controller: _assigneeController,
                  decoration: InputDecoration(
                      labelText: context.tr('mushrooms_dialog_assignee'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Priority Row
                Text(context.tr('mushrooms_dialog_priority'),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildPriorityButton(context.tr('mushrooms_priority_low'), 'low', Colors.green),
                    const SizedBox(width: 4),
                    _buildPriorityButton(context.tr('mushrooms_priority_normal'), 'normal', Colors.blue),
                    const SizedBox(width: 4),
                    _buildPriorityButton(context.tr('mushrooms_priority_high'), 'high', Colors.orange),
                    const SizedBox(width: 4),
                    _buildPriorityButton(context.tr('mushrooms_priority_urgent'), 'urgent', Colors.red),
                  ],
                ),
                const SizedBox(height: 12),

                // Link to Project
                TextFormField(
                  controller: _projectLinkController,
                  decoration: InputDecoration(
                      labelText: context.tr('mushrooms_dialog_project_link'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                      labelText: context.tr('mushrooms_dialog_notes'), border: const OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () {
                if (_selectedRoomId != null) {
                  final scheduledDateTime = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  );

                  String finalTitle = _titleController.text.trim();
                  if (finalTitle.isEmpty) {
                    finalTitle = _selectedJobType.toUpperCase();
                  }

                  String? planDetails;
                  if (_selectedJobType == 'watering') {
                    planDetails = '$_wateringPlan — ${_wateringVol} L/m²';
                  }

                  String? prochlorazRate;
                  if (_selectedJobType == 'prochloraz') {
                    prochlorazRate =
                        '${_prochlorazRate}g/m² · ${_prochlorazArea.toInt()}m²';
                  }

                  if (_selectedJobType == 'special_solo') {
                    context.read<MushroomsBloc>().add(AddSoloJobEvent(
                          roomId: _selectedRoomId!,
                          title: finalTitle,
                          assignee: _assigneeController.text.trim().isEmpty
                              ? 'Solo Worker'
                              : _assigneeController.text,
                          timeLimit: _soloTimeLimit,
                        ));
                  } else {
                    context.read<MushroomsBloc>().add(CreateCustomJobEvent(
                          roomId: _selectedRoomId!,
                          name: finalTitle,
                          jobType: _selectedJobType,
                          assignee: _assigneeController.text,
                          priority: _priority,
                          scheduledAt: scheduledDateTime,
                          planDetails: planDetails,
                          prochlorazRate: prochlorazRate,
                          notes: _notesController.text,
                          projectName:
                              _projectLinkController.text.trim().isEmpty
                                  ? null
                                  : _projectLinkController.text.trim(),
                        ));
                  }

                  Navigator.pop(context);
                }
              },
              child: Text(context.tr('mushrooms_dialog_assign_button'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriorityButton(String label, String value, Color color) {
    final isSelected = _priority == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _priority = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
                color: isSelected ? color : Colors.grey.shade400,
                width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Room Details Sheet
// ═══════════════════════════════════════════════════════════
class _RoomDetailsSheet extends StatefulWidget {
  final String roomId;
  final String roomName;

  const _RoomDetailsSheet({required this.roomId, required this.roomName});

  @override
  State<_RoomDetailsSheet> createState() => _RoomDetailsSheetState();
}

class _RoomDetailsSheetState extends State<_RoomDetailsSheet> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        try {
          final state = context.read<MushroomsBloc>().state;
          final jobs = state.selectedRoomJobs;
          final soloJobs = jobs
              .where((j) =>
                  j['job_type'] == 'special_solo' && j['status'] == 'in_progress')
              .toList();
          for (var sj in soloJobs) {
            final limit = sj['time_limit_minutes'] as int;
            final startedAt = DateTime.parse(sj['started_at'] as String);
            final deadline = startedAt.add(Duration(minutes: limit));
            if (DateTime.now().isAfter(deadline)) {
              HapticFeedback.vibrate();
              SystemSound.play(SystemSoundType.alert);
              if (sj['alarm_triggered'] != true) {
                context.read<MushroomsBloc>().add(CheckAlarmsEvent());
              }
            }
          }
        } catch (_) {}
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomSheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final headerColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;

    return BlocBuilder<MushroomsBloc, MushroomsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: bottomSheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final jobs = state.selectedRoomJobs;
        final soloJobs = jobs
            .where((j) =>
                j['job_type'] == 'special_solo' && j['status'] == 'in_progress')
            .toList();
        final pipelineJobs =
            jobs.where((j) => j['job_type'] != 'special_solo').toList();

        return DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: bottomSheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header details
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.roomName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('mushrooms_sheet_m2_plant'),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // TabBar
                Container(
                  color: headerColor,
                  child: TabBar(
                    indicatorColor: const Color(0xFF0EA5E9),
                    labelColor: const Color(0xFF0EA5E9),
                    unselectedLabelColor:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.grid_view_rounded, size: 18),
                        text: context.tr('mushrooms_sheet_tab_kanban'),
                      ),
                      Tab(
                        icon: const Icon(Icons.list_alt_rounded, size: 18),
                        text: context.tr('mushrooms_sheet_tab_pipeline'),
                      ),
                    ],
                  ),
                ),
                // TabBarView
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildKanbanTab(jobs),
                      _buildPipelineTab(pipelineJobs, soloJobs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatScheduledDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} $hour:$minute';
    } catch (_) {
      return dateStr;
    }
  }

  void _showJobDetailPanel(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final priority = job['priority'] ?? 'normal';
        final assignee = job['assignee'] != null && job['assignee'].toString().isNotEmpty
            ? job['assignee']
            : dialogContext.tr('mushrooms_sheet_unassigned');
        final notes = job['plan_details'] ?? job['prochloraz_rate'] ?? '';
        final linkedTaskId = job['linked_task_id'] ?? '';

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(job['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${dialogContext.tr('mushrooms_sheet_assignee')}: $assignee'),
              const SizedBox(height: 8),
              Text('${dialogContext.tr('mushrooms_sheet_priority')}: ${priority.toString().toUpperCase()}'),
              const SizedBox(height: 8),
              if (job['scheduled_at'] != null)
                Text(
                    '${dialogContext.tr('mushrooms_sheet_scheduled')}: ${_formatScheduledDate(job['scheduled_at'] as String)}'),
              const SizedBox(height: 8),
              if (notes.toString().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${dialogContext.tr('mushrooms_sheet_details')}: $notes',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            if (linkedTaskId.toString().isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.launch_rounded, size: 14),
                label: Text(dialogContext.tr('mushrooms_sheet_view_linked_task')),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                  context.push(
                      '/project/tasks?projectId=Costa M2 Operations&projectName=Costa%20M2%20Operations');
                },
              ),
            if (job['status'] == 'todo' || job['status'] == 'pending')
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  context.read<MushroomsBloc>().add(UpdateJobStatusEvent(
                      job['id'], widget.roomId, 'in_progress'));
                  Navigator.pop(dialogContext);
                },
                child: Text(dialogContext.tr('mushrooms_sheet_btn_start'),
                    style: const TextStyle(color: Colors.white)),
              ),
            if (job['status'] == 'in_progress')
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  context.read<MushroomsBloc>().add(
                      UpdateJobStatusEvent(job['id'], widget.roomId, 'review'));
                  Navigator.pop(dialogContext);
                },
                child: Text(dialogContext.tr('mushrooms_sheet_btn_send_review'),
                    style: const TextStyle(color: Colors.white)),
              ),
            if (job['status'] == 'review')
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  context.read<MushroomsBloc>().add(UpdateJobStatusEvent(
                      job['id'], widget.roomId, 'completed'));
                  Navigator.pop(dialogContext);
                },
                child: Text(dialogContext.tr('mushrooms_sheet_btn_approve'),
                    style: const TextStyle(color: Colors.white)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('mushrooms_sheet_close')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> job, {bool isDragging = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priority = job['priority'] ?? 'normal';
    final assignee = job['assignee'] ?? '';
    final scheduledAtStr = job['scheduled_at'] as String?;

    Color priorityColor = Colors.grey;
    if (priority == 'low') priorityColor = Colors.green;
    if (priority == 'high') priorityColor = Colors.orange;
    if (priority == 'urgent') priorityColor = Colors.red;

    return GestureDetector(
      onTap: isDragging ? null : () => _showJobDetailPanel(job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: isDragging
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10)
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (assignee.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      assignee,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                if (priority != 'normal')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority.toString().toUpperCase(),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: priorityColor),
                    ),
                  ),
              ],
            ),
            if (scheduledAtStr != null && scheduledAtStr.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatScheduledDate(scheduledAtStr),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(String title, List<Map<String, dynamic>> columnJobs,
      Color color, String targetStatus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) {
        final job = details.data;
        if (job['status'] != targetStatus) {
          context.read<MushroomsBloc>().add(
              UpdateJobStatusEvent(job['id'], widget.roomId, targetStatus));
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 220,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: candidateData.isNotEmpty ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${columnJobs.length}',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: columnJobs.length,
                  itemBuilder: (context, index) {
                    final job = columnJobs[index];
                    return Draggable<Map<String, dynamic>>(
                      data: job,
                      feedback: Material(
                        color: Colors.transparent,
                        child: _buildTaskCard(job, isDragging: true),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _buildTaskCard(job),
                      ),
                      child: _buildTaskCard(job),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanTab(List<Map<String, dynamic>> jobs) {
    final todoJobs = jobs
        .where((j) => j['status'] == 'todo' || j['status'] == 'pending')
        .toList();
    final inProgressJobs =
        jobs.where((j) => j['status'] == 'in_progress').toList();
    final reviewJobs = jobs.where((j) => j['status'] == 'review').toList();
    final completedJobs =
        jobs.where((j) => j['status'] == 'completed').toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKanbanColumn(
              context.tr('mushrooms_kanban_todo'), todoJobs, const Color(0xFF64748B), 'todo'),
          _buildKanbanColumn(context.tr('mushrooms_kanban_in_progress'), inProgressJobs,
              const Color(0xFF3B82F6), 'in_progress'),
          _buildKanbanColumn(
              context.tr('mushrooms_kanban_review'), reviewJobs, const Color(0xFFF59E0B), 'review'),
          _buildKanbanColumn(
              context.tr('mushrooms_kanban_completed'), completedJobs, const Color(0xFF10B981), 'completed'),
        ],
      ),
    );
  }

  Widget _buildPipelineTab(List<Map<String, dynamic>> pipelineJobs,
      List<Map<String, dynamic>> soloJobs) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        if (soloJobs.isNotEmpty) ...[
          ...soloJobs.map((sj) {
            final limit = sj['time_limit_minutes'] as int;
            final startedAtRaw = sj['started_at'] as String;
            final startedAt = DateTime.parse(startedAtRaw);

            final deadline = startedAt.add(Duration(minutes: limit));
            final remaining = deadline.difference(DateTime.now());
            final isOverdue = remaining.isNegative;

            final formattedTime = isOverdue
                ? context.tr('mushrooms_sheet_overdue')
                : '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

            final alertBgColor = isOverdue
                ? Colors.red.withValues(alpha: 0.12)
                : Colors.orange.withValues(alpha: 0.12);
            final alertBorderColor =
                isOverdue ? Colors.redAccent : Colors.orangeAccent;

            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: alertBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: alertBorderColor, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.emergency_rounded
                            : Icons.warning_rounded,
                        color: isOverdue ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('mushrooms_sheet_solo_active'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(context.tr('mushrooms_sheet_task').replaceAll('{task}', sj['name']),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(context.tr('mushrooms_sheet_worker').replaceAll('{worker}', sj['assignee']),
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('mushrooms_sheet_countdown').replaceAll('{time}', formattedTime),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isOverdue ? Colors.red : Colors.orange,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () {
                          context
                              .read<MushroomsBloc>()
                              .add(CompleteJobEvent(sj['id'], widget.roomId));
                        },
                        child: Text(context.tr('mushrooms_sheet_checkout'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
        if (pipelineJobs.isNotEmpty) ...[
          Text(
            context.tr('mushrooms_sheet_cycle_progress'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _buildPipelineTimeline(pipelineJobs),
          const SizedBox(height: 24),
          Text(
            context.tr('mushrooms_sheet_cycle_jobs'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...pipelineJobs.map((job) => _buildJobTile(job)),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.spa_outlined,
                      color: Colors.grey.shade400, size: 48),
                  const SizedBox(height: 12),
                  Text(context.tr('mushrooms_sheet_no_cycle'),
                      style: const TextStyle(
                          color: Colors.grey, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9)),
                    onPressed: () {
                      context
                          .read<MushroomsBloc>()
                          .add(StartCycleEvent(widget.roomId));
                    },
                    child: Text(context.tr('mushrooms_sheet_start_cycle_btn'),
                        style: const TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
          )
        ]
      ],
    );
  }

  // Visual Horizontal Timeline
  Widget _buildPipelineTimeline(List<Map<String, dynamic>> jobs) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: ListView.separated(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: jobs.length,
          separatorBuilder: (context, index) => Container(
            width: 20,
            height: 2,
            color: jobs[index]['status'] == 'completed'
                ? const Color(0xFF3B82F6)
                : Colors.grey.withValues(alpha: 0.3),
          ),
          itemBuilder: (context, index) {
            final job = jobs[index];
            final status = job['status'] as String;

            Color circleColor = Colors.grey;
            IconData icon = Icons.circle;

            if (status == 'completed') {
              circleColor = const Color(0xFF3B82F6);
              icon = Icons.check_circle_rounded;
            } else if (status == 'in_progress') {
              circleColor = const Color(0xFF10B981);
              icon = Icons.pending_rounded;
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: circleColor, size: 20),
                const SizedBox(height: 4),
                Text(
                  job['job_type'].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: status == 'in_progress' ? circleColor : Colors.grey,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildJobTile(Map<String, dynamic> job) {
    final status = job['status'] as String;
    final isDone = status == 'completed';
    final isActive = status == 'in_progress';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color tileBorderColor = Colors.transparent;
    if (isActive) {
      tileBorderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileBorderColor, width: 1.5),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isDone,
          activeColor: const Color(0xFF3B82F6),
          onChanged: (val) {
            if (val == true && !isDone) {
              context
                  .read<MushroomsBloc>()
                  .add(CompleteJobEvent(job['id'], widget.roomId));
            }
          },
        ),
        title: Text(
          job['name'] as String,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color:
                isDone ? Colors.grey : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job['plan_details'].toString().isNotEmpty)
              Text('${context.tr('mushrooms_dialog_watering_plan')}: ${job['plan_details']}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            if (job['prochloraz_rate'].toString().isNotEmpty)
              Text('${context.tr('mushrooms_dialog_prochloraz_rate')}: ${job['prochloraz_rate']}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueAccent)),
            if (job['assignee'].toString().isNotEmpty)
              Text('${context.tr('mushrooms_sheet_assignee')}: ${job['assignee']}',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: isActive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.tr('ser_status_in_progress').toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 10),
                ),
              )
            : null,
      ),
    );
  }
}
