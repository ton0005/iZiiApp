import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/window_action_service.dart';

/// Chế độ hiển thị màu sắc trên mô hình 3D
enum GrowRoom3dDisplayMode {
  realistic, // Màu thực tế (khung nhôm, đất than bùn, tơ nấm trắng)
  temperature, // Gradient nhiệt độ (Tầng trên ấm hơn tầng dưới)
  moisture, // Trạng thái độ ẩm / tưới nước
  pickingStatus, // Tiến độ thu hoạch theo khoang
}

/// Thông tin xác định vị trí một khoang luống cụ thể
class WindowLocation {
  final int rackIndex; // 0..3 (Phòng lớn) hoặc 0..1 (Phòng nhỏ)
  final int levelIndex; // 0..5 (Tầng 1 đến Tầng 6)
  final int windowIndex; // 0..8 (Window 1 đến Window 9)

  const WindowLocation({
    required this.rackIndex,
    required this.levelIndex,
    required this.windowIndex,
  });

  String get rackLabel => 'Rack ${rackIndex + 1}';
  String get levelLabel => 'Level ${levelIndex + 1}';
  String get windowLabel => 'Window ${windowIndex + 1}';
  String get code => 'R${rackIndex + 1}-L${levelIndex + 1}-W${windowIndex + 1}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowLocation &&
          runtimeType == other.runtimeType &&
          rackIndex == other.rackIndex &&
          levelIndex == other.levelIndex &&
          windowIndex == other.windowIndex;

  @override
  int get hashCode => Object.hash(rackIndex, levelIndex, windowIndex);
}

/// Điểm 3D trong hệ tọa độ không gian thực tế (mét)
class Point3D {
  final double x; // Chiều ngang (Racks / Aisles)
  final double y; // Chiều cao (0..6.0m)
  final double z; // Chiều dài (0..27.0m)

  const Point3D(this.x, this.y, this.z);

  Point3D operator +(Point3D o) => Point3D(x + o.x, y + o.y, z + o.z);
  Point3D operator -(Point3D o) => Point3D(x - o.x, y - o.y, z - o.z);
}

/// Đa giác 3D với màu sắc và thông tin tương tác
class Polygon3D {
  final List<Point3D> vertices;
  final Color baseColor;
  final WindowLocation? windowLocation;
  final bool isHighlight;
  final bool isSelected;
  final bool hasAlarm;
  final String? alarmCategory;
  final bool isFrame; // Viền khung kim loại
  final String? label;
  final double? normalY; // Dùng để tính góc phản chiếu ánh sáng

  Polygon3D({
    required this.vertices,
    required this.baseColor,
    this.windowLocation,
    this.isHighlight = false,
    this.isSelected = false,
    this.hasAlarm = false,
    this.alarmCategory,
    this.isFrame = false,
    this.label,
    this.normalY,
  });
}

/// CustomPainter vẽ phối cảnh 3D phòng trồng nấm
class GrowRoom3dPainter extends CustomPainter {
  final bool isLargeRoom; // true = 4 Rack, false = 2 Rack
  final double yaw; // Góc quay ngang (radians)
  final double pitch; // Góc quay đứng (radians)
  final double zoom; // Hệ số phóng to
  final Offset panOffset; // Độ dịch chuyển tâm nhìn
  final GrowRoom3dDisplayMode displayMode;
  final int? isolatedLevel; // null = xem tất cả, 1..6 = cô lập xem 1 tầng
  final int? isolatedRack; // null = xem tất cả, 1..4 = cô lập xem 1 rack
  final WindowLocation? selectedWindow;
  final WindowLocation? hoveredWindow;
  final Map<String, WindowIssueReport>? activeIssues;
  final bool showRoomShell; // Bật tắt vỏ tường/trần phòng
  final bool showDimensions; // Bật tắt thước đo kích thước 6m, 27m, 1.2m
  final bool isDark;

  // Callback để truyền lại danh sách đa giác phục vụ việc bắt sự kiện Click / Tap
  final Function(List<TransformedPolygon>)? onRenderPolygons;

  GrowRoom3dPainter({
    required this.isLargeRoom,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.panOffset,
    required this.displayMode,
    this.isolatedLevel,
    this.isolatedRack,
    this.selectedWindow,
    this.hoveredWindow,
    this.activeIssues,
    this.showRoomShell = true,
    this.showDimensions = true,
    this.isDark = true,
    this.onRenderPolygons,
  });

  // Thông số hình học thực tế (mét)
  static const double roomHeight = 6.0; // Cao 6m
  static const double rackLength = 27.0; // Dài 27m
  static const double rackWidth = 1.2; // Rộng 1.2m
  static const int windowCount = 9; // 9 windows
  static const double windowLength = 3.0; // Mỗi window 3m (9 * 3 = 27m)
  static const int levelCount = 6; // 6 levels
  static const double bedDepth = 0.20; // Độ dày luống 20cm

  // Cao độ của 6 tầng luống (tính từ sàn tới mặt luống)
  static const List<double> levelHeights = [
    0.45, // Level 1 (cách sàn 45cm)
    1.15, // Level 2
    1.85, // Level 3
    2.55, // Level 4
    3.25, // Level 5
    3.95, // Level 6
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);

    // Tính toán chiều rộng phòng theo số lượng rack
    // Phòng nhỏ: 2 Rack (1.2m) + Lối đi trái 0.8m + Giữa 1.0m + Phải 0.8m = ~5.0m
    // Phòng lớn: 4 Rack (1.2m) + 3 lối đi giữa (0.9m, 1.0m, 0.9m) + 2 biên 0.8m = ~9.2m
    final double roomWidth = isLargeRoom ? 9.2 : 5.0;
    const double roomLength = rackLength + 2.0; // Thêm 1m lối đi 2 đầu phòng = 29.0m

    // Tọa độ tâm phòng (để căn giữa điểm quay)
    final centerRoom = Point3D(roomWidth / 2, roomHeight / 2, roomLength / 2);

    // 1. Khởi tạo danh sách đa giác 3D
    final List<Polygon3D> polygons = [];

    // Vẽ vỏ phòng & vạch thước đo nếu được bật
    if (showRoomShell) {
      _buildRoomShell(polygons, roomWidth, roomLength);
    }

    // Vẽ lưới sàn & thước đo kích thước 6m, 27m
    if (showDimensions) {
      _buildFloorGridAndDimensions(polygons, roomWidth, roomLength);
    }

    // Vẽ Racks, Levels, Windows
    _buildRacks(polygons, roomWidth);

    // Vẽ hệ thống thông gió ở trần (độ cao 5.4m - 5.8m)
    _buildVentilationDuct(polygons, roomWidth, roomLength);

    // 2. Chiếu 3D sang 2D (Projection & Camera Transform)
    final double focalLength = math.min(size.width, size.height) * 1.1 * zoom;
    const double cameraDistance = 38.0; // Khoảng cách camera từ tâm

    final transformedList = <TransformedPolygon>[];

    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);

    for (final poly in polygons) {
      final points2D = <Offset>[];
      double totalDepth = 0.0;
      bool isBehindCamera = false;

      for (final v in poly.vertices) {
        // Chuyển về tọa độ tâm
        final dx = v.x - centerRoom.x;
        final dy = v.y - centerRoom.y;
        final dz = v.z - centerRoom.z;

        // Xoay quanh trục Y (Yaw)
        final x1 = dx * cosYaw - dz * sinYaw;
        final z1 = dx * sinYaw + dz * cosYaw;
        final y1 = dy;

        // Xoay quanh trục X (Pitch)
        final y2 = y1 * cosPitch - z1 * sinPitch;
        final z2 = y1 * sinPitch + z1 * cosPitch;
        final x2 = x1;

        // Khoảng cách camera
        final zCam = z2 + cameraDistance;
        if (zCam <= 1.0) {
          isBehindCamera = true;
          break;
        }

        totalDepth += z2;

        // Chiếu phối cảnh
        final screenX = center.dx + (x2 * focalLength) / zCam;
        final screenY = center.dy - (y2 * focalLength) / zCam; // Âm vì trục Y canvas ngược
        points2D.add(Offset(screenX, screenY));
      }

      if (!isBehindCamera && points2D.length >= 2) {
        final avgDepth = totalDepth / poly.vertices.length;
        transformedList.add(TransformedPolygon(
          poly: poly,
          points: points2D,
          depth: avgDepth,
        ));
      }
    }

    // 3. Sắp xếp chiều sâu (Painter's Algorithm: vẽ từ xa tới gần)
    transformedList.sort((a, b) => a.depth.compareTo(b.depth));

    // Truyền lại cho widget cha để phục vụ bắt sự kiện click
    onRenderPolygons?.call(transformedList);

    // 4. Vẽ lên Canvas
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final tp in transformedList) {
      final poly = tp.poly;
      final path = Path();
      path.moveTo(tp.points[0].dx, tp.points[0].dy);
      for (int i = 1; i < tp.points.length; i++) {
        path.lineTo(tp.points[i].dx, tp.points[i].dy);
      }
      path.close();

      // Tính màu sắc và độ bóng theo ánh sáng
      Color renderColor = poly.baseColor;
      if (poly.isSelected) {
        renderColor = const Color(0xFFFFD54F); // Vàng rực rỡ khi được chọn
      } else if (poly.hasAlarm) {
        // Cảnh báo sự cố ô trồng: Đỏ mận cho Disease, Cam sáng cho Safety/Maintenance
        renderColor = poly.alarmCategory == 'disease'
            ? const Color(0xFFE11D48)
            : const Color(0xFFEA580C);
      } else if (poly.isHighlight) {
        renderColor = Colors.cyanAccent.withValues(alpha: 0.85); // Cyan khi hover
      }

      fillPaint.color = renderColor;
      canvas.drawPath(path, fillPaint);

      // Vẽ viền khung
      if (poly.isSelected) {
        strokePaint.color = Colors.amberAccent;
        strokePaint.strokeWidth = 2.5;
        canvas.drawPath(path, strokePaint);
      } else if (poly.hasAlarm) {
        strokePaint.color = poly.alarmCategory == 'disease'
            ? Colors.redAccent
            : Colors.amberAccent;
        strokePaint.strokeWidth = 2.2;
        canvas.drawPath(path, strokePaint);
      } else if (poly.isHighlight) {
        strokePaint.color = Colors.cyanAccent;
        strokePaint.strokeWidth = 2.0;
        canvas.drawPath(path, strokePaint);
      } else if (poly.isFrame) {
        strokePaint.color = isDark ? Colors.white24 : Colors.black26;
        strokePaint.strokeWidth = 0.8;
        canvas.drawPath(path, strokePaint);
      } else {
        strokePaint.color = isDark ? Colors.black38 : Colors.white24;
        strokePaint.strokeWidth = 0.5;
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  // --- XÂY DỰNG HÌNH HỌC VỎ PHÒNG & THƯỚC ĐO ---
  void _buildRoomShell(List<Polygon3D> polygons, double roomWidth, double roomLength) {
    final double wallAlpha = isDark ? 0.25 : 0.35;
    final wallColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: wallAlpha)
        : const Color(0xFFE2E8F0).withValues(alpha: wallAlpha);

    // Sàn phòng (Floor)
    polygons.add(Polygon3D(
      vertices: [
        const Point3D(0, 0, 0),
        Point3D(roomWidth, 0, 0),
        Point3D(roomWidth, 0, roomLength),
        Point3D(0, 0, roomLength),
      ],
      baseColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      isFrame: true,
    ));

    // Tường sau (Back wall z = roomLength)
    polygons.add(Polygon3D(
      vertices: [
        Point3D(0, 0, roomLength),
        Point3D(roomWidth, 0, roomLength),
        Point3D(roomWidth, roomHeight, roomLength),
        Point3D(0, roomHeight, roomLength),
      ],
      baseColor: wallColor,
      isFrame: true,
    ));

    // Tường trái (Left wall x = 0)
    polygons.add(Polygon3D(
      vertices: [
        const Point3D(0, 0, 0),
        Point3D(0, 0, roomLength),
        Point3D(0, roomHeight, roomLength),
        const Point3D(0, roomHeight, 0),
      ],
      baseColor: wallColor.withValues(alpha: wallAlpha * 0.5),
      isFrame: true,
    ));
  }

  void _buildFloorGridAndDimensions(List<Polygon3D> polygons, double roomWidth, double roomLength) {
    // Vạch chia mét dọc theo chiều dài (0..27m)
    final gridLineColor = isDark
        ? Colors.blueGrey.withValues(alpha: 0.15)
        : Colors.blueGrey.withValues(alpha: 0.2);

    for (int w = 0; w <= windowCount; w++) {
      final zPos = 1.0 + w * windowLength;
      polygons.add(Polygon3D(
        vertices: [
          Point3D(0, 0.01, zPos),
          Point3D(roomWidth, 0.01, zPos),
          Point3D(roomWidth, 0.01, zPos + 0.05),
          Point3D(0, 0.01, zPos + 0.05),
        ],
        baseColor: gridLineColor,
        isFrame: false,
      ));
    }
  }

  // --- XÂY DỰNG RACKS, TẦNG (LEVELS), VÀ WINDOWS ---
  void _buildRacks(List<Polygon3D> polygons, double roomWidth) {
    final int rackTotal = isLargeRoom ? 4 : 2;

    // Xác định tọa độ X của từng Rack
    final List<double> rackXOffsets = [];
    if (isLargeRoom) {
      // 4 Racks bố trí đều trên 9.2m chiều rộng
      // R1: 0.8m -> 2.0m
      // R2: 2.9m -> 4.1m
      // R3: 5.1m -> 6.3m
      // R4: 7.2m -> 8.4m
      rackXOffsets.addAll([0.8, 2.9, 5.1, 7.2]);
    } else {
      // 2 Racks bố trí trên 5.0m
      // R1: 0.8m -> 2.0m
      // R2: 3.0m -> 4.2m
      rackXOffsets.addAll([0.8, 3.0]);
    }

    const zStart = 1.0; // Cách mép phòng 1.0m làm lối đi đầu hồi

    for (int r = 0; r < rackTotal; r++) {
      if (isolatedRack != null && (r + 1) != isolatedRack) {
        continue; // Bỏ qua rack không thuộc bộ lọc cô lập
      }

      final rx = rackXOffsets[r];

      // 1. Cột trụ chịu lực kim loại tại các khớp Window (0, 3, 6, 9... 27m)
      _buildRackPosts(polygons, rx, zStart);

      // 2. Dựng 6 Tầng (Levels)
      for (int l = 0; l < levelCount; l++) {
        if (isolatedLevel != null && (l + 1) != isolatedLevel) {
          continue; // Bỏ qua tầng không thuộc bộ lọc cô lập
        }

        final ly = levelHeights[l];

        // 3. Dựng 9 Window trên mỗi tầng (mỗi window dài 3m)
        for (int w = 0; w < windowCount; w++) {
          final wzStart = zStart + w * windowLength;
          final wzEnd = wzStart + windowLength;

          final winLoc = WindowLocation(rackIndex: r, levelIndex: l, windowIndex: w);
          final isSelected = selectedWindow == winLoc;
          final isHovered = hoveredWindow == winLoc;
          final issue = activeIssues?[winLoc.code];
          final hasAlarm = issue != null;
          final alarmCategory = issue?.category.name;

          final bedColor = _determineBedColor(l, w, isSelected, isHovered);

          // Mặt trên luống nấm (Casing Soil + Mycelium)
          polygons.add(Polygon3D(
            vertices: [
              Point3D(rx, ly + bedDepth, wzStart),
              Point3D(rx + rackWidth, ly + bedDepth, wzStart),
              Point3D(rx + rackWidth, ly + bedDepth, wzEnd),
              Point3D(rx, ly + bedDepth, wzEnd),
            ],
            baseColor: bedColor,
            windowLocation: winLoc,
            isSelected: isSelected,
            isHighlight: isHovered,
            hasAlarm: hasAlarm,
            alarmCategory: alarmCategory,
            normalY: 1.0,
          ));

          // Thành luống bên trái (Sideboard Left)
          polygons.add(Polygon3D(
            vertices: [
              Point3D(rx, ly, wzStart),
              Point3D(rx, ly + bedDepth, wzStart),
              Point3D(rx, ly + bedDepth, wzEnd),
              Point3D(rx, ly, wzEnd),
            ],
            baseColor: _shadeColor(bedColor, 0.75),
            windowLocation: winLoc,
            isSelected: isSelected,
            isHighlight: isHovered,
            isFrame: true,
          ));

          // Thành luống bên phải (Sideboard Right)
          polygons.add(Polygon3D(
            vertices: [
              Point3D(rx + rackWidth, ly, wzStart),
              Point3D(rx + rackWidth, ly, wzEnd),
              Point3D(rx + rackWidth, ly + bedDepth, wzEnd),
              Point3D(rx + rackWidth, ly + bedDepth, wzStart),
            ],
            baseColor: _shadeColor(bedColor, 0.85),
            windowLocation: winLoc,
            isSelected: isSelected,
            isHighlight: isHovered,
            isFrame: true,
          ));

          // Đáy giá đỡ kim loại (Metal bed bottom)
          polygons.add(Polygon3D(
            vertices: [
              Point3D(rx, ly, wzStart),
              Point3D(rx + rackWidth, ly, wzStart),
              Point3D(rx + rackWidth, ly, wzEnd),
              Point3D(rx, ly, wzEnd),
            ],
            baseColor: isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8),
            isFrame: true,
          ));
        }
      }
    }
  }

  // Dựng các cột nhôm/thép chịu lực dọc theo rack tại mỗi mốc 3m
  void _buildRackPosts(List<Polygon3D> polygons, double rx, double zStart) {
    final postColor = isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1);
    const postWidth = 0.08;
    final topHeight = levelHeights.last + bedDepth + 0.3; // Vượt qua tầng 6 một chút

    for (int w = 0; w <= windowCount; w++) {
      final pz = zStart + w * windowLength;

      // Cột bên trái
      polygons.add(Polygon3D(
        vertices: [
          Point3D(rx - postWidth, 0, pz),
          Point3D(rx, 0, pz),
          Point3D(rx, topHeight, pz),
          Point3D(rx - postWidth, topHeight, pz),
        ],
        baseColor: postColor,
        isFrame: true,
      ));

      // Cột bên phải
      polygons.add(Polygon3D(
        vertices: [
          Point3D(rx + rackWidth, 0, pz),
          Point3D(rx + rackWidth + postWidth, 0, pz),
          Point3D(rx + rackWidth + postWidth, topHeight, pz),
          Point3D(rx + rackWidth, topHeight, pz),
        ],
        baseColor: postColor,
        isFrame: true,
      ));
    }
  }

  // Ống gió điều hòa không khí ở trần phòng (độ cao 5.5m)
  void _buildVentilationDuct(List<Polygon3D> polygons, double roomWidth, double roomLength) {
    final ductColor = isDark
        ? const Color(0xFF475569).withValues(alpha: 0.6)
        : const Color(0xFF94A3B8).withValues(alpha: 0.7);

    final centerX = roomWidth / 2;
    const ductRadius = 0.35;
    const ductY = 5.4;

    // Mặt đáy ống gió
    polygons.add(Polygon3D(
      vertices: [
        Point3D(centerX - ductRadius, ductY, 1.0),
        Point3D(centerX + ductRadius, ductY, 1.0),
        Point3D(centerX + ductRadius, ductY, roomLength - 1.0),
        Point3D(centerX - ductRadius, ductY, roomLength - 1.0),
      ],
      baseColor: ductColor,
      isFrame: true,
    ));
  }

  // Xác định màu sắc luống dựa theo DisplayMode
  Color _determineBedColor(int level, int window, bool isSelected, bool isHovered) {
    if (isSelected) {
      return const Color(0xFFFFC107);
    }
    if (isHovered) {
      return const Color(0xFF00E5FF);
    }

    switch (displayMode) {
      case GrowRoom3dDisplayMode.realistic:
        // Đất than bùn đen nâu đậm với sắc trắng phủ nhẹ của nấm
        final base = isDark ? const Color(0xFF2C221B) : const Color(0xFF3E2D22);
        // Tầng cao nhận nhiều ánh sáng hơn một chút
        final lightnessFactor = 1.0 + (level * 0.04);
        return _shadeColor(base, lightnessFactor);

      case GrowRoom3dDisplayMode.temperature:
        // Gradient nhiệt độ: Tầng 1 (18°C - xanh dương) -> Tầng 6 (20.5°C - cam/đỏ nhẹ)
        final ratio = level / (levelCount - 1);
        if (ratio < 0.5) {
          return Color.lerp(const Color(0xFF0284C7), const Color(0xFF10B981), ratio * 2)!;
        } else {
          return Color.lerp(const Color(0xFF10B981), const Color(0xFFEF4444), (ratio - 0.5) * 2)!;
        }

      case GrowRoom3dDisplayMode.moisture:
        // Mô phỏng độ ẩm luống: Window giữa ẩm tốt (Xanh lá), rìa ngoài cần tưới (Vàng)
        if (window % 3 == 1) {
          return const Color(0xFF10B981); // Ẩm tốt
        } else if (window % 3 == 0) {
          return const Color(0xFFF59E0B); // Hơi khô
        } else {
          return const Color(0xFF3B82F6); // Vừa mới tưới
        }

      case GrowRoom3dDisplayMode.pickingStatus:
        // Tiến độ thu hoạch: Trống / Chưa hái / Đã hái
        if (level >= 4) {
          return const Color(0xFF10B981); // Đã hái sạch
        } else if (level >= 2) {
          return const Color(0xFFF59E0B); // Đang hái
        } else {
          return const Color(0xFF6366F1); // Chờ hái
        }
    }
  }

  Color _shadeColor(Color color, double factor) {
    return Color.fromARGB(
      (color.a * 255.0).round().clamp(0, 255),
      ((color.r * 255.0) * factor).round().clamp(0, 255),
      ((color.g * 255.0) * factor).round().clamp(0, 255),
      ((color.b * 255.0) * factor).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(covariant GrowRoom3dPainter oldDelegate) {
    return oldDelegate.isLargeRoom != isLargeRoom ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.displayMode != displayMode ||
        oldDelegate.isolatedLevel != isolatedLevel ||
        oldDelegate.isolatedRack != isolatedRack ||
        oldDelegate.selectedWindow != selectedWindow ||
        oldDelegate.hoveredWindow != hoveredWindow ||
        oldDelegate.activeIssues != activeIssues ||
        oldDelegate.showRoomShell != showRoomShell ||
        oldDelegate.showDimensions != showDimensions ||
        oldDelegate.isDark != isDark;
  }
}

/// Đa giác sau khi đã chiếu sang tọa độ 2D màn hình kèm độ sâu để kiểm tra Hit-Test
class TransformedPolygon {
  final Polygon3D poly;
  final List<Offset> points;
  final double depth;

  TransformedPolygon({
    required this.poly,
    required this.points,
    required this.depth,
  });

  /// Kiểm tra một điểm chạm (tap / click) có nằm bên trong đa giác không
  bool containsPoint(Offset tap) {
    if (points.length < 3) return false;
    int crossings = 0;
    for (int i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      if (((a.dy <= tap.dy && tap.dy < b.dy) || (b.dy <= tap.dy && tap.dy < a.dy)) &&
          (tap.dx < (b.dx - a.dx) * (tap.dy - a.dy) / (b.dy - a.dy) + a.dx)) {
        crossings++;
      }
    }
    return crossings % 2 != 0;
  }
}
