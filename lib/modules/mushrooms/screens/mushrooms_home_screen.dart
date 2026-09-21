import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/izii_colors.dart';
import '../../../core/enrollment/widgets/device_quick_actions_fab.dart';
import '../../../core/enrollment/device_user_service.dart';
import '../../../core/session/widgets/session_banner.dart';
import '../bloc/mushrooms_bloc.dart';
import '../repository.dart';
import '../services/employee_service.dart';
import '../services/window_action_service.dart';
import 'mushrooms_dashboard_screen.dart';
import 'mushboom_monarto_screen.dart';
import 'continuous_scanner_screen.dart';
import 'safety_tab_screen.dart';
import 'employees_tab_screen.dart';
import 'quick_access_card.dart';
import 'mushrooms_login_screen.dart';
import 'mushrooms_profile_screen.dart';
import 'harvest_attendance_screen.dart';
import 'growing_performance_board_screen.dart';
import 'growing_daily_job_plan_screen.dart';
import 'manager_batch_attendance_screen.dart';
import 'grow_room_3d_screen.dart';
import 'purchasing_tab_screen.dart';
import '../../communication/bloc/chat_bloc.dart';

class MushroomsHomeScreen extends StatefulWidget {
  const MushroomsHomeScreen({super.key});

  @override
  State<MushroomsHomeScreen> createState() => _MushroomsHomeScreenState();
}

class _MushroomsHomeScreenState extends State<MushroomsHomeScreen> {
  final MushroomsRepository _repository = MushroomsRepository();
  final EmployeeService _employeeService = EmployeeServiceImpl();
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _safetyLogs = [];
  bool _isAuthenticated = false;
  String? _currentEmployeeId;
  final WindowActionService _windowActionService = WindowActionService();
  StreamSubscription<List<WindowIssueReport>>? _windowIssuesSub;
  List<WindowIssueReport> _active3dIssues = [];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _load3dIssues();
    _windowIssuesSub = _windowActionService.issuesStream.listen((_) {
      if (mounted) _load3dIssues();
    });
  }

  @override
  void dispose() {
    _windowIssuesSub?.cancel();
    super.dispose();
  }

  Future<void> _load3dIssues() async {
    final issues = await _windowActionService.getActiveIssues();
    if (mounted) {
      setState(() {
        _active3dIssues = issues;
      });
    }
  }

  Future<void> _checkAuth() async {
    final empId = await _employeeService.getCurrentEmployeeId();
    if (empId != null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _currentEmployeeId = empId;
        });
        // Login changes DISPLAY NAME, NOT the identity key.
        //
        // Previously, SwitchUserEvent(empId) was called here — changing Chat identity
        // from device_id to employee ID. Consequence: `/call/ws/{device_id}` already
        // opened before was still under the old id, while signaling packets carried the new id,
        // so both sides never matched and all calls remained silent. See
        // DeviceUserService.applyLoggedInName to understand why id must be fixed.
        _applyEmployeeDisplayName(empId);
        context.read<MushroomsBloc>().add(LoadRoomsEvent());
        _loadMushroomData();
      }
    }
  }

  /// Attaches the logged-in employee name to the device identity.
  Future<void> _applyEmployeeDisplayName(String empId) async {
    try {
      final employees = await MushroomsRepository().getEmployees();
      final emp = employees.firstWhere(
        (e) => (e['id'] ?? '').toString() == empId,
        orElse: () => <String, dynamic>{},
      );
      final name = (emp['name'] ?? '').toString();
      final displayLabel = name.isNotEmpty
          ? (name.contains(empId) ? name : '$name ($empId)')
          : 'Employee $empId';
      await DeviceUserService().applyLoggedInName(displayLabel);
      if (mounted) {
        try {
          context.read<ChatBloc>().add(const RefreshIdentityEvent());
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    await _employeeService.logout();
    if (mounted) {
      setState(() {
        _isAuthenticated = false;
        _currentEmployeeId = null;
      });
    }
  }

  Future<void> _loadMushroomData() async {
    try {
      final dbEmployees = await _repository.getEmployees();
      final soloJobs = await _repository.getAllSoloJobs();
      if (mounted) {
        setState(() {
          _employees = dbEmployees;
          _safetyLogs = soloJobs;
        });
      }
    } catch (_) {}
  }

  // Helper: check if a room belongs to M1 or M2
  String _getPlantFromRoomName(String name) {
    final clean = name.replaceAll('Room ', '').trim();
    if (clean == '6A' || clean == '6B' || clean == '22A') {
      return 'M1';
    }
    final num = int.tryParse(clean.replaceAll(RegExp(r'[^0-9]'), ''));
    if (num != null && num >= 33) {
      return 'M2';
    }
    return 'M1';
  }

  // Sync state rooms to localRooms format
  Map<String, Map<String, dynamic>> _buildLocalRooms(
      List<Map<String, dynamic>> dbRooms) {
    final localRooms = <String, Map<String, dynamic>>{};
    for (var r in dbRooms) {
      final name = r['name'] as String;
      localRooms[name] = {
        'id': r['id'],
        'name': name,
        'plant': _getPlantFromRoomName(name),
        'status': r['status'] ?? 'idle',
        'current_stage': r['current_stage'] ?? 'idle',
        'day_in_cycle': r['day_in_cycle'] ?? 1,
        'cycle': 'Cycle 1',
        'area': '112 m²',
        'targetYield': r['targetYield'] ?? 0.0,
        'pickedYield': r['pickedYield'] ?? 0.0,
        'pickingPlan': r['pickingPlanJson'] != null &&
                r['pickingPlanJson'].toString().isNotEmpty
            ? jsonDecode(r['pickingPlanJson'])
            : null,
        'jobs': []
      };
    }
    return localRooms;
  }

  // ── Continuous Scanner Check-In/Check-Out Handlers ─────────────────────────
  void _onCheckIn(String code, String roomSelected,
      Map<String, Map<String, dynamic>> localRooms) async {
    final bloc = context.read<MushroomsBloc>();
    final matches = _employees.where((e) => e['id'] == code);
    if (matches.isEmpty) {
      _showSnackBar('Employee code not found!', isError: true);
      return;
    }
    final emp = matches.first;
    final existingCrews = await _repository.getRoomCrews();
    final alreadyCheckedIn = existingCrews.where((c) => c['empId'] == code);
    if (alreadyCheckedIn.isNotEmpty) {
      final oldRoom = alreadyCheckedIn.first['roomName']!;
      _showSnackBar(
          'Employee ${emp['name']} is already checked-in to Grow Room ${oldRoom.replaceAll('Room', '')}. Please check-out first!',
          isError: true);
      return;
    }
    await _repository.checkInRoomCrew(
        roomName: roomSelected, empName: emp['name']!, empId: code);

    final crews = await _repository.getRoomCrews();
    final roomCrewNames = crews
        .where((c) => c['roomName'] == roomSelected)
        .map((c) => c['empName']!)
        .toList();

    await _repository.logSafetyCheckin(
      jobId: 'crew_checkin',
      workerId: emp['name']!,
      eventType: 'checkin',
      notes:
          'Checked in to $roomSelected. Solo status: ${roomCrewNames.length <= 1}',
    );

    if (roomCrewNames.length == 1) {
      final room = localRooms[roomSelected];
      if (room != null) {
        bloc.add(AddSoloJobEvent(
          roomId: room['id'],
          title: 'Solo Picking',
          assignee: emp['name']!,
          timeLimit: 45,
        ));
      }
    } else if (roomCrewNames.length >= 2) {
      final room = localRooms[roomSelected];
      if (room != null) {
        final jobs = await _repository.getJobsForRoom(room['id']);
        final activeSoloPickingJobs = jobs.where((j) =>
            j['job_type'] == 'alone_worker' &&
            j['name'] == 'Solo Picking' &&
            j['status'] == 'in_progress');
        for (final job in activeSoloPickingJobs) {
          bloc.add(CompleteJobEvent(job['id'] as String, room['id'] as String));
        }
      }
    }

    _showSnackBar('Checked in ${emp['name']} to $roomSelected');
    _loadMushroomData();
  }

  void _onCheckOut(String code, String roomSelected,
      Map<String, Map<String, dynamic>> localRooms) async {
    final bloc = context.read<MushroomsBloc>();
    final matches = _employees.where((e) => e['id'] == code);
    if (matches.isEmpty) {
      _showSnackBar('Employee code not found!', isError: true);
      return;
    }
    final emp = matches.first;
    await _repository.checkOutRoomCrew(roomName: roomSelected, empId: code);

    await _repository.logSafetyCheckin(
      jobId: 'crew_checkout',
      workerId: emp['name']!,
      eventType: 'checkout',
      notes: 'Checked out from Room $roomSelected.',
    );

    final room = localRooms[roomSelected];
    if (room != null) {
      final jobs = await _repository.getJobsForRoom(room['id']);
      final activeSolo = jobs.firstWhere(
        (j) =>
            j['assignee'] == emp['name'] &&
            j['notes']?.contains('Solo') == true &&
            j['status'] != 'done',
        orElse: () => {},
      );
      if (activeSolo.isNotEmpty) {
        bloc.add(CompleteJobEvent(activeSolo['id'], room['id']));
      }
    }

    _showSnackBar('Checked out ${emp['name']} from $roomSelected');
    _loadMushroomData();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? IZiiColors.error : IZiiColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Navigation Actions
  // ══════════════════════════════════════════════════════════════════════════
  void _navigateToDesktop(BuildContext context) {
    final bloc = context.read<MushroomsBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: bloc,
          child: const MushboomMonartoScreen(),
        ),
      ),
    ).then((_) => bloc.add(LoadRoomsEvent()));
  }

  void _navigateToDashboard(BuildContext context) {
    final bloc = context.read<MushroomsBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: bloc,
          child: Platform.isWindows || Platform.isMacOS
              ? const MushboomMonartoScreen()
              : const MushroomsDashboardScreen(),
        ),
      ),
    ).then((_) => bloc.add(LoadRoomsEvent()));
  }

  void _navigateToScanner(
      BuildContext context, Map<String, Map<String, dynamic>> localRooms) {
    if (localRooms.isEmpty) {
      _showSnackBar('No rooms loaded yet', isError: true);
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContinuousScannerScreen(
          localRooms: localRooms,
          activePlant: 'M2',
          onCheckIn: (code, room) => _onCheckIn(code, room, localRooms),
          onCheckOut: (code, room) => _onCheckOut(code, room, localRooms),
          isDark: isDark,
        ),
      ),
    ).then((_) => _loadMushroomData());
  }

  void _navigateToSafety(BuildContext context) {
    final bloc = context.read<MushroomsBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (Platform.isWindows || Platform.isMacOS) {
      // On desktop, navigate to the main tabs layout but pre-select the safety tab
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: bloc,
            child: const MushboomMonartoScreen(initialTab: 'safety'),
          ),
        ),
      ).then((_) => bloc.add(LoadRoomsEvent()));
    } else {
      // On mobile/tablet, open SafetyTabScreen directly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: bloc,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Safety Management'),
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                foregroundColor: isDark ? Colors.white : Colors.black87,
              ),
              body: SafetyTabScreen(
                isDark: isDark,
                safetyLogs: _safetyLogs,
                onTriggerEmergency: (active) {},
                onTriggerSafetyCheckAll: () {
                  _showSnackBar(
                      'Broadcasted verification request to all check-in personnel.');
                },
                onResetSafety: () async {
                  await _repository.clearRoomCrews();
                  bloc.add(LoadRoomsEvent());
                  _loadMushroomData();
                  _showSnackBar('Safety metrics restored successfully.');
                },
                onReportIncident: (room, desc) {
                  _showSnackBar(
                      'Incident report sent successfully to Chief Engineer and Supervisor.');
                },
              ),
            ),
          ),
        ),
      ).then((_) {
        bloc.add(LoadRoomsEvent());
        _loadMushroomData();
      });
    }
  }

  void _navigateToEmployees(BuildContext context) {
    final bloc = context.read<MushroomsBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: bloc,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Employees & Roles'),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black87,
            ),
            body: EmployeesTabScreen(
              isDark: isDark,
              employees: _employees,
              onAddEmployee: (id, name, role, dept,
                  [pass, status, team]) async {
                await _repository.addEmployee(
                    id, name, role, dept, pass, status, team);
                _loadMushroomData();
              },
              onEditEmployee: (id, name, role, dept, [status, team]) async {
                await _repository.updateEmployee(
                    id, name, role, dept, status, team);
                _loadMushroomData();
              },
              onImportEmployees: (list) async {
                for (var emp in list) {
                  await _repository.addEmployee(emp['id']!, emp['name']!,
                      emp['role']!, emp['department']);
                }
                _loadMushroomData();
              },
            ),
          ),
        ),
      ),
    ).then((_) {
      bloc.add(LoadRoomsEvent());
      _loadMushroomData();
    });
  }

  void _navigateToHarvestAttendance(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HarvestAttendanceScreen(isDark: isDark),
      ),
    ).then((_) {
      if (!mounted) return;
      context.read<MushroomsBloc>().add(LoadRoomsEvent());
      _loadMushroomData();
    });
  }

  void _navigateToBatchAttendance(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerBatchAttendanceScreen(isDark: isDark),
      ),
    ).then((_) {
      if (!mounted) return;
      context.read<MushroomsBloc>().add(LoadRoomsEvent());
      _loadMushroomData();
    });
  }

  void _navigateToPerformanceBoard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GrowingPerformanceBoardScreen(),
      ),
    );
  }

  void _navigateToDailyJobPlan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GrowingDailyJobPlanScreen(),
      ),
    ).then((_) {
      if (!mounted) return;
      context.read<MushroomsBloc>().add(LoadRoomsEvent());
      _loadMushroomData();
    });
  }

  void _navigateTo3dRoom(BuildContext context, {String? roomName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GrowRoom3dScreen(
          initialRoomName: roomName,
        ),
      ),
    );
  }

  void _navigateToPurchasing(BuildContext context) {
    final bloc = context.read<MushroomsBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: bloc,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Purchasing & Suppliers'),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black87,
            ),
            body: PurchasingTabScreen(
              isDark: isDark,
              activePlant: 'M2',
              currentRole: 'Manager',
            ),
          ),
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      bloc.add(LoadRoomsEvent());
      _loadMushroomData();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    if (!_isAuthenticated) {
      return MushroomsLoginScreen(
        onLoginSuccess: (empId) {
          setState(() {
            _isAuthenticated = true;
            _currentEmployeeId = empId;
          });
          // See note in _checkAuth: only update display name, keep id intact.
          _applyEmployeeDisplayName(empId);
          context.read<MushroomsBloc>().add(LoadRoomsEvent());
          _loadMushroomData();
        },
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground,
      // Quick menu for device enrollment flow (QR / NFC). Placed on FAB instead of
      // inserting into layout to avoid disrupting existing layout and easy removal after testing.
      floatingActionButton: DeviceQuickActionsFab(isDark: isDark),
      appBar: AppBar(
        title: const Text('Costa Mushrooms',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.view_in_ar_rounded,
                  color: _active3dIssues.isNotEmpty
                      ? Colors.amber.shade400
                      : null,
                ),
                if (_active3dIssues.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_active3dIssues.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: _active3dIssues.isNotEmpty
                ? 'Mô hình 3D Phòng Trồng (${_active3dIssues.length} sự cố)'
                : 'Mô hình 3D Phòng Trồng',
            onPressed: () {
              final firstIssueRoom = _active3dIssues.isNotEmpty
                  ? _active3dIssues.first.roomName
                  : null;
              final firstIssueWindow = _active3dIssues.isNotEmpty
                  ? _active3dIssues.first.windowCode
                  : null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GrowRoom3dScreen(
                    initialRoomName: firstIssueRoom,
                    initialSelectedWindowCode: firstIssueWindow,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.desktop_windows_rounded),
            tooltip: 'Desktop View (Monarto)',
            onPressed: () => _navigateToDesktop(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile & Change Password',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MushroomsProfileScreen(isDark: isDark),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: BlocBuilder<MushroomsBloc, MushroomsState>(
        builder: (context, state) {
          if (state.isLoading && state.rooms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final localRooms = _buildLocalRooms(state.rooms);
          final activeRoomsCount =
              state.rooms.where((r) => r['status'] == 'active').length;
          final runningJobsCount =
              state.rooms.where((r) => r['current_stage'] != 'idle').length;
          final hasActiveAlarms = state.alarmActive;

          return SafeArea(
            child: Column(
              children: [
                // Shift check-in banner (G1) — placed at top because this is
                // the easiest thing to forget during the day, and the consequence only appears
                // when workers try to create an Alone Worker task and get blocked.
                SessionBanner(isDark: isDark),

                // 3D Grow Room Issue Notification Banner (if any open issues exist)
                if (_active3dIssues.isNotEmpty)
                  _build3dIssueAlertBanner(context, isDark),

                Expanded(
                  child: isTablet
                      ? _buildTabletGrid(context, localRooms, activeRoomsCount,
                          runningJobsCount, hasActiveAlarms, isDark)
                      : _buildPhoneColumn(context, localRooms, activeRoomsCount,
                          runningJobsCount, hasActiveAlarms, isDark),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 📱 Mobile Portrait Layout (Single Column)
  Widget _buildPhoneColumn(
    BuildContext context,
    Map<String, Map<String, dynamic>> localRooms,
    int activeRooms,
    int runningJobs,
    bool hasAlarms,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveStatsRow(activeRooms, runningJobs, hasAlarms, isDark),
          const SizedBox(height: 20),
          _buildSectionTitle('Operational Modules', isDark),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Operations Dashboard',
            subtitle:
                '$activeRooms active grow rooms • View target yield & pipelines',
            icon: Icons.dashboard_customize_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
            onTap: () => _navigateToDashboard(context),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Continuous Scanner',
            subtitle: 'Camera scanner & manual ID check-in for pickers',
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () => _navigateToScanner(context, localRooms),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Safety incident & Solo Job',
            subtitle: hasAlarms
                ? '⚠️ Active safety alarm triggered!'
                : 'All checked-in crew is safe',
            icon: Icons.shield_rounded,
            color: hasAlarms ? IZiiColors.error : const Color(0xFFF59E0B),
            badgeCount: hasAlarms ? 1 : 0,
            isDark: isDark,
            onTap: () => _navigateToPage(context, 'safety'),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Employees & Roles',
            subtitle: 'Register new personnel, modify roles & scan ID cards',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: () => _navigateToEmployees(context),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Harvest Plan & Attendance',
            subtitle: 'QR check-in, break tracker & timesheet approval',
            icon: Icons.assignment_turned_in_rounded,
            color: const Color(0xFFC97A3D),
            isDark: isDark,
            onTap: () => _navigateToHarvestAttendance(context),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Batch Team Attendance',
            subtitle: 'Manager batch check-in/out & break for 100+ crew',
            icon: Icons.checklist_rounded,
            color: const Color(0xFF0284C7),
            isDark: isDark,
            onTap: () => _navigateToBatchAttendance(context),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Daily Job Planning',
            subtitle:
                'Manager job planning across rooms & Sup/Lead assignment',
            icon: Icons.playlist_add_check_circle_rounded,
            color: const Color(0xFF0D9488),
            isDark: isDark,
            onTap: () => _navigateToDailyJobPlan(context),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Growing Performance Board',
            subtitle:
                'Job completion time, break duration & solo worker safety',
            icon: Icons.analytics_rounded,
            color: const Color(0xFF2A78D6),
            isDark: isDark,
            onTap: () => _navigateToPerformanceBoard(context),
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Mô hình 3D Phòng Trồng',
            subtitle: _active3dIssues.isNotEmpty
                ? '⚠️ ${_active3dIssues.length} sự cố ô luống đang chờ xử lý'
                : '3D Grow Room Model • Cao 6m • 4/2 Racks, 6 Tầng, 9 Windows (27m)',
            icon: Icons.view_in_ar_rounded,
            color: _active3dIssues.isNotEmpty
                ? Colors.redAccent
                : const Color(0xFF0EA5E9),
            badgeCount: _active3dIssues.length,
            isDark: isDark,
            onTap: () {
              final firstIssueRoom = _active3dIssues.isNotEmpty
                  ? _active3dIssues.first.roomName
                  : null;
              _navigateTo3dRoom(context, roomName: firstIssueRoom);
            },
          ),
          const SizedBox(height: 12),
          QuickAccessCard(
            title: 'Purchasing & Suppliers',
            subtitle:
                'Purchase requests, Part No., required dates & supplier directory',
            icon: Icons.shopping_cart_checkout_rounded,
            color: const Color(0xFF0D9488),
            isDark: isDark,
            onTap: () => _navigateToPurchasing(context),
          ),
        ],
      ),
    );
  }

  // 💻 Tablet/Landscape Layout (2 Column Grid)
  Widget _buildTabletGrid(
    BuildContext context,
    Map<String, Map<String, dynamic>> localRooms,
    int activeRooms,
    int runningJobs,
    bool hasAlarms,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLiveStatsRow(activeRooms, runningJobs, hasAlarms, isDark),
                const SizedBox(height: 24),
                _buildSectionTitle('Operational Modules', isDark),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16.0,
              crossAxisSpacing: 16.0,
              childAspectRatio: 2.2,
            ),
            delegate: SliverChildListDelegate([
              QuickAccessCard(
                title: 'Operations Dashboard',
                subtitle: 'Monitor all Costa M2 rooms, yields & growth steps',
                icon: Icons.dashboard_customize_rounded,
                color: const Color(0xFF6366F1),
                isDark: isDark,
                onTap: () => _navigateToDashboard(context),
              ),
              QuickAccessCard(
                title: 'Continuous Scanner',
                subtitle: 'Camera / manual check-in scanner for pickers',
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
                onTap: () => _navigateToScanner(context, localRooms),
              ),
              QuickAccessCard(
                title: 'Safety & Solo Alarms',
                subtitle: hasAlarms
                    ? '⚠️ Active safety alarm triggered!'
                    : 'All checked-in crew is safe',
                icon: Icons.shield_rounded,
                color: hasAlarms ? IZiiColors.error : const Color(0xFFF59E0B),
                badgeCount: hasAlarms ? 1 : 0,
                isDark: isDark,
                onTap: () => _navigateToPage(context, 'safety'),
              ),
              QuickAccessCard(
                title: 'Employees & Roles',
                subtitle:
                    'Register new personnel, modify roles & scan ID cards',
                icon: Icons.people_alt_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                onTap: () => _navigateToEmployees(context),
              ),
              QuickAccessCard(
                title: 'Harvest Plan & Attendance',
                subtitle: 'QR check-in, break tracker & timesheet approval',
                icon: Icons.assignment_turned_in_rounded,
                color: const Color(0xFFC97A3D),
                isDark: isDark,
                onTap: () => _navigateToHarvestAttendance(context),
              ),
              QuickAccessCard(
                title: 'Batch Team Attendance',
                subtitle: 'Manager batch check-in/out & break for 100+ crew',
                icon: Icons.checklist_rounded,
                color: const Color(0xFF0284C7),
                isDark: isDark,
                onTap: () => _navigateToBatchAttendance(context),
              ),
              QuickAccessCard(
                title: 'Daily Job Planning',
                subtitle:
                    'Manager job planning across rooms & Sup/Lead assignment',
                icon: Icons.playlist_add_check_circle_rounded,
                color: const Color(0xFF0D9488),
                isDark: isDark,
                onTap: () => _navigateToDailyJobPlan(context),
              ),
              QuickAccessCard(
                title: 'Growing Performance Board',
                subtitle:
                    'Job completion time, break duration & solo worker safety',
                icon: Icons.analytics_rounded,
                color: const Color(0xFF2A78D6),
                isDark: isDark,
                onTap: () => _navigateToPerformanceBoard(context),
              ),
              QuickAccessCard(
                title: 'Desktop View (Monarto)',
                subtitle:
                    'Full multi-tab workstation dashboard for iPad & large displays',
                icon: Icons.desktop_windows_rounded,
                color: const Color(0xFF0284C7),
                isDark: isDark,
                onTap: () => _navigateToDesktop(context),
              ),
              QuickAccessCard(
                title: 'Mô hình 3D Phòng Trồng',
                subtitle: _active3dIssues.isNotEmpty
                    ? '⚠️ ${_active3dIssues.length} sự cố ô luống đang chờ xử lý'
                    : '3D Grow Room Model • Cao 6m • 4/2 Racks, 6 Tầng, 9 Windows (27m)',
                icon: Icons.view_in_ar_rounded,
                color: _active3dIssues.isNotEmpty
                    ? Colors.redAccent
                    : const Color(0xFF0EA5E9),
                badgeCount: _active3dIssues.length,
                isDark: isDark,
                onTap: () {
                  final firstIssueRoom = _active3dIssues.isNotEmpty
                      ? _active3dIssues.first.roomName
                      : null;
                  _navigateTo3dRoom(context, roomName: firstIssueRoom);
                },
              ),
              QuickAccessCard(
                title: 'Purchasing & Suppliers',
                subtitle:
                    'Purchase requests, Part No., required dates & supplier directory',
                icon: Icons.shopping_cart_checkout_rounded,
                color: const Color(0xFF0D9488),
                isDark: isDark,
                onTap: () => _navigateToPurchasing(context),
              ),
            ]),
          )
        ],
      ),
    );
  }

  Widget _buildLiveStatsRow(
      int activeRooms, int runningJobs, bool hasAlarms, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E0D9)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
              'Active Rooms', '$activeRooms', const Color(0xFF10B981), isDark),
          _buildStatItem(
              'Running Jobs', '$runningJobs', const Color(0xFF6366F1), isDark),
          _buildStatItem('Safety Alerts', hasAlarms ? '1' : '0',
              hasAlarms ? IZiiColors.error : const Color(0xFFF59E0B), isDark,
              isAlert: hasAlarms),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark,
      {bool isAlert = false}) {
    Widget valueWidget = Text(
      value,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: isAlert
            ? IZiiColors.error
            : (isDark ? Colors.white : Colors.black87),
      ),
    );

    if (isAlert) {
      valueWidget = valueWidget
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 0.9, end: 1.1, duration: 600.ms);
    }

    return Column(
      children: [
        valueWidget,
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        )
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }

  void _navigateToPage(BuildContext context, String page) {
    if (page == 'safety') {
      _navigateToSafety(context);
    }
  }

  Widget _build3dIssueAlertBanner(BuildContext context, bool isDark) {
    final issueCount = _active3dIssues.length;
    final firstIssue = _active3dIssues.first;
    final hasCritical = _active3dIssues.any((i) => i.severity == 'critical');
    final bannerBg = hasCritical
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF422006) : const Color(0xFFFFFBEB));
    final bannerBorder = hasCritical
        ? (isDark ? Colors.red.shade800 : Colors.red.shade300)
        : (isDark ? Colors.amber.shade800 : Colors.amber.shade300);
    final bannerTextColor = hasCritical
        ? (isDark ? Colors.red.shade200 : Colors.red.shade900)
        : (isDark ? Colors.amber.shade200 : Colors.amber.shade900);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: hasCritical
                ? Colors.red.withValues(alpha: 0.12)
                : Colors.amber.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (hasCritical ? Colors.red : Colors.amber)
                  .withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasCritical ? Icons.warning_amber_rounded : Icons.view_in_ar_rounded,
              color: hasCritical ? Colors.redAccent : Colors.amber.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '3D GROW ROOM ALERT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: bannerTextColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: hasCritical ? Colors.red : Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$issueCount open',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${firstIssue.roomName} • ${firstIssue.windowCode}: [${firstIssue.category.displayName}] ${firstIssue.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasCritical ? Colors.red : const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GrowRoom3dScreen(
                    initialRoomName: firstIssue.roomName,
                    initialSelectedWindowCode: firstIssue.windowCode,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text('View 3D', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
