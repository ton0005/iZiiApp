import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter_animate/flutter_animate.dart';

import 'package:izii_app/core/theme/izii_colors.dart';
import '../../../core/database/app_database.dart';
import '../repository.dart';
import '../services/employee_service.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class HarvestAttendanceScreen extends StatefulWidget {
  final bool isDark;
  const HarvestAttendanceScreen({super.key, required this.isDark});

  @override
  State<HarvestAttendanceScreen> createState() => _HarvestAttendanceScreenState();
}

class _HarvestAttendanceScreenState extends State<HarvestAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final AppDatabase _db = AppDatabase();
  final MushroomsRepository _repo = MushroomsRepository();
  final EmployeeService _employeeService = EmployeeServiceImpl();

  // Tab navigation index matching mockup:
  // 0: Quét QR, 1: Xác nhận Room, 2: Đang làm việc, 3: Check-out, 4: Manager duyệt
  int _activeTabIndex = 0;

  // Active Picker Session State (Simulated/Tracked)
  String? _scannedEmployeeId;
  String? _scannedEmployeeName;
  String? _scannedEmployeeRole;
  String? _scannedTeamColor;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;

  // Break timing
  bool _isOnBreak = false;
  DateTime? _breakStartTime;
  int _accumulatedBreakMinutes = 0;
  Timer? _shiftTimer;
  Duration _workedDuration = Duration.zero;

  // Real-time scan fields
  MobileScannerController? _scannerController;
  bool _isScannerProcessing = false;
  final TextEditingController _manualIdController = TextEditingController();

  // Seed / Plan Data loaded from SQLite
  List<Map<String, dynamic>> _assignedRooms = [];
  List<Map<String, dynamic>> _pendingTimesheets = [];
  Map<String, dynamic>? _activePlan;

  @override
  void initState() {
    super.initState();
    _seedDefaultHarvestData();
    _loadDailyPlanData();
    _loadPendingTimesheets();
  }

  @override
  void dispose() {
    _shiftTimer?.cancel();
    _scannerController?.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  // --- Seed Demo Data if tables are empty ---
  // --- Seed Demo Data if tables are empty ---
  Future<void> _seedDefaultHarvestData() async {
    final today = DateTime.now();
    final plans = await _db.select(_db.mushroomHarvestPlans).get();
    if (plans.isEmpty) {
      const planId = 'PLAN_20260724';
      // Seed Plan
      await _db.into(_db.mushroomHarvestPlans).insert(
            MushroomHarvestPlansCompanion.insert(
              id: planId,
              planDate: today,
              zoneId: const d.Value('M2'),
              status: const d.Value('published'),
              totalTargetBoxes: const d.Value(42374),
            ),
          );

      // Seed break policy
      await _db.into(_db.mushroomBreakPolicies).insert(
            MushroomBreakPoliciesCompanion.insert(
              id: 'BP_STANDARD',
              standardBreakMinutes: const d.Value(25),
              graceMinutes: const d.Value(5),
              extraBreakRule: const d.Value('unpaid'),
            ),
          );

      // Seed Picker Teams from Real Harvesting Plan
      final teamSeeds = [
        {'id': 'TEAM_PURPLE', 'color': 'PURPLE', 'members': '["EMP001", "305629"]', 'rate': 31.5, 'headcount': 8},
        {'id': 'TEAM_PEARL', 'color': 'PEARL', 'members': '["EMP004"]', 'rate': 36.6, 'headcount': 8},
        {'id': 'TEAM_IVORY', 'color': 'IVORY', 'members': '["EMP002"]', 'rate': 28.7, 'headcount': 8},
        {'id': 'TEAM_JADE', 'color': 'JADE', 'members': '["EMP003"]', 'rate': 36.0, 'headcount': 8},
        {'id': 'TEAM_SAPPHIRE', 'color': 'SAPPHIRE', 'members': '[]', 'rate': 35.6, 'headcount': 8},
        {'id': 'TEAM_AMBER', 'color': 'AMBER', 'members': '[]', 'rate': 31.4, 'headcount': 6},
        {'id': 'TEAM_PEACH', 'color': 'PEACH', 'members': '[]', 'rate': 30.3, 'headcount': 8},
      ];

      for (final t in teamSeeds) {
        await _db.into(_db.mushroomPickerTeams).insert(
              MushroomPickerTeamsCompanion.insert(
                id: t['id'] as String,
                planId: planId,
                colorCode: t['color'] as String,
                headcount: d.Value(t['headcount'] as int),
                rateEstimate: d.Value(t['rate'] as double),
                memberIdsJson: d.Value(t['members'] as String),
              ),
            );
      }

      // Seed Room Assignments from Real Harvesting Plan Sheet (24/07/2026)
      final roomSeeds = [
        {'id': 'ASG_ROOM3', 'room': 'Room 3', 'boxes': 1000, 'trolley': 16, 'teams': '[{"teamColor": "IVORY", "headcount": 8}, {"teamColor": "PEARL", "headcount": 8}]', 'instr': '["CLUMPS (WASH TROLLEYS)"]'},
        {'id': 'ASG_ROOM24', 'room': 'Room 24', 'boxes': 600, 'trolley': 16, 'teams': '[{"teamColor": "PURPLE", "headcount": 8}]', 'instr': '["55", "50", "Soft??"]'},
        {'id': 'ASG_ROOM26', 'room': 'Room 26', 'boxes': 800, 'trolley': 16, 'teams': '[{"teamColor": "SAPPHIRE", "headcount": 8}]', 'instr': '["Check One Box"]'},
        {'id': 'ASG_ROOM42', 'room': 'Room 42', 'boxes': 1000, 'trolley': 16, 'teams': '[{"teamColor": "RUBY", "headcount": 8}]', 'instr': '["55", "30", "Keep moving bigger one from T/A"]'},
        {'id': 'ASG_ROOM50', 'room': 'Room 50', 'boxes': 1400, 'trolley': 16, 'teams': '[{"teamColor": "JADE", "headcount": 8}, {"teamColor": "AMBER", "headcount": 6}]', 'instr': '["MYCOSENSE INSTRUCTION: 6,1,7"]'},
        {'id': 'ASG_ROOM51', 'room': 'Room 51', 'boxes': 1200, 'trolley': 16, 'teams': '[{"teamColor": "VENUS", "headcount": 8}, {"teamColor": "LIME", "headcount": 8}]', 'instr': '["MYCOSENSE INSTRUCTION: 6,1,7"]'},
        {'id': 'ASG_ROOM52', 'room': 'Room 52', 'boxes': 600, 'trolley': 8, 'teams': '[{"teamColor": "BLACK", "headcount": 8}]', 'instr': '["MYCOSENSE INSTRUCTION: 5,7"]'},
        {'id': 'ASG_ROOM63', 'room': 'Room 63', 'boxes': 200, 'trolley': 0, 'teams': '[{"teamColor": "PEACH", "headcount": 8}]', 'instr': '["Clumps (WASH TROLLEYS)"]'},
      ];

      for (final r in roomSeeds) {
        await _db.into(_db.mushroomRoomAssignments).insert(
              MushroomRoomAssignmentsCompanion.insert(
                id: r['id'] as String,
                planId: planId,
                roomId: r['room'] as String,
                boxTarget: d.Value(r['boxes'] as int),
                trolleyCount: d.Value(r['trolley'] as int),
                teamAssignmentsJson: d.Value(r['teams'] as String),
                pickingInstructionsJson: d.Value(r['instr'] as String),
              ),
            );
      }
    }
  }

  Future<void> _loadDailyPlanData() async {
    final plans = await _db.select(_db.mushroomHarvestPlans).get();
    if (plans.isNotEmpty) {
      setState(() {
        _activePlan = plans.first.toJson();
      });
    }
  }

  Future<void> _loadPendingTimesheets() async {
    final tsList = await _db.select(_db.mushroomDailyTimesheets).get();
    final emps = await _repo.getEmployees();

    final mapped = tsList.map((ts) {
      final emp = emps.firstWhere((e) => e['id'] == ts.employeeId, orElse: () => {'name': ts.employeeId, 'role': 'Picker'});
      return {
        'id': ts.id,
        'employeeId': ts.employeeId,
        'name': emp['name'],
        'role': emp['role'],
        'teamColor': ts.assignedTeamColor ?? 'Purple',
        'checkInTime': ts.checkInTime,
        'checkOutTime': ts.checkOutTime,
        'totalBreakTaken': ts.totalBreakTakenMinutes,
        'standardBreakAllowed': ts.standardBreakAllowedMinutes,
        'extraBreak': ts.extraBreakMinutes,
        'grossWorked': ts.grossWorkedMinutes,
        'paidMinutes': ts.paidMinutes,
        'status': ts.status,
        'rooms': ts.assignedRoomsJson != null ? jsonDecode(ts.assignedRoomsJson!) : [],
      };
    }).toList();

    setState(() {
      _pendingTimesheets = mapped;
    });
  }

  // --- Check-In Trigger ---
  Future<void> _processCheckIn(String idCode) async {
    final cleanCode = idCode.trim().toUpperCase();
    final employees = await _repo.getEmployees();
    final match = employees.where((e) => e['id']?.toString().toUpperCase() == cleanCode);

    if (match.isEmpty) {
      _showErrorSnackBar('Employee ID not found: $cleanCode');
      return;
    }

    final emp = match.first;

    // Check team assignments in PickerTeams or employee's pickerTeamColor
    final planId = _activePlan?['id'] ?? 'PLAN_20260724';
    final teams = await _db.select(_db.mushroomPickerTeams).get();
    String detectedTeam = emp['pickerTeamColor'] ?? 'PURPLE';

    for (var t in teams) {
      if (t.memberIdsJson != null) {
        final List ids = jsonDecode(t.memberIdsJson!);
        if (ids.contains(cleanCode)) {
          detectedTeam = t.colorCode;
          break;
        }
      }
    }

    // Query room assignments for this team from SQLite
    final assignments = await (_db.select(_db.mushroomRoomAssignments)
          ..where((t) => t.planId.equals(planId)))
        .get();

    List<Map<String, dynamic>> myRooms = assignments.where((a) {
      if (a.teamAssignmentsJson != null) {
        final List list = jsonDecode(a.teamAssignmentsJson!);
        return list.any((item) => (item['teamColor'] as String).toUpperCase() == detectedTeam.toUpperCase());
      }
      return false;
    }).map((a) {
      final List instrs = a.pickingInstructionsJson != null ? jsonDecode(a.pickingInstructionsJson!) : [];
      return {
        'roomName': a.roomId.replaceAll('room_', 'Room '),
        'instructions': instrs,
        'boxTarget': a.boxTarget,
        'trolleyCount': a.trolleyCount,
      };
    }).toList();

    // Fallback if no specific room is assigned to team yet
    if (myRooms.isEmpty) {
      myRooms = [
        {
          'roomName': 'Room 24',
          'boxTarget': 600,
          'trolleyCount': 16,
          'instructions': ['55', '50', 'Soft??'],
        },
        {
          'roomName': 'Room 50',
          'boxTarget': 1400,
          'trolleyCount': 16,
          'instructions': ['MYCOSENSE INSTRUCTION: 6,1,7'],
        },
      ];
    }

    setState(() {
      _scannedEmployeeId = cleanCode;
      _scannedEmployeeName = emp['name'];
      _scannedEmployeeRole = emp['role'] ?? 'Senior Picker';
      _scannedTeamColor = detectedTeam;
      _checkInTime = DateTime.now();
      _assignedRooms = myRooms;
      _activeTabIndex = 1; // Go to Tab 2 (Reveal screen)
    });

    // Record check in event
    await _db.into(_db.mushroomAttendanceEvents).insert(
          MushroomAttendanceEventsCompanion.insert(
            id: 'AE_${DateTime.now().millisecondsSinceEpoch}',
            employeeId: cleanCode,
            planId: d.Value(planId),
            eventType: 'CHECK_IN',
            timestamp: d.Value(_checkInTime!),
            source: 'QR',
          ),
        );
  }

  // --- Start Shift ---
  void _startShiftClock() {
    _isOnBreak = false;
    _accumulatedBreakMinutes = 0;
    _workedDuration = Duration.zero;

    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _checkInTime != null && !_isOnBreak) {
        setState(() {
          _workedDuration = DateTime.now().difference(_checkInTime!);
        });
      }
    });

    setState(() {
      _activeTabIndex = 2; // Active shift screen
    });
  }

  // --- Toggle Break ---
  Future<void> _toggleBreak() async {
    final now = DateTime.now();
    final planId = _activePlan?['id'] ?? 'PLAN_DEMO_TODAY';

    if (!_isOnBreak) {
      // Start break
      setState(() {
        _isOnBreak = true;
        _breakStartTime = now;
      });

      await _db.into(_db.mushroomAttendanceEvents).insert(
            MushroomAttendanceEventsCompanion.insert(
              id: 'AE_${now.millisecondsSinceEpoch}',
              employeeId: _scannedEmployeeId!,
              planId: d.Value(planId),
              eventType: 'BREAK_START',
              timestamp: d.Value(now),
              source: 'MANUAL',
            ),
          );
    } else {
      // End break
      if (_breakStartTime != null) {
        final diff = now.difference(_breakStartTime!).inMinutes;
        _accumulatedBreakMinutes += diff;
      }
      setState(() {
        _isOnBreak = false;
        _breakStartTime = null;
      });

      await _db.into(_db.mushroomAttendanceEvents).insert(
            MushroomAttendanceEventsCompanion.insert(
              id: 'AE_${now.millisecondsSinceEpoch}',
              employeeId: _scannedEmployeeId!,
              planId: d.Value(planId),
              eventType: 'BREAK_END',
              timestamp: d.Value(now),
              source: 'MANUAL',
            ),
          );
    }
  }

  // --- Check-Out Trigger ---
  Future<void> _processCheckOut() async {
    _shiftTimer?.cancel();
    _checkOutTime = DateTime.now();
    final planId = _activePlan?['id'] ?? 'PLAN_DEMO_TODAY';

    // Record check out event
    await _db.into(_db.mushroomAttendanceEvents).insert(
          MushroomAttendanceEventsCompanion.insert(
            id: 'AE_${DateTime.now().millisecondsSinceEpoch}',
            employeeId: _scannedEmployeeId!,
            planId: d.Value(planId),
            eventType: 'CHECK_OUT',
            timestamp: d.Value(_checkOutTime!),
            source: 'MANUAL',
          ),
        );

    // Calculate timesheet details
    final grossMinutes = _checkOutTime!.difference(_checkInTime!).inMinutes;
    const stdAllowed = 25; // standard break allowed
    final extraBreak = _accumulatedBreakMinutes > stdAllowed
        ? (_accumulatedBreakMinutes - stdAllowed)
        : 0;

    // paidMinutes = gross - stdAllowed - extraBreak
    final paidMinutes = grossMinutes - stdAllowed - extraBreak;

    final tsId = 'TS_${_scannedEmployeeId}_${DateTime.now().millisecondsSinceEpoch}';

    // Insert Timesheet
    await _db.into(_db.mushroomDailyTimesheets).insert(
          MushroomDailyTimesheetsCompanion.insert(
            id: tsId,
            employeeId: _scannedEmployeeId!,
            planDate: DateTime.now(),
            checkInTime: d.Value(_checkInTime),
            checkOutTime: d.Value(_checkOutTime),
            totalBreakTakenMinutes: d.Value(_accumulatedBreakMinutes),
            standardBreakAllowedMinutes: const d.Value(stdAllowed),
            extraBreakMinutes: d.Value(extraBreak),
            grossWorkedMinutes: d.Value(grossMinutes),
            paidMinutes: d.Value(paidMinutes),
            assignedTeamColor: d.Value(_scannedTeamColor),
            assignedRoomsJson: d.Value(jsonEncode(_assignedRooms.map((r) => r['roomName']).toList())),
            status: d.Value(extraBreak > 0 ? 'needs_review' : 'normal'),
          ),
        );

    await _loadPendingTimesheets();

    setState(() {
      _activeTabIndex = 3; // Go to Tab 4 (Check-out summary)
    });
  }

  // --- Manager Review Actions ---
  Future<void> _approveTimesheet(String timesheetId, int extraBreak, int gross, int std, double baseHourlyRate) async {
    final paidMinutes = gross - std - extraBreak;
    final totalHours = paidMinutes / 60.0;
    final basePay = totalHours * baseHourlyRate;

    // 1. Update Timesheet status to normal
    await (_db.update(_db.mushroomDailyTimesheets)
          ..where((t) => t.id.equals(timesheetId)))
        .write(MushroomDailyTimesheetsCompanion(
          status: const d.Value('normal'),
          paidMinutes: d.Value(paidMinutes),
          extraBreakMinutes: d.Value(extraBreak),
        ));

    final ts = await (_db.select(_db.mushroomDailyTimesheets)
          ..where((t) => t.id.equals(timesheetId)))
        .getSingle();

    // 2. Generate Payroll Calculation
    await _db.into(_db.mushroomPayrollCalculations).insert(
          MushroomPayrollCalculationsCompanion.insert(
            id: 'PAY_${ts.employeeId}_${DateTime.now().millisecondsSinceEpoch}',
            employeeId: ts.employeeId,
            payPeriod: '2026-W30',
            totalPaidHours: d.Value(totalHours),
            basePay: d.Value(basePay),
            totalPay: d.Value(basePay),
          ),
        );

    await _loadPendingTimesheets();
    _showSuccessSnackBar('Timesheet approved and locked successfully!');
  }

  Future<void> _adjustTimesheetManually(Map<String, dynamic> ts) async {
    final TextEditingController checkinCtrl = TextEditingController(
        text: ts['checkInTime'] != null
            ? (ts['checkInTime'] as DateTime).toIso8601String().substring(11, 16)
            : '07:30');
    final TextEditingController checkoutCtrl = TextEditingController(
        text: ts['checkOutTime'] != null
            ? (ts['checkOutTime'] as DateTime).toIso8601String().substring(11, 16)
            : '16:00');
    final TextEditingController breakCtrl =
        TextEditingController(text: ts['totalBreakTaken'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Timesheet: ${ts['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: checkinCtrl,
              decoration: const InputDecoration(labelText: 'Check-In Time (HH:MM)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: checkoutCtrl,
              decoration: const InputDecoration(labelText: 'Check-Out Time (HH:MM)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: breakCtrl,
              decoration: const InputDecoration(labelText: 'Total Break Taken (Minutes)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
            onPressed: () async {
              final inTimeStr = checkinCtrl.text.split(':');
              final outTimeStr = checkoutCtrl.text.split(':');
              final newBreak = int.tryParse(breakCtrl.text) ?? 25;

              final today = DateTime.now();
              final checkIn = DateTime(today.year, today.month, today.day,
                  int.parse(inTimeStr[0]), int.parse(inTimeStr[1]));
              final checkOut = DateTime(today.year, today.month, today.day,
                  int.parse(outTimeStr[0]), int.parse(outTimeStr[1]));

              final gross = checkOut.difference(checkIn).inMinutes;
              const std = 25;
              final extra = newBreak > std ? (newBreak - std) : 0;
              final paid = gross - std - extra;

              await (_db.update(_db.mushroomDailyTimesheets)
                    ..where((t) => t.id.equals(ts['id'])))
                  .write(MushroomDailyTimesheetsCompanion(
                    checkInTime: d.Value(checkIn),
                    checkOutTime: d.Value(checkOut),
                    totalBreakTakenMinutes: d.Value(newBreak),
                    extraBreakMinutes: d.Value(extra),
                    grossWorkedMinutes: d.Value(gross),
                    paidMinutes: d.Value(paid),
                    status: const d.Value('normal'),
                  ));

              final totalHours = paid / 60.0;
              final basePay = totalHours * 28.5; // Demo wage rate

              await _db.into(_db.mushroomPayrollCalculations).insert(
                    MushroomPayrollCalculationsCompanion.insert(
                      id: 'PAY_${ts['employeeId']}_${DateTime.now().millisecondsSinceEpoch}',
                      employeeId: ts['employeeId'],
                      payPeriod: '2026-W30',
                      totalPaidHours: d.Value(totalHours),
                      basePay: d.Value(basePay),
                      totalPay: d.Value(basePay),
                    ),
                  );

              await _loadPendingTimesheets();
              if (ctx.mounted) Navigator.pop(ctx);
              _showSuccessSnackBar('Timesheet adjusted manually and payroll recorded!');
            },
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Manager Harvest Plan Builder Dialog ---
  void _showHarvestPlanBuilderDialog(BuildContext context) {
    final TextEditingController roomCtrl = TextEditingController(text: 'Room 50');
    final TextEditingController boxCtrl = TextEditingController(text: '1400');
    final TextEditingController trolleyCtrl = TextEditingController(text: '16');
    final TextEditingController instructionsCtrl = TextEditingController(text: 'MYCOSENSE INSTRUCTION: 6,1,7');
    String selectedTeam = 'JADE';
    int selectedFlush = 1;

    final List<Map<String, dynamic>> draftAssignments = [
      {'room': 'Room 3', 'flush': 1, 'boxes': 1000, 'trolley': 16, 'team': 'IVORY & PEARL', 'instr': 'CLUMPS (WASH TROLLEYS)'},
      {'room': 'Room 24', 'flush': 2, 'boxes': 600, 'trolley': 16, 'team': 'PURPLE', 'instr': '55, 50, Soft??'},
      {'room': 'Room 26', 'flush': 2, 'boxes': 800, 'trolley': 16, 'team': 'SAPPHIRE', 'instr': 'Check One Box'},
      {'room': 'Room 42', 'flush': 2, 'boxes': 1000, 'trolley': 16, 'team': 'RUBY', 'instr': '55, 30, Keep moving bigger one from T/A'},
      {'room': 'Room 50', 'flush': 1, 'boxes': 1400, 'trolley': 16, 'team': 'JADE & AMBER', 'instr': 'MYCOSENSE INSTRUCTION: 6,1,7'},
      {'room': 'Room 51', 'flush': 1, 'boxes': 1200, 'trolley': 16, 'team': 'VENUS & LIME', 'instr': 'MYCOSENSE INSTRUCTION: 6,1,7'},
      {'room': 'Room 52', 'flush': 1, 'boxes': 600, 'trolley': 8, 'team': 'BLACK', 'instr': 'MYCOSENSE INSTRUCTION: 5,7'},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_calendar_rounded, color: FarmColors.forestGreen),
                SizedBox(width: 8),
                Text('Lập Plan Thu Hoạch Chi Tiết (Manager)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cấu hình danh sách Room & chỉ tiêu hái trong ngày (24/07/2026)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // Add New Room Assignment Form
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('THÊM ROOM VÀO PLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FarmColors.forestGreenText)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: roomCtrl,
                                  decoration: const InputDecoration(labelText: 'Tên Room (e.g. Room 50)', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  value: selectedFlush,
                                  decoration: const InputDecoration(labelText: 'Flush', isDense: true),
                                  items: const [
                                    DropdownMenuItem(value: 1, child: Text('Flush 1')),
                                    DropdownMenuItem(value: 2, child: Text('Flush 2')),
                                    DropdownMenuItem(value: 3, child: Text('Flush 3')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedFlush = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: boxCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Target Boxes', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: trolleyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Số Trolley', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedTeam,
                                  decoration: const InputDecoration(labelText: 'Đội Hái', isDense: true),
                                  items: const [
                                    DropdownMenuItem(value: 'PURPLE', child: Text('PURPLE')),
                                    DropdownMenuItem(value: 'PEARL', child: Text('PEARL')),
                                    DropdownMenuItem(value: 'IVORY', child: Text('IVORY')),
                                    DropdownMenuItem(value: 'JADE', child: Text('JADE')),
                                    DropdownMenuItem(value: 'SAPPHIRE', child: Text('SAPPHIRE')),
                                    DropdownMenuItem(value: 'AMBER', child: Text('AMBER')),
                                    DropdownMenuItem(value: 'RUBY', child: Text('RUBY')),
                                    DropdownMenuItem(value: 'PEACH', child: Text('PEACH')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedTeam = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: instructionsCtrl,
                            decoration: const InputDecoration(labelText: 'Hướng dẫn hái (Ghi chú)', isDense: true),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FarmColors.forestGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () {
                                final rName = roomCtrl.text.trim();
                                final bCount = int.tryParse(boxCtrl.text.trim()) ?? 500;
                                final tCount = int.tryParse(trolleyCtrl.text.trim()) ?? 8;
                                final instr = instructionsCtrl.text.trim();
                                if (rName.isNotEmpty) {
                                  setDialogState(() {
                                    draftAssignments.add({
                                      'room': rName,
                                      'flush': selectedFlush,
                                      'boxes': bCount,
                                      'trolley': tCount,
                                      'team': selectedTeam,
                                      'instr': instr.isNotEmpty ? instr : '—',
                                    });
                                  });
                                }
                              },
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Thêm Room vào Plan', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('DANH SÁCH ROOMS (${draftAssignments.length} Rooms)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.builder(
                        itemCount: draftAssignments.length,
                        itemBuilder: (c, idx) {
                          final item = draftAssignments[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            title: Text('${item['room']} — Flush ${item['flush']} (${item['boxes']} boxes / ${item['trolley']} trolleys)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text('Team: ${item['team']} · Note: ${item['instr']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                              onPressed: () {
                                setDialogState(() {
                                  draftAssignments.removeAt(idx);
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: FarmColors.forestGreen),
                onPressed: () async {
                  final today = DateTime.now();
                  final planId = 'PLAN_${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
                  int totalBoxes = 0;
                  for (final item in draftAssignments) {
                    totalBoxes += item['boxes'] as int;
                  }

                  // Save Harvest Plan to SQLite
                  await _db.into(_db.mushroomHarvestPlans).insertOnConflictUpdate(
                        MushroomHarvestPlansCompanion.insert(
                          id: planId,
                          planDate: today,
                          zoneId: const d.Value('M2'),
                          status: const d.Value('published'),
                          totalTargetBoxes: d.Value(totalBoxes),
                        ),
                      );

                  // Save Room Assignments to SQLite
                  for (final item in draftAssignments) {
                    final cleanRoom = (item['room'] as String).toLowerCase().replaceAll(' ', '_');
                    await _db.into(_db.mushroomRoomAssignments).insertOnConflictUpdate(
                          MushroomRoomAssignmentsCompanion.insert(
                            id: '${planId}_$cleanRoom',
                            planId: planId,
                            roomId: item['room'] as String,
                            boxTarget: d.Value(item['boxes'] as int),
                            trolleyCount: d.Value(item['trolley'] as int),
                            teamAssignmentsJson: d.Value(jsonEncode([
                              {'teamColor': item['team'], 'headcount': 8}
                            ])),
                            pickingInstructionsJson: d.Value(jsonEncode([item['instr']])),
                          ),
                        );
                  }

                  await _loadDailyPlanData();
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _showSuccessSnackBar('Đã lưu & xuất bản Harvest Plan ($totalBoxes boxes) thành công vào SQLite!');
                },
                child: const Text('Lưu & Xuất Bản Plan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Feedback notifications ---
  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: FarmColors.forestGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: IZiiColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // Build Methods
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    final Color pageBg = isDark ? IZiiColors.darkBackground : IZiiColors.lightBackground;
    final Color surfaceBg = isDark ? IZiiColors.darkSurface : Colors.white;
    final Color appBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color appBarText = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'iZiiApp — Harvest Portal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: appBarText,
              ),
            ),
            Text(
              'Costa Mushroom · Check-in & Timesheets',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmColors.forestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              elevation: 0,
            ),
            onPressed: () => _showHarvestPlanBuilderDialog(context),
            icon: const Icon(Icons.edit_calendar_rounded, size: 14),
            label: const Text('Lập Plan (Manager)', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 12),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: appBarText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Navigation Bar
            Container(
              color: appBarBg,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(0, '1 · Quét QR'),
                    const SizedBox(width: 8),
                    _buildTabButton(1, '2 · Room Target'),
                    const SizedBox(width: 8),
                    _buildTabButton(2, '3 · Ca đang chạy'),
                    const SizedBox(width: 8),
                    _buildTabButton(3, '4 · Check-out'),
                    const SizedBox(width: 8),
                    _buildTabButton(4, '5 · Manager duyệt'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isTablet ? 720 : 480),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInnerScreen(surfaceBg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isActive = _activeTabIndex == index;
    final isDark = widget.isDark;

    final activeBg = FarmColors.forestGreen;
    final inactiveBg = isDark ? Colors.white10 : Colors.grey.shade100;
    final activeText = Colors.white;
    final inactiveText = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeBg : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeText : inactiveText,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInnerScreen(Color cardBg) {
    switch (_activeTabIndex) {
      case 0:
        return _buildQrCheckinScreen();
      case 1:
        return _buildRoomRevealScreen();
      case 2:
        return _buildActiveShiftScreen();
      case 3:
        return _buildCheckoutSummaryScreen();
      case 4:
        return _buildManagerReviewScreen();
      default:
        return _buildQrCheckinScreen();
    }
  }

  // --- TAB 1: QR CHECK-IN SCREEN ---
  Widget _buildQrCheckinScreen() {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HÔM NAY · CA SÁNG',
                  style: TextStyle(
                    fontSize: 11,
                    color: FarmColors.forestGreen,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quét mã QR Check-in',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const Icon(Icons.qr_code_scanner_rounded, color: FarmColors.forestGreen, size: 28),
          ],
        ),
        const SizedBox(height: 18),

        // Real Live Camera QR Frame
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController ??= MobileScannerController(),
                  onDetect: (capture) {
                    if (_isScannerProcessing) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code = barcodes.first.rawValue;
                      if (code != null) {
                        _isScannerProcessing = true;
                        _processCheckIn(code);
                      }
                    }
                  },
                ),
                // Corner outlines overlay
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: BorderPainterWidget(),
                  ),
                ),
                // Running laser scanner line
                const _ScanningLaserLine(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Đưa mã QR nhân viên vào giữa khung hình',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Manual Entry text field to simulate scans
        TextField(
          controller: _manualIdController,
          decoration: InputDecoration(
            labelText: 'Nhập ID Nhân viên (Ví dụ: EMP004 hoặc 305629)',
            labelStyle: const TextStyle(fontSize: 13),
            hintText: 'e.g. EMP004',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: FarmColors.forestGreen, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              _processCheckIn(val.trim());
            }
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FarmColors.forestGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (_manualIdController.text.trim().isNotEmpty) {
              _processCheckIn(_manualIdController.text.trim());
            } else {
              _processCheckIn('EMP004'); // default demo picker
            }
          },
          child: const Text('Xác nhận Check-in ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  // --- TAB 2: ROOM REVEAL SCREEN ---
  Widget _buildRoomRevealScreen() {
    final isDark = widget.isDark;
    final cardBg = isDark ? Colors.white10 : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ID Card Detail
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: FarmColors.forestGreen,
                child: Text(
                  _scannedEmployeeName?.substring(0, 2).toUpperCase() ?? 'PK',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scannedEmployeeName ?? 'Picker Name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${_scannedEmployeeId ?? "EMP004"} · ${_scannedEmployeeRole ?? "Picker"}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FarmColors.forestGreenLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: FarmColors.forestGreen),
                    SizedBox(width: 6),
                    Text('Checked-in',
                        style: TextStyle(
                            fontSize: 11,
                            color: FarmColors.forestGreenText,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Team Color Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _scannedTeamColor?.toLowerCase() == 'pearl'
                  ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
                  : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PHÂN BỔ ĐỘI HÁI (TEAM)',
                style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                '🟪 ${_scannedTeamColor?.toUpperCase() ?? 'PURPLE'} TEAM',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'DANH SÁCH ROOM HÁI HÔM NAY',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),

        // Assigned Rooms List
        _assignedRooms.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const Text('Không có room nào được phân bổ hôm nay'),
              )
            : Column(
                children: _assignedRooms.map((r) {
                  final List instList = r['instructions'] ?? [];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['roomName'] ?? 'Room 24',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: FarmColors.forestGreenLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                instList.join(' · '),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: FarmColors.forestGreenText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${r['boxTarget'] ?? 500} boxes',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FarmColors.forestGreen),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        const SizedBox(height: 12),

        // Attention Alert Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF332A15) : FarmColors.maintenanceOrangeLight,
            border: Border.all(color: FarmColors.maintenanceOrange.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: FarmColors.maintenanceOrange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lưu ý: Nếu Manager điều chỉnh plan giữa ca, danh sách Room sẽ tự động cập nhật.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.amber.shade200 : const Color(0xFF7A5A17), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FarmColors.forestGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _startShiftClock,
          child: const Text('Xác nhận & Bắt đầu ca hái', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  // --- TAB 3: ACTIVE SHIFT SCREEN ---
  Widget _buildActiveShiftScreen() {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room ${(_assignedRooms.isNotEmpty ? _assignedRooms.first['roomName'] : '24').replaceAll('Room', '').trim()} · $_scannedTeamColor Team',
                  style: const TextStyle(fontSize: 11, color: FarmColors.forestGreen, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ca làm việc đang chạy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isOnBreak ? FarmColors.maintenanceOrangeLight : FarmColors.forestGreenLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: _isOnBreak ? FarmColors.maintenanceOrange : FarmColors.forestGreen),
                  const SizedBox(width: 6),
                  Text(
                    _isOnBreak ? 'Đang Break' : 'Đang Hái',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isOnBreak ? FarmColors.maintenanceOrange : FarmColors.forestGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Timer / Shift duration Clock
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text(
                'THỜI GIAN LÀM VIỆC THỰC TẾ',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDuration(_workedDuration),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bắt đầu check-in lúc ${_checkInTime?.toIso8601String().substring(11, 16) ?? "07:42"}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'THỜI GIAN BREAK HÔM NAY',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        _buildSummaryLine('Định mức break cho phép', '25 phút'),
        _buildSummaryLine('Tổng thời gian đã dùng', '$_accumulatedBreakMinutes phút'),
        const SizedBox(height: 24),

        // Toggle Break Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isOnBreak ? FarmColors.forestGreen : (isDark ? Colors.white10 : Colors.grey.shade200),
            foregroundColor: _isOnBreak ? Colors.white : textColor,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _toggleBreak,
          icon: Icon(_isOnBreak ? Icons.play_arrow_rounded : Icons.coffee_rounded, size: 20),
          label: Text(
            _isOnBreak ? 'Kết thúc giờ Break' : 'Bắt đầu giờ Break',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Checkout button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: FarmColors.maintenanceOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _processCheckOut,
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text('Check-out Kết thúc Ca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  // --- TAB 4: CHECK-OUT SUMMARY SCREEN ---
  Widget _buildCheckoutSummaryScreen() {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final int gross = _checkOutTime?.difference(_checkInTime ?? DateTime.now()).inMinutes ?? 508;
    const int std = 25;
    final int extra = _accumulatedBreakMinutes > std ? (_accumulatedBreakMinutes - std) : 0;
    final int paid = gross - std - extra;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_scannedEmployeeName ?? "Marcell"} · EMP004',
                  style: const TextStyle(fontSize: 11, color: FarmColors.forestGreen, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tổng kết ca làm việc',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            const Icon(Icons.fact_check_rounded, color: FarmColors.forestGreen, size: 28),
          ],
        ),
        const SizedBox(height: 18),

        _buildSummaryLine('Giờ Check-in', _checkInTime?.toIso8601String().substring(11, 16) ?? '07:42'),
        _buildSummaryLine('Giờ Check-out', _checkOutTime?.toIso8601String().substring(11, 16) ?? '16:10'),
        _buildSummaryLine('Tổng giờ có mặt tại xưởng', '${gross ~/ 60}h ${gross % 60}p'),
        _buildSummaryLine('Break chuẩn (đã trừ)', '−${std}p'),
        _buildSummaryLine(
          'Extra break (chờ duyệt)',
          '−${extra}p ${extra > 0 ? "⚠" : ""}',
          color: extra > 0 ? FarmColors.maintenanceOrange : textColor,
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Giờ công tính lương tạm tính', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(
              '${paid ~/ 60}h ${paid % 60}p',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FarmColors.forestGreen),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Pending approval Alert
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF332A15) : FarmColors.maintenanceOrangeLight,
            border: Border.all(color: FarmColors.maintenanceOrange.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hourglass_empty_rounded, color: FarmColors.maintenanceOrange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bảng chấm công đang chờ Manager phê duyệt phần Extra Break trước khi chốt vào bảng lương.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.amber.shade200 : const Color(0xFF7A5A17), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FarmColors.forestGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            setState(() {
              // Clear state and return to QR screen
              _scannedEmployeeId = null;
              _scannedEmployeeName = null;
              _scannedEmployeeRole = null;
              _scannedTeamColor = null;
              _checkInTime = null;
              _checkOutTime = null;
              _isScannerProcessing = false;
              _activeTabIndex = 0;
            });
          },
          child: const Text('Hoàn tất Check-out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  // --- TAB 5: MANAGER REVIEW SCREEN ---
  Widget _buildManagerReviewScreen() {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final needsReview = _pendingTimesheets.where((ts) => ts['status'] == 'needs_review').toList();
    final approvedList = _pendingTimesheets.where((ts) => ts['status'] == 'normal').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PHE DUYỆT BẢNG CHẤM CÔNG',
                  style: TextStyle(fontSize: 11, color: FarmColors.forestGreen, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${needsReview.length} Timesheets cần duyệt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FarmColors.forestGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _showHarvestPlanBuilderDialog(context),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                  label: const Text('Lập Plan Thu Hoạch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadPendingTimesheets,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        needsReview.isEmpty && approvedList.isEmpty
            ? Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text('Không có bảng chấm công nào hôm nay'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (needsReview.isNotEmpty) ...[
                    Text(
                      'CẦN XỬ LÝ EXTRA BREAK (${needsReview.length})',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    ...needsReview.map((ts) => _buildReviewCard(ts, true)),
                    const SizedBox(height: 16),
                  ],
                  if (approvedList.isNotEmpty) ...[
                    Text(
                      'ĐÃ DUYỆT / HỢP LỆ (${approvedList.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FarmColors.forestGreen, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    ...approvedList.map((ts) => _buildReviewCard(ts, false)),
                  ],
                ],
              ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> ts, bool isPending) {
    final isDark = widget.isDark;
    final cardBg = isDark ? Colors.white10 : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;

    final int paidMin = ts['paidMinutes'] as int;
    final int gross = ts['grossWorked'] as int;
    final int extra = ts['extraBreak'] as int;
    final int std = ts['standardBreakAllowed'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ts['name'] ?? 'Employee Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ts['teamColor']?.toLowerCase() == 'pearl' ? Colors.blue.shade100 : Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  ts['teamColor']?.toUpperCase() ?? 'PURPLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: ts['teamColor']?.toLowerCase() == 'pearl' ? Colors.blue.shade900 : Colors.purple.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            children: [
              _buildMiniStat('Break chuẩn', '$std phút'),
              _buildMiniStat('Extra break', '$extra phút', isWarn: extra > 0),
              _buildMiniStat('Tổng giờ công', '${paidMin ~/ 60}h ${paidMin % 60}p'),
              _buildMiniStat('Phòng hái', (ts['rooms'] as List).join(', ')),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmColors.forestGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _approveTimesheet(ts['id'] as String, extra, gross, std, 28.5),
                    child: const Text('Duyệt trừ lương', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _adjustTimesheetManually(ts),
                    child: const Text('Điều chỉnh tay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {bool isWarn = false}) {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isWarn ? FarmColors.maintenanceOrange : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String val, {Color? color}) {
    final isDark = widget.isDark;
    final defaultColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? defaultColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}

// Re-usable widget class for scanner corners outline
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
      ..color = FarmColors.forestGreen
      ..strokeWidth = 3
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
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: FarmColors.forestGreen,
                boxShadow: [
                  BoxShadow(
                    color: FarmColors.forestGreen.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
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
