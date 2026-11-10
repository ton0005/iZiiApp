import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/chat_bloc.dart';
import '../theme/chat_theme.dart';

/// Các thành phần giao diện của Phase 1: trả lời, cảm xúc, ghim, chuyển tiếp.
/// Tách khỏi conversation_screen.dart để màn hình đó không phình thêm.

enum MessageAction {
  reply,
  copy,
  edit,
  forward,
  pin,
  select,
  deleteForMe,
  deleteForEveryone,
}

const kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

Map<String, dynamic> decodeMessageContent(String raw) {
  try {
    final d = jsonDecode(raw);
    if (d is Map) return Map<String, dynamic>.from(d);
  } catch (_) {}
  return <String, dynamic>{};
}

String messageText(ChatMessage m) =>
    (decodeMessageContent(m.content)['text'] as String?) ?? '';

/// Dòng xem trước ngắn của một tin: dùng cho khung trích dẫn, thanh ghim, ô soạn.
String messagePreview(BuildContext context, ChatMessage m) {
  if (m.isDeleted) return context.tr('chat_msg_deleted');
  final content = decodeMessageContent(m.content);
  final text = (content['text'] as String?) ?? '';
  if (text.isNotEmpty) return text;
  final atts = content['attachments'];
  if (atts is List && atts.isNotEmpty) {
    final first = atts.first;
    final name = first is Map ? first['name']?.toString() : null;
    return '📎 ${name ?? context.tr('chat_attachment')}';
  }
  return '';
}

/// Tên hiển thị của người gửi trong khung trích dẫn / ô soạn.
String senderLabel(BuildContext context, String senderId, String myId) {
  if (senderId == myId) return context.tr('chat_you');
  final contacts = context.read<ChatBloc>().state.contacts;
  for (final u in contacts) {
    if (u.id == senderId) return u.name;
  }
  return senderId;
}

// ── Menu nhấn giữ ────────────────────────────────────────────────────────────

Future<void> showMessageActionsSheet({
  required BuildContext context,
  required ChatMessage message,
  required bool isMe,
  required bool isDirect,
  bool canDeleteEveryone = false,
  required void Function(MessageAction action) onAction,
  required void Function(String emoji) onReact,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = ChatTheme.getAccent(isDark);
  final danger = ChatTheme.getDanger(isDark);
  final hasText = messageText(message).isNotEmpty;
  final isPinned = message.pinnedAt != null;
  final myReaction = context
      .read<ChatBloc>()
      .state
      .reactionsMap[message.id]
      ?.where((r) => r.userId == context.read<ChatBloc>().currentUserId)
      .map((r) => r.emoji)
      .firstOrNull;

  Widget tile(IconData icon, String key, MessageAction action,
      {Color? color}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color ?? accent),
      title: Text(context.tr(key),
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: color ?? ChatTheme.getTextPrimary(isDark))),
      onTap: () {
        Navigator.pop(context);
        onAction(action);
      },
    );
  }

  return showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? ChatTheme.bgPrimaryDark : Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDirect && !message.isDeleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final e in kQuickReactions)
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onReact(e);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: myReaction == e
                                ? accent.withValues(alpha: 0.2)
                                : null,
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ],
                ),
              ),
            if (!message.isDeleted) ...[
              tile(Icons.reply_rounded, 'chat_action_reply', MessageAction.reply),
              if (hasText)
                tile(Icons.copy_rounded, 'chat_action_copy', MessageAction.copy),
              if (isMe && isDirect && message.type == 'text' && hasText)
                tile(Icons.edit_rounded, 'chat_action_edit', MessageAction.edit),
              tile(Icons.forward_rounded, 'chat_action_forward',
                  MessageAction.forward),
              if (isDirect)
                tile(
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    isPinned ? 'chat_action_unpin' : 'chat_action_pin',
                    MessageAction.pin),
              tile(Icons.checklist_rounded, 'chat_action_select',
                  MessageAction.select),
            ],
            tile(Icons.delete_outline_rounded, 'chat_action_delete_me',
                MessageAction.deleteForMe,
                color: danger),
            if ((isMe || canDeleteEveryone) && isDirect && !message.isDeleted)
              tile(Icons.delete_forever_rounded, 'chat_action_delete_everyone',
                  MessageAction.deleteForEveryone,
                  color: danger),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

// ── Khung trích dẫn trong bubble ────────────────────────────────────────────

class ReplyQuote extends StatelessWidget {
  final String replyToId;
  final bool onMineBubble;
  final bool isDark;
  final String myId;
  final VoidCallback onTap;

  const ReplyQuote({
    super.key,
    required this.replyToId,
    required this.onMineBubble,
    required this.isDark,
    required this.myId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ChatBloc>();
    ChatMessage? local;
    for (final m in bloc.state.activeMessages) {
      if (m.id == replyToId) {
        local = m;
        break;
      }
    }
    if (local != null) return _body(context, local);

    // Tin gốc ở trang cũ chưa nạp lên màn hình — đọc thẳng từ DB.
    return FutureBuilder<ChatMessage?>(
      future: bloc.chatRepository.getMessageById(replyToId),
      builder: (context, snap) => _body(context, snap.data),
    );
  }

  Widget _body(BuildContext context, ChatMessage? m) {
    final accent = ChatTheme.getAccent(isDark);
    final bar = onMineBubble ? Colors.white : accent;
    final text = onMineBubble ? Colors.white : ChatTheme.getTextPrimary(isDark);

    return GestureDetector(
      onTap: m == null ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: (onMineBubble ? Colors.white : accent).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: bar, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m == null ? '' : senderLabel(context, m.senderId, myId),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: bar),
            ),
            Text(
              m == null
                  ? context.tr('chat_reply_original_missing')
                  : messagePreview(context, m),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: m == null || m.isDeleted ? FontStyle.italic : null,
                color: text.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cảm xúc dưới bubble ─────────────────────────────────────────────────────

class ReactionsRow extends StatelessWidget {
  final List<ChatReaction> reactions;
  final String myId;
  final bool isDark;
  final void Function(String emoji) onTap;

  const ReactionsRow({
    super.key,
    required this.reactions,
    required this.myId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    String? mine;
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
      if (r.userId == myId) mine = r.emoji;
    }
    final accent = ChatTheme.getAccent(isDark);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final e in counts.entries)
          GestureDetector(
            onTap: () => onTap(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: e.key == mine
                    ? accent.withValues(alpha: 0.25)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                border: Border.all(
                    color: e.key == mine ? accent : Colors.transparent),
              ),
              child: Text(
                e.value > 1 ? '${e.key} ${e.value}' : e.key,
                style: TextStyle(
                    fontSize: 13, color: ChatTheme.getTextPrimary(isDark)),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Thanh tin ghim ──────────────────────────────────────────────────────────

class PinnedMessagesBar extends StatefulWidget {
  final List<ChatMessage> pinned; // mới ghim trước
  final bool isDark;
  final void Function(ChatMessage message) onTap;
  final void Function(ChatMessage message) onUnpin;

  const PinnedMessagesBar({
    super.key,
    required this.pinned,
    required this.isDark,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  State<PinnedMessagesBar> createState() => _PinnedMessagesBarState();
}

class _PinnedMessagesBarState extends State<PinnedMessagesBar> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.pinned.isEmpty) return const SizedBox.shrink();
    final i = _index % widget.pinned.length;
    final m = widget.pinned[i];
    final accent = ChatTheme.getAccent(widget.isDark);

    return Material(
      color: widget.isDark ? ChatTheme.bgBubbleTheirsDark : Colors.white,
      child: InkWell(
        onTap: () {
          widget.onTap(m);
          if (widget.pinned.length > 1) {
            setState(() => _index = (i + 1) % widget.pinned.length);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: widget.isDark
                      ? Colors.grey.shade900
                      : Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Container(width: 3, height: 32, color: accent),
              const SizedBox(width: 10),
              Icon(Icons.push_pin_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pinned.length > 1
                          ? '${context.tr('chat_pinned_message')} (${i + 1}/${widget.pinned.length})'
                          : context.tr('chat_pinned_message'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: accent),
                    ),
                    Text(
                      messagePreview(context, m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: ChatTheme.getTextPrimary(widget.isDark)),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded,
                    size: 18, color: ChatTheme.getTextMuted(widget.isDark)),
                onPressed: () => widget.onUnpin(m),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Thanh ngữ cảnh phía trên ô soạn (đang trả lời / đang sửa) ─────────────────

class ComposerContextBar extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onCancel;

  const ComposerContextBar({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ChatTheme.getAccent(isDark);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accent)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: ChatTheme.getTextPrimary(isDark))),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded,
                size: 18, color: ChatTheme.getTextMuted(isDark)),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ── Chọn nơi chuyển tiếp ────────────────────────────────────────────────────

/// Chọn người nhận khi chuyển tiếp. Trả về danh sách người dùng đã chọn, hoặc
/// null nếu huỷ. Chuyển tiếp đi vào hội thoại 1-1 với từng người (E2EE).
Future<List<User>?> pickForwardTargets(
    BuildContext context, String myId) async {
  final contacts = context
      .read<ChatBloc>()
      .state
      .contacts
      .where((u) => u.id != myId)
      .toList();
  final selected = <String>{};

  return showDialog<List<User>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.tr('chat_forward_to')),
        content: SizedBox(
          width: 360,
          child: contacts.isEmpty
              ? Text(context.tr('chat_reply_original_missing'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final u in contacts)
                      CheckboxListTile(
                        dense: true,
                        value: selected.contains(u.id),
                        title: Text(u.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            selected.add(u.id);
                          } else {
                            selected.remove(u.id);
                          }
                        }),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('chat_cancel')),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(dialogContext,
                    contacts.where((u) => selected.contains(u.id)).toList()),
            child: Text(context.tr('chat_forward_send')),
          ),
        ],
      ),
    ),
  );
}
