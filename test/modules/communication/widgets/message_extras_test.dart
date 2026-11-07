// test/modules/communication/widgets/message_extras_test.dart
//
// Các thành phần giao diện Phase 1: cảm xúc, thanh ghim, thanh ngữ cảnh soạn tin.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/modules/communication/widgets/message_extras.dart';

ChatMessage _msg(String id, String text, {DateTime? pinnedAt}) => ChatMessage(
      id: id,
      conversationId: 'direct_a_b',
      senderId: 'a',
      type: 'text',
      content: '{"text":"$text"}',
      sentAt: DateTime(2026, 11, 1),
      isDeleted: false,
      pinnedAt: pinnedAt,
    );

ChatReaction _react(String user, String emoji) => ChatReaction(
      messageId: 'm1',
      userId: user,
      emoji: emoji,
      reactedAt: DateTime(2026, 11, 1),
    );

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('ReactionsRow', () {
    testWidgets('gộp cảm xúc giống nhau và hiện số lượng', (tester) async {
      await tester.pumpWidget(_host(ReactionsRow(
        reactions: [_react('a', '👍'), _react('b', '👍'), _react('c', '❤️')],
        myId: 'a',
        isDark: false,
        onTap: (_) {},
      )));
      expect(find.text('👍 2'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
    });

    testWidgets('bấm vào một cảm xúc báo đúng emoji', (tester) async {
      String? tapped;
      await tester.pumpWidget(_host(ReactionsRow(
        reactions: [_react('b', '😂')],
        myId: 'a',
        isDark: true,
        onTap: (e) => tapped = e,
      )));
      await tester.tap(find.text('😂'));
      expect(tapped, '😂');
    });
  });

  group('PinnedMessagesBar', () {
    testWidgets('rỗng thì không chiếm chỗ', (tester) async {
      await tester.pumpWidget(_host(PinnedMessagesBar(
          pinned: const [], isDark: false, onTap: (_) {}, onUnpin: (_) {})));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('nhiều tin ghim: bấm lần lượt đi qua từng tin', (tester) async {
      final tapped = <String>[];
      final pinned = [_msg('m2', 'hai'), _msg('m1', 'một')];
      await tester.pumpWidget(_host(PinnedMessagesBar(
        pinned: pinned,
        isDark: false,
        onTap: (m) => tapped.add(m.id),
        onUnpin: (_) {},
      )));
      expect(find.text('hai'), findsOneWidget);
      expect(find.textContaining('(1/2)'), findsOneWidget);

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(find.text('một'), findsOneWidget);
      expect(find.textContaining('(2/2)'), findsOneWidget);

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(tapped, ['m2', 'm1']);
      expect(find.text('hai'), findsOneWidget, reason: 'quay vòng');
    });

    testWidgets('nút đóng bỏ ghim đúng tin đang hiện', (tester) async {
      ChatMessage? unpinned;
      await tester.pumpWidget(_host(PinnedMessagesBar(
        pinned: [_msg('m1', 'một')],
        isDark: false,
        onTap: (_) {},
        onUnpin: (m) => unpinned = m,
      )));
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(unpinned?.id, 'm1');
    });
  });

  group('ComposerContextBar', () {
    testWidgets('hiện tiêu đề, nội dung và huỷ được', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(_host(ComposerContextBar(
        icon: Icons.reply_rounded,
        title: 'Trả lời Bob',
        subtitle: 'xin chào',
        isDark: false,
        onCancel: () => cancelled = true,
      )));
      expect(find.text('Trả lời Bob'), findsOneWidget);
      expect(find.text('xin chào'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cancelled, isTrue);
    });
  });

  test('decodeMessageContent chịu được JSON hỏng', () {
    expect(decodeMessageContent('không phải json'), isEmpty);
    expect(decodeMessageContent('[1,2]'), isEmpty);
    expect(decodeMessageContent('{"text":"a"}')['text'], 'a');
    expect(messageText(_msg('m', 'xin chào')), 'xin chào');
  });
}
