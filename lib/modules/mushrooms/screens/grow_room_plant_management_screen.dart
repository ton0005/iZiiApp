// lib/modules/mushrooms/screens/grow_room_plant_management_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/izii_colors.dart';
import '../services/grow_room_service.dart';
import '../services/plant_room_service.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class GrowRoomPlantManagementScreen extends StatefulWidget {
  final bool isDark;

  const GrowRoomPlantManagementScreen({
    super.key,
    required this.isDark,
  });

  @override
  State<GrowRoomPlantManagementScreen> createState() =>
      _GrowRoomPlantManagementScreenState();
}

class _GrowRoomPlantManagementScreenState
    extends State<GrowRoomPlantManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GrowRoomService _roomService = GrowRoomServiceImpl();
  final PlantRoomService _plantService = PlantRoomService();

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _rooms = [];
  List<PlantModel> _plants = [];

  String _searchQuery = '';
  String _selectedPlantFilter = 'ALL'; // 'ALL' or plant code e.g. 'M1', 'M2'
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'active', 'idle'

  bool _isLoading = true;
  StreamSubscription<void>? _plantChangesSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    _plantChangesSub = _plantService.watchChanges.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _plantChangesSub?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final plants = await _plantService.getPlants();
      final rooms = await _roomService.getRooms();

      if (mounted) {
        setState(() {
          _plants = plants;
          _rooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRoomPlantCode(Map<String, dynamic> room) {
    final roomId = room['id'] as String? ?? '';
    final roomName = room['name'] as String? ?? '';
    return _plantService.getPlantForRoomSync(roomId: roomId, roomName: roomName);
  }

  Color _getPlantColor(String plantCode) {
    final cleanCode = plantCode.toUpperCase();
    final p = _plants.firstWhere(
      (item) => item.code.toUpperCase() == cleanCode,
      orElse: () => PlantModel(code: cleanCode, name: 'Plant $cleanCode'),
    );
    try {
      final hex = p.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return cleanCode == 'M1' ? FarmColors.forestGreen : FarmColors.harvestPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDark || Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground;
    final surface = isDark ? IZiiColors.darkSurface : IZiiColors.lightSurface;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final ink2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: ink),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FarmColors.forestGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.meeting_room_rounded,
                  color: FarmColors.forestGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grow Rooms & Plants Management',
                  style: TextStyle(
                      color: ink, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Grow Rooms & Plants Catalog (CRUD)',
                  style: TextStyle(color: ink2, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: FarmColors.forestGreen,
          unselectedLabelColor: ink2,
          indicatorColor: FarmColors.forestGreen,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.door_sliding_rounded, size: 20),
              text: 'Grow Rooms (${_rooms.length})',
            ),
            Tab(
              icon: const Icon(Icons.domain_rounded, size: 20),
              text: 'Plants (${_plants.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRoomsTab(isDark, surface, ink, ink2, border),
                _buildPlantsTab(isDark, surface, ink, ink2, border),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: GROW ROOMS MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRoomsTab(
    bool isDark,
    Color surface,
    Color ink,
    Color ink2,
    Color border,
  ) {
    // Filter rooms
    final filtered = _rooms.where((r) {
      final name = (r['name'] as String? ?? '').toLowerCase();
      final id = (r['id'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchQuery = q.isEmpty || name.contains(q) || id.contains(q);

      final pCode = _getRoomPlantCode(r).toUpperCase();
      final matchPlant =
          _selectedPlantFilter == 'ALL' || pCode == _selectedPlantFilter;

      final status = (r['status'] as String? ?? 'idle').toLowerCase();
      final matchStatus = _selectedStatusFilter == 'ALL' ||
          status == _selectedStatusFilter.toLowerCase();

      return matchQuery && matchPlant && matchStatus;
    }).toList();

    return Column(
      children: [
        // Controls: Filter chips, search bar, and add button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plant Filter Chips & Add Room Button
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPlantFilterChip('ALL', 'All (${_rooms.length})'),
                          const SizedBox(width: 8),
                          for (final p in _plants) ...[
                            _buildPlantFilterChip(
                              p.code,
                              '${p.name} (${_rooms.where((r) => _getRoomPlantCode(r).toUpperCase() == p.code.toUpperCase()).length})',
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Room'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showAddRoomDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search Bar & Status Dropdown
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search room (e.g. Room 33, room_32)...',
                        hintStyle: TextStyle(color: ink2, fontSize: 13),
                        prefixIcon:
                            Icon(Icons.search_rounded, size: 20, color: ink2),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: border),
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: ink),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatusFilter,
                        icon: Icon(Icons.filter_alt_rounded,
                            size: 18, color: ink2),
                        style: TextStyle(
                            fontSize: 13,
                            color: ink,
                            fontWeight: FontWeight.w600),
                        dropdownColor: surface,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatusFilter = val);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                              value: 'ALL', child: Text('All Statuses')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'idle', child: Text('Idle')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Rooms List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: ink2),
                      const SizedBox(height: 12),
                      Text(
                        'No matching grow rooms found.',
                        style: TextStyle(color: ink2, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final room = filtered[index];
                    return _buildRoomCard(
                        room, isDark, surface, ink, ink2, border);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlantFilterChip(String code, String label) {
    final isSelected = _selectedPlantFilter == code;
    final color = code == 'ALL'
        ? const Color(0xFF475569)
        : _getPlantColor(code);

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : color,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      selectedColor: color,
      side: BorderSide(
        color: isSelected ? color : color.withValues(alpha: 0.3),
      ),
      onSelected: (_) {
        setState(() => _selectedPlantFilter = code);
      },
    );
  }

  Widget _buildRoomCard(
    Map<String, dynamic> room,
    bool isDark,
    Color surface,
    Color ink,
    Color ink2,
    Color border,
  ) {
    final id = room['id'] as String? ?? '';
    final name = room['name'] as String? ?? '';
    final plantCode = _getRoomPlantCode(room);
    final status = room['status'] as String? ?? 'idle';
    final stage = room['current_stage'] as String? ?? 'idle';
    final targetYield = (room['target_yield'] as num?)?.toDouble() ?? 0.0;
    final dayInCycle = room['day_in_cycle'] as int? ?? 1;

    final isActive = status.toLowerCase() == 'active';
    final plantColor = _getPlantColor(plantCode);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Plant Indicator Bar
            Container(
              width: 5,
              height: 52,
              decoration: BoxDecoration(
                color: plantColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),

            // Room Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Plant Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: plantColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: plantColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Plant $plantCode',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: plantColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Idle',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'ID: $id',
                        style: TextStyle(color: ink2, fontSize: 11),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Stage: $stage',
                        style: TextStyle(
                            color: ink2,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Day $dayInCycle',
                        style: TextStyle(color: ink2, fontSize: 11),
                      ),
                      if (targetYield > 0) ...[
                        const SizedBox(width: 14),
                        Text(
                          'Target: ${targetYield.toStringAsFixed(1)} kg',
                          style: TextStyle(color: ink2, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Quick Reassign Button (M1 <-> M2)
            PopupMenuButton<String>(
              tooltip: 'Quick Reassign Plant',
              icon: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: plantColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: plantColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded,
                        size: 16, color: plantColor),
                    const SizedBox(width: 4),
                    Text(
                      'Change Plant',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: plantColor,
                      ),
                    ),
                  ],
                ),
              ),
              onSelected: (newCode) async {
                if (newCode != plantCode) {
                  final messenger = ScaffoldMessenger.of(context);
                  await _roomService.reassignRoomPlant(id, newCode);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Successfully moved $name to Plant $newCode.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  _loadData();
                }
              },
              itemBuilder: (context) => [
                for (final p in _plants)
                  PopupMenuItem(
                    value: p.code,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _getPlantColor(p.code),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: p.code.toUpperCase() ==
                                    plantCode.toUpperCase()
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (p.code.toUpperCase() == plantCode.toUpperCase()) ...[
                          const Spacer(),
                          const Icon(Icons.check_rounded,
                              size: 16, color: Colors.green),
                        ],
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 4),

            // Edit Room Action
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: ink2),
              tooltip: 'Edit Room',
              onPressed: () => _showEditRoomDialog(room),
            ),

            // Delete Room Action
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.redAccent),
              tooltip: 'Delete Room',
              onPressed: () => _confirmDeleteRoom(room),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: PLANTS MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPlantsTab(
    bool isDark,
    Color surface,
    Color ink,
    Color ink2,
    Color border,
  ) {
    return Column(
      children: [
        // Plant Action Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Production Plants Catalog',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: ink),
                  ),
                  Text(
                    'Manage production facilities and assigned grow rooms (${_plants.length} plants)',
                    style: TextStyle(fontSize: 11, color: ink2),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Add Plant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.forestGreen,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showAddPlantDialog,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Plants List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _plants.length,
            itemBuilder: (context, index) {
              final plant = _plants[index];
              final plantRooms = _rooms.where((r) =>
                  _getRoomPlantCode(r).toUpperCase() ==
                  plant.code.toUpperCase()).toList();
              final plantColor = _getPlantColor(plant.code);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: border),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Avatar / Color Block
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: plantColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: plantColor.withValues(alpha: 0.4)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          plant.code,
                          style: TextStyle(
                            color: plantColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Plant Details
                      Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  plant.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: plant.isActive
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    plant.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: plant.isActive
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (plant.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                plant.description,
                                style: TextStyle(color: ink2, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.door_sliding_outlined,
                                    size: 14, color: ink2),
                                const SizedBox(width: 4),
                                Text(
                                  '${plantRooms.length} assigned rooms',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ink2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 20, color: ink2),
                        tooltip: 'Edit Plant',
                        onPressed: () => _showEditPlantDialog(plant),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: Colors.redAccent),
                        tooltip: 'Delete Plant',
                        onPressed: () => _confirmDeletePlant(plant, plantRooms.length),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIALOGS: ADD / EDIT / DELETE ROOM
  // ══════════════════════════════════════════════════════════════════════════

  void _showAddRoomDialog() {
    final nameCtrl = TextEditingController();
    final yieldCtrl = TextEditingController(text: '0.0');
    String selectedPlant = _plants.isNotEmpty ? _plants.first.code : 'M1';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add New Grow Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Name *',
                    hintText: 'e.g. Room 67, Spawn Room 1',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Assigned Plant *',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlant,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    for (final p in _plants)
                      DropdownMenuItem(
                        value: p.code,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getPlantColor(p.code),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(p.name),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedPlant = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: yieldCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Yield (kg)',
                    hintText: '0.0',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.forestGreen,
                  foregroundColor: Colors.white),
              child: const Text('Save Room'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final targetYield =
                    double.tryParse(yieldCtrl.text.trim()) ?? 0.0;
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  await _roomService.addRoom(
                    name: name,
                    plantName: selectedPlant,
                    targetYield: targetYield,
                  );
                  nav.pop();
                  if (!mounted) return;
                  _loadData();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRoomDialog(Map<String, dynamic> room) {
    final roomId = room['id'] as String;
    final nameCtrl = TextEditingController(text: room['name'] as String? ?? '');
    final yieldCtrl = TextEditingController(
        text: (room['target_yield'] ?? 0.0).toString());
    final currentPlant = _getRoomPlantCode(room);
    String selectedPlant = currentPlant;
    String selectedStatus = room['status'] as String? ?? 'idle';
    String selectedStage = room['current_stage'] as String? ?? 'idle';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Edit ${room['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Name *',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Assigned Plant *',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlant,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    for (final p in _plants)
                      DropdownMenuItem(
                        value: p.code,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getPlantColor(p.code),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(p.name),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedPlant = val);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'idle', child: Text('Idle')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => selectedStatus = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedStage,
                        decoration: const InputDecoration(
                          labelText: 'Stage',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'idle', child: Text('idle')),
                          DropdownMenuItem(value: 'filling', child: Text('filling')),
                          DropdownMenuItem(value: 'airing', child: Text('airing')),
                          DropdownMenuItem(
                              value: 'floor_wet', child: Text('floor_wet')),
                          DropdownMenuItem(
                              value: 'watering', child: Text('watering')),
                          DropdownMenuItem(
                              value: 'clean_room', child: Text('clean_room')),
                          DropdownMenuItem(
                              value: 'prochloraz', child: Text('prochloraz')),
                          DropdownMenuItem(
                              value: 'packup_tree', child: Text('packup_tree')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => selectedStage = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: yieldCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Yield (kg)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.forestGreen,
                  foregroundColor: Colors.white),
              child: const Text('Save Changes'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final targetYield =
                    double.tryParse(yieldCtrl.text.trim()) ?? 0.0;
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  await _roomService.updateRoom(
                    roomId: roomId,
                    name: name,
                    plantName: selectedPlant,
                    status: selectedStatus,
                    currentStage: selectedStage,
                    targetYield: targetYield,
                  );
                  nav.pop();
                  if (!mounted) return;
                  _loadData();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRoom(Map<String, dynamic> room) {
    final roomId = room['id'] as String;
    final name = room['name'] as String;
    final status = room['status'] as String? ?? 'idle';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: Text(
          status == 'active'
              ? 'WARNING: This room is currently ACTIVE. Are you sure you want to delete it?'
              : 'This room will be permanently removed from the catalog.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('Delete Room'),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _roomService.deleteRoom(roomId);
                nav.pop();
                if (!mounted) return;
                _loadData();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIALOGS: ADD / EDIT / DELETE PLANT
  // ══════════════════════════════════════════════════════════════════════════

  void _showAddPlantDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String colorHex = '#2D6A4F';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add New Plant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plant Code *',
                    hintText: 'e.g. M3, LAB, SUB',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plant Name *',
                    hintText: 'e.g. Plant M3, Spawn Laboratory',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. Monarto expansion facility',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Badge Color:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in [
                      '#2D6A4F',
                      '#7C3AED',
                      '#0284C7',
                      '#D97706',
                      '#E11D48',
                      '#4F46E5',
                      '#059669',
                      '#0D9488',
                    ])
                      InkWell(
                        onTap: () => setDlgState(() => colorHex = c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(int.parse('FF${c.replaceAll('#', '')}',
                                radix: 16)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorHex == c
                                  ? Colors.black87
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: colorHex == c
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.forestGreen,
                  foregroundColor: Colors.white),
              child: const Text('Add Plant'),
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                final name = nameCtrl.text.trim();
                if (code.isEmpty || name.isEmpty) return;

                final newPlant = PlantModel(
                  code: code,
                  name: name,
                  description: descCtrl.text.trim(),
                  colorHex: colorHex,
                  isActive: true,
                  sortOrder: _plants.length + 1,
                );

                final nav = Navigator.of(ctx);
                await _plantService.savePlant(newPlant);
                nav.pop();
                if (!mounted) return;
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlantDialog(PlantModel plant) {
    final nameCtrl = TextEditingController(text: plant.name);
    final descCtrl = TextEditingController(text: plant.description);
    String colorHex = plant.colorHex;
    bool isActive = plant.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Edit Plant ${plant.code}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plant Name *',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Status'),
                  value: isActive,
                  onChanged: (val) => setDlgState(() => isActive = val),
                ),
                const SizedBox(height: 8),
                const Text('Badge Color:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in [
                      '#2D6A4F',
                      '#7C3AED',
                      '#0284C7',
                      '#D97706',
                      '#E11D48',
                      '#4F46E5',
                      '#059669',
                      '#0D9488',
                    ])
                      InkWell(
                        onTap: () => setDlgState(() => colorHex = c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(int.parse('FF${c.replaceAll('#', '')}',
                                radix: 16)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorHex == c
                                  ? Colors.black87
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: colorHex == c
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.forestGreen,
                  foregroundColor: Colors.white),
              child: const Text('Save Changes'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final updated = plant.copyWith(
                  name: name,
                  description: descCtrl.text.trim(),
                  colorHex: colorHex,
                  isActive: isActive,
                );

                final nav = Navigator.of(ctx);
                await _plantService.savePlant(updated);
                nav.pop();
                if (!mounted) return;
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlant(PlantModel plant, int roomCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Plant ${plant.name}?'),
        content: Text(
          roomCount > 0
              ? 'WARNING: There are $roomCount rooms currently assigned to this plant. Deleting it will reassign them to default plants.'
              : 'This plant will be permanently removed from the catalog.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('Delete Plant'),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await _plantService.deletePlant(plant.code);
              nav.pop();
              if (!mounted) return;
              _loadData();
            },
          ),
        ],
      ),
    );
  }
}
