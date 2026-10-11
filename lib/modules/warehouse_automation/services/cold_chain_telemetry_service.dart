import 'dart:async';
import 'dart:math' as math;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../models/cold_chain_pod_models.dart';

/// Service managing in-transit cold-chain Bluetooth Low Energy (BLE)
/// temperature telemetry, MKT calculations, and excursion alerting.
class ColdChainTelemetryService {
  final AppDatabase _db;
  static const double maxSafeTempC = 5.0; // Fresh mushroom critical threshold
  static const double minSafeTempC = 0.0; // Freezing threshold
  static const double minBatteryPreTripThreshold = 20.0; // Pre-trip check (Risk #4)
  static const double deltaHOverR = 10000.0; // Haynes activation energy / gas constant in Kelvin

  final _telemetryStreamController = StreamController<ColdChainTelemetryReading>.broadcast();
  final _alarmStreamController = StreamController<String>.broadcast();

  Stream<ColdChainTelemetryReading> get telemetryStream => _telemetryStreamController.stream;
  Stream<String> get alarmStream => _alarmStreamController.stream;

  ColdChainTripSummary? _activeTrip;
  ColdChainTripSummary? get activeTrip => _activeTrip;

  ColdChainTelemetryService([AppDatabase? db]) : _db = db ?? AppDatabase();

  /// Haynes equation for Mean Kinetic Temperature (MKT)
  /// TK = (dH/R) / (-ln( (1/n) * sum(exp(-dH/R / Ti)) ))
  /// MKT_C = TK - 273.15
  static double calculateMeanKineticTemperature(List<double> temperaturesC) {
    if (temperaturesC.isEmpty) return 0.0;
    if (temperaturesC.length == 1) return temperaturesC.first;

    // Check if all values are identical to avoid numerical precision artifacts
    final first = temperaturesC.first;
    bool allSame = true;
    for (int i = 1; i < temperaturesC.length; i++) {
      if ((temperaturesC[i] - first).abs() > 0.0001) {
        allSame = false;
        break;
      }
    }
    if (allSame) return first;

    double expSum = 0.0;
    for (final t in temperaturesC) {
      final tKelvin = t + 273.15;
      if (tKelvin <= 0) continue;
      expSum += math.exp(-deltaHOverR / tKelvin);
    }

    final n = temperaturesC.length;
    final averageExp = expSum / n;
    if (averageExp <= 0) return temperaturesC.reduce(math.max);

    final tKelvinMkt = deltaHOverR / (-math.log(averageExp));
    final mktC = tKelvinMkt - 273.15;
    return double.parse(mktC.toStringAsFixed(2));
  }

  /// Evaluates pre-trip logger battery check against Risk #4 requirements (> 20%).
  Map<String, dynamic> checkPreTripBattery(double batteryPercentage) {
    final passed = batteryPercentage > minBatteryPreTripThreshold;
    return {
      'passed': passed,
      'batteryLevel': batteryPercentage,
      'threshold': minBatteryPreTripThreshold,
      'message': passed
          ? 'Pin thiết bị đo BLE đạt chuẩn xuất phát (${batteryPercentage.toStringAsFixed(0)}% > ${minBatteryPreTripThreshold.toStringAsFixed(0)}%)'
          : 'CẢNH BÁO PIN YẾU (${batteryPercentage.toStringAsFixed(0)}% <= ${minBatteryPreTripThreshold.toStringAsFixed(0)}%): '
              'Không đủ điều kiện xuất phát. Yêu cầu thay pin hoặc đổi thiết bị ghi nhiệt mới để tránh mất dữ liệu hành trình!',
    };
  }

  /// Initializes a new in-transit monitoring trip for a refrigerated trailer.
  Future<ColdChainTripSummary> startTrip({
    required String tripId,
    String? deliveryId,
    required String vehiclePlate,
    required String trailerId,
    required String loggerDeviceId,
    required String loggerName,
    required double batteryLevel,
    DateTime? startTime,
  }) async {
    final preTripCheck = checkPreTripBattery(batteryLevel);
    final isBatteryOk = preTripCheck['passed'] as bool;

    // Register or update IoT device entry in local database
    final now = startTime ?? DateTime.now();
    try {
      final existingDevice = await (_db.select(_db.iotDevices)
            ..where((tbl) => tbl.devEui.equals(loggerDeviceId)))
          .getSingleOrNull();

      if (existingDevice == null) {
        await _db.into(_db.iotDevices).insert(IotDevicesCompanion.insert(
              id: const Uuid().v4(),
              devEui: loggerDeviceId,
              name: loggerName,
              deviceType: 'temperature',
              codecId: 'ble_reefer_logger_v1',
              locationId: Value(trailerId),
              batteryLevel: Value(batteryLevel),
              lastSeenAt: Value(now),
              status: Value(isBatteryOk ? 'active' : 'faulty'),
            ));
      } else {
        await (_db.update(_db.iotDevices)
              ..where((tbl) => tbl.id.equals(existingDevice.id)))
            .write(IotDevicesCompanion(
          locationId: Value(trailerId),
          batteryLevel: Value(batteryLevel),
          lastSeenAt: Value(now),
        ));
      }
    } catch (_) {
      // Non-blocking in test/memory mode
    }

    _activeTrip = ColdChainTripSummary(
      tripId: tripId,
      deliveryId: deliveryId,
      vehiclePlate: vehiclePlate,
      trailerId: trailerId,
      loggerDeviceId: loggerDeviceId,
      loggerName: loggerName,
      batteryLevel: batteryLevel,
      startTime: now,
      minTempC: 0.0,
      maxTempC: 0.0,
      avgTempC: 0.0,
      meanKineticTemperatureC: 0.0,
      totalReadings: 0,
      excursionReadings: 0,
      totalExcursionMinutes: 0,
      isCompliant: true,
      preTripBatteryCheckPassed: isBatteryOk,
      status: 'active',
      readings: [],
    );

    return _activeTrip!;
  }

  /// Ingests a new temperature reading from BLE logger or telemetry simulator.
  Future<ColdChainTelemetryReading> recordReading({
    required double temperatureC,
    double? humidityPct,
    double? batteryPct,
    double? locationLat,
    double? locationLng,
    int? rssi,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final trip = _activeTrip;
    final tripId = trip?.tripId ?? 'STANDALONE_TELEMETRY';
    final isExcursion = temperatureC > maxSafeTempC || temperatureC < minSafeTempC;

    final reading = ColdChainTelemetryReading(
      id: const Uuid().v4(),
      tripId: tripId,
      timestamp: now,
      temperatureC: temperatureC,
      humidityPct: humidityPct,
      batteryPct: batteryPct,
      isExcursion: isExcursion,
      locationLat: locationLat,
      locationLng: locationLng,
      rssi: rssi,
    );

    // Save reading to Drift SensorReadings table
    try {
      await _db.into(_db.sensorReadings).insert(SensorReadingsCompanion.insert(
            id: reading.id,
            deviceId: trip?.loggerDeviceId ?? 'BLE_LOGGER_01',
            locationId: Value(trip?.trailerId ?? 'REEFER_TRAILER_01'),
            metric: 'temperature',
            value: temperatureC,
            unit: 'C',
            measuredAt: now,
            quality: Value(isExcursion ? 'suspect' : 'ok'),
          ));

      // Also record humidity if available
      if (humidityPct != null) {
        await _db.into(_db.sensorReadings).insert(SensorReadingsCompanion.insert(
              id: const Uuid().v4(),
              deviceId: trip?.loggerDeviceId ?? 'BLE_LOGGER_01',
              locationId: Value(trip?.trailerId ?? 'REEFER_TRAILER_01'),
              metric: 'humidity',
              value: humidityPct,
              unit: '%',
              measuredAt: now,
              quality: const Value('ok'),
            ));
      }
    } catch (_) {
      // Non-blocking
    }

    // Handle excursion alarm
    if (isExcursion) {
      final alertMsg = temperatureC > maxSafeTempC
          ? 'CẢNH BÁO NHIỆT ĐỘ VƯỢT MỨC (+${temperatureC.toStringAsFixed(1)}°C > $maxSafeTempC°C)! Kiểm tra dàn lạnh thùng xe ngay!'
          : 'CẢNH BÁO NHIỆT ĐỘ ĐÓNG BĂNG (${temperatureC.toStringAsFixed(1)}°C < $minSafeTempC°C)! Nguy cơ đông đá hư hỏng nấm!';

      _alarmStreamController.add(alertMsg);

      try {
        await _db.into(_db.automationEvents).insert(AutomationEventsCompanion.insert(
              id: const Uuid().v4(),
              ruleId: 'COLD_CHAIN_REEFER_EXCURSION_ALARM',
              locationId: Value(trip?.trailerId),
              triggeringReadingId: Value(reading.id),
              triggeringValue: Value(temperatureC),
              status: const Value('failed'),
              resultRecordType: const Value('stock_pickings'),
              resultRecordId: Value(trip?.deliveryId),
              errorMessage: Value(alertMsg),
              acknowledgedAt: Value(DateTime.now()),
            ));

        SyncService().queueMutation('automation_events', 'insert', {
          'rule_id': 'COLD_CHAIN_REEFER_EXCURSION_ALARM',
          'trailer_id': trip?.trailerId,
          'temperature_c': temperatureC,
          'trip_id': tripId,
          'timestamp': now.toIso8601String(),
        });
      } catch (_) {}
    }

    // Update active trip metrics
    if (trip != null) {
      final updatedReadings = List<ColdChainTelemetryReading>.from(trip.readings)..add(reading);
      final temps = updatedReadings.map((r) => r.temperatureC).toList();
      final minTemp = temps.reduce(math.min);
      final maxTemp = temps.reduce(math.max);
      final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
      final mkt = calculateMeanKineticTemperature(temps);
      final excursionCount = updatedReadings.where((r) => r.isExcursion).length;
      // Approximate excursion minutes assuming 1 reading / 5 mins (or delta time)
      final excursionMins = excursionCount * 5;
      final isCompliant = maxTemp <= maxSafeTempC && minTemp >= minSafeTempC;

      _activeTrip = trip.copyWith(
        minTempC: double.parse(minTemp.toStringAsFixed(2)),
        maxTempC: double.parse(maxTemp.toStringAsFixed(2)),
        avgTempC: double.parse(avgTemp.toStringAsFixed(2)),
        meanKineticTemperatureC: mkt,
        totalReadings: updatedReadings.length,
        excursionReadings: excursionCount,
        totalExcursionMinutes: excursionMins,
        isCompliant: isCompliant,
        status: isExcursion ? 'alarm_triggered' : (trip.status == 'alarm_triggered' ? 'alarm_triggered' : 'active'),
        readings: updatedReadings,
      );
    }

    _telemetryStreamController.add(reading);
    return reading;
  }

  /// Finalizes the trip upon reaching customer distribution centre.
  ColdChainTripSummary completeTrip() {
    final trip = _activeTrip;
    if (trip == null) {
      throw StateError('No active cold-chain trip to complete.');
    }

    final finalizedTrip = trip.copyWith(
      status: trip.isCompliant ? 'verified' : 'completed_with_excursions',
      endTime: DateTime.now(),
    );

    _activeTrip = finalizedTrip;
    return finalizedTrip;
  }

  /// Generates a compliance certification object for delivery manifest embedding.
  Map<String, dynamic> generateComplianceCertificate(ColdChainTripSummary trip) {
    return {
      'certificate_number': 'CERT-CC-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${trip.tripId.substring(0, math.min(6, trip.tripId.length)).toUpperCase()}',
      'vehicle_plate': trip.vehiclePlate,
      'trailer_id': trip.trailerId,
      'logger_device_id': trip.loggerDeviceId,
      'start_time': trip.startTime.toIso8601String(),
      'end_time': (trip.endTime ?? DateTime.now()).toIso8601String(),
      'total_duration_hours': ((trip.endTime ?? DateTime.now()).difference(trip.startTime).inMinutes / 60.0).toStringAsFixed(1),
      'min_temp_c': trip.minTempC,
      'max_temp_c': trip.maxTempC,
      'avg_temp_c': trip.avgTempC,
      'mean_kinetic_temperature_c': trip.meanKineticTemperatureC,
      'target_safe_range': '$minSafeTempC°C to $maxSafeTempC°C',
      'total_readings': trip.totalReadings,
      'excursions_detected': trip.excursionReadings,
      'total_excursion_minutes': trip.totalExcursionMinutes,
      'compliance_status': trip.isCompliant ? 'PASSED_COMPLIANT' : 'REJECTED_EXCURSION',
      'regulation_standard': 'HACCP & Fresh Produce Cold Chain Standard (Australia) & USP <1151>',
      'verified_at': DateTime.now().toIso8601String(),
    };
  }

  void dispose() {
    _telemetryStreamController.close();
    _alarmStreamController.close();
  }
}
