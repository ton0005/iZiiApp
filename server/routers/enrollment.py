# server/routers/enrollment.py
"""
Đăng ký thiết bị — đổi "vé mời" lấy token riêng (B2).

ĐÂY LÀ ENDPOINT CÔNG KHAI DUY NHẤT không cần bí mật hệ thống. Vì vậy nó là bề
mặt tấn công đáng chú ý nhất và được siết theo 4 hướng:

  1. Vé phải còn hạn VÀ chưa dùng — kiểm trong cùng một câu UPDATE để hai
     request đồng thời không cùng đổi được một vé.
  2. Rate-limit theo IP — chặn dò vé bằng brute force.
  3. Thông điệp lỗi ĐỒNG NHẤT cho mọi trường hợp sai (hết hạn / đã dùng /
     không tồn tại). Nếu phân biệt, kẻ tấn công sẽ biết mình đoán gần đúng hay
     chưa.
  4. Vé 24 byte ngẫu nhiên — không gian tìm kiếm quá lớn để dò trong vài phút
     mà vé còn hiệu lực.
"""
from __future__ import annotations

import time
from datetime import datetime, timezone
from typing import Dict, List, Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from database import sql
from dependencies import open_connection
from security_auth import generate_token, hash_token
from server_config import CONFIG

router = APIRouter(prefix="/devices", tags=["Device Enrollment"])

# Thông điệp DUY NHẤT trả về cho mọi lý do thất bại — xem lý do #3 ở docstring.
_GENERIC_ERROR = (
    "Mã đăng ký không hợp lệ hoặc đã hết hạn. Hãy xin quản lý cấp mã mới."
)

# ── Rate limit đơn giản trong bộ nhớ ────────────────────────────────────────
# Đủ cho một server biên phục vụ vài chục thiết bị. Nếu sau này chạy nhiều
# worker hoặc nhiều instance thì phải chuyển sang Redis.
_MAX_ATTEMPTS = 10
_WINDOW_SECONDS = 300
_attempts: Dict[str, List[float]] = {}


def _check_rate_limit(client_ip: str) -> None:
    now = time.time()
    window = _attempts.setdefault(client_ip, [])
    # Bỏ các lần thử đã ra ngoài cửa sổ thời gian
    window[:] = [t for t in window if now - t < _WINDOW_SECONDS]
    if len(window) >= _MAX_ATTEMPTS:
        raise HTTPException(
            429,
            f"Thử quá nhiều lần. Đợi {_WINDOW_SECONDS // 60} phút rồi thử lại.",
        )
    window.append(now)


class EnrollPayload(BaseModel):
    token: str
    device_id: str
    device_name: Optional[str] = None
    platform: Optional[str] = None
    user_id: Optional[str] = None
    # Public key để đăng ký luôn vào sổ thiết bị, tận dụng hạ tầng danh tính
    # đã có sẵn trong app (device_identity_service.dart).
    public_key: Optional[str] = None
    signing_public_key: Optional[str] = None


@router.post("/enroll")
async def enroll_device(payload: EnrollPayload, request: Request):
    """
    Đổi vé mời lấy token riêng của thiết bị.

    Thiết bị KHÔNG bao giờ nhận được IZIIAPP_SERVER_SECRET — nó chỉ có token
    của chính mình, thu hồi riêng lẻ được, và mọi thay đổi nó tạo ra đều truy
    được về đúng máy nào qua `actor_device_id` trong mutation log.
    """
    client_ip = request.client.host if request.client else "unknown"
    _check_rate_limit(client_ip)

    if not payload.token or not payload.device_id:
        raise HTTPException(400, _GENERIC_ERROR)

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()

    with open_connection() as conn:
        # Đọc chế độ TRƯỚC khi đánh dấu đã dùng — sau khi UPDATE thì vẫn đọc
        # được, nhưng đọc trước cho rõ ràng về thứ tự.
        ticket_row = conn.execute(
            sql(
                "SELECT profile, owner_user_id, owner_user_name, session_max_hours "
                "FROM enrollment_tokens WHERE token = ?"
            ),
            (payload.token,),
        ).fetchone()

        # Đánh dấu vé đã dùng NGAY trong câu UPDATE có điều kiện. Cách này
        # nguyên tử: hai thiết bị chạm cùng lúc thì chỉ một cái có rowcount=1,
        # cái còn lại nhận 0 và bị từ chối. Nếu tách thành SELECT rồi UPDATE
        # thì sẽ có khe hở cho cả hai cùng qua.
        cur = conn.execute(
            sql(
                "UPDATE enrollment_tokens SET used_at = ?, used_by = ? "
                "WHERE token = ? AND used_at IS NULL AND expires_at > ?"
            ),
            (now_iso, payload.device_id, payload.token, now_iso),
        )
        if not cur.rowcount:
            conn.commit()
            print(f"⛔ [ENROLL] Từ chối vé không hợp lệ từ {client_ip}")
            raise HTTPException(403, _GENERIC_ERROR)

        # Chế độ LẤY TỪ VÉ, không lấy từ payload do client gửi lên — nếu tin
        # client thì ai cũng tự nâng máy mình thành 'personal' để khỏi điểm danh.
        profile = "shared"
        owner_user_id = None
        owner_user_name = None
        session_max_hours = None
        if ticket_row:
            profile = (ticket_row["profile"] or "shared")
            owner_user_id = ticket_row["owner_user_id"]
            owner_user_name = ticket_row["owner_user_name"]
            session_max_hours = ticket_row["session_max_hours"]

        # Cấp token riêng, chỉ lưu HASH.
        device_token = generate_token()
        # Máy cá nhân: user_id chính là chủ máy — đây là thứ thay thế cho việc
        # điểm danh đầu ca.
        effective_user = owner_user_id if profile == "personal" else (payload.user_id or "")
        conn.execute(
            sql(
                "INSERT OR REPLACE INTO device_tokens "
                "(device_id, token_hash, scope, device_name, user_id, issued_at, "
                " profile, owner_user_id, owner_user_name, session_max_hours) "
                "VALUES (?, ?, 'device', ?, ?, ?, ?, ?, ?, ?)"
            )
            if CONFIG.db_backend != "postgres"
            else (
                "INSERT INTO device_tokens "
                "(device_id, token_hash, scope, device_name, user_id, issued_at, "
                " profile, owner_user_id, owner_user_name, session_max_hours) "
                "VALUES (%s, %s, 'device', %s, %s, %s, %s, %s, %s, %s) "
                "ON CONFLICT (device_id) DO UPDATE SET "
                "  token_hash = EXCLUDED.token_hash, "
                "  device_name = EXCLUDED.device_name, "
                "  user_id = EXCLUDED.user_id, "
                "  issued_at = EXCLUDED.issued_at, "
                "  profile = EXCLUDED.profile, "
                "  owner_user_id = EXCLUDED.owner_user_id, "
                "  owner_user_name = EXCLUDED.owner_user_name, "
                "  session_max_hours = EXCLUDED.session_max_hours, "
                "  revoked_at = NULL"
            ),
            (
                payload.device_id,
                hash_token(device_token),
                payload.device_name or "",
                effective_user,
                now_iso,
                profile,
                owner_user_id,
                owner_user_name,
                session_max_hours,
            ),
        )

        # Đăng ký luôn vào sổ thiết bị nếu có public key — gộp hai bước thành
        # một để công nhân chỉ phải chạm đúng một lần.
        if payload.public_key:
            try:
                import hashlib
                fingerprint = hashlib.sha256(payload.public_key.encode()).hexdigest()[:8].upper()
                if CONFIG.db_backend == "postgres":
                    conn.execute(
                        "INSERT INTO devices (device_id, user_id, public_key, signing_public_key, "
                        "device_name, platform, fingerprint, registered_at, last_seen_at) "
                        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) "
                        "ON CONFLICT (device_id) DO UPDATE SET "
                        "  public_key = EXCLUDED.public_key, "
                        "  signing_public_key = EXCLUDED.signing_public_key, "
                        "  last_seen_at = EXCLUDED.last_seen_at",
                        (payload.device_id, payload.user_id or "", payload.public_key,
                         payload.signing_public_key, payload.device_name or "",
                         payload.platform or "", fingerprint, now_iso, now_iso),
                    )
                else:
                    conn.execute(
                        "INSERT OR REPLACE INTO devices (device_id, user_id, public_key, "
                        "signing_public_key, device_name, platform, fingerprint, "
                        "registered_at, last_seen_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        (payload.device_id, payload.user_id or "", payload.public_key,
                         payload.signing_public_key, payload.device_name or "",
                         payload.platform or "", fingerprint, now_iso, now_iso),
                    )
            except Exception as e:
                # Không chặn enroll chỉ vì sổ thiết bị lỗi — token vẫn hợp lệ.
                print(f"⚠️  [ENROLL] Không ghi được vào bảng devices: {e}")

        conn.commit()

    # Đăng ký thành công thì xoá lịch sử rate-limit của IP đó.
    _attempts.pop(client_ip, None)

    print(
        f"✅ [ENROLL] Thiết bị {payload.device_id} ({payload.device_name or '-'}) "
        f"đã đăng ký từ {client_ip} — chế độ {profile}"
        + (f", chủ máy {owner_user_name or owner_user_id}" if profile == "personal" else "")
    )

    return {
        "status": "success",
        "device_token": device_token,   # LẦN DUY NHẤT token xuất hiện dạng gốc
        "device_id": payload.device_id,
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "issued_at": now_iso,
        # Máy dùng thông tin này để biết có phải hiện màn hình điểm danh không.
        "profile": profile,
        "owner_user_id": owner_user_id,
        "owner_user_name": owner_user_name,
        "session_max_hours": session_max_hours,
        "requires_check_in": profile == "shared",
        "note": "Lưu device_token vào secure storage. Server chỉ giữ hash nên "
                "không cấp lại được — mất thì phải đăng ký lại.",
    }


@router.get("/directory")
async def device_directory(request: Request):
    """
    Danh bạ các thiết bị đã đăng ký — nguồn danh sách liên hệ cho Chat.

    MÔ HÌNH "MỘT THIẾT BỊ = MỘT USER": mỗi thiết bị đã enroll trở thành một
    danh tính trong app, thay cho các User demo (Quill Phan, Trần Thị Bích...).
    Endpoint này là thứ để mỗi máy biết những máy nào khác đang tồn tại.

    KHÔNG trả về bất kỳ bí mật nào — chỉ id, tên, zone và thời điểm hoạt động
    gần nhất. Cùng loại thông tin mà /api/v1/devices/online vốn đã công khai.
    Thiết bị đã thu hồi bị loại khỏi danh sách.
    """
    # Nếu server yêu cầu device token thì danh bạ cũng phải có token — tránh
    # người ngoài LAN liệt kê được toàn bộ thiết bị của nhà máy.
    if CONFIG.require_device_token:
        from security_auth import lookup_device_by_token
        token = request.headers.get("X-iZii-Device-Token")
        if not token:
            raise HTTPException(401, "Thiếu X-iZii-Device-Token.")
        with open_connection() as conn:
            if lookup_device_by_token(conn, token) is None:
                raise HTTPException(401, "Device token không hợp lệ hoặc đã bị thu hồi.")

    with open_connection() as conn:
        rows = conn.execute(
            "SELECT dt.device_id, dt.device_name, dt.user_id, dt.issued_at, "
            "       dt.last_used_at, d.platform "
            "FROM device_tokens dt "
            "LEFT JOIN devices d ON d.device_id = dt.device_id "
            "WHERE dt.revoked_at IS NULL "
            "ORDER BY dt.device_name, dt.device_id"
        ).fetchall()

    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "devices": [
            {
                "device_id": r["device_id"],
                "device_name": r["device_name"] or r["device_id"],
                "user_id": r["user_id"] or "",
                "platform": r["platform"] or "",
                "issued_at": r["issued_at"],
                "last_used_at": r["last_used_at"],
            }
            for r in rows
        ],
    }


@router.get("/enroll/status")
async def enroll_status():
    """
    Thiết bị hỏi trước khi enroll: server này có bắt buộc token không.
    Không cần xác thực — chỉ trả thông tin chính sách, không lộ dữ liệu.
    """
    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "require_device_token": CONFIG.require_device_token,
        "enrollment_ttl_seconds": CONFIG.enrollment_token_ttl,
    }
