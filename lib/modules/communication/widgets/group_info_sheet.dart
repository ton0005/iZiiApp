import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/database/app_database.dart';
import '../bloc/chat_bloc.dart';
import '../theme/chat_theme.dart';
import 'presence_avatar.dart';

class GroupInfoSheet extends StatefulWidget {
  final String conversationId;
  const GroupInfoSheet({super.key, required this.conversationId});

  static Future<void> show(BuildContext context, String conversationId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GroupInfoSheet(conversationId: conversationId),
    );
  }

  @override
  State<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<GroupInfoSheet> {
  ChatConversation? _convo;
  List<ChatParticipant> _participants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    final chatBloc = context.read<ChatBloc>();
    final db = chatBloc.db;
    final c = await (db.select(db.chatConversations)..where((tbl) => tbl.id.equals(widget.conversationId))).getSingleOrNull();
    final p = await (db.select(db.chatParticipants)..where((tbl) => tbl.conversationId.equals(widget.conversationId))).get();

    if (mounted) {
      setState(() {
        _convo = c;
        _participants = p;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatBloc = context.read<ChatBloc>();
    final myId = chatBloc.currentUserId ?? '';
    final myParticipant = _participants.where((p) => p.userId == myId).firstOrNull;
    final isMeAdmin = myParticipant?.role == 'owner' || myParticipant?.role == 'admin';

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: ChatTheme.getBgPrimary(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHeader(isDark),
                const SizedBox(height: 16),
                _buildActionButtons(isDark),
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Members (${_participants.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ChatTheme.getTextPrimary(isDark),
                        ),
                      ),
                      if (isMeAdmin)
                        TextButton.icon(
                          onPressed: _showAddMemberDialog,
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _participants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final p = _participants[idx];
                      return _buildMemberTile(p, isMeAdmin, myId, isDark);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Leave group'),
                      onPressed: _confirmLeaveGroup,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final title = _convo?.title ?? 'Group Chat';
    final desc = _convo?.description;
    final isBroadcast = _convo?.isBroadcast ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isBroadcast ? Colors.orange.withOpacity(0.15) : ChatTheme.getAccent(isDark).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBroadcast ? Icons.campaign_rounded : Icons.groups_rounded,
              color: isBroadcast ? Colors.orange : ChatTheme.getAccent(isDark),
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ChatTheme.getTextPrimary(isDark),
            ),
          ),
          if (isBroadcast) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Broadcast Channel',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
          ],
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ChatTheme.getTextMuted(isDark)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          icon: Icons.link_rounded,
          label: 'Invite link',
          onTap: _copyInviteLink,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? ChatTheme.bgBubbleTheirsDark : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: ChatTheme.getAccent(isDark)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ChatTheme.getTextPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(ChatParticipant p, bool isMeAdmin, String myId, bool isDark) {
    final isMe = p.userId == myId;
    final isOwner = p.role == 'owner';
    final isAdmin = p.role == 'admin';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PresenceAvatar(name: p.userId, radius: 18),
      title: Row(
        children: [
          Expanded(
            child: Text(
              p.userId + (isMe ? ' (You)' : ''),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                color: ChatTheme.getTextPrimary(isDark),
              ),
            ),
          ),
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Owner',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            )
          else if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
        ],
      ),
      trailing: (isMeAdmin && !isMe && !isOwner)
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (action) => _handleMemberAction(action, p),
              itemBuilder: (ctx) => [
                if (!isAdmin)
                  const PopupMenuItem(value: 'promote', child: Text('Promote to Admin'))
                else
                  const PopupMenuItem(value: 'demote', child: Text('Dismiss as Admin')),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from group', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            )
          : null,
    );
  }

  void _copyInviteLink() {
    final link = 'https://izii.app/chat/join/${widget.conversationId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite link copied: $link')),
    );
  }

  void _handleMemberAction(String action, ChatParticipant p) async {
    final chatBloc = context.read<ChatBloc>();
    if (action == 'promote') {
      await chatBloc.chatRepository.setParticipantRole(widget.conversationId, p.userId, 'admin');
    } else if (action == 'demote') {
      await chatBloc.chatRepository.setParticipantRole(widget.conversationId, p.userId, 'member');
    } else if (action == 'remove') {
      await chatBloc.chatRepository.removeGroupParticipant(widget.conversationId, p.userId);
    }
    _loadGroupData();
  }

  void _showAddMemberDialog() {
    final chatBloc = context.read<ChatBloc>();
    final contacts = chatBloc.state.contacts;
    final currentMemberIds = _participants.map((p) => p.userId).toSet();
    final available = contacts.where((c) => !currentMemberIds.contains(c.id)).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add members'),
        content: SizedBox(
          width: 320,
          child: available.isEmpty
              ? const Text('All contacts are already in this group.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (cCtx, idx) {
                    final u = available[idx];
                    return ListTile(
                      leading: PresenceAvatar(name: u.name, radius: 16),
                      title: Text(u.name),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await chatBloc.chatRepository.addGroupParticipant(widget.conversationId, u.id);
                        _loadGroupData();
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text('You will no longer receive messages from this group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close sheet
              final chatBloc = context.read<ChatBloc>();
              final myId = chatBloc.currentUserId ?? '';
              await chatBloc.chatRepository.leaveGroup(widget.conversationId, myId);
              chatBloc.add(LoadConversationsEvent());
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
