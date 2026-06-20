import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/izii_colors.dart';
import '../../../core/database/app_database.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_models.dart';

class RecordChatTab extends StatefulWidget {
  final String recordType; // 'lead' | 'deal' | 'job' | 'service'
  final String recordId;
  final List<String> participantUserIds;

  const RecordChatTab({
    super.key,
    required this.recordType,
    required this.recordId,
    required this.participantUserIds,
  });

  @override
  State<RecordChatTab> createState() => _RecordChatTabState();
}

class _RecordChatTabState extends State<RecordChatTab> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    final chatBloc = context.read<ChatBloc>();
    final currentUserId = chatBloc.currentUserId ?? '';

    try {
      final convo =
          await chatBloc.chatRepository.getOrCreateRecordLinkedConversation(
        currentUserId: currentUserId,
        recordType: widget.recordType,
        recordId: widget.recordId,
        participantUserIds:
            {...widget.participantUserIds, currentUserId}.toList(),
      );

      if (mounted) {
        setState(() {
          _conversationId = convo.id;
          _initializing = false;
        });
        chatBloc.add(OpenConversationEvent(convo.id));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    context.read<ChatBloc>().add(SendMessageEvent(
          conversationId: _conversationId!,
          text: text,
        ));

    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversationId == null) {
      return Center(
        child: Text(context.tr('chat_error_init')),
      );
    }

    return Column(
      children: [
        // Comments Feed
        Expanded(
          child: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              if (state.activeConversationId != _conversationId) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = state.activeMessages;
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    context.tr('chat_no_comments_yet'),
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];

                  return FutureBuilder<User?>(
                    future: _getUser(context, msg.senderId),
                    builder: (context, snapshot) {
                      final userName = snapshot.data?.name ?? 'User';
                      String commentText = '';
                      try {
                        final contentMap = Map<String, dynamic>.from(
                            jsonDecode(msg.content) as Map);
                        commentText = contentMap['text'] as String? ?? '';
                      } catch (_) {
                        commentText = msg.content;
                      }

                      final timeStr = DateFormat('dd/MM HH:mm')
                          .format(msg.sentAt.toLocal());

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  IZiiColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: IZiiColors.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? IZiiColors.darkSurface
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      commentText,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // Comment input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? IZiiColors.darkSurface : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? IZiiColors.darkSurfaceHighlight
                    : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? IZiiColors.darkBackground
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: context.tr('chat_write_comment'),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: IZiiColors.primary),
                onPressed: _sendComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<User?> _getUser(BuildContext context, String userId) async {
    final chatBloc = context.read<ChatBloc>();
    try {
      final query = chatBloc.db.select(chatBloc.db.users)
        ..where((u) => u.id.equals(userId));
      return await query.getSingleOrNull();
    } catch (_) {
      return null;
    }
  }
}
