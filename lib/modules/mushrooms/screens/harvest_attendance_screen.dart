// lib/modules/mushrooms/screens/harvest_attendance_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter_animate/flutter_animate.dart';

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
  Future<void> _seedDefaultHarvestData() async {
    final today = DateTime.now();
    final plans = await _db.select(_db.mushroomHarvestPlans).get();
    if (plans.isEmpty) {
      const planId = 'PLAN_DEMO_TODAY';
      // Seed Plan
      await _db.into(_db.mushroomHarvestPlans).insert(
            MushroomHarvestPlansCompanion.insert(
              id: planId,
              planDate: today,
              zoneId: const d.Value('M2'),
              status: const d.Value('published'),
              totalTargetBoxes: const d.Value(800),
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

      // Seed Picker Teams
      await _db.into(_db.mushroomPickerTeams).insert(
            MushroomPickerTeamsCompanion.insert(
              id: 'TEAM_PURPLE',
              planId: planId,
              colorCode: 'Purple',
              headcount: const d.Value(6),
              rateEstimate: const d.Value(28.5),
              memberIdsJson: const d.Value('["EMP001", "305629"]'),
            ),
          );
      await _db.into(_db.mushroomPickerTeams).insert(
            MushroomPickerTeamsCompanion.insert(
              id: 'TEAM_PEARL',
              planId: planId,
              colorCode: 'Pearl',
              headcount: const d.Value(8),
              rateEstimate: const d.Value(31.9),
              memberIdsJson: const d.Value('["EMP004"]'),
            ),
          );

      // Seed Room Assignments
      await _db.into(_db.mushroomRoomAssignments).insert(
            MushroomRoomAssignmentsCompanion.insert(
              id: 'ASG_ROOM24',
              planId: planId,
              roomId: 'room_24',
              boxTarget: const d.Value(600),
              trolleyCount: const d.Value(8),
              teamAssignmentsJson: const d.Value('[{"teamColor": "Purple", "headcount": 6}]'),
              pickingInstructionsJson: const d.Value('["MB", "CB"]'),
              notes: const d.Value('Target priority rooms first'),
            ),
          );
      await _db.into(_db.mushroomRoomAssignments).insert(
            MushroomRoomAssignmentsCompanion.insert(
              id: 'ASG_ROOM61',
              planId: planId,
              roomId: 'room_61',
              boxTarget: const d.Value(200),
              trolleyCount: const d.Value(4),
              teamAssignmentsJson: const d.Value('[{"teamColor": "Purple", "headcount": 6}]'),
              pickingInstructionsJson: const d.Value('["Clumps", "Wash trolleys"]'),
            ),
          );
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

    // Check default team assignments in PickerTeams
    final planId = _activePlan?['id'] ?? 'PLAN_DEMO_TODAY';
    final teams = await _db.select(_db.mushroomPickerTeams).get();
    String detectedTeam = 'Purple';
    for (var t in teams) {
      if (t.memberIdsJson != null) {
        final List ids = jsonDecode(t.memberIdsJson!);
        if (ids.contains(cleanCode)) {
          detectedTeam = t.colorCode;
          break;
        }
      }
    }

    // Query room assignments for this team
    final assignments = await (_db.select(_db.mushroomRoomAssignments)
          ..where((t) => t.planId.equals(planId)))
        .get();

    final myRooms = assignments.where((a) {
      if (a.teamAssignmentsJson != null) {
        final List list = jsonDecode(a.teamAssignmentsJson!);
        return list.any((item) => item['teamColor'] == detectedTeam);
      }
      return false;
    }).map((a) {
      return {
        'roomName': a.roomId.replaceAll('room_', 'Room '),
        'instructions': a.pickingInstructionsJson != null ? jsonDecode(a.pickingInstructionsJson!) : [],
        'boxTarget': a.boxTarget,
      };
    }).toList();

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
            child: const Text('Save Changes'),
          ),
        ],
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // Build Methods
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // Soil-950 Mockup background styling
    final Color topBg = widget.isDark ? const Color(0xFF100E0B) : const Color(0xFF181510);
    final Color cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: topBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A241D),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'iZiiApp — Harvest Portal',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF1F3EA),
                  fontFamily: 'monospace'),
            ),
            Text(
              'Costa Mushroom · Check-in Flow',
              style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade400,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF1F3EA)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Navigation Bar
            Container(
              color: const Color(0xFF2A241D),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(0, '1 · Quét QR'),
                    const SizedBox(width: 8),
                    _buildTabButton(1, '2 · Xác nhận Room'),
                    const SizedBox(width: 8),
                    _buildTabButton(2, '3 · Đang làm việc'),
                    const SizedBox(width: 8),
                    _buildTabButton(3, '4 · Check-out'),
                    const SizedBox(width: 8),
                    _buildTabButton(4, '5 · Manager duyệt'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 380),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3EA), // Sage-50 mockup background color
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: const Color(0xFF100E0B), width: 6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.55),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        color: Colors.white,
                        constraints: const BoxConstraints(minHeight: 560),
                        child: Column(
                          children: [
                            // Mobile Statusbar mock
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _activeTabIndex == 2 ? '11:05' : (_activeTabIndex == 3 ? '16:10' : '07:42'),
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5B5F52)),
                                  ),
                                  const Text(
                                    '●●●●',
                                    style: TextStyle(
                                        color: Color(0xFF5B5F52), fontSize: 10),
                                  )
                                ],
                              ),
                            ),
                            // Inner Page Body based on Tab Index
                            Expanded(
                              child: _buildInnerScreen(cardBg),
                            ),
                          ],
                        ),
                      ),
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3F6B3A) : const Color(0xFF211D17),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF3F6B3A) : const Color(0xFF3A362C),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFA7AC98),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FRIDAY · 24/07/2026',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: Color(0xFF3F6B3A),
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Check-in ca sáng',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E211B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Real Live Camera QR Frame
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181510),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
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
                const SizedBox(height: 18),
                const Text(
                  'Đưa mã QR cá nhân vào khung quét',
                  style: TextStyle(
                      color: Color(0xFF8C9280),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace'),
                ),
                const Spacer(),
                // Manual Entry text field to simulate scans
                TextField(
                  controller: _manualIdController,
                  decoration: const InputDecoration(
                    labelText: 'Manual Entry (Simulate barcode scan)',
                    hintText: 'e.g. EMP004 or 305629',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _processCheckIn(val.trim());
                    }
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE7EBDC),
                    foregroundColor: const Color(0xFF1E211B),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_manualIdController.text.trim().isNotEmpty) {
                      _processCheckIn(_manualIdController.text.trim());
                    } else {
                      _processCheckIn('EMP004'); // default demo picker
                    }
                  },
                  child: const Text('Confirm Employee ID', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: ROOM REVEAL SCREEN ---
  Widget _buildRoomRevealScreen() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID Card Detail
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EBDC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F6B3A),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _scannedEmployeeName?.substring(0, 2).toUpperCase() ?? 'PK',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              _scannedEmployeeRole ?? 'Picker',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF5B5F52),
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE7D6),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Color(0xFF3F6B3A)),
                            SizedBox(width: 4),
                            Text('Checked-in',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF3F6B3A),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Team Color Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _scannedTeamColor?.toLowerCase() == 'pearl'
                          ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                          : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BẠN THUỘC TEAM',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: Colors.white70,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🟪 ${_scannedTeamColor?.toUpperCase() ?? 'PURPLE'}',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'ROOM ĐƯỢC PHÂN BỔ HÔM NAY',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B5F52)),
                ),
                const SizedBox(height: 8),
                // Assigned Rooms List
                Expanded(
                  child: _assignedRooms.isEmpty
                      ? const Center(child: Text('Không có room được phân bổ hôm nay'))
                      : ListView.builder(
                          itemCount: _assignedRooms.length,
                          itemBuilder: (context, idx) {
                            final r = _assignedRooms[idx];
                            final List instList = r['instructions'] ?? [];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F3EA),
                                border: Border.all(color: const Color(0xFFD8DCCC)),
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        instList.join(' · '),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            color: Color(0xFF3F6B3A),
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${r['boxTarget'] ?? 500} boxes',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF5B5F52)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                // Attention Alert Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E9C9),
                    border: Border.all(color: const Color(0xFFE4C578)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📍', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lưu ý: Nếu Manager điều chỉnh plan giữa ca, room phân bổ sẽ tự cập nhật — kiểm tra lại trước khi đổi phòng.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF7A5A17), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Footer bar button
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F6B3A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startShiftClock,
            child: const Text('Đã hiểu, bắt đầu ca',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // --- TAB 3: ACTIVE SHIFT SCREEN ---
  Widget _buildActiveShiftScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Room ${(_assignedRooms.isNotEmpty ? _assignedRooms.first['roomName'] : '24').replaceAll('Room', '').trim()} · $_scannedTeamColor Team',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: Color(0xFF3F6B3A),
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ca đang chạy',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E211B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Timer / Shift duration Clock
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181510),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'THỜI GIAN LÀM VIỆC',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFF8C9280),
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDuration(_workedDuration),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check-in lúc ${_checkInTime?.toIso8601String().substring(11, 16) ?? "07:42"}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFFDCE7D6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'BREAK HÔM NAY',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B5F52)),
                  ),
                ),
                const SizedBox(height: 6),
                _buildSummaryLine('Chuẩn cho phép', '25 phút'),
                _buildSummaryLine('Đã dùng', '$_accumulatedBreakMinutes phút'),
                const Spacer(),
                // Toggle Break Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnBreak ? const Color(0xFF3F6B3A) : const Color(0xFFE7EBDC),
                    foregroundColor: _isOnBreak ? Colors.white : const Color(0xFF1E211B),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _toggleBreak,
                  child: Text(
                    _isOnBreak ? '☕ Kết thúc Break' : '☕ Bắt đầu Break',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        // Checkout bar button
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC97A3D),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _processCheckOut,
            child: const Text('Check-out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // --- TAB 4: CHECK-OUT SUMMARY SCREEN ---
  Widget _buildCheckoutSummaryScreen() {
    final int gross = _checkOutTime?.difference(_checkInTime ?? DateTime.now()).inMinutes ?? 508;
    const int std = 25;
    final int extra = _accumulatedBreakMinutes > std ? (_accumulatedBreakMinutes - std) : 0;
    final int paid = gross - std - extra;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_scannedEmployeeName ?? "Marcell"} · 24/07/2026',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: Color(0xFF3F6B3A),
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tổng kết ca',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E211B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildSummaryLine('Check-in', _checkInTime?.toIso8601String().substring(11, 16) ?? '07:42'),
                _buildSummaryLine('Check-out', _checkOutTime?.toIso8601String().substring(11, 16) ?? '16:10'),
                _buildSummaryLine('Tổng giờ tại xưởng', '${gross ~/ 60}h ${gross % 60}p'),
                _buildSummaryLine('Break chuẩn (đã trừ)', '−${std}p'),
                _buildSummaryLine(
                  'Extra break (chờ duyệt)',
                  '−${extra}p ${extra > 0 ? "⚠" : ""}',
                  color: extra > 0 ? const Color(0xFFC97A3D) : Colors.black87,
                ),
                const SizedBox(height: 10),
                Divider(color: Colors.grey.shade400, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Giờ công tạm tính',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${paid ~/ 60}h ${paid % 60}p',
                      style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F6B3A)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Pending approval Alert
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E9C9),
                    border: Border.all(color: const Color(0xFFE4C578)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⏳', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang chờ Manager duyệt phần extra break trước khi chốt vào bảng lương.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF7A5A17), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Footer check-out completion
        Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F6B3A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
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
            child: const Text('Hoàn tất Check-out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // --- TAB 5: MANAGER REVIEW SCREEN ---
  Widget _buildManagerReviewScreen() {
    final needsReview = _pendingTimesheets.where((ts) => ts['status'] == 'needs_review').toList();
    final approvedList = _pendingTimesheets.where((ts) => ts['status'] == 'normal').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TIMESHEETS REVIEW · 24/07/2026',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F6B3A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${needsReview.length} timesheets cần duyệt',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E211B)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadPendingTimesheets,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: needsReview.isEmpty && approvedList.isEmpty
                ? const Center(child: Text('Không có timesheets nào hôm nay'))
                : ListView(
                    children: [
                      if (needsReview.isNotEmpty) ...[
                        const Text(
                          'CẦN DUYỆT (CHỜ XỬ LÝ EXTRA BREAK)',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              color: Color(0xFF5B5F52),
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        ...needsReview.map((ts) => _buildReviewCard(ts, true)),
                        const SizedBox(height: 16),
                      ],
                      if (approvedList.isNotEmpty) ...[
                        const Text(
                          'ĐÃ DUYỆT / HỢP LỆ (LOCKED)',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              color: Color(0xFF3F6B3A),
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        ...approvedList.map((ts) => _buildReviewCard(ts, false)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> ts, bool isPending) {
    final int paidMin = ts['paidMinutes'] as int;
    final int gross = ts['grossWorked'] as int;
    final int extra = ts['extraBreak'] as int;
    final int std = ts['standardBreakAllowed'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3EA),
        border: Border.all(color: const Color(0xFFD8DCCC)),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ts['teamColor']?.toLowerCase() == 'pearl'
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  ts['teamColor']?.toUpperCase() ?? 'PURPLE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: ts['teamColor']?.toLowerCase() == 'pearl'
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF6B21A8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.3,
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F6B3A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _approveTimesheet(ts['id'] as String, extra, gross, std, 28.5),
                    child: const Text('Duyệt trừ lương', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE7EBDC),
                      foregroundColor: const Color(0xFF1E211B),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _adjustTimesheetManually(ts),
                    child: const Text('Điều chỉnh tay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 9, color: Color(0xFF5B5F52), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: isWarn ? const Color(0xFFC97A3D) : const Color(0xFF1E211B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String val, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5B5F52)),
          ),
          Text(
            val,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
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
      ..color = const Color(0xFFD9A441)
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
                color: const Color(0xFFD9A441),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD9A441).withOpacity(0.5),
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
