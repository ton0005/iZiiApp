import 'package:flutter/material.dart';
import '../../communication/screens/chat_inbox_screen.dart';

class ChatTabScreen extends StatelessWidget {
  final bool isDark;

  const ChatTabScreen({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return const ChatInboxScreen(embedded: true);
  }
}
