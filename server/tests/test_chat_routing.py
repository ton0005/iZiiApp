# server/tests/test_chat_routing.py
"""
Chat chỉ được giao cho thành viên hội thoại (chat_access.py, chat_ws.py,
routers/conversations.py, lọc chat trong /sync/pull).

Đặc tả hành vi:
1. Hội thoại 1-1 `direct_<a>_<b>`: thành viên suy ra từ id, kể cả khi id chứa '_'.
2. WS: gói có conversation_id chỉ tới socket của thành viên; socket chưa khai
   danh tính không nhận; người ngoài gửi vào hoặc mạo danh sender bị bỏ.
3. Hội thoại chưa đăng ký → phát rộng kiểu cũ (tương thích bản app cũ).
4. Tín hiệu gọi có target_id → chỉ tới máy đích nếu máy đó đang kết nối.
5. PUT /api/v1/conversations: bắt buộc device token; người ngoài không được
   ghi đè thành viên; người tạo luôn là thành viên; loại khỏi nhóm = left_at.
6. /sync/pull: máy đã xác thực không nhận chat của hội thoại không thuộc về.
"""
import asyncio
import json
import os
import sqlite3
import unittest
from unittest import mock

from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

import chat_access
from chat_ws import ChatConnectionManager
from server_config import CONFIG

_MIGRATION = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "migrations", "versions", "0013_chat_core.sql",
)


# .env trên máy dev có thể đặt backend=postgres — sql() sẽ đổi '?' thành '%s'
# và hỏng truy vấn trên SQLite in-memory.
_backend_patch = mock.patch.object(CONFIG, "db_backend", "sqlite")


def setUpModule():
    _backend_patch.start()


def tearDownModule():
    _backend_patch.stop()


def _make_db() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    with open(_MIGRATION, encoding="utf-8") as f:
        conn.executescript(f.read())
    return conn


class FakeSocket:
    def __init__(self, name):
        self.name = name
        self.received = []

    async def send_text(self, text):
        self.received.append(json.loads(text) if text.startswith("{") else text)


def _run(coro):
    return asyncio.run(coro)


class TestChatAccess(unittest.TestCase):
    def test_direct_member_handles_underscores(self):
        cid = "direct_EMP_007_izii-d-ab12"
        self.assertTrue(chat_access.is_direct_member(cid, "EMP_007"))
        self.assertTrue(chat_access.is_direct_member(cid, "izii-d-ab12"))
        self.assertFalse(chat_access.is_direct_member(cid, "EMP"))
        self.assertFalse(chat_access.is_direct_member(cid, "007"))
        self.assertFalse(chat_access.is_direct_member("group-1", "EMP_007"))

    def test_upsert_and_leave(self):
        conn = _make_db()
        self.assertIsNone(chat_access.get_members(conn, "g1"))
        self.assertIsNone(chat_access.can_access(conn, "g1", "a"))

        chat_access.upsert_conversation(conn, "g1", conv_type="group",
                                        created_by="a", members=["a", "b", "c"])
        self.assertEqual(chat_access.get_members(conn, "g1"), {"a", "b", "c"})

        chat_access.upsert_conversation(conn, "g1", conv_type="group",
                                        created_by="a", members=["a", "b"])
        self.assertEqual(chat_access.get_members(conn, "g1"), {"a", "b"})
        self.assertFalse(chat_access.can_access(conn, "g1", "c"))
        # Lịch sử thành viên còn giữ — cần cho xoay khoá nhóm sau này.
        left = conn.execute(
            "SELECT left_at FROM chat_conversation_members WHERE member_id = 'c'"
        ).fetchone()
        self.assertIsNotNone(left["left_at"])

        # Quay lại nhóm thì left_at được xoá.
        chat_access.upsert_conversation(conn, "g1", conv_type="group",
                                        created_by="a", members=["a", "b", "c"])
        self.assertTrue(chat_access.can_access(conn, "g1", "c"))

    def test_filter_chat_updates(self):
        conn = _make_db()
        chat_access.upsert_conversation(conn, "g1", conv_type="group",
                                        created_by="a", members=["a", "b"])
        updates = [
            {"table": "chat_messages", "data": {"id": "m1", "conversation_id": "direct_a_b"}},
            {"table": "chat_messages", "data": {"id": "m2", "conversation_id": "direct_b_c"}},
            {"table": "chat_messages", "data": {"id": "m3", "conversation_id": "g1"}},
            {"table": "chat_messages", "data": {"id": "m4", "conversation_id": "unregistered"}},
            {"table": "chat_conversations", "data": {"id": "direct_b_c"}},
            {"table": "chat_messages", "data": {"id": "m5", "read_at": "x"}},
            {"table": "mushroom_jobs", "data": {"id": "j1"}},
        ]
        a_sees = {u["data"]["id"] for u in chat_access.filter_chat_updates(conn, updates, "a")}
        self.assertEqual(a_sees, {"m1", "m3", "m4", "m5", "j1"})
        c_sees = {u["data"]["id"] for u in chat_access.filter_chat_updates(conn, updates, "c")}
        self.assertEqual(c_sees, {"m2", "m4", "direct_b_c", "m5", "j1"})


class TestChatWsRouting(unittest.TestCase):
    def setUp(self):
        self.groups = {"g1": {"a", "b"}}
        self.mgr = ChatConnectionManager(membership_lookup=lambda cid: self.groups.get(cid))
        self.a, self.b, self.c, self.anon = (FakeSocket(n) for n in ("a", "b", "c", "anon"))
        self.mgr.register(self.a, "a", True)
        self.mgr.register(self.b, "b", True)
        self.mgr.register(self.c, "c", True)
        self.mgr.register(self.anon, None)

    def _send(self, ws, event, data):
        payload = {"event": event, "data": data}
        return _run(self.mgr.route(ws, json.dumps(payload), payload))

    def test_direct_message_reaches_only_companion(self):
        out = self._send(self.a, "send_message",
                         {"conversation_id": "direct_a_b", "sender_id": "a", "content": {"text": "hi"}})
        self.assertEqual(out, "routed:1")
        self.assertEqual(len(self.b.received), 1)
        self.assertEqual(self.c.received, [])
        self.assertEqual(self.anon.received, [])
        self.assertEqual(self.a.received, [])

    def test_typing_and_read_receipts_are_scoped(self):
        self._send(self.a, "typing_state",
                   {"conversation_id": "direct_a_b", "user_id": "a", "is_typing": True})
        self._send(self.b, "msg_read", {"conversation_id": "direct_a_b", "message_id": "m1"})
        self.assertEqual(len(self.a.received), 1)
        self.assertEqual(len(self.b.received), 1)
        self.assertEqual(self.c.received, [])

    def test_outsider_cannot_inject(self):
        out = self._send(self.c, "send_message",
                         {"conversation_id": "direct_a_b", "sender_id": "c"})
        self.assertEqual(out, "dropped:not_member")
        self.assertEqual(self.a.received + self.b.received, [])

    def test_spoofed_sender_is_dropped(self):
        out = self._send(self.a, "send_message",
                         {"conversation_id": "direct_a_b", "sender_id": "b"})
        self.assertEqual(out, "dropped:spoofed_sender")
        self.assertEqual(self.b.received, [])

    def test_registered_group(self):
        out = self._send(self.a, "send_message", {"conversation_id": "g1", "sender_id": "a"})
        self.assertEqual(out, "routed:1")
        self.assertEqual(len(self.b.received), 1)
        self.assertEqual(self.c.received, [])

    def test_unregistered_conversation_falls_back_to_broadcast(self):
        out = self._send(self.a, "send_message", {"conversation_id": "legacy-uuid", "sender_id": "a"})
        self.assertEqual(out, "legacy_broadcast")
        for ws in (self.b, self.c, self.anon):
            self.assertEqual(len(ws.received), 1)

    def test_membership_cache_invalidation(self):
        self._send(self.a, "send_message", {"conversation_id": "g1", "sender_id": "a"})
        self.groups["g1"] = {"a", "c"}
        self.mgr.invalidate("g1")
        self._send(self.a, "send_message", {"conversation_id": "g1", "sender_id": "a"})
        self.assertEqual(len(self.b.received), 1)
        self.assertEqual(len(self.c.received), 1)

    def test_call_signal_targets_device(self):
        out = self._send(self.a, "call_offer", {"target_id": "b", "sdp": "x"})
        self.assertEqual(out, "routed:1")
        self.assertEqual(self.c.received, [])
        # Máy đích chưa khai danh tính → vẫn phát rộng để không rớt cuộc gọi.
        out = self._send(self.a, "call_offer", {"target_id": "old-device", "sdp": "x"})
        self.assertEqual(out, "legacy_broadcast")

    def test_presence_still_broadcast(self):
        out = self._send(self.a, "presence_update", {"user_id": "a", "presence": "online_synced"})
        self.assertEqual(out, "broadcast")
        for ws in (self.b, self.c, self.anon):
            self.assertEqual(len(ws.received), 1)

    def test_disconnect_cleans_identity(self):
        self.mgr.disconnect(self.b)
        self.assertIsNone(self.mgr.member_of(self.b))
        out = self._send(self.a, "send_message", {"conversation_id": "direct_a_b", "sender_id": "a"})
        self.assertEqual(out, "routed:0")


class TestConversationsRouter(unittest.TestCase):
    def setUp(self):
        from dependencies import get_db
        from routers import conversations
        from security_auth import DeviceIdentity, optional_device

        self.conn = _make_db()
        self.invalidated = []
        app = FastAPI()
        app.include_router(conversations.router)
        app.state.ws_manager = type("M", (), {"invalidate": lambda _s, cid: self.invalidated.append(cid)})()

        def _db():
            yield self.conn

        async def _device(request: Request):
            dev = request.headers.get("X-Test-Device")
            return DeviceIdentity(device_id=dev) if dev else None

        app.dependency_overrides[get_db] = _db
        app.dependency_overrides[optional_device] = _device
        self.client = TestClient(app)

    def _put(self, cid, device, members, conv_type="group"):
        headers = {"X-Test-Device": device} if device else {}
        return self.client.put(f"/api/v1/conversations/{cid}", headers=headers,
                               json={"type": conv_type, "members": members})

    def test_requires_device_identity(self):
        self.assertEqual(self._put("g1", None, ["a"]).status_code, 401)
        self.assertEqual(self.client.get("/api/v1/conversations/g1").status_code, 401)

    def test_creator_is_always_member(self):
        r = self._put("g1", "a", ["b"])
        self.assertEqual(r.status_code, 200, r.text)
        self.assertTrue(r.json()["created"])
        self.assertEqual(chat_access.get_members(self.conn, "g1"), {"a", "b"})
        self.assertEqual(self.invalidated, ["g1"])

    def test_outsider_cannot_take_over(self):
        self._put("g1", "a", ["a", "b"])
        r = self._put("g1", "mallory", ["mallory"])
        self.assertEqual(r.status_code, 403)
        self.assertEqual(chat_access.get_members(self.conn, "g1"), {"a", "b"})
        self.assertEqual(self.client.get("/api/v1/conversations/g1",
                                         headers={"X-Test-Device": "mallory"}).status_code, 403)

    def test_member_can_update_and_read(self):
        self._put("g1", "a", ["a", "b"])
        self.assertEqual(self._put("g1", "b", ["a", "b", "c"]).status_code, 200)
        r = self.client.get("/api/v1/conversations/g1", headers={"X-Test-Device": "c"})
        self.assertEqual(r.json()["members"], ["a", "b", "c"])

    def test_direct_is_derived(self):
        self.assertEqual(self._put("direct_a_b", "a", []).json()["derived"], True)
        self.assertEqual(self._put("direct_a_b", "c", []).status_code, 403)

    def test_rejects_unknown_type(self):
        self.assertEqual(self._put("g1", "a", ["a"], conv_type="weird").status_code, 400)


class TestSyncPullChatFilter(unittest.TestCase):
    def test_filter_applies_only_to_identified_devices(self):
        from routers.sync import _filter_chat_for_device
        from security_auth import DeviceIdentity

        conn = _make_db()
        repo = type("R", (), {"conn": conn})()
        updates = [
            {"table": "chat_messages", "data": {"id": "m1", "conversation_id": "direct_a_b"}},
            {"table": "chat_messages", "data": {"id": "m2", "conversation_id": "direct_b_c"}},
        ]
        self.assertEqual(len(_filter_chat_for_device(repo, updates, None)), 2)
        seen = _filter_chat_for_device(repo, updates, DeviceIdentity(device_id="a"))
        self.assertEqual([u["data"]["id"] for u in seen], ["m1"])


class TestMessagesRouterHardening(unittest.TestCase):
    """/api/v1/messages/* khi máy có device token: không mạo danh, không đọc /
    ack hộ máy khác, không nhét bản mã vào hội thoại người khác."""

    def setUp(self):
        from dependencies import get_message_repo, get_notification_repo
        from repository.sqlite_repo import (
            SQLiteMessageRepository, SQLiteNotificationRepository)
        from routers import messages
        from security_auth import DeviceIdentity, optional_device

        self.conn = sqlite3.connect(":memory:", check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        init = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "migrations", "versions", "0001_initial_schema.sql")
        with open(init, encoding="utf-8") as f:
            self.conn.executescript(f.read())
        for dev, user in (("alice", "u-alice"), ("bob", "u-bob"), ("mallory", "u-mal")):
            self.conn.execute(
                "INSERT INTO devices (device_id, user_id, device_name) VALUES (?,?,?)",
                (dev, user, dev))
        self.conn.commit()

        app = FastAPI()
        app.include_router(messages.router)
        app.dependency_overrides[get_message_repo] = lambda: SQLiteMessageRepository(self.conn)
        app.dependency_overrides[get_notification_repo] = lambda: SQLiteNotificationRepository(self.conn)

        async def _device(request: Request):
            dev = request.headers.get("X-Test-Device")
            return DeviceIdentity(device_id=dev) if dev else None

        app.dependency_overrides[optional_device] = _device
        self.client = TestClient(app)

    def _send(self, as_device, sender, convo, to):
        headers = {"X-Test-Device": as_device} if as_device else {}
        return self.client.post("/api/v1/messages/send", headers=headers, json={
            "conversation_id": convo, "sender_device_id": sender,
            "payloads": {d: {"ciphertext": "c", "nonce": "n", "signature": "s"} for d in to},
        })

    def _pending(self, as_device, device_id):
        headers = {"X-Test-Device": as_device} if as_device else {}
        return self.client.get(f"/api/v1/messages/pending?device_id={device_id}", headers=headers)

    def test_happy_path(self):
        r = self._send("alice", "alice", "direct_alice_bob", ["bob"])
        self.assertEqual(r.status_code, 200, r.text)
        p = self._pending("bob", "bob").json()
        self.assertEqual(len(p["messages"]), 1)
        self.assertEqual(p["messages"][0]["sender_device_id"], "alice")

    def test_cannot_spoof_sender(self):
        r = self._send("mallory", "alice", "direct_alice_bob", ["bob"])
        self.assertEqual(r.status_code, 403)
        self.assertEqual(self._pending("bob", "bob").json()["messages"], [])

    def test_cannot_inject_into_others_conversation(self):
        # mallory gửi đúng danh tính của mình nhưng vào hội thoại alice-bob
        r = self._send("mallory", "mallory", "direct_alice_bob", ["bob"])
        self.assertEqual(r.status_code, 403)
        # hoặc nhắm một thiết bị không thuộc hội thoại của chính mình
        r = self._send("alice", "alice", "direct_alice_bob", ["mallory"])
        self.assertEqual(r.status_code, 403)

    def test_legacy_conversation_named_by_user_id(self):
        r = self._send("alice", "alice", "direct_u-alice_u-bob", ["bob"])
        self.assertEqual(r.status_code, 200, r.text)

    def test_cannot_read_other_devices_queue(self):
        self._send("alice", "alice", "direct_alice_bob", ["bob"])
        self.assertEqual(self._pending("mallory", "bob").status_code, 403)

    def test_cannot_ack_other_devices_messages(self):
        self._send("alice", "alice", "direct_alice_bob", ["bob"])
        mid = self._pending("bob", "bob").json()["messages"][0]["id"]

        # mallory ack hộ bob: bị bỏ qua, tin của bob vẫn còn
        r = self.client.post("/api/v1/messages/ack", headers={"X-Test-Device": "mallory"},
                             json={"device_id": "mallory", "message_ids": [mid]})
        self.assertEqual(r.json()["acknowledged"], 0)
        self.assertEqual(len(self._pending("bob", "bob").json()["messages"]), 1)

        # mallory khai device_id của bob: 403
        r = self.client.post("/api/v1/messages/ack", headers={"X-Test-Device": "mallory"},
                             json={"device_id": "bob", "message_ids": [mid]})
        self.assertEqual(r.status_code, 403)

        # bob tự ack: được
        r = self.client.post("/api/v1/messages/ack", headers={"X-Test-Device": "bob"},
                             json={"device_id": "bob", "message_ids": [mid]})
        self.assertEqual(r.json()["acknowledged"], 1)
        self.assertEqual(self._pending("bob", "bob").json()["messages"], [])

    def test_unauthenticated_still_works_when_token_not_required(self):
        # Giai đoạn chuyển tiếp: máy chưa enroll không bị chặn (xem optional_device).
        self.assertEqual(self._send(None, "alice", "direct_alice_bob", ["bob"]).status_code, 200)


class TestRejectPlaintextDirectChat(unittest.TestCase):
    def _run(self, flag):
        from routers.sync import MutationModel, _filter_valid_mutations
        muts = [
            MutationModel(id="1", table="chat_messages", operation="insert",
                          data={"id": "m1", "conversation_id": "direct_a_b", "content": "{}"}),
            MutationModel(id="2", table="chat_messages", operation="insert",
                          data={"id": "m2", "conversation_id": "record-uuid", "content": "{}"}),
            MutationModel(id="3", table="chat_conversations", operation="insert",
                          data={"id": "direct_a_b"}),
            MutationModel(id="4", table="tasks", operation="insert", data={"id": "t1"}),
        ]
        with mock.patch.object(CONFIG, "reject_plaintext_direct_chat", flag):
            return _filter_valid_mutations(None, None, muts, None)

    def test_flag_on_rejects_only_direct_chat(self):
        valid, rejected = self._run(True)
        self.assertEqual({m.id for m in valid}, {"2", "4"})
        self.assertEqual({r["table"] for r in rejected}, {"chat_messages", "chat_conversations"})
        self.assertTrue(all(r["error"] == "plaintext_direct_chat_forbidden" for r in rejected))

    def test_flag_off_keeps_everything(self):
        valid, rejected = self._run(False)
        self.assertEqual(len(valid), 4)
        self.assertEqual(rejected, [])


if __name__ == "__main__":
    unittest.main()
