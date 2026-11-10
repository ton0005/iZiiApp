# server/routers/conversations.py
"""
Sổ đăng ký hội thoại & quản lý nhóm/kênh (Phase 2):
- PUT /api/v1/conversations/{id}         — tạo/cập nhật hội thoại, metadata (tên, ảnh, mô tả, kênh), thành viên
- POST /api/v1/conversations             — tạo nhóm/kênh mới tiện lợi
- GET /api/v1/conversations/{id}         — xem chi tiết hội thoại, metadata, danh sách thành viên + vai trò
- POST /api/v1/conversations/{id}/members— thêm thành viên / phân vai trò (owner/admin)
- DELETE /api/v1/conversations/{id}/members/{member_id} — xoá thành viên khỏi nhóm
- POST /api/v1/conversations/{id}/leave  — rời nhóm
- POST /api/v1/conversations/{id}/invite — tạo link mời vào nhóm
- POST /api/v1/conversations/{id}/join   — tham gia nhóm qua link mời
- POST /api/v1/conversations/{id}/read   — đánh dấu đã đọc tin nhắn trong nhóm
- GET /api/v1/conversations/{id}/messages/{message_id}/readers — danh sách người đã xem tin

BẮT BUỘC device token, kể cả khi IZIIAPP_REQUIRE_DEVICE_TOKEN tắt: endpoint này
quyết định ai đọc được tin của ai.
"""
import uuid
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone

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
    title: Optional[str] = None
    description: Optional[str] = None
    avatar_url: Optional[str] = None
    is_broadcast: bool = False
    member_roles: Optional[Dict[str, str]] = None


class MemberActionPayload(BaseModel):
    member_id: str
    role: Optional[str] = "member"  # 'admin' | 'member'


class ReadReceiptPayload(BaseModel):
    message_id: str
    read_at: Optional[str] = None


def _require_identity(device: Optional[DeviceIdentity]) -> str:
    if device is None or not device.device_id:
        raise HTTPException(
            401, "Cần X-iZii-Device-Token hợp lệ để quản lý thành viên hội thoại."
        )
    return device.device_id


@router.post("")
def create_conversation(
    body: ConversationUpsert,
    request: Request,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Tạo mới một nhóm hoặc kênh chat."""
    caller = _require_identity(device)
    new_id = f"group_{uuid.uuid4().hex[:16]}" if body.type == "group" else str(uuid.uuid4())
    return upsert_conversation(new_id, body, request, conn=conn, device=device)


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
        # Người ngoài không được ghi đè danh sách thành viên
        raise HTTPException(403, "Không phải thành viên hội thoại này.")

    members = set(body.members)
    if existing is None:
        # Người tạo luôn là thành viên và owner
        members.add(caller)

    result = chat_access.upsert_conversation(
        conn,
        conversation_id,
        conv_type=body.type,
        created_by=caller,
        members=members,
        record_type=body.record_type,
        record_id=body.record_id,
        title=body.title,
        description=body.description,
        avatar_url=body.avatar_url,
        is_broadcast=body.is_broadcast,
        member_roles=body.member_roles,
    )
    conn.commit()

    ws_manager = getattr(request.app.state, "ws_manager", None)
    if ws_manager is not None and hasattr(ws_manager, "invalidate"):
        ws_manager.invalidate(conversation_id)

    full_conv = chat_access.get_conversation(conn, conversation_id)
    return {**result, "type": body.type, "created": existing is None, "details": full_conv}


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

    conv = chat_access.get_conversation(conn, conversation_id)
    if not conv:
        raise HTTPException(404, "Không tìm thấy dữ liệu hội thoại.")
    return {
        **conv,
        "members": sorted(m["member_id"] for m in conv["members"]),
        "member_details": conv["members"],
    }


@router.post("/{conversation_id}/members")
def add_or_update_member(
    conversation_id: str,
    body: MemberActionPayload,
    request: Request,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Thêm thành viên hoặc nâng/hạ quyền admin (chỉ admin/owner)."""
    caller = _require_identity(device)
    if chat_access.is_direct(conversation_id):
        raise HTTPException(400, "Không hỗ trợ thêm thành viên cho hội thoại 1-1.")

    if not chat_access.is_group_admin(conn, conversation_id, caller):
        raise HTTPException(403, "Chỉ quản trị viên hoặc trưởng nhóm mới có thể thêm thành viên.")

    now = datetime.now(timezone.utc).isoformat()
    role_to_set = body.role if body.role in ("admin", "member") else "member"

    from database import sql
    conn.execute(
        sql(
            "INSERT INTO chat_conversation_members "
            "(conversation_id, member_id, role, joined_at, left_at) "
            "VALUES (?, ?, ?, ?, NULL) "
            "ON CONFLICT (conversation_id, member_id) DO UPDATE SET "
            "role = excluded.role, left_at = NULL"
        ),
        (conversation_id, body.member_id, role_to_set, now),
    )
    conn.commit()

    ws_manager = getattr(request.app.state, "ws_manager", None)
    if ws_manager is not None and hasattr(ws_manager, "invalidate"):
        ws_manager.invalidate(conversation_id)

    return {"status": "success", "member_id": body.member_id, "role": role_to_set}


@router.delete("/{conversation_id}/members/{member_id}")
def remove_member(
    conversation_id: str,
    member_id: str,
    request: Request,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Xoá thành viên khỏi nhóm (chỉ admin/owner)."""
    caller = _require_identity(device)
    if chat_access.is_direct(conversation_id):
        raise HTTPException(400, "Không hỗ trợ cho hội thoại 1-1.")

    caller_role = chat_access.get_member_role(conn, conversation_id, caller)
    target_role = chat_access.get_member_role(conn, conversation_id, member_id)

    if not target_role:
        raise HTTPException(404, "Thành viên không nằm trong nhóm.")

    if caller_role == "owner":
        if member_id == caller:
            raise HTTPException(400, "Trưởng nhóm không thể tự xoá mình bằng endpoint này, hãy dùng /leave.")
    elif caller_role == "admin":
        if target_role in ("owner", "admin"):
            raise HTTPException(403, "Quản trị viên không thể xoá trưởng nhóm hoặc quản trị viên khác.")
    else:
        raise HTTPException(403, "Chỉ quản trị viên hoặc trưởng nhóm mới có quyền xoá thành viên.")

    now = datetime.now(timezone.utc).isoformat()
    from database import sql
    conn.execute(
        sql("UPDATE chat_conversation_members SET left_at = ? WHERE conversation_id = ? AND member_id = ?"),
        (now, conversation_id, member_id),
    )
    conn.commit()

    ws_manager = getattr(request.app.state, "ws_manager", None)
    if ws_manager is not None and hasattr(ws_manager, "invalidate"):
        ws_manager.invalidate(conversation_id)

    return {"status": "success", "removed_member_id": member_id}


@router.post("/{conversation_id}/leave")
def leave_group(
    conversation_id: str,
    request: Request,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Thành viên tự rời khỏi nhóm."""
    caller = _require_identity(device)
    if chat_access.is_direct(conversation_id):
        raise HTTPException(400, "Không hỗ trợ cho hội thoại 1-1.")

    role = chat_access.get_member_role(conn, conversation_id, caller)
    if not role:
        raise HTTPException(400, "Bạn không phải thành viên của nhóm này.")

    now = datetime.now(timezone.utc).isoformat()
    from database import sql
    conn.execute(
        sql("UPDATE chat_conversation_members SET left_at = ? WHERE conversation_id = ? AND member_id = ?"),
        (now, conversation_id, caller),
    )

    # Nếu owner rời nhóm, chuyển quyền owner cho admin/thành viên còn lại đầu tiên
    if role == "owner":
        next_owner = conn.execute(
            sql(
                "SELECT member_id, role FROM chat_conversation_members "
                "WHERE conversation_id = ? AND left_at IS NULL "
                "ORDER BY CASE WHEN role = 'admin' THEN 0 ELSE 1 END, joined_at ASC"
            ),
            (conversation_id,),
        ).fetchone()
        if next_owner:
            conn.execute(
                sql(
                    "UPDATE chat_conversation_members SET role = 'owner' "
                    "WHERE conversation_id = ? AND member_id = ?"
                ),
                (conversation_id, next_owner["member_id"]),
            )

    conn.commit()

    ws_manager = getattr(request.app.state, "ws_manager", None)
    if ws_manager is not None and hasattr(ws_manager, "invalidate"):
        ws_manager.invalidate(conversation_id)

    return {"status": "success", "left_conversation_id": conversation_id}


@router.post("/{conversation_id}/invite")
def create_invite_link(
    conversation_id: str,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Tạo link mời vào nhóm."""
    caller = _require_identity(device)
    access = chat_access.can_access(conn, conversation_id, caller)
    if not access:
        raise HTTPException(403, "Chỉ thành viên mới có thể lấy link mời.")

    return {
        "conversation_id": conversation_id,
        "invite_code": f"izii_inv_{conversation_id}",
        "invite_url": f"https://izii.app/chat/join/{conversation_id}",
    }


@router.post("/{conversation_id}/join")
def join_group(
    conversation_id: str,
    request: Request,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Tham gia nhóm qua link mời."""
    caller = _require_identity(device)
    conv = chat_access.get_conversation(conn, conversation_id)
    if not conv:
        raise HTTPException(404, "Không tìm thấy nhóm để tham gia.")

    now = datetime.now(timezone.utc).isoformat()
    from database import sql
    conn.execute(
        sql(
            "INSERT INTO chat_conversation_members "
            "(conversation_id, member_id, role, joined_at, left_at) "
            "VALUES (?, ?, 'member', ?, NULL) "
            "ON CONFLICT (conversation_id, member_id) DO UPDATE SET left_at = NULL"
        ),
        (conversation_id, caller, now),
    )
    conn.commit()

    ws_manager = getattr(request.app.state, "ws_manager", None)
    if ws_manager is not None and hasattr(ws_manager, "invalidate"):
        ws_manager.invalidate(conversation_id)

    return {"status": "success", "joined": conversation_id, "role": "member"}


@router.post("/{conversation_id}/read")
def mark_read(
    conversation_id: str,
    body: ReadReceiptPayload,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Đánh dấu đã đọc một tin nhắn trong nhóm/kênh."""
    caller = _require_identity(device)
    access = chat_access.can_access(conn, conversation_id, caller)
    if not access:
        raise HTTPException(403, "Không phải thành viên hội thoại này.")

    res = chat_access.record_read_receipt(conn, conversation_id, body.message_id, caller, body.read_at)
    conn.commit()
    return res


@router.get("/{conversation_id}/messages/{message_id}/readers")
def get_readers(
    conversation_id: str,
    message_id: str,
    conn=Depends(get_db),
    device: Optional[DeviceIdentity] = Depends(optional_device),
):
    """Lấy danh sách người đã đọc một tin nhắn."""
    caller = _require_identity(device)
    access = chat_access.can_access(conn, conversation_id, caller)
    if not access:
        raise HTTPException(403, "Không phải thành viên hội thoại này.")

    readers = chat_access.get_message_readers(conn, message_id)
    return {"message_id": message_id, "readers": readers, "count": len(readers)}
