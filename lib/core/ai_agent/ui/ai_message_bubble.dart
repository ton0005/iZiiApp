import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/chat_models.dart';

class AiMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const AiMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              backgroundColor: Color(0xFF6366F1), // Primary
              child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF6366F1)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Render text with inline lead cards
                  _buildRichContent(context, isUser),
                  if (message.toolCalls != null &&
                      message.toolCalls!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...message.toolCalls!
                        .map((t) => _buildToolCard(t, context)),
                  ]
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 32),
        ],
      ),
    ).animate().fade(duration: 300.ms).slideY(
        begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildRichContent(BuildContext context, bool isUser) {
    final content = message.content;

    // Check if the content contains lead card markers: [LEAD:name|status|revenue|title]
    if (!isUser && content.contains('[LEAD:')) {
      return _buildContentWithLeadCards(context, content);
    }

    return Text(
      content,
      style: TextStyle(
        color: isUser
            ? Colors.white
            : Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }

  Widget _buildContentWithLeadCards(BuildContext context, String content) {
    final parts = <Widget>[];
    final regex = RegExp(r'\[LEAD:([^\]]+)\]');
    int lastEnd = 0;

    for (final match in regex.allMatches(content)) {
      // Add text before this match
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          parts.add(Text(
            textBefore,
            style:
                TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
          ));
          parts.add(const SizedBox(height: 8));
        }
      }

      // Parse lead data: name|status|revenue|title
      final data = match.group(1)!.split('|');
      if (data.length >= 3) {
        parts.add(_buildLeadCard(
          context,
          name: data[0].trim(),
          status: data[1].trim(),
          revenue: data[2].trim(),
          title: data.length > 3 ? data[3].trim() : '',
        ));
        parts.add(const SizedBox(height: 6));
      }

      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        parts.add(const SizedBox(height: 4));
        parts.add(Text(
          remaining,
          style:
              TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts,
    );
  }

  Widget _buildLeadCard(
    BuildContext context, {
    required String name,
    required String status,
    required String revenue,
    String title = '',
  }) {
    // Parse status color
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Đang đàm phán':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.handshake_outlined;
        break;
      case 'Chốt đơn':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Khách hàng mới':
        statusColor = const Color(0xFF06B6D4);
        statusIcon = Icons.person_add_outlined;
        break;
      default:
        statusColor = const Color(0xFF6366F1);
        statusIcon = Icons.person_outline;
    }

    return GestureDetector(
      onTap: () => _showLeadDetail(context,
          name: name, status: status, revenue: revenue, title: title),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: 0.08),
              statusColor.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        revenue,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: statusColor.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  void _showLeadDetail(
    BuildContext context, {
    required String name,
    required String status,
    required String revenue,
    String title = '',
  }) {
    Color statusColor;
    switch (status) {
      case 'Đang đàm phán':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'Chốt đơn':
        statusColor = const Color(0xFF10B981);
        break;
      case 'Khách hàng mới':
        statusColor = const Color(0xFF06B6D4);
        break;
      default:
        statusColor = const Color(0xFF6366F1);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Info rows
            _buildDetailRow(Icons.monetization_on_outlined, 'Trị giá dự kiến',
                revenue, Colors.green),
            if (title.isNotEmpty)
              _buildDetailRow(Icons.description_outlined, 'Nhu cầu', title,
                  const Color(0xFF6366F1)),
            _buildDetailRow(Icons.calendar_today_outlined, 'Ngày tạo',
                'Hôm nay', Colors.grey),
            const SizedBox(height: 24),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Cập nhật'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: statusColor),
                      foregroundColor: statusColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Liên hệ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(ToolCall tool, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.build_circle, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Text(
            'Action: ${tool.name}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          if (tool.result != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, size: 16, color: Colors.green),
          ]
        ],
      ),
    );
  }
}
