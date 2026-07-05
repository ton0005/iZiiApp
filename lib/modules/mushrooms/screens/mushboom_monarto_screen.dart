import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  const MushboomMonartoScreen({super.key});

  @override
  State<MushboomMonartoScreen> createState() => _MushboomMonartoScreenState();
}

class _MushboomMonartoScreenState extends State<MushboomMonartoScreen> {
  // Tab state
  String _activeTab =
      'growing'; // growing, harvest, coolroom, maintenance, tasks, chat, safety
  String _activePlant = 'M2'; // M1 or M2
  String? _selectedRoomName;
  String? _lastLoadedRoomId;
  String _activeRole =
      'Growing Lead'; // Vinh (Growing Lead), Hải (Harvest Supervisor), Trúc (Cool Room Manager), Nam (Maintenance Lead)
  String _language = 'en'; // vi or en
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
      'title': 'Khử trùng quạt hút gió',
      'plant': 'M2',
      'room': '33',
      'assignee': 'Nam T.',
      'priority': 'normal',
      'status': 'inprog',
      'notes': 'Bảo trì bộ lọc khuẩn định kỳ.'
    },
    {
      'id': 'MNT-102',
      'title': 'Cân chỉnh cảm biến độ ẩm',
      'plant': 'M1',
      'room': '12',
      'assignee': 'Lợi P.',
      'priority': 'high',
      'status': 'todo',
      'notes': 'Cảm biến lệch 5% so với đo tay.'
    }
  ];

  // Chat History
  final Map<String, List<Map<String, String>>> _chatHistory = {
    'Growing Crew': [
      {
        'sender': 'Minh T.',
        'text': 'Đã hoàn thành tưới nước phòng 33 sáng nay.',
        'time': '08:30',
        'role': 'Growing Specialist'
      },
      {
        'sender': 'Vinh',
        'text': 'Tốt lắm, kiểm tra độ ẩm phòng 34 luôn nhé.',
        'time': '08:45',
        'role': 'Growing Lead'
      }
    ],
    'Sarah (Sales)': [
      {
        'sender': 'Sarah',
        'text':
            'Aeon Mall cần gấp 150kg nấm cỡ vừa vào chiều nay, kho đủ hàng không Trúc ơi?',
        'time': '09:15',
        'role': 'Sales Lead'
      },
      {
        'sender': 'Trúc',
        'text': 'Để mình lập kế hoạch picking gấp gửi cho Harvest.',
        'time': '09:20',
        'role': 'Cool Room Manager'
      }
    ],
    'Mike (Site Manager)': [
      {
        'sender': 'Mike',
        'text': 'Đã cập nhật hệ thống báo động an toàn cho branch mới.',
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

  // BLoC
  late MushroomsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = MushroomsBloc()..add(LoadRoomsEvent());
    _loadMushroomData();
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

    setState(() {
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

            final room = _localRooms[_selectedRoomName];
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
                _localRooms[rName]!['jobs'] = state.selectedRoomJobs
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
                                  : 'todo'),
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
                      final isDesktop = constraints.maxWidth > 800;
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
          Row(
            children: [
              // Role Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: FarmColors.borderStrong),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _activeRole,
                    items: const [
                      DropdownMenuItem(
                          value: 'Growing Lead',
                          child: Text('Vinh (Growing Lead)',
                              style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'Harvest Supervisor',
                          child: Text('Hải (Harvest Sup)',
                              style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'Cool Room Manager',
                          child: Text('Trúc (Cool Room Mgr)',
                              style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'Maintenance Lead',
                          child: Text('Nam (Maint Lead)',
                              style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _activeRole = val);
                    },
                  ),
                ),
              )
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
    if (_activeTab == 'tasks') {
      return _language == 'vi'
          ? 'Dự án & Công việc (Tasks)'
          : 'Project & Tasks';
    }
    if (_activeTab == 'chat') {
      return _language == 'vi' ? 'Trò chuyện (Chat)' : 'Encrypted Chat';
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
    if (_activeTab == 'tasks') return 'Kanban Board & Gantt Chart Timeline';
    if (_activeTab == 'chat') return 'Offline BLE P2P Chat Simulator';
    return 'Solo Working Alerts & Incident Manager';
  }

  // --- Sidebar ---
  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 240,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          // Sidebar Logo Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: isDark ? Colors.white10 : FarmColors.borderLight)),
            ),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dashboard_rounded,
                        color: FarmColors.forestGreen),
                    SizedBox(width: 8),
                    Text('iZiiApp',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: FarmColors.forestGreen)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.call_split, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('mushroom-farm-fork',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSidebarLabel(
                    _language == 'vi' ? 'PHÒNG BAN' : 'DEPARTMENTS'),
                _buildSidebarItem(
                    'growing',
                    Icons.corporate_fare_rounded,
                    _language == 'vi' ? 'Trồng trọt (Growing)' : 'Growing',
                    FarmColors.forestGreen),
                _buildSidebarItem(
                    'harvest',
                    Icons.cut_rounded,
                    _language == 'vi' ? 'Thu hoạch (Harvest)' : 'Harvest',
                    FarmColors.harvestPurple),
                _buildSidebarItem(
                    'coolroom',
                    Icons.ac_unit_rounded,
                    _language == 'vi' ? 'Kho lạnh (Cool Room)' : 'Cool Room',
                    FarmColors.coolBlue),
                _buildSidebarItem(
                    'maintenance',
                    Icons.build_rounded,
                    _language == 'vi' ? 'Bảo trì (Maintenance)' : 'Maintenance',
                    FarmColors.maintenanceOrange),
                const Divider(),
                _buildSidebarLabel(
                    _language == 'vi' ? 'HỆ THỐNG' : 'UTILITIES'),
                _buildSidebarItem(
                    'tasks',
                    Icons.view_kanban_rounded,
                    _language == 'vi' ? 'Công việc (Tasks)' : 'Tasks',
                    Colors.blueGrey),
                _buildSidebarItem(
                    'chat',
                    Icons.question_answer_rounded,
                    _language == 'vi' ? 'Trò chuyện (Chat)' : 'Chat',
                    Colors.blue),
                _buildSidebarItem(
                    'safety',
                    Icons.shield_rounded,
                    _language == 'vi' ? 'An toàn (Safety)' : 'Safety',
                    Colors.redAccent),
                _buildSidebarItem(
                    'employees',
                    Icons.badge_rounded,
                    _language == 'vi' ? 'Nhân sự (Employees)' : 'Employees',
                    Colors.teal),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebarLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildSidebarItem(
      String tabId, IconData icon, String label, Color indicatorColor) {
    final isActive = _activeTab == tabId;
    return InkWell(
      onTap: () => switchTab(tabId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? FarmColors.forestGreenLight.withOpacity(0.3)
              : Colors.transparent,
          border: isActive
              ? Border(left: BorderSide(color: indicatorColor, width: 4))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: isActive ? indicatorColor : Colors.grey),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? indicatorColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void switchTab(String tabId) {
    setState(() {
      _activeTab = tabId;
    });
    _loadMushroomData();
  }

  // --- Main Content Switcher ---
  Widget _buildMainContent(bool isDark) {
    if (_activeTab == 'growing') {
      return GrowingTabScreen(
        isDark: isDark,
        localRooms: _localRooms,
        activePlant: _activePlant,
        roomFilter: _roomFilter,
        selectedRoomName: _selectedRoomName,
        onPlantChanged: (plant) {
          setState(() {
            _activePlant = plant;
            final firstRoom = _localRooms.values.firstWhere(
                (r) => r['plant'] == plant,
                orElse: () => _localRooms.values.first);
            _selectedRoomName = firstRoom['name'];
          });
        },
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
        onImportEmployees: _onImportEmployees,
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
  }) {
    final room = _localRooms[roomName];
    if (room != null) {
      if (jobType == 'alone_worker') {
        _bloc.add(AddSoloJobEvent(
          roomId: room['id'],
          title: 'Alone Worker (Solo)',
          assignee: assignee,
          timeLimit: timeLimit ?? 45,
          coLevel: coLevel,
          co2Level: co2Level,
          checkInTime: checkInTime,
          checkOutTime: checkOutTime,
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
        roomId: room['id'],
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
          'Nhân viên ${emp['name']} đang check-in tại Grow Room ${oldRoom.replaceAll('Room', '')}. Vui lòng check-out trước!');
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

  void _onSendPickingPlan(
      String roomSelected, int buttonVal, int mediumVal, int openVal) async {
    final total = buttonVal + mediumVal + openVal;
    if (total <= 0) {
      _showMsg('Vui lòng nhập sản lượng lớn hơn 0!');
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
    _showMsg('Đã tạo kế hoạch picking và gửi đến Harvest thành công!');
  }

  void _onDeliverOrder(Map<String, dynamic> order) async {
    final repo = MushroomsRepository();
    final orderId = order['id'] as String;

    if (orderId == 'ORD-001') {
      if (_stockButton >= 50 && _stockMedium >= 100) {
        await repo.updateMushroomStock('button', -50.0);
        await repo.updateMushroomStock('cup', -100.0);
        await repo.deliverMushroomOrder(orderId);
        _showMsg('Giao đơn hàng ORD-001 thành công!');
      } else {
        _showMsg(
            'Không đủ nấm tồn kho trong kho lạnh! Vui lòng lập thêm kế hoạch Picking.');
      }
    } else if (orderId == 'ORD-002') {
      if (_stockMedium >= 80 && _stockOpen >= 30) {
        await repo.updateMushroomStock('cup', -80.0);
        await repo.updateMushroomStock('flat', -30.0);
        await repo.deliverMushroomOrder(orderId);
        _showMsg('Giao đơn hàng ORD-002 thành công!');
      } else {
        _showMsg('Không đủ nấm tồn kho trong kho lạnh!');
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
    _showMsg('Đã tạo lệnh bảo trì mới thành công!');
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
      _bloc.add(UpdateJobStatusEvent(
        jobId as String,
        room['id'],
        nextStatus == 'done' ? 'completed' : nextStatus,
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
        'Đã gửi báo cáo sự cố thành công tới Kỹ thuật trưởng và Supervisor.');
  }

  void _onTriggerSafetyContact(String roomNum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liên lạc an toàn'),
        content: Text(
            'Sending periodic check‑in signals and pinging the solo worker’s phone at ${roomNum.replaceAll('Room', 'Grow Room')}...'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))
        ],
      ),
    );
  }

  void _onTriggerSafetyCheckAll() {
    _showMsg('Đã phát tín hiệu yêu cầu tất cả nhân sự xác minh check-in.');
  }

  void _onResetSafety() async {
    final repo = MushroomsRepository();
    await repo.clearRoomCrews();
    setState(() {
      _emergencyActive = false;
    });
    _loadMushroomData();
    _showMsg('Đã khôi phục các chỉ số an toàn.');
  }

  void _onAddEmployee(String id, String name, String role) async {
    final repo = MushroomsRepository();
    await repo.addEmployee(id, name, role);
    _loadMushroomData();
  }

  void _onImportEmployees(List<Map<String, String>> list) async {
    final repo = MushroomsRepository();
    for (var emp in list) {
      await repo.addEmployee(emp['id']!, emp['name']!, emp['role']!);
    }
    _loadMushroomData();
  }

  void _showMsg(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông báo'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }
}
