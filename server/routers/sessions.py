# server/routers/sessions.py
"""
Phiên làm việc — điểm danh đầu ca (G1).

VẤN ĐỀ ĐANG GIẢI QUYẾT
----------------------
Mô hình cũ coi "một thiết bị = một người". Máy tính bảng dùng chung giữa hai ca
khiến hệ thống ghi cả hai ca là cùng một người.

Với Chat thì chỉ khó chịu. Với **Alone Worker thì nghiêm trọng**: cảnh báo
"device-abc123 đang một mình trong Room 10 quá 45 phút" không cho biết phải đi
cứu ai. Trong điều tra tai nạn lao động, câu hỏi đầu tiên của thanh tra là "ai
đang ở trong phòng" — không trả lời được thì toàn bộ giá trị pháp lý của nhật ký
sụp đổ.

MÔ HÌNH MỚI
-----------
    Thiết bị  ──đăng ký MỘT LẦN──►  device_token   (server xác thực)
    Người     ──điểm danh MỖI CA──►  work_session   (gắn user vào device)
    Mutation  ──mang cả hai──────►  ai + máy nào

Ba cách điểm danh, chọn theo thực tế từng tổ:
  • list      — chọn tên từ danh sách (đơn giản nhất, luôn dùng được)
  • pin       — chọn tên + mã PIN 4-6 số (chống chọn nhầm/mạo danh)
  • nfc_badge — chạm thẻ nhân viên (nhanh nhất, dùng được khi đeo găng)
"""
from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel

from database import sql
from dependencies import open_connection
from security_auth import lookup_device_by_token, verify_admin_secret
from server_config import CONFIG

router = APIRouter(prefix="/sessions", tags=["Work Sessions"])

# Phiên tự hết hạn sau ngần này giờ.
#
# Vì sao cần: công nhân hiếm khi bấm "kết thúc ca" — họ chỉ cất máy rồi về.
# Không có giới hạn thì phiên treo qua đêm và mọi thao tác của ca sau bị gán
# nhầm cho người ca trước. 12 giờ đủ dài cho ca dài nhất, đủ ngắn để không
# chồng sang ca kế tiếp.
SESSION_MAX_HOURS = 12


# ── Tiện ích ────────────────────────────────────────────────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _hash_pin(pin: str, salt: str) -> str:
    """
    PBKDF2 thay vì SHA-256 đơn thuần: PIN chỉ 4-6 chữ số nên không gian tìm
    kiếm rất nhỏ (10.000-1.000.000). Hash nhanh sẽ bị vét cạn trong vài giây
    nếu database bị lộ. 200.000 vòng lặp làm việc đó tốn hàng giờ mỗi PIN.
    """
    return hashlib.pbkdf2_hmac(
        "sha256", pin.encode("utf-8"), salt.encode("utf-8"), 200_000
    ).hex()


def _require_device(request: Request, token: Optional[str]):
    """
    Mọi thao tác phiên đều phải đến từ thiết bị đã đăng ký — phiên gắn với
    device_id nên không có thiết bị thì không có gì để gắn.
    """
    if not token:
        raise HTTPException(401, "Thiếu X-iZii-Device-Token. Máy cần đăng ký trước khi điểm danh.")
    with open_connection() as conn:
        identity = lookup_device_by_token(conn, token)
    if identity is None:
        raise HTTPException(401, "Device token không hợp lệ hoặc đã bị thu hồi.")
    return identity


def _device_max_hours(conn, device_id: str) -> Optional[int]:
    """
    Số giờ tối đa của một ca TRÊN MÁY NÀY.

    Trả None = không giới hạn — dùng cho iPhone/iPad cá nhân của Manager mang
    về nhà: bắt phiên hết hạn sau 12 giờ rồi ngày nào cũng phải điểm danh lại
    là vô nghĩa với máy dùng riêng.

    Thứ tự ưu tiên:
      1. session_max_hours khai riêng cho máy
      2. Mặc định theo chế độ: shared = 12 giờ, personal = không giới hạn
    """
    try:
        row = conn.execute(
            sql("SELECT profile, session_max_hours FROM device_tokens WHERE device_id = ?"),
            (device_id,),
        ).fetchone()
    except Exception:
        return SESSION_MAX_HOURS

    if not row:
        return SESSION_MAX_HOURS

    try:
        custom = row["session_max_hours"]
    except (IndexError, KeyError):
        custom = None
    if custom is not None:
        return int(custom)

    try:
        profile = row["profile"] or "shared"
    except (IndexError, KeyError):
        profile = "shared"
    return None if profile == "personal" else SESSION_MAX_HOURS


def _close_stale_sessions(conn) -> int:
    """
    Đóng các phiên đã vượt giới hạn giờ CỦA RIÊNG TỪNG MÁY.

    Không dùng một câu UPDATE duy nhất với hằng số toàn cục nữa: mỗi máy có
    giới hạn khác nhau, và máy cá nhân thì không có giới hạn nào.

    Gọi trước mỗi truy vấn phiên thay vì chạy tác vụ nền — rẻ hơn và không cần
    thêm scheduler. Số phiên đang mở luôn nhỏ (bằng số máy đang dùng).
    """
    rows = conn.execute(
        "SELECT id, device_id, started_at FROM work_sessions WHERE ended_at IS NULL"
    ).fetchall()
    if not rows:
        return 0

    now = datetime.now(timezone.utc)
    closed = 0
    for r in rows:
        max_hours = _device_max_hours(conn, r["device_id"])
        if max_hours is None:
            continue  # máy cá nhân — phiên không hết hạn
        try:
            started = datetime.fromisoformat(r["started_at"])
        except Exception:
            continue
        if now - started > timedelta(hours=max_hours):
            conn.execute(
                sql(
                    "UPDATE work_sessions SET ended_at = ?, ended_reason = 'timeout' "
                    "WHERE id = ?"
                ),
                (_now(), r["id"]),
            )
            closed += 1

    if closed:
        conn.commit()
        print(f"⏰ [SESSION] Tự đóng {closed} phiên đã quá giới hạn giờ.")
    return closed


def get_active_session(conn, device_id: str) -> Optional[Dict[str, Any]]:
    """
    Phiên đang mở của một thiết bị. Dùng bởi security_auth để gắn user_id thật
    vào mutation, và bởi ràng buộc Alone Worker.
    """
    row = conn.execute(
        sql(
            "SELECT id, user_id, user_name, department, zone, method, started_at "
            "FROM work_sessions WHERE device_id = ? AND ended_at IS NULL "
            "ORDER BY started_at DESC LIMIT 1"
        ),
        (device_id,),
    ).fetchone()
    if not row:
        return None
    # Kiểm hạn ngay tại đây: phiên quá giờ coi như không tồn tại, kể cả khi
    # tác vụ dọn dẹp chưa kịp chạy. Giới hạn lấy theo TỪNG MÁY — máy cá nhân
    # trả None nghĩa là không bao giờ hết hạn.
    max_hours = _device_max_hours(conn, device_id)
    if max_hours is not None:
        try:
            started = datetime.fromisoformat(row["started_at"])
            if datetime.now(timezone.utc) - started > timedelta(hours=max_hours):
                return None
        except Exception:
            pass
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "user_name": row["user_name"],
        "department": row["department"],
        "zone": row["zone"],
        "method": row["method"],
        "started_at": row["started_at"],
    }


def get_active_session_for_person(conn, identifier: str) -> Optional[Dict[str, Any]]:
    """
    Phiên đang mở của MỘT NGƯỜI, trên bất kỳ thiết bị nào.

    VÌ SAO CẦN, tách khỏi [get_active_session]: hai câu hỏi khác nhau.

      • get_active_session(device_id)      → "ai đang cầm máy này?"
      • get_active_session_for_person(...) → "người này có đang trong ca không?"

    Ràng buộc Alone Worker cần câu thứ hai. Quản lý ngồi laptop tạo công việc
    và phân công cho công nhân đã điểm danh trên iPad — người làm việc một mình
    là CÔNG NHÂN, không phải quản lý. Kiểm phiên của máy tạo công việc là kiểm
    nhầm người, và đó chính là lỗi đã gặp: điểm danh xong trên iPad, laptop vẫn
    báo "chưa điểm danh".

    [identifier] chấp nhận cả mã nhân viên lẫn tên, vì trường `assignee` của
    công việc lưu TÊN chứ không lưu mã. So khớp tên không phân biệt hoa thường
    và bỏ khoảng trắng thừa.
    """
    ident = (identifier or "").strip()
    if not ident:
        return None

    rows = conn.execute(
        sql(
            "SELECT id, device_id, user_id, user_name, department, zone, method, started_at "
            "FROM work_sessions WHERE ended_at IS NULL "
            "ORDER BY started_at DESC"
        )
    ).fetchall()

    needle = ident.casefold()
    for row in rows:
        uid = (row["user_id"] or "").strip()
        uname = (row["user_name"] or "").strip()
        if uid.casefold() != needle and uname.casefold() != needle:
            continue

        # Phiên quá giờ coi như không tồn tại, kể cả khi tác vụ dọn chưa chạy.
        max_hours = _device_max_hours(conn, row["device_id"])
        if max_hours is not None:
            try:
                started = datetime.fromisoformat(row["started_at"])
                if datetime.now(timezone.utc) - started > timedelta(hours=max_hours):
                    continue
            except Exception:
                pass

        return {
            "id": row["id"],
            "device_id": row["device_id"],
            "user_id": row["user_id"],
            "user_name": row["user_name"],
            "department": row["department"],
            "zone": row["zone"],
            "method": row["method"],
            "started_at": row["started_at"],
        }
    return None


# ── Mô hình dữ liệu ─────────────────────────────────────────────────────────

class StartSessionPayload(BaseModel):
    user_id: str
    user_name: Optional[str] = None
    department: Optional[str] = None
    method: str = "list"          # list | pin | nfc_badge | auto
    pin: Optional[str] = None     # bắt buộc khi method='pin'


class SetPinPayload(BaseModel):
    user_id: str
    pin: str


# ── Endpoint ────────────────────────────────────────────────────────────────

@router.post("/start")
async def start_session(
    payload: StartSessionPayload,
    request: Request,
    x_izii_device_token: Optional[str] = Header(None, alias="X-iZii-Device-Token"),
):
    """
    Điểm danh đầu ca.

    Tự đóng phiên cũ trên cùng máy — công nhân ca sau chỉ cần điểm danh, không
    phải nhớ bấm kết thúc giúp người ca trước.
    """
    device = _require_device(request, x_izii_device_token)

    if not payload.user_id.strip():
        raise HTTPException(400, "Thiếu mã nhân viên.")

    with open_connection() as conn:
        _close_stale_sessions(conn)

        # Xác thực PIN nếu tổ này dùng phương thức PIN.
        if payload.method == "pin":
            if not payload.pin:
                raise HTTPException(400, "Thiếu mã PIN.")
            row = conn.execute(
                sql("SELECT pin_hash, salt FROM employee_pins WHERE user_id = ?"),
                (payload.user_id,),
            ).fetchone()
            if not row:
                raise HTTPException(403, "Nhân viên này chưa được đặt mã PIN. Báo quản lý.")
            if _hash_pin(payload.pin, row["salt"]) != row["pin_hash"]:
                print(f"⛔ [SESSION] PIN sai cho {payload.user_id} từ máy {device.device_id}")
                raise HTTPException(403, "Mã PIN không đúng.")

        # Đóng phiên đang mở trên máy này (nếu có) trước khi mở phiên mới.
        prev = get_active_session(conn, device.device_id)
        if prev:
            conn.execute(
                sql(
                    "UPDATE work_sessions SET ended_at = ?, ended_reason = 'replaced' "
                    "WHERE id = ?"
                ),
                (_now(), prev["id"]),
            )

        session_id = f"ws_{uuid.uuid4().hex[:16]}"
        now = _now()
        conn.execute(
            sql(
                "INSERT INTO work_sessions "
                "(id, device_id, user_id, user_name, department, zone, method, started_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            ),
            (session_id, device.device_id, payload.user_id, payload.user_name or "",
             payload.department or "", CONFIG.zone, payload.method, now),
        )
        conn.commit()

    print(
        f"👤 [SESSION] {payload.user_name or payload.user_id} điểm danh trên "
        f"{device.device_id} (cách: {payload.method})"
        + (f" — thay phiên của {prev['user_name'] or prev['user_id']}" if prev else "")
    )

    return {
        "status": "success",
        "session_id": session_id,
        "user_id": payload.user_id,
        "user_name": payload.user_name or "",
        "device_id": device.device_id,
        "zone": CONFIG.zone,
        "started_at": now,
        "expires_at": (
            datetime.now(timezone.utc) + timedelta(hours=SESSION_MAX_HOURS)
        ).isoformat(),
        "replaced_session": prev["id"] if prev else None,
    }


@router.post("/end")
async def end_session(
    request: Request,
    x_izii_device_token: Optional[str] = Header(None, alias="X-iZii-Device-Token"),
):
    """Kết thúc ca thủ công."""
    device = _require_device(request, x_izii_device_token)

    with open_connection() as conn:
        current = get_active_session(conn, device.device_id)
        if not current:
            return {"status": "noop", "message": "Không có phiên nào đang mở."}
        conn.execute(
            sql("UPDATE work_sessions SET ended_at = ?, ended_reason = 'manual' WHERE id = ?"),
            (_now(), current["id"]),
        )
        conn.commit()

    print(f"👋 [SESSION] {current['user_name'] or current['user_id']} kết thúc ca.")
    return {"status": "success", "session_id": current["id"], "ended_at": _now()}


@router.get("/current")
async def current_session(
    request: Request,
    x_izii_device_token: Optional[str] = Header(None, alias="X-iZii-Device-Token"),
):
    """
    Phiên đang mở của máy này. App gọi lúc khởi động để biết có cần hiện màn
    hình điểm danh không.
    """
    device = _require_device(request, x_izii_device_token)
    with open_connection() as conn:
        _close_stale_sessions(conn)
        session = get_active_session(conn, device.device_id)
        max_hours = _device_max_hours(conn, device.device_id)

    return {
        "device_id": device.device_id,
        "has_session": session is not None,
        "session": session,
        "max_hours": max_hours,          # None = ca không giới hạn
        "profile": device.profile,       # 'shared' | 'personal'
        "owner_user_id": device.user_id if device.is_personal else None,
        "owner_user_name": device.user_name if device.is_personal else None,
        # Máy cá nhân không bắt buộc điểm danh — danh tính đã biết từ lúc cấp máy.
        "requires_check_in": not device.is_personal,
        "identity_is_known": device.identity_is_known,
        "require_for_alone_worker": True,
    }


@router.get("/active")
async def list_active_sessions(
    request: Request,
    x_izii_device_token: Optional[str] = Header(None, alias="X-iZii-Device-Token"),
):
    """
    AI ĐANG TRONG CA — dùng cho màn hình giám sát của quản lý.

    Đây là câu trả lời cho câu hỏi quan trọng nhất khi có sự cố: ai đang ở
    trong nhà máy, trên máy nào, từ lúc nào.
    """
    _require_device(request, x_izii_device_token)

    with open_connection() as conn:
        _close_stale_sessions(conn)
        rows = conn.execute(
            "SELECT ws.id, ws.device_id, ws.user_id, ws.user_name, ws.department, "
            "       ws.zone, ws.method, ws.started_at, dt.device_name "
            "FROM work_sessions ws "
            "LEFT JOIN device_tokens dt ON dt.device_id = ws.device_id "
            "WHERE ws.ended_at IS NULL "
            "ORDER BY ws.started_at DESC"
        ).fetchall()

    now = datetime.now(timezone.utc)
    sessions: List[Dict[str, Any]] = []
    for r in rows:
        minutes = None
        try:
            minutes = int((now - datetime.fromisoformat(r["started_at"])).total_seconds() // 60)
        except Exception:
            pass
        sessions.append({
            "session_id": r["id"],
            "user_id": r["user_id"],
            "user_name": r["user_name"] or r["user_id"],
            "department": r["department"],
            "zone": r["zone"],
            "method": r["method"],
            "device_id": r["device_id"],
            "device_name": r["device_name"] or r["device_id"],
            "started_at": r["started_at"],
            "minutes_elapsed": minutes,
        })

    return {"count": len(sessions), "sessions": sessions, "server_id": CONFIG.server_id}


@router.post("/pin")
async def set_employee_pin(
    payload: SetPinPayload,
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    """
    Đặt hoặc đổi mã PIN cho một nhân viên. Chỉ quản trị viên.

    PIN lưu ở SERVER chứ không trong bảng nhân viên phía app — nếu để trong
    mutation log thì nó sẽ được đồng bộ xuống MỌI thiết bị.
    """
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)

    pin = payload.pin.strip()
    if not pin.isdigit() or not (4 <= len(pin) <= 6):
        raise HTTPException(400, "PIN phải là 4-6 chữ số.")
    # Chặn vài PIN đoán được ngay
    if pin in ("0000", "1111", "1234", "123456", "000000", "111111"):
        raise HTTPException(400, "PIN quá dễ đoán. Chọn dãy số khác.")

    salt = secrets.token_hex(16)
    with open_connection() as conn:
        if CONFIG.db_backend == "postgres":
            conn.execute(
                "INSERT INTO employee_pins (user_id, pin_hash, salt, updated_at) "
                "VALUES (%s, %s, %s, %s) "
                "ON CONFLICT (user_id) DO UPDATE SET "
                "  pin_hash = EXCLUDED.pin_hash, salt = EXCLUDED.salt, "
                "  updated_at = EXCLUDED.updated_at",
                (payload.user_id, _hash_pin(pin, salt), salt, _now()),
            )
        else:
            conn.execute(
                "INSERT OR REPLACE INTO employee_pins (user_id, pin_hash, salt, updated_at) "
                "VALUES (?, ?, ?, ?)",
                (payload.user_id, _hash_pin(pin, salt), salt, _now()),
            )
        conn.commit()

    print(f"🔢 [SESSION] Đã đặt PIN cho nhân viên {payload.user_id}")
    return {"status": "success", "user_id": payload.user_id}


@router.get("/pin/status")
async def pin_status(
    request: Request,
    x_izii_device_token: Optional[str] = Header(None, alias="X-iZii-Device-Token"),
):
    """
    Danh sách nhân viên ĐÃ đặt PIN — để app biết hiện ô nhập PIN cho ai.
    Chỉ trả về mã nhân viên, không trả bất kỳ thông tin nào về PIN.
    """
    _require_device(request, x_izii_device_token)
    with open_connection() as conn:
        rows = conn.execute("SELECT user_id FROM employee_pins").fetchall()
    return {"users_with_pin": [r["user_id"] for r in rows]}
