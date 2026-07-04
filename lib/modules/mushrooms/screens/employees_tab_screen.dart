import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class EmployeesTabScreen extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> employees;
  final Function(String, String, String) onAddEmployee;
  final Function(List<Map<String, String>>) onImportEmployees;

  const EmployeesTabScreen({
    super.key,
    required this.isDark,
    required this.employees,
    required this.onAddEmployee,
    required this.onImportEmployees,
  });

  @override
  State<EmployeesTabScreen> createState() => _EmployeesTabScreenState();
}

class _EmployeesTabScreenState extends State<EmployeesTabScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
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
          Row(
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
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Scan Card'),
                    onPressed: _showScanCardDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Import Excel'),
                    onPressed: _showImportExcelDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Add Employee'),
                    onPressed: _showAddEmployeeDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreenText,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
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
          // Employees List Card
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
                  : Column(
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
                              Expanded(flex: 2, child: Text('CREATED AT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
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
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade100)),
                                ),
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
                                            backgroundColor: emp['role'].toString().contains('Specialist')
                                                ? Colors.blue.withOpacity(0.1)
                                                : (emp['role'].toString().contains('Picker')
                                                    ? Colors.green.withOpacity(0.1)
                                                    : Colors.orange.withOpacity(0.1)),
                                            label: Text(
                                              emp['role'],
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: emp['role'].toString().contains('Specialist')
                                                    ? Colors.blue.shade800
                                                    : (emp['role'].toString().contains('Picker')
                                                        ? Colors.green.shade800
                                                        : Colors.orange.shade800),
                                              ),
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
                                    ],
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

  void _showAddEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    String id = '';
    String name = '';
    String role = 'Harvest Picker';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Employee Registry'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
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
                items: const [
                  DropdownMenuItem(value: 'Harvest Picker', child: Text('Harvest Picker')),
                  DropdownMenuItem(value: 'Box Mover', child: Text('Box Mover')),
                  DropdownMenuItem(value: 'Growing Specialist', child: Text('Growing Specialist')),
                  DropdownMenuItem(value: 'Maintenance Specialist', child: Text('Maintenance Specialist')),
                ],
                onChanged: (val) => role = val!,
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
                widget.onAddEmployee(id, name, role);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Employee $name successfully registered.')),
                );
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                {'id': 'EMP007', 'name': 'Kevin P.', 'role': 'Harvest Picker'},
                {'id': 'EMP008', 'name': 'Jessica W.', 'role': 'Box Mover'},
                {'id': 'EMP009', 'name': 'Michael T.', 'role': 'Harvest Picker'},
                {'id': 'EMP010', 'name': 'Sarah L.', 'role': 'Box Mover'},
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
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Employee Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, color: Colors.white, size: 40),
                      SizedBox(height: 10),
                      Text('[ CAMERA VIEWFINDER LIVE ]', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      SizedBox(height: 6),
                      Text('Align card barcode within frame', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                  Positioned(
                    top: 40,
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: BorderPainterWidget(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Manual Entry (Simulate scan outcome)',
                hintText: 'e.g. EMP011,David B.,Box Mover',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
            onPressed: () {
              final raw = textController.text.trim();
              if (raw.isNotEmpty) {
                final parts = raw.split(',');
                if (parts.length >= 3) {
                  widget.onAddEmployee(parts[0].trim().toUpperCase(), parts[1].trim(), parts[2].trim());
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Scanned barcode: Employee ${parts[1]} added successfully.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid simulator entry. Format: ID,Name,Role')),
                  );
                }
              } else {
                // Default fallback simulation
                widget.onAddEmployee('EMP011', 'David B.', 'Box Mover');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scanned barcode: Employee David B. added successfully.')),
                );
              }
            },
            child: const Text('Simulate Scan', style: TextStyle(color: Colors.white)),
          ),
        ],
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
