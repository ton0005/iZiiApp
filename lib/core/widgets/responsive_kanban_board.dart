import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum KanbanLayoutMode { mobile, tablet, desktop }

class ResponsiveKanbanBoard<T extends Object> extends StatefulWidget {
  /// Ordered list of lane keys (e.g. ['todo', 'in_progress', 'done'])
  final List<String> laneKeys;

  /// Get lane display title
  final String Function(String key, BuildContext ctx) laneTitle;

  /// Get lane accent color
  final Color Function(String key) laneColor;

  /// Grouped data: lane key → list of items
  final Map<String, List<T>> groupedData;

  /// Unique key extractor for each item (for drag identification)
  final String Function(T item) itemKey;

  /// Lane key extractor from an item (to know current lane)
  final String Function(T item) itemLane;

  /// Card builder — receives item, lane color, layout mode, and drag handle widget
  final Widget Function(
    BuildContext ctx,
    T item,
    Color laneColor,
    KanbanLayoutMode mode,
    Widget dragHandle,
  ) cardBuilder;

  /// Called when an item is dropped into a new lane
  final void Function(T item, String newLaneKey) onItemMoved;

  /// Optional empty-lane placeholder text
  final String? emptyLaneHint;

  const ResponsiveKanbanBoard({
    super.key,
    required this.laneKeys,
    required this.laneTitle,
    required this.laneColor,
    required this.groupedData,
    required this.itemKey,
    required this.itemLane,
    required this.cardBuilder,
    required this.onItemMoved,
    this.emptyLaneHint,
  });

  @override
  State<ResponsiveKanbanBoard<T>> createState() =>
      _ResponsiveKanbanBoardState<T>();
}

class _ResponsiveKanbanBoardState<T extends Object>
    extends State<ResponsiveKanbanBoard<T>> {
  late PageController _pageController;
  late ScrollController _horizontalScrollController;
  int _currentMobilePage = 0;
  DateTime? _lastScrollTime;

  // Track vertically collapsed lanes (mainly for Tablet layout)
  final Map<String, bool> _collapsedLanes = {};

  // Track drag state
  String? _currentlyDraggingId;
  String? _dragOverLaneKey;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Auto-scroll logic when dragging a card near screen edges
  void _handleDragUpdate(
      DragUpdateDetails details, double screenWidth, KanbanLayoutMode mode) {
    final now = DateTime.now();
    if (_lastScrollTime != null &&
        now.difference(_lastScrollTime!) < const Duration(milliseconds: 500)) {
      return;
    }

    final x = details.globalPosition.dx;
    const edgeWidth = 60.0;

    if (mode == KanbanLayoutMode.mobile) {
      if (x < edgeWidth) {
        if (_currentMobilePage > 0) {
          _lastScrollTime = now;
          _pageController.animateToPage(
            _currentMobilePage - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else if (x > screenWidth - edgeWidth) {
        if (_currentMobilePage < widget.laneKeys.length - 1) {
          _lastScrollTime = now;
          _pageController.animateToPage(
            _currentMobilePage + 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    } else if (mode == KanbanLayoutMode.tablet) {
      if (x < edgeWidth) {
        if (_horizontalScrollController.offset > 0) {
          _lastScrollTime = now;
          final target = (_horizontalScrollController.offset - 200)
              .clamp(0.0, _horizontalScrollController.position.maxScrollExtent);
          _horizontalScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      } else if (x > screenWidth - edgeWidth) {
        if (_horizontalScrollController.offset <
            _horizontalScrollController.position.maxScrollExtent) {
          _lastScrollTime = now;
          final target = (_horizontalScrollController.offset + 200)
              .clamp(0.0, _horizontalScrollController.position.maxScrollExtent);
          _horizontalScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final KanbanLayoutMode mode;
        if (screenWidth < 768) {
          mode = KanbanLayoutMode.mobile;
        } else if (screenWidth < 1200) {
          mode = KanbanLayoutMode.tablet;
        } else {
          mode = KanbanLayoutMode.desktop;
        }

        switch (mode) {
          case KanbanLayoutMode.mobile:
            return _buildMobileLayout(context, screenWidth);
          case KanbanLayoutMode.tablet:
            return _buildTabletLayout(context, screenWidth);
          case KanbanLayoutMode.desktop:
            return _buildDesktopLayout(context, screenWidth);
        }
      },
    );
  }

  // ================= MOBILE LAYOUT =================
  Widget _buildMobileLayout(BuildContext context, double width) {
    return Column(
      children: [
        // Top lane selector tabs
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: widget.laneKeys.asMap().entries.map((entry) {
              final idx = entry.key;
              final key = entry.value;
              final color = widget.laneColor(key);
              final isSelected = _currentMobilePage == idx;
              final count = widget.groupedData[key]?.length ?? 0;

              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    idx,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.laneTitle(key, context),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).textTheme.bodyLarge?.color
                              : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($count)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? color : Colors.grey[500],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // PageView for Lanes
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentMobilePage = page;
              });
            },
            itemCount: widget.laneKeys.length,
            itemBuilder: (context, index) {
              final laneKey = widget.laneKeys[index];
              return _buildLaneColumn(
                context: context,
                laneKey: laneKey,
                width: width,
                mode: KanbanLayoutMode.mobile,
              );
            },
          ),
        ),

        // Page Indicator Dots
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.laneKeys.asMap().entries.map((entry) {
              final idx = entry.key;
              final key = entry.value;
              final isSelected = _currentMobilePage == idx;
              final color = widget.laneColor(key);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 18.0 : 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : Colors.grey[600]?.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ================= TABLET LAYOUT =================
  Widget _buildTabletLayout(BuildContext context, double width) {
    // Each lane is ~48% width of the viewport
    final laneWidth = width * 0.46;

    return SingleChildScrollView(
      controller: _horizontalScrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.laneKeys.map((laneKey) {
          return Container(
            width: laneWidth,
            margin: const EdgeInsets.only(right: 16),
            child: _buildLaneColumn(
              context: context,
              laneKey: laneKey,
              width: laneWidth,
              mode: KanbanLayoutMode.tablet,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= DESKTOP LAYOUT =================
  Widget _buildDesktopLayout(BuildContext context, double width) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.laneKeys.map((laneKey) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildLaneColumn(
                context: context,
                laneKey: laneKey,
                width: (width - 40) / widget.laneKeys.length,
                mode: KanbanLayoutMode.desktop,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= LANE COLUMN =================
  Widget _buildLaneColumn({
    required BuildContext context,
    required String laneKey,
    required double width,
    required KanbanLayoutMode mode,
  }) {
    final title = widget.laneTitle(laneKey, context);
    final color = widget.laneColor(laneKey);
    final items = widget.groupedData[laneKey] ?? [];
    final isCollapsed = _collapsedLanes[laneKey] ?? false;
    final isOver = _dragOverLaneKey == laneKey;

    return DragTarget<T>(
      onWillAcceptWithDetails: (details) =>
          widget.itemLane(details.data) != laneKey,
      onAcceptWithDetails: (details) {
        widget.onItemMoved(details.data, laneKey);
        setState(() {
          _dragOverLaneKey = null;
        });
      },
      onLeave: (data) {
        setState(() {
          _dragOverLaneKey = null;
        });
      },
      onMove: (details) {
        if (_dragOverLaneKey != laneKey &&
            widget.itemLane(details.data) != laneKey) {
          setState(() {
            _dragOverLaneKey = laneKey;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isOver
                ? color.withValues(alpha: 0.08)
                : Theme.of(context).cardColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isOver ? color : Colors.grey.withValues(alpha: 0.08),
              width: isOver ? 2.0 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top accent gradient border per lane
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.3)],
                    ),
                  ),
                ),

                // Lane Header
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: mode == KanbanLayoutMode.tablet
                        ? () {
                            setState(() {
                              _collapsedLanes[laneKey] = !isCollapsed;
                            });
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (mode == KanbanLayoutMode.tablet) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  isCollapsed
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  size: 18,
                                  color: Colors.grey[500],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Card List
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: isCollapsed
                      ? const SizedBox.shrink()
                      : Container(
                          constraints: BoxConstraints(
                            maxHeight: mode == KanbanLayoutMode.mobile
                                ? MediaQuery.of(context).size.height * 0.65
                                : mode == KanbanLayoutMode.tablet
                                    ? MediaQuery.of(context).size.height * 0.60
                                    : MediaQuery.of(context).size.height * 0.70,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: items.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 32, horizontal: 16),
                                  child: Center(
                                    child: Text(
                                      widget.emptyLaneHint ??
                                          'Kéo thả thẻ vào đây',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return _buildDraggableCard(
                                      context: context,
                                      item: item,
                                      laneColor: color,
                                      width: width,
                                      mode: mode,
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= DRAGGABLE CARD =================
  Widget _buildDraggableCard({
    required BuildContext context,
    required T item,
    required Color laneColor,
    required double width,
    required KanbanLayoutMode mode,
  }) {
    final key = widget.itemKey(item);
    final double cardWidth =
        mode == KanbanLayoutMode.mobile ? width - 48 : width - 32;

    // Premium visual drag handle
    final Widget dragHandle = Listener(
      onPointerDown: (_) {
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Icon(
          Icons.drag_indicator_rounded,
          color: Colors.grey[400],
          size: 20,
        ),
      ),
    );

    // Build the raw card
    final Widget card = _KanbanHoverCard(
      mode: mode,
      child: widget.cardBuilder(context, item, laneColor, mode, dragHandle),
    );

    // Common feedback widget
    final Widget dragFeedback = Material(
      color: Colors.transparent,
      child: SizedBox(
        width: cardWidth,
        child: Opacity(
          opacity: 0.85,
          child: Transform.scale(
            scale: 0.96,
            child:
                widget.cardBuilder(context, item, laneColor, mode, dragHandle),
          ),
        ),
      ),
    );

    // Check if we use immediate Draggable or LongPressDraggable
    if (mode == KanbanLayoutMode.mobile) {
      // Swipe gestures (PageView) require LongPressDraggable to prevent horizontal swipe interference
      return LongPressDraggable<T>(
        data: item,
        delay: const Duration(milliseconds: 180),
        feedback: dragFeedback,
        childWhenDragging: Opacity(opacity: 0.25, child: card),
        onDragStarted: () {
          setState(() {
            _currentlyDraggingId = key;
          });
        },
        onDragUpdate: (details) =>
            _handleDragUpdate(details, MediaQuery.of(context).size.width, mode),
        onDragEnd: (_) {
          setState(() {
            _currentlyDraggingId = null;
            _dragOverLaneKey = null;
          });
        },
        child:
            card.animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),
      );
    } else {
      // Tablet & Desktop support both immediate dragging
      return Draggable<T>(
        data: item,
        feedback: dragFeedback,
        childWhenDragging: Opacity(opacity: 0.25, child: card),
        onDragStarted: () {
          setState(() {
            _currentlyDraggingId = key;
          });
        },
        onDragUpdate: (details) =>
            _handleDragUpdate(details, MediaQuery.of(context).size.width, mode),
        onDragEnd: (_) {
          setState(() {
            _currentlyDraggingId = null;
            _dragOverLaneKey = null;
          });
        },
        child:
            card.animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),
      );
    }
  }
}

// Widget that handles hover and cursor change effects
class _KanbanHoverCard extends StatefulWidget {
  final Widget child;
  final KanbanLayoutMode mode;

  const _KanbanHoverCard({
    required this.child,
    required this.mode,
  });

  @override
  State<_KanbanHoverCard> createState() => _KanbanHoverCardState();
}

class _KanbanHoverCardState extends State<_KanbanHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.mode == KanbanLayoutMode.mobile) {
      return widget.child;
    }

    return MouseRegion(
      cursor: _isHovered ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
