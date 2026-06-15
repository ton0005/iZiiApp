import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/database/app_database.dart';
import '../../../core/device_identity/device_discovery_service.dart';
import '../../../core/device_identity/device_identity_models.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_models.dart';
import '../widgets/presence_avatar.dart';
import '../widgets/quick_reply_tray.dart';
import '../widgets/coach_marks.dart';
import '../theme/chat_theme.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final bool embedded; // Hides AppBar back navigation when embedded in Split View

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showScrollToBottom = false;
  bool _showQuickReplyTray = false;
  
  // Accessibility Font size options state
  ChatFontSizeOption _fontSizeOption = ChatFontSizeOption.medium;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(OpenConversationEvent(widget.conversationId));
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Show scroll to bottom button if scrolled up by more than 200px
    if (maxScroll - currentScroll > 200.0) {
      if (!_showScrollToBottom) {
        setState(() {
          _showScrollToBottom = true;
        });
      }
    } else {
      if (_showScrollToBottom) {
        setState(() {
          _showScrollToBottom = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTextChanged(String text) {
    if (text.isEmpty && _isTyping) {
      _isTyping = false;
      context.read<ChatBloc>().add(SendTypingStateEvent(widget.conversationId, false));
    } else if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      context.read<ChatBloc>().add(SendTypingStateEvent(widget.conversationId, true));
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        context.read<ChatBloc>().add(SendTypingStateEvent(widget.conversationId, false));
      }
    });
  }

  void _sendMessage({String? quickReply}) {
    final text = quickReply ?? _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatBloc>().add(SendMessageEvent(
          conversationId: widget.conversationId,
          text: text,
        ));
    
    if (quickReply == null) {
      _messageController.clear();
      _onTextChanged('');
    }
    Timer(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatBloc = context.read<ChatBloc>();
    final currentUserId = chatBloc.currentUserId ?? '';

    return CoachMarks(
      featureKey: 'chat_interface',
      child: Scaffold(
        backgroundColor: ChatTheme.getBgPrimary(isDark),
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          backgroundColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
          elevation: 1,
          titleSpacing: widget.embedded ? 16 : 0,
          title: FutureBuilder<User?>(
            future: chatBloc.chatRepository.getCompanion(widget.conversationId, currentUserId),
            builder: (context, companionSnapshot) {
              if (!companionSnapshot.hasData) {
                return const SizedBox();
              }
              final companion = companionSnapshot.data!;
              
              return FutureBuilder<List<RemoteDevice>>(
                future: DeviceDiscoveryService().getOnlineDevices(),
                builder: (context, onlineSnapshot) {
                  final onlineDevices = onlineSnapshot.data ?? [];
                  final isE2ee = onlineDevices.any((d) => d.userId == companion.id);

                  return BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      final presence = state.userPresenceMap[companion.id] ?? ChatPresenceState.offline;
                      final isTyping = state.typingUsersMap[widget.conversationId]?.contains(companion.id) ?? false;

                      return Row(
                        children: [
                          PresenceAvatar(
                            name: companion.name,
                            presence: presence,
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      companion.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: ChatTheme.getTextPrimary(isDark),
                                      ),
                                    ),
                                    if (isE2ee) ...[
                                      const SizedBox(width: 6),
                                      const Tooltip(
                                        message: 'Mã hoá đầu cuối (E2EE)',
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 15,
                                          color: Color(0xFF10B981), // Emerald green
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTyping 
                                      ? context.tr('chat_is_typing')
                                      : _getPresenceText(context, presence),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isTyping 
                                        ? ChatTheme.getOnline(isDark) 
                                        : ChatTheme.getTextMuted(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          actions: [
            // Voice call button helper
            IconButton(
              icon: Icon(Icons.phone_rounded, color: ChatTheme.getAccent(isDark)),
              onPressed: () {
                // Call companion logic
              },
            ),
            // Font Size Selection Menu
            PopupMenuButton<ChatFontSizeOption>(
              icon: Icon(Icons.text_fields_rounded, color: ChatTheme.getAccent(isDark)),
              onSelected: (option) {
                setState(() {
                  _fontSizeOption = option;
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: ChatFontSizeOption.small,
                  child: Text('A A Small text (14px)', style: TextStyle(fontSize: ChatTheme.getFontSize(ChatFontSizeOption.small))),
                ),
                PopupMenuItem(
                  value: ChatFontSizeOption.medium,
                  child: Text('A A Normal text (16px)', style: TextStyle(fontSize: ChatTheme.getFontSize(ChatFontSizeOption.medium))),
                ),
                PopupMenuItem(
                  value: ChatFontSizeOption.large,
                  child: Text('A A Large text (18px)', style: TextStyle(fontSize: ChatTheme.getFontSize(ChatFontSizeOption.large))),
                ),
                PopupMenuItem(
                  value: ChatFontSizeOption.extraLarge,
                  child: Text('A A Extra Large (20px)', style: TextStyle(fontSize: ChatTheme.getFontSize(ChatFontSizeOption.extraLarge))),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Messages Feed
                Expanded(
                  child: BlocConsumer<ChatBloc, ChatState>(
                    listener: (context, state) {
                      Timer(const Duration(milliseconds: 100), _scrollToBottom);
                    },
                    builder: (context, state) {
                      if (state.isLoading && state.activeMessages.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state.activeMessages.isEmpty) {
                        return Center(
                          child: Text(
                            context.tr('chat_no_messages_yet'),
                            style: TextStyle(color: ChatTheme.getTextMuted(isDark), fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: state.activeMessages.length,
                        itemBuilder: (context, index) {
                          final message = state.activeMessages[index];
                          final isMe = message.senderId == currentUserId;
                          
                          // Group messages by day
                          bool showDateSeparator = false;
                          if (index == 0) {
                            showDateSeparator = true;
                          } else {
                            final prevMessage = state.activeMessages[index - 1];
                            final diff = message.sentAt.difference(prevMessage.sentAt).inDays;
                            if (diff.abs() > 0) {
                              showDateSeparator = true;
                            }
                          }

                          return Column(
                            children: [
                              if (showDateSeparator) _buildDateSeparator(message.sentAt, isDark),
                              _buildMessageBubble(context, message, isMe, isDark),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                // Typing indicator row
                _buildTypingIndicator(isDark),

                // Quick Reply tray if active
                if (_showQuickReplyTray)
                  QuickReplyTray(
                    onReplySelected: (reply) {
                      _sendMessage(quickReply: reply);
                      setState(() {
                        _showQuickReplyTray = false;
                      });
                    },
                  ),

                // Message input bar
                _buildInputBar(context, isDark),
              ],
            ),

            // Scroll to bottom FAB
            if (_showScrollToBottom)
              Positioned(
                right: 16,
                bottom: 80,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: ChatTheme.getAccent(isDark),
                  child: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
                  onPressed: () {
                    _scrollToBottom();
                    setState(() {
                      _showScrollToBottom = false;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    String dateStr = '';
    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate).inDays;

    if (difference == 0) {
      dateStr = 'Today';
    } else if (difference == 1) {
      dateStr = 'Yesterday';
    } else {
      dateStr = DateFormat('EEEE, d MMM').format(localDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          dateStr,
          style: TextStyle(
            color: ChatTheme.getTextMuted(isDark),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message, bool isMe, bool isDark) {
    String messageText = '';
    try {
      final contentMap = Map<String, dynamic>.from(jsonDecode(message.content) as Map);
      messageText = contentMap['text'] as String? ?? '';
    } catch (_) {
      messageText = message.content;
    }

    final sentTime = DateFormat('h:mm a').format(message.sentAt.toLocal());
    final fontSize = ChatTheme.getFontSize(_fontSizeOption);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActionSheet(context, messageText, message.id, isMe),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe 
                ? ChatTheme.getBgBubbleMine(isDark) 
                : ChatTheme.getBgBubbleTheirs(isDark),
            border: Border.all(
              color: isMe 
                  ? Colors.transparent 
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                messageText,
                style: TextStyle(
                  color: isMe ? Colors.white : ChatTheme.getTextPrimary(isDark),
                  fontSize: fontSize,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sentTime,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white.withValues(alpha: 0.75) : ChatTheme.getTextMuted(isDark),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusTick(message),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTick(ChatMessage message) {
    if (message.readAt != null) {
      return const Icon(Icons.done_all_rounded, size: 14, color: Colors.cyanAccent);
    } else if (message.deliveredAt != null) {
      return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70);
    } else {
      return const Icon(Icons.done_rounded, size: 14, color: Colors.white70);
    }
  }

  Widget _buildTypingIndicator(bool isDark) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final typingUsers = state.typingUsersMap[widget.conversationId];
        if (typingUsers == null || typingUsers.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Text(
                'typing...',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: ChatTheme.getOnline(isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Quick reply toggle button (⚡)
                IconButton(
                  icon: Icon(
                    _showQuickReplyTray ? Icons.bolt_rounded : Icons.offline_bolt_outlined,
                    color: ChatTheme.getAccent(isDark),
                  ),
                  onPressed: () {
                    setState(() {
                      _showQuickReplyTray = !_showQuickReplyTray;
                    });
                  },
                ),
                
                // Attachment Button (📎)
                IconButton(
                  icon: Icon(Icons.attach_file_rounded, color: ChatTheme.getTextMuted(isDark)),
                  onPressed: () {
                    // Attachment logic
                  },
                ),
                
                // Text Message input field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? ChatTheme.bgPrimaryDark : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            onChanged: _onTextChanged,
                            maxLines: 3,
                            minLines: 1,
                            style: TextStyle(fontSize: 16, color: ChatTheme.getTextPrimary(isDark)),
                            decoration: InputDecoration(
                              hintText: context.tr('chat_type_message'),
                              hintStyle: TextStyle(color: ChatTheme.getTextMuted(isDark)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        // Emoji Button (😊)
                        IconButton(
                          icon: Icon(Icons.sentiment_satisfied_alt_rounded, color: ChatTheme.getTextMuted(isDark)),
                          onPressed: () {
                            // Emoji tray action
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Send or Voice Action Button
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (context, value, child) {
                    final hasText = value.text.trim().isNotEmpty;
                    return CircleAvatar(
                      backgroundColor: ChatTheme.getAccent(isDark),
                      radius: 22,
                      child: IconButton(
                        icon: Icon(
                          hasText ? Icons.send_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: hasText 
                            ? _sendMessage 
                            : () {
                                // Voice message recorder trigger placeholder
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Voice recording... (Hold to Record alternative)'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageActionSheet(BuildContext context, String text, String messageId, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ChatTheme.bgPrimaryDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.copy_rounded, color: ChatTheme.getAccent(isDark)),
                title: const Text('Copy message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                },
              ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: ChatTheme.getDanger(isDark)),
                  title: const Text('Delete message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () {
                    // Soft delete logic
                    context.read<ChatBloc>().chatRepository.deleteMessage(messageId);
                    context.read<ChatBloc>().add(OpenConversationEvent(widget.conversationId));
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: Icon(Icons.reply_rounded, color: ChatTheme.getAccent(isDark)),
                title: const Text('Reply to message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPresenceText(BuildContext context, ChatPresenceState state) {
    switch (state) {
      case ChatPresenceState.onlineSynced:
        return context.tr('chat_presence_online');
      case ChatPresenceState.syncPaused:
        return context.tr('chat_presence_paused');
      case ChatPresenceState.private:
        return context.tr('chat_presence_private');
      case ChatPresenceState.offline:
        return context.tr('chat_presence_offline');
    }
  }
}
