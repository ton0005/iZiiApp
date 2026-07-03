import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class ChatTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, List<Map<String, String>>> chatHistory;
  final String activeChatContact;
  final String activeRole;
  final Function(String) onContactSelected;
  final Function(String) onSendMessage;

  const ChatTabScreen({
    super.key,
    required this.isDark,
    required this.chatHistory,
    required this.activeChatContact,
    required this.activeRole,
    required this.onContactSelected,
    required this.onSendMessage,
  });

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _chatInputController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chatHistory[widget.activeChatContact] ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border.all(color: FarmColors.borderLight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left list of chats
            Container(
              width: 250,
              decoration: const BoxDecoration(
                  border:
                      Border(right: BorderSide(color: FarmColors.borderLight))),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Cuộc trò chuyện (E2EE)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      children: widget.chatHistory.keys.map((contact) {
                        final isSel = widget.activeChatContact == contact;
                        final lastMsg = widget.chatHistory[contact]!.last['text'];
                        return ListTile(
                          selected: isSel,
                          selectedTileColor:
                              FarmColors.forestGreenLight.withOpacity(0.4),
                          leading: CircleAvatar(
                              backgroundColor: FarmColors.forestGreen,
                              child: Text(contact[0],
                                  style: const TextStyle(color: Colors.white))),
                          title: Text(contact,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(lastMsg ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => widget.onContactSelected(contact),
                        );
                      }).toList(),
                    ),
                  )
                ],
              ),
            ),
            // Right chat pane
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: FarmColors.borderLight)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text('Kênh mật mã E2EE: ${widget.activeChatContact}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Container(
                      color: widget.isDark ? Colors.black26 : Colors.grey.shade50,
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        controller: _chatScrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, idx) {
                          final msg = messages[idx];
                          final isVinh = msg['sender'] == 'Vinh';
                          return Align(
                            alignment: isVinh
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isVinh
                                    ? FarmColors.forestGreen
                                    : (widget.isDark
                                        ? const Color(0xFF333333)
                                        : Colors.white),
                                border: isVinh
                                    ? null
                                    : Border.all(color: FarmColors.borderLight),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isVinh
                                      ? const Radius.circular(12)
                                      : const Radius.circular(2),
                                  bottomRight: isVinh
                                      ? const Radius.circular(2)
                                      : const Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isVinh
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text('${msg['sender']} (${msg['role']})',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isVinh
                                              ? Colors.white70
                                              : Colors.grey,
                                          fontSize: 9)),
                                  const SizedBox(height: 4),
                                  Text(msg['text'] ?? '',
                                      style: TextStyle(
                                          color: isVinh
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text('${msg['time']} · E2EE Mật mã',
                                      style: TextStyle(
                                          fontSize: 8,
                                          color: isVinh
                                              ? Colors.white60
                                              : Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: FarmColors.borderLight)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _chatInputController,
                            decoration: const InputDecoration(
                                hintText: 'Nhập tin nhắn mật mã...',
                                border: InputBorder.none),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send,
                              color: FarmColors.forestGreen),
                          onPressed: _submit,
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
