import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/chat_theme.dart';

/// Thẻ xem trước liên kết (Link Preview Card).
/// Tự động trích xuất các đường dẫn URL trong tin nhắn văn bản và hiển thị card preview đẹp mắt.
class LinkPreviewCard extends StatelessWidget {
  final String url;
  final bool isDark;
  final bool isMe;

  const LinkPreviewCard({
    super.key,
    required this.url,
    required this.isDark,
    required this.isMe,
  });

  static List<String> extractUrls(String text) {
    final urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final trailingPunctuation = RegExp(r'[.,!?:;)\]\>]+$');
    return urlRegExp.allMatches(text).map((m) {
      return m.group(0)!.replaceAll(trailingPunctuation, '');
    }).toSet().toList();
  }

  String _getHost(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl');
      return uri.host;
    } catch (_) {
      return rawUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _getHost(url);
    final accent = ChatTheme.getAccent(isDark);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.15) : (isDark ? Colors.black26 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe ? Colors.white24 : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.link_rounded, color: isMe ? Colors.white : accent, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        host,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : ChatTheme.getTextPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        url,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : ChatTheme.getTextMuted(isDark),
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: isMe ? Colors.white70 : ChatTheme.getTextMuted(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
