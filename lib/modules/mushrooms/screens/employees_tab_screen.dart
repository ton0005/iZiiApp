import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:izii_app/core/sync/sync_service.dart';
import '../repository.dart';
import '../services/harvest_plan_excel_service.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class EmployeesTabScreen extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> employees;
  final Function(String, String, String, String?, [String?, String?, String?]) onAddEmployee;
  final Function(String, String, String, String?, [String?, String?]) onEditEmployee;
  final Function(List<Map<String, String>>) onImportEmployees;

  const EmployeesTabScreen({
    super.key,
    required this.isDark,
    required this.employees,
    required this.onAddEmployee,
    required this.onEditEmployee,
    required this.onImportEmployees,
  });

  @override
  State<EmployeesTabScreen> createState() => _EmployeesTabScreenState();
}

class _EmployeesTabScreenState extends State<EmployeesTabScreen> {
  final MushroomsRepository _repo = MushroomsRepository();
  final HarvestPlanExcelService _excelService = HarvestPlanExcelService();
  final TextEditingController _searchController = TextEditingController();
  MobileScannerController? _dialogScannerController;
  bool _isScannerProcessing = false;
  String _searchQuery = '';
  List<String> _roles = [];
  List<Map<String, dynamic>> _departments = [];
  List<String> _teams = [];

  Future<void> _importTeamsFromExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        String content;
        if (file.path.toLowerCase().endsWith('.xlsx')) {
          final bytes = await file.readAsBytes();
          content = _excelService.convertXlsxBytesToCsvString(bytes);
        } else {
          content = await file.readAsString();
        }

        final parsedTeams = _excelService.parsePickerTeamsFromCsvContent(content);

        if (parsedTeams.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No team rows found in selected CSV file.')),
            );
          }
          return;
        }

        await _repo.upsertPickerTeams(parsedTeams);
        await _loadTeams();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported & upserted ${parsedTeams.length} Picker Teams into SQLite!'),
              backgroundColor: FarmColors.forestGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing teams: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportTeamsToExcel() async {
    try {
      final teams = await _repo.getPickerTeamsDetails();
      final file = await _excelService.exportPickerTeamsToCsvFile(teams);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Picker Teams exported: ${file.path}'),
            backgroundColor: FarmColors.forestGreen,
            action: SnackBarAction(
              label: 'Share/Open',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(file.path)], text: 'PICKER TEAMS & ESTIMATED SPEED CSV');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting teams: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  StreamSubscription<SyncEvent>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadDepartments();
    _loadTeams();

    _syncSubscription = SyncService().syncEventStream.listen((event) {
      if (mounted) {
        _loadRoles();
        _loadDepartments();
        _loadTeams();
      }
    });
  }

  Future<void> _loadRoles() async {
    final list = await _repo.getRoles();
    if (mounted) {
      setState(() {
        _roles = list;
      });
    }
  }

  Future<void> _loadDepartments() async {
    final list = await _repo.getDepartments();
    if (mounted) {
      setState(() {
        _departments = list;
      });
    }
  }

  Future<void> _loadTeams() async {
    final list = await _repo.getTeams();
    if (mounted) {
      setState(() {
        _teams = list;
      });
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.employees.where((e) {
      final query = _searchQuery.toLowerCase();
      return e['id'].toString().toLowerCase().contains(query) ||
          e['name'].toString().toLowerCase().contains(query) ||
          e['role'].toString().toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 650;
              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Employee Registry',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Manage pickers, box movers and specialists (${widget.employees.length} registered)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildScanButton(),
                        _buildImportButton(),
                        _buildImportTeamsButton(),
                        _buildExportTeamsButton(),
                        _buildManageRolesButton(),
                        _buildAddEmployeeButton(),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Employee Registry',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage pickers, box movers and specialists (${widget.employees.length} registered)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildScanButton(),
                        _buildImportButton(),
                        _buildImportTeamsButton(),
                        _buildExportTeamsButton(),
                        _buildManageRolesButton(),
                        _buildAddEmployeeButton(),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),
          // Search Box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by ID, name or role...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 16),
          // Employees List Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No employees found matching the search.'),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 700;
                        return isDesktop
                            ? _buildDesktopTable(filtered)
                            : _buildMobileCardList(filtered);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: widget.isDark ? Colors.white10 : Colors.grey.shade50,
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('EMPLOYEE ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              Expanded(flex: 3, child: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              Expanded(flex: 3, child: Text('ROLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              Expanded(flex: 3, child: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              Expanded(flex: 2, child: Text('CREATED AT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              Expanded(flex: 1, child: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
            ],
          ),
        ),
        const Divider(height: 1),
        // List Body
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, idx) {
              final emp = filtered[idx];
              final timeStr = emp['createdAt'] != null
                  ? emp['createdAt'].toString().substring(0, 10)
                  : 'N/A';
              final statusStr = emp['status']?.toString().toLowerCase() ?? 'active';
              final isActive = statusStr == 'active';
              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade100)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    title: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            emp['id'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            emp['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: -4),
                              padding: EdgeInsets.zero,
                              backgroundColor: widget.isDark
                                  ? FarmColors.forestGreen
                                  : (emp['role'].toString().contains('Specialist')
                                      ? Colors.blue.withOpacity(0.1)
                                      : (emp['role'].toString().contains('Picker')
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1))),
                              label: Text(
                                emp['role'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDark
                                      ? Colors.white
                                      : (emp['role'].toString().contains('Specialist')
                                          ? Colors.blue.shade800
                                          : (emp['role'].toString().contains('Picker')
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                emp['department']?.toString() ?? 'N/A',
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (emp['department']?.toString().toLowerCase().contains('harvest') == true)
                                Text(
                                  'Team: ${emp['pickerTeamColor'] ?? 'NEW'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: emp['pickerTeamColor'] == null || emp['pickerTeamColor'] == 'NEW'
                                        ? Colors.orange.shade700
                                        : (widget.isDark ? Colors.tealAccent : Colors.teal.shade800),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : Colors.redAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                      : Colors.redAccent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    size: 12,
                                    color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            timeStr,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.blueGrey),
                            onPressed: () => _showEditEmployeeDialog(emp),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCardList(List<Map<String, dynamic>> filtered) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, idx) {
        final emp = filtered[idx];
        final timeStr = emp['createdAt'] != null
            ? emp['createdAt'].toString().substring(0, 10)
            : 'N/A';
        final statusStr = emp['status']?.toString().toLowerCase() ?? 'active';
        final isActive = statusStr == 'active';
        final empName = emp['name']?.toString() ?? '';
        final initial = empName.isNotEmpty ? empName[0].toUpperCase() : 'E';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: widget.isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          color: widget.isDark ? const Color(0xFF263238) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: FarmColors.forestGreen.withValues(alpha: 0.2),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FarmColors.forestGreenText,
                          fontSize: 14,
                        ),
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
                                emp['id']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                      : Colors.redAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            empName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.blueGrey),
                      onPressed: () => _showEditEmployeeDialog(emp),
                      tooltip: 'Edit Employee',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: -4),
                      padding: EdgeInsets.zero,
                      backgroundColor: widget.isDark
                          ? FarmColors.forestGreen
                          : (emp['role'].toString().contains('Specialist')
                              ? Colors.blue.withOpacity(0.1)
                              : (emp['role'].toString().contains('Picker')
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1))),
                      label: Text(
                        emp['role']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark
                              ? Colors.white
                              : (emp['role'].toString().contains('Specialist')
                                  ? Colors.blue.shade800
                                  : (emp['role'].toString().contains('Picker')
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800)),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          emp['department']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if (emp['department']?.toString().toLowerCase().contains('harvest') == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Team: ${emp['pickerTeamColor'] ?? 'NEW'}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.tealAccent : Colors.teal.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Joined: $timeStr',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _getDepartmentItems() {
    final depts = _departments.isNotEmpty
        ? _departments
        : [
            {'id': 'DEP001', 'name': 'Harvest', 'description': 'Responsible for mushroom picking and grading'},
            {'id': 'DEP002', 'name': 'Growing', 'description': 'Responsible for watering, composting and climate control'},
            {'id': 'DEP003', 'name': 'Maintenance', 'description': 'Responsible for mechanical repairs and cleaning'},
            {'id': 'DEP004', 'name': 'Sales', 'description': 'Responsible for retail orders and shipping logistics'},
          ];

    return depts.map((dept) {
      return DropdownMenuItem<String>(
        value: dept['name'] as String,
        child: Text(
          '${dept['name']} (${dept['id']})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );
    }).toList();
  }

  void _showEditEmployeeDialog(Map<String, dynamic> emp) {
    final formKey = GlobalKey<FormState>();
    final id = emp['id'] as String;
    String name = emp['name'] as String;
    String role = emp['role'] as String;
    String department = emp['department']?.toString() ?? 'Harvest';
    String pickerTeamColor = emp['pickerTeamColor']?.toString() ?? 'NEW';
    if (pickerTeamColor.trim().isEmpty) pickerTeamColor = 'NEW';
    if (!_teams.contains(pickerTeamColor)) {
      _teams.add(pickerTeamColor);
    }

    final deptsList = _departments.isNotEmpty
        ? _departments.map((d) => d['name'] as String).toList()
        : ['Harvest', 'Growing', 'Maintenance', 'Sales'];
    if (!deptsList.contains(department)) {
      department = deptsList.first;
    }

    final dropDownItems = _roles.isNotEmpty
        ? _roles
        : ['Harvest Picker', 'Box Mover', 'Growing Specialist', 'Maintenance Specialist'];
    if (!dropDownItems.contains(role)) {
      role = dropDownItems.first;
    }

    String status = (emp['status']?.toString().toLowerCase() == 'inactive' || emp['status']?.toString().toLowerCase() == 'not active') ? 'inactive' : 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isHarvestDept = department.toLowerCase().contains('harvest');
          return AlertDialog(
            title: const Text('Edit Employee Registry'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: id,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      enabled: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => name = val!.trim(),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Role'),
                    value: role,
                    items: dropDownItems
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => role = val!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Department'),
                    value: department,
                    items: _getDepartmentItems(),
                    onChanged: (val) => setDialogState(() => department = val!),
                  ),
                  if (isHarvestDept) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Harvest Team (Đội màu/Nhóm)'),
                      value: pickerTeamColor,
                      items: _teams
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t == 'NEW' ? 'NEW (Chưa phân team)' : 'Team $t'),
                              ))
                          .toList(),
                      onChanged: (val) => setDialogState(() => pickerTeamColor = val!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Status (Trạng thái)'),
                    value: status,
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active (Đang hoạt động)'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive (Tạm khóa / Ngưng)'),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => status = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    widget.onEditEmployee(id, name, role, department, status, isHarvestDept ? pickerTeamColor : null);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManageRolesDialog() async {
    final textController = TextEditingController();
    int selectedLevel = 0;

    // Fetch initial roles with levels
    List<Map<String, dynamic>> dialogRoles = await _repo.getRolesWithLevels();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manage Employee Roles & Levels'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: textController,
                        decoration: const InputDecoration(
                          hintText: 'Enter new role name...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: selectedLevel,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Lvl 0 (Worker)')),
                        DropdownMenuItem(value: 1, child: Text('Lvl 1 (Specialist)')),
                        DropdownMenuItem(value: 2, child: Text('Lvl 2 (Lead/Sup)')),
                        DropdownMenuItem(value: 3, child: Text('Lvl 3 (Manager)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedLevel = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmColors.forestGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final val = textController.text.trim();
                        if (val.isNotEmpty) {
                          await _repo.addRole(val, level: selectedLevel);
                          textController.clear();
                          selectedLevel = 0;
                          final updated = await _repo.getRolesWithLevels();
                          final updatedNames = await _repo.getRoles();
                          setState(() {
                            _roles = updatedNames;
                          });
                          setDialogState(() {
                            dialogRoles = updated;
                          });
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Active Roles & Levels:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: dialogRoles.isEmpty
                      ? const Center(child: Text('No roles defined.'))
                      : ListView.builder(
                          itemCount: dialogRoles.length,
                          itemBuilder: (c, idx) {
                            final r = dialogRoles[idx];
                            final level = r['level'] ?? 0;
                            String lvlLabel = 'Lvl $level';
                            if (level == 0) lvlLabel += ' (Worker)';
                            if (level == 1) lvlLabel += ' (Specialist)';
                            if (level == 2) lvlLabel += ' (Lead/Sup)';
                            if (level == 3) lvlLabel += ' (Manager)';

                            return ListTile(
                              dense: true,
                              title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(lvlLabel, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () async {
                                  final roleName = r['name'] ?? '';
                                  await _repo.deleteRole(roleName);
                                  final updated = await _repo.getRolesWithLevels();
                                  final updatedNames = await _repo.getRoles();
                                  setState(() {
                                    _roles = updatedNames;
                                  });
                                  setDialogState(() {
                                    dialogRoles = updated;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEmployeeDialog({String? prefilledId}) {
    final formKey = GlobalKey<FormState>();
    String id = prefilledId ?? '';
    String name = '';
    String password = '';
    String role = _roles.isNotEmpty ? _roles.first : 'Harvest Picker';
    final deptsList = _departments.isNotEmpty
        ? _departments.map((d) => d['name'] as String).toList()
        : ['Harvest', 'Growing', 'Maintenance', 'Sales'];
    String department = deptsList.contains('Harvest') ? 'Harvest' : deptsList.first;
    String pickerTeamColor = 'NEW';

    final dropDownItems = _roles.isNotEmpty
        ? _roles
        : ['Harvest Picker', 'Box Mover', 'Growing Specialist', 'Maintenance Specialist', 'Manager', 'Supervisor'];

    String status = 'active';

    bool isElevatedRole(String r) {
      final lower = r.toLowerCase();
      return lower.contains('manager') ||
          lower.contains('supervisor') ||
          lower.contains('lead') ||
          lower.contains('specialist');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final showPasswordField = isElevatedRole(role);
          final isHarvestDept = department.toLowerCase().contains('harvest');
          return AlertDialog(
            title: const Text('Add Employee Registry'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: id,
                    decoration: const InputDecoration(labelText: 'Employee ID (e.g. EMP007)'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => id = val!.trim().toUpperCase(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    onSaved: (val) => name = val!.trim(),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Role'),
                    value: role,
                    items: dropDownItems
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        role = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Department'),
                    value: department,
                    items: _getDepartmentItems(),
                    onChanged: (val) {
                      setDialogState(() {
                        department = val!;
                      });
                    },
                  ),
                  if (isHarvestDept) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Harvest Team (Đội màu/Nhóm)'),
                      value: pickerTeamColor,
                      items: _teams
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t == 'NEW' ? 'NEW (Chưa phân team)' : 'Team $t'),
                              ))
                          .toList(),
                      onChanged: (val) => setDialogState(() => pickerTeamColor = val!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Status (Trạng thái)'),
                    value: status,
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active (Đang hoạt động)'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive (Tạm khóa / Ngưng)'),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        status = val!;
                      });
                    },
                  ),
                  if (showPasswordField) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Initial Password (Mật khẩu khởi tạo)',
                        hintText: 'Mặc định: password123',
                      ),
                      onSaved: (val) => password = val?.trim() ?? '',
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    widget.onAddEmployee(id, name, role, department, password, status, isHarvestDept ? pickerTeamColor : null);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Employee $name successfully registered.')),
                    );
                  }
                },
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showImportExcelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Employee List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select an Excel (.xlsx) or CSV (.csv) file containing employee records.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
                color: widget.isDark ? Colors.white10 : Colors.grey.shade50,
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _simulateExcelImport();
                },
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.file_upload_outlined, size: 36, color: FarmColors.forestGreen),
                    SizedBox(height: 8),
                    Text('Click to Upload File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Drag and drop files here', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateExcelImport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excel Parser preview'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found 4 new employee records in spreadsheet:'),
            SizedBox(height: 12),
            Text('• EMP007 — Kevin P. (Harvest Picker)'),
            Text('• EMP008 — Jessica W. (Box Mover)'),
            Text('• EMP009 — Michael T. (Harvest Picker)'),
            Text('• EMP010 — Sarah L. (Box Mover)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
            onPressed: () {
              widget.onImportEmployees([
                {'id': 'EMP007', 'name': 'Kevin P.', 'role': 'Harvest Picker', 'department': 'Harvest'},
                {'id': 'EMP008', 'name': 'Jessica W.', 'role': 'Box Mover', 'department': 'Harvest'},
                {'id': 'EMP009', 'name': 'Michael T.', 'role': 'Harvest Picker', 'department': 'Harvest'},
                {'id': 'EMP010', 'name': 'Sarah L.', 'role': 'Box Mover', 'department': 'Harvest'},
              ]);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Successfully imported 4 employee records from Excel.')),
              );
            },
            child: const Text('Confirm Import', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showScanCardDialog() {
    _isScannerProcessing = false;
    _dialogScannerController = MobileScannerController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Scan Employee Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade700, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _dialogScannerController!,
                        onDetect: (capture) async {
                          if (_isScannerProcessing) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          final String? rawVal = barcodes.first.rawValue;
                          if (rawVal == null || rawVal.isEmpty) return;

                          _isScannerProcessing = true;
                          await _dialogScannerController?.stop();

                          final raw = rawVal.trim();
                          final parts = raw.split(',');
                          if (parts.length >= 3) {
                            final id = parts[0].trim().toUpperCase();
                            final name = parts[1].trim();
                            final role = parts[2].trim();
                            final dept = parts.length >= 4 ? parts[3].trim() : 'Harvest';
                            widget.onAddEmployee(id, name, role, dept);
                            if (ctx.mounted) Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Scanned barcode: Employee $name added successfully.')),
                            );
                          } else {
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showAddEmployeeDialog(prefilledId: raw);
                          }
                        },
                      ),
                      Positioned.fill(
                        child: const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: BorderPainterWidget(),
                        ),
                      ),
                      const _ScanningLaserLine(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Align employee badge QR/Barcode in viewfinder.\nFormats: "ID,Name,Role,Dept" or just "ID"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _dialogScannerController?.dispose();
                _dialogScannerController = null;
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScanButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.qr_code_scanner, size: 16),
      label: const Text('Scan Card'),
      onPressed: _showScanCardDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildImportButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.upload_file_rounded, size: 16),
      label: const Text('Import Employees'),
      onPressed: _showImportExcelDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: FarmColors.forestGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildImportTeamsButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.file_upload_rounded, size: 16),
      label: const Text('Import Teams (CSV/XLSX)'),
      onPressed: _importTeamsFromExcel,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildExportTeamsButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.file_download_rounded, size: 16, color: FarmColors.forestGreen),
      label: const Text('Export Teams (CSV)', style: TextStyle(color: FarmColors.forestGreenText, fontWeight: FontWeight.bold)),
      onPressed: _exportTeamsToExcel,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildManageRolesButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.supervised_user_circle_rounded, size: 16),
      label: const Text('Manage Roles'),
      onPressed: _showManageRolesDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAddEmployeeButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
      label: const Text('Add Employee'),
      onPressed: _showAddEmployeeDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: FarmColors.forestGreenText,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class BorderPainterWidget extends StatelessWidget {
  const BorderPainterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BorderPainter(),
    );
  }
}

class _BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      // Top Left Corner
      ..moveTo(0, 20)
      ..lineTo(0, 0)
      ..lineTo(20, 0)
      // Top Right Corner
      ..moveTo(size.width - 20, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 20)
      // Bottom Right Corner
      ..moveTo(size.width, size.height - 20)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - 20, size.height)
      // Bottom Left Corner
      ..moveTo(20, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - 20);

    canvas.drawPath(path, paint);

    // Draw scanning laser
    final laserPaint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), laserPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanningLaserLine extends StatefulWidget {
  const _ScanningLaserLine();

  @override
  State<_ScanningLaserLine> createState() => _ScanningLaserLineState();
}

class _ScanningLaserLineState extends State<_ScanningLaserLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Positioned.fill(
          child: Align(
            alignment: Alignment(0, _animationController.value * 2 - 1),
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.red,
                    Colors.transparent
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
