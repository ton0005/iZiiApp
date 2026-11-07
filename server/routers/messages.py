# server/routers/messages.py
"""
Track 3 — E2EE Messaging Router.

Handles encrypted message sending, retrieval, and acknowledgment:
- POST /api/v1/messages/send    — Send encrypted message envelopes to recipient devices
- GET  /api/v1/messages/pending — Get undelivered messages for a device
- POST /api/v1/messages/ack     — Acknowledge message delivery
"""
from fastapi import APIRouter, Depends, HTTPException
import chat_access
from security_auth import DeviceIdentity, optional_device
from pydantic import BaseModel
from typing import List, Dict, Optional
from datetime import datetime, timezone

from dependencies import get_message_repo, get_notification_repo
from repository.interface import IMessageRepository, INotificationRepository

router = APIRouter(prefix="/api/v1/messages", tags=["E2EE Messaging"])


class EncryptedPayload(BaseModel):
    ciphertext: str
    nonce: str
    signature: Optional[str] = None


class MessageSendPayload(BaseModel):
    conversation_id: str
    sender_device_id: str
    payloads: Dict[str, EncryptedPayload]


class MessageAckPayload(BaseModel):
    # Client gửi kèm device_id của mình. Khi máy có device token, giá trị này
    # (hoặc token) quyết định ai được ack — xem _own_ids().
    device_id: Optional[str] = None
    message_ids: List[str] = []
    # Tin máy nhận KHÔNG giải mã được. Trước đây client im lặng bỏ qua, nên
    # server tưởng chưa giao và gửi lại mãi — nguyên nhân của 1173 tin kẹt
    # trong log ngày 11/08.
    failed_ids: List[str] = []
    failed_reason: Optional[str] = None


def _identities(notif_repo: INotificationRepository, device_id: str) -> set:
    """device_id và mã người dùng đăng ký của thiết bị đó.

    Hội thoại 1-1 cũ đặt tên theo mã người dùng thay vì device_id, nên kiểm tra
    thành viên phải chấp nhận cả hai.
    """
    ids = {device_id}
    try:
        info = notif_repo.get_recipient_info(device_id)
        if info and info.get("user_id"):
            ids.add(info["user_id"])
    except Exception:
        pass
    return ids


def _in_direct_conversation(conversation_id: str, ids: set) -> bool:
    return any(chat_access.is_direct_member(conversation_id, i) for i in ids)


@router.post("/send")
async def message_send(body: MessageSendPayload,
                        msg_repo: IMessageRepository = Depends(get_message_repo),
                        notif_repo: INotificationRepository = Depends(get_notification_repo),
                        device: Optional[DeviceIdentity] = Depends(optional_device)):
    now = datetime.now(timezone.utc).isoformat()

    # Máy đã xác thực không được gửi mạo danh thiết bị khác. (Máy chưa enroll
    # vẫn qua được khi IZIIAPP_REQUIRE_DEVICE_TOKEN tắt — xem optional_device.)
    if device is not None and device.device_id != body.sender_device_id:
        raise HTTPException(403, "sender_device_id không khớp device token.")

    # Hội thoại 1-1: cả người gửi lẫn mọi thiết bị nhận phải là thành viên.
    # Không có kiểm tra này, ai cũng nhét được bản mã vào hàng đợi của người
    # khác (spam, hoặc ép máy nạn nhân xử lý phong bì rác).
    if chat_access.is_direct(body.conversation_id):
        if not _in_direct_conversation(
                body.conversation_id, _identities(notif_repo, body.sender_device_id)):
            raise HTTPException(403, "Người gửi không thuộc hội thoại này.")
        for recipient in body.payloads.keys():
            if not _in_direct_conversation(
                    body.conversation_id, _identities(notif_repo, recipient)):
                raise HTTPException(403, f"Thiết bị nhận {recipient} không thuộc hội thoại này.")

    try:
        # Convert pydantic payloads to plain dicts for repository
        payloads_dict = {k: v.model_dump() for k, v in body.payloads.items()}
        created_ids = msg_repo.send(body.conversation_id, body.sender_device_id, payloads_dict, now)
        
        # Notification Dispatch Logic
        for recipient_device_id in body.payloads.keys():
            recipient = notif_repo.get_recipient_info(recipient_device_id)
            if recipient:
                user_id = recipient["user_id"]
                
                # Check user settings
                setting = notif_repo.get_notification_setting(user_id, 'new_message')
                enable_push = setting["enable_push"] if setting else 1
                enable_in_app = setting["enable_in_app"] if setting else 1
                enable_email = setting["enable_email"] if setting else 1
                
                if enable_in_app:
                    import uuid
                    notif_repo.create_notification({
                        "id": str(uuid.uuid4()),
                        "user_id": user_id,
                        "title": "New Message",
                        "body": "You have received an encrypted private message.",
                        "event_type": "new_message",
                        "resource_id": body.conversation_id,
                        "created_at": now
                    })
                    print(f"   🔔 [IN-APP] Created notification for {user_id}")
                
                if enable_push and recipient.get("push_token"):
                    print(f"   📲 [PUSH] Dispatched Push Notification to token {recipient['push_token'][:16]}...")
                
                if enable_email:
                    print(f"   ✉️ [EMAIL] Scheduled Delayed Email to {user_id} in 15 mins")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    return {"status": "success", "message": f"Sent to {len(body.payloads)} devices", "message_ids": created_ids}


@router.get("/pending")
async def messages_pending(device_id: str,
                            limit: int = 50,
                            repo: IMessageRepository = Depends(get_message_repo),
                            device: Optional[DeviceIdentity] = Depends(optional_device)):
    """
    Lấy MỘT LÔ tin chưa giao, cũ trước.

    Có [limit] vì máy nhận phải gọi một request lấy khoá công khai cho mỗi
    người gửi lạ. Trả về cả hàng đợi nghìn tin đồng nghĩa với hàng nghìn
    round-trip trong một vòng poll 5 giây, và vòng poll sau lại chồng lên vòng
    trước — đúng vòng lặp đã quan sát được.
    """
    if device is not None and device.device_id != device_id:
        # Đọc hàng đợi của máy khác: bản mã không đọc được nhưng lộ ai nhắn ai.
        raise HTTPException(403, "device_id không khớp device token.")
    pending = repo.get_pending(device_id, limit=limit)
    remaining = repo.count_pending(device_id)

    if pending:
        print(
            f"\n📬 [PENDING] Giao {len(pending)} tin cho {device_id[:16]}… "
            f"(còn lại {max(0, remaining - len(pending))})"
        )

    return {
        "messages": pending,
        # Client dùng cờ này để poll tiếp NGAY thay vì đợi hết 5 giây, nên hàng
        # đợi tồn đọng vẫn thoát nhanh dù mỗi lô nhỏ.
        "has_more": remaining > len(pending),
        "remaining": remaining,
    }


@router.post("/ack")
async def message_ack(body: MessageAckPayload,
                       repo: IMessageRepository = Depends(get_message_repo),
                       device: Optional[DeviceIdentity] = Depends(optional_device)):
    now = datetime.now(timezone.utc).isoformat()

    if device is not None:
        if body.device_id and body.device_id != device.device_id:
            raise HTTPException(403, "device_id không khớp device token.")
        # Chỉ ack/báo lỗi tin gửi TỚI máy này. Nếu không, máy A ack hộ máy B là
        # làm B mất tin (server coi là đã giao và không gửi lại).
        mine = {m["id"] for m in repo.get_pending(device.device_id, limit=200)}
        body.message_ids = [i for i in body.message_ids if i in mine]
        body.failed_ids = [i for i in body.failed_ids if i in mine]

    try:
        acked_count = repo.acknowledge(body.message_ids, now) if body.message_ids else 0
        dead_count = 0
        if body.failed_ids:
            dead_count = repo.mark_failed(
                body.failed_ids, now, body.failed_reason or "decrypt_failed"
            )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    if body.message_ids:
        print(f"\n✅ [ACK] Đã giao {acked_count}/{len(body.message_ids)} tin.")
    if body.failed_ids:
        print(
            f"⚠️  [ACK] {len(body.failed_ids)} tin giải mã lỗi"
            + (f", {dead_count} tin bị chuyển dead-letter." if dead_count else ".")
        )

    return {
        "status": "success",
        "acknowledged": acked_count,
        "dead_lettered": dead_count,
    }
