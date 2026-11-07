# server/routers/conversations.py
"""
Sổ đăng ký hội thoại — server cần biết thành viên để chỉ giao tin cho đúng
người (WS /chat, /sync/pull). Xem chat_access.py.

- PUT /api/v1/conversations/{id}  — client đăng ký/cập nhật hội thoại + thành viên
- GET /api/v1/conversations/{id}  — xem thành viên (chỉ thành viên mới xem được)

BẮT BUỘC device token, kể cả khi IZIIAPP_REQUIRE_DEVICE_TOKEN tắt: endpoint này
quyết định ai đọc được tin của ai. Cho máy chưa xác thực gọi đồng nghĩa với
cho bất kỳ ai tự thêm mình vào nhóm của người khác.
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

import chat_access
from dependencies import get_db
from security_auth import DeviceIdentity, optional_device

router = APIRouter(prefix="/api/v1/conversations", tags=["Chat Conversations"])


class ConversationUpsert(BaseModel):
    type: str  # 'record_linked' | 'group'
    members: List[str]
    record_type: Optional[str] = None
    record_id: Optional[str] = None


def _require_identity(device: Optional[DeviceIdentity]) -> str:
    if device is None or not device.device_id:
        raise HTTPException(
            401, "Cần X-iZii-Device-Token hợp lệ để quản lý thành viên hội thoại."
        )
    return device.device_id


@router.put("/{conversation_id}")
def upsert_conversation(
    conversation_id: str,
    body: ConversationUpsert,
    request: Request,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    caller = _require_identity(device)

    if chat_access.is_direct(conversation_id):
        # Thành viên hội thoại 1-1 suy ra từ id — không lưu, không cho sửa.
        if not chat_access.is_direct_member(conversation_id, caller):
            raise HTTPException(403, "Không phải thành viên hội thoại này.")
        return {"id": conversation_id, "type": "direct", "derived": True}

    if body.type not in ("record_linked", "group"):
        raise HTTPException(400, f"type không hợp lệ: {body.type}")

    existing = chat_access.get_members(conn, conversation_id)
    if existing is not None and caller not in existing:
        # Hội thoại đã có chủ: người ngoài không được ghi đè danh sách thành
        # viên (tự thêm mình vào để đọc trộm).
        raise HTTPException(403, "Không phải thành viên hội thoại này.")

    members = set(body.members)
    if existing is None:
        # Người tạo luôn là thành viên — tránh tạo hội thoại mà chính mình
        # không đọc được.
        members.add(caller)

    result = chat_access.upsert_conversation(
        conn,
        conversation_id,
        conv_type=body.type,
        created_by=caller,
        members=members,
        record_type=body.record_type,
        record_id=body.record_id,
    )
    conn.commit()

    # WS giữ cache thành viên vài giây — xoá ngay để người vừa bị loại khỏi
    # nhóm không nhận thêm tin nào.
    ws_manager = getattr(request.app.state, "ws_manager", None)
    if ws_manager is not None and hasattr(ws_manager, "invalidate"):
        ws_manager.invalidate(conversation_id)
    return {**result, "type": body.type, "created": existing is None}


@router.get("/{conversation_id}")
def get_conversation(
    conversation_id: str,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    caller = _require_identity(device)
    access = chat_access.can_access(conn, conversation_id, caller)
    if access is None:
        raise HTTPException(404, "Hội thoại chưa được đăng ký.")
    if not access:
        raise HTTPException(403, "Không phải thành viên hội thoại này.")

    if chat_access.is_direct(conversation_id):
        return {"id": conversation_id, "type": "direct", "derived": True}
    return {
        "id": conversation_id,
        "members": sorted(chat_access.get_members(conn, conversation_id) or []),
    }
