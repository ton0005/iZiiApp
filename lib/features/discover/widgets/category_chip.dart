import 'package:flutter/material.dart';
import '../../../core/theme/izii_colors.dart';

/// A premium category filter chip with icon, gradient selected state,
/// and animated scale-on-tap feedback.
class CategoryChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: sel ? IZiiColors.primaryGradient : null,
            color: sel ? null : IZiiColors.darkSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  sel ? Colors.transparent : IZiiColors.darkSurfaceHighlight,
              width: 1.2,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: IZiiColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: sel ? Colors.white : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? Colors.white : Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
