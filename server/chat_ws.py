# server/chat_ws.py
"""
Quản lý kết nối WS /chat và ĐỊNH TUYẾN gói tin client gửi lên.

TRƯỚC ĐÂY mọi gói client gửi đều được phát cho tất cả client khác — máy nào
kết nối được /chat cũng nhận nội dung tin nhắn, trạng thái đang gõ, đã đọc
của mọi cuộc hội thoại.

QUY TẮC HIỆN TẠI cho gói do CLIENT gửi:
  1. Gói có `data.conversation_id` → chỉ giao cho socket của thành viên
     (chat_access). Socket chưa khai danh tính (bản app cũ) KHÔNG nhận — máy đó
     vẫn nhận tin qua /sync/pull, chỉ chậm hơn, còn hơn đọc được tin người khác.
     Hội thoại chưa đăng ký → phát rộng như cũ + ghi log (xem chat_access).
  2. Gói có `data.target_id` (tín hiệu gọi) → giao đúng máy đích nếu đang kết
     nối; không thì phát rộng để không làm rớt cuộc gọi như trước đây.
  3. Còn lại (presence, heartbeat) → phát rộng.

Gói do SERVER phát (sync_trigger, event_engine, radio…) vẫn dùng broadcast().
"""
import asyncio
import json
import time
from typing import Any, Callable, Dict, Iterable, List, Optional, Set, Tuple

from fastapi import WebSocket

import chat_access

# Kết quả tra thành viên: ("direct", None) | ("members", {...}) | ("unknown", None)
Membership = Tuple[str, Optional[Set[str]]]


def _db_membership_lookup(conversation_id: str) -> Optional[Set[str]]:
    from dependencies import open_connection
    with open_connection() as conn:
        return chat_access.get_members(conn, conversation_id)


def _db_can_post_lookup(conversation_id: str, member_id: str) -> Optional[bool]:
    if chat_access.is_direct(conversation_id):
        return chat_access.is_direct_member(conversation_id, member_id)
    try:
        from dependencies import open_connection
        with open_connection() as conn:
            return chat_access.can_post_in_conversation(conn, conversation_id, member_id)
    except Exception:
        return True


def _db_record_read_receipt(conversation_id: str, message_id: str, member_id: str):
    from dependencies import open_connection
    with open_connection() as conn:
        chat_access.record_read_receipt(conn, conversation_id, message_id, member_id)
        conn.commit()


class ChatConnectionManager:
    def __init__(
        self,
        membership_lookup: Callable[[str], Optional[Set[str]]] = _db_membership_lookup,
        can_post_lookup: Callable[[str, str], Optional[bool]] = _db_can_post_lookup,
        cache_ttl: float = 15.0,
    ):
        self.active_connections: List[WebSocket] = []
        # socket → device_id (None = bản app cũ chưa khai danh tính)
        self._member_of: Dict[WebSocket, Optional[str]] = {}
        self._verified: Dict[WebSocket, bool] = {}
        self._lookup = membership_lookup
        self._can_post_lookup = can_post_lookup
        self._cache_ttl = cache_ttl
        # Typing/read gửi dồn dập; tra DB mỗi gói là thừa. Router hội thoại gọi
        # invalidate() khi danh sách thành viên đổi.
        self._cache: Dict[str, Tuple[float, Optional[Set[str]]]] = {}

    # ── Vòng đời kết nối ────────────────────────────────────────────────────

    async def connect(self, websocket: WebSocket, member_id: Optional[str] = None,
                      verified: bool = False):
        await websocket.accept()
        self.register(websocket, member_id, verified)

    def register(self, websocket, member_id: Optional[str] = None, verified: bool = False):
        self.active_connections.append(websocket)
        self._member_of[websocket] = member_id or None
        self._verified[websocket] = verified
        who = f"{member_id} ({'token' if verified else 'tự khai'})" if member_id else "chưa khai danh tính"
        print(f"\n🔌 [WS] Client connected: {who}. Active clients: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        self._member_of.pop(websocket, None)
        self._verified.pop(websocket, None)
        print(f"🔌 [WS] Client disconnected. Active clients: {len(self.active_connections)}")

    def member_of(self, websocket) -> Optional[str]:
        return self._member_of.get(websocket)

    def invalidate(self, conversation_id: str):
        self._cache.pop(conversation_id, None)

    # ── Gửi ─────────────────────────────────────────────────────────────────

    async def _send_all(self, message: str, targets: Iterable):
        for connection in list(targets):
            try:
                await connection.send_text(message)
            except Exception:
                pass

    async def broadcast(self, message: str, exclude: Optional[WebSocket]):
        await self._send_all(
            message, (c for c in self.active_connections if c is not exclude)
        )

    async def send_to_member_ids(self, message: str, member_ids: Set[str],
                                 exclude: Optional[WebSocket] = None) -> int:
        targets = [
            c for c in self.active_connections
            if c is not exclude and self._member_of.get(c) in member_ids
        ]
        await self._send_all(message, targets)
        return len(targets)

    # ── Định tuyến gói client ───────────────────────────────────────────────

    async def _membership(self, conversation_id: str) -> Membership:
        if chat_access.is_direct(conversation_id):
            return ("direct", None)
        cached = self._cache.get(conversation_id)
        if cached and cached[0] > time.monotonic():
            members = cached[1]
        else:
            try:
                members = await asyncio.to_thread(self._lookup, conversation_id)
            except Exception as e:
                print(f"⚠️ [WS] Không tra được thành viên {conversation_id}: {e}")
                members = None
            self._cache[conversation_id] = (time.monotonic() + self._cache_ttl, members)
        return ("members", members) if members is not None else ("unknown", None)

    @staticmethod
    def _is_member(membership: Membership, conversation_id: str, member_id: Optional[str]) -> bool:
        if not member_id:
            return False
        kind, members = membership
        if kind == "direct":
            return chat_access.is_direct_member(conversation_id, member_id)
        return member_id in (members or set())

    async def route(self, websocket, raw: str, payload: Optional[Dict[str, Any]]) -> str:
        """
        Giao gói client gửi lên. Trả chuỗi mô tả kết quả (để ghi log và test):
        'broadcast', 'routed:<n>', 'legacy_broadcast', 'dropped:<lý do>'.
        """
        data = payload.get("data") if isinstance(payload, dict) else None
        if not isinstance(data, dict):
            await self.broadcast(raw, exclude=websocket)
            return "broadcast"

        sender = self._member_of.get(websocket)
        conversation_id = data.get("conversation_id")

        if conversation_id:
            conversation_id = str(conversation_id)
            membership = await self._membership(conversation_id)

            if membership[0] == "unknown":
                print(
                    f"⚠️ [WS] Hội thoại {conversation_id} chưa đăng ký thành viên — "
                    f"phát rộng kiểu cũ. Client cần gọi PUT /api/v1/conversations/{{id}}."
                )
                await self.broadcast(raw, exclude=websocket)
                return "legacy_broadcast"

            if sender is not None:
                if not self._is_member(membership, conversation_id, sender):
                    print(f"⛔ [WS] {sender} gửi vào hội thoại {conversation_id} không phải của mình — bỏ.")
                    return "dropped:not_member"
                claimed = data.get("sender_id") or data.get("user_id")
                if claimed and claimed != sender:
                    print(f"⛔ [WS] {sender} mạo danh {claimed} trong {conversation_id} — bỏ.")
                    return "dropped:spoofed_sender"

                # Kênh thông báo (broadcast channel): chỉ admin/owner được đăng tin
                ev = payload.get("event") if payload else None
                if ev == "send_message" and not chat_access.is_direct(conversation_id):
                    can_post = await asyncio.to_thread(self._can_post_lookup, conversation_id, sender)
                    if can_post is False:
                        print(f"⛔ [WS] {sender} không có quyền đăng bài trong kênh thông báo {conversation_id} — bỏ.")
                        return "dropped:broadcast_not_admin"

            # Xử lý mention & read receipt
            ev = payload.get("event") if payload else None
            if ev == "send_message" and sender:
                content_val = data.get("content") or ""
                await self._check_and_notify_mentions(conversation_id, sender, content_val, membership)
            elif ev == "msg_read_receipt" and sender:
                msg_id = data.get("message_id")
                if msg_id:
                    await asyncio.to_thread(_db_record_read_receipt, conversation_id, str(msg_id), sender)

            targets = [
                c for c in self.active_connections
                if c is not websocket
                and self._is_member(membership, conversation_id, self._member_of.get(c))
            ]
            await self._send_all(raw, targets)
            return f"routed:{len(targets)}"

        target_id = data.get("target_id")
        if target_id:
            sent = await self.send_to_member_ids(raw, {str(target_id)}, exclude=websocket)
            if sent:
                return f"routed:{sent}"
            # Máy đích chưa khai danh tính (bản cũ) — giữ hành vi cũ để cuộc
            # gọi vẫn đổ chuông.
            await self.broadcast(raw, exclude=websocket)
            return "legacy_broadcast"

        await self.broadcast(raw, exclude=websocket)
        return "broadcast"


    async def _check_and_notify_mentions(
        self, conversation_id: str, sender: str, content: Any, membership: Membership
    ):
        import re, uuid
        from datetime import datetime, timezone
        text = ""
        if isinstance(content, str):
            try:
                parsed = json.loads(content)
                if isinstance(parsed, dict):
                    text = str(parsed.get("text") or "")
                else:
                    text = content
            except Exception:
                text = content
        elif isinstance(content, dict):
            text = str(content.get("text") or "")
        if not text:
            return

        mentions = re.findall(r"@([A-Za-z0-9_.-]+)", text)
        if not mentions:
            return

        members = membership[1] or set()
        for target in set(mentions):
            if target in members and target != sender:
                try:
                    def _notify():
                        from dependencies import open_connection, get_notification_repo
                        with open_connection() as conn:
                            repo = get_notification_repo(conn)
                            now = datetime.now(timezone.utc).isoformat()
                            repo.create_notification({
                                "id": str(uuid.uuid4()),
                                "user_id": target,
                                "title": "Bạn được nhắc đến",
                                "body": f"@{sender} đã nhắc đến bạn trong một tin nhắn.",
                                "event_type": "mention",
                                "resource_id": conversation_id,
                                "created_at": now,
                            })
                            conn.commit()
                    await asyncio.to_thread(_notify)
                except Exception as e:
                    print(f"⚠️ [WS] Lỗi thông báo mention: {e}")


def parse_payload(raw: str) -> Optional[Dict[str, Any]]:
    try:
        payload = json.loads(raw)
    except Exception:
        return None
    return payload if isinstance(payload, dict) else None
