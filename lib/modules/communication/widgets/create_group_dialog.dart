import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/database/app_database.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/chat_bloc.dart';
import '../theme/chat_theme.dart';
import '../widgets/presence_avatar.dart';

class CreateGroupDialog extends StatefulWidget {
  final bool initialIsBroadcast;
  const CreateGroupDialog({super.key, this.initialIsBroadcast = false});

  static Future<String?> show(BuildContext context, {bool isBroadcast = false}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => CreateGroupDialog(initialIsBroadcast: isBroadcast),
    );
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late bool _isBroadcast;
  final Set<String> _selectedUserIds = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _isBroadcast = widget.initialIsBroadcast;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatBloc = context.read<ChatBloc>();
    final contacts = chatBloc.state.contacts;
    final myId = chatBloc.currentUserId ?? '';

    return Dialog(
      backgroundColor: ChatTheme.getBgPrimary(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isBroadcast
                        ? Colors.orange.withOpacity(0.15)
                        : ChatTheme.getAccent(isDark).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isBroadcast ? Icons.campaign_rounded : Icons.groups_rounded,
                    color: _isBroadcast ? Colors.orange : ChatTheme.getAccent(isDark),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isBroadcast ? 'Create Broadcast Channel' : 'Create Group Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ChatTheme.getTextPrimary(isDark),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(color: ChatTheme.getTextPrimary(isDark)),
              decoration: InputDecoration(
                labelText: _isBroadcast ? 'Channel name *' : 'Group name *',
                hintText: _isBroadcast ? 'e.g. Morning Shift - Costa Room 34' : 'e.g. Mushroom Team 1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: TextStyle(color: ChatTheme.getTextPrimary(isDark)),
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Group purpose and topics...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Broadcast channel (Admins only can post)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ChatTheme.getTextPrimary(isDark),
                ),
              ),
              subtitle: Text(
                'Best for safety alerts, shift schedules, announcements',
                style: TextStyle(fontSize: 12, color: ChatTheme.getTextMuted(isDark)),
              ),
              value: _isBroadcast,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _isBroadcast = val),
            ),
            const Divider(height: 20),
            Text(
              'Select members (${_selectedUserIds.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: ChatTheme.getTextMuted(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts available',
                        style: TextStyle(color: ChatTheme.getTextMuted(isDark)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: contacts.length,
                      itemBuilder: (ctx, idx) {
                        final user = contacts[idx];
                        if (user.id == myId) return const SizedBox.shrink();
                        final isSelected = _selectedUserIds.contains(user.id);
                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedUserIds.add(user.id);
                              } else {
                                _selectedUserIds.remove(user.id);
                              }
                            });
                          },
                          secondary: PresenceAvatar(
                            name: user.name,
                            radius: 18,
                          ),
                          title: Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: ChatTheme.getTextPrimary(isDark),
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${user.id}',
                            style: TextStyle(fontSize: 11, color: ChatTheme.getTextMuted(isDark)),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBroadcast ? Colors.orange : ChatTheme.getAccent(isDark),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isBroadcast ? 'Create Channel' : 'Create Group'),
                  onPressed: _submitting ? null : _createGroup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group / channel name.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final chatBloc = context.read<ChatBloc>();
    final myId = chatBloc.currentUserId ?? '';

    try {
      final convo = await chatBloc.chatRepository.createGroup(
        title: title,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        isBroadcast: _isBroadcast,
        memberUserIds: _selectedUserIds.toList(),
        creatorId: myId,
      );

      // Trigger sync and reload conversations
      chatBloc.add(LoadConversationsEvent());
      if (mounted) {
        Navigator.pop(context, convo.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() => _submitting = false);
      }
    }
  }
}
