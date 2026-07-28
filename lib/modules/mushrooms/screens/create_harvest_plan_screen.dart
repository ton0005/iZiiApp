import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:izii_app/core/theme/izii_colors.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors
import '../widgets/plant_map_widget.dart';
import '../services/harvest_plan_service.dart';
import '../services/harvest_plan_excel_service.dart';
import '../repository.dart';

class CreateHarvestPlanScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final Map<String, List<String>> roomCrews;
  final Map<String, dynamic>? initialPlanData;

  const CreateHarvestPlanScreen({
    super.key,
    required this.isDark,
    required this.localRooms,
    required this.roomCrews,
    this.initialPlanData,
  });

  @override
  State<CreateHarvestPlanScreen> createState() => _CreateHarvestPlanScreenState();
}

class _CreateHarvestPlanScreenState extends State<CreateHarvestPlanScreen> {
  final HarvestPlanService _planService = HarvestPlanService();
  final HarvestPlanExcelService _excelService = HarvestPlanExcelService();
  final MushroomsRepository _repo = MushroomsRepository();

  late DateTime _planDate;
  late String _activePlant;
  late String _status; // 'draft' or 'published'
  String? _planId;

  final Set<String> _selectedRoomNames = {};
  final List<Map<String, dynamic>> _roomAssignments = [];
  List<Map<String, dynamic>> _dbTeams = [];

  @override
  void initState() {
    super.initState();
    _activePlant = 'M2';
    _status = 'published';
    _loadDatabaseTeams();

    if (widget.initialPlanData != null) {
      final p = widget.initialPlanData!;
      _planId = p['id'];
      _planDate = p['planDate'] is DateTime ? p['planDate'] : DateTime.parse(p['planDate']);
      _activePlant = p['zoneId'] ?? 'M2';
      _status = p['status'] ?? 'published';

      final List assignments = p['assignments'] ?? [];
      for (final a in assignments) {
        final rName = (a['roomName'] ?? a['roomId'] ?? '').toString();
        if (rName.isNotEmpty) {
          _selectedRoomNames.add(rName);

          final List teamsList = a['teams'] is List ? a['teams'] : [];
          String teamStr = 'PURPLE';
          if (teamsList.isNotEmpty) {
            teamStr = teamsList.map((t) => t['teamColor'] ?? t.toString()).join(' & ');
          }

          final List instrs = a['instructions'] is List ? a['instructions'] : [];
          String instrStr = instrs.isNotEmpty ? instrs.first.toString() : '—';

          _roomAssignments.add({
            'roomName': rName,
            'flush': a['flush'] ?? 1,
            'boxTarget': a['boxTarget'] ?? 600,
            'trolleyCount': a['trolleyCount'] ?? 8,
            'teams': teamStr,
            'headcount': a['headcount'] ?? 8,
            'instructions': instrStr,
          });
        }
      }
    } else {
      _planDate = DateTime.now();
      // Pre-select Room 50 default test assignment
      _selectedRoomNames.add('Room 50');
      _roomAssignments.add({
        'roomName': 'Room 50',
        'flush': 1,
        'boxTarget': 1400,
        'trolleyCount': 16,
        'teams': 'JADE & AMBER',
        'headcount': 14,
        'instructions': 'MYCOSENSE INSTRUCTION: 6,1,7',
      });
    }
  }

  Future<void> _loadDatabaseTeams() async {
    final teams = await _repo.getPickerTeamsDetails();
    if (mounted) {
      setState(() {
        _dbTeams = teams;
      });
    }
  }

  Color _getTeamColor(String code) {
    switch (code.toUpperCase()) {
      case 'PURPLE': return Colors.purple;
      case 'PEARL': return Colors.grey.shade400;
      case 'IVORY': return Colors.amber.shade200;
      case 'SAPPHIRE': return Colors.blue;
      case 'JADE': return Colors.teal;
      case 'AMBER': return Colors.amber.shade800;
      case 'RUBY': return Colors.red;
      case 'BLACK': return Colors.black;
      case 'PEACH': return Colors.orange.shade300;
      case 'LIME': return Colors.lime.shade700;
      default: return FarmColors.forestGreen;
    }
  }

  void _showTeamSelectionDialog(Map<String, dynamic> item) {
    final currentTeamsStr = item['teams'].toString();
    final List<String> currentSelected = currentTeamsStr
        .split('&')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    final selectedSet = Set<String>.from(currentSelected);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.storage_rounded, color: FarmColors.forestGreen, size: 20),
                  const SizedBox(width: 8),
                  Text('SELECT DATABASE TEAMS (${item['roomName']})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select assigned teams directly from Database:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                Navigator.pop(ctx);
                                await _importTeamsFromExcel();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.file_upload_rounded, size: 14, color: FarmColors.forestGreen),
                                    SizedBox(width: 2),
                                    Text('Import CSV', style: TextStyle(fontSize: 11, color: FarmColors.forestGreenText, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () async {
                                await _exportTeamsToExcel();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.file_download_rounded, size: 14, color: FarmColors.forestGreen),
                                    SizedBox(width: 2),
                                    Text('Export CSV', style: TextStyle(fontSize: 11, color: FarmColors.forestGreenText, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _dbTeams.map((t) {
                            final code = (t['colorCode'] ?? '').toString().toUpperCase();
                            final isSel = selectedSet.contains(code);
                            final hc = t['headcount'] ?? 8;
                            final rate = t['rateEstimate'] ?? 28.5;

                            return FilterChip(
                              selected: isSel,
                              avatar: CircleAvatar(
                                backgroundColor: _getTeamColor(code),
                                radius: 8,
                              ),
                              label: Text('$code ($hc HV · ${rate}kg/h)', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    selectedSet.add(code);
                                  } else {
                                    selectedSet.remove(code);
                                  }
                                });
                              },
                              selectedColor: FarmColors.forestGreen.withOpacity(0.2),
                              checkmarkColor: FarmColors.forestGreen,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen, foregroundColor: Colors.white),
                  onPressed: () {
                    final newTeamsStr = selectedSet.isNotEmpty
                        ? selectedSet.join(' & ')
                        : 'PURPLE';

                    int totalHeadcount = 0;
                    for (final code in selectedSet) {
                      final match = _dbTeams.firstWhere((t) => (t['colorCode'] ?? '').toString().toUpperCase() == code, orElse: () => {});
                      if (match.isNotEmpty) {
                        totalHeadcount += (match['headcount'] ?? 8) as int;
                      }
                    }
                    if (totalHeadcount == 0) totalHeadcount = 8;

                    setState(() {
                      item['teams'] = newTeamsStr;
                      item['headcount'] = totalHeadcount;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Confirm Selection'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleRoomSelection(String roomName) {
    setState(() {
      if (_selectedRoomNames.contains(roomName)) {
        _selectedRoomNames.remove(roomName);
        _roomAssignments.removeWhere((ra) => ra['roomName'] == roomName);
      } else {
        _selectedRoomNames.add(roomName);
        _roomAssignments.add({
          'roomName': roomName,
          'flush': 1,
          'boxTarget': 600,
          'trolleyCount': 8,
          'teams': 'PURPLE',
          'headcount': 8,
          'instructions': 'Standard harvesting',
        });
      }
    });
  }

  Future<void> _savePlan(String targetStatus) async {
    if (_roomAssignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one room on the map.')),
      );
      return;
    }

    try {
      final savedId = await _planService.saveHarvestPlan(
        planId: _planId,
        planDate: _planDate,
        zoneId: _activePlant,
        status: targetStatus,
        roomAssignments: _roomAssignments,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(targetStatus == 'published'
                ? 'Successfully published Harvest Plan ($savedId) to SQLite!'
                : 'Saved Harvest Plan ($savedId) as Draft.'),
            backgroundColor: FarmColors.forestGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: $e'), backgroundColor: IZiiColors.error),
        );
      }
    }
  }

  Future<void> _importExcelPlan() async {
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
        final importedAssignments = _excelService.parsePlanFromCsvContent(content);

        if (importedAssignments.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not find room assignments in selected file.')),
            );
          }
          return;
        }

        setState(() {
          _selectedRoomNames.clear();
          _roomAssignments.clear();

          for (final item in importedAssignments) {
            final rName = item['roomName'].toString();
            _selectedRoomNames.add(rName);
            _roomAssignments.add(item);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported ${_roomAssignments.length} room assignments from Excel CSV!'),
              backgroundColor: FarmColors.forestGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing Excel file: $e'), backgroundColor: IZiiColors.error),
        );
      }
    }
  }

  Future<void> _exportExcelPlan() async {
    if (_roomAssignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add room assignments before exporting.')),
      );
      return;
    }

    try {
      final planData = {
        'id': _planId ?? 'PLAN_${_planDate.year}${_planDate.month.toString().padLeft(2, '0')}${_planDate.day.toString().padLeft(2, '0')}',
        'planDate': _planDate,
        'zoneId': _activePlant,
        'status': _status,
        'totalTargetBoxes': _roomAssignments.fold(0, (sum, item) => sum + ((item['boxTarget'] ?? 0) as int)),
        'createdBy': 'Manager',
        'assignments': _roomAssignments,
      };

      final file = await _excelService.exportPlanToCsvFile(planData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan exported to Excel CSV: ${file.path}'),
            backgroundColor: FarmColors.forestGreen,
            action: SnackBarAction(
              label: 'Share/Open',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(file.path)], text: 'Costa Mushroom Harvesting Plan CSV');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: IZiiColors.error),
        );
      }
    }
  }

  Future<void> _downloadSampleTemplate() async {
    try {
      final file = await _excelService.generateSampleExcelTemplate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample Excel Template generated: ${file.path}'),
            backgroundColor: FarmColors.forestGreen,
            action: SnackBarAction(
              label: 'Share/Open',
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(file.path)], text: 'Sample Harvesting Plan Template CSV');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating template: $e'), backgroundColor: IZiiColors.error),
        );
      }
    }
  }

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
        await _loadDatabaseTeams();

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
          SnackBar(content: Text('Error importing teams CSV: $e'), backgroundColor: IZiiColors.error),
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
            content: Text('Picker Teams exported to CSV: ${file.path}'),
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
          SnackBar(content: Text('Error exporting teams CSV: $e'), backgroundColor: IZiiColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final pageBg = isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground;
    final cardBg = isDark ? IZiiColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _planId == null ? 'CREATE HARVEST PLAN' : 'EDIT HARVEST PLAN (${_planId})',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              'Select rooms directly on floor map or import Excel CSV plan',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.file_upload_rounded, size: 16, color: FarmColors.forestGreen),
            label: const Text('Import Excel', style: TextStyle(fontSize: 12, color: FarmColors.forestGreenText)),
            onPressed: _importExcelPlan,
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.file_download_rounded, size: 16, color: FarmColors.forestGreen),
            label: const Text('Export Excel', style: TextStyle(fontSize: 12, color: FarmColors.forestGreenText)),
            onPressed: _exportExcelPlan,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.description_rounded, color: FarmColors.forestGreen, size: 20),
            tooltip: 'Download Sample Excel Template',
            onPressed: _downloadSampleTemplate,
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            icon: const Icon(Icons.drafts_rounded, size: 16),
            label: const Text('Save Draft'),
            onPressed: () => _savePlan('draft'),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmColors.forestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.publish_rounded, size: 16),
            label: const Text('Save & Publish Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _savePlan('published'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane: Shared PlantMapWidget with Multi-Select enabled
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border.all(color: widget.isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: FarmColors.forestGreen.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.touch_app_rounded, color: FarmColors.forestGreen, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'FLOOR MAP MULTI-SELECT',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: FarmColors.forestGreenText),
                              ),
                            ],
                          ),
                          Text(
                            '${_selectedRoomNames.length} Rooms Selected',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PlantMapWidget(
                        isDark: isDark,
                        activePlant: _activePlant,
                        localRooms: widget.localRooms,
                        roomCrews: widget.roomCrews,
                        selectedRoomNames: _selectedRoomNames,
                        onRoomSelected: (rName) => _toggleRoomSelection(rName),
                        onPlantChanged: (plant) => setState(() => _activePlant = plant),
                        showHeader: true,
                        showLegend: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Pane: Plan Header & Room Assignments Form
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border.all(color: widget.isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan General Settings Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _planDate,
                                firstDate: DateTime(2026),
                                lastDate: DateTime(2028),
                              );
                              if (picked != null) {
                                setState(() => _planDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Plan Date',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                border: OutlineInputBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_planDate.day.toString().padLeft(2, '0')}/${_planDate.month.toString().padLeft(2, '0')}/${_planDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: 'Initial Status',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'draft', child: Text('Draft')),
                              DropdownMenuItem(value: 'published', child: Text('Published')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ASSIGNED ROOMS DETAILS (${_roomAssignments.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: FarmColors.forestGreenText),
                        ),
                        if (_selectedRoomNames.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedRoomNames.clear();
                                _roomAssignments.clear();
                              });
                            },
                            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Room Assignments List
                    Expanded(
                      child: _roomAssignments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.touch_app_rounded, size: 40, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap room cards on the left floor map to add assignments.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _roomAssignments.length,
                              itemBuilder: (context, idx) {
                                final item = _roomAssignments[idx];
                                return _buildRoomAssignmentCard(idx, item);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomAssignmentCard(int idx, Map<String, dynamic> item) {
    final isDark = widget.isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade50,
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['roomName'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: FarmColors.forestGreenText),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _selectedRoomNames.remove(item['roomName']);
                    _roomAssignments.removeAt(idx);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: item['flush'] as int,
                  decoration: const InputDecoration(labelText: 'Flush', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Flush 1')),
                    DropdownMenuItem(value: 2, child: Text('Flush 2')),
                    DropdownMenuItem(value: 3, child: Text('Flush 3')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => item['flush'] = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item['boxTarget'].toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Box Target', isDense: true, border: OutlineInputBorder()),
                  onChanged: (val) {
                    item['boxTarget'] = int.tryParse(val) ?? 0;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item['trolleyCount'].toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Trolleys', isDense: true, border: OutlineInputBorder()),
                  onChanged: (val) {
                    item['trolleyCount'] = int.tryParse(val) ?? 0;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () => _showTeamSelectionDialog(item),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Assigned Team(s) (Database)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['teams'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item['headcount'].toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pickers', isDense: true, border: OutlineInputBorder()),
                  onChanged: (val) {
                    item['headcount'] = int.tryParse(val) ?? 8;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: item['instructions'].toString(),
            decoration: const InputDecoration(
              labelText: 'Picking Instructions',
              hintText: 'e.g. MYCOSENSE INSTRUCTION: 6,1,7',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              item['instructions'] = val;
            },
          ),
        ],
      ),
    );
  }
}
