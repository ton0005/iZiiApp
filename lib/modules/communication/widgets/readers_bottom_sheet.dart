import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../models/chat_models.dart';
import '../repository/chat_repository.dart';
import '../theme/chat_theme.dart';
import 'presence_avatar.dart';

class ReadersBottomSheet extends StatelessWidget {
  final String conversationId;
  final String messageId;
  final ChatRepository repository;

  const ReadersBottomSheet({
    super.key,
    required this.conversationId,
    required this.messageId,
    required this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    required String messageId,
    required ChatRepository repository,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ReadersBottomSheet(
        conversationId: conversationId,
        messageId: messageId,
        repository: repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<ChatMessageRead>>(
      future: repository.getMessageReads(messageId),
      builder: (context, snapshot) {
        final reads = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: ChatTheme.getBgPrimary(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.done_all_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Read by (${reads.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ChatTheme.getTextPrimary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (reads.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No one has read this message yet',
                      style: TextStyle(color: ChatTheme.getTextMuted(isDark)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final r = reads[idx];
                      final timeStr = DateFormat('h:mm a • dd/MM').format(r.readAt.toLocal());

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PresenceAvatar(name: r.userId, radius: 18),
                        title: Text(
                          r.userId,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ChatTheme.getTextPrimary(isDark),
                          ),
                        ),
                        trailing: Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: ChatTheme.getTextMuted(isDark),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
