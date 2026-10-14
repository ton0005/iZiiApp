import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../models/cold_chain_pod_models.dart';
import '../services/cold_chain_telemetry_service.dart';

/// Screen for In-Transit Cold-Chain Telemetry monitoring, BLE logger beacons,
/// real-time excursion audio-visual alerts, and Haynes MKT calculation.
class ColdChainTelemetryScreen extends StatefulWidget {
  const ColdChainTelemetryScreen({super.key});

  @override
  State<ColdChainTelemetryScreen> createState() => _ColdChainTelemetryScreenState();
}

class _ColdChainTelemetryScreenState extends State<ColdChainTelemetryScreen> {
  late ColdChainTelemetryService _telemetryService;
  StreamSubscription? _telemetrySub;
  StreamSubscription? _alarmSub;

  final String _vehiclePlate = 'VIC-REEFER-882';
  final String _trailerId = 'TRL-COLD-04';
  final String _loggerDeviceId = 'BLE-LOGGER-TM402';
  final String _loggerName = 'Elitech LogEt 1 BLE (Cold Reefer)';
  final double _batteryLevel = 94.0;

  ColdChainTripSummary? _trip;
  bool _isAlarmDismissed = false;

  @override
  void initState() {
    super.initState();
    _telemetryService = ColdChainTelemetryService(AppDatabase());
    _initTrip();

    _telemetrySub = _telemetryService.telemetryStream.listen((reading) {
      if (mounted) {
        setState(() {
          _trip = _telemetryService.activeTrip;
        });
      }
    });

    _alarmSub = _telemetryService.alarmStream.listen((alarmMsg) {
      if (mounted) {
        setState(() {
          _isAlarmDismissed = false;
        });
        _showAlarmBanner(alarmMsg);
      }
    });
  }

  Future<void> _initTrip() async {
    await _telemetryService.startTrip(
      tripId: 'TRIP-20261005-001',
      deliveryId: 'DELIV-MEL-WOOLWORTHS-01',
      vehiclePlate: _vehiclePlate,
      trailerId: _trailerId,
      loggerDeviceId: _loggerDeviceId,
      loggerName: _loggerName,
      batteryLevel: _batteryLevel,
    );

    // Seed realistic initial readings along cold-chain route (Melbourne -> Mulgrave DC)
    final baseTime = DateTime.now().subtract(const Duration(minutes: 60));
    final initialTemps = [2.6, 2.7, 2.9, 3.1, 2.8, 3.0, 2.9, 2.8, 3.2, 3.0, 2.9, 2.8];
    for (int i = 0; i < initialTemps.length; i++) {
      await _telemetryService.recordReading(
        temperatureC: initialTemps[i],
        humidityPct: 92.0 + (i % 3),
        batteryPct: _batteryLevel,
        timestamp: baseTime.add(Duration(minutes: i * 5)),
        rssi: -65 - (i % 8),
      );
    }

    if (mounted) {
      setState(() {
        _trip = _telemetryService.activeTrip;
      });
    }
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _alarmSub?.cancel();
    super.dispose();
  }

  void _showAlarmBanner(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateReading(double tempC, {String? label}) async {
    await _telemetryService.recordReading(
      temperatureC: tempC,
      humidityPct: 91.5,
      batteryPct: _batteryLevel,
      locationLat: -37.8136,
      locationLng: 144.9631,
      rssi: -68,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Temperature reading recorded: ${tempC.toStringAsFixed(1)}°C ${label != null ? "($label)" : ""}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showComplianceCertificateDialog() {
    if (_trip == null) return;
    final cert = _telemetryService.generateComplianceCertificate(_trip!);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'In-Transit Cold Chain Compliance Certificate',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _trip!.isCompliant ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _trip!.isCompliant ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _trip!.isCompliant ? Icons.check_circle : Icons.error,
                        color: _trip!.isCompliant ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _trip!.isCompliant
                              ? 'COLD CHAIN COMPLIANT (HACCP FRESH PRODUCE)'
                              : 'NON-COMPLIANT - TEMPERATURE EXCURSION DETECTED!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _trip!.isCompliant ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCertRow('Certificate Number:', cert['certificate_number'] as String),
                _buildCertRow('Vehicle Plate:', cert['vehicle_plate'] as String),
                _buildCertRow('Reefer Trailer ID:', cert['trailer_id'] as String),
                _buildCertRow('BLE Logger Device:', cert['logger_device_id'] as String),
                _buildCertRow('Target Control Range:', cert['target_safe_range'] as String),
                const Divider(),
                _buildCertRow('Minimum Temperature:', '${cert['min_temp_c']}°C'),
                _buildCertRow('Maximum Temperature:', '${cert['max_temp_c']}°C'),
                _buildCertRow('Average Temperature:', '${cert['avg_temp_c']}°C'),
                _buildCertRow('Mean Kinetic Temp (MKT):', '${cert['mean_kinetic_temperature_c']}°C', isBold: true),
                _buildCertRow('Total Readings:', '${cert['total_readings']} samples'),
                _buildCertRow('Excursions Detected:', '${cert['excursions_detected']} samples'),
                _buildCertRow('Total Excursion Duration:', '${cert['total_excursion_minutes']} min'),
                const Divider(),
                _buildCertRow('Regulatory Standard:', cert['regulation_standard'] as String),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/warehouse/pod');
            },
            icon: const Icon(Icons.assignment_turned_in),
            label: const Text('Proceed to Sign e-PoD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isBold ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final currentTemp = trip != null && trip.readings.isNotEmpty
        ? trip.readings.last.temperatureC
        : 2.8;
    final isAlarm = currentTemp > ColdChainTelemetryService.maxSafeTempC ||
        currentTemp < ColdChainTelemetryService.minSafeTempC;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'In-Transit Cold Chain Reefer Telemetry',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: isAlarm ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Cold Chain Compliance Certificate',
            onPressed: _showComplianceCertificateDialog,
          ),
          IconButton(
            icon: const Icon(Icons.assignment_turned_in),
            tooltip: 'Navigate to e-PoD Sign-off',
            onPressed: () => context.push('/warehouse/pod'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alarm banner if active
            if (isAlarm && !_isAlarmDismissed)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emergency, color: Color(0xFFDC2626), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTemp > 5.0
                                ? 'CRITICAL TEMPERATURE EXCURSION (+${currentTemp.toStringAsFixed(1)}°C > 5.0°C)'
                                : 'CRITICAL FREEZE WARNING (${currentTemp.toStringAsFixed(1)}°C < 0.0°C)',
                            style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Cabin alert triggered! Inspect reefer cooling relay or trailer door immediately.',
                            style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF991B1B)),
                      onPressed: () => setState(() => _isAlarmDismissed = true),
                    ),
                  ],
                ),
              ),

            // Logger Connection & Pre-Trip Health Card
            _buildDeviceStatusCard(),

            const SizedBox(height: 16),

            // Primary Temperature Display
            _buildTemperatureGaugeCard(currentTemp, isAlarm),

            const SizedBox(height: 16),

            // Time-Series Graph (Safety Corridor: 0°C - 5°C)
            _buildTemperatureGraphCard(),

            const SizedBox(height: 16),

            // Haynes MKT & Journey Statistics
            _buildMktStatisticsCard(),

            const SizedBox(height: 16),

            // Simulation & Test Panel
            _buildSimulationPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    final batteryPassed = _batteryLevel > ColdChainTelemetryService.minBatteryPreTripThreshold;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth_connected, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loggerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Device: $_loggerDeviceId | Vehicle: $_vehiclePlate | Trailer: $_trailerId',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sensors, size: 14, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'BLE Online',
                        style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Battery level
                Row(
                  children: [
                    Icon(
                      batteryPassed ? Icons.battery_charging_full : Icons.battery_alert,
                      color: batteryPassed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Battery: ${_batteryLevel.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: batteryPassed ? const Color(0xFF0F172A) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                // Pre-trip check requirement (Risk #4)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: batteryPassed ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: batteryPassed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    batteryPassed ? 'Pre-Trip Check: PASSED (> 20%)' : 'Pre-Trip Check: FAILED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: batteryPassed ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureGaugeCard(double currentTemp, bool isAlarm) {
    final statusColor = isAlarm
        ? const Color(0xFFEF4444)
        : (currentTemp >= 2.0 && currentTemp <= 4.0
            ? const Color(0xFF10B981)
            : const Color(0xFF3B82F6));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isAlarm
                ? [const Color(0xFFFFF1F2), const Color(0xFFFEE2E2)]
                : [const Color(0xFFF0FDF4), const Color(0xFFE0F2FE)],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CURRENT REEFER TEMPERATURE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Color(0xFF475569),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAlarm
                        ? (currentTemp > 5.0 ? 'OUT OF SAFE RANGE' : 'LOCALIZED FREEZING')
                        : 'OPTIMAL SAFE ZONE',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currentTemp.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '°C',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Fresh Produce Control Corridor: 0.0°C – 5.0°C (Optimal: 2.0°C – 4.0°C)',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureGraphCard() {
    final readings = _trip?.readings ?? [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'In-Transit Temperature Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Row(
                  children: [
                    Container(width: 10, height: 10, color: const Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    const Text('Safe Range (0-5°C)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Container(width: 10, height: 10, color: const Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    const Text('> 5°C', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _TemperatureChartPainter(
                  readings: readings,
                  maxThreshold: ColdChainTelemetryService.maxSafeTempC,
                  minThreshold: ColdChainTelemetryService.minSafeTempC,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMktStatisticsCard() {
    final trip = _trip;
    final minT = trip?.minTempC ?? 0.0;
    final maxT = trip?.maxTempC ?? 0.0;
    final avgT = trip?.avgTempC ?? 0.0;
    final mkt = trip?.meanKineticTemperatureC ?? 0.0;
    final excursionMins = trip?.totalExcursionMinutes ?? 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calculate, color: Color(0xFF1E3A8A), size: 20),
                SizedBox(width: 8),
                Text(
                  'Thermodynamic Statistics & MKT (Haynes)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem('Minimum', '${minT.toStringAsFixed(1)}°C', Colors.blue),
                _buildStatItem('Average', '${avgT.toStringAsFixed(1)}°C', const Color(0xFF0F172A)),
                _buildStatItem('Maximum', '${maxT.toStringAsFixed(1)}°C', maxT > 5.0 ? Colors.red : Colors.green),
                _buildStatItem('MKT (Haynes)', '${mkt.toStringAsFixed(1)}°C', const Color(0xFF1E3A8A), isHighlight: true),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total excursion time (>5°C): $excursionMins min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: excursionMins > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
                Text(
                  'Total samples: ${trip?.totalReadings ?? 0}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: isHighlight ? Border.all(color: const Color(0xFF3B82F6), width: 1) : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationPanel() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'In-Transit Cold Chain Sensor Simulation Panel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _simulateReading(2.8, label: 'Optimal'),
                  icon: const Icon(Icons.check, color: Color(0xFF10B981), size: 18),
                  label: const Text('2.8°C (Nominal)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _simulateReading(4.5, label: 'Marginal'),
                  icon: const Icon(Icons.north_east, color: Colors.amber, size: 18),
                  label: const Text('4.5°C (Upper Limit)'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _simulateReading(7.2, label: 'Door Open - Alarm'),
                  icon: const Icon(Icons.warning, color: Colors.white, size: 18),
                  label: const Text('+7.2°C (Excursion)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _simulateReading(-1.2, label: 'Freezing - Alarm'),
                  icon: const Icon(Icons.ac_unit, color: Colors.white, size: 18),
                  label: const Text('-1.2°C (Freeze)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/warehouse/pod'),
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text('Arrive at Destination & Sign e-PoD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering time-series temperature graph with safety corridor.
class _TemperatureChartPainter extends CustomPainter {
  final List<ColdChainTelemetryReading> readings;
  final double maxThreshold;
  final double minThreshold;

  _TemperatureChartPainter({
    required this.readings,
    required this.maxThreshold,
    required this.minThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paintGrid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    final paintSafeCorridor = Paint()
      ..color = const Color(0xFFDCFCE7).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final paintThresholdHigh = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final paintThresholdLow = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final paintLine = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPointOk = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;

    final paintPointExcursion = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    // Y scale range from -2°C to 10°C
    const yMin = -2.0;
    const yMax = 10.0;
    double toY(double temp) =>
        size.height - ((temp - yMin) / (yMax - yMin) * size.height).clamp(0.0, size.height);

    // Draw safe corridor rectangle (minThreshold to maxThreshold)
    final ySafeTop = toY(maxThreshold);
    final ySafeBottom = toY(minThreshold);
    canvas.drawRect(
      Rect.fromLTRB(0, ySafeTop, size.width, ySafeBottom),
      paintSafeCorridor,
    );

    // Draw threshold lines
    canvas.drawLine(Offset(0, ySafeTop), Offset(size.width, ySafeTop), paintThresholdHigh);
    canvas.drawLine(Offset(0, ySafeBottom), Offset(size.width, ySafeBottom), paintThresholdLow);

    // Draw baseline grid
    canvas.drawLine(Offset(0, toY(0.0)), Offset(size.width, toY(0.0)), paintGrid);

    if (readings.isEmpty) return;

    final path = Path();
    final stepX = readings.length > 1 ? size.width / (readings.length - 1) : size.width;

    for (int i = 0; i < readings.length; i++) {
      final x = i * stepX;
      final y = toY(readings[i].temperatureC);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paintLine);

    // Draw sample dots
    for (int i = 0; i < readings.length; i++) {
      final x = i * stepX;
      final temp = readings[i].temperatureC;
      final y = toY(temp);
      final isExcursion = temp > maxThreshold || temp < minThreshold;
      canvas.drawCircle(Offset(x, y), isExcursion ? 4.5 : 3.0, isExcursion ? paintPointExcursion : paintPointOk);
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) => true;
}
