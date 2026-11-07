// test/modules/communication/direct_e2ee_channel_test.dart
//
// Kênh E2EE cho tin 1-1:
// 1. Gửi: không bao giờ rơi về plaintext; chưa gửi được thì nằm chờ, giữ thứ tự.
// 2. Nhận: đối chiếu hội thoại + thành viên; chỉ người gửi gốc mới sửa/thu hồi.
// 3. Idempotent: phát lại không hồi sinh tin đã thu hồi.
// Mã hoá thật được thay bằng đối tượng giả — phần mật mã đã có test riêng.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:izii_app/core/database/app_database.dart';
import 'package:izii_app/core/device_identity/device_identity_models.dart';
import 'package:izii_app/modules/communication/models/chat_envelope.dart';
import 'package:izii_app/modules/communication/repository/chat_repository.dart';
import 'package:izii_app/modules/communication/services/direct_e2ee_channel.dart';

RemoteDevice _device(String id, {bool revoked = false}) => RemoteDevice(
      deviceId: id,
      userId: id,
      publicKeyBase64: 'pk-$id',
      signingPublicKeyBase64: 'sk-$id',
      deviceName: id,
      platform: 'android',
      registeredAt: DateTime(2026),
      isRevoked: revoked,
    );

void main() {
  const convo = 'direct_alice_bob';
  final t0 = DateTime.now().subtract(const Duration(hours: 1));

  late AppDatabase db;
  late ChatRepository repo;

  // Điều khiển được từ test.
  var serverUp = true;
  var knownDevices = <String, RemoteDevice>{'bob': _device('bob')};
  late List<({String conv, Map<String, String> plaintexts})> relayed;

  DirectE2eeChannel makeChannel() => DirectE2eeChannel(
        repo: repo,
        resolveRecipients: (peer) async =>
            knownDevices[peer] == null ? [] : [knownDevices[peer]!],
        encrypt: (plaintext, to) async => EncryptedPayload(
          ciphertextBase64: plaintext, // "mã hoá" giả: giữ nguyên để test đọc lại
          nonceBase64: 'n',
          senderDeviceId: 'alice',
          signatureBase64: 's',
          sentAt: DateTime.now(),
        ),
        relay: ({
          required conversationId,
          required recipientDeviceIds,
          required payloads,
        }) async {
          if (!serverUp) return false;
          relayed.add((
            conv: conversationId,
            plaintexts: payloads.map((k, v) => MapEntry(k, v.ciphertextBase64)),
          ));
          return true;
        },
      );

  ChatEnvelope msg(String id, String text, {DateTime? ts}) =>
      ChatEnvelope.message(
        id: id,
        conversationId: convo,
        type: 'text',
        content: {'text': text},
        ts: ts ?? t0,
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.testInstance = db;
    repo = ChatRepository(db);
    serverUp = true;
    knownDevices = {'bob': _device('bob')};
    relayed = [];
  });

  tearDown(() async => db.close());

  group('ChatEnvelope', () {
    test('khứ hồi mọi loại', () {
      final all = [
        msg('m1', 'xin chào'),
        ChatEnvelope.edit(
            id: 'e1', conversationId: convo, targetId: 'm1', newText: 'x', ts: t0),
        ChatEnvelope.revoke(id: 'r1', conversationId: convo, targetId: 'm1', ts: t0),
        ChatEnvelope.reaction(
            id: 'x1', conversationId: convo, targetId: 'm1', emoji: '👍', ts: t0),
        ChatEnvelope.pin(
            id: 'p1', conversationId: convo, targetId: 'm1', pinned: true, ts: t0),
      ];
      for (final e in all) {
        final back = ChatEnvelope.fromJson(e.toJson());
        expect(back.kind, e.kind);
        expect(back.id, e.id);
        expect(back.conversationId, convo);
        expect(back.targetId, e.targetId);
      }
    });

    test('từ chối văn bản thuần, JSON lạ, phiên bản sai, thiếu trường', () {
      expect(() => ChatEnvelope.fromJson('xin chào'), throwsFormatException);
      expect(() => ChatEnvelope.fromJson('[]'), throwsFormatException);
      expect(() => ChatEnvelope.fromJson('{"v":2,"k":"message"}'),
          throwsFormatException);
      expect(() => ChatEnvelope.fromJson('{"v":1,"k":"nuke","c":"a","id":"b","ts":"2026-01-01"}'),
          throwsFormatException);
      expect(
          () => ChatEnvelope.fromJson(
              '{"v":1,"k":"edit","c":"a","id":"b","ts":"2026-01-01T00:00:00Z"}'),
          throwsFormatException,
          reason: 'edit thiếu target');
    });
  });

  group('gửi', () {
    test('gửi thành công: bản mã chứa phong bì, hàng đợi rỗng', () async {
      final ch = makeChannel();
      await ch.send(msg('m1', 'hi'), myId: 'alice');

      expect(relayed.single.conv, convo);
      expect(relayed.single.plaintexts.keys, ['bob']);
      expect(ChatEnvelope.fromJson(relayed.single.plaintexts['bob']!).id, 'm1');
      expect(await repo.pendingE2eeIds(), isEmpty);
    });

    test('server sập: nằm chờ trong hàng đợi, không gửi gì, rồi gửi bù theo thứ tự', () async {
      final ch = makeChannel();
      serverUp = false;
      await ch.send(msg('m1', 'một', ts: t0), myId: 'alice');
      await ch.send(msg('m2', 'hai', ts: t0.add(const Duration(seconds: 1))),
          myId: 'alice');

      expect(relayed, isEmpty);
      expect(await repo.pendingE2eeIds(), {'m1', 'm2'});
      final row = (await repo.pendingE2ee()).first;
      expect(row.attempts, greaterThan(0));

      serverUp = true;
      expect(await ch.flush(myId: 'alice'), 2);
      expect(relayed.map((r) => ChatEnvelope.fromJson(r.plaintexts['bob']!).id),
          ['m1', 'm2'], reason: 'giữ nguyên thứ tự gửi');
      expect(await repo.pendingE2eeIds(), isEmpty);
    });

    test('chưa có khoá người nhận: chờ, KHÔNG gửi plaintext', () async {
      knownDevices = {};
      final ch = makeChannel();
      await ch.send(msg('m1', 'bí mật'), myId: 'alice');

      expect(relayed, isEmpty);
      expect(await repo.pendingE2eeIds(), {'m1'});
      expect((await repo.pendingE2ee()).single.lastError, contains('bob'));

      knownDevices = {'bob': _device('bob')};
      expect(await ch.flush(myId: 'alice'), 1);
    });

    test('thiết bị bị thu hồi không nhận được tin', () async {
      knownDevices = {'bob': _device('bob', revoked: true)};
      final ch = DirectE2eeChannel(
        repo: repo,
        resolveRecipients: (peer) async =>
            knownDevices[peer]!.isRevoked ? [] : [knownDevices[peer]!],
        encrypt: (p, to) async => throw StateError('không được mã hoá cho máy đã thu hồi'),
        relay: ({required conversationId, required recipientDeviceIds, required payloads}) async => true,
      );
      await ch.send(msg('m1', 'x'), myId: 'alice');
      expect(await repo.pendingE2eeIds(), {'m1'});
    });

    test('một tin lỗi chặn tin sau CỦA CÙNG hội thoại nhưng không chặn hội thoại khác', () async {
      knownDevices = {'bob': _device('bob'), 'carol': _device('carol')};
      var failBob = true;
      final ch = DirectE2eeChannel(
        repo: repo,
        resolveRecipients: (peer) async => [knownDevices[peer]!],
        encrypt: (p, to) async => EncryptedPayload(
            ciphertextBase64: p,
            nonceBase64: 'n',
            senderDeviceId: 'alice',
            signatureBase64: 's',
            sentAt: DateTime.now()),
        relay: ({required conversationId, required recipientDeviceIds, required payloads}) async {
          if (conversationId == convo && failBob) return false;
          relayed.add((conv: conversationId, plaintexts: {}));
          return true;
        },
      );
      await repo.enqueueE2ee(msg('b1', 'a', ts: t0));
      await repo.enqueueE2ee(msg('b2', 'b', ts: t0.add(const Duration(seconds: 1))));
      await repo.enqueueE2ee(ChatEnvelope.message(
          id: 'c1', conversationId: 'direct_alice_carol', type: 'text',
          content: {'text': 'c'}, ts: t0.add(const Duration(seconds: 2))));

      expect(await ch.flush(myId: 'alice'), 1);
      expect(relayed.single.conv, 'direct_alice_carol');
      expect(await repo.pendingE2eeIds(), {'b1', 'b2'});

      failBob = false;
      expect(await ch.flush(myId: 'alice'), 2);
    });

    test('phong bì không thuộc máy này bị dọn, không kẹt hàng đợi', () async {
      await repo.enqueueE2ee(ChatEnvelope.message(
          id: 'x', conversationId: 'direct_zed_yan', type: 'text',
          content: {'text': 'x'}, ts: t0));
      await makeChannel().flush(myId: 'alice');
      expect(await repo.pendingE2eeIds(), isEmpty);
      expect(relayed, isEmpty);
    });
  });

  group('nhận', () {
    Future<IncomingResult> receive(ChatEnvelope e,
            {String conv = convo,
            Set<String> sender = const {'bob'},
            Set<String> me = const {'alice'}}) =>
        makeChannel().processIncoming(
            conversationId: conv,
            plaintext: e.toJson(),
            senderIds: sender,
            myIds: me,
            receivedAt: DateTime.now());

    test('nhận tin: lưu với senderId của người gửi đã xác thực, id giữ nguyên', () async {
      final r = await receive(msg('m1', 'chào'));
      expect(r.outcome, EnvelopeOutcome.applied);
      final saved = await repo.getMessageById('m1');
      expect(saved!.senderId, 'bob');
      expect(jsonDecode(saved.content)['text'], 'chào');
      expect(saved.deliveredAt, isNotNull);
    });

    test('gửi lại cùng phong bì → duplicate, không nhân đôi', () async {
      await receive(msg('m1', 'a'));
      final again = await receive(msg('m1', 'a'));
      expect(again.outcome, EnvelopeOutcome.duplicate);
      expect((await repo.getMessages(convo)).length, 1);
    });

    test('server lái bản mã sang hội thoại khác → từ chối', () async {
      final r = await receive(msg('m1', 'a'), conv: 'direct_alice_carol');
      expect(r.rejectReason, 'conversation_mismatch');
      expect(await repo.getMessageById('m1'), isNull);
    });

    test('người gửi không thuộc hội thoại → từ chối', () async {
      final r = await receive(msg('m1', 'a'), sender: {'mallory'});
      expect(r.rejectReason, 'not_member');
    });

    test('tôi không thuộc hội thoại → từ chối', () async {
      final r = await receive(msg('m1', 'a'), me: {'dave'});
      expect(r.rejectReason, 'not_member');
    });

    test('văn bản thuần (không phải phong bì) → từ chối, không hiện thành tin', () async {
      final r = await makeChannel().processIncoming(
          conversationId: convo,
          plaintext: 'tin plaintext kiểu cũ',
          senderIds: {'bob'},
          myIds: {'alice'});
      expect(r.rejectReason, startsWith('malformed'));
      expect(await repo.getMessages(convo), isEmpty);
    });

    test('hội thoại cũ dùng mã người dùng thay device_id vẫn nhận được', () async {
      const legacy = 'direct_EMP001_EMP002';
      final env = ChatEnvelope.message(
          id: 'm1', conversationId: legacy, type: 'text', content: {'text': 'a'}, ts: t0);
      final r = await makeChannel().processIncoming(
          conversationId: legacy,
          plaintext: env.toJson(),
          senderIds: {'izii-d-aaaa', 'EMP002'}, // device_id + userId đăng ký
          myIds: {'izii-d-bbbb', 'EMP001'});
      expect(r.senderId, 'EMP002');
      expect(r.outcome, EnvelopeOutcome.applied);
    });

    group('sửa / thu hồi / cảm xúc / ghim', () {
      setUp(() async {
        await receive(msg('m1', 'gốc')); // tin của bob
      });

      test('người gửi gốc sửa được; có editedAt; giữ phần còn lại của content', () async {
        final r = await receive(ChatEnvelope.edit(
            id: 'e1', conversationId: convo, targetId: 'm1', newText: 'đã sửa',
            ts: t0.add(const Duration(minutes: 1))));
        expect(r.outcome, EnvelopeOutcome.applied);
        final m = (await repo.getMessageById('m1'))!;
        expect(jsonDecode(m.content)['text'], 'đã sửa');
        expect(m.editedAt, isNotNull);
      });

      test('người KHÁC không sửa/thu hồi được tin của bob', () async {
        // alice (tôi) cố sửa tin của bob bằng cách tự gửi sự kiện vào máy mình
        final edit = await repo.applyEnvelope(
            ChatEnvelope.edit(
                id: 'e1', conversationId: convo, targetId: 'm1', newText: 'hack', ts: t0),
            senderId: 'alice');
        final revoke = await repo.applyEnvelope(
            ChatEnvelope.revoke(id: 'r1', conversationId: convo, targetId: 'm1', ts: t0),
            senderId: 'alice');
        expect(edit, EnvelopeOutcome.ignored);
        expect(revoke, EnvelopeOutcome.ignored);
        final m = (await repo.getMessageById('m1'))!;
        expect(jsonDecode(m.content)['text'], 'gốc');
        expect(m.isDeleted, isFalse);
      });

      test('sửa cũ hơn bản đã sửa bị bỏ (đến sai thứ tự)', () async {
        await receive(ChatEnvelope.edit(id: 'e2', conversationId: convo,
            targetId: 'm1', newText: 'mới', ts: t0.add(const Duration(minutes: 5))));
        final stale = await receive(ChatEnvelope.edit(id: 'e1', conversationId: convo,
            targetId: 'm1', newText: 'cũ', ts: t0.add(const Duration(minutes: 2))));
        expect(stale.outcome, EnvelopeOutcome.ignored);
        expect(jsonDecode((await repo.getMessageById('m1'))!.content)['text'], 'mới');
      });

      test('thu hồi xoá sạch nội dung + cảm xúc + ghim; phát lại không hồi sinh', () async {
        await receive(ChatEnvelope.reaction(id: 'x', conversationId: convo,
            targetId: 'm1', emoji: '👍', ts: t0));
        await receive(ChatEnvelope.pin(id: 'p', conversationId: convo,
            targetId: 'm1', pinned: true, ts: t0));
        await receive(ChatEnvelope.revoke(
            id: 'r1', conversationId: convo, targetId: 'm1', ts: t0));

        final m = (await repo.getMessageById('m1'))!;
        expect(m.isDeleted, isTrue);
        expect(m.content, '{}');
        expect(m.pinnedAt, isNull);
        expect((await repo.getReactionsFor(['m1'])), isEmpty);

        // Phát lại phong bì tin gốc → không được hồi sinh.
        final replay = await receive(msg('m1', 'gốc'));
        expect(replay.outcome, EnvelopeOutcome.duplicate);
        expect((await repo.getMessageById('m1'))!.isDeleted, isTrue);
      });

      test('không sửa / thả cảm xúc / ghim tin đã thu hồi', () async {
        await receive(ChatEnvelope.revoke(
            id: 'r1', conversationId: convo, targetId: 'm1', ts: t0));
        for (final e in [
          ChatEnvelope.edit(id: 'e', conversationId: convo, targetId: 'm1',
              newText: 'x', ts: t0.add(const Duration(minutes: 1))),
          ChatEnvelope.reaction(id: 'x', conversationId: convo, targetId: 'm1',
              emoji: '👍', ts: t0),
          ChatEnvelope.pin(id: 'p', conversationId: convo, targetId: 'm1',
              pinned: true, ts: t0),
        ]) {
          expect((await receive(e)).outcome, EnvelopeOutcome.ignored);
        }
      });

      test('cảm xúc: mỗi người một cảm xúc, đổi được, gỡ được', () async {
        await receive(ChatEnvelope.reaction(id: 'x1', conversationId: convo,
            targetId: 'm1', emoji: '👍', ts: t0));
        await repo.applyEnvelope(
            ChatEnvelope.reaction(id: 'x2', conversationId: convo,
                targetId: 'm1', emoji: '❤️', ts: t0),
            senderId: 'alice');
        var r = (await repo.getReactionsFor(['m1']))['m1']!;
        expect({for (final x in r) x.userId: x.emoji}, {'bob': '👍', 'alice': '❤️'});

        await receive(ChatEnvelope.reaction(id: 'x3', conversationId: convo,
            targetId: 'm1', emoji: '😂', ts: t0.add(const Duration(seconds: 5))));
        r = (await repo.getReactionsFor(['m1']))['m1']!;
        expect(r.firstWhere((x) => x.userId == 'bob').emoji, '😂');

        await receive(ChatEnvelope.reaction(id: 'x4', conversationId: convo,
            targetId: 'm1', emoji: '', ts: t0.add(const Duration(seconds: 9))));
        r = (await repo.getReactionsFor(['m1']))['m1']!;
        expect(r.map((x) => x.userId), ['alice']);
      });

      test('emoji quá dài bị bỏ', () async {
        final r = await receive(ChatEnvelope.reaction(id: 'x', conversationId: convo,
            targetId: 'm1', emoji: 'a' * 50, ts: t0));
        expect(r.outcome, EnvelopeOutcome.ignored);
      });

      test('ghim và bỏ ghim', () async {
        await receive(ChatEnvelope.pin(id: 'p1', conversationId: convo,
            targetId: 'm1', pinned: true, ts: t0));
        expect((await repo.getPinnedMessages(convo)).map((m) => m.id), ['m1']);
        await receive(ChatEnvelope.pin(id: 'p2', conversationId: convo,
            targetId: 'm1', pinned: false, ts: t0.add(const Duration(seconds: 1))));
        expect(await repo.getPinnedMessages(convo), isEmpty);
      });

      test('sự kiện nhắm tin chưa tới / sai hội thoại bị bỏ', () async {
        expect(
            (await receive(ChatEnvelope.revoke(
                    id: 'r', conversationId: convo, targetId: 'chua-co', ts: t0)))
                .outcome,
            EnvelopeOutcome.ignored);
        // tin m1 thuộc `convo`; phong bì khai hội thoại khác dù id đúng
        final other = await repo.applyEnvelope(
            ChatEnvelope.revoke(
                id: 'r', conversationId: 'direct_alice_carol', targetId: 'm1', ts: t0),
            senderId: 'bob');
        expect(other, EnvelopeOutcome.ignored);
      });
    });

    test('ts từ tương lai bị kẹp về hiện tại', () async {
      await receive(msg('m1', 'a', ts: DateTime.now().add(const Duration(days: 30))));
      final m = (await repo.getMessageById('m1'))!;
      expect(m.sentAt.isBefore(DateTime.now().add(const Duration(minutes: 1))), isTrue);
    });
  });

  test('queueMessageOffline từ chối tin 1-1 (chốt chặn plaintext)', () async {
    await repo.queueMessageOffline(ChatMessage(
      id: 'm1', conversationId: convo, senderId: 'alice', type: 'text',
      content: '{"text":"bí mật"}', sentAt: t0, isDeleted: false,
    ));
    expect(await db.select(db.outboxMutations).get(), isEmpty);

    await repo.queueMessageOffline(ChatMessage(
      id: 'm2', conversationId: 'record-uuid', senderId: 'alice', type: 'text',
      content: '{"text":"ok"}', sentAt: t0, isDeleted: false,
    ));
    expect(await db.select(db.outboxMutations).get(), hasLength(1));
  });

  test('directPeer', () {
    expect(ChatRepository.directPeer('direct_alice_bob', 'alice'), 'bob');
    expect(ChatRepository.directPeer('direct_alice_bob', 'bob'), 'alice');
    expect(ChatRepository.directPeer('direct_alice_bob', 'eve'), isNull);
    expect(ChatRepository.directPeer('direct_EMP_007_izii-d-ab12', 'EMP_007'),
        'izii-d-ab12');
    expect(ChatRepository.directPeer('direct_EMP_007_izii-d-ab12', 'izii-d-ab12'),
        'EMP_007');
  });
}
