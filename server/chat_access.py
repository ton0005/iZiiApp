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
CHAT_SYNC_TABLES = {"chat_messages", "chat_conversations", "chat_participants", "chat_read_receipts"}


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


def get_conversation(conn, conversation_id: str) -> Optional[Dict[str, Any]]:
    """Lấy thông tin đầy đủ của cuộc hội thoại, kèm danh sách thành viên và vai trò."""
    row = conn.execute(
        sql(
            "SELECT id, type, title, description, avatar_url, is_broadcast, "
            "record_type, record_id, created_by, created_at, updated_at "
            "FROM chat_conversations WHERE id = ?"
        ),
        (conversation_id,),
    ).fetchone()
    if not row:
        return None

    members_rows = conn.execute(
        sql(
            "SELECT member_id, role, joined_at FROM chat_conversation_members "
            "WHERE conversation_id = ? AND left_at IS NULL ORDER BY joined_at ASC"
        ),
        (conversation_id,),
    ).fetchall()

    members = [
        {
            "member_id": m["member_id"],
            "role": m["role"] or "member",
            "joined_at": m["joined_at"],
        }
        for m in members_rows
    ]

    return {
        "id": row["id"],
        "type": row["type"],
        "title": row["title"],
        "description": row["description"],
        "avatar_url": row["avatar_url"],
        "is_broadcast": bool(row["is_broadcast"]),
        "record_type": row["record_type"],
        "record_id": row["record_id"],
        "created_by": row["created_by"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "members": members,
    }


def get_member_role(conn, conversation_id: str, member_id: str) -> Optional[str]:
    """Vai trò của thành viên trong hội thoại ('owner' | 'admin' | 'member'), None nếu không phải thành viên."""
    if not conversation_id or not member_id:
        return None
    if is_direct(conversation_id):
        return "member" if is_direct_member(conversation_id, member_id) else None
    row = conn.execute(
        sql(
            "SELECT role FROM chat_conversation_members "
            "WHERE conversation_id = ? AND member_id = ? AND left_at IS NULL"
        ),
        (conversation_id, member_id),
    ).fetchone()
    return row["role"] if row else None


def is_group_admin(conn, conversation_id: str, member_id: str) -> bool:
    """Kiểm tra người dùng có quyền quản trị viên hoặc trưởng nhóm không."""
    role = get_member_role(conn, conversation_id, member_id)
    return role in ("owner", "admin")


def can_post_in_conversation(conn, conversation_id: str, member_id: str) -> Optional[bool]:
    """
    True nếu được phép gửi tin.
    Trong kênh thông báo (is_broadcast = True), chỉ owner hoặc admin mới được đăng tin.
    None nếu hội thoại chưa đăng ký.
    """
    if is_direct(conversation_id):
        return is_direct_member(conversation_id, member_id)

    conv = get_conversation(conn, conversation_id)
    if conv is None:
        return None
    role = get_member_role(conn, conversation_id, member_id)
    if role is None:
        return False
    if conv.get("is_broadcast"):
        return role in ("owner", "admin")
    return True


def upsert_conversation(
    conn,
    conversation_id: str,
    *,
    conv_type: str,
    created_by: str,
    members: Iterable[str],
    record_type: Optional[str] = None,
    record_id: Optional[str] = None,
    title: Optional[str] = None,
    description: Optional[str] = None,
    avatar_url: Optional[str] = None,
    is_broadcast: bool = False,
    member_roles: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    """
    Đăng ký/cập nhật hội thoại và danh sách thành viên kèm vai trò và metadata nhóm.

    Thành viên vắng mặt trong [members] bị đánh dấu left_at chứ không xoá —
    giữ lại để biết ai TỪNG ở trong nhóm (cần cho xoay khoá E2EE nhóm sau này).
    Không commit; bên gọi commit.
    """
    now = datetime.now(timezone.utc).isoformat()
    wanted = {m for m in members if m}
    roles = member_roles or {}

    conn.execute(
        sql(
            "INSERT INTO chat_conversations "
            "(id, type, title, description, avatar_url, is_broadcast, "
            "record_type, record_id, created_by, created_at, updated_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT (id) DO UPDATE SET "
            "type = excluded.type, title = COALESCE(excluded.title, chat_conversations.title), "
            "description = COALESCE(excluded.description, chat_conversations.description), "
            "avatar_url = COALESCE(excluded.avatar_url, chat_conversations.avatar_url), "
            "is_broadcast = excluded.is_broadcast, "
            "record_type = excluded.record_type, record_id = excluded.record_id, "
            "updated_at = excluded.updated_at"
        ),
        (
            conversation_id,
            conv_type,
            title,
            description,
            avatar_url,
            1 if is_broadcast else 0,
            record_type,
            record_id,
            created_by,
            now,
            now,
        ),
    )

    for member_id in wanted:
        default_role = "owner" if member_id == created_by else "member"
        role_to_set = roles.get(member_id, default_role)
        conn.execute(
            sql(
                "INSERT INTO chat_conversation_members "
                "(conversation_id, member_id, role, joined_at, left_at) "
                "VALUES (?, ?, ?, ?, NULL) "
                "ON CONFLICT (conversation_id, member_id) DO UPDATE SET "
                "role = CASE WHEN excluded.role != 'member' THEN excluded.role ELSE chat_conversation_members.role END, "
                "left_at = NULL"
            ),
            (conversation_id, member_id, role_to_set, now),
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

    return {
        "id": conversation_id,
        "title": title,
        "is_broadcast": is_broadcast,
        "members": sorted(wanted),
        "updated_at": now,
    }


def record_read_receipt(
    conn, conversation_id: str, message_id: str, member_id: str, read_at: Optional[str] = None
) -> Dict[str, Any]:
    """Ghi nhận đã đọc tin nhắn trong nhóm/kênh."""
    ts = read_at or datetime.now(timezone.utc).isoformat()
    conn.execute(
        sql(
            "INSERT INTO chat_read_receipts "
            "(conversation_id, message_id, member_id, read_at) "
            "VALUES (?, ?, ?, ?) "
            "ON CONFLICT (message_id, member_id) DO UPDATE SET read_at = excluded.read_at"
        ),
        (conversation_id, message_id, member_id, ts),
    )
    return {"conversation_id": conversation_id, "message_id": message_id, "member_id": member_id, "read_at": ts}


def get_message_readers(conn, message_id: str) -> List[Dict[str, str]]:
    """Lấy danh sách người đã đọc một tin nhắn."""
    rows = conn.execute(
        sql(
            "SELECT member_id, read_at FROM chat_read_receipts "
            "WHERE message_id = ? ORDER BY read_at ASC"
        ),
        (message_id,),
    ).fetchall()
    return [{"member_id": r["member_id"], "read_at": r["read_at"]} for r in rows]


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
