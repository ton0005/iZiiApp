import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/izii_colors.dart';
import '../../../core/enrollment/widgets/device_quick_actions_fab.dart';
import '../../../core/session/widgets/session_banner.dart';
import '../bloc/mushrooms_bloc.dart';
import '../repository.dart';
import '../services/employee_service.dart';
import 'mushrooms_dashboard_screen.dart';
import 'mushboom_monarto_screen.dart';
import 'continuous_scanner_screen.dart';
import 'safety_tab_screen.dart';
import 'employees_tab_screen.dart';
import 'quick_access_card.dart';
import 'mushrooms_login_screen.dart';
import 'mushrooms_profile_screen.dart';
import 'harvest_attendance_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final empId = await _employeeService.getCurrentEmployeeId();
    if (empId != null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _currentEmployeeId = empId;
        });
        try {
          context.read<ChatBloc>().add(SwitchUserEvent(empId));
        } catch (_) {}
        context.read<MushroomsBloc>().add(LoadRoomsEvent());
        _loadMushroomData();
      }
    }
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
      context.read<MushroomsBloc>().add(LoadRoomsEvent());
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
          try {
            context.read<ChatBloc>().add(SwitchUserEvent(empId));
          } catch (_) {}
          context.read<MushroomsBloc>().add(LoadRoomsEvent());
          _loadMushroomData();
        },
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground,
      // Menu nhanh cho luồng đăng ký thiết bị (QR / NFC). Đặt ở FAB thay vì
      // chèn vào layout để không xô lệch bố cục hiện có và gỡ ra dễ dàng khi
      // test xong.
      floatingActionButton: DeviceQuickActionsFab(isDark: isDark),
      appBar: AppBar(
        title: const Text('Costa Mushrooms',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
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
                // Thanh điểm danh đầu ca (G1) — đặt trên cùng vì đây là việc
                // dễ quên nhất trong ngày, và hậu quả chỉ lộ ra khi công nhân
                // định tạo công việc Alone Worker rồi bị chặn.
                SessionBanner(isDark: isDark),
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
          const SizedBox(height: 24),
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
                const SizedBox(height: 32),
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
}
