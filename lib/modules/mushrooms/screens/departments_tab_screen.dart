import 'package:flutter/material.dart';
import '../repository.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class DepartmentsTabScreen extends StatefulWidget {
  final bool isDark;

  const DepartmentsTabScreen({
    super.key,
    required this.isDark,
  });

  @override
  State<DepartmentsTabScreen> createState() => _DepartmentsTabScreenState();
}

class _DepartmentsTabScreenState extends State<DepartmentsTabScreen> {
  final MushroomsRepository _repo = MushroomsRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _departments = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoading = true);
    final list = await _repo.getDepartments();
    setState(() {
      _departments = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _departments.where((d) {
      final query = _searchQuery.toLowerCase();
      return d['id'].toString().toLowerCase().contains(query) ||
          d['name'].toString().toLowerCase().contains(query) ||
          (d['description'] ?? '').toString().toLowerCase().contains(query);
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
                    'Department Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage company organization departments (${_departments.length} active)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_business_rounded, size: 16),
                label: const Text('Add Department'),
                onPressed: _showAddDepartmentDialog,
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
              hintText: 'Search by ID, name or description...',
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
          // Departments List Card
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
                      ? const Center(
                          child: Text('No departments found.'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              color: widget.isDark ? Colors.white10 : Colors.grey.shade50,
                              child: const Row(
                                children: [
                                  Expanded(flex: 2, child: Text('DEPARTMENT ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                  Expanded(flex: 3, child: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                  Expanded(flex: 5, child: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                  Expanded(flex: 2, child: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // List Body
                            Expanded(
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final dept = filtered[idx];
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
                                                dept['id'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                dept['name'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FarmColors.forestGreen),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 5,
                                              child: Text(
                                                dept['description'] ?? 'N/A',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.blue),
                                                    onPressed: () => _showEditDepartmentDialog(dept),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.redAccent),
                                                    onPressed: () => _confirmDeleteDepartment(dept),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
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

  void _showAddDepartmentDialog() {
    final formKey = GlobalKey<FormState>();
    String id = '';
    String name = '';
    String description = '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Department'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Department ID (e.g. DEP005)'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => id = val!.trim().toUpperCase(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => name = val!.trim(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                onSaved: (val) => description = val?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                await _repo.addDepartment(id, name, description);
                Navigator.pop(ctx);
                _loadDepartments();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDepartmentDialog(Map<String, dynamic> dept) {
    final formKey = GlobalKey<FormState>();
    final id = dept['id'] as String;
    String name = dept['name'] as String;
    String description = dept['description'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Department'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: id,
                decoration: const InputDecoration(
                  labelText: 'Department ID',
                  enabled: false,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => name = val!.trim(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                onSaved: (val) => description = val?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                await _repo.updateDepartment(id, name, description);
                Navigator.pop(ctx);
                _loadDepartments();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDepartment(Map<String, dynamic> dept) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete department "${dept['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _repo.deleteDepartment(dept['id'] as String);
              Navigator.pop(ctx);
              _loadDepartments();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
