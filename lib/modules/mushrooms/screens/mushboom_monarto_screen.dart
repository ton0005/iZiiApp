import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:izii_app/core/bloc/app_bloc.dart';
import '../bloc/mushrooms_bloc.dart';
import '../repository.dart';

// Import sub-screens
import 'growing_tab_screen.dart';
import 'harvest_tab_screen.dart';
import 'cool_room_tab_screen.dart';
import 'maintenance_tab_screen.dart';
import 'tasks_tab_screen.dart';
import 'chat_tab_screen.dart';
import 'safety_tab_screen.dart';
import 'employees_tab_screen.dart';
import 'departments_tab_screen.dart';
import 'job_types_management_screen.dart';
import 'settings_tab_screen.dart';
import 'growing_performance_board_screen.dart';
import 'mushrooms_profile_screen.dart';
import '../services/employee_service.dart';
import 'package:izii_app/core/database/app_database.dart';

// --- Premium color definitions ---
class FarmColors {
  static const Color forestGreen = Color(0xFF2D6A4F);
  static const Color forestGreenLight = Color(0xFFE8F3EE);
  static const Color forestGreenText = Color(0xFF1B4332);

  static const Color harvestPurple = Color(0xFF7C3AED);
  static const Color harvestPurpleLight = Color(0xFFF5F3FF);

  static const Color coolBlue = Color(0xFF0284C7);
  static const Color coolBlueLight = Color(0xFFF0F9FF);

  static const Color maintenanceOrange = Color(0xFFD97706);
  static const Color maintenanceOrangeLight = Color(0xFFFEF3C7);

  static const Color borderLight = Color(0xFFE2E0D9);
  static const Color borderStrong = Color(0xFFC8C5BC);
  static const Color bgLight = Color(0xFFFAF9F6);
  static const Color bgDark = Color(0xFF121212);
}

class MushboomMonartoScreen extends StatefulWidget {
  final String? initialTab;
  const MushboomMonartoScreen({super.key, this.initialTab});

  @override
  State<MushboomMonartoScreen> createState() => _MushboomMonartoScreenState();
}

class _MushboomMonartoScreenState extends State<MushboomMonartoScreen> {
  // Tab state
  final EmployeeService _employeeService = EmployeeServiceImpl();
  bool _isAuthenticated = false;
  String? _currentEmployeeId;
  String _activeTab =
      'growing'; // growing, harvest, coolroom, maintenance, tasks, chat, safety
  String _activePlant = 'M2'; // M1 or M2
  String? _selectedRoomName;
  String? _lastLoadedRoomId;
  String _activeRole =
      'Growing Lead'; // Vinh (Growing Lead), Hải (Harvest Supervisor), Trúc (Cool Room Manager), Nam (Maintenance Lead)
  String get _language => Localizations.localeOf(context).languageCode;
  String _roomFilter = 'all'; // all, active, idle

  String? _tasksSelectedRoomName;
  String _tasksViewMode = 'kanban'; // kanban or gantt

  String _activeChatContact = 'Growing Crew';

  bool _emergencyActive = false;

  // Local active state maps (synchronized with database where applicable)
  final Map<String, Map<String, dynamic>> _localRooms = {};

  // Picking plans sent from Cool Room to Harvest
  final List<Map<String, dynamic>> _pickingPlans = [];

  // Warehouse Stock (kg)
  double _stockButton = 120;
  double _stockMedium = 240;
  double _stockOpen = 95;

  // Orders Registry
  final List<Map<String, dynamic>> _orders = [
    {
      'id': 'ORD-001',
      'customer': 'Aeon Mall',
      'req': 'Button: 50kg, Medium: 100kg',
      'total': 150.0,
      'status': 'Pending'
    },
    {
      'id': 'ORD-002',
      'customer': 'Lotte Mart',
      'req': 'Medium: 80kg, Open: 30kg',
      'total': 110.0,
      'status': 'Pending'
    },
    {
      'id': 'ORD-003',
      'customer': 'Costa Supply',
      'req': 'Open: 50kg',
      'total': 50.0,
      'status': 'Delivered'
    }
  ];

  // Maintenance Logs
  final List<Map<String, dynamic>> _maintenanceJobs = [
    {
      'id': 'MNT-101',
      'title': 'Exhaust fan sterilization',
      'plant': 'M2',
      'room': '33',
      'assignee': 'Nam T.',
      'priority': 'normal',
      'status': 'inprog',
      'notes': 'Routine antibacterial filter maintenance.'
    },
    {
      'id': 'MNT-102',
      'title': 'Calibrate humidity sensor',
      'plant': 'M1',
      'room': '12',
      'assignee': 'Loi P.',
      'priority': 'high',
      'status': 'todo',
      'notes': 'Sensor offset is 5% compared to manual measurement.'
    }
  ];

  // Chat History
  final Map<String, List<Map<String, String>>> _chatHistory = {
    'Growing Crew': [
      {
        'sender': 'Minh T.',
        'text': 'Completed watering Room 33 this morning.',
        'time': '08:30',
        'role': 'Growing Specialist'
      },
      {
        'sender': 'Vinh',
        'text': 'Great, check humidity for Room 34 as well.',
        'time': '08:45',
        'role': 'Growing Lead'
      }
    ],
    'Sarah (Sales)': [
      {
        'sender': 'Sarah',
        'text':
            'Aeon Mall needs 150kg medium mushrooms urgently this afternoon, is warehouse stock enough, Truc?',
        'time': '09:15',
        'role': 'Sales Lead'
      },
      {
        'sender': 'Truc',
        'text': 'I\'ll create an urgent picking plan and send to Harvest.',
        'time': '09:20',
        'role': 'Cool Room Manager'
      }
    ],
    'Mike (Site Manager)': [
      {
        'sender': 'Mike',
        'text': 'Updated the safety alarm system for the new branch.',
        'time': '07:00',
        'role': 'Site Manager'
      }
    ]
  };

  // Safety Logs
  final List<Map<String, dynamic>> _safetyLogs = [
    {
      'empId': 'EMP001',
      'empName': 'Minh T.',
      'room': '33',
      'role': 'Growing Specialist',
      'time': '08:00',
      'action': 'Check-in',
      'solo': false
    },
    {
      'empId': 'EMP003',
      'empName': 'Hùng V.',
      'room': '44',
      'role': 'Harvest Picker',
      'time': '08:15',
      'action': 'Check-in',
      'solo': false
    }
  ];

  // Room crews (Who is checked into which room)
  final Map<String, List<String>> _roomCrews = {};

  // Employees Registry
  final List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _rolesWithLevels = [];
  MushroomEmployee? _currentEmployee;

  // Sidebar state
  bool _isSidebarPinned = true;
  bool _isSidebarHovered = false;

  // BLoC
  late MushroomsBloc _bloc;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _activeTab = widget.initialTab!;
    }
    _bloc = MushroomsBloc()..add(LoadRoomsEvent());
    _loadMushroomData();
  }

  // Role name -> numeric level (0=Worker, 1=Specialist, 2=Lead/Supervisor,
  // 3=Manager), resolved against the same catalogue the Employees screen
  // edits (_rolesWithLevels), with a name-based fallback heuristic.
  int _getRoleLevel(String role) {
    for (final r in _rolesWithLevels) {
      if (r['name']?.toString().toLowerCase() == role.toLowerCase()) {
        return r['level'] as int? ?? 0;
      }
    }
    final r = role.toLowerCase();
    if (r.contains('manager') ||
        r.contains('site manager') ||
        r.contains('cool room manager')) return 3;
    if (r.contains('lead') || r.contains('supervisor')) return 2;
    if (r.contains('specialist')) return 1;
    return 0; // picker, box mover, worker, etc.
  }

  // Job Types management is a Level 2+ (Lead/Supervisor/Manager) destination.
  bool get _canManageJobTypes =>
      _currentEmployee != null && _getRoleLevel(_currentEmployee!.role) >= 2;

  bool _isJobVisible(Map<String, dynamic> job, String activeRole,
      List<Map<String, dynamic>> employees) {
    final userLevel = _getRoleLevel(activeRole);

    final assignee =
        job['assignee']?.toString() ?? job['assigneeName']?.toString() ?? '';
    if (assignee.isEmpty || assignee == 'Not Assigned') {
      return true; // Unassigned jobs are visible to everyone
    }

    String getActiveName(String role) {
      if (role == 'Growing Lead') return 'Vinh';
      if (role == 'Harvest Supervisor') return 'Hải';
      if (role == 'Cool Room Manager') return 'Trúc';
      if (role == 'Maintenance Lead') return 'Nam';
      return '';
    }

    final activeName = getActiveName(activeRole);
    if (activeName.isNotEmpty &&
        assignee.toLowerCase().contains(activeName.toLowerCase())) {
      return true; // Always show jobs assigned to myself
    }

    String assigneeRole = '';
    for (final e in employees) {
      final empName = e['name']?.toString() ?? '';
      if (empName.isNotEmpty &&
          (assignee.toLowerCase().contains(empName.toLowerCase()) ||
              empName.toLowerCase().contains(assignee.toLowerCase()))) {
        assigneeRole = e['role']?.toString() ?? '';
        break;
      }
    }

    if (assigneeRole.isEmpty) {
      return true; // Default visible if employee not found (could be supervisor or system generated)
    }

    final assigneeLevel = _getRoleLevel(assigneeRole);
    return userLevel >= assigneeLevel;
  }

  Future<void> _loadMushroomData() async {
    final repo = MushroomsRepository();
    final stock = await repo.getMushroomStock();
    final orders = await repo.getMushroomOrders();
    final mntTickets = await repo.getMaintenanceTickets();
    final crewChat = await repo.getChatHistory('Growing Crew');
    final sarahChat = await repo.getChatHistory('Sarah (Sales)');
    final mikeChat = await repo.getChatHistory('Mike (Site Manager)');
    final crews = await repo.getRoomCrews();
    final soloJobs = await repo.getAllSoloJobs();
    final dbEmployees = await repo.getEmployees();
    final rolesList = await repo.getRolesWithLevels();
    final currentEmp = await EmployeeServiceImpl().getCurrentEmployee();

    setState(() {
      _currentEmployee = currentEmp;
      if (currentEmp != null) {
        _activeRole = currentEmp.role;
      }
      _stockButton = stock['button'] ?? 120.0;
      _stockMedium = stock['cup'] ?? 240.0;
      _stockOpen = stock['flat'] ?? 95.0;

      _orders.clear();
      _orders.addAll(orders);

      _maintenanceJobs.clear();
      _maintenanceJobs.addAll(mntTickets);

      _chatHistory['Growing Crew'] = crewChat;
      _chatHistory['Sarah (Sales)'] = sarahChat;
      _chatHistory['Mike (Site Manager)'] = mikeChat;

      _roomCrews.clear();
      for (final c in crews) {
        _roomCrews.putIfAbsent(c['roomName']!, () => []).add(c['empName']!);
      }

      _safetyLogs.clear();
      _safetyLogs.addAll(soloJobs);

      _employees.clear();
      _employees.addAll(dbEmployees);

      _rolesWithLevels = rolesList;
    });
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

  void _syncDatabaseRooms(List<Map<String, dynamic>> dbRooms) {
    for (var r in dbRooms) {
      final name = r['name'] as String;
      if (!_localRooms.containsKey(name)) {
        _localRooms[name] = {
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
          'pickingPlan': r['pickingPlanJson'] != null
              ? jsonDecode(r['pickingPlanJson'])
              : null,
          'jobs': []
        };
      } else {
        // Update stage & status from database
        _localRooms[name]!['status'] =
            r['status'] ?? _localRooms[name]!['status'];
        _localRooms[name]!['current_stage'] =
            r['current_stage'] ?? _localRooms[name]!['current_stage'];
        _localRooms[name]!['day_in_cycle'] =
            r['day_in_cycle'] ?? _localRooms[name]!['day_in_cycle'];
        _localRooms[name]!['targetYield'] =
            r['targetYield'] ?? _localRooms[name]!['targetYield'];
        _localRooms[name]!['pickedYield'] =
            r['pickedYield'] ?? _localRooms[name]!['pickedYield'];
        _localRooms[name]!['pickingPlan'] = r['pickingPlanJson'] != null
            ? jsonDecode(r['pickingPlanJson'])
            : null;
      }
    }
    _pickingPlans.clear();
    for (final room in _localRooms.values) {
      if (room['pickingPlan'] != null) {
        _pickingPlans.add(Map<String, dynamic>.from(room['pickingPlan']));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<MushroomsBloc, MushroomsState>(
        listener: (context, state) {
          if (state.rooms.isNotEmpty) {
            setState(() {
              _syncDatabaseRooms(state.rooms);
              if (_selectedRoomName == null && _localRooms.isNotEmpty) {
                // Find first room in plant
                final firstRoom = _localRooms.values.firstWhere(
                    (r) => r['plant'] == _activePlant,
                    orElse: () => _localRooms.values.first);
                _selectedRoomName = firstRoom['name'];
              }
              if (_tasksSelectedRoomName == null && _localRooms.isNotEmpty) {
                _tasksSelectedRoomName = _selectedRoomName;
              }
            });

            final activeRoomName = (_activeTab == 'tasks')
                ? _tasksSelectedRoomName
                : _selectedRoomName;
            final room = _localRooms[activeRoomName];
            if (room != null && room['id'] != _lastLoadedRoomId) {
              _lastLoadedRoomId = room['id'];
              _bloc.add(LoadRoomDetailsEvent(room['id']));
            }
          }

          if (state.selectedRoomId != null) {
            setState(() {
              final roomEntry = _localRooms.values.firstWhere(
                  (r) => r['id'] == state.selectedRoomId,
                  orElse: () => {});
              if (roomEntry.isNotEmpty) {
                final rName = roomEntry['name'] as String;
                // Chỉ nhận job THỰC SỰ khai báo đúng phòng này.
                //
                // Trước đây điều kiện là:
                //     if (jRoomId != null && jRoomId != state.selectedRoomId)
                // tức job THIẾU room_id sẽ lọt qua và bị gán vào bất kỳ phòng
                // nào đang được chọn — fail-open. Hiện _mapJob (job_list_service
                // .dart:88-114) luôn kèm 'room_id' nên chưa lộ, nhưng chỉ cần
                // một nguồn job khác (API ngoài, cache, mock) quên field này là
                // lỗi "phòng nào cũng hiện job giống nhau" tái diễn.
                //
                // Giờ đổi thành fail-closed: không xác định được phòng thì loại.
                final filteredJobs = state.selectedRoomJobs.where((j) {
                  final jRoomId = j['room_id'] ?? j['roomId'];
                  if (jRoomId == null || jRoomId != state.selectedRoomId) {
                    return false;
                  }
                  return _isJobVisible(j, _activeRole, _employees);
                }).toList();

                _localRooms[rName]!['jobs'] = filteredJobs
                    .map((j) => {
                          'id': j['id'],
                          'name': j['name'],
                          'job_type': j['job_type'],
                          'icon': j['job_type'] == 'watering'
                              ? Icons.water_drop
                              : j['job_type'] == 'prochloraz'
                                  ? Icons.science
                                  : Icons.task_alt,
                          'status': j['status'] == 'completed'
                              ? 'done'
                              : (j['status'] == 'in_progress'
                                  ? 'inprog'
                                  : (j['status'] == 'review'
                                      ? 'review'
                                      : 'todo')),
                          'assignee': j['assignee'] ?? 'Not Assigned',
                          'date': j['scheduled_at'] != null
                              ? j['scheduled_at'].toString().substring(5, 10)
                              : 'Today',
                          'notes':
                              j['plan_details'] ?? j['prochloraz_rate'] ?? '',
                          'is_solo_job': j['is_solo_job'],
                          'time_limit_minutes': j['time_limit_minutes'],
                          'started_at': j['started_at'],
                          'co_level': j['co_level'],
                          'co2_level': j['co2_level'],
                          'check_in_time': j['check_in_time'],
                          'check_out_time': j['check_out_time'],
                        })
                    .toList();
              }
            });
            _loadMushroomData();
          }

          if (state.error != null && state.error!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && _localRooms.isEmpty) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            backgroundColor: isDark ? FarmColors.bgDark : FarmColors.bgLight,
            body: Column(
              children: [
                // Global Emergency Bar
                if (_emergencyActive)
                  Container(
                    width: double.infinity,
                    color: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'EMERGENCY WARNING:... detected in Room ...! Evacuate immediately.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          onPressed: () =>
                              setState(() => _emergencyActive = false),
                          child: const Text('Confirm',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),

                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 700;
                      return Row(
                        children: [
                          if (isDesktop) _buildSidebar(isDark),
                          Expanded(
                            child: Column(
                              children: [
                                _buildTopbar(isDark),
                                Expanded(
                                  child: _buildMainContent(isDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Top Bar ---
  Widget _buildTopbar(bool isDark) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
            bottom: BorderSide(
                color: isDark ? Colors.white10 : FarmColors.borderLight)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to Mobile Portal',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTabTitle(),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getTabSubtitle(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  )
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.account_circle_outlined, size: 24),
                tooltip: 'Profile & Change Password',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MushroomsProfileScreen(isDark: isDark),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sign out',
                onPressed: _handleLogout,
              ),
              const SizedBox(width: 8),
              // Employee Info Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : FarmColors.forestGreen.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isDark
                        ? Colors.white24
                        : FarmColors.forestGreen.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: isDark ? Colors.white70 : FarmColors.forestGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentEmployee != null
                          ? '${_currentEmployee!.name} (ID: ${_currentEmployee!.id}) • ${_currentEmployee!.role}'
                          : 'NV: ${_activeRole}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  String _getTabTitle() {
    if (_activeTab == 'growing') {
      return _language == 'vi' ? 'Trồng trọt (Growing)' : 'Growing Department';
    }
    if (_activeTab == 'harvest') {
      return _language == 'vi' ? 'Thu hoạch (Harvest)' : 'Harvest Department';
    }
    if (_activeTab == 'coolroom') {
      return _language == 'vi' ? 'Kho lạnh (Cool Room)' : 'Cool Room Warehouse';
    }
    if (_activeTab == 'maintenance') {
      return _language == 'vi' ? 'Bảo trì (Maintenance)' : 'Maintenance Log';
    }
    if (_activeTab == 'performance') {
      return _language == 'vi'
          ? 'Hiệu suất (Performance Board)'
          : 'Growing Performance Board';
    }
    if (_activeTab == 'tasks') {
      return _language == 'vi'
          ? 'Dự án & Công việc (Tasks)'
          : 'Project & Tasks';
    }
    if (_activeTab == 'chat') {
      return _language == 'vi' ? 'Trò chuyện (Chat)' : 'Encrypted Chat';
    }
    if (_activeTab == 'employees') {
      return _language == 'vi' ? 'Nhân sự (Employees)' : 'Employee Registry';
    }
    if (_activeTab == 'departments') {
      return _language == 'vi'
          ? 'Phòng ban (Departments)'
          : 'Department Directory';
    }
    if (_activeTab == 'settings') {
      return _language == 'vi' ? 'Cài đặt (Settings)' : 'Settings';
    }
    return _language == 'vi' ? 'An toàn lao động (Safety)' : 'Safety Dashboard';
  }

  String _getTabSubtitle() {
    if (_activeTab == 'growing') return 'Costa Mushroom — Plant $_activePlant';
    if (_activeTab == 'harvest') {
      return 'Staff Check-In & Real-time Harvest Supervision';
    }
    if (_activeTab == 'coolroom') {
      return 'Warehouse Inventory & Picking Plans Dispatcher';
    }
    if (_activeTab == 'maintenance') {
      return 'Maintenance History & Technical Error Reports';
    }
    if (_activeTab == 'performance') {
      return 'Joblist Completion, Break Time & Alone Worker Safety Board';
    }
    if (_activeTab == 'tasks') return 'Kanban Board & Gantt Chart Timeline';
    if (_activeTab == 'chat') return 'Offline BLE P2P Chat Simulator';
    if (_activeTab == 'employees') return 'Staff & Specialist Registry';
    if (_activeTab == 'departments')
      return 'Manage business department listings';
    if (_activeTab == 'settings')
      return 'Server, Sync & Application Preferences';
    return 'Solo Working Alerts & Incident Manager';
  }

  // --- Sidebar ---
  // --- Sidebar ---
  Widget _buildSidebar(bool isDark) {
    final isMobilePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    final effectivePinned = isMobilePlatform || _isSidebarPinned;
    final effectiveExpanded = effectivePinned || _isSidebarHovered;
    final targetWidth = effectiveExpanded ? 260.0 : 79.0;

    return MouseRegion(
      onEnter: (_) {
        if (!effectivePinned && !_isSidebarHovered) {
          setState(() => _isSidebarHovered = true);
        }
      },
      onExit: (_) {
        if (!effectivePinned && _isSidebarHovered) {
          setState(() => _isSidebarHovered = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: targetWidth,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: ClipRect(
          child: Column(
            children: [
              // Sidebar Logo Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : FarmColors.borderLight,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fixed size Logo (32px height) in BOTH expanded and collapsed states
                    Image.asset(
                      'assets/images/costa-tag-logo-green.png',
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                    if (effectiveExpanded) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.call_split, size: 10, color: Colors.grey),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'mushroom-farm-fork',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Pin Icon Button BELOW Logo (Hidden on iOS/Android)
                    if (!isMobilePlatform) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isSidebarPinned = !_isSidebarPinned;
                            if (_isSidebarPinned) {
                              _isSidebarHovered = false;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: effectiveExpanded ? 10 : 6,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _isSidebarPinned
                                ? FarmColors.forestGreen.withValues(alpha: 0.12)
                                : (isDark ? Colors.white10 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isSidebarPinned
                                  ? FarmColors.forestGreen.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Tooltip(
                            message: _isSidebarPinned
                                ? (_language == 'vi'
                                    ? 'Tự động ẩn Menu (Auto-hide)'
                                    : 'Auto-hide Menu')
                                : (_language == 'vi'
                                    ? 'Ghim Menu (Pin)'
                                    : 'Pin Menu'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isSidebarPinned
                                      ? Icons.view_sidebar_rounded
                                      : Icons.view_sidebar_outlined,
                                  size: 18,
                                  color: _isSidebarPinned
                                      ? FarmColors.forestGreen
                                      : Colors.grey.shade600,
                                ),
                                if (effectiveExpanded) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _isSidebarPinned
                                          ? (_language == 'vi' ? 'Đã ghim Menu' : 'Pinned')
                                          : (_language == 'vi' ? 'Tự động ẩn' : 'Auto-hide'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isSidebarPinned
                                            ? FarmColors.forestGreen
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    _buildSidebarLabel(
                        _language == 'vi' ? 'PHÒNG BAN' : 'DEPARTMENTS',
                        effectiveExpanded),
                    _buildSidebarItem(
                        'growing',
                        Icons.corporate_fare_rounded,
                        _language == 'vi' ? 'Trồng trọt (Growing)' : 'Growing',
                        FarmColors.forestGreen,
                        effectiveExpanded),
                    _buildSidebarItem(
                        'harvest',
                        Icons.cut_rounded,
                        _language == 'vi' ? 'Thu hoạch (Harvest)' : 'Harvest',
                        FarmColors.harvestPurple,
                        effectiveExpanded),
                    _buildSidebarItem(
                        'coolroom',
                        Icons.ac_unit_rounded,
                        _language == 'vi' ? 'Kho lạnh (Cool Room)' : 'Cool Room',
                        FarmColors.coolBlue,
                        effectiveExpanded),
                    _buildSidebarItem(
                        'maintenance',
                        Icons.build_rounded,
                        _language == 'vi'
                            ? 'Bảo trì (Maintenance)'
                            : 'Maintenance',
                        FarmColors.maintenanceOrange,
                        effectiveExpanded),
                    if (effectiveExpanded)
                      const Divider()
                    else
                      const SizedBox(height: 8),
                    _buildSidebarLabel(
                        _language == 'vi' ? 'HỆ THỐNG' : 'UTILITIES',
                        effectiveExpanded),
                    _buildSidebarItem(
                        'performance',
                        Icons.analytics_rounded,
                        _language == 'vi'
                            ? 'Hiệu suất (Performance)'
                            : 'Performance Board',
                        const Color(0xFF2A78D6),
                        effectiveExpanded),
                    _buildSidebarItem(
                        'tasks',
                        Icons.view_kanban_rounded,
                        _language == 'vi' ? 'Công việc (Tasks)' : 'Tasks',
                        Colors.blueGrey,
                        effectiveExpanded),
                    _buildSidebarItem(
                        'chat',
                        Icons.question_answer_rounded,
                        _language == 'vi' ? 'Trò chuyện (Chat)' : 'Chat',
                        Colors.blue,
                        effectiveExpanded),
                    _buildSidebarItem(
                        'safety',
                        Icons.shield_rounded,
                        _language == 'vi' ? 'An toàn (Safety)' : 'Safety',
                        Colors.redAccent,
                        effectiveExpanded),
                    _buildSidebarItem(
                        'employees',
                        Icons.badge_rounded,
                        _language == 'vi' ? 'Nhân sự (Employees)' : 'Employees',
                        Colors.teal,
                        effectiveExpanded),
                    _buildSidebarItem(
                        'departments',
                        Icons.lan_rounded,
                        _language == 'vi'
                            ? 'Phòng ban (Departments)'
                            : 'Departments',
                        Colors.indigo,
                        effectiveExpanded),
                    // Level 2+ (Lead/Supervisor/Manager) only — see
                    // _canManageJobTypes.
                    if (_canManageJobTypes)
                      _buildSidebarItem(
                          'jobtypes',
                          Icons.add_task_rounded,
                          _language == 'vi'
                              ? 'Loại công việc (Job Types)'
                              : 'Job Types',
                          Colors.deepPurple,
                          effectiveExpanded),
                    if (effectiveExpanded)
                      const Divider()
                    else
                      const SizedBox(height: 8),
                    _buildSidebarLabel(
                        _language == 'vi' ? 'CẤU HÌNH' : 'CONFIGURATION',
                        effectiveExpanded),
                    _buildSidebarItem(
                        'settings',
                        Icons.settings_rounded,
                        _language == 'vi' ? 'Cài đặt (Settings)' : 'Settings',
                        const Color(0xFF8B5CF6),
                        effectiveExpanded),
                  ],
                ),
              ),

              // Bottom Left Logo
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : FarmColors.borderLight,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: ClipRect(
                  child: Row(
                    mainAxisAlignment: effectiveExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.dashboard_rounded,
                        color: FarmColors.forestGreen,
                        size: 20,
                      ),
                      if (effectiveExpanded) ...[
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'iZiiApp',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: FarmColors.forestGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarLabel(String text, bool expanded) {
    if (!expanded) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(String tabId, IconData icon, String label,
      Color indicatorColor, bool expanded) {
    final isActive = _activeTab == tabId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color? bgCol = isActive
        ? (isDark
            ? FarmColors.forestGreen
            : FarmColors.forestGreenLight.withOpacity(0.4))
        : null;

    final Color textIconCol = isActive
        ? (isDark ? Colors.white : FarmColors.forestGreenText)
        : Colors.grey.shade600;

    final itemWidget = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: () => switchTab(tabId),
        borderRadius: BorderRadius.circular(8),
        child: ClipRect(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 10 : 0,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(8),
            ),
            child: expanded
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: 260.0 - 16.0 - 20.0,
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: textIconCol),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isActive ? FontWeight.bold : FontWeight.normal,
                                color: textIconCol,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: Icon(icon, size: 20, color: textIconCol),
                  ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 300),
      child: itemWidget,
    );
  }

  void switchTab(String tabId) {
    setState(() {
      _activeTab = tabId;
    });
    _loadMushroomData();

    final activeRoomName =
        (tabId == 'tasks') ? _tasksSelectedRoomName : _selectedRoomName;
    final room = _localRooms[activeRoomName];
    if (room != null) {
      _lastLoadedRoomId = room['id'];
      _bloc.add(LoadRoomDetailsEvent(room['id']));
    }
  }

  // --- Main Content Switcher ---
  Widget _buildMainContent(bool isDark) {
    if (_activeTab == 'growing') {
      return GrowingTabScreen(
        isDark: isDark,
        localRooms: _localRooms,
        roomCrews: _roomCrews,
        activePlant: _activePlant,
        roomFilter: _roomFilter,
        selectedRoomName: _selectedRoomName,
        employees: _employees,
        onPlantChanged: _onPlantChanged,
        onRoomFilterChanged: (filter) => setState(() => _roomFilter = filter),
        onRoomSelected: (roomName) {
          setState(() {
            _selectedRoomName = roomName;
          });
          final room = _localRooms[roomName];
          if (room != null && room['id'] != _lastLoadedRoomId) {
            _lastLoadedRoomId = room['id'];
            _bloc.add(LoadRoomDetailsEvent(room['id']));
          }
        },
        onJobCreated: _onJobCreated,
        onJobStatusChanged: _onJobStatusChanged,
        onSwitchToTasks: _onSwitchToTasks,
        onStartCycle: _onStartCycle,
        onResetRoom: _onResetRoom,
      );
    }
    if (_activeTab == 'harvest') {
      return HarvestTabScreen(
        isDark: isDark,
        localRooms: _localRooms,
        roomCrews: _roomCrews,
        pickingPlans: _pickingPlans,
        onCheckIn: _onCheckIn,
        onCheckOut: _onCheckOut,
        onPickedYieldUpdated: _onPickedYieldUpdated,
        onSafetyContact: _onTriggerSafetyContact,
        activePlant: _activePlant,
        onPlantChanged: _onPlantChanged,
      );
    }
    if (_activeTab == 'coolroom') {
      return CoolRoomTabScreen(
        isDark: isDark,
        localRooms: _localRooms,
        activePlant: _activePlant,
        stockButton: _stockButton,
        stockMedium: _stockMedium,
        stockOpen: _stockOpen,
        orders: _orders,
        onSendPickingPlan: _onSendPickingPlan,
        onDeliverOrder: _onDeliverOrder,
        onPlantChanged: _onPlantChanged,
      );
    }
    if (_activeTab == 'maintenance') {
      return MaintenanceTabScreen(
        isDark: isDark,
        localRooms: _localRooms,
        maintenanceJobs: _maintenanceJobs,
        onCreateMaintenanceJob: _onCreateMaintenanceJob,
        onUpdateMaintStatus: _onUpdateMaintStatus,
      );
    }
    if (_activeTab == 'performance') {
      return const GrowingPerformanceBoardScreen(isEmbedded: true);
    }
    if (_activeTab == 'tasks') {
      return TasksTabScreen(
        isDark: isDark,
        localRooms: _localRooms,
        tasksSelectedRoomName: _tasksSelectedRoomName,
        tasksViewMode: _tasksViewMode,
        onRoomSelected: (rName) {
          setState(() => _tasksSelectedRoomName = rName);
          final room = _localRooms[rName];
          if (room != null) {
            _bloc.add(LoadRoomDetailsEvent(room['id']));
          }
        },
        onViewModeChanged: (mode) => setState(() => _tasksViewMode = mode),
        onJobStatusChanged: _onTaskStatusAdvanced,
      );
    }
    if (_activeTab == 'chat') {
      return ChatTabScreen(
        isDark: isDark,
      );
    }
    if (_activeTab == 'safety') {
      return SafetyTabScreen(
        isDark: isDark,
        safetyLogs: _safetyLogs,
        onTriggerEmergency: (active) =>
            setState(() => _emergencyActive = active),
        onTriggerSafetyCheckAll: _onTriggerSafetyCheckAll,
        onResetSafety: _onResetSafety,
        onReportIncident: _onReportIncident,
      );
    }
    if (_activeTab == 'employees') {
      return EmployeesTabScreen(
        isDark: isDark,
        employees: _employees,
        onAddEmployee: _onAddEmployee,
        onEditEmployee: _onEditEmployee,
        onImportEmployees: _onImportEmployees,
      );
    }
    if (_activeTab == 'departments') {
      return DepartmentsTabScreen(
        isDark: isDark,
      );
    }
    if (_activeTab == 'jobtypes') {
      // Sidebar already hides this destination below Level 2, but a direct
      // _activeTab assignment (e.g. deep link) still gets the same gate —
      // the screen re-checks on its own too (see JobTypesManagementScreen).
      if (!_canManageJobTypes) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _language == 'vi'
                      ? 'Chỉ Quản lý Cấp 2 trở lên mới truy cập được mục này.'
                      : 'Only Level 2+ management can access this screen.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }
      return JobTypesManagementScreen(isDark: isDark);
    }
    if (_activeTab == 'settings') {
      return SettingsTabScreen(
        isDark: isDark,
      );
    }
    return const SizedBox.shrink();
  }

  // --- Callbacks for State Updates ---

  void _onStartCycle(
      String roomName, String wateringPlan, String prochlorazRate) {
    final room = _localRooms[roomName];
    if (room != null) {
      _bloc.add(StartCycleEvent(
        room['id'],
        wateringPlan: wateringPlan,
        prochlorazRate: prochlorazRate,
      ));
    }
  }

  void _onResetRoom(String roomName) {
    final room = _localRooms[roomName];
    if (room != null) {
      _bloc.add(ResetRoomEvent(room['id']));
    }
  }

  void _onJobCreated(
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
    bool isSoloJob = false,
  }) {
    var room = _localRooms[roomName];
    if (room == null) {
      room = _localRooms.values.firstWhere(
        (r) =>
            r['name'] == roomName ||
            r['id'] == roomName ||
            r['name'] == roomName.replaceAll('Grow Room', 'Room').trim() ||
            'Grow Room ${r['name'].replaceAll('Room', '').trim()}' == roomName,
        orElse: () => <String, dynamic>{},
      );
    }
    final roomId = (room.isNotEmpty ? room['id'] : null) ??
        roomName.toLowerCase().replaceAll(' ', '_');

    if (jobType == 'alone_worker' || isSoloJob) {
      // jobType may be a custom solo type from the Job Types catalogue
      // (e.g. "deep_clean_solo") — title still needs to read like a job
      // name, not the raw slug.
      final title = jobType == 'alone_worker'
          ? 'Alone Worker (Solo)'
          : '${jobType.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ')} (Solo)';
      _bloc.add(AddSoloJobEvent(
        roomId: roomId,
        title: title,
        assignee: assignee,
        timeLimit: timeLimit ?? 45,
        coLevel: coLevel,
        co2Level: co2Level,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
        jobType: jobType,
      ));
      return;
    }
    String planDetails = '';
    if (jobType == 'watering') {
      planDetails = wateringPlan == '2side'
          ? '2 Side $wateringVol L/m²'
          : '1 Side $wateringVol L/m²';
    }
    String prochlorazRate = '';
    if (jobType == 'prochloraz') {
      prochlorazRate = '${rate}g/m²';
    }

    _bloc.add(CreateCustomJobEvent(
      roomId: roomId,
      name: jobType.toUpperCase(),
      jobType: jobType,
      assignee: assignee,
      priority: 'normal',
      scheduledAt: DateTime.now(),
      planDetails: planDetails,
      prochlorazRate: prochlorazRate,
      notes: notes,
      projectName: 'Costa M2 Operations',
    ));
  }

  void _onJobStatusChanged(String roomName, dynamic jobId, bool done) {
    final room = _localRooms[roomName];
    if (room != null) {
      _bloc.add(UpdateJobStatusEvent(
        jobId as String,
        room['id'],
        done ? 'completed' : 'todo',
      ));
    }
  }

  void _onSwitchToTasks(String roomName, String viewMode) {
    setState(() {
      _tasksSelectedRoomName = roomName;
      _activeTab = 'tasks';
      _tasksViewMode = viewMode;
    });
    final room = _localRooms[roomName];
    if (room != null) {
      _lastLoadedRoomId = room['id'];
      _bloc.add(LoadRoomDetailsEvent(room['id']));
    }
  }

  void _onCheckIn(String code, String roomSelected) async {
    final repo = MushroomsRepository();
    final dbEmployees = await repo.getEmployees();
    final matches = dbEmployees.where((e) => e['id'] == code);
    if (matches.isEmpty) {
      _showMsg('Employee code not found!');
      return;
    }
    final emp = matches.first;
    final existingCrews = await repo.getRoomCrews();
    final alreadyCheckedIn = existingCrews.where((c) => c['empId'] == code);
    if (alreadyCheckedIn.isNotEmpty) {
      final oldRoom = alreadyCheckedIn.first['roomName']!;
      _showMsg(
          'Employee ${emp['name']} is already checked-in at Grow Room ${oldRoom.replaceAll('Room', '')}. Please check-out first!');
      return;
    }
    await repo.checkInRoomCrew(
        roomName: roomSelected, empName: emp['name']!, empId: code);

    final crews = await repo.getRoomCrews();
    final roomCrewNames = crews
        .where((c) => c['roomName'] == roomSelected)
        .map((c) => c['empName']!)
        .toList();

    await repo.logSafetyCheckin(
      jobId: 'crew_checkin',
      workerId: emp['name']!,
      eventType: 'checkin',
      notes:
          'Checked in to $roomSelected. Solo status: ${roomCrewNames.length <= 1}',
    );

    if (roomCrewNames.length == 1) {
      final room = _localRooms[roomSelected];
      if (room != null) {
        _bloc.add(AddSoloJobEvent(
          roomId: room['id'],
          title: 'Solo Picking',
          assignee: emp['name']!,
          timeLimit: 45,
        ));
      }
    } else if (roomCrewNames.length >= 2) {
      final room = _localRooms[roomSelected];
      if (room != null) {
        final jobs = await repo.getJobsForRoom(room['id']);
        final activeSoloPickingJobs = jobs.where((j) =>
            j['job_type'] == 'alone_worker' &&
            j['name'] == 'Solo Picking' &&
            j['status'] == 'in_progress');
        for (final job in activeSoloPickingJobs) {
          _bloc
              .add(CompleteJobEvent(job['id'] as String, room['id'] as String));
        }
      }
    }

    _loadMushroomData();
  }

  void _onCheckOut(String code, String roomSelected) async {
    final repo = MushroomsRepository();
    final dbEmployees = await repo.getEmployees();
    final matches = dbEmployees.where((e) => e['id'] == code);
    if (matches.isEmpty) {
      _showMsg('Employee code not found!');
      return;
    }
    final emp = matches.first;
    await repo.checkOutRoomCrew(roomName: roomSelected, empId: code);

    await repo.logSafetyCheckin(
      jobId: 'crew_checkout',
      workerId: emp['name']!,
      eventType: 'checkout',
      notes: 'Checked out from Room $roomSelected.',
    );

    final room = _localRooms[roomSelected];
    if (room != null) {
      final List<Map<String, dynamic>> jobs =
          List<Map<String, dynamic>>.from(room['jobs']);
      final activeSolo = jobs.firstWhere(
        (j) =>
            j['assignee'] == emp['name'] &&
            j['notes']?.contains('Solo') == true &&
            j['status'] != 'done',
        orElse: () => {},
      );
      if (activeSolo.isNotEmpty) {
        _bloc.add(CompleteJobEvent(activeSolo['id'], room['id']));
      }
    }

    _loadMushroomData();
  }

  void _onPickedYieldUpdated(String name, double pickedVal) async {
    final room = _localRooms[name];
    if (room == null) return;
    final targetVal = room['targetYield'] ?? 0.0;
    final repo = MushroomsRepository();
    await repo.updateRoomPickedYield(room['id'], pickedVal);

    if (pickedVal >= targetVal && targetVal > 0) {
      final plan = room['pickingPlan'] as Map<String, dynamic>?;
      if (plan != null) {
        await repo.updateMushroomStock(
            'button', plan['button']?.toDouble() ?? 0.0);
        await repo.updateMushroomStock(
            'cup', plan['medium']?.toDouble() ?? 0.0);
        await repo.updateMushroomStock('flat', plan['open']?.toDouble() ?? 0.0);
        await repo.clearRoomPickingPlan(room['id']);
      }
    }
    _loadMushroomData();
    _bloc.add(LoadRoomsEvent());
  }

  void _onPlantChanged(String plant) {
    setState(() {
      _activePlant = plant;
      final firstRoom = _localRooms.values.firstWhere(
          (r) => r['plant'] == plant,
          orElse: () => _localRooms.values.first);
      _selectedRoomName = firstRoom['name'];
    });
  }

  void _onSendPickingPlan(
      String roomSelected, int buttonVal, int mediumVal, int openVal,
      [String mushroomType = 'White']) async {
    final total = buttonVal + mediumVal + openVal;
    if (total <= 0) {
      _showMsg('Please enter a target yield greater than 0!');
      return;
    }
    final room = _localRooms[roomSelected];
    if (room == null) return;

    final planMap = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'roomName': roomSelected,
      'plant': _activePlant,
      'button': buttonVal,
      'medium': mediumVal,
      'open': openVal,
      'mushroomType': mushroomType,
      'sentAt': DateTime.now().toLocal().toString().substring(11, 16)
    };

    final repo = MushroomsRepository();
    await repo.updateRoomPickingPlan(
      room['id'],
      targetYield: total.toDouble(),
      planJson: jsonEncode(planMap),
    );

    _loadMushroomData();
    _bloc.add(LoadRoomsEvent());
    _showMsg('Picking plan created and successfully sent to Harvest!');
  }

  void _onDeliverOrder(Map<String, dynamic> order) async {
    final repo = MushroomsRepository();
    final orderId = order['id'] as String;

    if (orderId == 'ORD-001') {
      if (_stockButton >= 50 && _stockMedium >= 100) {
        await repo.updateMushroomStock('button', -50.0);
        await repo.updateMushroomStock('cup', -100.0);
        await repo.deliverMushroomOrder(orderId);
        _showMsg('Delivered order ORD-001 successfully!');
      } else {
        _showMsg(
            'Insufficient stock in the cool room! Please schedule more picking.');
      }
    } else if (orderId == 'ORD-002') {
      if (_stockMedium >= 80 && _stockOpen >= 30) {
        await repo.updateMushroomStock('cup', -80.0);
        await repo.updateMushroomStock('flat', -30.0);
        await repo.deliverMushroomOrder(orderId);
        _showMsg('Delivered order ORD-002 successfully!');
      } else {
        _showMsg('Insufficient stock in the cool room!');
      }
    }
    _loadMushroomData();
  }

  void _onCreateMaintenanceJob(String title, String plant, String room,
      String assignee, String priority, String notes) async {
    final repo = MushroomsRepository();
    await repo.createMaintenanceTicket(
      title: title,
      plant: plant,
      room: room,
      assignee: assignee,
      priority: priority,
      notes: notes,
    );
    _loadMushroomData();
    _showMsg('A new maintenance order has been successfully created!');
  }

  void _onUpdateMaintStatus(String jobId, String status) async {
    final repo = MushroomsRepository();
    await repo.updateMaintenanceTicketStatus(jobId, status);
    _loadMushroomData();
  }

  void _onTaskStatusAdvanced(
      String roomName, dynamic jobId, String nextStatus) {
    final room = _localRooms[roomName];
    if (room != null) {
      String dbStatus = 'todo';
      if (nextStatus == 'inprog') dbStatus = 'in_progress';
      if (nextStatus == 'review') dbStatus = 'review';
      if (nextStatus == 'done' || nextStatus == 'completed')
        dbStatus = 'completed';

      _bloc.add(UpdateJobStatusEvent(
        jobId as String,
        room['id'],
        dbStatus,
      ));
    }
  }

  void _onSendMessage(String text) async {
    final repo = MushroomsRepository();
    await repo.sendChatMessage(
      sender: 'Vinh',
      contact: _activeChatContact,
      text: text,
      role: _activeRole,
    );
    _loadMushroomData();

    if (_activeChatContact == 'Sarah (Sales)' &&
        text.toLowerCase().contains('picking')) {
      Timer(const Duration(seconds: 1), () async {
        await repo.sendChatMessage(
          sender: 'Sarah',
          contact: 'Sarah (Sales)',
          text: 'Tuyệt vời! Mình báo Aeon Mall xuất hóa đơn luôn.',
          role: 'Sales Lead',
        );
        _loadMushroomData();
      });
    }
  }

  void _onReportIncident(String location, String desc) {
    _showMsg(
        'Successfully submitted incident report to the Chief Technician and Supervisor.');
  }

  void _onTriggerSafetyContact(String roomNum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Secure communication'),
        content: Text(
            'Sending periodic check‑in signals and pinging the solo worker’s phone at ${roomNum.replaceAll('Room', 'Grow Room')}...'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  void _onTriggerSafetyCheckAll() {
    _showMsg(
        'A signal has been issued requesting all personnel to verify their check‑in.');
  }

  void _onResetSafety() async {
    final repo = MushroomsRepository();
    await repo.clearRoomCrews();
    setState(() {
      _emergencyActive = false;
    });
    _loadMushroomData();
    _showMsg('Safety metrics have been restored.');
  }

  void _onAddEmployee(String id, String name, String role,
      [String? department, String? password, String? status, String? pickerTeamColor]) async {
    final repo = MushroomsRepository();
    await repo.addEmployee(id, name, role, department, password, status, pickerTeamColor);
    _loadMushroomData();
  }

  void _onEditEmployee(String id, String name, String role,
      [String? department, String? status, String? pickerTeamColor]) async {
    final repo = MushroomsRepository();
    await repo.updateEmployee(id, name, role, department, status, pickerTeamColor);
    _loadMushroomData();
  }

  void _onImportEmployees(List<Map<String, String>> list) async {
    final repo = MushroomsRepository();
    for (var emp in list) {
      await repo.addEmployee(
          emp['id']!, emp['name']!, emp['role']!, emp['department']);
    }
    _loadMushroomData();
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

  void _showMsg(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }
}
