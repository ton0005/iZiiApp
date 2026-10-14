// Models for In-Transit Cold-Chain Telemetry & Mobile e-PoD
// Part of Phase 3, Sprint 8 (Industrial WMS & Logistics Automation)

class ColdChainTelemetryReading {
  final String id;
  final String tripId;
  final DateTime timestamp;
  final double temperatureC;
  final double? humidityPct;
  final double? batteryPct;
  final bool isExcursion; // Temperature > 5.0°C or < 0.0°C for fresh mushrooms
  final double? locationLat;
  final double? locationLng;
  final int? rssi;

  const ColdChainTelemetryReading({
    required this.id,
    required this.tripId,
    required this.timestamp,
    required this.temperatureC,
    this.humidityPct,
    this.batteryPct,
    required this.isExcursion,
    this.locationLat,
    this.locationLng,
    this.rssi,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'timestamp': timestamp.toIso8601String(),
        'temperature_c': temperatureC,
        'humidity_pct': humidityPct,
        'battery_pct': batteryPct,
        'is_excursion': isExcursion,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'rssi': rssi,
      };

  factory ColdChainTelemetryReading.fromJson(Map<String, dynamic> json) =>
      ColdChainTelemetryReading(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        temperatureC: (json['temperature_c'] as num).toDouble(),
        humidityPct: (json['humidity_pct'] as num?)?.toDouble(),
        batteryPct: (json['battery_pct'] as num?)?.toDouble(),
        isExcursion: json['is_excursion'] as bool? ?? false,
        locationLat: (json['location_lat'] as num?)?.toDouble(),
        locationLng: (json['location_lng'] as num?)?.toDouble(),
        rssi: json['rssi'] as int?,
      );
}

class ColdChainTripSummary {
  final String tripId;
  final String? deliveryId; // Associated StockPicking ID
  final String vehiclePlate; // e.g. "VIC-REEFER-882"
  final String trailerId; // e.g. "TRL-COLD-04"
  final String loggerDeviceId; // e.g. "BLE-LOGGER-TM402"
  final String loggerName;
  final double batteryLevel; // Pre-trip check requirement > 20%
  final DateTime startTime;
  final DateTime? endTime;
  final double minTempC;
  final double maxTempC;
  final double avgTempC;
  final double meanKineticTemperatureC; // MKT calculated using Haynes equation
  final int totalReadings;
  final int excursionReadings;
  final int totalExcursionMinutes;
  final bool isCompliant; // True if maxTemp <= 5.0°C and minTemp >= 0.0°C
  final bool preTripBatteryCheckPassed; // True if batteryLevel > 20%
  final String status; // 'active', 'alarm_triggered', 'completed', 'verified'
  final List<ColdChainTelemetryReading> readings;

  const ColdChainTripSummary({
    required this.tripId,
    this.deliveryId,
    required this.vehiclePlate,
    required this.trailerId,
    required this.loggerDeviceId,
    required this.loggerName,
    required this.batteryLevel,
    required this.startTime,
    this.endTime,
    required this.minTempC,
    required this.maxTempC,
    required this.avgTempC,
    required this.meanKineticTemperatureC,
    required this.totalReadings,
    required this.excursionReadings,
    required this.totalExcursionMinutes,
    required this.isCompliant,
    required this.preTripBatteryCheckPassed,
    required this.status,
    this.readings = const [],
  });

  ColdChainTripSummary copyWith({
    String? status,
    DateTime? endTime,
    double? minTempC,
    double? maxTempC,
    double? avgTempC,
    double? meanKineticTemperatureC,
    int? totalReadings,
    int? excursionReadings,
    int? totalExcursionMinutes,
    bool? isCompliant,
    List<ColdChainTelemetryReading>? readings,
  }) {
    return ColdChainTripSummary(
      tripId: tripId,
      deliveryId: deliveryId,
      vehiclePlate: vehiclePlate,
      trailerId: trailerId,
      loggerDeviceId: loggerDeviceId,
      loggerName: loggerName,
      batteryLevel: batteryLevel,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      minTempC: minTempC ?? this.minTempC,
      maxTempC: maxTempC ?? this.maxTempC,
      avgTempC: avgTempC ?? this.avgTempC,
      meanKineticTemperatureC:
          meanKineticTemperatureC ?? this.meanKineticTemperatureC,
      totalReadings: totalReadings ?? this.totalReadings,
      excursionReadings: excursionReadings ?? this.excursionReadings,
      totalExcursionMinutes:
          totalExcursionMinutes ?? this.totalExcursionMinutes,
      isCompliant: isCompliant ?? this.isCompliant,
      preTripBatteryCheckPassed: preTripBatteryCheckPassed,
      status: status ?? this.status,
      readings: readings ?? this.readings,
    );
  }

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'delivery_id': deliveryId,
        'vehicle_plate': vehiclePlate,
        'trailer_id': trailerId,
        'logger_device_id': loggerDeviceId,
        'logger_name': loggerName,
        'battery_level': batteryLevel,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'min_temp_c': minTempC,
        'max_temp_c': maxTempC,
        'avg_temp_c': avgTempC,
        'mean_kinetic_temperature_c': meanKineticTemperatureC,
        'total_readings': totalReadings,
        'excursion_readings': excursionReadings,
        'total_excursion_minutes': totalExcursionMinutes,
        'is_compliant': isCompliant,
        'pre_trip_battery_check_passed': preTripBatteryCheckPassed,
        'status': status,
        'readings': readings.map((r) => r.toJson()).toList(),
      };
}

class DeliveryStopItem {
  final String pickingId;
  final String orderCode; // e.g. "SO-2026-0042"
  final String customerName; // e.g. "Woolworths DC Mulgrave"
  final String destinationAddress;
  final String? contactPhone;
  final int palletCount;
  final int cartonCount;
  final double grossWeightKg;
  final List<String> products;
  final String status; // 'assigned', 'staged', 'in_transit', 'delivered'
  final DateTime? scheduledDate;

  const DeliveryStopItem({
    required this.pickingId,
    required this.orderCode,
    required this.customerName,
    required this.destinationAddress,
    this.contactPhone,
    required this.palletCount,
    required this.cartonCount,
    required this.grossWeightKg,
    this.products = const [],
    this.status = 'assigned',
    this.scheduledDate,
  });

  Map<String, dynamic> toJson() => {
        'picking_id': pickingId,
        'order_code': orderCode,
        'customer_name': customerName,
        'destination_address': destinationAddress,
        'contact_phone': contactPhone,
        'pallet_count': palletCount,
        'carton_count': cartonCount,
        'gross_weight_kg': grossWeightKg,
        'products': products,
        'status': status,
        'scheduled_date': scheduledDate?.toIso8601String(),
      };
}

class ProofOfDeliveryRecord {
  final String id;
  final String pickingId;
  final String orderCode;
  final String customerName;
  final String destinationAddress;
  final String recipientName;
  final String? recipientPhone;
  final String? recipientDesignation; // e.g. "Receiving Supervisor"
  final String sealNumber; // Container security seal e.g. "SEAL-AU-89412"
  final bool sealIntact;
  final String? sealPhotoBase64;
  final String? cargoPhotoBase64;
  final List<List<double>>? signatureStrokePoints; // [[x,y], [x,y]...]
  final String? signatureSvg;
  final String? signaturePngBase64;
  final DateTime deliveredAt;
  final double gpsLatitude;
  final double gpsLongitude;
  final double gpsAccuracyMeters;
  final String cryptoHash; // SHA-256 digital stamp
  final ColdChainTripSummary? coldChainCompliance;
  final int cartonCount;
  final int palletCount;
  final double? grossWeightKg;
  final String? notes;
  final String syncStatus; // 'local_confirmed', 'erp_synced'
  final String manifestAuthorizationCode;

  const ProofOfDeliveryRecord({
    required this.id,
    required this.pickingId,
    required this.orderCode,
    required this.customerName,
    required this.destinationAddress,
    required this.recipientName,
    this.recipientPhone,
    this.recipientDesignation,
    required this.sealNumber,
    required this.sealIntact,
    this.sealPhotoBase64,
    this.cargoPhotoBase64,
    this.signatureStrokePoints,
    this.signatureSvg,
    this.signaturePngBase64,
    required this.deliveredAt,
    required this.gpsLatitude,
    required this.gpsLongitude,
    this.gpsAccuracyMeters = 5.0,
    required this.cryptoHash,
    this.coldChainCompliance,
    required this.cartonCount,
    required this.palletCount,
    this.grossWeightKg,
    this.notes,
    this.syncStatus = 'local_confirmed',
    required this.manifestAuthorizationCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'picking_id': pickingId,
        'order_code': orderCode,
        'customer_name': customerName,
        'destination_address': destinationAddress,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'recipient_designation': recipientDesignation,
        'seal_number': sealNumber,
        'seal_intact': sealIntact,
        'seal_photo_base64': sealPhotoBase64,
        'cargo_photo_base64': cargoPhotoBase64,
        'signature_svg': signatureSvg,
        'signature_png_base64': signaturePngBase64,
        'delivered_at': deliveredAt.toIso8601String(),
        'gps_latitude': gpsLatitude,
        'gps_longitude': gpsLongitude,
        'gps_accuracy_meters': gpsAccuracyMeters,
        'crypto_hash': cryptoHash,
        'cold_chain_compliance': coldChainCompliance?.toJson(),
        'carton_count': cartonCount,
        'pallet_count': palletCount,
        'gross_weight_kg': grossWeightKg,
        'notes': notes,
        'sync_status': syncStatus,
        'manifest_authorization_code': manifestAuthorizationCode,
      };
}
