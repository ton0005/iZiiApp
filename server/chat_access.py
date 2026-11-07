# server/chat_access.py
"""
Ai được nhận tin của cuộc hội thoại nào.

TRƯỚC ĐÂY: server không biết gì về thành viên hội thoại. WS /chat phát mọi
gói tin cho MỌI client, /sync/pull trả mọi bản ghi chat_messages cho MỌI máy —
nghĩa là máy nào kết nối được server cũng đọc được tin riêng của người khác.

Hai nguồn xác định thành viên:
  1. Hội thoại 1-1 có id tất định `direct_<idA>_<idB>` (hai device_id sắp xếp)
     → suy ra thành viên từ chính id, không cần tra bảng.
  2. Hội thoại còn lại (record_linked, group) → bảng chat_conversation_members,
     do client đăng ký qua PUT /api/v1/conversations/{id}.

Hội thoại CHƯA đăng ký trả về None ("không biết"), không phải False. Bản app cũ
chưa biết gọi endpoint đăng ký; chặn hẳn sẽ làm chat theo bản ghi ngừng chạy
ngay lúc nâng cấp server. Bên gọi tự quyết xử lý None thế nào và PHẢI ghi log.
"""
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Set

from database import sql

DIRECT_PREFIX = "direct_"

# Bảng sync mang nội dung hội thoại. chat_conversations/chat_participants dùng
# trường `id`/`conversation_id` khác nhau nên tách hàm lấy id ở dưới.
CHAT_SYNC_TABLES = {"chat_messages", "chat_conversations", "chat_participants"}


def is_direct(conversation_id: str) -> bool:
    return bool(conversation_id) and conversation_id.startswith(DIRECT_PREFIX)


def is_direct_member(conversation_id: str, member_id: str) -> bool:
    """
    So khớp đầu/cuối thay vì split('_') vì device_id/mã nhân viên có thể chứa
    dấu gạch dưới — split sẽ cắt sai và trả nhầm thành viên.

    Chỉ khớp đầu/cuối vẫn mơ hồ: `direct_EMP_007_x` khớp cả "EMP" (+ "007_x").
    Client luôn SẮP XẾP hai id trước khi ghép (chat_repository.dart), nên phần
    đầu phải <= phần cuối — dùng ràng buộc đó để loại cách tách sai.
    """
    if not is_direct(conversation_id) or not member_id:
        return False
    rest = conversation_id[len(DIRECT_PREFIX):]
    head, tail = member_id + "_", "_" + member_id
    if rest.startswith(head) and member_id <= rest[len(head):]:
        return True
    if rest.endswith(tail) and rest[:-len(tail)] <= member_id:
        return True
    return False


def get_members(conn, conversation_id: str) -> Optional[Set[str]]:
    """Thành viên còn hiệu lực; None nếu hội thoại chưa được đăng ký."""
    exists = conn.execute(
        sql("SELECT 1 FROM chat_conversations WHERE id = ?"),
        (conversation_id,),
    ).fetchone()
    if not exists:
        return None
    rows = conn.execute(
        sql(
            "SELECT member_id FROM chat_conversation_members "
            "WHERE conversation_id = ? AND left_at IS NULL"
        ),
        (conversation_id,),
    ).fetchall()
    return {r["member_id"] for r in rows}


def can_access(conn, conversation_id: str, member_id: str) -> Optional[bool]:
    """True/False nếu xác định được, None nếu hội thoại chưa đăng ký."""
    if not conversation_id or not member_id:
        return False
    if is_direct(conversation_id):
        return is_direct_member(conversation_id, member_id)
    members = get_members(conn, conversation_id)
    if members is None:
        return None
    return member_id in members


def upsert_conversation(
    conn,
    conversation_id: str,
    *,
    conv_type: str,
    created_by: str,
    members: Iterable[str],
    record_type: Optional[str] = None,
    record_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Đăng ký/cập nhật hội thoại và danh sách thành viên.

    Thành viên vắng mặt trong [members] bị đánh dấu left_at chứ không xoá —
    giữ lại để biết ai TỪNG ở trong nhóm (cần cho xoay khoá E2EE nhóm sau này).
    Không commit; bên gọi commit.
    """
    now = datetime.now(timezone.utc).isoformat()
    wanted = {m for m in members if m}

    conn.execute(
        sql(
            "INSERT INTO chat_conversations "
            "(id, type, record_type, record_id, created_by, created_at, updated_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT (id) DO UPDATE SET "
            "type = excluded.type, record_type = excluded.record_type, "
            "record_id = excluded.record_id, updated_at = excluded.updated_at"
        ),
        (conversation_id, conv_type, record_type, record_id, created_by, now, now),
    )

    for member_id in wanted:
        conn.execute(
            sql(
                "INSERT INTO chat_conversation_members "
                "(conversation_id, member_id, role, joined_at, left_at) "
                "VALUES (?, ?, ?, ?, NULL) "
                "ON CONFLICT (conversation_id, member_id) DO UPDATE SET left_at = NULL"
            ),
            (conversation_id, member_id,
             "owner" if member_id == created_by else "member", now),
        )

    current = conn.execute(
        sql(
            "SELECT member_id FROM chat_conversation_members "
            "WHERE conversation_id = ? AND left_at IS NULL"
        ),
        (conversation_id,),
    ).fetchall()
    for row in current:
        if row["member_id"] not in wanted:
            conn.execute(
                sql(
                    "UPDATE chat_conversation_members SET left_at = ? "
                    "WHERE conversation_id = ? AND member_id = ?"
                ),
                (now, conversation_id, row["member_id"]),
            )

    return {"id": conversation_id, "members": sorted(wanted), "updated_at": now}


def _conversation_id_of(update: Dict[str, Any]) -> str:
    data = update.get("data") or {}
    if update.get("table") == "chat_conversations":
        return str(data.get("id") or "")
    return str(data.get("conversation_id") or "")


def filter_chat_updates(
    conn, updates: List[Dict[str, Any]], member_id: str
) -> List[Dict[str, Any]]:
    """
    Bỏ khỏi trang /sync/pull các bản ghi chat của hội thoại mà máy này không
    thuộc về. Bản ghi không phải chat giữ nguyên.

    Hội thoại chưa đăng ký (None) vẫn cho qua để bản app cũ không mất chat theo
    bản ghi — xem docstring đầu file.
    """
    cache: Dict[str, Optional[bool]] = {}
    result = []
    for u in updates:
        if u.get("table") not in CHAT_SYNC_TABLES:
            result.append(u)
            continue
        cid = _conversation_id_of(u)
        if not cid:
            # Mutation cập nhật một phần (chỉ id + trạng thái) không mang nội
            # dung. Client sẽ gọi /sync/record để lấy bản đầy đủ — chốt kiểm
            # tra quyền nằm ở đó.
            result.append(u)
            continue
        if cid not in cache:
            cache[cid] = can_access(conn, cid, member_id)
        if cache[cid] is not False:
            result.append(u)
    return result
