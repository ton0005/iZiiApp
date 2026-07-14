# server/routers/messages.py
"""
Track 3 — E2EE Messaging Router.

Handles encrypted message sending, retrieval, and acknowledgment:
- POST /api/v1/messages/send    — Send encrypted message envelopes to recipient devices
- GET  /api/v1/messages/pending — Get undelivered messages for a device
- POST /api/v1/messages/ack     — Acknowledge message delivery
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Optional
from datetime import datetime

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
    message_ids: List[str]


@router.post("/send")
async def message_send(body: MessageSendPayload,
                        msg_repo: IMessageRepository = Depends(get_message_repo),
                        notif_repo: INotificationRepository = Depends(get_notification_repo)):
    now = datetime.now().isoformat()
    
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
                            repo: IMessageRepository = Depends(get_message_repo)):
    pending = repo.get_pending(device_id)
    
    if pending:
        print(f"\n📬 [PENDING] {len(pending)} message(s) waiting for device {device_id[:16]}...")
    
    return {"messages": pending}


@router.post("/ack")
async def message_ack(body: MessageAckPayload,
                       repo: IMessageRepository = Depends(get_message_repo)):
    now = datetime.now().isoformat()
    
    try:
        acked_count = repo.acknowledge(body.message_ids, now)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    print(f"\n✅ [ACK] Acknowledged {acked_count}/{len(body.message_ids)} message(s)")
    return {"status": "success", "message": f"Acknowledged {acked_count} message(s)", "acknowledged": acked_count}
