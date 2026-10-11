// Models for VDA 5050 AGV / AMR Gateway & Fast Roll-Door Interlock
// Part of Phase 3, Sprint 9 (Industrial WMS & Logistics Automation)

class AgvNodePosition {
  final double x;
  final double y;
  final double z;
  final double theta;
  final String mapId;

  const AgvNodePosition({
    required this.x,
    required this.y,
    this.z = 0.0,
    this.theta = 0.0,
    this.mapId = 'COSTA-WH1-PLANT',
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'theta': theta,
        'mapId': mapId,
      };

  factory AgvNodePosition.fromJson(Map<String, dynamic> json) => AgvNodePosition(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        z: (json['z'] as num?)?.toDouble() ?? 0.0,
        theta: (json['theta'] as num?)?.toDouble() ?? 0.0,
        mapId: json['mapId'] as String? ?? 'COSTA-WH1-PLANT',
      );
}

class VdaAction {
  final String actionId;
  final String actionType; // 'pick', 'drop', 'door_interlock_open', 'door_interlock_close', 'charge', 'wait'
  final String blockingType; // 'HARD', 'SOFT', 'NONE'
  final Map<String, dynamic>? actionParameters;

  const VdaAction({
    required this.actionId,
    required this.actionType,
    this.blockingType = 'HARD',
    this.actionParameters,
  });

  Map<String, dynamic> toJson() => {
        'actionId': actionId,
        'actionType': actionType,
        'blockingType': blockingType,
        'actionParameters': actionParameters,
      };
}

class VdaNode {
  final String nodeId;
  final int sequenceId;
  final bool released;
  final AgvNodePosition nodePosition;
  final List<VdaAction> actions;

  const VdaNode({
    required this.nodeId,
    required this.sequenceId,
    this.released = true,
    required this.nodePosition,
    this.actions = const [],
  });

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'sequenceId': sequenceId,
        'released': released,
        'nodePosition': nodePosition.toJson(),
        'actions': actions.map((a) => a.toJson()).toList(),
      };
}

class VdaEdge {
  final String edgeId;
  final int sequenceId;
  final bool released;
  final String startNodeId;
  final String endNodeId;
  final double maxSpeed; // m/s

  const VdaEdge({
    required this.edgeId,
    required this.sequenceId,
    this.released = true,
    required this.startNodeId,
    required this.endNodeId,
    this.maxSpeed = 1.8,
  });

  Map<String, dynamic> toJson() => {
        'edgeId': edgeId,
        'sequenceId': sequenceId,
        'released': released,
        'startNodeId': startNodeId,
        'endNodeId': endNodeId,
        'maxSpeed': maxSpeed,
      };
}

class VdaOrder {
  final int headerId;
  final String timestamp;
  final String version;
  final String manufacturer;
  final String serialNumber;
  final String orderId;
  final int orderUpdateId;
  final String zone;
  final List<VdaNode> nodes;
  final List<VdaEdge> edges;

  const VdaOrder({
    this.headerId = 1,
    required this.timestamp,
    this.version = '2.0.0',
    this.manufacturer = 'CostaAutomation',
    required this.serialNumber,
    required this.orderId,
    this.orderUpdateId = 0,
    this.zone = 'WH1',
    required this.nodes,
    required this.edges,
  });

  Map<String, dynamic> toJson() => {
        'headerId': headerId,
        'timestamp': timestamp,
        'version': version,
        'manufacturer': manufacturer,
        'serialNumber': serialNumber,
        'orderId': orderId,
        'orderUpdateId': orderUpdateId,
        'zone': zone,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };
}

class AgvVehicleState {
  final String serialNumber;
  final String manufacturer;
  final String model;
  final String operatingMode; // 'AUTOMATIC', 'MANUAL', 'SEMIAUTOMATIC'
  final double batteryCharge; // 0-100%
  final double batteryHealth;
  final bool isCharging;
  final AgvNodePosition position;
  final bool driving;
  final String? currentOrderId;
  final String lastNodeId;
  final List<String> loadedLpns;
  final String connectionState; // 'ONLINE', 'OFFLINE'
  final DateTime lastSeenAt;

  const AgvVehicleState({
    required this.serialNumber,
    required this.manufacturer,
    required this.model,
    required this.operatingMode,
    required this.batteryCharge,
    this.batteryHealth = 99.0,
    this.isCharging = false,
    required this.position,
    required this.driving,
    this.currentOrderId,
    required this.lastNodeId,
    this.loadedLpns = const [],
    this.connectionState = 'ONLINE',
    required this.lastSeenAt,
  });

  AgvVehicleState copyWith({
    String? operatingMode,
    double? batteryCharge,
    AgvNodePosition? position,
    bool? driving,
    String? currentOrderId,
    String? lastNodeId,
    List<String>? loadedLpns,
    DateTime? lastSeenAt,
  }) {
    return AgvVehicleState(
      serialNumber: serialNumber,
      manufacturer: manufacturer,
      model: model,
      operatingMode: operatingMode ?? this.operatingMode,
      batteryCharge: batteryCharge ?? this.batteryCharge,
      batteryHealth: batteryHealth,
      isCharging: isCharging,
      position: position ?? this.position,
      driving: driving ?? this.driving,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      lastNodeId: lastNodeId ?? this.lastNodeId,
      loadedLpns: loadedLpns ?? this.loadedLpns,
      connectionState: connectionState,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'serialNumber': serialNumber,
        'manufacturer': manufacturer,
        'model': model,
        'operatingMode': operatingMode,
        'batteryState': {
          'batteryCharge': batteryCharge,
          'batteryHealth': batteryHealth,
          'charging': isCharging,
        },
        'agvPosition': position.toJson(),
        'driving': driving,
        'currentOrderId': currentOrderId,
        'lastNodeId': lastNodeId,
        'loads': loadedLpns.map((lpn) => {'loadId': lpn, 'loadType': 'pallet'}).toList(),
        'connectionState': connectionState,
        'lastSeenAt': lastSeenAt.toIso8601String(),
      };
}

class FastRollDoorInterlock {
  final String id;
  final String name;
  final String locationCode;
  final String status; // 'open', 'closed', 'opening', 'closing', 'interlocked_holding'
  final String relayDeviceId;
  final double proximityRadiusMeters;
  final int autoCloseDelaySec;
  final DateTime? lastTriggeredAt;
  final List<String> authorizedVehicles;

  const FastRollDoorInterlock({
    required this.id,
    required this.name,
    required this.locationCode,
    required this.status,
    required this.relayDeviceId,
    this.proximityRadiusMeters = 4.5,
    this.autoCloseDelaySec = 5,
    this.lastTriggeredAt,
    this.authorizedVehicles = const [],
  });

  FastRollDoorInterlock copyWith({
    String? status,
    DateTime? lastTriggeredAt,
  }) {
    return FastRollDoorInterlock(
      id: id,
      name: name,
      locationCode: locationCode,
      status: status ?? this.status,
      relayDeviceId: relayDeviceId,
      proximityRadiusMeters: proximityRadiusMeters,
      autoCloseDelaySec: autoCloseDelaySec,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      authorizedVehicles: authorizedVehicles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locationCode': locationCode,
        'status': status,
        'relayDeviceId': relayDeviceId,
        'proximityRadiusMeters': proximityRadiusMeters,
        'autoCloseDelaySec': autoCloseDelaySec,
        'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
        'authorizedVehicles': authorizedVehicles,
      };
}

class FatStageResult {
  final int stageNumber;
  final String name;
  final String standard;
  final bool passed;
  final String metrics;
  final DateTime completedAt;

  const FatStageResult({
    required this.stageNumber,
    required this.name,
    required this.standard,
    required this.passed,
    required this.metrics,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'stageNumber': stageNumber,
        'name': name,
        'standard': standard,
        'passed': passed,
        'metrics': metrics,
        'completedAt': completedAt.toIso8601String(),
      };
}

class FatCommissioningReport {
  final String reportId;
  final String plantLocation;
  final DateTime testedAt;
  final String overallResult; // 'PASSED_COMMISSIONED', 'FAILED'
  final List<String> complianceStandards;
  final int totalStages;
  final int passedStages;
  final int concurrentMobileTerminals;
  final int offlineMutationsQueued;
  final String syncConflictRate;
  final double meanLatencyMs;
  final List<FatStageResult> stages;

  const FatCommissioningReport({
    required this.reportId,
    required this.plantLocation,
    required this.testedAt,
    required this.overallResult,
    required this.complianceStandards,
    required this.totalStages,
    required this.passedStages,
    this.concurrentMobileTerminals = 50,
    this.offlineMutationsQueued = 1500,
    this.syncConflictRate = '0.00%',
    this.meanLatencyMs = 32.4,
    required this.stages,
  });

  bool get isSuccessful => overallResult == 'PASSED_COMMISSIONED' && passedStages == totalStages;

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'plantLocation': plantLocation,
        'testedAt': testedAt.toIso8601String(),
        'overallResult': overallResult,
        'complianceStandards': complianceStandards,
        'totalStages': totalStages,
        'passedStages': passedStages,
        'stressTestMetrics': {
          'concurrentMobileTerminals': concurrentMobileTerminals,
          'offlineMutationsQueued': offlineMutationsQueued,
          'syncConflictRate': syncConflictRate,
          'meanLatencyMs': meanLatencyMs,
        },
        'stages': stages.map((s) => s.toJson()).toList(),
      };
}
