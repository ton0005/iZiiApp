import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widgets/grow_room_3d_painter.dart';
import '../repository.dart';
import '../services/window_action_service.dart';
import '../services/plant_room_service.dart';

/// Màn hình tương tác 3D mô hình phòng nuôi trồng nấm (Grow Room 3D Model)
/// Tuân thủ quy cách thực tế:
/// - Chiều cao phòng: 6 mét
/// - Phòng lớn: 4 Rack, mỗi rack 6 Level, dài 27 mét, rộng 1.2 mét, gồm 9 windows (3 mét/window)
/// - Phòng nhỏ: 2 Rack, mỗi rack 6 Level, dài 27 mét, rộng 1.2 mét, gồm 9 windows (3 mét/window)
class GrowRoom3dScreen extends StatefulWidget {
  final String? initialRoomName;
  final bool? initialIsLargeRoom;
  final String? initialSelectedWindowCode; // e.g. "R2-L3-W5"

  const GrowRoom3dScreen({
    super.key,
    this.initialRoomName,
    this.initialIsLargeRoom,
    this.initialSelectedWindowCode,
  });

  @override
  State<GrowRoom3dScreen> createState() => _GrowRoom3dScreenState();
}

class _GrowRoom3dScreenState extends State<GrowRoom3dScreen>
    with SingleTickerProviderStateMixin {
  // Trạng thái phòng
  late bool _isLargeRoom;
  String? _selectedRoomName;
  List<Map<String, dynamic>> _dbRooms = [];

  // Trạng thái sự cố / cảnh báo ô luống
  final WindowActionService _actionService = WindowActionService();
  Map<String, WindowIssueReport> _activeIssues = {};
  StreamSubscription<List<WindowIssueReport>>? _issuesSubscription;

  // Trạng thái Camera 3D
  double _yaw = 0.58; // Góc quay ngang (~33 độ)
  double _pitch = 0.38; // Góc quay đứng (~22 độ)
  double _zoom = 1.15; // Phóng to mặc định
  Offset _panOffset = Offset.zero;

  // Xoay tự động (Turntable)
  late AnimationController _turntableController;
  bool _isAutoRotating = false;

  // Chế độ hiển thị & bộ lọc
  GrowRoom3dDisplayMode _displayMode = GrowRoom3dDisplayMode.realistic;
  int? _isolatedLevel; // null = xem cả 6 tầng, 1..6 = xem riêng 1 tầng
  int? _isolatedRack; // null = xem tất cả rack, 1..4 = xem riêng 1 rack
  bool _showRoomShell = true;
  bool _showDimensions = true;

  // Tương tác chạm ô (Selection & Hover)
  WindowLocation? _selectedWindow;
  WindowLocation? _hoveredWindow;
  List<TransformedPolygon> _renderedPolygons = [];

  // Theo dõi thao tác chuột/cảm ứng
  Offset? _lastPanPosition;
  double _baseZoom = 1.0;

  // Trạng thái thu gọn/bật tắt khung điều khiển (UI/UX Mobile Optimization)
  bool _showHud = true; // Bật/Tắt toàn bộ HUD (Zen mode / Fullscreen 3D)
  bool _isCameraControlsExpanded = false; // Thu gọn/mở rộng khung Camera & Tầng
  bool _isDisplayModeExpanded = false; // Thu gọn/mở rộng khung Chế độ hiển thị
  bool _isBottomInspectorExpanded = true; // Thu gọn/mở rộng thanh thông số / ô chọn
  String _currentPreset = 'isometric';

  String get _currentPresetLabel {
    switch (_currentPreset) {
      case 'front':
        return 'Front End';
      case 'side':
        return 'Side (9W)';
      case 'top':
        return 'Top Floor';
      case 'isometric':
      default:
        return 'Isometric';
    }
  }

  String get _displayModeLabel {
    switch (_displayMode) {
      case GrowRoom3dDisplayMode.temperature:
        return 'Heatmap';
      case GrowRoom3dDisplayMode.moisture:
        return 'Moisture';
      case GrowRoom3dDisplayMode.pickingStatus:
        return 'Harvest';
      case GrowRoom3dDisplayMode.realistic:
      default:
        return 'Realistic';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedRoomName = widget.initialRoomName ?? 'Room 33';
    _isLargeRoom = widget.initialIsLargeRoom ??
        (!_isSmallRoomByName(_selectedRoomName ?? ''));

    if (widget.initialSelectedWindowCode != null) {
      final match = RegExp(r'R(\d+)-L(\d+)-W(\d+)')
          .firstMatch(widget.initialSelectedWindowCode!);
      if (match != null) {
        final r = int.parse(match.group(1)!) - 1;
        final l = int.parse(match.group(2)!) - 1;
        final w = int.parse(match.group(3)!) - 1;
        _selectedWindow =
            WindowLocation(rackIndex: r, levelIndex: l, windowIndex: w);
      }
    }

    _turntableController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..addListener(() {
        if (_isAutoRotating) {
          setState(() {
            _yaw += 0.008;
            if (_yaw > math.pi * 2) _yaw -= math.pi * 2;
          });
        }
      });

    _loadRooms();
    _loadActiveIssues();
    _issuesSubscription = _actionService.issuesStream.listen((_) {
      if (mounted) _loadActiveIssues();
    });
  }

  @override
  void dispose() {
    _issuesSubscription?.cancel();
    _turntableController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveIssues() async {
    final issues =
        await _actionService.getActiveIssuesMap(_selectedRoomName ?? '');
    if (mounted) {
      setState(() {
        _activeIssues = issues;
      });
    }
  }

  Map<String, dynamic> _getTelemetryForWindow(WindowLocation loc) {
    // Level 1: ~18.0°C, Level 6: ~20.2°C
    final baseTemp = 18.0 + (loc.levelIndex * 0.44);
    final tempVar = (math.sin(loc.windowIndex) * 0.2);
    final temp = double.parse((baseTemp + tempVar).toStringAsFixed(1));
    final humidity = double.parse(
        (90.5 + (math.cos(loc.windowIndex) * 1.5)).toStringAsFixed(1));
    final co2 = (1120 + loc.levelIndex * 22 + loc.windowIndex * 8).toDouble();
    final casingTemp = double.parse((temp + 0.4).toStringAsFixed(1));
    final flush = (loc.windowIndex % 3 == 0)
        ? 'Flush 2 (Harvesting)'
        : 'Flush 1 (Pinning)';
    return {
      'temp': temp,
      'humidity': humidity,
      'co2': co2,
      'casingTemp': casingTemp,
      'flush': flush,
    };
  }

  bool _isSmallRoomByName(String roomName) {
    return roomName == 'Room 40' ||
        roomName == 'Room 41' ||
        roomName == 'Room 46' ||
        roomName == 'Room 47' ||
        roomName == 'Room 55' ||
        roomName == 'Room 56' ||
        roomName == 'Room 57' ||
        roomName == 'Room 52' ||
        roomName == 'Room 52A' ||
        roomName == 'Room 10' ||
        roomName == 'Room 11' ||
        roomName == 'Room 12' ||
        roomName == 'Room 13' ||
        roomName == 'Room 14' ||
        roomName == 'Room 15' ||
        roomName == 'Room 16';
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await MushroomsRepository().getRooms();
      rooms.sort((a, b) => PlantRoomService.compareRoomNames(
            (a['name'] as String?) ?? '',
            (b['name'] as String?) ?? '',
          ));
      if (mounted) {
        setState(() {
          _dbRooms = rooms;
        });
      }
    } catch (_) {}
  }

  void _onRoomChanged(String? roomName) {
    if (roomName == null) return;
    setState(() {
      _selectedRoomName = roomName;
      _isLargeRoom = !_isSmallRoomByName(roomName);
      _selectedWindow = null;
    });
    _loadActiveIssues();
  }

  void _setPresetCamera(String preset) {
    setState(() {
      _currentPreset = preset;
      _panOffset = Offset.zero;
      switch (preset) {
        case 'isometric':
          _yaw = 0.58;
          _pitch = 0.38;
          _zoom = 1.15;
          break;
        case 'front': // Nhìn từ cửa vào dọc theo các lối đi
          _yaw = 0.0;
          _pitch = 0.05;
          _zoom = 1.35;
          break;
        case 'side': // Nhìn ngang thấy rõ 9 window và chiều cao 6m
          _yaw = math.pi / 2;
          _pitch = 0.08;
          _zoom = 1.05;
          break;
        case 'top': // Mặt bằng sàn từ trên cao nhìn xuống
          _yaw = 0.0;
          _pitch = 1.54;
          _zoom = 1.1;
          break;
      }
    });
  }

  void _toggleAutoRotate() {
    setState(() {
      _isAutoRotating = !_isAutoRotating;
      if (_isAutoRotating) {
        _turntableController.repeat();
      } else {
        _turntableController.stop();
      }
    });
  }

  void _handleTap(TapUpDetails details) {
    final tapPos = details.localPosition;
    // Tìm polygon gần camera nhất chứa điểm chạm
    TransformedPolygon? hit;
    for (final tp in _renderedPolygons.reversed) {
      if (tp.poly.windowLocation != null && tp.containsPoint(tapPos)) {
        hit = tp;
        break;
      }
    }

    setState(() {
      if (hit != null) {
        _selectedWindow = hit.poly.windowLocation;
        _isBottomInspectorExpanded = true; // Tự động mở rộng khi chọn ô trồng
      } else {
        _selectedWindow = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF131C2E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        titleSpacing: isMobile ? 8 : NavigationToolbar.kMiddleSpacing,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A78D6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.view_in_ar_rounded,
                  color: Color(0xFF2A78D6), size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedRoomName ?? 'Grow Room 3D',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isLargeRoom
                        ? (isMobile ? '4 Racks • 6 Levels • 6m H' : 'Large Room • 4 Racks • 6 Levels • 9 Windows (27m) • 6m Height')
                        : (isMobile ? '2 Racks • 6 Levels • 6m H' : 'Small Room • 2 Racks • 6 Levels • 9 Windows (27m) • 6m Height'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Quick toggle Large Room / Small Room
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(isMobile ? '2R' : 'Small (2 Racks)'),
                  icon: isMobile ? null : const Icon(Icons.view_column_outlined, size: 16),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(isMobile ? '4R' : 'Large (4 Racks)'),
                  icon: isMobile ? null : const Icon(Icons.view_column_rounded, size: 16),
                ),
              ],
              selected: {_isLargeRoom},
              onSelectionChanged: (val) {
                setState(() {
                  _isLargeRoom = val.first;
                  _selectedWindow = null;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10)),
                textStyle: WidgetStateProperty.all(TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          // Dropdown chọn phòng từ danh sách (nếu có)
          if (_dbRooms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRoomName,
                  dropdownColor: cardBg,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  items: _dbRooms.map((r) {
                    final name = r['name'] as String;
                    final isSmall = _isSmallRoomByName(name);
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text('$name (${isSmall ? "2R" : "4R"})'),
                    );
                  }).toList(),
                  onChanged: _onRoomChanged,
                ),
              ),
            ),

          // Fullscreen / Zen mode Master Toggle
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _showHud ? Icons.fullscreen_rounded : Icons.fullscreen_exit_rounded,
              color: _showHud ? (isDark ? Colors.white70 : Colors.black87) : const Color(0xFF2A78D6),
            ),
            tooltip: _showHud ? 'Zen Mode (Hide All Controls)' : 'Show All Controls',
            onPressed: () => setState(() => _showHud = !_showHud),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // KHÔNG GIAN VẼ 3D VỚI GESTURE DETECTOR
          Positioned.fill(
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  setState(() {
                    if (pointerSignal.scrollDelta.dy < 0) {
                      _zoom = (_zoom * 1.08).clamp(0.4, 4.0);
                    } else {
                      _zoom = (_zoom / 1.08).clamp(0.4, 4.0);
                    }
                  });
                }
              },
              child: GestureDetector(
                onScaleStart: (details) {
                  _baseZoom = _zoom;
                  _lastPanPosition = details.localFocalPoint;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.pointerCount == 1 && _lastPanPosition != null) {
                      // Kéo 1 ngón tay / chuột trái: Xoay Camera (Yaw & Pitch)
                      final delta = details.localFocalPoint - _lastPanPosition!;
                      _yaw += delta.dx * 0.008;
                      _pitch = (_pitch - delta.dy * 0.008).clamp(-1.45, 1.45);
                    } else if (details.pointerCount > 1) {
                      // Kéo 2 ngón tay: Phóng to thu nhỏ và Dịch chuyển (Pan)
                      _zoom = (_baseZoom * details.scale).clamp(0.4, 4.0);
                      if (_lastPanPosition != null) {
                        _panOffset += details.localFocalPoint - _lastPanPosition!;
                      }
                    }
                    _lastPanPosition = details.localFocalPoint;
                  });
                },
                onScaleEnd: (_) {
                  _lastPanPosition = null;
                },
                onTapUp: _handleTap,
                child: CustomPaint(
                  painter: GrowRoom3dPainter(
                    isLargeRoom: _isLargeRoom,
                    yaw: _yaw,
                    pitch: _pitch,
                    zoom: _zoom,
                    panOffset: _panOffset,
                    displayMode: _displayMode,
                    isolatedLevel: _isolatedLevel,
                    isolatedRack: _isolatedRack,
                    selectedWindow: _selectedWindow,
                    hoveredWindow: _hoveredWindow,
                    activeIssues: _activeIssues,
                    showRoomShell: _showRoomShell,
                    showDimensions: _showDimensions,
                    isDark: isDark,
                    onRenderPolygons: (polys) {
                      _renderedPolygons = polys;
                    },
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          // HUD OVERLAYS (Hiện khi _showHud == true)
          if (_showHud) ...[
            // HUD TOP-LEFT: BỘ ĐIỀU KHIỂN GÓC NHÌN & CÔNG CỤ
            Positioned(
              top: 12,
              left: 12,
              child: _buildControlsCard(cardBg, borderColor, isDark, isMobile),
            ),

            // HUD TOP-RIGHT: CHỌN CHẾ ĐỘ HIỂN THỊ MÀU
            Positioned(
              top: 12,
              right: 12,
              child: _buildDisplayModeCard(cardBg, borderColor, isDark, isMobile),
            ),

            // HUD BOTTOM: THANH THÔNG TIN CHI TIẾT Ô ĐANG CHỌN HOẶC TỔNG QUAN PHÒNG
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: _buildBottomInspector(cardBg, borderColor, isDark, isMobile),
            ),
          ] else ...[
            // NÚT PHỤC HỒI HUD KHI ĐANG Ở ZEN / FULLSCREEN MODE
            Positioned(
              top: 12,
              right: 12,
              child: _buildShowHudButton(cardBg, borderColor, isDark),
            ),
          ],
        ],
      ),
    );
  }

  // --- NÚT PHỤC HỒI HUD KHI ĐANG Ở ZEN / FULLSCREEN MODE ---
  Widget _buildShowHudButton(Color cardBg, Color borderColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _showHud = true),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2A78D6)),
                const SizedBox(width: 6),
                Text(
                  'Show Controls',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BỘ ĐIỀU KHIỂN GÓC NHÌN CAMERA & TẦNG ---
  Widget _buildControlsCard(
      Color cardBg, Color borderColor, bool isDark, bool isMobile) {
    if (!_isCameraControlsExpanded) {
      // COLLAPSED PILL: Gọn gàng, vừa vặn trên mobile, không che khuất mô hình 3D
      return Container(
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isCameraControlsExpanded = true;
                if (isMobile) _isDisplayModeExpanded = false; // Tránh chồng chéo trên màn hình hẹp
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded, size: 16, color: Color(0xFF2A78D6)),
                  const SizedBox(width: 6),
                  Text(
                    _currentPresetLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (_isolatedLevel != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A78D6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'L$_isolatedLevel',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2A78D6),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  // Nút bật tắt xoay tự động nhanh ngay trên pill
                  InkWell(
                    onTap: _toggleAutoRotate,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        _isAutoRotating
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: _isAutoRotating ? Colors.amber : Colors.blueGrey,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // EXPANDED CARD
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? 275 : 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_rounded, size: 16, color: Color(0xFF2A78D6)),
              const SizedBox(width: 6),
              Text(
                'Camera & Controls',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              // Auto-rotate button
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  _isAutoRotating
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: _isAutoRotating ? Colors.amber : Colors.blueGrey,
                  size: 20,
                ),
                tooltip: 'Auto Rotate 3D',
                onPressed: _toggleAutoRotate,
              ),
              const SizedBox(width: 4),
              // Reset Button
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                tooltip: 'Reset to Default View',
                onPressed: () => _setPresetCamera('isometric'),
              ),
              const SizedBox(width: 4),
              // Collapse Button
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                tooltip: 'Collapse',
                onPressed: () =>
                    setState(() => _isCameraControlsExpanded = false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Camera presets
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _buildPresetBtn('Isometric', _currentPreset == 'isometric',
                  () => _setPresetCamera('isometric')),
              _buildPresetBtn('Front End', _currentPreset == 'front',
                  () => _setPresetCamera('front')),
              _buildPresetBtn('Side (9W)', _currentPreset == 'side',
                  () => _setPresetCamera('side')),
              _buildPresetBtn('Top Floor', _currentPreset == 'top',
                  () => _setPresetCamera('top')),
            ],
          ),
          const SizedBox(height: 8),
          // Toggle Room Shell and Rulers
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilterChip(
                label: const Text('Room Shell', style: TextStyle(fontSize: 10.5)),
                selected: _showRoomShell,
                onSelected: (val) => setState(() => _showRoomShell = val),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Rulers (6m/27m)', style: TextStyle(fontSize: 10.5)),
                selected: _showDimensions,
                onSelected: (val) => setState(() => _showDimensions = val),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Level filter (Level 1..6)
          Text(
            'Level Filter (Tầng 1..6):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('All', style: TextStyle(fontSize: 10.5)),
                selected: _isolatedLevel == null,
                onSelected: (_) => setState(() => _isolatedLevel = null),
                visualDensity: VisualDensity.compact,
              ),
              for (int l = 1; l <= 6; l++)
                ChoiceChip(
                  label: Text('L$l', style: const TextStyle(fontSize: 10.5)),
                  selected: _isolatedLevel == l,
                  onSelected: (sel) =>
                      setState(() => _isolatedLevel = sel ? l : null),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetBtn(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2A78D6)
              : Colors.blueGrey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  // --- WIDGET CHỌN CHẾ ĐỘ HIỂN THỊ MÀU ---
  Widget _buildDisplayModeCard(
      Color cardBg, Color borderColor, bool isDark, bool isMobile) {
    if (!_isDisplayModeExpanded) {
      // COLLAPSED PILL
      return Container(
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isDisplayModeExpanded = true;
                if (isMobile) _isCameraControlsExpanded = false; // Tránh chồng chéo
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    _displayModeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.blueGrey),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // EXPANDED CARD
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? 220 : 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                'Display Mode',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                tooltip: 'Collapse',
                onPressed: () => setState(() => _isDisplayModeExpanded = false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            direction: Axis.vertical,
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _buildModeChip('Realistic (Materials)', GrowRoom3dDisplayMode.realistic),
              _buildModeChip('Temperature Heatmap', GrowRoom3dDisplayMode.temperature),
              _buildModeChip('Moisture / Irrigation', GrowRoom3dDisplayMode.moisture),
              _buildModeChip('Harvest Progress', GrowRoom3dDisplayMode.pickingStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, GrowRoom3dDisplayMode mode) {
    final isSelected = _displayMode == mode;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) => setState(() => _displayMode = mode),
      visualDensity: VisualDensity.compact,
    );
  }

  // --- WIDGET BẢNG THÔNG SỐ CHI TIẾT DƯỚI ĐÁY MÀN HÌNH ---
  Widget _buildBottomInspector(
      Color cardBg, Color borderColor, bool isDark, bool isMobile) {
    if (_selectedWindow != null) {
      final loc = _selectedWindow!;
      final double zStart = 1.0 + loc.windowIndex * 3.0;
      final double zEnd = zStart + 3.0;
      final double elevation = GrowRoom3dPainter.levelHeights[loc.levelIndex];
      final tele = _getTelemetryForWindow(loc);
      final activeIssue = _activeIssues[loc.code];

      // KHI ĐANG THU GỌN: Thanh bar siêu gọn hiển thị mã ô & nhiệt ẩm
      if (!_isBottomInspectorExpanded) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cardBg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activeIssue != null
                  ? (activeIssue.category == WindowIssueCategory.disease
                      ? Colors.redAccent
                      : Colors.amber)
                  : const Color(0xFF2A78D6),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (activeIssue != null ? Colors.red : const Color(0xFF2A78D6))
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (activeIssue != null) ...[
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      loc.code,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: activeIssue != null ? Colors.redAccent : const Color(0xFF2A78D6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${tele['temp']}°C • ${tele['humidity']}% RH • ${tele['flush']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                tooltip: 'Expand Details',
                onPressed: () => setState(() => _isBottomInspectorExpanded = true),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Deselect',
                onPressed: () => setState(() => _selectedWindow = null),
              ),
            ],
          ),
        );
      }

      // KHI ĐANG MỞ RỘNG: Bảng thông số chi tiết của ô
      return Container(
        padding: EdgeInsets.all(isMobile ? 10 : 14),
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activeIssue != null
                ? (activeIssue.category == WindowIssueCategory.disease
                    ? Colors.redAccent
                    : Colors.amber)
                : const Color(0xFF2A78D6).withValues(alpha: 0.8),
            width: 1.8,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Tiêu đề ô, vị trí, kích thước, Thu nhỏ & Bỏ chọn
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: (activeIssue != null ? Colors.red : const Color(0xFF2A78D6))
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activeIssue != null ? Colors.redAccent : const Color(0xFF2A78D6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activeIssue != null ? Icons.warning_amber_rounded : Icons.view_in_ar_rounded,
                        color: activeIssue != null ? Colors.redAccent : const Color(0xFF2A78D6),
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        loc.code,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: activeIssue != null ? Colors.redAccent : const Color(0xFF2A78D6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loc.rackLabel} • ${loc.levelLabel} • ${loc.windowLabel}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '3.0m×1.2m (3.6m²) • Pos: ${zStart.toStringAsFixed(1)}-${zEnd.toStringAsFixed(1)}m • H: ~${elevation.toStringAsFixed(1)}m',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  tooltip: 'Minimize Details',
                  onPressed: () => setState(() => _isBottomInspectorExpanded = false),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Deselect',
                  onPressed: () => setState(() => _selectedWindow = null),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Telemetry Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTelemetryChip(
                    icon: Icons.thermostat_rounded,
                    label: 'Air Temp',
                    value: '${tele['temp']}°C',
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildTelemetryChip(
                    icon: Icons.water_drop_rounded,
                    label: 'RH Humidity',
                    value: '${tele['humidity']}%',
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildTelemetryChip(
                    icon: Icons.co2_rounded,
                    label: 'CO2 Level',
                    value: '${(tele['co2'] as double).toInt()} ppm',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildTelemetryChip(
                    icon: Icons.grass_rounded,
                    label: 'Casing Temp',
                    value: '${tele['casingTemp']}°C',
                    color: const Color(0xFFD97706),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildTelemetryChip(
                    icon: Icons.eco_rounded,
                    label: 'Flush Stage',
                    value: '${tele['flush']}',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Row 3: Active Issue Alert Banner (if any)
            if (activeIssue != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Text(
                      activeIssue.category.iconEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '[${activeIssue.category.displayName}] ${activeIssue.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  activeIssue.severity.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${activeIssue.description} • By: ${activeIssue.reporterName}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Resolve', style: TextStyle(fontSize: 10.5)),
                      onPressed: () => _resolveIssue(activeIssue.id),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Row 4: Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_alert_rounded, size: 15),
                  label: const Text(
                    'Log Issue / Add Action',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _showLogIssueDialog(context, loc, tele),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // When no window is selected: Show room specification summary
    final int rackCount = _isLargeRoom ? 4 : 2;
    final int shelfCount = rackCount * 6;
    final int totalWindows = shelfCount * 9;
    final double totalArea = shelfCount * 27.0 * 1.2;

    if (!_isBottomInspectorExpanded) {
      // MINIMIZED CAPSULE for Room Specs
      return Center(
        child: Container(
          decoration: BoxDecoration(
            color: cardBg.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isBottomInspectorExpanded = true),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF2A78D6)),
                    const SizedBox(width: 6),
                    Text(
                      '${_isLargeRoom ? "Large (4 Racks)" : "Small (2 Racks)"} • 6m H • Tap bed to inspect',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: Colors.blueGrey),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // EXPANDED ROOM SUMMARY
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricBadge(
                    'Room Type',
                    _isLargeRoom ? 'LARGE ROOM' : 'SMALL ROOM',
                    _isLargeRoom ? Colors.indigo : Colors.teal,
                  ),
                  const SizedBox(width: 14),
                  _buildMetricBadge('Ceiling Height', '6.0 meters', Colors.blueGrey),
                  const SizedBox(width: 14),
                  _buildMetricBadge('Rack Scale', '$rackCount Racks × 6 Levels', const Color(0xFF2A78D6)),
                  const SizedBox(width: 14),
                  _buildMetricBadge('Rack Length', '27.0 meters (9 Windows)', const Color(0xFF10B981)),
                  const SizedBox(width: 14),
                  _buildMetricBadge('Total Bed Area', '${totalArea.toStringAsFixed(1)} m²', Colors.amber[800]!),
                  const SizedBox(width: 14),
                  _buildMetricBadge('Total Bays', '$totalWindows Windows (3m)', Colors.purple),
                  const SizedBox(width: 14),
                  Text(
                    '• Tap any bed window to inspect details',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            tooltip: 'Minimize Specs',
            onPressed: () => setState(() => _isBottomInspectorExpanded = false),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildTelemetryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resolveIssue(String id) async {
    await _actionService.updateIssueStatus(id, 'resolved');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Issue status updated to RESOLVED.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // --- HỘP THOẠI BÁO CÁO SỰ CỐ / THÊM ACTION CHO Ô TRỒNG ---
  void _showLogIssueDialog(
    BuildContext context,
    WindowLocation loc,
    Map<String, dynamic> tele,
  ) {
    WindowIssueCategory selectedCategory = WindowIssueCategory.disease;
    String selectedSeverity = 'critical'; // Mặc định cảnh báo
    final titleController = TextEditingController(text: selectedCategory.presets.first);
    final descController = TextEditingController();
    final reporterController = TextEditingController(text: 'Vinh (Growing Lead)');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF131C2E) : Colors.white;

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_alert_rounded, color: Color(0xFFE11D48), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Issue / Add Action',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '${_selectedRoomName ?? "Room"} • ${loc.code} (${loc.rackLabel} • ${loc.levelLabel} • ${loc.windowLabel})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Current Telemetry Snapshot
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('🌡️ ${tele['temp']}°C', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('💧 ${tele['humidity']}% RH', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('💨 ${(tele['co2'] as double).toInt()} ppm', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('🌱 Casing: ${tele['casingTemp']}°C', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 1. Issue Category
                      const Text(
                        '1. Issue Category:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: WindowIssueCategory.values.map((cat) {
                          final isSel = selectedCategory == cat;
                          return ChoiceChip(
                            avatar: Text(cat.iconEmoji),
                            label: Text(cat.displayName, style: const TextStyle(fontSize: 11)),
                            selected: isSel,
                            selectedColor: const Color(0xFFE11D48).withValues(alpha: 0.2),
                            onSelected: (sel) {
                              if (sel) {
                                setDialogState(() {
                                  selectedCategory = cat;
                                  titleController.text = cat.presets.first;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // 2. Quick Presets
                      const Text(
                        '2. Quick Presets:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selectedCategory.presets.map((preset) {
                          final isSel = titleController.text == preset;
                          return ActionChip(
                            label: Text(preset, style: TextStyle(fontSize: 10.5, color: isSel ? Colors.amber : null)),
                            backgroundColor: isSel
                                ? Colors.amber.withValues(alpha: 0.15)
                                : Colors.blueGrey.withValues(alpha: 0.08),
                            onPressed: () {
                              setDialogState(() {
                                titleController.text = preset;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Issue Title
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Issue Title',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),

                      // Detailed Description
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Detailed Description / Proposed Action',
                          hintText: 'e.g. Size of mould patch, exact location on bed, urgent isolation required...',
                          labelStyle: const TextStyle(fontSize: 12),
                          hintStyle: const TextStyle(fontSize: 11),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 14),

                      // 3. Severity
                      Row(
                        children: [
                          const Text('3. Severity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Normal', style: TextStyle(fontSize: 11)),
                            selected: selectedSeverity == 'normal',
                            onSelected: (s) => setDialogState(() => selectedSeverity = 'normal'),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Warning', style: TextStyle(fontSize: 11)),
                            selected: selectedSeverity == 'high',
                            selectedColor: Colors.orange.withValues(alpha: 0.25),
                            onSelected: (s) => setDialogState(() => selectedSeverity = 'high'),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Critical', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: selectedSeverity == 'critical',
                            selectedColor: Colors.red.withValues(alpha: 0.3),
                            onSelected: (s) => setDialogState(() => selectedSeverity = 'critical'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reporter
                      TextField(
                        controller: reporterController,
                        decoration: InputDecoration(
                          labelText: 'Reporter (Staff / Lead)',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Submit Report & Raise Alert', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;

                    await _actionService.reportIssue(
                      roomName: _selectedRoomName ?? 'Room 33',
                      rackIndex: loc.rackIndex,
                      levelIndex: loc.levelIndex,
                      windowIndex: loc.windowIndex,
                      category: selectedCategory,
                      title: titleController.text.trim(),
                      description: descController.text.trim().isNotEmpty
                          ? descController.text.trim()
                          : titleController.text.trim(),
                      severity: selectedSeverity,
                      reporterName: reporterController.text.trim(),
                      temperature: tele['temp'],
                      humidity: tele['humidity'],
                      co2: tele['co2'],
                      casingTemp: tele['casingTemp'],
                    );

                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Issue [${selectedCategory.displayName}] logged at ${loc.code}. Data synced to Growing Performance Board.',
                          ),
                          backgroundColor: Colors.green[800],
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
