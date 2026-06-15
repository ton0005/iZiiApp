import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';

class QuickReplyTray extends StatelessWidget {
  final Function(String) onReplySelected;

  const QuickReplyTray({
    super.key,
    required this.onReplySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final replies = [
      '✅ On my way',
      '✅ Done',
      '🆘 Need help',
      '⏳ Running late',
      '📞 Call me',
      '🆗 OK 👍',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? ChatTheme.bgPrimaryDark : ChatTheme.bgPrimaryLight,
        border: Border(
          top: BorderSide(
            color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: replies.map((reply) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onReplySelected(reply),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    constraints: ChatTheme.tapTargetConstraints, // ensure 44px tap target minimum
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: reply.startsWith('🆘') 
                            ? ChatTheme.getDanger(isDark)
                            : ChatTheme.getAccent(isDark).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      color: reply.startsWith('🆘') 
                          ? ChatTheme.getDanger(isDark).withValues(alpha: 0.1)
                          : ChatTheme.getAccent(isDark).withValues(alpha: 0.05),
                    ),
                    child: Text(
                      reply,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: reply.startsWith('🆘') 
                            ? ChatTheme.getDanger(isDark)
                            : ChatTheme.getTextPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
