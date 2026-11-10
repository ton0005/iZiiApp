import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/database/app_database.dart';
import '../../../core/device_identity/screens/online_devices_screen.dart';
import '../../../core/device_identity/ble_device_discovery_service.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_models.dart';
import '../widgets/presence_avatar.dart';
import '../theme/chat_theme.dart';
import 'conversation_screen.dart';
import '../widgets/create_group_dialog.dart';

class ChatInboxScreen extends StatefulWidget {
  final bool embedded;
  const ChatInboxScreen({super.key, this.embedded = false});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedConversationId; // For split screen views
  String _currentFilter = 'all'; // 'all' | 'unread' | 'groups' | 'archived'

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadConversationsEvent());
    context.read<ChatBloc>().add(LoadContactsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    Widget body;
    if (screenWidth >= 1200.0) {
      body = _buildThreePanelLayout(isDark);
    } else if (screenWidth >= 768.0) {
      body = _buildTwoPanelLayout(isDark);
    } else {
      body = _buildMobileLayout(isDark);
    }

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: ChatTheme.getBgPrimary(isDark),
      appBar: AppBar(
        title: Text(
          context.tr('chat_collaboration_title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: ChatTheme.getTextPrimary(isDark),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981)),
            tooltip: 'Create New Group / Channel',
            onSelected: (val) async {
              if (val == 'group') {
                final gid = await CreateGroupDialog.show(context, isBroadcast: false);
                if (gid != null && context.mounted) {
                  context.push('/chat/conversation/$gid');
                }
              } else if (val == 'broadcast') {
                final gid = await CreateGroupDialog.show(context, isBroadcast: true);
                if (gid != null && context.mounted) {
                  context.push('/chat/conversation/$gid');
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'group',
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, color: Color(0xFF0284C7), size: 20),
                    SizedBox(width: 10),
                    Text('Create New Group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'broadcast',
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text('Create Broadcast Channel'),
                  ],
                ),
              ),
            ],
          ),
          // Track 3: Online devices discovery
          IconButton(
            icon: const Icon(Icons.devices_rounded, color: Color(0xFF06B6D4)),
            tooltip: context.tr('chat_tooltip_online_devices'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnlineDevicesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.supervised_user_circle_rounded,
                color: Colors.orange),
            tooltip: context.tr('chat_tooltip_switch_test_account'),
            onPressed: () => _showTestProfileSwitcher(context),
          ),
          IconButton(
            icon: Icon(Icons.sync_rounded, color: ChatTheme.getAccent(isDark)),
            onPressed: () {
              context.read<ChatBloc>().add(LoadConversationsEvent());
              context.read<ChatBloc>().add(LoadContactsEvent());
            },
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final accent = ChatTheme.getAccent(isDark);
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'unread', 'label': 'Unread'},
      {'key': 'groups', 'label': 'Groups & Channels'},
      {'key': 'archived', 'label': 'Archived'},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final f = filters[idx];
          final isSelected = _currentFilter == f['key'];
          return ChoiceChip(
            label: Text(f['label']!, style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : ChatTheme.getTextPrimary(isDark),
            )),
            selected: isSelected,
            selectedColor: accent,
            backgroundColor: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.grey.shade100,
            onSelected: (_) {
              setState(() {
                _currentFilter = f['key']!;
              });
            },
          );
        },
      ),
    );
  }

  void _showConversationOptionsSheet(BuildContext context, ChatConversation convo, bool isDark) {
    final bloc = context.read<ChatBloc>();
    final isPinned = convo.isPinned;
    final isArchived = convo.isArchived;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
              title: Text(isPinned ? 'Unpin conversation' : 'Pin to top'),
              onTap: () async {
                Navigator.pop(ctx);
                await bloc.chatRepository.setConversationPinned(convo.id, !isPinned);
                bloc.add(LoadConversationsEvent());
              },
            ),
            ListTile(
              leading: Icon(isArchived ? Icons.unarchive_rounded : Icons.archive_rounded),
              title: Text(isArchived ? 'Unarchive conversation' : 'Archive conversation'),
              onTap: () async {
                Navigator.pop(ctx);
                await bloc.chatRepository.setConversationArchived(convo.id, !isArchived);
                bloc.add(LoadConversationsEvent());
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Mute notifications (8 hours)'),
              onTap: () async {
                Navigator.pop(ctx);
                await bloc.chatRepository.setConversationMuted(
                  convo.id,
                  DateTime.now().add(const Duration(hours: 8)),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications muted for 8 hours')),
                  );
                }
                bloc.add(LoadConversationsEvent());
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_read_outlined),
              title: const Text('Mark as read'),
              onTap: () async {
                Navigator.pop(ctx);
                await bloc.chatRepository.markConversationRead(convo.id);
                bloc.add(LoadConversationsEvent());
              },
            ),
          ],
        ),
      ),
    );
  }

  // Mobile Single-column Inbox
  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        _buildTestUserBanner(isDark),
        _buildSearchField(isDark),
        _buildFilterChips(isDark),
        _buildContactsStrip(isDark),
        const Divider(thickness: 1, height: 16),
        Expanded(child: _buildConversationsList(isDark, isMobile: true)),
      ],
    );
  }

  // Tablet Split View: Inbox Left (35%), Conversation Right (65%)
  Widget _buildTwoPanelLayout(bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.35,
          child: Column(
            children: [
              _buildTestUserBanner(isDark),
              _buildSearchField(isDark),
              _buildContactsStrip(isDark),
              const Divider(thickness: 1, height: 16),
              Expanded(child: _buildConversationsList(isDark, isMobile: false)),
            ],
          ),
        ),
        VerticalDivider(
            width: 1,
            color:
                isDark ? ChatTheme.bgBubbleTheirsDark : Colors.grey.shade300),
        Expanded(
          child: _selectedConversationId != null
              ? ConversationScreen(
                  key: ValueKey(_selectedConversationId),
                  conversationId: _selectedConversationId!,
                  embedded: true,
                )
              : _buildEmptyDetailState(isDark),
        ),
      ],
    );
  }

  // Desktop Three Panel Layout: Contacts (25%), Conversation (50%), Details (25%)
  Widget _buildThreePanelLayout(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      children: [
        // Left Panel: Contact list + Inbox
        SizedBox(
          width: width * 0.25,
          child: Column(
            children: [
              _buildTestUserBanner(isDark),
              _buildSearchField(isDark),
              _buildContactsStrip(isDark),
              const Divider(thickness: 1, height: 16),
              Expanded(child: _buildConversationsList(isDark, isMobile: false)),
            ],
          ),
        ),
        VerticalDivider(
            width: 1,
            color:
                isDark ? ChatTheme.bgBubbleTheirsDark : Colors.grey.shade300),

        // Middle Panel: Conversation Screen
        Expanded(
          child: _selectedConversationId != null
              ? ConversationScreen(
                  key: ValueKey(_selectedConversationId),
                  conversationId: _selectedConversationId!,
                  embedded: true,
                )
              : _buildEmptyDetailState(isDark),
        ),
        VerticalDivider(
            width: 1,
            color:
                isDark ? ChatTheme.bgBubbleTheirsDark : Colors.grey.shade300),

        // Right Panel: Record Details context placeholder
        SizedBox(
          width: width * 0.25,
          child: _buildRecordDetailsPanel(isDark),
        ),
      ],
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          style:
              TextStyle(color: ChatTheme.getTextPrimary(isDark), fontSize: 16),
          decoration: InputDecoration(
            hintText: context.tr('chat_search_hint'),
            hintStyle: TextStyle(color: ChatTheme.getTextMuted(isDark)),
            prefixIcon: Icon(Icons.search_rounded,
                color: ChatTheme.getTextMuted(isDark)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsStrip(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
          child: Text(
            context.tr('chat_contacts_header'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: ChatTheme.getTextMuted(isDark),
            ),
          ),
        ),
        BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            final filteredContacts = state.contacts.where((c) {
              return c.name.toLowerCase().contains(_searchQuery);
            }).toList();

            if (filteredContacts.isEmpty) {
              return const SizedBox(height: 10);
            }

            return SizedBox(
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = filteredContacts[index];
                  final isBleConnected = BleDeviceDiscoveryService()
                      .isUserConnectedBle(contact.id);
                  final presence = isBleConnected
                      ? ChatPresenceState.onlineSynced
                      : (state.userPresenceMap[contact.id] ??
                          ChatPresenceState.offline);

                  return GestureDetector(
                    onTap: () {
                      context
                          .read<ChatBloc>()
                          .add(OpenDirectChatWithUserEvent(contact.id));
                      final currentUserId = state.currentUserId ??
                          context.read<ChatBloc>().currentUserId ??
                          'default_user';
                      final ids = [currentUserId, contact.id]..sort();
                      final convoId = 'direct_${ids[0]}_${ids[1]}';
                      final screenWidth = MediaQuery.of(context).size.width;
                      if (screenWidth >= 768.0) {
                        setState(() {
                          _selectedConversationId = convoId;
                        });
                      } else {
                        context.push('/chat/conversation/$convoId');
                      }
                    },
                    child: Container(
                      width: 76,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          PresenceAvatar(
                            name: contact.name,
                            presence: presence,
                            radius: 24, // 48px size
                          ),
                          const SizedBox(height: 6),
                          Text(
                            contact.name.split(' ').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: ChatTheme.getTextPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildConversationsList(bool isDark, {required bool isMobile}) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state.isLoading && state.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: isDark
                      ? ChatTheme.bgBubbleTheirsDark
                      : Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('chat_no_conversations'),
                  style: TextStyle(
                      color: ChatTheme.getTextMuted(isDark), fontSize: 16),
                ),
              ],
            ),
          );
        }

        final filteredConvos = state.conversations.where((c) {
          if (_currentFilter == 'unread' && c.unreadCount == 0) return false;
          if (_currentFilter == 'groups' && !(c.type == 'group' || c.isBroadcast)) return false;
          if (_currentFilter == 'archived' && !c.isArchived) return false;
          if (_currentFilter != 'archived' && c.isArchived) return false;
          return true;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: filteredConvos.length,
          itemBuilder: (context, index) {
            final convo = filteredConvos[index];

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getConvoDetail(context, convo),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 72);
                }

                final detail = snapshot.data!;
                final companionName = detail['name'] as String;
                final companionId = detail['id'] as String;
                final isBleConnected =
                    BleDeviceDiscoveryService().isUserConnectedBle(companionId);
                final companionPresence = isBleConnected
                    ? ChatPresenceState.onlineSynced
                    : (state.userPresenceMap[companionId] ??
                        ChatPresenceState.offline);
                final lastSnippet = detail['last_message'] as String;
                final timeStr = detail['time'] as String;
                final unreadCount = detail['unread_count'] as int;

                return Dismissible(
                  key: Key(convo.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    decoration: BoxDecoration(
                      color: ChatTheme.getDanger(isDark),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.delete_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('chat_action_delete'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    // Trigger delete mutation logic
                  },
                  child: InkWell(
                    onLongPress: () => _showConversationOptionsSheet(context, convo, isDark),
                    child: Card(
                    color: _selectedConversationId == convo.id
                        ? ChatTheme.getAccent(isDark).withValues(alpha: 0.15)
                        : (isDark
                            ? ChatTheme.bgBubbleTheirsDark
                            : Colors.white),
                    elevation: 0,
                    margin:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _selectedConversationId == convo.id
                            ? ChatTheme.getAccent(isDark)
                            : (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200),
                        width: _selectedConversationId == convo.id ? 2.0 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        if (isMobile) {
                          context
                              .read<ChatBloc>()
                              .add(OpenConversationEvent(convo.id));
                          context.push('/chat/conversation/${convo.id}');
                        } else {
                          setState(() {
                            _selectedConversationId = convo.id;
                          });
                          context
                              .read<ChatBloc>()
                              .add(OpenConversationEvent(convo.id));
                        }
                      },
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: PresenceAvatar(
                        name: companionName,
                        presence: companionPresence,
                        radius: 24, // 48px size
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              companionName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: ChatTheme.getTextPrimary(isDark),
                              ),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: ChatTheme.getTextMuted(isDark),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastSnippet,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ChatTheme.getTextMuted(isDark),
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ChatTheme.getDanger(isDark),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyDetailState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_chat_read_rounded,
            size: 80,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('chat_select_convo_prompt'),
            style:
                TextStyle(fontSize: 16, color: ChatTheme.getTextMuted(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordDetailsPanel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('chat_record_context_header'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: ChatTheme.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  context.tr('chat_no_linked_record_selected'),
                  style: TextStyle(
                      color: ChatTheme.getTextMuted(isDark), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getConvoDetail(
      BuildContext context, dynamic convo) async {
    final chatBloc = context.read<ChatBloc>();
    final currentUserId = chatBloc.currentUserId ?? '';

    final companion =
        await chatBloc.chatRepository.getCompanion(convo.id, currentUserId);
    final lastMsg = await chatBloc.chatRepository.getLatestMessage(convo.id);

    final String name = convo.type == 'group'
        ? (convo.title ?? 'Group Chat')
        : (convo.type == 'record_linked'
            ? '${convo.recordType.toString().toUpperCase()} - ${convo.recordId.toString().substring(0, 4)}'
            : (companion?.name ?? 'Companion'));

    final String id = companion?.id ?? '';
    String lastSnippet = '';
    String timeStr = '';
    int unreadCount = 0;

    if (lastMsg != null) {
      try {
        final decoded =
            Map<String, dynamic>.from(jsonDecode(lastMsg.content) as Map);
        lastSnippet = decoded['text'] as String? ?? '';
      } catch (_) {
        lastSnippet = lastMsg.content;
      }

      final sentLocal = lastMsg.sentAt.toLocal();
      final difference = DateTime.now().difference(sentLocal);

      if (difference.inDays > 0) {
        timeStr = DateFormat('dd/MM').format(sentLocal);
      } else {
        timeStr = DateFormat('h:mm a').format(sentLocal);
      }

      if (lastMsg.senderId != currentUserId && lastMsg.readAt == null) {
        unreadCount = 1; // Basic unread count calculator
      }
    } else {
      lastSnippet = context.tr('chat_no_messages_yet');
    }

    return {
      'id': id,
      'name': name,
      'last_message': lastSnippet,
      'time': timeStr,
      'unread_count': unreadCount,
    };
  }

  void _showTestProfileSwitcher(BuildContext context) async {
    final chatBloc = context.read<ChatBloc>();
    final db = chatBloc.db;
    final users = await db.select(db.users).get();
    final currentUserId =
        chatBloc.state.currentUserId ?? chatBloc.currentUserId;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatTheme.getBgBubbleTheirs(
            Theme.of(ctx).brightness == Brightness.dark),
        title: Text(
          context.tr('chat_switch_test_role_title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ChatTheme.getTextPrimary(
                Theme.of(ctx).brightness == Brightness.dark),
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isCurrent = user.id == currentUserId;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return ListTile(
                leading: Icon(
                  isCurrent
                      ? Icons.check_circle_rounded
                      : Icons.account_circle_rounded,
                  color: isCurrent ? const Color(0xFF10B981) : Colors.grey,
                ),
                title: Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: ChatTheme.getTextPrimary(isDark),
                  ),
                ),
                subtitle: Text('ID: ${user.id}',
                    style: TextStyle(color: ChatTheme.getTextMuted(isDark))),
                onTap: () {
                  Navigator.pop(ctx);
                  chatBloc.add(SwitchUserEvent(user.id));
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTestUserBanner(bool isDark) {
    return Container(
      color: Colors.orange.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.bug_report_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                // Tên hiển thị lấy từ danh bạ (đã đồng bộ từ server). Không
                // còn ánh xạ cứng theo id demo — id giờ luôn là device_id, và
                // tên đi theo người đang đăng nhập trên máy đó.
                final currentUserId = state.currentUserId;
                String currentName = state.myDisplayName;
                if (currentName.isEmpty) {
                  for (var user in state.contacts) {
                    if (user.id == currentUserId) {
                      currentName = user.name;
                      break;
                    }
                  }
                }
                if (currentName.isEmpty) {
                  currentName = currentUserId ?? 'This device';
                }

                return Text(
                  context
                      .tr('chat_playing_role')
                      .replaceAll('{name}', currentName),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ChatTheme.getTextPrimary(isDark),
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text(context.tr('chat_switch_role_button'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _showTestProfileSwitcher(context),
          ),
        ],
      ),
    );
  }
}
