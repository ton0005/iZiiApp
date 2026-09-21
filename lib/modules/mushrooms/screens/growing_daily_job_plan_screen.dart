import 'package:flutter/material.dart';
import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/events/app_event_bus.dart';
import '../repository.dart';
import '../widgets/job_completion_review_dialog.dart';
import '../services/daily_job_plan_pdf_service.dart';
import '../services/plant_room_service.dart';

class GrowingDailyJobPlanScreen extends StatefulWidget {
  final DateTime? initialDate;
  const GrowingDailyJobPlanScreen({super.key, this.initialDate});

  @override
  State<GrowingDailyJobPlanScreen> createState() =>
      _GrowingDailyJobPlanScreenState();
}

class _GrowingDailyJobPlanScreenState extends State<GrowingDailyJobPlanScreen>
    with SingleTickerProviderStateMixin {
  final MushroomsRepository _repo = MushroomsRepository();
  final AppDatabase _db = AppDatabase();

  late TabController _tabController;
  late DateTime _selectedDate;

  bool _isLoading = true;
  List<MushroomJob> _allJobs = [];
  List<GrowRoom> _rooms = [];
  List<Map<String, dynamic>> _jobTypes = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _departments = [];

  // Filter by Plant (M1, M2, all)
  String _selectedPlant = 'all'; // all, M1, M2

  // Filter for Sup/Lead Tab
  String _leadStatusFilter =
      'all'; // all, unassigned, assigned, in_progress, completed
  final String _leadRoomFilter = 'all';

  StreamSubscription<SyncEvent>? _syncSubscription;
  StreamSubscription<AppDomainEvent>? _eventBusSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadData();

    // Auto reload when background/realtime sync pulls jobs or rooms
    _syncSubscription = SyncService().syncEventStream.listen((event) {
      if (event.tables.contains('mushroom_jobs') ||
          event.tables.contains('grow_rooms') ||
          event.tables.contains('tasks')) {
        _loadData();
      }
    });

    // Auto reload on domain events
    _eventBusSubscription = AppEventBus().stream.listen((event) {
      if (event.eventType.startsWith('mushroom.') ||
          event.eventType.startsWith('tasks.')) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _eventBusSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await _db.select(_db.growRooms).get();
      rooms.sort((a, b) => PlantRoomService.compareRoomNames(a.name, b.name));
      final jobTypes = await _repo.getJobTypes(activeOnly: true);
      final employees = await _repo.getEmployees();
      final departments = await _repo.getDepartments();

      // Load jobs for selected day
      final startOfDay =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final allDbJobs = await (_db.select(_db.mushroomJobs)
            ..where((t) =>
                (t.scheduledAt.isBiggerOrEqualValue(startOfDay) &
                    t.scheduledAt.isSmallerThanValue(endOfDay)) |
                (t.scheduledAt.isNull() &
                    t.createdAt.isBiggerOrEqualValue(startOfDay) &
                    t.createdAt.isSmallerThanValue(endOfDay))))
          .get();

      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _jobTypes = jobTypes;
        _employees = employees;
        _departments = departments;
        _allJobs = allDbJobs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading daily plan: $e')),
      );
    }
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    _loadData();
  }

  Future<void> _exportOrPrintPdf() async {
    if (_allJobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No jobs planned for this date to export.'),
        ),
      );
      return;
    }
    try {
      await DailyJobPlanPdfService.printDailyPlan(
        context: context,
        date: _selectedDate,
        jobs: _allJobs,
        rooms: _rooms,
        jobTypes: _jobTypes,
        employees: _employees,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  Color _colorFromHex(String? hex, {Color fallback = const Color(0xFF2A78D6)}) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return fallback;
  }

  Map<String, dynamic>? _getJobTypeInfo(String jobTypeId) {
    final match = _jobTypes.where(
        (jt) => (jt['id'] as String).toLowerCase() == jobTypeId.toLowerCase());
    if (match.isNotEmpty) return match.first;
    return null;
  }

  String _getRoomName(String roomId) {
    final match = _rooms.where((r) => r.id == roomId);
    if (match.isNotEmpty) return match.first.name;
    return roomId;
  }

  String _getRoomPlant(String roomId) {
    final match = _rooms.where((r) => r.id == roomId);
    if (match.isNotEmpty) {
      return PlantRoomService.resolveDefaultPlantCode(match.first.name);
    }
    return PlantRoomService.resolveDefaultPlantCode(roomId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MODAL: Growing Manager Batch Job Planning
  // ══════════════════════════════════════════════════════════════════════════
  void _showAddPlanDialog() {
    final selectedRoomIds = <String>{};
    String dialogPlantFilter = 'all'; // 'all', 'M1', 'M2'
    final m1Rooms = _rooms
        .where((r) => PlantRoomService.resolveDefaultPlantCode(r.name) == 'M1')
        .toList()
      ..sort((a, b) => PlantRoomService.compareRoomNames(a.name, b.name));
    final m2Rooms = _rooms
        .where((r) => PlantRoomService.resolveDefaultPlantCode(r.name) == 'M2')
        .toList()
      ..sort((a, b) => PlantRoomService.compareRoomNames(a.name, b.name));

    String selectedJobType =
        _jobTypes.isNotEmpty ? _jobTypes.first['id'] as String : 'watering';
    final nameController = TextEditingController(text: '');
    final notesController = TextEditingController();
    final planDetailsController = TextEditingController();
    final prochlorazRateController = TextEditingController(text: '1.3');
    final wateringVolController = TextEditingController(text: '1.5');
    String wateringSide = '2side';
    String priority = 'normal';
    int planMinutes = 30;
    bool isSoloJob = false;
    int soloTimeLimit = 45;

    void updateJobTypeDefaults(String jtId) {
      final info = _getJobTypeInfo(jtId);
      if (info != null) {
        planMinutes = (info['plan_minutes'] as num?)?.toInt() ?? 30;
        isSoloJob = info['is_solo_job'] == true || jtId == 'alone_worker';
        if (nameController.text.isEmpty ||
            _jobTypes.any((t) => t['name'] == nameController.text)) {
          nameController.text = (info['name'] as String?) ?? jtId;
        }
      }
    }

    updateJobTypeDefaults(selectedJobType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final ink = isDark ? Colors.white : const Color(0xFF0F172A);
        final ink2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.90,
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ink2.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Plan: Growing Manager',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, dd/MM/yyyy')
                                .format(_selectedDate),
                            style: TextStyle(fontSize: 13, color: ink2),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        // Room Selection Header & Plant Tabs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Rooms (${selectedRoomIds.length}/${_rooms.length})',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ink),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  if (selectedRoomIds.length == _rooms.length) {
                                    selectedRoomIds.clear();
                                  } else {
                                    selectedRoomIds
                                        .addAll(_rooms.map((r) => r.id));
                                  }
                                });
                              },
                              child: Text(
                                  selectedRoomIds.length == _rooms.length
                                      ? 'Deselect All'
                                      : 'Select All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Quick Plant Filter Toggle Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: Text('Tất cả (${_rooms.length})'),
                                selected: dialogPlantFilter == 'all',
                                onSelected: (val) {
                                  if (val) {
                                    setSheetState(
                                        () => dialogPlantFilter = 'all');
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('Plant M1 (${m1Rooms.length})'),
                                selectedColor: const Color(0xFF10B981)
                                    .withValues(alpha: 0.2),
                                selected: dialogPlantFilter == 'M1',
                                onSelected: (val) {
                                  if (val) {
                                    setSheetState(
                                        () => dialogPlantFilter = 'M1');
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('Plant M2 (${m2Rooms.length})'),
                                selectedColor: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.2),
                                selected: dialogPlantFilter == 'M2',
                                onSelected: (val) {
                                  if (val) {
                                    setSheetState(
                                        () => dialogPlantFilter = 'M2');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Section 1: Plant M1
                        if (dialogPlantFilter == 'all' ||
                            dialogPlantFilter == 'M1') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('M1',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Plant M1 (Phòng 1-32)',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: ink)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${m1Rooms.where((r) => selectedRoomIds.contains(r.id)).length}/${m1Rooms.length})',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: ink2,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        setSheetState(() {
                                          final allM1Sel = m1Rooms.every((r) =>
                                              selectedRoomIds.contains(r.id));
                                          if (allM1Sel) {
                                            for (final r in m1Rooms) {
                                              selectedRoomIds.remove(r.id);
                                            }
                                          } else {
                                            for (final r in m1Rooms) {
                                              selectedRoomIds.add(r.id);
                                            }
                                          }
                                        });
                                      },
                                      child: Text(
                                        m1Rooms.every((r) =>
                                                selectedRoomIds.contains(r.id))
                                            ? 'Bỏ chọn M1'
                                            : 'Chọn tất cả M1',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: m1Rooms.map((r) {
                                    final isSel =
                                        selectedRoomIds.contains(r.id);
                                    return FilterChip(
                                      label: Text(r.name),
                                      selected: isSel,
                                      selectedColor: const Color(0xFF10B981)
                                          .withValues(alpha: 0.2),
                                      checkmarkColor: const Color(0xFF10B981),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                        color: isSel
                                            ? const Color(0xFF10B981)
                                            : ink,
                                      ),
                                      onSelected: (val) {
                                        setSheetState(() {
                                          if (val) {
                                            selectedRoomIds.add(r.id);
                                          } else {
                                            selectedRoomIds.remove(r.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section 2: Plant M2
                        if (dialogPlantFilter == 'all' ||
                            dialogPlantFilter == 'M2') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('M2',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Plant M2 (Phòng 33-66)',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: ink)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${m2Rooms.where((r) => selectedRoomIds.contains(r.id)).length}/${m2Rooms.length})',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: ink2,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        setSheetState(() {
                                          final allM2Sel = m2Rooms.every((r) =>
                                              selectedRoomIds.contains(r.id));
                                          if (allM2Sel) {
                                            for (final r in m2Rooms) {
                                              selectedRoomIds.remove(r.id);
                                            }
                                          } else {
                                            for (final r in m2Rooms) {
                                              selectedRoomIds.add(r.id);
                                            }
                                          }
                                        });
                                      },
                                      child: Text(
                                        m2Rooms.every((r) =>
                                                selectedRoomIds.contains(r.id))
                                            ? 'Bỏ chọn M2'
                                            : 'Chọn tất cả M2',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: m2Rooms.map((r) {
                                    final isSel =
                                        selectedRoomIds.contains(r.id);
                                    return FilterChip(
                                      label: Text(r.name),
                                      selected: isSel,
                                      selectedColor: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.2),
                                      checkmarkColor: const Color(0xFF8B5CF6),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                        color: isSel
                                            ? const Color(0xFF8B5CF6)
                                            : ink,
                                      ),
                                      onSelected: (val) {
                                        setSheetState(() {
                                          if (val) {
                                            selectedRoomIds.add(r.id);
                                          } else {
                                            selectedRoomIds.remove(r.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Job Type Selection
                        Text(
                          'Job Type',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ink),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedJobType,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: _jobTypes.map((jt) {
                            final id = jt['id'] as String;
                            final name = (jt['name'] as String?) ?? id;
                            final color = _colorFromHex(jt['color'] as String?);
                            return DropdownMenuItem(
                              value: id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('$name (${jt['plan_minutes'] ?? 30}m)'),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() {
                                selectedJobType = val;
                                updateJobTypeDefaults(val);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Priority & Standard Duration
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Priority',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: ink)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: priority,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'low', child: Text('Low')),
                                      DropdownMenuItem(
                                          value: 'normal',
                                          child: Text('Normal')),
                                      DropdownMenuItem(
                                          value: 'high', child: Text('High')),
                                      DropdownMenuItem(
                                          value: 'urgent',
                                          child: Text('Urgent')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setSheetState(() => priority = v);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Target Plan (Min)',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: ink)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    initialValue: '$planMinutes',
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                    ),
                                    onChanged: (v) {
                                      final parsed = int.tryParse(v);
                                      if (parsed != null) planMinutes = parsed;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dynamic Fields based on Job Type
                        if (selectedJobType == 'watering') ...[
                          Text('Watering Parameters',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ink)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                        value: '1side', label: Text('1 Side')),
                                    ButtonSegment(
                                        value: '2side', label: Text('2 Side')),
                                  ],
                                  selected: {wateringSide},
                                  onSelectionChanged: (set) {
                                    setSheetState(
                                        () => wateringSide = set.first);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: wateringVolController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Volume (L/m²)',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (selectedJobType == 'prochloraz') ...[
                          Text('Prochloraz Application',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ink)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: prochlorazRateController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Rate (g/m²)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Solo Job Settings
                        Row(
                          children: [
                            Checkbox(
                              value: isSoloJob,
                              onChanged: (val) {
                                setSheetState(() => isSoloJob = val ?? false);
                              },
                            ),
                            const Text(
                                'Alone Worker (Requires Safety Alarm flow)'),
                          ],
                        ),
                        if (isSoloJob) ...[
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 12, bottom: 12),
                            child: TextFormField(
                              initialValue: '$soloTimeLimit',
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max Safety Limit (Minutes)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (v) {
                                final p = int.tryParse(v);
                                if (p != null) soloTimeLimit = p;
                              },
                            ),
                          ),
                        ],

                        // Notes & Instructions
                        Text('Notes / Instructions for Sup & Crew',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ink)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g., Check humidity before spraying...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton.icon(
                          icon: const Icon(Icons.playlist_add_check),
                          label: Text(
                            'Create Plan for ${selectedRoomIds.length} Room(s)',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A78D6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: selectedRoomIds.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  await _createBatchJobs(
                                    roomIds: selectedRoomIds.toList(),
                                    jobType: selectedJobType,
                                    name: nameController.text.trim().isNotEmpty
                                        ? nameController.text.trim()
                                        : selectedJobType.toUpperCase(),
                                    priority: priority,
                                    planMinutes: planMinutes,
                                    isSoloJob: isSoloJob,
                                    timeLimit: soloTimeLimit,
                                    wateringSide: wateringSide,
                                    wateringVol: double.tryParse(
                                            wateringVolController.text) ??
                                        1.5,
                                    prochlorazRate:
                                        prochlorazRateController.text.trim(),
                                    notes: notesController.text.trim(),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createBatchJobs({
    required List<String> roomIds,
    required String jobType,
    required String name,
    required String priority,
    required int planMinutes,
    required bool isSoloJob,
    required int timeLimit,
    required String wateringSide,
    required double wateringVol,
    required String prochlorazRate,
    required String notes,
  }) async {
    setState(() => _isLoading = true);

    String planDetails = '';
    if (jobType == 'watering') {
      planDetails = '$wateringSide ${wateringVol}L/m²';
    } else if (jobType == 'prochloraz') {
      planDetails = '${prochlorazRate}g/m²';
    }

    try {
      for (final roomId in roomIds) {
        await _repo.createPlannedDailyJob(
          roomId: roomId,
          jobType: jobType,
          name: name,
          scheduledAt: _selectedDate,
          priority: priority,
          planDetails: planDetails.isNotEmpty ? planDetails : null,
          prochlorazRate: prochlorazRate.isNotEmpty ? prochlorazRate : null,
          timeLimitMinutes: isSoloJob ? timeLimit : planMinutes,
          isSoloJob: isSoloJob,
          notes: notes.isNotEmpty ? notes : null,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 6),
          content: Text(
            'Successfully planned $name for ${roomIds.length} room(s). Waiting for Sup/Lead assignment.',
          ),
          action: SnackBarAction(
            label: 'Print PDF',
            textColor: Colors.white,
            onPressed: _exportOrPrintPdf,
          ),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error planning jobs: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MODAL: Sup/Lead Assign Worker
  // ══════════════════════════════════════════════════════════════════════════
  void _showAssignWorkerDialog(MushroomJob job) {
    String search = '';
    String deptFilter = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final ink = isDark ? Colors.white : const Color(0xFF0F172A);
        final ink2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filteredEmps = _employees.where((e) {
              final name = (e['name'] as String? ?? '').toLowerCase();
              final dept = (e['department'] as String? ?? '').toLowerCase();
              if (deptFilter != 'all' &&
                  !dept.contains(deptFilter.toLowerCase())) {
                return false;
              }
              if (search.isNotEmpty && !name.contains(search.toLowerCase())) {
                return false;
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ink2.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assign Worker to Job',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: ink)),
                          Text(
                            '${job.name} · Room: ${_getRoomName(job.roomId)}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2A78D6)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search employee by name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      setSheetState(() => search = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All Depts'),
                          selected: deptFilter == 'all',
                          onSelected: (s) =>
                              setSheetState(() => deptFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        ..._departments.map((d) {
                          final dName = (d['name'] as String?) ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(dName),
                              selected: deptFilter == dName,
                              onSelected: (s) =>
                                  setSheetState(() => deptFilter = dName),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: filteredEmps.isEmpty
                        ? Center(
                            child: Text('No employees match search.',
                                style: TextStyle(color: ink2)),
                          )
                        : ListView.separated(
                            itemCount: filteredEmps.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final emp = filteredEmps[i];
                              final empName =
                                  (emp['name'] as String?) ?? emp['id'];
                              final empDept =
                                  (emp['department'] as String?) ?? 'Staff';
                              final isCurrent = job.assignee == empName;

                              // Count current daily assigned jobs for this employee
                              final countToday = _allJobs
                                  .where((j) => j.assignee == empName)
                                  .length;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF2A78D6)
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    empName.isNotEmpty ? empName[0] : '?',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2A78D6)),
                                  ),
                                ),
                                title: Text(
                                  empName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isCurrent
                                        ? const Color(0xFF2A78D6)
                                        : ink,
                                  ),
                                ),
                                subtitle: Text(
                                  '$empDept · $countToday job(s) today',
                                  style: TextStyle(fontSize: 12, color: ink2),
                                ),
                                trailing: isCurrent
                                    ? const Chip(
                                        label: Text('Assigned'),
                                        backgroundColor: Color(0xFFE0F2FE),
                                      )
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF2A78D6),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                        ),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await _assignJob(job.id, empName);
                                        },
                                        child: const Text('Select'),
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assignJob(String jobId, String workerName) async {
    setState(() => _isLoading = true);
    try {
      await _repo.assignJobToWorker(jobId, workerName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Assigned job to $workerName'),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning job: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unassignJob(String jobId) async {
    setState(() => _isLoading = true);
    try {
      await _repo.unassignJob(jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job set back to unassigned')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unassigning job: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startJob(String jobId) async {
    setState(() => _isLoading = true);
    try {
      await _repo.updateJobStatus(jobId, 'in_progress');
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting job: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeJobWithReview(MushroomJob job) async {
    final override = await confirmJobCompletion(
      context,
      jobType: job.jobType,
      startedAt: job.startedAt,
      createdAt: job.createdAt,
    );
    if (override == null) return; // User cancelled

    setState(() => _isLoading = true);
    try {
      await _repo.completeJob(job.id, onTimeOverride: override ? true : null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Job "${job.name}" marked as completed!'),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing job: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteJob(MushroomJob job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Planned Job?'),
        content: Text(
            'Are you sure you want to remove "${job.name}" for ${_getRoomName(job.roomId)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _repo.deleteMushroomJob(job.id);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting job: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UI BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final ink2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final m1Jobs =
        _allJobs.where((j) => _getRoomPlant(j.roomId) == 'M1').toList();
    final m2Jobs =
        _allJobs.where((j) => _getRoomPlant(j.roomId) == 'M2').toList();
    final effectiveJobs = _selectedPlant == 'M1'
        ? m1Jobs
        : (_selectedPlant == 'M2' ? m2Jobs : _allJobs);

    // KPI counts
    final totalJobs = effectiveJobs.length;
    final unassignedJobs = effectiveJobs
        .where((j) => j.assignee == null || j.assignee!.trim().isEmpty)
        .length;
    final assignedJobs = effectiveJobs
        .where((j) =>
            (j.assignee != null && j.assignee!.trim().isNotEmpty) &&
            j.status != 'completed' &&
            j.status != 'in_progress')
        .length;
    final inProgressJobs =
        effectiveJobs.where((j) => j.status == 'in_progress').length;
    final completedJobs =
        effectiveJobs.where((j) => j.status == 'completed').length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Daily Job Planning & Dispatch'),
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Export & Print Daily Job Plan (PDF)',
            onPressed: _exportOrPrintPdf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2A78D6),
            unselectedLabelColor: ink2,
            indicatorColor: const Color(0xFF2A78D6),
            indicatorWeight: 3,
            tabs: [
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Growing Job Planning',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline, size: 18),
                    const SizedBox(width: 8),
                    Text('Sup/Lead Assign Jobs ($unassignedJobs)',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Date Switcher Header
                  _buildDateHeader(surface, ink, ink2, border),

                  // Plant Selection Header Tabs (M1 / M2 / All)
                  _buildPlantSelector(surface, ink, ink2, border,
                      m1Jobs.length, m2Jobs.length, _allJobs.length),

                  // KPI Summary Bar
                  _buildKpiBar(
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                    total: totalJobs,
                    unassigned: unassignedJobs,
                    assigned: assignedJobs,
                    inProgress: inProgressJobs,
                    completed: completedJobs,
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Manager Planning View
                        _buildManagerPlanningTab(surface, ink, ink2, border),

                        // Tab 2: Sup/Lead Assignment View
                        _buildLeadAssignmentTab(surface, ink, ink2, border),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2A78D6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Plan Jobs'),
        onPressed: _showAddPlanDialog,
      ),
    );
  }

  Widget _buildDateHeader(Color surface, Color ink, Color ink2, Color border) {
    final isToday = DateTime.now().year == _selectedDate.year &&
        DateTime.now().month == _selectedDate.month &&
        DateTime.now().day == _selectedDate.day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _onDateChanged(
                    _selectedDate.subtract(const Duration(days: 1))),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) _onDateChanged(picked);
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Color(0xFF2A78D6)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    _onDateChanged(_selectedDate.add(const Duration(days: 1))),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Export / Print PDF'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: _exportOrPrintPdf,
              ),
              if (!isToday) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  onPressed: () => _onDateChanged(DateTime.now()),
                  child: const Text('Go to Today'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlantSelector(Color surface, Color ink, Color ink2, Color border,
      int m1Count, int m2Count, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPlantFilterChip(
              title: 'Plant M1',
              subtitle: 'Phòng 1-32 ($m1Count jobs)',
              isSelected: _selectedPlant == 'M1',
              activeColor: const Color(0xFF10B981),
              onTap: () => setState(() => _selectedPlant = 'M1'),
              ink: ink,
              ink2: ink2,
              border: border,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPlantFilterChip(
              title: 'Plant M2',
              subtitle: 'Phòng 33-66 ($m2Count jobs)',
              isSelected: _selectedPlant == 'M2',
              activeColor: const Color(0xFF8B5CF6),
              onTap: () => setState(() => _selectedPlant = 'M2'),
              ink: ink,
              ink2: ink2,
              border: border,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPlantFilterChip(
              title: 'Tất cả Plants',
              subtitle: 'All ($totalCount jobs)',
              isSelected: _selectedPlant == 'all',
              activeColor: const Color(0xFF2A78D6),
              onTap: () => setState(() => _selectedPlant = 'all'),
              ink: ink,
              ink2: ink2,
              border: border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantFilterChip({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    required Color ink,
    required Color ink2,
    required Color border,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : border,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? activeColor : ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiBar({
    required Color surface,
    required Color border,
    required Color ink,
    required Color ink2,
    required int total,
    required int unassigned,
    required int assigned,
    required int inProgress,
    required int completed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildKpiItem('Total Planned', '$total', ink),
          _buildKpiItem('Unassigned', '$unassigned', const Color(0xFFF59E0B),
              isHighlight: unassigned > 0),
          _buildKpiItem('Assigned', '$assigned', const Color(0xFF2A78D6)),
          _buildKpiItem('In Progress', '$inProgress', const Color(0xFF8B5CF6)),
          _buildKpiItem('Completed', '$completed', const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, Color color,
      {bool isHighlight = false}) {
    return Column(
      children: [
        Container(
          padding: isHighlight
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
              : EdgeInsets.zero,
          decoration: isHighlight
              ? BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 1: Manager Planning View
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildManagerPlanningTab(
      Color surface, Color ink, Color ink2, Color border) {
    final displayJobs = _selectedPlant == 'all'
        ? _allJobs
        : _allJobs
            .where((j) => _getRoomPlant(j.roomId) == _selectedPlant)
            .toList();

    if (displayJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note,
                size: 64, color: ink2.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _selectedPlant == 'all'
                  ? 'No jobs planned for ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'
                  : 'No jobs planned for Plant ${_selectedPlant.toUpperCase()} on ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "+ Plan Jobs" button below to schedule work for rooms.',
              style: TextStyle(fontSize: 13, color: ink2),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Plan Jobs Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A78D6),
                foregroundColor: Colors.white,
              ),
              onPressed: _showAddPlanDialog,
            ),
          ],
        ),
      );
    }

    // Separate jobs into M1 and M2
    final Map<String, List<MushroomJob>> m1JobsByRoom = {};
    final Map<String, List<MushroomJob>> m2JobsByRoom = {};

    for (final j in displayJobs) {
      final plant = _getRoomPlant(j.roomId);
      if (plant == 'M2') {
        m2JobsByRoom.putIfAbsent(j.roomId, () => []).add(j);
      } else {
        m1JobsByRoom.putIfAbsent(j.roomId, () => []).add(j);
      }
    }

    // Sort rooms naturally: 1, 2, 3, 4, 5, 6, 6A, 6B, 7, 8, ..., 22, 22A, 23...
    final sortedM1RoomIds = m1JobsByRoom.keys.toList()
      ..sort((a, b) => PlantRoomService.compareRoomNames(
          _getRoomName(a), _getRoomName(b)));
    final sortedM2RoomIds = m2JobsByRoom.keys.toList()
      ..sort((a, b) => PlantRoomService.compareRoomNames(
          _getRoomName(a), _getRoomName(b)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Plant M1 Section
        if (sortedM1RoomIds.isNotEmpty) ...[
          if (_selectedPlant == 'all')
            _buildPlantSectionHeader(
              title: 'Plant M1 (Phòng 1-32)',
              jobCount: sortedM1RoomIds.fold<int>(
                  0, (sum, id) => sum + (m1JobsByRoom[id]?.length ?? 0)),
              roomCount: sortedM1RoomIds.length,
              color: const Color(0xFF10B981),
              ink: ink,
              ink2: ink2,
            ),
          ...sortedM1RoomIds.map((roomId) => _buildRoomCard(
              roomId, m1JobsByRoom[roomId]!, surface, ink, ink2, border)),
          if (_selectedPlant == 'all' && sortedM2RoomIds.isNotEmpty)
            const SizedBox(height: 8),
        ],

        // Plant M2 Section
        if (sortedM2RoomIds.isNotEmpty) ...[
          if (_selectedPlant == 'all')
            _buildPlantSectionHeader(
              title: 'Plant M2 (Phòng 33-66)',
              jobCount: sortedM2RoomIds.fold<int>(
                  0, (sum, id) => sum + (m2JobsByRoom[id]?.length ?? 0)),
              roomCount: sortedM2RoomIds.length,
              color: const Color(0xFF8B5CF6),
              ink: ink,
              ink2: ink2,
            ),
          ...sortedM2RoomIds.map((roomId) => _buildRoomCard(
              roomId, m2JobsByRoom[roomId]!, surface, ink, ink2, border)),
        ],
      ],
    );
  }

  Widget _buildPlantSectionHeader({
    required String title,
    required int jobCount,
    required int roomCount,
    required Color color,
    required Color ink,
    required Color ink2,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            '$roomCount phòng · $jobCount jobs',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ink2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(String roomId, List<MushroomJob> roomJobs,
      Color surface, Color ink, Color ink2, Color border) {
    final roomName = _getRoomName(roomId);
    final plant = _getRoomPlant(roomId);
    final isM2 = plant == 'M2';
    final plantColor =
        isM2 ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: plantColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.meeting_room_rounded,
                          size: 18, color: plantColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      roomName,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: plantColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plant,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: plantColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${roomJobs.length} job(s)',
                  style: TextStyle(
                      fontSize: 12,
                      color: ink2,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Divider(height: 20),
            ...roomJobs
                .map((j) => _buildManagerJobItem(j, ink, ink2, border)),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerJobItem(
      MushroomJob job, Color ink, Color ink2, Color border) {
    final jtInfo = _getJobTypeInfo(job.jobType);
    final color = _colorFromHex(jtInfo?['color'] as String?);
    final isUnassigned = job.assignee == null || job.assignee!.trim().isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: border.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      job.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ink),
                    ),
                    const SizedBox(width: 8),
                    if (job.isSoloJob)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('SOLO',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (job.planDetails != null && job.planDetails!.isNotEmpty)
                      job.planDetails,
                    if (job.prochlorazRate != null &&
                        job.prochlorazRate!.isNotEmpty)
                      job.prochlorazRate,
                    'Priority: ${job.priority ?? "normal"}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isUnassigned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Unassigned',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706)),
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 14, color: Color(0xFF2A78D6)),
                    const SizedBox(width: 4),
                    Text(
                      job.assignee!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ink),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                job.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: job.status == 'completed'
                      ? const Color(0xFF10B981)
                      : (job.status == 'in_progress'
                          ? const Color(0xFF8B5CF6)
                          : ink2),
                ),
              ),
            ],
          ),
          if (job.status != 'completed') ...[
            const SizedBox(width: 6),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _deleteJob(job),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAB 2: Sup / Lead Assignment View
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildLeadAssignmentTab(
      Color surface, Color ink, Color ink2, Color border) {
    final filteredJobs = _allJobs.where((j) {
      if (_selectedPlant != 'all' &&
          _getRoomPlant(j.roomId) != _selectedPlant) {
        return false;
      }
      final isUnassigned = j.assignee == null || j.assignee!.trim().isEmpty;
      if (_leadStatusFilter == 'unassigned' && !isUnassigned) return false;
      if (_leadStatusFilter == 'assigned' &&
          (isUnassigned ||
              j.status == 'completed' ||
              j.status == 'in_progress')) return false;
      if (_leadStatusFilter == 'in_progress' && j.status != 'in_progress')
        return false;
      if (_leadStatusFilter == 'completed' && j.status != 'completed')
        return false;
      if (_leadRoomFilter != 'all' && j.roomId != _leadRoomFilter) return false;
      return true;
    }).toList();

    // Sắp xếp các jobs theo thứ tự phòng tự nhiên: 1, 2, ..., 6, 6A, 6B, 7, 8...
    filteredJobs.sort((a, b) {
      final roomA = _getRoomName(a.roomId);
      final roomB = _getRoomName(b.roomId);
      final cRoom = PlantRoomService.compareRoomNames(roomA, roomB);
      if (cRoom != 0) return cRoom;
      return (a.scheduledAt ?? a.createdAt)
          .compareTo(b.scheduledAt ?? b.createdAt);
    });

    return Column(
      children: [
        // Lead Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Jobs'),
                  selected: _leadStatusFilter == 'all',
                  onSelected: (s) => setState(() => _leadStatusFilter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Needs Worker (Unassigned)'),
                  selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  selected: _leadStatusFilter == 'unassigned',
                  onSelected: (s) =>
                      setState(() => _leadStatusFilter = 'unassigned'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Assigned'),
                  selected: _leadStatusFilter == 'assigned',
                  onSelected: (s) =>
                      setState(() => _leadStatusFilter = 'assigned'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('In Progress'),
                  selected: _leadStatusFilter == 'in_progress',
                  onSelected: (s) =>
                      setState(() => _leadStatusFilter = 'in_progress'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: _leadStatusFilter == 'completed',
                  onSelected: (s) =>
                      setState(() => _leadStatusFilter = 'completed'),
                ),
              ],
            ),
          ),
        ),

        // List of jobs for Sup/Lead
        Expanded(
          child: filteredJobs.isEmpty
              ? Center(
                  child: Text('No jobs matching filter.',
                      style: TextStyle(color: ink2)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredJobs.length,
                  itemBuilder: (ctx, i) {
                    final job = filteredJobs[i];
                    return _buildLeadJobCard(job, surface, ink, ink2, border);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeadJobCard(
      MushroomJob job, Color surface, Color ink, Color ink2, Color border) {
    final jtInfo = _getJobTypeInfo(job.jobType);
    final color = _colorFromHex(jtInfo?['color'] as String?);
    final roomName = _getRoomName(job.roomId);
    final plant = _getRoomPlant(job.roomId);
    final isM2 = plant == 'M2';
    final plantColor =
        isM2 ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    final isUnassigned = job.assignee == null || job.assignee!.trim().isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Room, Job Type, Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      job.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ink),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: plantColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plant,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: plantColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('·  $roomName',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ink2)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: job.status == 'completed'
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : (job.status == 'in_progress'
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                            : (isUnassigned
                                ? const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.15)
                                : const Color(0xFF2A78D6)
                                    .withValues(alpha: 0.15))),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isUnassigned ? 'NEEDS WORKER' : job.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: job.status == 'completed'
                          ? const Color(0xFF10B981)
                          : (job.status == 'in_progress'
                              ? const Color(0xFF8B5CF6)
                              : (isUnassigned
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF2A78D6))),
                    ),
                  ),
                ),
              ],
            ),

            if (job.planDetails != null && job.planDetails!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Plan: ${job.planDetails}',
                  style: TextStyle(fontSize: 12, color: ink2)),
            ],

            const Divider(height: 20),

            // Worker Assignment Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isUnassigned
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                          : const Color(0xFF2A78D6).withValues(alpha: 0.2),
                      child: Icon(
                        isUnassigned ? Icons.person_add : Icons.person,
                        size: 16,
                        color: isUnassigned
                            ? const Color(0xFFD97706)
                            : const Color(0xFF2A78D6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUnassigned ? 'Unassigned' : job.assignee!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isUnassigned ? const Color(0xFFD97706) : ink,
                      ),
                    ),
                  ],
                ),

                // Actions for Sup/Lead
                Row(
                  children: [
                    if (isUnassigned)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Assign Worker'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A78D6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _showAssignWorkerDialog(job),
                      )
                    else ...[
                      TextButton(
                        onPressed: () => _showAssignWorkerDialog(job),
                        child: const Text('Reassign'),
                      ),
                      if (job.status != 'in_progress' &&
                          job.status != 'completed') ...[
                        TextButton(
                          onPressed: () => _unassignJob(job.id),
                          child: const Text('Unassign',
                              style: TextStyle(color: Colors.red)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          onPressed: () => _startJob(job.id),
                          child: const Text('Start'),
                        ),
                      ],
                      if (job.status == 'in_progress')
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          onPressed: () => _completeJobWithReview(job),
                          child: const Text('Mark Done'),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
