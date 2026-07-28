import 'package:flutter/material.dart';
import '../screens/mushboom_monarto_screen.dart'; // For FarmColors
import '../services/safety_management_service.dart';

class PlantMapWidget extends StatefulWidget {
  final bool isDark;
  final String activePlant; // 'M1' or 'M2'
  final Map<String, Map<String, dynamic>> localRooms;
  final Map<String, List<String>> roomCrews;
  final String roomFilter; // 'all', 'active', 'idle'
  final Set<String> selectedRoomNames; // Supports single or multi-select
  final Map<String, Color>? highlightedRooms; // Custom highlight colors for plan review mode
  final Function(String roomName) onRoomSelected;
  final Function(String plant)? onPlantChanged;
  final Function(String filter)? onRoomFilterChanged;
  final bool showHeader;
  final bool showLegend;
  final bool isMaximized;
  final VoidCallback? onToggleMaximize;

  const PlantMapWidget({
    super.key,
    required this.isDark,
    required this.activePlant,
    required this.localRooms,
    required this.roomCrews,
    this.roomFilter = 'all',
    required this.selectedRoomNames,
    this.highlightedRooms,
    required this.onRoomSelected,
    this.onPlantChanged,
    this.onRoomFilterChanged,
    this.showHeader = true,
    this.showLegend = true,
    this.isMaximized = false,
    this.onToggleMaximize,
  });

  @override
  State<PlantMapWidget> createState() => _PlantMapWidgetState();
}

class _PlantMapWidgetState extends State<PlantMapWidget> {
  final ScrollController _horizontalScrollController = ScrollController();
  final SafetyManagementService _safetyService = SafetyManagementService();

  static const List<String?> m2TopRow = [
    'Room 33', 'Room 34', 'Room 35', 'Room 36', 'Room 37', 'Room 38',
    'Room 39', 'Room 40', 'Room 41', 'Room 42', 'Room 43', 'Room 44',
    'corridor',
    'Room 45', 'Room 46', 'Room 47', 'Room 48', 'Room 49', 'Room 50',
    'Room 51', 'Room 52', 'Room 52A'
  ];

  static const List<String?> m2BottomRow = [
    'Room 66', 'Room 65', 'Room 64', 'Room 63', 'Room 62', 'Room 61',
    'Room 60', 'Room 59', 'Room 58', 'Room 57', 'Room 56', 'Room 55',
    'corridor',
    'Room 54', 'Room 53', null, null, null, null, null, null, null
  ];

  static const List<String?> m1TopRow = [
    'Room 1', 'Room 2', 'Room 3', 'Room 4', 'Room 5', 'Room 6',
    'Room 7', 'Room 8', 'Room 9', 'Room 10', 'Room 11', 'Room 12',
    'corridor',
    'Room 13', 'Room 14', 'Room 15', 'Room 16', 'Room 17', 'Room 18',
    'Room 19', 'Room 20', null
  ];

  static const List<String?> m1BottomRow = [
    'Room 32', 'Room 31', 'Room 30', 'Room 29', 'Room 28', 'Room 27',
    'Room 26', 'Room 25', 'Room 24', 'Room 23', 'Room 22', 'Room 21',
    'corridor',
    null, null, null, null, null, null, null, null, null
  ];

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  bool _isSmallRoom(String roomName) {
    return roomName == 'Room 52A' || roomName == 'Room 20';
  }

  double _getRoomBaseWidth(String? roomName) {
    if (roomName == null) return 96.0;
    if (roomName == 'corridor') return 36.0;
    if (_isSmallRoom(roomName)) return 48.0;
    return 96.0;
  }

  Color _getStageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'spawn':
      case 'casing':
        return Colors.brown;
      case 'growing':
      case 'pinning':
        return Colors.green;
      case 'harvesting':
      case 'harvest':
        return FarmColors.maintenanceOrange;
      case 'airing':
        return Colors.purple;
      case 'watering':
        return Colors.cyan;
      case 'prochloraz':
        return Colors.red;
      case 'packuptree':
        return Colors.orange;
      case 'cleanroom':
        return Colors.green.shade700;
      case 'idle':
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topRow = widget.activePlant == 'M2' ? m2TopRow : m1TopRow;
    final bottomRow = widget.activePlant == 'M2' ? m2BottomRow : m1BottomRow;
    final int columnCount = topRow.length;

    final List<double> columnWidths = List.generate(columnCount, (i) {
      final topName = topRow[i];
      final bottomName = bottomRow[i];

      final topWidth = _getRoomBaseWidth(topName);
      final bottomWidth = _getRoomBaseWidth(bottomName);

      return topWidth > bottomWidth ? topWidth : bottomWidth;
    });

    final double totalCorridorWidth =
        columnWidths.fold(0.0, (sum, w) => sum + w + 12.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) _buildFloorMapHeader(),
        Expanded(
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 8, bottom: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: List.generate(columnCount, (i) {
                        return _buildCell(topRow[i], columnWidths[i], true);
                      }),
                    ),
                    const SizedBox(height: 10),
                    _buildCentralCorridor(totalCorridorWidth),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(columnCount, (i) {
                        return _buildCell(bottomRow[i], columnWidths[i], false);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showLegend) _buildLegend(),
      ],
    );
  }

  Widget _buildFloorMapHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_rounded,
                  color: FarmColors.forestGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Plant ${widget.activePlant} Floor Map Layout',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (widget.onPlantChanged != null) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => widget.onPlantChanged!(widget.activePlant == 'M2' ? 'M1' : 'M2'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: FarmColors.forestGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FarmColors.forestGreen),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Switch to ${widget.activePlant == 'M2' ? 'M1' : 'M2'}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: FarmColors.forestGreenText),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.swap_horiz_rounded,
                            size: 14, color: FarmColors.forestGreenText),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onRoomFilterChanged != null) ...[
                _buildFilterBtn('All', 'all'),
                const SizedBox(width: 4),
                _buildFilterBtn('Active', 'active'),
                const SizedBox(width: 4),
                _buildFilterBtn('Idle', 'idle'),
                const SizedBox(width: 8),
              ],
              if (widget.onToggleMaximize != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    widget.isMaximized
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: FarmColors.forestGreen,
                    size: 20,
                  ),
                  tooltip: widget.isMaximized ? 'Exit Full Screen' : 'Full Screen Map',
                  onPressed: widget.onToggleMaximize,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String label, String mode) {
    final isActive = widget.roomFilter == mode;
    return InkWell(
      onTap: () => widget.onRoomFilterChanged?.call(mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? FarmColors.forestGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildCentralCorridor(double corridorWidth) {
    return Container(
      width: corridorWidth,
      height: 24,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF222222) : Colors.grey.shade200,
        border: Border.all(color: FarmColors.borderLight),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(corridorWidth, 2),
            painter: DashedLinePainter(
              color: Colors.amber.withOpacity(0.5),
            ),
          ),
          Positioned(
            left: 16,
            child: Text(
              'MAIN LOGISTICS TRANSPORT CORRIDOR',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: widget.isDark ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
          Positioned(
            right: 16,
            child: Text(
              'MAIN LOGISTICS TRANSPORT CORRIDOR',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: widget.isDark ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String? roomName, double colW, bool isTopLine) {
    if (roomName == null) {
      return Container(
        width: colW,
        height: 105,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: const BoxDecoration(color: Colors.transparent),
      );
    }

    if (roomName == 'corridor') {
      return Container(
        width: colW,
        height: 105,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          border: Border.all(color: FarmColors.borderStrong, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            'MID WALKWAY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white24 : Colors.black26,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }

    final room = widget.localRooms[roomName];

    // Highlight / Selection checks
    final isSelected = widget.selectedRoomNames.contains(roomName);
    final Color? customHighlight = widget.highlightedRooms?[roomName];

    final isFilterMatch = widget.roomFilter == 'all' ||
        (room != null && widget.roomFilter == 'active' && room['status'] == 'active') ||
        (room != null && widget.roomFilter == 'idle' && room['status'] == 'idle');

    final double opacity = isFilterMatch ? 1.0 : 0.2;

    // Evaluate Safety Status via SafetyManagementService
    final safetyStatus = _safetyService.evaluateRoomSafety(room);
    final String displayStage = safetyStatus.stageLabel;
    final Color stageColor = _safetyService.getTagColor(
        safetyStatus, _getStageColor(displayStage));

    final crew = widget.roomCrews[roomName] ?? [];
    final hasCrew = crew.isNotEmpty;
    final double roomWidth = _isSmallRoom(roomName) ? 46.0 : 92.0;

    final Color defaultBg = isSelected
        ? (widget.isDark ? const Color(0xFF2A2A2A) : Colors.amber.shade50)
        : (widget.isDark ? const Color(0xFF1E1E1E) : Colors.white);

    final Color cardBgColor = customHighlight?.withOpacity(0.15) ??
        _safetyService.getCardBackgroundColor(
            safetyStatus, widget.isDark, defaultBg);

    final Color defaultBorder = customHighlight ??
        (isSelected ? FarmColors.forestGreen : FarmColors.borderLight);

    final Color borderColor =
        _safetyService.getBorderColor(safetyStatus, defaultBorder);

    final double borderWidth =
        (isSelected || customHighlight != null || safetyStatus.level != RoomSafetyLevel.normal)
            ? 3.0
            : 1.0;

    final List<BoxShadow>? cardShadow = _safetyService.getBoxShadow(
        safetyStatus, customHighlight ?? (isSelected ? FarmColors.forestGreen : null));

    return Container(
      width: colW,
      height: 105,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: roomWidth,
          height: 105,
          child: InkWell(
            onTap: isFilterMatch ? () => widget.onRoomSelected(roomName) : null,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border.all(color: borderColor, width: borderWidth),
                borderRadius: BorderRadius.circular(8),
                boxShadow: cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          roomName.replaceAll('Room ', ''),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: FarmColors.forestGreen, size: 12),
                    ],
                  ),
                  const Spacer(),
                  if (hasCrew)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_rounded,
                              color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            '${crew.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      displayStage.replaceAll('_', ' ').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: stageColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black12 : Colors.grey.shade50,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          _buildLegendDot('Growing', Colors.green),
          _buildLegendDot('Harvest', FarmColors.maintenanceOrange),
          _buildLegendDot('Casing', Colors.brown),
          _buildLegendDot('Watering', Colors.cyan),
          _buildLegendDot('Clean', Colors.green.shade700),
          _buildLegendDot('Alone Worker', Colors.orange),
          _buildLegendDot('Alone Timeout', Colors.red),
          _buildLegendDot('Idle', Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;

    const double dashWidth = 8;
    const double dashSpace = 8;
    double startX = 4;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2),
          Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
