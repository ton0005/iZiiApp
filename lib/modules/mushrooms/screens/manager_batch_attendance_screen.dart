// lib/modules/mushrooms/screens/manager_batch_attendance_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/izii_colors.dart';
import '../services/manager_attendance_service.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class ManagerBatchAttendanceScreen extends StatefulWidget {
  final bool isDark;
  const ManagerBatchAttendanceScreen({super.key, required this.isDark});

  @override
  State<ManagerBatchAttendanceScreen> createState() =>
      _ManagerBatchAttendanceScreenState();
}

class _ManagerBatchAttendanceScreenState
    extends State<ManagerBatchAttendanceScreen> {
  final ManagerAttendanceService _service = ManagerAttendanceService();

  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  DateTime? _customEffectiveTime; // null = use real-time now()
  final bool _useCustomTime = false;

  List<EmployeeAttendanceRecord> _allRecords = [];
  final Set<String> _selectedEmpIds = {};

  // Filter state
  String _searchQuery = '';
  final String _selectedDepartment = 'ALL';
  String _selectedTeam = 'ALL';
  AttendanceWorkState? _selectedStateFilter; // null = all

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final records = await _service.getDailyAttendanceList(
        targetDate: _selectedDate,
      );
      if (mounted) {
        setState(() {
          _allRecords = records;
          // Remove selected IDs if they are no longer in the list
          _selectedEmpIds.removeWhere(
            (id) => !records.any((r) => r.id == id),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load attendance records: $e', isError: true);
      }
    }
  }

  // --- Helpers for Filtering ---
  List<EmployeeAttendanceRecord> get _filteredRecords {
    return _allRecords.where((r) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = r.name.toLowerCase().contains(query);
        final matchId = r.id.toLowerCase().contains(query);
        if (!matchName && !matchId) return false;
      }

      // 2. Department
      if (_selectedDepartment != 'ALL' &&
          r.department.toUpperCase() != _selectedDepartment.toUpperCase()) {
        return false;
      }

      // 3. Team Color
      if (_selectedTeam != 'ALL' &&
          r.teamColor.toUpperCase() != _selectedTeam.toUpperCase()) {
        return false;
      }

      // 4. State Filter
      if (_selectedStateFilter != null && r.state != _selectedStateFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  // --- Helper Team Colors ---
  Color _getTeamColor(String teamColor) {
    switch (teamColor.toUpperCase()) {
      case 'PURPLE':
        return Colors.purple.shade600;
      case 'PEARL':
        return Colors.blueGrey.shade400;
      case 'IVORY':
        return const Color(0xFFD4AF37); // Warm gold/ivory
      case 'JADE':
        return Colors.teal.shade600;
      case 'SAPPHIRE':
        return Colors.blue.shade700;
      case 'AMBER':
        return Colors.amber.shade800;
      case 'PEACH':
        return Colors.deepOrange.shade300;
      case 'RUBY':
        return Colors.red.shade700;
      case 'VENUS':
        return Colors.pink.shade400;
      case 'LIME':
        return Colors.lightGreen.shade700;
      case 'BLACK':
        return Colors.grey.shade800;
      default:
        return Colors.indigo.shade500;
    }
  }

  DateTime get _effectiveTime {
    if (_useCustomTime && _customEffectiveTime != null) {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _customEffectiveTime!.hour,
        _customEffectiveTime!.minute,
      );
    }
    return DateTime.now();
  }

  // --- Batch Execution Dialog & Logic ---
  Future<void> _triggerBatchAction(String actionKey) async {
    if (_selectedEmpIds.isEmpty) {
      _showSnackBar('Please select at least 1 employee to proceed!', isError: true);
      return;
    }

    final selectedCount = _selectedEmpIds.length;
    String actionTitle = '';
    Color actionColor = Colors.blue;
    IconData actionIcon = Icons.check;

    switch (actionKey) {
      case 'CHECK_IN':
        actionTitle = 'Check In';
        actionColor = Colors.green.shade600;
        actionIcon = Icons.login_rounded;
        break;
      case 'START_BREAK':
        actionTitle = 'Start Break';
        actionColor = Colors.orange.shade700;
        actionIcon = Icons.coffee_rounded;
        break;
      case 'END_BREAK':
        actionTitle = 'End Break';
        actionColor = Colors.teal.shade600;
        actionIcon = Icons.timer_off_rounded;
        break;
      case 'CHECK_OUT':
        actionTitle = 'Check Out';
        actionColor = Colors.red.shade700;
        actionIcon = Icons.logout_rounded;
        break;
    }

    TimeOfDay chosenTime = TimeOfDay.fromDateTime(_effectiveTime);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final timeStr =
              '${chosenTime.hour.toString().padLeft(2, '0')}:${chosenTime.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: actionColor.withValues(alpha: 0.15),
                  child: Icon(actionIcon, color: actionColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Confirm $actionTitle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are about to perform $actionTitle for:',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: actionColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Employee count:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '$selectedCount personnel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: actionColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Effective time: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: chosenTime,
                        );
                        if (picked != null) {
                          setDlgState(() => chosenTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Confirm & Apply',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final targetTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      chosenTime.hour,
      chosenTime.minute,
    );

    final empList = _selectedEmpIds.toList();
    setState(() => _isLoading = true);

    try {
      BatchActionResult res;
      switch (actionKey) {
        case 'CHECK_IN':
          res = await _service.batchCheckIn(
            employeeIds: empList,
            effectiveTime: targetTimestamp,
          );
          break;
        case 'START_BREAK':
          res = await _service.batchStartBreak(
            employeeIds: empList,
            effectiveTime: targetTimestamp,
          );
          break;
        case 'END_BREAK':
          res = await _service.batchEndBreak(
            employeeIds: empList,
            effectiveTime: targetTimestamp,
          );
          break;
        case 'CHECK_OUT':
          res = await _service.batchCheckOut(
            employeeIds: empList,
            effectiveTime: targetTimestamp,
          );
          break;
        default:
          return;
      }

      _showSnackBar(res.summary, isSuccess: true);
      _selectedEmpIds.clear();
      await _loadData();
    } catch (e) {
      _showSnackBar('Error performing action: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : (isSuccess ? Icons.check_circle : Icons.info_outline),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError
            ? IZiiColors.error
            : (isSuccess ? Colors.green.shade700 : const Color(0xFF1E293B)),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Seed Demo 120+ Harvest Crew ---
  Future<void> _seedDemoCrew() async {
    setState(() => _isLoading = true);
    final count = await _service.generateLargeHarvestCrewIfFew();
    _showSnackBar('Prepared $count demo personnel across color teams for testing!', isSuccess: true);
    await _loadData();
  }

  // --- Show History Dialog ---
  void _showHistoryDialog() {
    final history = _service.recentHistory;
    final isDark = widget.isDark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Batch Action History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'No batch operations recorded in this session yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final item = history[i];
                    final timeStr = DateFormat('HH:mm:ss').format(item.timestamp);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.withValues(alpha: 0.15),
                        child: Text(
                          item.actionName.substring(0, 1),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      title: Text(
                        '${item.actionName} ($timeStr)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        item.summary,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final filtered = _filteredRecords;

    // Compute instant KPI metrics
    final totalCount = _allRecords.length;
    final workingCount = _allRecords
        .where((r) => r.state == AttendanceWorkState.working)
        .length;
    final onBreakCount = _allRecords
        .where((r) => r.state == AttendanceWorkState.onBreak)
        .length;
    final checkedOutCount = _allRecords
        .where((r) => r.state == AttendanceWorkState.checkedOut)
        .length;
    final notCheckedInCount = _allRecords
        .where((r) => r.state == AttendanceWorkState.notCheckedIn)
        .length;

    // List of available team colors
    final availableTeams = {'ALL', ..._allRecords.map((r) => r.teamColor)}.toList();

    return Scaffold(
      backgroundColor: isDark ? FarmColors.bgDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Batch Team Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Manager Portal • ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          // Date selection button
          IconButton(
            tooltip: 'Select date',
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadData();
              }
            },
          ),
          // History button
          IconButton(
            tooltip: 'Action history',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistoryDialog,
          ),
          // Seed demo crew button
          if (_allRecords.length < 50)
            IconButton(
              tooltip: 'Quickly seed 120+ demo crew (Harvest)',
              icon: const Icon(Icons.group_add_rounded, color: Colors.green),
              onPressed: _seedDemoCrew,
            ),
          // Refresh button
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. KPI Summary Cards
                _buildKpiHeader(
                  isDark: isDark,
                  total: totalCount,
                  working: workingCount,
                  onBreak: onBreakCount,
                  checkedOut: checkedOutCount,
                  notCheckedIn: notCheckedInCount,
                ),

                // 2. Toolbar (Search + Filters + Select All)
                _buildFilterToolbar(
                  isDark: isDark,
                  availableTeams: availableTeams,
                  filteredCount: filtered.length,
                ),

                // 3. Employee List
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final record = filtered[index];
                            final isSelected = _selectedEmpIds.contains(record.id);
                            return _buildEmployeeCard(
                              record: record,
                              isSelected: isSelected,
                              isDark: isDark,
                            );
                          },
                        ),
                ),
              ],
            ),
      // 4. Sticky Bottom Action Bar
      bottomSheet: _buildStickyActionBar(isDark),
    );
  }

  // --- Widget KPI Cards ---
  Widget _buildKpiHeader({
    required bool isDark,
    required int total,
    required int working,
    required int onBreak,
    required int checkedOut,
    required int notCheckedIn,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiChip(
              title: 'Total',
              count: total,
              color: Colors.blueGrey,
              isActive: _selectedStateFilter == null,
              onTap: () => setState(() => _selectedStateFilter = null),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              title: 'Working',
              count: working,
              color: Colors.green.shade600,
              isActive: _selectedStateFilter == AttendanceWorkState.working,
              onTap: () => setState(
                  () => _selectedStateFilter = AttendanceWorkState.working),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              title: 'On Break',
              count: onBreak,
              color: Colors.orange.shade700,
              isActive: _selectedStateFilter == AttendanceWorkState.onBreak,
              onTap: () => setState(
                  () => _selectedStateFilter = AttendanceWorkState.onBreak),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              title: 'Checked Out',
              count: checkedOut,
              color: Colors.blue.shade700,
              isActive: _selectedStateFilter == AttendanceWorkState.checkedOut,
              onTap: () => setState(
                  () => _selectedStateFilter = AttendanceWorkState.checkedOut),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              title: 'Not Checked In',
              count: notCheckedIn,
              color: Colors.grey.shade500,
              isActive: _selectedStateFilter == AttendanceWorkState.notCheckedIn,
              onTap: () => setState(() =>
                  _selectedStateFilter = AttendanceWorkState.notCheckedIn),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiChip({
    required String title,
    required int count,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 4,
              backgroundColor: color,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Filter Toolbar ---
  Widget _buildFilterToolbar({
    required bool isDark,
    required List<String> availableTeams,
    required int filteredCount,
  }) {
    final filtered = _filteredRecords;
    final allFilteredSelected = filtered.isNotEmpty &&
        filtered.every((r) => _selectedEmpIds.contains(r.id));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar + Team dropdown
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name, employee ID (EMP...)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Dropdown Team Filter
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTeam,
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    items: availableTeams.map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Row(
                          children: [
                            if (t != 'ALL') ...[
                              CircleAvatar(
                                radius: 5,
                                backgroundColor: _getTeamColor(t),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(t == 'ALL' ? 'All Teams' : 'Team $t'),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedTeam = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Select All button & Selection stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: allFilteredSelected,
                    onChanged: (check) {
                      setState(() {
                        if (check == true) {
                          for (var r in filtered) {
                            _selectedEmpIds.add(r.id);
                          }
                        } else {
                          for (var r in filtered) {
                            _selectedEmpIds.remove(r.id);
                          }
                        }
                      });
                    },
                  ),
                  Text(
                    allFilteredSelected
                        ? 'Deselect All'
                        : 'Select All ($filteredCount filtered)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_selectedEmpIds.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedEmpIds.clear()),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Employee Card ---
  Widget _buildEmployeeCard({
    required EmployeeAttendanceRecord record,
    required bool isSelected,
    required bool isDark,
  }) {
    final teamColor = _getTeamColor(record.teamColor);

    // State badge details
    String stateLabel = 'Not In';
    Color stateBg = Colors.grey.shade300;
    Color stateFg = Colors.grey.shade800;
    IconData stateIcon = Icons.hourglass_empty_rounded;

    switch (record.state) {
      case AttendanceWorkState.working:
        stateLabel = 'Working';
        stateBg = Colors.green.shade100;
        stateFg = Colors.green.shade800;
        stateIcon = Icons.work_rounded;
        break;
      case AttendanceWorkState.onBreak:
        stateLabel = 'On Break';
        stateBg = Colors.orange.shade100;
        stateFg = Colors.orange.shade900;
        stateIcon = Icons.coffee_rounded;
        break;
      case AttendanceWorkState.checkedOut:
        stateLabel = 'Checked Out';
        stateBg = Colors.blue.shade100;
        stateFg = Colors.blue.shade800;
        stateIcon = Icons.check_circle_rounded;
        break;
      case AttendanceWorkState.notCheckedIn:
        break;
    }

    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected
          ? Colors.blue.withValues(alpha: isDark ? 0.2 : 0.08)
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? Colors.blue
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedEmpIds.remove(record.id);
            } else {
              _selectedEmpIds.add(record.id);
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (_) {
                  setState(() {
                    if (isSelected) {
                      _selectedEmpIds.remove(record.id);
                    } else {
                      _selectedEmpIds.add(record.id);
                    }
                  });
                },
              ),

              // Avatar with Team Color indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: teamColor.withValues(alpha: 0.15),
                    child: Text(
                      record.name.isNotEmpty
                          ? record.name.split(' ').last.substring(0, 1)
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: teamColor,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: teamColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Employee Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        // State Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: stateBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(stateIcon, size: 12, color: stateFg),
                              const SizedBox(width: 4),
                              Text(
                                stateLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: stateFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          record.id,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  ${record.department} (${record.role})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        if (record.checkInTime != null)
                          Text(
                            'In: ${timeFormat.format(record.checkInTime!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                   ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        if (record.checkOutTime != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Out: ${timeFormat.format(record.checkOutTime!)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 56, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No employees match the current filters.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // --- Sticky Bottom Action Bar ---
  Widget _buildStickyActionBar(bool isDark) {
    final count = _selectedEmpIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.checklist_rounded, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      'Selected: $count employees',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: count > 0
                            ? Colors.blue
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Time: ${DateFormat('HH:mm').format(_effectiveTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 4 Primary action buttons
            Row(
              children: [
                // 1. Check In
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed:
                        count > 0 ? () => _triggerBatchAction('CHECK_IN') : null,
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text(
                      'Check In',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. Start Break
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed: count > 0
                        ? () => _triggerBatchAction('START_BREAK')
                        : null,
                    icon: const Icon(Icons.coffee_rounded, size: 16),
                    label: const Text(
                      'Start Break',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. End Break
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed: count > 0
                        ? () => _triggerBatchAction('END_BREAK')
                        : null,
                    icon: const Icon(Icons.timer_off_rounded, size: 16),
                    label: const Text(
                      'End Break',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 4. Check Out
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    onPressed: count > 0
                        ? () => _triggerBatchAction('CHECK_OUT')
                        : null,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text(
                      'Check Out',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
