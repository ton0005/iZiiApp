import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/izii_colors.dart';
import '../bloc/mushrooms_bloc.dart';
import '../../../core/localization/app_localizations.dart';

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

class MushroomsDashboardScreen extends StatefulWidget {
  const MushroomsDashboardScreen({super.key});

  @override
  State<MushroomsDashboardScreen> createState() =>
      _MushroomsDashboardScreenState();
}

class _MushroomsDashboardScreenState extends State<MushroomsDashboardScreen> {
  // Tab state
  String _activeTab =
      'growing'; // growing, harvest, coolroom, maintenance, tasks, chat, safety
  String _activePlant = 'M2'; // M1 or M2
  String? _selectedRoomName;
  String _activeRole =
      'Growing Lead'; // Vinh (Growing Lead), Hải (Harvest Supervisor), Trúc (Cool Room Manager), Nam (Maintenance Lead)
  String _language = 'vi'; // vi or en
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

  // Controller for chat input
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // BLoC
  late MushroomsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = MushroomsBloc()..add(LoadRoomsEvent());
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
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
          'targetYield': 0.0,
          'pickedYield': 0.0,
          'pickingPlan': null,
          'jobs': [
            {
              'id': 1,
              'name': 'Filling',
              'icon': Icons.archive,
              'status': 'done',
              'assignee': 'Minh T.',
              'date': '14 Jun',
              'notes': 'Giá thể nấm chuẩn chất lượng.'
            },
            {
              'id': 2,
              'name': 'Airing',
              'icon': Icons.wind_power,
              'status': 'inprog',
              'assignee': 'Lan N.',
              'date': '15 Jun',
              'notes': 'Bọc plastic giữ ẩm floor wet.'
            },
            {
              'id': 3,
              'name': 'Watering',
              'icon': Icons.water_drop,
              'status': 'todo',
              'assignee': 'Hùng V.',
              'date': '16 Jun',
              'notes': 'Tưới nước định kỳ 2 Side.'
            }
          ]
        };
      } else {
        // Update stage & status from database
        _localRooms[name]!['status'] =
            r['status'] ?? _localRooms[name]!['status'];
        _localRooms[name]!['current_stage'] =
            r['current_stage'] ?? _localRooms[name]!['current_stage'];
        _localRooms[name]!['day_in_cycle'] =
            r['day_in_cycle'] ?? _localRooms[name]!['day_in_cycle'];
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
                              'CẢNH BÁO BÁO ĐỘNG KHẨN CẤP: Rò rỉ khí CO2 tại phòng 55! Hãy sơ tán lập tức.',
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
                          child: const Text('Xác nhận',
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
              // Language Switcher
              TextButton.icon(
                icon: const Icon(Icons.language, size: 18, color: Colors.grey),
                label: Text(_language == 'vi' ? 'Tiếng Việt' : 'English',
                    style: const TextStyle(color: Colors.grey)),
                onPressed: () {
                  setState(() {
                    _language = _language == 'vi' ? 'en' : 'vi';
                  });
                },
              ),
              const SizedBox(width: 16),
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
    if (_activeTab == 'growing')
      return _language == 'vi' ? 'Trồng trọt (Growing)' : 'Growing Department';
    if (_activeTab == 'harvest')
      return _language == 'vi' ? 'Thu hoạch (Harvest)' : 'Harvest Department';
    if (_activeTab == 'coolroom')
      return _language == 'vi' ? 'Kho lạnh (Cool Room)' : 'Cool Room Warehouse';
    if (_activeTab == 'maintenance')
      return _language == 'vi' ? 'Bảo trì (Maintenance)' : 'Maintenance Log';
    if (_activeTab == 'tasks')
      return _language == 'vi'
          ? 'Dự án & Công việc (Tasks)'
          : 'Project & Tasks';
    if (_activeTab == 'chat')
      return _language == 'vi' ? 'Trò trò (Chat)' : 'Encrypted Chat';
    return _language == 'vi' ? 'An toàn lao động (Safety)' : 'Safety Dashboard';
  }

  String _getTabSubtitle() {
    if (_activeTab == 'growing') return 'Costa Mushroom — Plant $_activePlant';
    if (_activeTab == 'harvest')
      return 'Check-in nhân sự & Giám sát hái nấm thực tế';
    if (_activeTab == 'coolroom')
      return 'Warehouse Inventory & Picking Plans Dispatcher';
    if (_activeTab == 'maintenance')
      return 'Lịch sử bảo dưỡng & Báo lỗi kỹ thuật';
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
  }

  // --- Main Content Switcher ---
  Widget _buildMainContent(bool isDark) {
    if (_activeTab == 'growing') return _buildGrowingContent(isDark);
    if (_activeTab == 'harvest') return _buildHarvestContent(isDark);
    if (_activeTab == 'coolroom') return _buildCoolRoomContent(isDark);
    if (_activeTab == 'maintenance') return _buildMaintenanceContent(isDark);
    if (_activeTab == 'tasks') return _buildTasksContent(isDark);
    if (_activeTab == 'chat') return _buildChatContent(isDark);
    return _buildSafetyContent(isDark);
  }

  // ==========================================
  // GROWING DEPARTMENT
  // ==========================================
  Widget _buildGrowingContent(bool isDark) {
    // KPI Data
    final totalCount =
        _localRooms.values.where((r) => r['plant'] == _activePlant).length;
    final activeCount = _localRooms.values
        .where((r) => r['plant'] == _activePlant && r['status'] == 'active')
        .length;
    final idleCount = _localRooms.values
        .where((r) => r['plant'] == _activePlant && r['status'] == 'idle')
        .length;

    // Filters
    final roomsFiltered = _localRooms.values.where((r) {
      if (r['plant'] != _activePlant) return false;
      if (_roomFilter == 'active') return r['status'] == 'active';
      if (_roomFilter == 'idle') return r['status'] == 'idle';
      return true;
    }).toList();

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
                      backgroundColor: _activePlant == 'M2'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _activePlant = 'M2'),
                    child: const Text('Plant M2 (Rooms 33-66)'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activePlant == 'M1'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _activePlant = 'M1'),
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
                label: const Text('Thêm Job Mới'),
                onPressed: () => _showNewJobDialog(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          // KPIs Grid Row
          Row(
            children: [
              _buildKpiCard(
                  'TỔNG SỐ PHÒNG', '$totalCount', 'Phòng $_activePlant', false),
              const SizedBox(width: 12),
              _buildKpiCard('ĐANG HOẠT ĐỘNG', '$activeCount',
                  'Có chu kỳ hoạt động', false),
              const SizedBox(width: 12),
              _buildKpiCard('ĐANG TRỐNG (IDLE)', '$idleCount',
                  'Có thể bắt đầu vụ mới', false),
              const SizedBox(width: 12),
              _buildKpiCard('SỰ CỐ AN TOÀN', '0', 'Bình thường', false),
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
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: FarmColors.borderLight)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFilterBtn('Tất cả', 'all'),
                            _buildFilterBtn('Chạy', 'active'),
                            _buildFilterBtn('Trống', 'idle'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: roomsFiltered.length,
                          itemBuilder: (context, idx) {
                            final room = roomsFiltered[idx];
                            final name = room['name'] as String;
                            final isSel = _selectedRoomName == name;
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
                              onTap: () => setState(() {
                                _selectedRoomName = name;
                              }),
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
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: Border.all(color: FarmColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _selectedRoomName != null
                        ? _buildRoomDetailsPanel(isDark, _selectedRoomName!)
                        : const Center(
                            child: Text('Hãy chọn một phòng để xem chi tiết.')),
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
    final active = _roomFilter == value;
    return InkWell(
      onTap: () => setState(() => _roomFilter = value),
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
      name = 'TƯỚI NƯỚC';
    }
    if (stage == 'prochloraz') {
      bg = Colors.red;
      name = 'PHUN NẤM';
    }
    if (stage == 'packuptree') {
      bg = Colors.orange;
      name = 'DỌN RỄ';
    }
    if (stage == 'cleanroom') {
      bg = Colors.green;
      name = 'DỌN PHÒNG';
    }
    if (stage == 'idle') {
      bg = Colors.grey.shade400;
      name = 'TRỐNG';
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
    final room = _localRooms[roomName]!;
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
                Text('Phòng $roomName',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Plant ${room['plant']} · Diện tích: ${room['area']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  icon:
                      const Icon(Icons.timeline, color: Colors.grey, size: 16),
                  label: const Text('Timeline',
                      style: TextStyle(color: Colors.grey)),
                  onPressed: () {
                    setState(() {
                      _tasksSelectedRoomName = roomName;
                      _activeTab = 'tasks';
                      _tasksViewMode = 'gantt';
                    });
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.view_kanban,
                      color: Colors.grey, size: 16),
                  label: const Text('Kanban',
                      style: TextStyle(color: Colors.grey)),
                  onPressed: () {
                    setState(() {
                      _tasksSelectedRoomName = roomName;
                      _activeTab = 'tasks';
                      _tasksViewMode = 'kanban';
                    });
                  },
                )
              ],
            )
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetaInfoBox('CHU KỲ', room['cycle']),
            _buildMetaInfoBox(
                'NGÀY TRONG CHU KỲ', room['day_in_cycle'].toString()),
            _buildMetaInfoBox(
                'GIAI ĐOẠN', room['current_stage'].toString().toUpperCase()),
            _buildMetaInfoBox('TIẾN ĐỘ CHU KỲ', '${(progress * 100).toInt()}%'),
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
        const Text('DANH SÁCH PIPELINE CÔNG VIỆC',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, idx) {
              final job = jobs[idx];
              final done = job['status'] == 'done';

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
                      children: [
                        Checkbox(
                          value: done,
                          onChanged: (val) {
                            setState(() {
                              job['status'] = (val ?? false) ? 'done' : 'todo';
                            });
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
    String roomSelected = _localRooms.keys
        .firstWhere((k) => _localRooms[k]!['plant'] == _activePlant);
    String assignee = 'Minh T.';
    String notes = '';

    // Watering fields
    String wateringPlan = '2side';
    double wateringVol = 2.0;

    // Prochloraz fields
    double rate = 1.3;
    double area = 112.0;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final chemicalTotal = (rate * area).toStringAsFixed(1);
            return AlertDialog(
              title: const Text('Tạo Job Trồng Trọt Mới',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Phòng'),
                        value: roomSelected,
                        items: _localRooms.keys
                            .where(
                                (k) => _localRooms[k]!['plant'] == _activePlant)
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text('Phòng $r')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setDialogState(() => roomSelected = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: 'Loại công việc (Job Type)'),
                        value: jobType,
                        items: const [
                          DropdownMenuItem(
                              value: 'filling',
                              child: Text('Filling (Nạp giá thể)')),
                          DropdownMenuItem(
                              value: 'airing',
                              child: Text('Airing (Plastic floor wet)')),
                          DropdownMenuItem(
                              value: 'watering',
                              child: Text('Watering (Tưới nước)')),
                          DropdownMenuItem(
                              value: 'prochloraz',
                              child: Text('Prochloraz (Phun nấm)')),
                          DropdownMenuItem(
                              value: 'packuptree',
                              child: Text('Pack Up Tree (Dọn rễ)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => jobType = val);
                        },
                      ),
                      if (jobType == 'watering') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                              labelText: 'Phương án tưới'),
                          value: wateringPlan,
                          items: const [
                            DropdownMenuItem(
                                value: '2side',
                                child: Text('Tưới 2 bên giường (2 Side)')),
                            DropdownMenuItem(
                                value: '1side',
                                child: Text('Tưới 1 bên giường (1 Side)')),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => wateringPlan = val);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Lượng nước (L/m²)'),
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
                                    labelText: 'Tỷ lệ hóa chất (g/m²)'),
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
                                    labelText: 'Diện tích (m²)'),
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
                            'Tổng hóa chất cần chuẩn bị: $chemicalTotal g',
                            style: const TextStyle(
                                color: FarmColors.forestGreenText,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        )
                      ],
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration:
                            const InputDecoration(labelText: 'Người phụ trách'),
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
                            const InputDecoration(labelText: 'Ghi chú thêm'),
                        onChanged: (val) => notes = val,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen),
                  onPressed: () {
                    // Update room stage & create job
                    setState(() {
                      final room = _localRooms[roomSelected]!;
                      room['status'] = 'active';
                      room['current_stage'] = jobType;

                      String jobNotes = notes;
                      if (jobType == 'watering') {
                        jobNotes +=
                            ' [Tưới: ${wateringPlan == '2side' ? '2 Side' : '1 Side'} · $wateringVol L/m²]';
                      } else if (jobType == 'prochloraz') {
                        jobNotes +=
                            ' [Hóa chất: $rate g/m² · Diện tích: $area m²]';
                      }

                      final newJob = {
                        'id': room['jobs'].length + 1,
                        'name': jobType.toUpperCase(),
                        'icon': jobType == 'watering'
                            ? Icons.water_drop
                            : jobType == 'prochloraz'
                                ? Icons.science
                                : Icons.task_alt,
                        'status': 'todo',
                        'assignee': assignee,
                        'date': 'Hôm nay',
                        'notes': jobNotes
                      };
                      room['jobs'].add(newJob);
                    });
                    Navigator.pop(dialogCtx);
                  },
                  child:
                      const Text('Tạo', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // HARVEST DEPARTMENT
  // ==========================================
  Widget _buildHarvestContent(bool isDark) {
    // Check if any room has only 1 picker checked in
    String? soloRoom;
    String? soloWorker;
    int soloCount = 0;

    _localRooms.forEach((rName, rData) {
      final crew = _roomCrews[rName] ?? [];
      if (crew.length == 1) {
        soloRoom = rName;
        soloWorker = crew[0];
        soloCount++;
      }
    });

    final activeRooms = _localRooms.values.where((r) {
      final crew = _roomCrews[r['name']] ?? [];
      final target = r['targetYield'] ?? 0.0;
      return crew.isNotEmpty || target > 0.0;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Solo Warning banner
          if (soloRoom != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                          'Cảnh báo: Nhân viên đang làm việc đơn lẻ (Solo) tại Phòng $soloRoom (${soloWorker})!',
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    onPressed: () => _triggerSafetyContact(soloRoom!),
                    child: const Text('Liên lạc khẩn cấp'),
                  )
                ],
              ),
            ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Checkin form & Picking plan list
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      // Check-in card
                      _buildHarvestCheckinCard(isDark),
                      const SizedBox(height: 16),
                      // Picking plans list card
                      Expanded(
                        child: _buildHarvestPickingPlansCard(isDark),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right: Active rooms table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: Border.all(color: FarmColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Danh sách phòng đang thu hoạch',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: activeRooms.isEmpty
                              ? const Center(
                                  child: Text(
                                      'Chưa có phòng nào hoạt động thu hoạch.'))
                              : _buildActiveRoomsTable(activeRooms),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _triggerSafetyContact(String roomNum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liên lạc an toàn'),
        content: Text(
            'Đang gửi tín hiệu yêu cầu check-in định kỳ và ping điện thoại của solo worker tại Phòng $roomNum...'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))
        ],
      ),
    );
  }

  Widget _buildHarvestCheckinCard(bool isDark) {
    final empIdController = TextEditingController();
    String roomSelected = _localRooms.keys.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Check-in / Check-out phòng',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(
            controller: empIdController,
            decoration: const InputDecoration(
                labelText: 'Mã số nhân viên (Employee ID)',
                hintText: 'EMP003',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          StatefulBuilder(
            builder: (context, setCheckinState) {
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Phòng làm việc'),
                value: roomSelected,
                items: _localRooms.keys
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text('Phòng $r')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setCheckinState(() => roomSelected = val);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    final code = empIdController.text.trim().toUpperCase();
                    _handleCheckIn(code, roomSelected);
                  },
                  child: const Text('Check In'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    final code = empIdController.text.trim().toUpperCase();
                    _handleCheckOut(code, roomSelected);
                  },
                  child: const Text('Check Out'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _handleCheckIn(String code, String roomSelected) {
    const registry = {
      'EMP001': {'name': 'Minh T.', 'role': 'Growing Specialist'},
      'EMP002': {'name': 'Lan N.', 'role': 'Growing Specialist'},
      'EMP003': {'name': 'Hùng V.', 'role': 'Harvest Picker'},
      'EMP004': {'name': 'Phúc D.', 'role': 'Harvest Picker'},
      'EMP005': {'name': 'Nam T.', 'role': 'Maintenance Specialist'},
      'EMP006': {'name': 'Lợi P.', 'role': 'Maintenance Specialist'}
    };
    final emp = registry[code];
    if (emp == null) {
      _showMsg('Không tìm thấy mã số nhân viên!');
      return;
    }
    setState(() {
      _roomCrews.putIfAbsent(roomSelected, () => []);
      if (!_roomCrews[roomSelected]!.contains(emp['name'])) {
        _roomCrews[roomSelected]!.add(emp['name']!);
        _safetyLogs.insert(0, {
          'empId': code,
          'empName': emp['name'],
          'room': roomSelected,
          'role': emp['role'],
          'time': DateTime.now().toLocal().toString().substring(11, 16),
          'action': 'Check-in',
          'solo': _roomCrews[roomSelected]!.length == 1
        });
      }
    });
  }

  void _handleCheckOut(String code, String roomSelected) {
    const registry = {
      'EMP001': {'name': 'Minh T.', 'role': 'Growing Specialist'},
      'EMP002': {'name': 'Lan N.', 'role': 'Growing Specialist'},
      'EMP003': {'name': 'Hùng V.', 'role': 'Harvest Picker'},
      'EMP004': {'name': 'Phúc D.', 'role': 'Harvest Picker'},
      'EMP005': {'name': 'Nam T.', 'role': 'Maintenance Specialist'},
      'EMP006': {'name': 'Lợi P.', 'role': 'Maintenance Specialist'}
    };
    final emp = registry[code];
    if (emp == null) {
      _showMsg('Không tìm thấy mã số nhân viên!');
      return;
    }
    setState(() {
      if (_roomCrews.containsKey(roomSelected) &&
          _roomCrews[roomSelected]!.contains(emp['name'])) {
        _roomCrews[roomSelected]!.remove(emp['name']);
        _safetyLogs.insert(0, {
          'empId': code,
          'empName': emp['name'],
          'room': roomSelected,
          'role': emp['role'],
          'time': DateTime.now().toLocal().toString().substring(11, 16),
          'action': 'Check-out',
          'solo': false
        });
      }
    });
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

  Widget _buildHarvestPickingPlansCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kế hoạch thu hoạch từ Kho Lạnh',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Expanded(
            child: _pickingPlans.isEmpty
                ? const Center(
                    child: Text('Chưa có yêu cầu thu hoạch.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.builder(
                    itemCount: _pickingPlans.length,
                    itemBuilder: (context, idx) {
                      final plan = _pickingPlans[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Phòng ${plan['roomName']} (Plant ${plan['plant']})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                                'Cỡ nấm: Button: ${plan['button']}kg, Medium: ${plan['medium']}kg, Open: ${plan['open']}kg',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveRoomsTable(List<Map<String, dynamic>> activeRooms) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Phòng')),
          DataColumn(label: Text('Chu kỳ')),
          DataColumn(label: Text('Nhân sự (Crew)')),
          DataColumn(label: Text('Target (kg)')),
          DataColumn(label: Text('Đã hái (kg)')),
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('An toàn')),
        ],
        rows: activeRooms.map((room) {
          final name = room['name'] as String;
          final crew = _roomCrews[name] ?? [];
          final isSolo = crew.length == 1;

          final targetVal = room['targetYield'] ?? 0.0;
          final pickedVal = room['pickedYield'] ?? 0.0;
          final done = targetVal > 0 && pickedVal >= targetVal;

          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (isSolo) return Colors.red.shade50;
              return null;
            }),
            cells: [
              DataCell(Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(room['cycle'] ?? 'Cycle 1')),
              DataCell(Text(crew.isNotEmpty ? crew.join(', ') : 'Trống')),
              DataCell(Text('${targetVal.toInt()} kg')),
              DataCell(
                TextFormField(
                  initialValue: pickedVal.toString(),
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(contentPadding: EdgeInsets.zero),
                  onFieldSubmitted: (val) {
                    setState(() {
                      final input = double.tryParse(val) ?? 0.0;
                      room['pickedYield'] = input;
                      // Update stock if picking completed
                      if (input >= targetVal && targetVal > 0) {
                        final plan =
                            room['pickingPlan'] as Map<String, dynamic>?;
                        if (plan != null) {
                          _stockButton += plan['button'];
                          _stockMedium += plan['medium'];
                          _stockOpen += plan['open'];

                          room['targetYield'] = 0.0;
                          room['pickedYield'] = 0.0;
                          room['pickingPlan'] = null;
                          _pickingPlans
                              .removeWhere((p) => p['roomName'] == name);
                        }
                      }
                    });
                  },
                ),
              ),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color:
                          done ? Colors.green.shade100 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(done ? 'Hoàn thành' : 'Đang hái',
                      style: TextStyle(
                          color: done
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(
                Icon(
                  isSolo
                      ? Icons.warning_amber_rounded
                      : (crew.isEmpty
                          ? Icons.remove
                          : Icons.check_circle_outline),
                  color: isSolo
                      ? Colors.red
                      : (crew.isEmpty ? Colors.grey : Colors.green),
                ),
              )
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // COOL ROOM WAREHOUSE
  // ==========================================
  Widget _buildCoolRoomContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Stock display & Create Plan Form
          SizedBox(
            width: 350,
            child: Column(
              children: [
                // Stock inventory gauges card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kho lạnh - Tồn kho hiện tại',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 16),
                      _buildStockRow(
                          'Button Size (Cỡ Nhỏ)', _stockButton, Colors.orange),
                      const SizedBox(height: 12),
                      _buildStockRow(
                          'Medium Size (Cỡ Vừa)', _stockMedium, Colors.purple),
                      const SizedBox(height: 12),
                      _buildStockRow(
                          'Open Size (Cỡ Lớn)', _stockOpen, Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Create plan card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildCreatePickingPlanCard(isDark),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Orders list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Đơn hàng xuất kho hôm nay (Orders List)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, idx) {
                        final order = _orders[idx];
                        final isDelivered = order['status'] == 'Delivered';
                        return ListTile(
                          title: Text(
                              '${order['customer']} — Đơn ${order['id']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(order['req']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${order['total']} kg',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              if (!isDelivered)
                                ElevatedButton(
                                  onPressed: () => _handleDeliverOrder(order),
                                  child: const Text('Giao hàng'),
                                )
                              else
                                const Text('Đã giao',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _handleDeliverOrder(Map<String, dynamic> order) {
    // Deduct stock based on order requirements
    if (order['id'] == 'ORD-001') {
      if (_stockButton >= 50 && _stockMedium >= 100) {
        setState(() {
          _stockButton -= 50;
          _stockMedium -= 100;
          order['status'] = 'Delivered';
        });
      } else {
        _showMsg(
            'Không đủ nấm tồn kho trong kho lạnh! Vui lòng lập thêm kế hoạch Picking.');
      }
    } else if (order['id'] == 'ORD-002') {
      if (_stockMedium >= 80 && _stockOpen >= 30) {
        setState(() {
          _stockMedium -= 80;
          _stockOpen -= 30;
          order['status'] = 'Delivered';
        });
      } else {
        _showMsg('Không đủ nấm tồn kho trong kho lạnh!');
      }
    }
  }

  Widget _buildStockRow(String size, double val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(size, style: const TextStyle(fontSize: 13)),
          ],
        ),
        Text('${val.toInt()} kg',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildCreatePickingPlanCard(bool isDark) {
    String roomSelected = _localRooms.keys
        .firstWhere((k) => _localRooms[k]!['plant'] == _activePlant);
    int buttonVal = 50;
    int mediumVal = 100;
    int openVal = 30;

    return StatefulBuilder(
      builder: (context, setPlanState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lập kế hoạch Picking gửi cho Harvest',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Phòng thu hoạch'),
              value: roomSelected,
              items: _localRooms.keys
                  .where((k) => _localRooms[k]!['plant'] == _activePlant)
                  .map((r) =>
                      DropdownMenuItem(value: r, child: Text('Phòng $r')))
                  .toList(),
              onChanged: (val) {
                if (val != null) setPlanState(() => roomSelected = val);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Button Size (kg)'),
              initialValue: buttonVal.toString(),
              keyboardType: TextInputType.number,
              onChanged: (val) => buttonVal = int.tryParse(val) ?? 0,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Medium Size (kg)'),
              initialValue: mediumVal.toString(),
              keyboardType: TextInputType.number,
              onChanged: (val) => mediumVal = int.tryParse(val) ?? 0,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Open Size (kg)'),
              initialValue: openVal.toString(),
              keyboardType: TextInputType.number,
              onChanged: (val) => openVal = int.tryParse(val) ?? 0,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.coolBlue,
                    foregroundColor: Colors.white),
                onPressed: () {
                  final total = buttonVal + mediumVal + openVal;
                  if (total <= 0) {
                    _showMsg('Vui lòng nhập sản lượng lớn hơn 0!');
                    return;
                  }
                  setState(() {
                    final plan = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'roomName': roomSelected,
                      'plant': _activePlant,
                      'button': buttonVal,
                      'medium': mediumVal,
                      'open': openVal,
                      'sentAt':
                          DateTime.now().toLocal().toString().substring(11, 16)
                    };
                    _pickingPlans.add(plan);
                    _localRooms[roomSelected]!['targetYield'] =
                        total.toDouble();
                    _localRooms[roomSelected]!['pickingPlan'] = plan;
                  });
                  _showMsg(
                      'Đã tạo kế hoạch picking và gửi đến Harvest thành công!');
                },
                child: const Text('Gửi Yêu Cầu Thu Hoạch'),
              ),
            )
          ],
        );
      },
    );
  }

  // ==========================================
  // MAINTENANCE LOGIC
  // ==========================================
  Widget _buildMaintenanceContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Create Ticket Form
          SizedBox(
            width: 340,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildCreateMaintenanceForm(isDark),
            ),
          ),
          const SizedBox(width: 16),
          // Right: Maintenance Board
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Lệnh bảo trì đang thực hiện',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _maintenanceJobs.length,
                      itemBuilder: (context, idx) {
                        final mnt = _maintenanceJobs[idx];
                        final status = mnt['status'] as String;
                        return ListTile(
                          title: Text(mnt['title'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Vị trí: Plant ${mnt['plant']} · Phòng ${mnt['room']} · Ghi chú: ${mnt['notes']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: mnt['priority'] == 'high'
                                      ? Colors.red.shade100
                                      : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    mnt['priority'].toString().toUpperCase(),
                                    style: TextStyle(
                                        color: mnt['priority'] == 'high'
                                            ? Colors.red
                                            : Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              _buildMaintStatusBadge(status),
                              const SizedBox(width: 10),
                              if (status != 'done')
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      if (status == 'todo')
                                        mnt['status'] = 'inprog';
                                      else if (status == 'inprog')
                                        mnt['status'] = 'done';
                                    });
                                  },
                                  child: Text(status == 'todo'
                                      ? 'Bắt đầu'
                                      : 'Hoàn tất'),
                                )
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMaintStatusBadge(String status) {
    if (status == 'done')
      return const Text('Đã sửa xong',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    if (status == 'inprog')
      return const Text('Đang tiến hành',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold));
    return const Text('Chờ xử lý', style: TextStyle(color: Colors.grey));
  }

  Widget _buildCreateMaintenanceForm(bool isDark) {
    String title = '';
    String plantSelected = 'M2';
    String roomSelected = 'Room 33';
    String priority = 'normal';
    String assignee = 'Nam T.';
    String notes = '';

    return StatefulBuilder(
      builder: (context, setMaintState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tạo lệnh bảo trì thiết bị',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                  labelText: 'Tên thiết bị / Sự cố',
                  hintText: 'VD: Sửa quạt gió bị kẹt'),
              onChanged: (val) => title = val,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Khu vực'),
                    value: plantSelected,
                    items: const [
                      DropdownMenuItem(value: 'M1', child: Text('Plant M1')),
                      DropdownMenuItem(value: 'M2', child: Text('Plant M2')),
                      DropdownMenuItem(
                          value: 'CoolRoom', child: Text('Kho Lạnh')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setMaintState(() {
                          plantSelected = val;
                          if (val == 'CoolRoom') {
                            roomSelected = 'CR1';
                          } else {
                            roomSelected = _localRooms.keys.firstWhere(
                                (k) => _localRooms[k]!['plant'] == val);
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Phòng'),
                    value: roomSelected,
                    items: plantSelected == 'CoolRoom'
                        ? const [
                            DropdownMenuItem(value: 'CR1', child: Text('CR 1')),
                            DropdownMenuItem(value: 'CR2', child: Text('CR 2'))
                          ]
                        : _localRooms.keys
                            .where((k) =>
                                _localRooms[k]!['plant'] == plantSelected)
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text('Room $r')))
                            .toList(),
                    onChanged: (val) {
                      if (val != null) setMaintState(() => roomSelected = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Người thực hiện'),
              value: assignee,
              items: const [
                DropdownMenuItem(
                    value: 'Nam T.', child: Text('Nam T. (Maintenance)')),
                DropdownMenuItem(
                    value: 'Lợi P.', child: Text('Lợi P. (Maintenance)')),
              ],
              onChanged: (val) {
                if (val != null) setMaintState(() => assignee = val);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Độ ưu tiên'),
              value: priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Thấp (Low)')),
                DropdownMenuItem(
                    value: 'normal', child: Text('Bình thường (Normal)')),
                DropdownMenuItem(value: 'high', child: Text('Cao (High)')),
              ],
              onChanged: (val) {
                if (val != null) setMaintState(() => priority = val);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration:
                  const InputDecoration(labelText: 'Mô tả chi tiết lỗi'),
              onChanged: (val) => notes = val,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.maintenanceOrange,
                    foregroundColor: Colors.white),
                onPressed: () {
                  if (title.isEmpty) {
                    _showMsg('Vui lòng nhập tên thiết bị!');
                    return;
                  }
                  setState(() {
                    _maintenanceJobs.add({
                      'id':
                          'MNT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                      'title': title,
                      'plant': plantSelected,
                      'room': roomSelected,
                      'assignee': assignee,
                      'priority': priority,
                      'status': 'todo',
                      'notes': notes
                    });
                  });
                  _showMsg('Đã tạo lệnh bảo trì mới thành công!');
                },
                child: const Text('Tạo Lệnh Bảo Trì'),
              ),
            )
          ],
        );
      },
    );
  }

  // ==========================================
  // PROJECT & TASKS (KANBAN & GANTT)
  // ==========================================
  Widget _buildTasksContent(bool isDark) {
    if (_tasksSelectedRoomName == null && _localRooms.isNotEmpty) {
      _tasksSelectedRoomName = _localRooms.keys.first;
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Select room header & View switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Xem công việc phòng: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _tasksSelectedRoomName,
                    items: _localRooms.keys
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text('Phòng $r')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _tasksSelectedRoomName = val);
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tasksViewMode == 'kanban'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _tasksViewMode = 'kanban'),
                    child: const Text('Kanban'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tasksViewMode == 'gantt'
                          ? FarmColors.forestGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _tasksViewMode = 'gantt'),
                    child: const Text('Gantt Timeline'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // View Mode renderer
          Expanded(
            child: _tasksSelectedRoomName != null
                ? (_tasksViewMode == 'kanban'
                    ? _buildKanbanView(isDark, _tasksSelectedRoomName!)
                    : _buildGanttView(isDark, _tasksSelectedRoomName!))
                : const Center(child: Text('Không có phòng nào khả dụng.')),
          )
        ],
      ),
    );
  }

  Widget _buildKanbanView(bool isDark, String roomName) {
    final room = _localRooms[roomName]!;
    final List<Map<String, dynamic>> jobs =
        List<Map<String, dynamic>>.from(room['jobs']);

    final todo = jobs.where((j) => j['status'] == 'todo').toList();
    final inprog = jobs.where((j) => j['status'] == 'inprog').toList();
    final review = jobs.where((j) => j['status'] == 'review').toList();
    final done = jobs.where((j) => j['status'] == 'done').toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKanbanCol('To Do', todo, Colors.grey, roomName),
        const SizedBox(width: 12),
        _buildKanbanCol('In Progress', inprog, Colors.blue, roomName),
        const SizedBox(width: 12),
        _buildKanbanCol('Review', review, Colors.orange, roomName),
        const SizedBox(width: 12),
        _buildKanbanCol('Done', done, Colors.green, roomName),
      ],
    );
  }

  Widget _buildKanbanCol(String title, List<Map<String, dynamic>> list,
      Color labelColor, String roomName) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FarmColors.borderLight),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: labelColor, width: 3))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${list.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: list.length,
                itemBuilder: (context, idx) {
                  final job = list[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(job['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(job['assignee']),
                      onTap: () => _showTaskDetailDialog(job, roomName),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showTaskDetailDialog(Map<String, dynamic> job, String roomName) {
    final status = job['status'] as String;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(job['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trạng thái: ${status.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Người phụ trách: ${job['assignee']}'),
            const SizedBox(height: 6),
            Text('Ghi chú: ${job['notes'] ?? ''}'),
          ],
        ),
        actions: [
          if (status != 'done')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (status == 'todo')
                    job['status'] = 'inprog';
                  else if (status == 'inprog')
                    job['status'] = 'review';
                  else if (status == 'review') job['status'] = 'done';
                });
                Navigator.pop(ctx);
              },
              child: const Text('Tiến hành tiếp'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))
        ],
      ),
    );
  }

  Widget _buildGanttView(bool isDark, String roomName) {
    final room = _localRooms[roomName]!;
    final List<Map<String, dynamic>> jobs =
        List<Map<String, dynamic>>.from(room['jobs']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Colors.grey),
                SizedBox(width: 8),
                Text('Gantt Timeline Chart (Ngày 1 đến 18)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            // Timeline numbers row
            Row(
              children: [
                const SizedBox(
                    width: 140,
                    child: Text('Công việc (Jobs)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey))),
                Expanded(
                  child: Row(
                    children: List.generate(
                        18,
                        (idx) => Expanded(
                              child: Text('D${idx + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            )),
                  ),
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, idx) {
                  final job = jobs[idx];
                  final status = job['status'] as String;

                  final startDay = idx * 2;
                  final duration = 3;

                  Color barColor = Colors.grey.shade300;
                  if (status == 'done')
                    barColor = const Color(0xFFC0DD97);
                  else if (status == 'inprog')
                    barColor = const Color(0xFF85B7EB);
                  else if (status == 'review')
                    barColor = const Color(0xFFFAC775);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Row(
                            children: [
                              Icon(job['icon'] as IconData? ?? Icons.task_alt,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(job['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              // Horizontal grid markers
                              Row(
                                children: List.generate(
                                    18,
                                    (idx) => Expanded(
                                          child: Container(
                                            height: 26,
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors
                                                            .grey.shade200))),
                                          ),
                                        )),
                              ),
                              // Positioned bar
                              LayoutBuilder(
                                builder: (context, box) {
                                  final totalWidth = box.maxWidth;
                                  final leftOffset =
                                      (startDay / 18) * totalWidth;
                                  final barWidth = (duration / 18) * totalWidth;

                                  return Positioned(
                                    left: leftOffset,
                                    width: barWidth,
                                    top: 3,
                                    height: 20,
                                    child: InkWell(
                                      onTap: () =>
                                          _showTaskDetailDialog(job, roomName),
                                      child: Container(
                                        decoration: BoxDecoration(
                                            color: barColor,
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        alignment: Alignment.center,
                                        child: Text(job['name'],
                                            style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87)),
                                      ),
                                    ),
                                  );
                                },
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // COMMUNICATION (CHAT)
  // ==========================================
  Widget _buildChatContent(bool isDark) {
    final messages = _chatHistory[_activeChatContact] ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border.all(color: FarmColors.borderLight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left list of chats
            Container(
              width: 250,
              decoration: BoxDecoration(
                  border:
                      Border(right: BorderSide(color: FarmColors.borderLight))),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Cuộc trò chuyện (E2EE)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      children: _chatHistory.keys.map((contact) {
                        final isSel = _activeChatContact == contact;
                        final lastMsg = _chatHistory[contact]!.last['text'];
                        return ListTile(
                          selected: isSel,
                          selectedTileColor:
                              FarmColors.forestGreenLight.withOpacity(0.4),
                          leading: CircleAvatar(
                              backgroundColor: FarmColors.forestGreen,
                              child: Text(contact[0],
                                  style: const TextStyle(color: Colors.white))),
                          title: Text(contact,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(lastMsg ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                          onTap: () =>
                              setState(() => _activeChatContact = contact),
                        );
                      }).toList(),
                    ),
                  )
                ],
              ),
            ),
            // Right chat pane
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: FarmColors.borderLight)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text('Kênh mật mã E2EE: $_activeChatContact',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Container(
                      color: isDark ? Colors.black26 : Colors.grey.shade50,
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        controller: _chatScrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, idx) {
                          final msg = messages[idx];
                          final isVinh = msg['sender'] == 'Vinh';
                          return Align(
                            alignment: isVinh
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isVinh
                                    ? FarmColors.forestGreen
                                    : (isDark
                                        ? const Color(0xFF333333)
                                        : Colors.white),
                                border: isVinh
                                    ? null
                                    : Border.all(color: FarmColors.borderLight),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isVinh
                                      ? const Radius.circular(12)
                                      : const Radius.circular(2),
                                  bottomRight: isVinh
                                      ? const Radius.circular(2)
                                      : const Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isVinh
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text('${msg['sender']} (${msg['role']})',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isVinh
                                              ? Colors.white70
                                              : Colors.grey,
                                          fontSize: 9)),
                                  const SizedBox(height: 4),
                                  Text(msg['text'] ?? '',
                                      style: TextStyle(
                                          color: isVinh
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text('${msg['time']} · E2EE Mật mã',
                                      style: TextStyle(
                                          fontSize: 8,
                                          color: isVinh
                                              ? Colors.white60
                                              : Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: FarmColors.borderLight)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _chatInputController,
                            decoration: const InputDecoration(
                                hintText: 'Nhập tin nhắn mật mã...',
                                border: InputBorder.none),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send,
                              color: FarmColors.forestGreen),
                          onPressed: _handleSendMessage,
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _handleSendMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatHistory[_activeChatContact]!.add({
        'sender': 'Vinh',
        'text': text,
        'time': DateTime.now().toLocal().toString().substring(11, 16),
        'role': _activeRole
      });
      _chatInputController.clear();
    });

    Timer(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController
            .jumpTo(_chatScrollController.position.maxScrollExtent);
      }
    });

    // Simulated Auto reply
    if (_activeChatContact == 'Sarah (Sales)' &&
        text.toLowerCase().contains('picking')) {
      Timer(const Duration(seconds: 1), () {
        setState(() {
          _chatHistory['Sarah (Sales)']!.add({
            'sender': 'Sarah',
            'text': 'Tuyệt vời! Mình báo Aeon Mall xuất hóa đơn luôn.',
            'time': DateTime.now().toLocal().toString().substring(11, 16),
            'role': 'Sales Lead'
          });
        });
      });
    }
  }

  // ==========================================
  // SAFETY & ALARMS
  // ==========================================
  Widget _buildSafetyContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Control Buttons & Incident Form
          SizedBox(
            width: 340,
            child: Column(
              children: [
                // Alarms panel card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Điều khiển an toàn nông trại',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.emergency_share,
                            color: Colors.white),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(42)),
                        onPressed: () =>
                            setState(() => _emergencyActive = true),
                        label: const Text('KÍCH HOẠT BÁO ĐỘNG ĐỎ'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                        onPressed: () => _showMsg(
                            'Đã phát tín hiệu yêu cầu tất cả nhân sự xác minh check-in.'),
                        child: const Text('Yêu Cầu Check-In Định Kỳ'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                        onPressed: () {
                          setState(() {
                            _emergencyActive = false;
                            _roomCrews.clear();
                          });
                          _showMsg('Đã khôi phục các chỉ số an toàn.');
                        },
                        child: const Text('Khôi Phục Trạng Thái An Toàn'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Report Form card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildIncidentReportForm(isDark),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Safety log list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nhật ký an toàn (Check-in / Check-out / Solo)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildSafetyLogsTable(),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSafetyLogsTable() {
    return ListView.builder(
      itemCount: _safetyLogs.length,
      itemBuilder: (context, idx) {
        final log = _safetyLogs[idx];
        final isSolo = log['solo'] as bool;
        return ListTile(
          selected: isSolo,
          selectedColor: Colors.red,
          selectedTileColor: Colors.red.shade50,
          leading: Icon(
            log['action'] == 'Check-in' ? Icons.login : Icons.logout,
            color: log['action'] == 'Check-in' ? Colors.green : Colors.grey,
          ),
          title: Text(
              '${log['empName']} (${log['empId']}) — Phòng ${log['room']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Vai trò: ${log['role']} · Thời gian: ${log['time']}'),
          trailing: isSolo
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.red, size: 14),
                    SizedBox(width: 4),
                    Text('Solo Timer: 45m',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildIncidentReportForm(bool isDark) {
    String location = '';
    String desc = '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Báo cáo sự cố an toàn lao động',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
              labelText: 'Vị trí xảy ra sự cố',
              hintText: 'VD: Phòng 55 hoặc Kho Lạnh M1'),
          onChanged: (val) => location = val,
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Mô tả chi tiết sự cố'),
          onChanged: (val) => desc = val,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () {
              if (location.isEmpty || desc.isEmpty) {
                _showMsg('Vui lòng điền vị trí và mô tả sự cố!');
                return;
              }
              _showMsg(
                  'Đã gửi báo cáo sự cố thành công tới Kỹ thuật trưởng và Supervisor.');
            },
            child: const Text('Gửi Báo Cáo Sự Cố'),
          ),
        )
      ],
    );
  }
}
