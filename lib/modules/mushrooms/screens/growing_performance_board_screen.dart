import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/events/app_event_bus.dart';
import '../models/growing_performance_models.dart';
import '../services/growing_performance_service.dart';
import '../services/window_action_service.dart';
import 'growing_daily_job_plan_screen.dart';
import 'grow_room_3d_screen.dart';

/// Growing Performance Board Screen
/// Operational performance dashboard tracking daily Joblist, Break time, and Alone Worker safety.
class GrowingPerformanceBoardScreen extends StatefulWidget {
  final bool isEmbedded;
  const GrowingPerformanceBoardScreen({super.key, this.isEmbedded = false});

  @override
  State<GrowingPerformanceBoardScreen> createState() =>
      _GrowingPerformanceBoardScreenState();
}

class _GrowingPerformanceBoardScreenState
    extends State<GrowingPerformanceBoardScreen> {
  final GrowingPerformanceService _service = GrowingPerformanceService();
  final WindowActionService _windowActionService = WindowActionService();

  // Dataset loaded live from the SQLite database
  List<PerformanceTaskRecord> _allTasks = [];
  List<PerformanceShiftRecord> _allShifts = [];
  List<PerformanceDept> _departments = [];
  List<PerformanceEmployee> _employees = [];
  List<PerformanceJobType> _jobTypes = [];
  bool _isLoading = true;
  String? _loadError;

  // Window Issues & Alarms state (from 3D Model)
  List<WindowIssueReport> _windowIssues = [];
  String _selectedIssueCategoryFilter = 'all';
  String _selectedIssueStatusFilter = 'all';
  StreamSubscription<List<WindowIssueReport>>? _issuesSubscription;

  // Filter state
  int _rangeDays = 7; // 1, 7, 30
  String _selectedDept = 'all'; // all, or a department id
  String _selectedEmp = 'all';
  String _selectedJob = 'all';

  // Table sorting state
  String _sortColumn =
      'jobs'; // name, dept, jobs, onTime, avgMin, vsPlan, break, otH, alarms
  int _sortDir = -1; // 1 = asc, -1 = desc

  StreamSubscription<SyncEvent>? _syncSubscription;
  StreamSubscription<AppDomainEvent>? _eventBusSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadWindowIssues();
    _issuesSubscription = _windowActionService.issuesStream.listen((issues) {
      if (mounted) {
        setState(() {
          _windowIssues = issues;
        });
      }
    });

    // Auto refresh performance dataset when new jobs or updates arrive via sync
    _syncSubscription = SyncService().syncEventStream.listen((event) {
      if (event.tables.contains('mushroom_jobs') ||
          event.tables.contains('tasks') ||
          event.tables.contains('mushroom_attendance_events') ||
          event.tables.contains('mushroom_daily_timesheets')) {
        _loadData();
      }
    });

    _eventBusSubscription = AppEventBus().stream.listen((event) {
      if (event.eventType.startsWith('mushroom.') ||
          event.eventType.startsWith('tasks.')) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _issuesSubscription?.cancel();
    _syncSubscription?.cancel();
    _eventBusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadWindowIssues() async {
    final issues = await _windowActionService.getIssues();
    if (mounted) {
      setState(() {
        _windowIssues = issues;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final dataset = await _service.loadDataset(rangeDays: 30);
      if (!mounted) return;
      setState(() {
        _departments = dataset.departments;
        _employees = dataset.employees;
        _jobTypes = dataset.jobTypes;
        _allTasks = dataset.tasks;
        _allShifts = dataset.shifts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _colorFromHex(String? hex, {required Color fallback}) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return fallback;
  }

  // Filter data by range and criteria
  bool _taskMatches(PerformanceTaskRecord r) {
    if (r.dayOffset >= _rangeDays) return false;
    if (_selectedDept != 'all' && r.deptId != _selectedDept) return false;
    if (_selectedEmp != 'all' && r.employeeId != _selectedEmp) return false;
    if (_selectedJob != 'all' &&
        r.jobId.toLowerCase() != _selectedJob.toLowerCase()) {
      return false;
    }
    return true;
  }

  bool _shiftMatches(PerformanceShiftRecord s) {
    if (s.dayOffset >= _rangeDays) return false;
    if (_selectedDept != 'all' && s.deptId != _selectedDept) return false;
    if (_selectedEmp != 'all' && s.employeeId != _selectedEmp) return false;
    return true;
  }

  void _onSort(String col) {
    setState(() {
      if (_sortColumn == col) {
        _sortDir = -_sortDir;
      } else {
        _sortColumn = col;
        _sortDir = (col == 'name' || col == 'dept') ? 1 : -1;
      }
    });
  }

  String get _currentTimestampString {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Unified theme colors
    final plane = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAF9F5);
    final surface = isDark ? const Color(0xFF1A1A19) : const Color(0xFFFCFCFB);
    final surface2 = isDark ? const Color(0xFF242423) : const Color(0xFFF1F0EC);
    final ink = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B0B);
    final ink2 = isDark ? const Color(0xFFC3C2B7) : const Color(0xFF52514E);
    const muted = Color(0xFF898781);
    final border = isDark ? const Color(0x1AFFFFFF) : const Color(0x1A0B0B0B);
    final border2 = isDark ? const Color(0x2EFFFFFF) : const Color(0x290B0B0B);

    const s1 = Color(0xFF2A78D6); // Growing
    const s2 = Color(0xFFEB6834); // Harvest
    const s3 = Color(0xFF1BAF7A); // Maintenance
    const good = Color(0xFF0CA30C);
    const warning = Color(0xFFFAB219);
    const critical = Color(0xFFD03B3B);

    // Filter current dataset
    final filteredTasks = _allTasks.where(_taskMatches).toList();
    final filteredShifts = _allShifts.where(_shiftMatches).toList();

    final Widget bodyContent;
    if (_isLoading) {
      bodyContent = _buildLoadingState(ink2);
    } else if (_loadError != null) {
      bodyContent = _buildErrorState(ink, ink2, critical);
    } else {
      bodyContent = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isEmbedded ? 16 : 24,
        vertical: widget.isEmbedded ? 12 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              _buildHeader(ink, ink2, muted, border2),
              const SizedBox(height: 16),

              // 2. Filters
              _buildFilters(
                  surface, surface2, ink, ink2, muted, border, border2, s1),
              const SizedBox(height: 20),

              // 3. KPIs Cards
              _buildKpisGrid(filteredTasks, filteredShifts, surface, ink, ink2,
                  muted, border, good, warning, critical),
              const SizedBox(height: 20),

              // 4. Two Top Charts: Duration vs Plan & Completion Trend
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildJobDurationPanel(filteredTasks, surface,
                              ink, ink2, muted, border, s1, critical),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTrendPanel(filteredTasks, surface, ink,
                              ink2, muted, border, s1, s2, s3),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildJobDurationPanel(filteredTasks, surface, ink,
                            ink2, muted, border, s1, critical),
                        const SizedBox(height: 16),
                        _buildTrendPanel(filteredTasks, surface, ink, ink2,
                            muted, border, s1, s2, s3),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // 5. Break Time & Overtime Panel
              _buildBreakPanel(filteredShifts, surface, ink, ink2, muted,
                  border, s1, warning),
              const SizedBox(height: 16),

              // 6. Main Performance Table
              _buildTablePanel(
                  filteredTasks,
                  filteredShifts,
                  surface,
                  surface2,
                  ink,
                  ink2,
                  muted,
                  border,
                  border2,
                  s1,
                  good,
                  warning,
                  critical),
              const SizedBox(height: 16),

              // 7. Alone Worker Safety Section
              _buildSafetyPanel(filteredTasks, surface, surface2, ink, ink2,
                  muted, border, border2, good, warning, critical),
              const SizedBox(height: 16),

              // 8. Top Rooms Activity Section
              _buildTopRoomsPanel(
                  filteredTasks, surface, ink, ink2, muted, border),
              const SizedBox(height: 24),

              // 9. 3D Room Window Action / Issues & Alarms Section
              _buildWindowIssuesPanel(
                  surface, surface2, ink, ink2, muted, border, border2, critical, warning, good, s1),
              const SizedBox(height: 24),

              // 10. Schema & Architecture Mapping Note
              _buildSchemaMappingFooter(
                  surface, surface2, ink, ink2, muted, border),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
    }

    if (widget.isEmbedded) {
      return Container(color: plane, child: bodyContent);
    }

    return Scaffold(
      backgroundColor: plane,
      appBar: AppBar(
        title: Text(
          'Growing Performance Board',
          style:
              TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: ink),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: _isLoading ? null : _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: bodyContent,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Loading & Error States
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildLoadingState(Color ink2) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading performance data from database…',
                style: TextStyle(color: ink2, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Color ink, Color ink2, Color critical) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: critical, size: 32),
            const SizedBox(height: 12),
            Text('Failed to load performance data',
                style: TextStyle(
                    color: ink, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            Text(_loadError ?? '',
                style: TextStyle(color: ink2, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  1. Header
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(Color ink, Color ink2, Color muted, Color border2) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border2)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COSTA MUSHROOM M2 · GROWING & HARVEST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Growing Performance Board',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'Daily employee performance based on the Joblist — completion time, break time, and Alone Worker safety.',
                  style: TextStyle(fontSize: 14, color: ink2, height: 1.4),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.playlist_add_check, size: 16),
                label: const Text('Daily Job Plan',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A78D6),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GrowingDailyJobPlanScreen(),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: ink),
                tooltip: 'Refresh Data',
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      '${_rangeDays == 1 ? "Today's" : "$_rangeDays-Day"} Data · Updated $_currentTimestampString',
                      style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  2. Filters Bar
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFilters(Color surface, Color surface2, Color ink, Color ink2,
      Color muted, Color border, Color border2, Color s1) {
    final availableEmployees = _employees.where((e) {
      if (_selectedDept == 'all') return true;
      return e.deptId == _selectedDept;
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Range segment
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PERIOD',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: muted)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRangeBtn('Today', 1, surface, ink, ink2),
                    _buildRangeBtn('7 Days', 7, surface, ink, ink2),
                    _buildRangeBtn('30 Days', 30, surface, ink, ink2),
                  ],
                ),
              ),
            ],
          ),

          // Department Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DEPARTMENT',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: muted)),
              const SizedBox(width: 8),
              _buildDropdown(
                value: _selectedDept,
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All Departments')),
                  ..._departments.map(
                    (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedDept = v!;
                    _selectedEmp = 'all';
                  });
                },
                surface: surface,
                ink: ink,
                border2: border2,
              ),
            ],
          ),

          // Employee Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('EMPLOYEE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: muted)),
              const SizedBox(width: 8),
              _buildDropdown(
                value: _selectedEmp,
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All Employees')),
                  ...availableEmployees.map(
                    (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedEmp = v!);
                },
                surface: surface,
                ink: ink,
                border2: border2,
              ),
            ],
          ),

          // Job Type Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('JOB TYPE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: muted)),
              const SizedBox(width: 8),
              _buildDropdown(
                value: (_selectedJob == 'all' || _jobTypes.any((j) => j.id == _selectedJob))
                    ? _selectedJob
                    : 'all',
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All Job Types')),
                  ..._jobTypes.map(
                    (j) => DropdownMenuItem(value: j.id, child: Text(j.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedJob = v!);
                },
                surface: surface,
                ink: ink,
                border2: border2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeBtn(
      String title, int days, Color surface, Color ink, Color ink2) {
    final active = _rangeDays == days;
    return InkWell(
      onTap: () => setState(() => _rangeDays = days),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [
                  const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1))
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? ink : ink2,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required Color surface,
    required Color ink,
    required Color border2,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: ink),
          style:
              TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ink),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  3. KPIs Grid (6 Cards)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildKpisGrid(
    List<PerformanceTaskRecord> tasks,
    List<PerformanceShiftRecord> shifts,
    Color surface,
    Color ink,
    Color ink2,
    Color muted,
    Color border,
    Color good,
    Color warning,
    Color critical,
  ) {
    final doneCount = tasks.length;
    final onTimeCount = tasks.where((t) => t.onTime).length;
    final onTimePct =
        doneCount > 0 ? (onTimeCount / doneCount * 100).round() : 0;

    final avgActual = doneCount > 0
        ? (tasks.map((t) => t.actualMinutes).reduce((a, b) => a + b) /
                doneCount)
            .round()
        : 0;
    final avgPlan = doneCount > 0
        ? (tasks.map((t) => t.planMinutes).reduce((a, b) => a + b) / doneCount)
            .round()
        : 0;
    final diffPlanPct =
        avgPlan > 0 ? (((avgActual - avgPlan) / avgPlan) * 100).round() : 0;

    final totalExtraBreak =
        shifts.fold<double>(0, (sum, s) => sum + s.extraBreakMinutes).round();
    final extraBreakShifts =
        shifts.where((s) => s.extraBreakMinutes > 0).length;

    final soloTasks = tasks.where((t) => t.soloInfo != null).toList();
    final soloAlarms = soloTasks.where((t) => t.soloInfo!.isAlarm).length;
    final soloNoCheckout =
        soloTasks.where((t) => !t.soloInfo!.isCheckedOut).length;

    final totalOtHours =
        (shifts.fold<double>(0, (sum, s) => sum + s.overtimeHours) * 10)
                .round() /
            10;

    final onTimeColor =
        onTimePct >= 85 ? good : (onTimePct >= 70 ? warning : critical);
    final diffColor =
        diffPlanPct <= 0 ? good : (diffPlanPct <= 10 ? warning : critical);
    final breakColor = extraBreakShifts == 0
        ? good
        : (extraBreakShifts <= shifts.length * 0.3 ? warning : critical);
    final soloColor = soloAlarms == 0 ? good : critical;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMultiLine = constraints.maxWidth < 800;
          return GridView.count(
            crossAxisCount: isMultiLine ? 2 : 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: isMultiLine ? 1.8 : 1.3,
            children: [
              _buildKpiTile(
                  'JOBS COMPLETED',
                  '$doneCount',
                  '',
                  '${shifts.length} work shifts',
                  null,
                  ink,
                  ink2,
                  muted,
                  border),
              _buildKpiTile(
                  'ON-TIME RATE',
                  '$onTimePct',
                  '%',
                  '$onTimeCount/$doneCount jobs',
                  onTimeColor,
                  ink,
                  ink2,
                  muted,
                  border),
              _buildKpiTile(
                  'AVG DURATION / JOB',
                  '$avgActual',
                  'min',
                  '${diffPlanPct > 0 ? '+' : ''}$diffPlanPct% vs standard',
                  diffColor,
                  ink,
                  ink2,
                  muted,
                  border),
              _buildKpiTile(
                  'EXCESS BREAK TIME',
                  '$totalExtraBreak',
                  'min',
                  '$extraBreakShifts excess shifts',
                  breakColor,
                  ink,
                  ink2,
                  muted,
                  border),
              _buildKpiTile(
                  'ALONE WORKER ALERTS',
                  '$soloAlarms',
                  '',
                  '${soloTasks.length} sessions · $soloNoCheckout not checked out',
                  soloColor,
                  ink,
                  ink2,
                  muted,
                  border),
              _buildKpiTile('OVERTIME HOURS', '$totalOtHours', 'hrs',
                  'all personnel in period', null, ink, ink2, muted, border),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiTile(String title, String val, String unit, String sub,
      Color? dotColor, Color ink, Color ink2, Color muted, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: muted)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(val,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: ink)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(unit,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ink2)),
              ],
            ],
          ),
          Row(
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  sub,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: ink2,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  4. Panel 1: Duration vs Plan
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildJobDurationPanel(
      List<PerformanceTaskRecord> tasks,
      Color surface,
      Color ink,
      Color ink2,
      Color muted,
      Color border,
      Color s1,
      Color critical) {
    final jobs = _jobTypes
        .where((j) => j.id != 'alone_worker')
        .map((j) {
          final matching = tasks
              .where((t) => t.jobId.toLowerCase() == j.id.toLowerCase())
              .toList();
          // Supervisor/manager confirmed complete on time (onTimeOverride == true)
          // means the job completed within standard time in reality, so cap at planMinutes
          // and do not draw any Over Standard portion.
          final actualAvg = matching.isNotEmpty
              ? matching.map((t) {
                  if (t.onTimeOverride == true) {
                    return math.min(t.actualMinutes, t.planMinutes);
                  }
                  return t.actualMinutes;
                }).reduce((a, b) => a + b) /
                  matching.length
              : 0.0;
          return (
            j: j,
            count: matching.length,
            actual: actualAvg,
            plan: j.planMinutes
          );
        })
        .where((d) => d.count > 0)
        .toList();

    // Sort by difference actual - plan descending
    jobs.sort((a, b) => (b.actual - b.plan).compareTo(a.actual - a.plan));

    // Dynamic scale so any job duration fits cleanly without clipping
    final maxVal = jobs.fold<double>(
      75.0,
      (m, item) => math.max(m, math.max(item.actual, item.plan) * 1.15),
    );

    return _buildPanelContainer(
      surface: surface,
      border: border,
      title: 'Completion Time by Job Type',
      unit: 'min',
      subtitle:
          'Bar represents average actual time. Vertical line is planned standard. Over-standard portion is highlighted in warning color.',
      legend: [
        _buildLegendItem(s1, 'Within Standard', ink2),
        _buildLegendItem(critical, 'Over Standard', ink2),
        _buildLegendLineItem(ink, 'Planned Standard', ink2),
      ],
      child: jobs.isEmpty
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No data matching filters.',
                      style: TextStyle(color: muted))))
          : Column(
              children: jobs.map((item) {
                final over = item.actual > item.plan;
                final inPlanPortion =
                    (item.actual > item.plan ? item.plan : item.actual) /
                        maxVal;
                final overPortion =
                    over ? (item.actual - item.plan) / maxVal : 0.0;
                final planLinePos = (item.plan / maxVal).clamp(0.0, 1.0);
                final jobColor = _colorFromHex(item.j.color, fallback: s1);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          item.j.name,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ink),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final w = box.maxWidth;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Background bar
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: ink.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                // In-plan bar
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: w * inPlanPortion,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: jobColor,
                                      borderRadius: BorderRadius.horizontal(
                                        left: const Radius.circular(4),
                                        right: over
                                            ? Radius.zero
                                            : const Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                // Over-plan bar
                                if (over)
                                  Positioned(
                                    left: w * inPlanPortion,
                                    top: 0,
                                    bottom: 0,
                                    width: w * overPortion,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: critical,
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                                right: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                // Plan vertical line
                                Positioned(
                                  left: w * planLinePos,
                                  top: -4,
                                  bottom: -4,
                                  child: Container(
                                    width: 2,
                                    color: ink,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${item.actual.round()}′',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: over ? critical : ink2),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  4. Panel 2: Trend Panel
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTrendPanel(
      List<PerformanceTaskRecord> tasks,
      Color surface,
      Color ink,
      Color ink2,
      Color muted,
      Color border,
      Color s1,
      Color s2,
      Color s3) {
    final now = DateTime.now();
    final days = List.generate(_rangeDays, (i) {
      final off = _rangeDays - 1 - i;
      final date = now.subtract(Duration(days: off));
      final dayTasks = tasks.where((t) => t.dayOffset == off).toList();
      final gCount = dayTasks.where((t) => t.deptId == 'growing').length;
      final hCount = dayTasks.where((t) => t.deptId == 'harvest').length;
      final mCount = dayTasks.where((t) => t.deptId == 'maintenance').length;
      return (
        date: date,
        total: dayTasks.length,
        growing: gCount,
        harvest: hCount,
        maint: mCount,
      );
    });

    final maxVal =
        days.fold<int>(1, (m, d) => d.total > m ? d.total : m).toDouble();

    return _buildPanelContainer(
      surface: surface,
      border: border,
      title: 'Jobs Completed by Day',
      unit: 'number of jobs · by department',
      subtitle:
          'Actual closed work volume during the period, broken down by department.',
      legend: [
        _buildLegendItem(s1, 'Growing', ink2),
        _buildLegendItem(s2, 'Harvest', ink2),
        _buildLegendItem(s3, 'Maintenance', ink2),
      ],
      child: SizedBox(
        height: 220,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days.map((d) {
            final isSun = d.date.weekday == 7;
            final gH = maxVal > 0 ? (d.growing / maxVal) * 140 : 0.0;
            final hH = maxVal > 0 ? (d.harvest / maxVal) * 140 : 0.0;
            final mH = maxVal > 0 ? (d.maint / maxVal) * 140 : 0.0;

            final dayLabel =
                '${d.date.day.toString().padLeft(2, '0')}/${d.date.month.toString().padLeft(2, '0')}';

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (d.total > 0)
                      Text('${d.total}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ink2))
                    else
                      Text(isSun ? 'Off' : '0',
                          style: TextStyle(fontSize: 10, color: muted)),
                    const SizedBox(height: 4),
                    if (d.total > 0)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (mH > 0)
                              Container(
                                  width: double.infinity,
                                  height: mH,
                                  color: s3),
                            if (hH > 0)
                              Container(
                                  width: double.infinity,
                                  height: hH,
                                  color: s2),
                            if (gH > 0)
                              Container(
                                  width: double.infinity,
                                  height: gH,
                                  color: s1),
                          ],
                        ),
                      )
                    else
                      Container(height: 2, color: border),
                    const SizedBox(height: 6),
                    Text(dayLabel,
                        style: TextStyle(fontSize: 10, color: muted)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  5. Panel 3: Break Time Panel
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBreakPanel(
      List<PerformanceShiftRecord> shifts,
      Color surface,
      Color ink,
      Color ink2,
      Color muted,
      Color border,
      Color s1,
      Color warning) {
    final emps = _employees
        .where((e) {
          if (_selectedDept != 'all' && e.deptId != _selectedDept) return false;
          if (_selectedEmp != 'all' && e.id != _selectedEmp) return false;
          return true;
        })
        .map((e) {
          final matching = shifts.where((s) => s.employeeId == e.id).toList();
          final count = matching.length;
          final avgTaken = count > 0
              ? matching
                      .map((s) => s.takenBreakMinutes)
                      .reduce((a, b) => a + b) /
                  count
              : 0.0;
          return (emp: e, count: count, taken: avgTaken, allowed: 30.0);
        })
        .where((d) => d.count > 0)
        .toList();

    emps.sort((a, b) => b.taken.compareTo(a.taken));

    return _buildPanelContainer(
      surface: surface,
      border: border,
      title: 'Break Time & Overtime',
      unit: 'min/shift · period average',
      subtitle:
          'Break taken vs standard 30-min allowance per shift. Excess break time is deducted from payable hours.',
      legend: [
        _buildLegendItem(s1, 'Break within limit', ink2),
        _buildLegendItem(warning, 'Break exceeding limit', ink2),
        _buildLegendLineItem(ink, 'Allowed limit (30′)', ink2),
      ],
      child: emps.isEmpty
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No shifts matching filters.',
                      style: TextStyle(color: muted))))
          : Column(
              children: emps.map((item) {
                final over = item.taken > item.allowed;
                const maxVal = 55.0;
                final inPlanPortion =
                    (item.taken > item.allowed ? item.allowed : item.taken) /
                        maxVal;
                final overPortion =
                    over ? (item.taken - item.allowed) / maxVal : 0.0;
                final planLinePos = (item.allowed / maxVal).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          item.emp.name,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ink),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final w = box.maxWidth;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: ink.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: w * inPlanPortion,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: s1,
                                      borderRadius: BorderRadius.horizontal(
                                        left: const Radius.circular(4),
                                        right: over
                                            ? Radius.zero
                                            : const Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                if (over)
                                  Positioned(
                                    left: w * inPlanPortion,
                                    top: 0,
                                    bottom: 0,
                                    width: w * overPortion,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: warning,
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                                right: Radius.circular(4)),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: w * planLinePos,
                                  top: -4,
                                  bottom: -4,
                                  child: Container(
                                    width: 2,
                                    color: ink,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${item.taken.round()}′',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ink2),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  6. Panel 4: Main Sortable Table
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTablePanel(
    List<PerformanceTaskRecord> tasks,
    List<PerformanceShiftRecord> shifts,
    Color surface,
    Color surface2,
    Color ink,
    Color ink2,
    Color muted,
    Color border,
    Color border2,
    Color s1,
    Color good,
    Color warning,
    Color critical,
  ) {
    final summaries = _employees
        .where((e) {
          if (_selectedDept != 'all' && e.deptId != _selectedDept) return false;
          if (_selectedEmp != 'all' && e.id != _selectedEmp) return false;
          return true;
        })
        .map((e) {
          final userTasks = tasks.where((t) => t.employeeId == e.id).toList();
          final userShifts = shifts.where((s) => s.employeeId == e.id).toList();

          final nJobs = userTasks.length;
          final onTimeCount = userTasks.where((t) => t.onTime).length;
          final onTimePct = nJobs > 0 ? (onTimeCount / nJobs * 100) : 0.0;

          final avgActual = nJobs > 0
              ? (userTasks.map((t) => t.actualMinutes).reduce((a, b) => a + b) /
                  nJobs)
              : 0.0;
          final avgPlan = nJobs > 0
              ? (userTasks.map((t) => t.planMinutes).reduce((a, b) => a + b) /
                  nJobs)
              : 0.0;
          final vsPlan =
              avgPlan > 0 ? ((avgActual - avgPlan) / avgPlan * 100) : 0.0;

          final avgBreak = userShifts.isNotEmpty
              ? (userShifts
                      .map((s) => s.takenBreakMinutes)
                      .reduce((a, b) => a + b) /
                  userShifts.length)
              : 0.0;
          final totalOt =
              (userShifts.fold<double>(0, (sum, s) => sum + s.overtimeHours) *
                          10)
                      .round() /
                  10;

          final soloTasks = userTasks.where((t) => t.soloInfo != null).toList();
          final soloAlarms = soloTasks.where((t) => t.soloInfo!.isAlarm).length;

          final dept =
              _departments.firstWhere(
            (d) => d.id == e.deptId,
            orElse: () => _departments.first,
          );

          return EmployeePerformanceSummary(
            employeeId: e.id,
            name: e.name,
            role: e.role,
            deptId: e.deptId,
            deptName: dept.name,
            deptColorValue: dept.colorValue,
            totalJobs: nJobs,
            onTimePercent: onTimePct,
            avgMinutesPerJob: avgActual,
            vsPlanPercent: vsPlan,
            avgBreakTakenMinutes: avgBreak,
            allowedBreakMinutes: 30.0,
            totalOvertimeHours: totalOt,
            soloAlarmCount: soloAlarms,
            soloTotalSessions: soloTasks.length,
            totalShifts: userShifts.length,
          );
        })
        .where((d) => d.totalJobs > 0 || d.totalShifts > 0)
        .toList();

    // Sort table
    summaries.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'name':
          cmp = a.name.compareTo(b.name);
          break;
        case 'dept':
          cmp = a.deptName.compareTo(b.deptName);
          break;
        case 'jobs':
          cmp = a.totalJobs.compareTo(b.totalJobs);
          break;
        case 'onTime':
          cmp = a.onTimePercent.compareTo(b.onTimePercent);
          break;
        case 'avgMin':
          cmp = a.avgMinutesPerJob.compareTo(b.avgMinutesPerJob);
          break;
        case 'vsPlan':
          cmp = a.vsPlanPercent.compareTo(b.vsPlanPercent);
          break;
        case 'break':
          cmp = a.avgBreakTakenMinutes.compareTo(b.avgBreakTakenMinutes);
          break;
        case 'otH':
          cmp = a.totalOvertimeHours.compareTo(b.totalOvertimeHours);
          break;
        case 'alarms':
          cmp = a.soloAlarmCount.compareTo(b.soloAlarmCount);
          break;
      }
      return cmp * _sortDir;
    });

    return _buildPanelContainer(
      surface: surface,
      border: border,
      title: 'Employee Performance Table',
      unit: 'click column headers to sort',
      subtitle:
          'Detailed tabular breakdown for precise metrics across all operational parameters.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          horizontalMargin: 12,
          columnSpacing: 24,
          columns: [
            _buildSortableHeader('EMPLOYEE', 'name', muted, ink),
            _buildSortableHeader('DEPARTMENT', 'dept', muted, ink),
            _buildSortableHeader('JOBS', 'jobs', muted, ink, isNum: true),
            _buildSortableHeader('ON-TIME', 'onTime', muted, ink, isNum: true),
            _buildSortableHeader('AVG MIN/JOB', 'avgMin', muted, ink,
                isNum: true),
            _buildSortableHeader('VS PLAN', 'vsPlan', muted, ink,
                isNum: true),
            _buildSortableHeader('BREAK/SHIFT', 'break', muted, ink),
            _buildSortableHeader('OT (HRS)', 'otH', muted, ink, isNum: true),
            _buildSortableHeader('SAFETY', 'alarms', muted, ink, isNum: true),
          ],
          rows: summaries.map((row) {
            final onPillColor = row.onTimePercent >= 85
                ? good
                : (row.onTimePercent >= 70 ? warning : critical);
            final vsPillColor = row.vsPlanPercent <= 0
                ? good
                : (row.vsPlanPercent <= 10 ? warning : critical);
            final vsTxt =
                '${row.vsPlanPercent > 0 ? '+' : ''}${row.vsPlanPercent.round()}%';
            final breakOver =
                row.avgBreakTakenMinutes > row.allowedBreakMinutes;

            return DataRow(
              cells: [
                // Employee
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(row.deptColorValue),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(row.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: ink)),
                          Text(row.role,
                              style: TextStyle(fontSize: 11, color: muted)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Department
                DataCell(Text(row.deptName,
                    style: TextStyle(fontSize: 13, color: ink))),
                // Jobs count
                DataCell(Text('${row.totalJobs}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ink))),
                // On-Time %
                DataCell(_buildPillBadge(
                    '${row.onTimePercent.round()}%', onPillColor)),
                // Avg min/job
                DataCell(Text('${row.avgMinutesPerJob.round()}',
                    style: TextStyle(fontSize: 13, color: ink))),
                // Vs Plan
                DataCell(_buildPillBadge(vsTxt, vsPillColor)),
                // Break / Shift
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        child: Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                  color: surface2,
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                            FractionallySizedBox(
                              widthFactor: (row.avgBreakTakenMinutes / 50)
                                  .clamp(0.0, 1.0),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: breakOver ? warning : s1,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${row.avgBreakTakenMinutes.round()}′',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ink)),
                    ],
                  ),
                ),
                // OT (Hours)
                DataCell(Text('${row.totalOvertimeHours}',
                    style: TextStyle(fontSize: 13, color: ink))),
                // Safety
                DataCell(
                  row.soloTotalSessions == 0
                      ? Text('—', style: TextStyle(color: muted))
                      : (row.soloAlarmCount == 0
                          ? _buildPillBadge(
                              '✓ ${row.soloTotalSessions} sessions', good)
                          : _buildPillBadge(
                              '⚠ ${row.soloAlarmCount}/${row.soloTotalSessions}',
                              critical)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  DataColumn _buildSortableHeader(
      String label, String colKey, Color muted, Color ink,
      {bool isNum = false}) {
    final active = _sortColumn == colKey;
    final arrow = active ? (_sortDir > 0 ? ' ↑' : ' ↓') : ' ↕';

    return DataColumn(
      numeric: isNum,
      label: InkWell(
        onTap: () => _onSort(colKey),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.9,
                color: active ? ink : muted,
              ),
            ),
            Text(
              arrow,
              style: TextStyle(
                fontSize: 12,
                color: active ? ink : muted.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  7. Panel 5: Alone Worker Safety Grid
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSafetyPanel(
    List<PerformanceTaskRecord> tasks,
    Color surface,
    Color surface2,
    Color ink,
    Color ink2,
    Color muted,
    Color border,
    Color border2,
    Color good,
    Color warning,
    Color critical,
  ) {
    final soloTasks = tasks.where((t) => t.soloInfo != null).toList();
    soloTasks.sort((a, b) {
      final ka = a.soloInfo!.isAlarm ? 0 : 1;
      final kb = b.soloInfo!.isAlarm ? 0 : 1;
      if (ka != kb) return ka.compareTo(kb);
      return a.dayOffset.compareTo(b.dayOffset);
    });

    final displaySolo = soloTasks.take(6).toList();
    final alarmsCount = soloTasks.where((t) => t.soloInfo!.isAlarm).length;

    return _buildPanelContainer(
      surface: surface,
      border: border,
      title: 'Alone Worker Safety Monitoring',
      unit: soloTasks.isNotEmpty
          ? '$alarmsCount alerts / ${soloTasks.length} sessions'
          : '',
      subtitle:
          'Direct monitoring of solo work sessions in grow rooms: duration limits and environmental gas levels (CO/CO₂).',
      child: displaySolo.isEmpty
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No Alone Worker sessions in this period.',
                      style: TextStyle(color: muted))))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMulti = constraints.maxWidth > 700;
                return GridView.count(
                  crossAxisCount: isMulti ? 3 : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isMulti ? 1.55 : 2.2,
                  children: displaySolo.map((r) {
                    final s = r.soloInfo!;
                    final emp =
                        _employees.firstWhere(
                      (e) => e.id == r.employeeId,
                      orElse: () =>
                          _employees.first,
                    );
                    final over = s.insideMinutes > s.limitMinutes;
                    final pct =
                        (s.insideMinutes / s.limitMinutes).clamp(0.0, 1.0);
                    final hiCO = s.coPpm > 85;
                    final hiCO2 = s.co2Ppm > 4500;
                    final statusColor =
                        s.isAlarm ? critical : (pct > 0.85 ? warning : good);

                    final reasons = <String>[];
                    if (over) reasons.add('Over time');
                    if (hiCO) reasons.add('High CO');
                    if (hiCO2) reasons.add('High CO₂');
                    if (!s.isCheckedOut) reasons.add('Not checked out');

                    final pillText = s.isAlarm
                        ? '⚠ ${reasons.join(' · ')}'
                        : (pct > 0.85 ? '◐ Almost out of time' : '✓ Safe');

                    final startH = r.startMinutesOfDay ~/ 60;
                    final startM = r.startMinutesOfDay % 60;
                    final timeStr =
                        '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}';
                    final dateStr =
                        '${r.date.day.toString().padLeft(2, '0')}/${r.date.month.toString().padLeft(2, '0')}';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: s.isAlarm ? critical : border2,
                          width: s.isAlarm ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Room ${r.roomNumber}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: ink)),
                              _buildPillBadge(pillText, statusColor),
                            ],
                          ),
                          Text('${emp.name} · $dateStr · at $timeStr',
                              style: TextStyle(fontSize: 11.5, color: ink2)),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: surface2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(statusColor),
                              minHeight: 6,
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                  'Inside room: ${s.insideMinutes.round()}′ / ${s.limitMinutes.round()}′',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: over ? critical : ink2,
                                      fontWeight: over
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                              Text('CO: ${s.coPpm} ppm',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: hiCO ? critical : ink2,
                                      fontWeight: hiCO
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                              Text('CO₂: ${s.co2Ppm.round()} ppm',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: hiCO2 ? critical : ink2,
                                      fontWeight: hiCO2
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                              Text(
                                  s.isCheckedOut
                                      ? 'Checked out'
                                      : 'Not checked out',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: s.isCheckedOut ? good : critical,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  8. Panel 6: Top Rooms Activity
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTopRoomsPanel(List<PerformanceTaskRecord> tasks, Color surface,
      Color ink, Color ink2, Color muted, Color border) {
    final Map<int, int> roomCounts = {};
    for (final t in tasks) {
      roomCounts[t.roomNumber] = (roomCounts[t.roomNumber] ?? 0) + 1;
    }

    final topRooms =
        roomCounts.entries.map((e) => (room: e.key, count: e.value)).toList();
    topRooms.sort((a, b) => b.count.compareTo(a.count));
    final displayTop = topRooms.take(10).toList();
    final maxVal =
        displayTop.isNotEmpty ? displayTop.first.count.toDouble() : 1.0;

    return _buildPanelContainer(
      surface: surface,
      border: border,
      title: 'Top Active Rooms',
      unit: 'jobs / room',
      subtitle:
          'Ranking of mushroom grow rooms by total job activity in the selected period.',
      child: displayTop.isEmpty
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No room activity data available.',
                      style: TextStyle(color: muted))))
          : Column(
              children: displayTop.map((item) {
                final ratio = (item.count / maxVal).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text('Room ${item.room}',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: ink),
                            textAlign: TextAlign.right),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 14,
                                width: box.maxWidth * ratio,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A78D6)
                                      .withValues(alpha: 0.4 + 0.6 * ratio),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 28,
                        child: Text('${item.count}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ink2)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  9. 3D Room Window Action / Issues & Alarms Panel
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildWindowIssuesPanel(
    Color surface,
    Color surface2,
    Color ink,
    Color ink2,
    Color muted,
    Color border,
    Color border2,
    Color critical,
    Color warning,
    Color good,
    Color s1,
  ) {
    final filtered = _windowIssues.where((issue) {
      if (_selectedIssueCategoryFilter != 'all' &&
          issue.category.name != _selectedIssueCategoryFilter) {
        return false;
      }
      if (_selectedIssueStatusFilter != 'all' &&
          issue.status != _selectedIssueStatusFilter) {
        return false;
      }
      return true;
    }).toList();

    final totalCount = _windowIssues.length;
    final openCount = _windowIssues.where((i) => i.status == 'open').length;
    final inProgressCount =
        _windowIssues.where((i) => i.status == 'in_progress').length;
    final resolvedCount =
        _windowIssues.where((i) => i.status == 'resolved').length;
    final criticalCount =
        _windowIssues.where((i) => i.severity == 'critical').length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Button to open 3D model
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: s1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.view_in_ar_rounded, size: 22, color: s1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '3D Grow Room Window Actions & Alarms',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ink),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: critical.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: critical.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '$openCount open',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: critical,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Monitor and coordinate disease, safety, QA, and maintenance alerts across 3D room windows.',
                      style: TextStyle(fontSize: 12.5, color: ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GrowRoom3dScreen(
                        initialRoomName: 'Room 33',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.view_in_ar, size: 16),
                label: const Text('Open 3D Model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: s1,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Summary Metric Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildIssueMetricBadge('Total Issues', '$totalCount', ink2, surface2, border),
              _buildIssueMetricBadge('Open', '$openCount', critical,
                  critical.withValues(alpha: 0.1), critical.withValues(alpha: 0.3)),
              _buildIssueMetricBadge('In Progress', '$inProgressCount', warning,
                  warning.withValues(alpha: 0.1), warning.withValues(alpha: 0.3)),
              _buildIssueMetricBadge('Resolved', '$resolvedCount', good,
                  good.withValues(alpha: 0.1), good.withValues(alpha: 0.3)),
              _buildIssueMetricBadge('Critical', '$criticalCount', critical,
                  critical.withValues(alpha: 0.15), critical.withValues(alpha: 0.5)),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: border, height: 1),
          const SizedBox(height: 14),

          // Filters Row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Category:',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: ink2)),
                  const SizedBox(width: 6),
                  _buildIssueFilterChip('All', 'all', _selectedIssueCategoryFilter,
                      (val) => setState(() => _selectedIssueCategoryFilter = val),
                      surface2, ink, s1, border),
                  _buildIssueFilterChip('🦠 Disease', 'disease', _selectedIssueCategoryFilter,
                      (val) => setState(() => _selectedIssueCategoryFilter = val),
                      surface2, ink, critical, border),
                  _buildIssueFilterChip('⚠️ Safety', 'safety', _selectedIssueCategoryFilter,
                      (val) => setState(() => _selectedIssueCategoryFilter = val),
                      surface2, ink, warning, border),
                  _buildIssueFilterChip('🔍 QA', 'qa', _selectedIssueCategoryFilter,
                      (val) => setState(() => _selectedIssueCategoryFilter = val),
                      surface2, ink, s1, border),
                  _buildIssueFilterChip('⏱️ Operation', 'working', _selectedIssueCategoryFilter,
                      (val) => setState(() => _selectedIssueCategoryFilter = val),
                      surface2, ink, const Color(0xFF9C27B0), border),
                  _buildIssueFilterChip('🛠️ Maintenance', 'maintenance', _selectedIssueCategoryFilter,
                      (val) => setState(() => _selectedIssueCategoryFilter = val),
                      surface2, ink, const Color(0xFF1BAF7A), border),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Status:',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: ink2)),
                  const SizedBox(width: 6),
                  _buildIssueFilterChip('All', 'all', _selectedIssueStatusFilter,
                      (val) => setState(() => _selectedIssueStatusFilter = val),
                      surface2, ink, s1, border),
                  _buildIssueFilterChip('🔴 Open', 'open', _selectedIssueStatusFilter,
                      (val) => setState(() => _selectedIssueStatusFilter = val),
                      surface2, ink, critical, border),
                  _buildIssueFilterChip('🟡 In Progress', 'in_progress', _selectedIssueStatusFilter,
                      (val) => setState(() => _selectedIssueStatusFilter = val),
                      surface2, ink, warning, border),
                  _buildIssueFilterChip('🟢 Resolved', 'resolved', _selectedIssueStatusFilter,
                      (val) => setState(() => _selectedIssueStatusFilter = val),
                      surface2, ink, good, border),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Issues List / Empty State
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: surface2.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 36, color: good),
                  const SizedBox(height: 8),
                  Text(
                    'No issues or alerts matching filter.',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Alerts logged from the 3D grow room model will automatically appear here.',
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final issue = filtered[index];
                return _buildWindowIssueCard(
                  issue: issue,
                  surface: surface,
                  surface2: surface2,
                  ink: ink,
                  ink2: ink2,
                  muted: muted,
                  border: border,
                  critical: critical,
                  warning: warning,
                  good: good,
                  s1: s1,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildIssueMetricBadge(
    String label,
    String value,
    Color textColor,
    Color bg,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w500, color: textColor),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelected,
    Color surface2,
    Color ink,
    Color activeColor,
    Color border,
  ) {
    final isSelected = value == currentValue;
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 4),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.15)
                : surface2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? activeColor : border,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowIssueCard({
    required WindowIssueReport issue,
    required Color surface,
    required Color surface2,
    required Color ink,
    required Color ink2,
    required Color muted,
    required Color border,
    required Color critical,
    required Color warning,
    required Color good,
    required Color s1,
  }) {
    final (statusColor, statusLabel) =
        _getStatusInfo(issue.status, critical, warning, good);
    final categoryColor =
        _getIssueCategoryColor(issue.category, critical, warning, s1);
    final isResolved = issue.status == 'resolved';

    final createdDateStr =
        '${issue.createdAt.day.toString().padLeft(2, '0')}/${issue.createdAt.month.toString().padLeft(2, '0')} ${issue.createdAt.hour.toString().padLeft(2, '0')}:${issue.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface2.withValues(alpha: isResolved ? 0.3 : 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: issue.severity == 'critical' && !isResolved
              ? critical.withValues(alpha: 0.5)
              : border,
          width: issue.severity == 'critical' && !isResolved ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top line: Location & Tags
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Room & Window location badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: s1.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view_rounded, size: 13, color: s1),
                    const SizedBox(width: 5),
                    Text(
                      '${issue.roomName} • Window: ${issue.windowCode}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: s1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border:
                      Border.all(color: categoryColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${issue.category.iconEmoji} ${issue.category.displayName}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Severity badge
              if (issue.severity == 'critical' || issue.severity == 'high')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: critical.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    issue.severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: critical,
                    ),
                  ),
                ),

              const Spacer(),

              // Status Dropdown / Action
              PopupMenuButton<String>(
                initialValue: issue.status,
                tooltip: 'Change status',
                onSelected: (newStatus) async {
                  await _windowActionService.updateIssueStatus(
                      issue.id, newStatus);
                  final refreshed = await _windowActionService.getIssues();
                  if (mounted) {
                    setState(() {
                      _windowIssues = refreshed;
                    });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.radio_button_checked,
                            size: 15, color: Color(0xFFD03B3B)),
                        SizedBox(width: 8),
                        Text('Open'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'in_progress',
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            size: 15, color: Color(0xFFFAB219)),
                        SizedBox(width: 8),
                        Text('In Progress'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'resolved',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: Color(0xFF0CA30C)),
                        SizedBox(width: 8),
                        Text('Resolved'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down,
                          size: 16, color: statusColor),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Title & Description
          Text(
            issue.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: ink,
              decoration: isResolved ? TextDecoration.lineThrough : null,
            ),
          ),
          if (issue.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              issue.description,
              style: TextStyle(fontSize: 12, color: ink2),
            ),
          ],

          const SizedBox(height: 10),

          // Telemetry snapshot chips row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _buildTelemetryItem('🌡️ Temp',
                    '${issue.temperature.toStringAsFixed(1)}°C', ink2),
                _buildTelemetryItem('💧 Humidity',
                    '${issue.humidity.toStringAsFixed(0)}% RH', ink2),
                _buildTelemetryItem(
                    '💨 CO₂', '${issue.co2.toStringAsFixed(0)} ppm', ink2),
                _buildTelemetryItem('🌱 Casing',
                    '${issue.casingTemp.toStringAsFixed(1)}°C', ink2),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Footer: Reporter, Date and "View in 3D" button
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: muted),
              const SizedBox(width: 4),
              Text(
                '${issue.reporterName} • $createdDateStr',
                style: TextStyle(fontSize: 11.5, color: muted),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GrowRoom3dScreen(
                        initialRoomName: issue.roomName,
                        initialSelectedWindowCode: issue.windowCode,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.view_in_ar, size: 14),
                label: const Text('View in 3D'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: s1,
                  side: BorderSide(color: s1.withValues(alpha: 0.6)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(String label, String val, Color ink2) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: ink2),
        ),
        Text(
          val,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink2),
        ),
      ],
    );
  }

  Color _getIssueCategoryColor(
    WindowIssueCategory category,
    Color critical,
    Color warning,
    Color s1,
  ) {
    switch (category) {
      case WindowIssueCategory.disease:
        return critical;
      case WindowIssueCategory.safety:
        return warning;
      case WindowIssueCategory.qa:
        return const Color(0xFF2A78D6);
      case WindowIssueCategory.working:
        return const Color(0xFF9C27B0);
      case WindowIssueCategory.maintenance:
        return const Color(0xFF1BAF7A);
    }
  }

  (Color, String) _getStatusInfo(
    String status,
    Color critical,
    Color warning,
    Color good,
  ) {
    switch (status) {
      case 'in_progress':
        return (warning, 'In Progress');
      case 'resolved':
        return (good, 'Resolved');
      case 'open':
      default:
        return (critical, 'Open');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  10. Schema Mapping & Architecture Footer
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSchemaMappingFooter(Color surface, Color surface2, Color ink,
      Color ink2, Color muted, Color border) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, size: 18, color: ink),
              const SizedBox(width: 8),
              Text('Database Schema & Data Source Mapping',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The Growing Performance Board reads live from the local iZiiApp database (Drift/SQLite):\n'
            '• mushroom_jobs: job count, actual duration and on-time rate (vs a fixed standard time per job type), room and Alone Worker gas levels/check-out status.\n'
            '• mushroom_daily_timesheets: shift check-in/out, break time taken, extra break and overtime hours.\n'
            '• mushroom_employees / mushroom_departments: the Department & Employee filters and the per-employee breakdown table.\n'
            'The planned/standard minutes per job type are a fixed operational reference (not stored in the database) since mushroom_jobs only records actual timestamps.',
            style: TextStyle(fontSize: 12, color: ink2, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Helper Containers & Legends
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPanelContainer({
    required Color surface,
    required Color border,
    required String title,
    required String unit,
    required String subtitle,
    List<Widget>? legend,
    required Widget child,
  }) {
    final ink = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF0B0B0B);
    final ink2 = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFC3C2B7)
        : const Color(0xFF52514E);
    const muted = Color(0xFF898781);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
              if (unit.isNotEmpty)
                Text(unit, style: const TextStyle(fontSize: 12, color: muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12.5, color: ink2)),
          if (legend != null && legend.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 6, children: legend),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, Color ink2) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: ink2)),
      ],
    );
  }

  Widget _buildLegendLineItem(Color color, String label, Color ink2) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 13,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: ink2)),
      ],
    );
  }
}
