import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/chat_theme.dart';

class CoachMarks extends StatefulWidget {
  final Widget child;
  final String featureKey;

  const CoachMarks({
    super.key,
    required this.child,
    required this.featureKey,
  });

  @override
  State<CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<CoachMarks> {
  bool _shouldShow = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown =
        prefs.getBool('coach_mark_${widget.featureKey}') ?? false;
    if (!alreadyShown && mounted) {
      setState(() {
        _shouldShow = true;
      });
      // Delay showing the overlay until frame renders
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
    }
  }

  void _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coach_mark_${widget.featureKey}', true);
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _shouldShow = false;
      });
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Dark transparent background
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
              ),
            ),

            // Tooltip UI
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ChatTheme.bgBubbleMineDark,
                              ChatTheme.accentDark
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome to In-App Chat!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Here are a few quick tips:\n\n'
                        '• ⚡ Quick Reply: Tap to send friendly preset messages without typing.\n'
                        '• AA Text Slider: Slide to increase text size up to Extra Large.\n'
                        '• 🆘 SOS Button: Press to send immediate emergency alerts.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ChatTheme.getAccent(isDark),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _dismiss,
                          child: const Text(
                            'Got it, thanks!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
