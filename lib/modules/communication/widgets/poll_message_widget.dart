import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';

/// Dữ liệu một lựa chọn bình chọn (Poll Option)
class PollOption {
  final String id;
  final String text;
  final List<String> voterIds;

  const PollOption({
    required this.id,
    required this.text,
    this.voterIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'voter_ids': voterIds,
      };

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
        id: map['id']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        voterIds: (map['voter_ids'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// Widget hiển thị bình chọn (Interactive Poll Widget) ngay trong bong bóng chat.
class PollMessageWidget extends StatelessWidget {
  final String question;
  final List<PollOption> options;
  final bool allowMultiple;
  final String currentUserId;
  final bool isDark;
  final bool isMe;
  final ValueChanged<String> onVote;

  const PollMessageWidget({
    super.key,
    required this.question,
    required this.options,
    this.allowMultiple = false,
    required this.currentUserId,
    required this.isDark,
    required this.isMe,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ChatTheme.getAccent(isDark);
    final totalVotes = options.fold<int>(0, (sum, opt) => sum + opt.voterIds.length);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, color: isMe ? Colors.white : accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isMe ? Colors.white : ChatTheme.getTextPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            allowMultiple ? 'Multiple choices allowed • $totalVotes votes' : 'Single choice • $totalVotes votes',
            style: TextStyle(
              fontSize: 11,
              color: isMe ? Colors.white70 : ChatTheme.getTextMuted(isDark),
            ),
          ),
          const SizedBox(height: 10),

          // Danh sách các lựa chọn
          ...options.map((opt) {
            final hasVoted = opt.voterIds.contains(currentUserId);
            final percent = totalVotes > 0 ? (opt.voterIds.length / totalVotes) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isMe ? Colors.white.withValues(alpha: 0.15) : (isDark ? Colors.black26 : Colors.grey.shade100),
                border: Border.all(
                  color: hasVoted ? (isMe ? Colors.white : accent) : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  width: hasVoted ? 1.5 : 0.8,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onVote(opt.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasVoted
                                  ? (allowMultiple ? Icons.check_box_rounded : Icons.radio_button_checked_rounded)
                                  : (allowMultiple ? Icons.check_box_outline_blank_rounded : Icons.radio_button_off_rounded),
                              size: 18,
                              color: hasVoted ? (isMe ? Colors.white : accent) : (isMe ? Colors.white60 : ChatTheme.getTextMuted(isDark)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                opt.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                                  color: isMe ? Colors.white : ChatTheme.getTextPrimary(isDark),
                                ),
                              ),
                            ),
                            Text(
                              '${(percent * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.white : accent,
                              ),
                            ),
                          ],
                        ),
                        if (totalVotes > 0) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 5,
                              backgroundColor: isMe ? Colors.white24 : Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(isMe ? Colors.white : accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
