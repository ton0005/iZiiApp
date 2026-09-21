import 'package:flutter/material.dart';
import '../../../core/theme/izii_colors.dart';
import '../repository.dart';
import '../services/employee_service.dart';

/// Job Types management screen — CRUD over the catalogue of Growing job
/// types (mushroom_job_types), including custom types beyond the built-in pipeline steps.
///
/// Designed with adaptive mobile (Samsung/Android) & desktop layouts,
/// matching iZiiApp fonts, theme tokens (Light/Dark mode), and styling.
class JobTypesManagementScreen extends StatefulWidget {
  final bool isDark;

  const JobTypesManagementScreen({
    super.key,
    required this.isDark,
  });

  @override
  State<JobTypesManagementScreen> createState() =>
      _JobTypesManagementScreenState();
}

class _JobTypesManagementScreenState extends State<JobTypesManagementScreen> {
  final MushroomsRepository _repo = MushroomsRepository();
  final EmployeeService _employeeService = EmployeeServiceImpl();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _jobTypes = [];
  String _searchQuery = '';
  bool _isLoading = true;

  // null = still checking, true = allowed, false = denied
  bool? _accessAllowed;
  int _userLevel = 0;
  String? _userDepartment;
  String _selectedDepartment = 'All'; // 'All', 'Growing', 'Harvest', 'Maintenance', 'Sales', 'Purchasing'

  static const List<String> _departments = [
    'All',
    'Growing',
    'Harvest',
    'Maintenance',
    'Sales',
    'Purchasing',
  ];

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _departmentColor(String? dept) {
    switch (dept?.trim().toLowerCase()) {
      case 'growing':
        return const Color(0xFF10B981); // Emerald
      case 'harvest':
        return const Color(0xFFEC4899); // Pink
      case 'maintenance':
        return const Color(0xFF0284C7); // Sky blue
      case 'sales':
        return const Color(0xFF6366F1); // Indigo
      case 'purchasing':
        return const Color(0xFF0D9488); // Teal
      default:
        return Colors.blueGrey;
    }
  }

  IconData _departmentIcon(String? dept) {
    switch (dept?.trim().toLowerCase()) {
      case 'growing':
        return Icons.eco_rounded;
      case 'harvest':
        return Icons.content_cut_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'sales':
        return Icons.storefront_rounded;
      case 'purchasing':
        return Icons.shopping_cart_checkout_rounded;
      default:
        return Icons.domain_rounded;
    }
  }

  Future<void> _checkAccessAndLoad() async {
    final emp = await _employeeService.getCurrentEmployee();
    final empId = emp?.id ?? await _employeeService.getCurrentEmployeeId();
    final level = empId != null ? await _repo.getEmployeeLevel(empId) : 0;
    final allowed = level >= 2;

    String? dept = emp?.department?.trim();
    if (dept == null || dept.isEmpty) {
      final role = emp?.role.toLowerCase() ?? '';
      if (role.contains('growing')) {
        dept = 'Growing';
      } else if (role.contains('harvest')) {
        dept = 'Harvest';
      } else if (role.contains('maintenance')) {
        dept = 'Maintenance';
      } else if (role.contains('sales')) {
        dept = 'Sales';
      } else if (role.contains('purchasing')) {
        dept = 'Purchasing';
      } else if (role.contains('cool room')) {
        dept = 'Sales';
      }
    }

    if (!mounted) return;
    setState(() {
      _accessAllowed = allowed;
      _userLevel = level;
      _userDepartment = dept;
      // If Level 2 (Supervisor/Lead), pre-select their own department if identified
      if (level == 2 && dept != null && dept.isNotEmpty && _departments.contains(dept)) {
        _selectedDepartment = dept;
      } else {
        _selectedDepartment = 'All';
      }
    });

    if (allowed) {
      await _loadJobTypes();
    }
  }

  Future<void> _loadJobTypes() async {
    setState(() => _isLoading = true);
    final list = await _repo.getJobTypes();
    if (!mounted) return;
    setState(() {
      _jobTypes = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark || Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground;
    final surface = isDark ? IZiiColors.darkSurface : IZiiColors.lightSurface;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final ink2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final canPop = Navigator.canPop(context);
    final isMobile = MediaQuery.of(context).size.width < 720;

    if (_accessAllowed == null) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_accessAllowed == false) {
      return Scaffold(
        backgroundColor: bg,
        appBar: canPop
            ? AppBar(
                title: const Text('Job Types Management'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        body: _buildAccessDenied(surface, ink, ink2, border),
      );
    }

    final filtered = _jobTypes.where((j) {
      // Department filter
      final dept = (j['department'] as String?)?.trim() ?? 'Growing';
      if (_selectedDepartment != 'All' && dept.toLowerCase() != _selectedDepartment.toLowerCase()) {
        return false;
      }
      final query = _searchQuery.toLowerCase();
      return j['id'].toString().toLowerCase().contains(query) ||
          j['name'].toString().toLowerCase().contains(query) ||
          dept.toLowerCase().contains(query);
    }).toList();

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Desktop / Non-pushed Header (only if not full-page mobile Scaffold)
        if (!canPop) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Job Types Management',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDepartment == 'All'
                        ? 'Catalogue of job types across all departments (${_jobTypes.length} total)'
                        : 'Catalogue of $_selectedDepartment job types and standards (${filtered.length} total)',
                    style: TextStyle(fontSize: 13, color: ink2),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: const Text('Add Job Type', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: _showAddJobTypeDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IZiiColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Department Selector Tabs
        Container(
          height: 42,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _departments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final dept = _departments[idx];
              final isSelected = _selectedDepartment == dept;
              final deptColor = dept == 'All' ? IZiiColors.primary : _departmentColor(dept);

              int count;
              if (dept == 'All') {
                count = _jobTypes.length;
              } else {
                count = _jobTypes.where((j) => ((j['department'] as String?) ?? 'Growing').toLowerCase() == dept.toLowerCase()).length;
              }

              return InkWell(
                onTap: () => setState(() => _selectedDepartment = dept),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? deptColor.withValues(alpha: 0.25) : deptColor)
                        : surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? deptColor : border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dept == 'All' ? Icons.dashboard_customize_rounded : _departmentIcon(dept),
                        size: 16,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.white)
                            : ink2,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dept,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white24
                              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Search Box & Summary Bar
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: ink, fontSize: 14),
            decoration: InputDecoration(
              hintText: _selectedDepartment == 'All'
                  ? 'Search job type across departments by ID, name or department...'
                  : 'Search $_selectedDepartment job type by ID or name...',
              hintStyle: TextStyle(color: ink2, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: ink2),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: ink2),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Body: Mobile Cards vs Desktop Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.layers_clear_outlined, size: 52, color: ink2.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No job types configured for $_selectedDepartment.'
                                : 'No matching job types found.',
                            style: TextStyle(color: ink2, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : isMobile
                      ? _buildMobileCardList(filtered, isDark, surface, ink, ink2, border)
                      : _buildDesktopTable(filtered, isDark, surface, ink, ink2, border),
        ),
      ],
    );

    // If pushed as a full screen on mobile, wrap in Scaffold with custom styled AppBar
    if (canPop) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text(
            'Job Types Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF334155), Color(0xFF0F172A)]
                    : const [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_task_rounded, color: Colors.white),
              tooltip: 'Add Job Type',
              onPressed: _showAddJobTypeDialog,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddJobTypeDialog,
          backgroundColor: IZiiColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Job Type', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: content,
        ),
      );
    }

    // Embedded in desktop shell
    return Padding(
      padding: const EdgeInsets.all(20),
      child: content,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Mobile Card List (Samsung / Android phones)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileCardList(
    List<Map<String, dynamic>> list,
    bool isDark,
    Color surface,
    Color ink,
    Color ink2,
    Color border,
  ) {
    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, idx) {
        final jt = list[idx];
        final id = jt['id'] as String;
        final name = jt['name'] as String? ?? id;
        final planMinutes = jt['plan_minutes'] as int? ?? 30;
        final isSolo = jt['is_solo_job'] == true;
        final isCustom = jt['is_custom'] == true;
        final isActive = jt['is_active'] == true;
        final colorHex = jt['color'] as String?;
        final dotColor = MushroomsRepository.parseHexColor(colorHex) ?? IZiiColors.primary;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? border : border.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showEditJobTypeDialog(jt),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Color circle, Name, Active Toggle & Actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12, width: 1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Active Switch
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: isActive,
                            activeThumbColor: IZiiColors.success,
                            onChanged: (val) async {
                              await _repo.updateJobType(
                                id: id,
                                name: name,
                                planMinutes: planMinutes,
                                isSoloJob: isSolo,
                                isActive: val,
                                color: colorHex,
                              );
                              _loadJobTypes();
                            },
                          ),
                        ),
                        // Context actions
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 20, color: ink2),
                          color: surface,
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showEditJobTypeDialog(jt);
                            } else if (val == 'delete') {
                              _confirmDeleteJobType(jt);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_outlined, size: 18, color: IZiiColors.primary),
                                  const SizedBox(width: 8),
                                  Text('Edit', style: TextStyle(color: ink)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: IZiiColors.error),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: IZiiColors.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Badges row: ID, Std Time, Type, Solo
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Department badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _departmentColor(jt['department'] as String?).withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _departmentColor(jt['department'] as String?).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_departmentIcon(jt['department'] as String?), size: 11, color: _departmentColor(jt['department'] as String?)),
                              const SizedBox(width: 4),
                              Text(
                                (jt['department'] as String?) ?? 'Growing',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _departmentColor(jt['department'] as String?),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ID chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            id,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ink2,
                            ),
                          ),
                        ),

                        // Standard Time
                        _buildBadge(
                          '⏱️ $planMinutes min',
                          const Color(0xFF4F46E5),
                          isDark,
                        ),

                        // Type: Custom / Built-in
                        _buildBadge(
                          isCustom ? 'Custom' : 'Built-in',
                          isCustom ? IZiiColors.secondary : Colors.blueGrey,
                          isDark,
                        ),

                        // Solo Job badge
                        if (isSolo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: IZiiColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: IZiiColors.error.withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, size: 12, color: IZiiColors.error),
                                SizedBox(width: 4),
                                Text(
                                  'Solo Safety Flow',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: IZiiColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Desktop Table (for wide screens / tablets)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopTable(
    List<Map<String, dynamic>> list,
    bool isDark,
    Color surface,
    Color ink,
    Color ink2,
    Color border,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('JOB TYPE ID', style: _tableHeaderStyle(ink2))),
                Expanded(flex: 3, child: Text('NAME', style: _tableHeaderStyle(ink2))),
                Expanded(flex: 2, child: Text('DEPARTMENT', style: _tableHeaderStyle(ink2))),
                Expanded(flex: 2, child: Text('STD. TIME', style: _tableHeaderStyle(ink2))),
                Expanded(flex: 2, child: Text('TYPE', style: _tableHeaderStyle(ink2))),
                Expanded(flex: 2, child: Text('STATUS', style: _tableHeaderStyle(ink2))),
                Expanded(flex: 2, child: Text('ACTIONS', style: _tableHeaderStyle(ink2))),
              ],
            ),
          ),
          const Divider(height: 1),

          // List Body
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, idx) {
                final jt = list[idx];
                final isSolo = jt['is_solo_job'] == true;
                final isCustom = jt['is_custom'] == true;
                final isActive = jt['is_active'] == true;
                final dotColor = MushroomsRepository.parseHexColor(jt['color'] as String?) ?? IZiiColors.primary;
                final deptName = (jt['department'] as String?) ?? 'Growing';

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      ),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    title: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            jt['id'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: ink,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black26, width: 1),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  jt['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: ink,
                                  ),
                                ),
                              ),
                              if (isSolo)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.shield_rounded,
                                    size: 14,
                                    color: IZiiColors.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildBadge(
                              deptName,
                              _departmentColor(deptName),
                              isDark,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${jt['plan_minutes']} min',
                            style: TextStyle(fontSize: 13, color: ink),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildBadge(
                              isCustom ? 'Custom' : 'Built-in',
                              isCustom ? IZiiColors.secondary : Colors.blueGrey,
                              isDark,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildBadge(
                              isActive ? 'Active' : 'Inactive',
                              isActive ? IZiiColors.success : Colors.grey,
                              isDark,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18, color: IZiiColors.primary),
                                onPressed: () => _showEditJobTypeDialog(jt),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 14),
                              IconButton(
                                icon: const Icon(Icons.delete_forever_rounded, size: 18, color: IZiiColors.error),
                                onPressed: () => _confirmDeleteJobType(jt),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle(Color ink2) {
    return TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 11,
      letterSpacing: 0.5,
      color: ink2,
    );
  }

  Widget _buildBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAccessDenied(Color surface, Color ink, Color ink2, Color border) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person_rounded, size: 48, color: IZiiColors.accent),
            const SizedBox(height: 14),
            Text(
              'Access Restricted',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Only Level 2+ management (Lead / Supervisor / Manager) can manage department job types.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ink2),
            ),
          ],
        ),
      ),
    );
  }

  String _slugify(String name) {
    var s = name.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'job_${DateTime.now().millisecondsSinceEpoch}' : s;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Dialogs: Add Job Type
  // ══════════════════════════════════════════════════════════════════════════
  void _showAddJobTypeDialog() {
    final isDark = widget.isDark || Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IZiiColors.darkSurface : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final formKey = GlobalKey<FormState>();
    String id = '';
    String name = '';
    String department = (_selectedDepartment != 'All')
        ? _selectedDepartment
        : (_userDepartment != null && _departments.contains(_userDepartment))
            ? _userDepartment!
            : 'Growing';
    int planMinutes = 30;
    bool isSoloJob = false;
    String color = '#10B981';
    bool idManuallyEdited = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add Job Type',
            style: TextStyle(fontWeight: FontWeight.bold, color: ink),
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      style: TextStyle(color: ink),
                      decoration: _dialogInputDecoration('Name *', border),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Name is required' : null,
                      onChanged: (val) {
                        name = val;
                        if (!idManuallyEdited) {
                          setDialogState(() => id = _slugify(val));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('id_$id'),
                      initialValue: id,
                      style: TextStyle(color: ink, fontFamily: 'monospace'),
                      decoration: _dialogInputDecoration(
                        'Job Type ID (unique) *',
                        border,
                        helperText: 'Auto-filled from Name — edit if needed',
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'ID is required' : null,
                      onChanged: (val) {
                        idManuallyEdited = true;
                        id = val.trim();
                      },
                    ),
                    const SizedBox(height: 12),
                    // Department Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: department,
                      decoration: _dialogInputDecoration('Department *', border),
                      dropdownColor: surface,
                      items: _departments.where((d) => d != 'All').map((d) {
                        final dCol = _departmentColor(d);
                        return DropdownMenuItem(
                          value: d,
                          child: Row(
                            children: [
                              Icon(_departmentIcon(d), size: 16, color: dCol),
                              const SizedBox(width: 8),
                              Text(d, style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (_userLevel == 2 && _userDepartment != null && _userDepartment!.isNotEmpty)
                          ? null // Locked to their own department if Level 2 Lead/Supervisor
                          : (val) {
                              if (val != null) {
                                setDialogState(() => department = val);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      style: TextStyle(color: ink),
                      decoration: _dialogInputDecoration('Standard Time (minutes) *', border),
                      initialValue: planMinutes.toString(),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onChanged: (val) =>
                          planMinutes = int.tryParse(val) ?? 30,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      style: TextStyle(color: ink),
                      decoration: _dialogInputDecoration(
                        'Stage Color (hex)',
                        border,
                        helperText: 'e.g. #10B981, #6366F1',
                      ),
                      initialValue: color,
                      onChanged: (val) => color = val.trim(),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: IZiiColors.primary,
                      title: Text(
                        'Alone Worker (Solo) job',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                      ),
                      subtitle: const Text(
                        'Requires safety countdown timer & gas monitoring flow',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: isSoloJob,
                      onChanged: (v) => setDialogState(() => isSoloJob = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: IZiiColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final finalId = id.trim().isEmpty ? _slugify(name) : id.trim();
                final ok = await _repo.addJobType(
                  id: finalId,
                  name: name.trim(),
                  department: department,
                  planMinutes: planMinutes,
                  isSoloJob: isSoloJob,
                  color: color.isNotEmpty ? color : null,
                );
                if (!ok) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        backgroundColor: IZiiColors.error,
                        content: Text('Job Type ID "$finalId" already exists.'),
                      ),
                    );
                  }
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadJobTypes();
              },
              child: const Text('Add Job Type'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Dialogs: Edit Job Type
  // ══════════════════════════════════════════════════════════════════════════
  void _showEditJobTypeDialog(Map<String, dynamic> jobType) {
    final isDark = widget.isDark || Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IZiiColors.darkSurface : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final formKey = GlobalKey<FormState>();
    final id = jobType['id'] as String;
    String name = jobType['name'] as String? ?? id;
    String department = (jobType['department'] as String?)?.trim() ?? 'Growing';
    int planMinutes = jobType['plan_minutes'] as int? ?? 30;
    bool isSoloJob = jobType['is_solo_job'] == true;
    bool isActive = jobType['is_active'] == true;
    String color = (jobType['color'] as String?) ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Job Type',
            style: TextStyle(fontWeight: FontWeight.bold, color: ink),
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: id,
                      style: TextStyle(color: ink.withValues(alpha: 0.6), fontFamily: 'monospace'),
                      decoration: _dialogInputDecoration('Job Type ID (fixed)', border, enabled: false),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: name,
                      style: TextStyle(color: ink),
                      decoration: _dialogInputDecoration('Name *', border),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Name is required' : null,
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 12),
                    // Department Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: department,
                      decoration: _dialogInputDecoration('Department *', border),
                      dropdownColor: surface,
                      items: _departments.where((d) => d != 'All').map((d) {
                        final dCol = _departmentColor(d);
                        return DropdownMenuItem(
                          value: d,
                          child: Row(
                            children: [
                              Icon(_departmentIcon(d), size: 16, color: dCol),
                              const SizedBox(width: 8),
                              Text(d, style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (_userLevel == 2 && _userDepartment != null && _userDepartment!.isNotEmpty)
                          ? null // Locked to their own department if Level 2 Lead/Supervisor
                          : (val) {
                              if (val != null) {
                                setDialogState(() => department = val);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: planMinutes.toString(),
                      style: TextStyle(color: ink),
                      decoration: _dialogInputDecoration('Standard Time (minutes) *', border),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onChanged: (val) =>
                          planMinutes = int.tryParse(val) ?? planMinutes,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: color,
                      style: TextStyle(color: ink),
                      decoration: _dialogInputDecoration(
                        'Stage Color (hex)',
                        border,
                        helperText: 'e.g. #10B981, #6366F1',
                      ),
                      onChanged: (val) => color = val.trim(),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: IZiiColors.primary,
                      title: Text(
                        'Alone Worker (Solo) job',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                      ),
                      subtitle: const Text(
                        'Requires safety countdown timer & gas monitoring flow',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: isSoloJob,
                      onChanged: (v) => setDialogState(() => isSoloJob = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: IZiiColors.success,
                      title: Text(
                        'Active',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                      ),
                      subtitle: const Text(
                        'Inactive job types are hidden from new-job planning dropdown',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: IZiiColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await _repo.updateJobType(
                  id: id,
                  name: name.trim(),
                  department: department,
                  planMinutes: planMinutes,
                  isSoloJob: isSoloJob,
                  isActive: isActive,
                  color: color.isNotEmpty ? color : null,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadJobTypes();
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Dialogs: Delete Confirmation
  // ══════════════════════════════════════════════════════════════════════════
  void _confirmDeleteJobType(Map<String, dynamic> jobType) {
    final isDark = widget.isDark || Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IZiiColors.darkSurface : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final ink2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Delete',
          style: TextStyle(fontWeight: FontWeight.bold, color: ink),
        ),
        content: Text(
          'Are you sure you want to delete job type "${jobType['name']}"?\n\nExisting jobs created with this type will keep their history — only the catalogue template entry is removed.',
          style: TextStyle(fontSize: 13, color: ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: IZiiColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await _repo.deleteJobType(jobType['id'] as String);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadJobTypes();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String label, Color border, {String? helperText, bool enabled = true}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      enabled: enabled,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: IZiiColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
