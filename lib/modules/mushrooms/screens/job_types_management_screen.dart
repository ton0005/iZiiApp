import 'package:flutter/material.dart';
import '../repository.dart';
import '../services/employee_service.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

/// Job Types management screen — CRUD over the catalogue of Growing job
/// types (mushroom_job_types), including fully custom types beyond the
/// built-in pipeline steps (filling, watering, prochloraz, ...).
///
/// Access is restricted to Level 2+ management (Lead/Supervisor/Manager).
/// The sidebar in [MushboomMonartoScreen] already hides this destination
/// from lower-level accounts, but the check is repeated here so the screen
/// is safe even if reached another way.
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

  Future<void> _checkAccessAndLoad() async {
    final empId = await _employeeService.getCurrentEmployeeId();
    final level = empId != null ? await _repo.getEmployeeLevel(empId) : 0;
    final allowed = level >= 2;
    if (!mounted) return;
    setState(() => _accessAllowed = allowed);
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
    if (_accessAllowed == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_accessAllowed == false) {
      return _buildAccessDenied();
    }

    final filtered = _jobTypes.where((j) {
      final query = _searchQuery.toLowerCase();
      return j['id'].toString().toLowerCase().contains(query) ||
          j['name'].toString().toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Types Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage the Growing job type catalogue — add custom job types beyond the built-in ones (${_jobTypes.length} total)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: const Text('Add Job Type'),
                onPressed: _showAddJobTypeDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmColors.forestGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Search Box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by ID or name...',
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
          // Job Types List Card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No job types found.'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              color: widget.isDark
                                  ? Colors.white10
                                  : Colors.grey.shade50,
                              child: const Row(
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text('JOB TYPE ID',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  Expanded(
                                      flex: 3,
                                      child: Text('NAME',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('STD. TIME',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('TYPE',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('STATUS',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('ACTIONS',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Colors.grey))),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // List Body
                            Expanded(
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final jt = filtered[idx];
                                  final isSolo = jt['is_solo_job'] == true;
                                  final isCustom = jt['is_custom'] == true;
                                  final isActive = jt['is_active'] == true;
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: widget.isDark
                                                  ? Colors.white10
                                                  : Colors.grey.shade100)),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 4),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                jt['id'],
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontFamily: 'monospace',
                                                    fontSize: 13),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  _buildColorDot(jt['color'] as String?),
                                                  Expanded(
                                                    child: Text(
                                                      jt['name'],
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          color: FarmColors
                                                              .forestGreen),
                                                    ),
                                                  ),
                                                  if (isSolo)
                                                    const Padding(
                                                      padding:
                                                          EdgeInsets.only(
                                                              left: 4),
                                                      child: Icon(
                                                          Icons
                                                              .shield_rounded,
                                                          size: 14,
                                                          color: Colors
                                                              .redAccent),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${jt['plan_minutes']} min',
                                                style:
                                                    const TextStyle(fontSize: 13),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: _buildBadge(
                                                isCustom ? 'Custom' : 'Built-in',
                                                isCustom
                                                    ? Colors.indigo
                                                    : Colors.blueGrey,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: _buildBadge(
                                                isActive ? 'Active' : 'Inactive',
                                                isActive
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.edit_rounded,
                                                        size: 16,
                                                        color: Colors.blue),
                                                    onPressed: () =>
                                                        _showEditJobTypeDialog(
                                                            jt),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons
                                                            .delete_forever_rounded,
                                                        size: 16,
                                                        color:
                                                            Colors.redAccent),
                                                    onPressed: () =>
                                                        _confirmDeleteJobType(
                                                            jt),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
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
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildColorDot(String? hexColor) {
    final color = MushroomsRepository.parseHexColor(hexColor) ?? const Color(0xFF0EA5E9);
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26, width: 1),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Access Restricted',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Only Level 2+ management (Lead / Supervisor / Manager) can manage job types.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
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

  void _showAddJobTypeDialog() {
    final formKey = GlobalKey<FormState>();
    String id = '';
    String name = '';
    int planMinutes = 30;
    bool isSoloJob = false;
    String color = '#10B981';
    bool idManuallyEdited = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Job Type'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onChanged: (val) {
                        name = val;
                        if (!idManuallyEdited) {
                          setDialogState(() => id = _slugify(val));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('id_$id'),
                      initialValue: id,
                      decoration: const InputDecoration(
                        labelText: 'Job Type ID (unique)',
                        helperText: 'Auto-filled from Name — edit if needed',
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onChanged: (val) {
                        idManuallyEdited = true;
                        id = val.trim();
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Standard Time (minutes)'),
                      initialValue: planMinutes.toString(),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onChanged: (val) =>
                          planMinutes = int.tryParse(val) ?? 30,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Stage Color (hex, e.g. #10B981)',
                        helperText: 'Controls stage color on maps and dashboard',
                      ),
                      initialValue: color,
                      onChanged: (val) => color = val.trim(),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alone Worker (Solo) job',
                          style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                          'Requires the Alone Worker safety flow (time limit, gas levels)',
                          style: TextStyle(fontSize: 11)),
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
                child: const Text('Cancel')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final finalId = id.trim().isEmpty ? _slugify(name) : id.trim();
                final ok = await _repo.addJobType(
                  id: finalId,
                  name: name,
                  planMinutes: planMinutes,
                  isSoloJob: isSoloJob,
                  color: color.isNotEmpty ? color : null,
                );
                if (!ok) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content:
                              Text('Job Type ID "$finalId" already exists.')),
                    );
                  }
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadJobTypes();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditJobTypeDialog(Map<String, dynamic> jobType) {
    final formKey = GlobalKey<FormState>();
    final id = jobType['id'] as String;
    String name = jobType['name'] as String;
    int planMinutes = jobType['plan_minutes'] as int;
    bool isSoloJob = jobType['is_solo_job'] == true;
    bool isActive = jobType['is_active'] == true;
    String color = (jobType['color'] as String?) ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Job Type'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: id,
                      decoration: const InputDecoration(
                        labelText: 'Job Type ID',
                        enabled: false,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: planMinutes.toString(),
                      decoration: const InputDecoration(
                          labelText: 'Standard Time (minutes)'),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onChanged: (val) =>
                          planMinutes = int.tryParse(val) ?? planMinutes,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: color,
                      decoration: const InputDecoration(
                        labelText: 'Stage Color (hex, e.g. #10B981)',
                        helperText: 'Controls stage color on maps and dashboard',
                      ),
                      onChanged: (val) => color = val.trim(),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alone Worker (Solo) job',
                          style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                          'Requires the Alone Worker safety flow (time limit, gas levels)',
                          style: TextStyle(fontSize: 11)),
                      value: isSoloJob,
                      onChanged: (v) => setDialogState(() => isSoloJob = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active',
                          style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                          'Inactive job types are hidden from the new-job dropdown',
                          style: TextStyle(fontSize: 11)),
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
                child: const Text('Cancel')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await _repo.updateJobType(
                  id: id,
                  name: name,
                  planMinutes: planMinutes,
                  isSoloJob: isSoloJob,
                  isActive: isActive,
                  color: color.isNotEmpty ? color : null,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadJobTypes();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteJobType(Map<String, dynamic> jobType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete job type "${jobType['name']}"? Existing jobs already created with this type keep their history — only the catalogue entry is removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
}
