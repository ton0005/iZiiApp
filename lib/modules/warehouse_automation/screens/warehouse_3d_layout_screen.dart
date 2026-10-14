import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/warehouse_3d_models.dart';
import '../services/warehouse_3d_service.dart';

class Warehouse3dLayoutScreen extends StatefulWidget {
  const Warehouse3dLayoutScreen({super.key});

  @override
  State<Warehouse3dLayoutScreen> createState() => _Warehouse3dLayoutScreenState();
}

class _Warehouse3dLayoutScreenState extends State<Warehouse3dLayoutScreen> {
  final Warehouse3dService _service = Warehouse3dService();

  List<Warehouse3dObject> _allObjects = [];
  bool _isLoading = true;
  String _filterZone = 'ALL';
  bool _showLabels = true;
  bool _showOccupancyHeatmap = true;
  Warehouse3dObject? _selectedObject;

  // Camera & viewport control
  double _zoom = 28.0;
  double _azimuth = math.pi / 4; // 45 degrees
  double _elevation = math.pi / 6; // 30 degrees
  Offset _panOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadWarehouseLayout();
  }

  Future<void> _loadWarehouseLayout() async {
    setState(() => _isLoading = true);
    try {
      final objects = await _service.loadWarehouse3dLayout();
      setState(() {
        _allObjects = objects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load 3D layout: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Warehouse3dObject> get _filteredObjects {
    if (_filterZone == 'ALL') return _allObjects;
    return _allObjects.where((obj) => obj.path.contains('/$_filterZone')).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate theme
      appBar: AppBar(
        title: const Text(
          '3D Warehouse Layout & Visual Locations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Icon(_showLabels ? Icons.label : Icons.label_off, color: Colors.cyanAccent),
            tooltip: _showLabels ? 'Hide Bin Labels' : 'Show Bin Labels',
            onPressed: () => setState(() => _showLabels = !_showLabels),
          ),
          IconButton(
            icon: Icon(
              _showOccupancyHeatmap ? Icons.local_fire_department : Icons.palette_outlined,
              color: Colors.amberAccent,
            ),
            tooltip: 'Occupancy Heatmap Mode',
            onPressed: () => setState(() => _showOccupancyHeatmap = !_showOccupancyHeatmap),
          ),
          IconButton(
            icon: const Icon(Icons.add_home_work_outlined, color: Colors.greenAccent),
            tooltip: 'Add New Aisle (Aisle Builder)',
            onPressed: _openAddAisleDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Layout',
            onPressed: _loadWarehouseLayout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Stack(
              children: [
                // 3D Canvas with gestures
                GestureDetector(
                  onScaleUpdate: (details) {
                    setState(() {
                      _zoom = (_zoom * details.scale).clamp(12.0, 75.0);
                      _panOffset += details.focalPointDelta;
                    });
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      final projection = IsometricProjection(
                        zoom: _zoom,
                        azimuth: _azimuth,
                        elevation: _elevation,
                        panOffset: _panOffset,
                      );

                      return CustomPaint(
                        size: size,
                        painter: _Warehouse3dPainter(
                          objects: _filteredObjects,
                          projection: projection,
                          selectedObjectId: _selectedObject?.id,
                          showLabels: _showLabels,
                          showHeatmap: _showOccupancyHeatmap,
                        ),
                      );
                    },
                  ),
                ),

                // Camera Angle Controls (Top-right floating overlay)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Camera View Angle',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCameraBtn('Isometric', () {
                              setState(() {
                                _azimuth = math.pi / 4;
                                _elevation = math.pi / 6;
                              });
                            }),
                            const SizedBox(width: 4),
                            _buildCameraBtn('Top-Down (2D)', () {
                              setState(() {
                                _azimuth = 0;
                                _elevation = math.pi / 2 - 0.01;
                              });
                            }),
                            const SizedBox(width: 4),
                            _buildCameraBtn('Oblique (45°)', () {
                              setState(() {
                                _azimuth = math.pi / 3;
                                _elevation = math.pi / 4;
                              });
                            }),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _zoom = (_zoom + 5.0).clamp(12.0, 75.0)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _zoom = (_zoom - 5.0).clamp(12.0, 75.0)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.center_focus_strong, color: Colors.white70, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() {
                                _panOffset = Offset.zero;
                                _zoom = 28.0;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Zone Selector & KPI legend (Top-left floating overlay)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.filter_alt_outlined, color: Colors.cyanAccent, size: 16),
                            const SizedBox(width: 6),
                            DropdownButton<String>(
                              value: _filterZone,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All Zones (Full Plant)')),
                                DropdownMenuItem(value: 'COLD', child: Text('Cold Store Zone')),
                                DropdownMenuItem(value: 'STAGING', child: Text('Staging Area')),
                                DropdownMenuItem(value: 'QUARANTINE', child: Text('Quarantine Zone (QC)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _filterZone = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildLegendRow(),
                      ],
                    ),
                  ),
                ),

                // Location details inspector modal (Bottom overlay)
                if (_selectedObject != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildLocationInspector(_selectedObject!),
                  )
                else
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildQuickSelectorBar(),
                  ),
              ],
            ),
    );
  }

  Widget _buildCameraBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  Widget _buildLegendRow() {
    return Row(
      children: [
        _buildLegendItem(const Color(0xFF10B981), 'Empty (0%)'),
        const SizedBox(width: 8),
        _buildLegendItem(const Color(0xFFF59E0B), 'Occupied (<100%)'),
        const SizedBox(width: 8),
        _buildLegendItem(const Color(0xFFE11D48), 'Full (100%)'),
        const SizedBox(width: 8),
        _buildLegendItem(const Color(0xFF8B5CF6), 'Quarantine (QC)'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildQuickSelectorBar() {
    final binObjects = _filteredObjects.where((o) => o.type == 'bin').toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap a bin to view stock inventory or modify coordinates (${binObjects.length} storage bins)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          PopupMenuButton<Warehouse3dObject>(
            icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.cyanAccent),
            tooltip: 'Select storage bin from list',
            onSelected: (obj) => setState(() => _selectedObject = obj),
            itemBuilder: (context) => binObjects.map((obj) {
              return PopupMenuItem(
                value: obj,
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: obj.statusColor),
                    const SizedBox(width: 8),
                    Text('${obj.code} (${obj.palletCount} Pallets)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInspector(Warehouse3dObject obj) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: obj.statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: obj.statusColor),
                    ),
                    child: Text(
                      obj.code,
                      style: TextStyle(
                        color: obj.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    obj.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => setState(() => _selectedObject = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  '3D Coordinates (m)',
                  'X:${obj.x.toStringAsFixed(1)} Y:${obj.y.toStringAsFixed(1)} Z:${obj.z.toStringAsFixed(1)}',
                  Icons.scatter_plot,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  'Payload Capacity',
                  '${(obj.currentWeightKg ?? 0).toStringAsFixed(0)} / ${(obj.maxWeightKg ?? 1500).toStringAsFixed(0)} kg',
                  Icons.monitor_weight_outlined,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  'Pallet Occupancy',
                  '${obj.palletCount} / ${obj.maxPallets} Pallets',
                  Icons.layers_outlined,
                ),
              ),
            ],
          ),
          if (obj.storedLpns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Stored Pallet LPN Barcodes:',
              style: TextStyle(color: Colors.cyanAccent.shade100, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: obj.storedLpns.map((lpn) {
                return Chip(
                  backgroundColor: const Color(0xFF0F172A),
                  side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                  label: Text(lpn, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  avatar: const Icon(Icons.qr_code, color: Colors.cyanAccent, size: 14),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Edit Position / Status', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                ),
                onPressed: () => _openEditLocationDialog(obj),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 13),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Future<void> _openAddAisleDialog() async {
    final zoneCtrl = TextEditingController(text: 'COLD');
    final aisleCtrl = TextEditingController(text: 'A03');
    final startXCtrl = TextEditingController(text: '10.0');
    final startYCtrl = TextEditingController(text: '2.0');
    final bayCountCtrl = TextEditingController(text: '4');
    final levelCountCtrl = TextEditingController(text: '3');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add & Arrange 3D Aisle / Racks', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: zoneCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Zone Code (e.g. COLD)', labelStyle: TextStyle(color: Colors.white70)),
              ),
              TextField(
                controller: aisleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Aisle Code (e.g. A03)', labelStyle: TextStyle(color: Colors.white70)),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startXCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Origin X (m)', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: startYCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Origin Y (m)', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: bayCountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Rack Bays', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: levelCountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Shelf Levels', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Create 3D Racks', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final config = AisleTemplateConfig(
                zoneCode: zoneCtrl.text.trim().toUpperCase(),
                aisleCode: aisleCtrl.text.trim().toUpperCase(),
                startX: double.tryParse(startXCtrl.text) ?? 10.0,
                startY: double.tryParse(startYCtrl.text) ?? 2.0,
                bayCount: int.tryParse(bayCountCtrl.text) ?? 4,
                levelCount: int.tryParse(levelCountCtrl.text) ?? 3,
              );
              await _service.createAisleWithRacks(config);
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );

    if (result == true) {
      await _loadWarehouseLayout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully created 3D Aisle and synchronized to Drift/Postgres!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _openEditLocationDialog(Warehouse3dObject obj) async {
    final xCtrl = TextEditingController(text: obj.x.toString());
    final yCtrl = TextEditingController(text: obj.y.toString());
    final zCtrl = TextEditingController(text: obj.z.toString());
    final weightCtrl = TextEditingController(text: (obj.maxWeightKg ?? 1500).toString());
    String status = obj.status;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Edit Location: ${obj.code}', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: xCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'X (m)', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: yCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Y (m)', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: zCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Z (m)', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Max Payload (kg)', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Location Status', labelStyle: TextStyle(color: Colors.white70)),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active (Ready)')),
                    DropdownMenuItem(value: 'blocked', child: Text('Blocked / Locked')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => status = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await _service.updateLocationPositionAndStatus(
                  locationId: obj.id,
                  posX: double.tryParse(xCtrl.text),
                  posY: double.tryParse(yCtrl.text),
                  posZ: double.tryParse(zCtrl.text),
                  maxWeightKg: double.tryParse(weightCtrl.text),
                  status: status,
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      await _loadWarehouseLayout();
      setState(() => _selectedObject = null);
    }
  }
}

/// CustomPainter for rendering 3D isometric warehouse cuboids and labels
class _Warehouse3dPainter extends CustomPainter {
  final List<Warehouse3dObject> objects;
  final IsometricProjection projection;
  final String? selectedObjectId;
  final bool showLabels;
  final bool showHeatmap;

  _Warehouse3dPainter({
    required this.objects,
    required this.projection,
    this.selectedObjectId,
    required this.showLabels,
    required this.showHeatmap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw 3D floor grid
    _drawFloorGrid(canvas, size);

    // 2. Sort objects back-to-front (Painter's algorithm)
    final sorted = List<Warehouse3dObject>.from(objects)
      ..sort((a, b) {
        final depthA = projection.depth(a.x + a.width / 2, a.y + a.length / 2, a.z);
        final depthB = projection.depth(b.x + b.width / 2, b.y + b.length / 2, b.z);
        return depthA.compareTo(depthB);
      });

    // 3. Render 3D Cuboids
    for (final obj in sorted) {
      _draw3dCuboid(canvas, size, obj);
    }
  }

  void _drawFloorGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    const gridSize = 20.0; // 20m x 20m floor
    const step = 2.0;

    for (double x = -6.0; x <= gridSize; x += step) {
      final p1 = projection.project(x, -2.0, 0, size);
      final p2 = projection.project(x, gridSize, 0, size);
      canvas.drawLine(p1, p2, gridPaint);
    }

    for (double y = -2.0; y <= gridSize; y += step) {
      final p1 = projection.project(-6.0, y, 0, size);
      final p2 = projection.project(gridSize, y, 0, size);
      canvas.drawLine(p1, p2, gridPaint);
    }
  }

  void _draw3dCuboid(Canvas canvas, Size size, Warehouse3dObject obj) {
    final isSelected = obj.id == selectedObjectId;
    final baseColor = showHeatmap ? obj.statusColor : (obj.customColor ?? const Color(0xFF3B82F6));

    final topColor = baseColor.withValues(alpha: 0.9);
    final leftColor = HSLColor.fromColor(baseColor).withLightness((HSLColor.fromColor(baseColor).lightness * 0.7).clamp(0.0, 1.0)).toColor();
    final rightColor = HSLColor.fromColor(baseColor).withLightness((HSLColor.fromColor(baseColor).lightness * 0.85).clamp(0.0, 1.0)).toColor();

    final x0 = obj.x;
    final x1 = obj.x + obj.width;
    final y0 = obj.y;
    final y1 = obj.y + obj.length;
    final z0 = obj.z;
    final z1 = obj.z + obj.height;

    // 7 visible vertices used for rendering top, left, right faces
    final p000 = projection.project(x0, y0, z0, size);
    final p110 = projection.project(x1, y1, z0, size);
    final p010 = projection.project(x0, y1, z0, size);

    final p001 = projection.project(x0, y0, z1, size);
    final p101 = projection.project(x1, y0, z1, size);
    final p111 = projection.project(x1, y1, z1, size);
    final p011 = projection.project(x0, y1, z1, size);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = isSelected ? Colors.cyanAccent : Colors.black45
      ..strokeWidth = isSelected ? 2.5 : 1.0;

    // Left face (X = x0)
    final leftPath = Path()
      ..moveTo(p000.dx, p000.dy)
      ..lineTo(p010.dx, p010.dy)
      ..lineTo(p011.dx, p011.dy)
      ..lineTo(p001.dx, p001.dy)
      ..close();
    fillPaint.color = leftColor;
    canvas.drawPath(leftPath, fillPaint);
    canvas.drawPath(leftPath, borderPaint);

    // Front/Right face (Y = y1)
    final rightPath = Path()
      ..moveTo(p010.dx, p010.dy)
      ..lineTo(p110.dx, p110.dy)
      ..lineTo(p111.dx, p111.dy)
      ..lineTo(p011.dx, p011.dy)
      ..close();
    fillPaint.color = rightColor;
    canvas.drawPath(rightPath, fillPaint);
    canvas.drawPath(rightPath, borderPaint);

    // Top face (Z = z1)
    final topPath = Path()
      ..moveTo(p001.dx, p001.dy)
      ..lineTo(p101.dx, p101.dy)
      ..lineTo(p111.dx, p111.dy)
      ..lineTo(p011.dx, p011.dy)
      ..close();
    fillPaint.color = topColor;
    canvas.drawPath(topPath, fillPaint);
    canvas.drawPath(topPath, borderPaint);

    // Label
    if (showLabels && (obj.type == 'bin' || obj.type == 'staging' || obj.type == 'quarantine')) {
      final centerTop = Offset(
        (p001.dx + p101.dx + p111.dx + p011.dx) / 4,
        (p001.dy + p101.dy + p111.dy + p011.dy) / 4,
      );

      final labelText = obj.code.contains('-') ? obj.code.split('-').last : obj.code;
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(centerTop.dx - textPainter.width / 2, centerTop.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Warehouse3dPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.projection != projection ||
        oldDelegate.selectedObjectId != selectedObjectId ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showHeatmap != showHeatmap;
  }
}
