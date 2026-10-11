import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Representation of an object in 3D warehouse space (meters)
class Warehouse3dObject {
  final String id;
  final String code;
  final String name;
  final String type; // warehouse, zone, aisle, rack, level, bin, dock, staging, quarantine
  final String? parentId;
  final String path;
  
  // 3D coordinates (meters)
  final double x;
  final double y;
  final double z;
  
  // Dimensions (meters)
  final double width;  // X span
  final double length; // Y span
  final double height; // Z span
  
  // Operational attributes
  final String status; // active, blocked, maintenance, quarantine
  final bool isStorable;
  final double? maxWeightKg;
  final double? currentWeightKg;
  final int palletCount;
  final int maxPallets;
  final List<String> storedLpns;
  final List<String> storedSkus;
  final Color? customColor;

  const Warehouse3dObject({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    required this.path,
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.length,
    required this.height,
    this.status = 'active',
    this.isStorable = true,
    this.maxWeightKg,
    this.currentWeightKg,
    this.palletCount = 0,
    this.maxPallets = 1,
    this.storedLpns = const [],
    this.storedSkus = const [],
    this.customColor,
  });

  /// Utilization ratio (0.0 to 1.0+)
  double get occupancyRate {
    if (maxPallets <= 0) return 0.0;
    return palletCount / maxPallets;
  }

  /// Heatmap / status color code
  Color get statusColor {
    if (customColor != null) return customColor!;
    if (status == 'blocked') return const Color(0xFFEF4444); // Red
    if (status == 'maintenance') return const Color(0xFFF59E0B); // Amber
    if (type == 'quarantine' || status == 'quarantine') return const Color(0xFF8B5CF6); // Purple
    if (type == 'dock') return const Color(0xFF06B6D4); // Cyan
    if (type == 'staging') return const Color(0xFF3B82F6); // Blue

    // Storable bin occupancy heatmap
    if (!isStorable) return const Color(0xFF64748B); // Slate neutral

    if (palletCount == 0) {
      return const Color(0xFF10B981); // Green - Empty/Available
    } else if (occupancyRate < 1.0) {
      return const Color(0xFFF59E0B); // Amber - Partially occupied
    } else {
      return const Color(0xFFE11D48); // Rose/Red - Full
    }
  }

  Warehouse3dObject copyWith({
    String? id,
    String? code,
    String? name,
    String? type,
    String? parentId,
    String? path,
    double? x,
    double? y,
    double? z,
    double? width,
    double? length,
    double? height,
    String? status,
    bool? isStorable,
    double? maxWeightKg,
    double? currentWeightKg,
    int? palletCount,
    int? maxPallets,
    List<String>? storedLpns,
    List<String>? storedSkus,
    Color? customColor,
  }) {
    return Warehouse3dObject(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      path: path ?? this.path,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      width: width ?? this.width,
      length: length ?? this.length,
      height: height ?? this.height,
      status: status ?? this.status,
      isStorable: isStorable ?? this.isStorable,
      maxWeightKg: maxWeightKg ?? this.maxWeightKg,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      palletCount: palletCount ?? this.palletCount,
      maxPallets: maxPallets ?? this.maxPallets,
      storedLpns: storedLpns ?? this.storedLpns,
      storedSkus: storedSkus ?? this.storedSkus,
      customColor: customColor ?? this.customColor,
    );
  }
}

/// Perspective and transformation utilities for 3D/Isometric warehouse rendering
class IsometricProjection {
  final double zoom;
  final double azimuth; // Camera angle in radians around Z axis (e.g. 45 deg = math.pi/4)
  final double elevation; // Pitch angle in radians (e.g. 30 deg = math.pi/6)
  final Offset panOffset;

  const IsometricProjection({
    this.zoom = 28.0, // Pixels per meter
    this.azimuth = math.pi / 4, // 45 degrees
    this.elevation = math.pi / 6, // 30 degrees
    this.panOffset = Offset.zero,
  });

  /// Projects 3D world coordinates (x, y, z in meters) to 2D screen coordinates
  Offset project(double wx, double wy, double wz, Size canvasSize) {
    // 1. Rotate around Z axis by azimuth
    final cosA = math.cos(azimuth);
    final sinA = math.sin(azimuth);
    final rx = wx * cosA - wy * sinA;
    final ry = wx * sinA + wy * cosA;

    // 2. Project onto screen with elevation pitch
    final cosE = math.cos(elevation);
    final sinE = math.sin(elevation);

    final screenX = rx * zoom + canvasSize.width / 2 + panOffset.dx;
    final screenY = (ry * sinE - wz * cosE) * zoom + canvasSize.height / 2 + panOffset.dy;

    return Offset(screenX, screenY);
  }

  /// Calculates depth score for isometric painters (Painter's algorithm sorting)
  double depth(double wx, double wy, double wz) {
    final sinA = math.sin(azimuth);
    final cosA = math.cos(azimuth);
    final sinE = math.sin(elevation);
    final cosE = math.cos(elevation);

    // Camera view distance vector
    return (wx * sinA + wy * cosA) * cosE + wz * sinE;
  }
}

/// Template structure for creating a new Aisle / Rack in Manager Mode
class AisleTemplateConfig {
  final String zoneCode;
  final String aisleCode;
  final double startX;
  final double startY;
  final int bayCount; // Number of vertical rack columns
  final int levelCount; // Number of vertical shelf levels
  final double bayWidth; // Width per bay (e.g., 2.4m for 2 pallets)
  final double rackDepth; // Depth of rack (e.g., 1.2m for standard Euro pallet)
  final double levelHeight; // Height per level (e.g., 1.8m)
  final double maxWeightPerBinKg;

  const AisleTemplateConfig({
    required this.zoneCode,
    required this.aisleCode,
    required this.startX,
    required this.startY,
    this.bayCount = 4,
    this.levelCount = 3,
    this.bayWidth = 2.4,
    this.rackDepth = 1.2,
    this.levelHeight = 1.8,
    this.maxWeightPerBinKg = 1500.0,
  });
}
