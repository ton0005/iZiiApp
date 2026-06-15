import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../theme/chat_theme.dart';

class PresenceAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final ChatPresenceState presence;
  final double radius;

  const PresenceAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.presence = ChatPresenceState.offline,
    this.radius = 24.0, // 24 radius = 48px size (large, clear)
  });

  Color _getStatusColor(bool isDark) {
    switch (presence) {
      case ChatPresenceState.onlineSynced:
        return ChatTheme.getOnline(isDark);
      case ChatPresenceState.syncPaused:
        return ChatTheme.getAccent(isDark);
      case ChatPresenceState.private:
        return ChatTheme.getTextMuted(isDark);
      case ChatPresenceState.offline:
        return ChatTheme.getTextMuted(isDark).withValues(alpha: 0.8);
    }
  }

  String _getInitials() {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(isDark);
    final initials = _getInitials();

    // Specific WCAG AA layout properties
    const double dotSize = 12.0;

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: ChatTheme.getAccent(isDark).withValues(alpha: 0.15),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.bold,
                    color: ChatTheme.getAccent(isDark),
                  ),
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: ChatTheme.getBgPrimary(isDark),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 2,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
