# server/security_auth.py
"""
Xác thực & phân quyền — B1: tách bạch ba phạm vi bí mật.

VẤN ĐỀ CŨ: cả hệ thống dùng chung một chuỗi `IZIIAPP_SERVER_SECRET`. Thiết bị
nào biết token đồng bộ cũng gọi được `/admin/reset` (xoá sạch database) và
`/admin/config` (ghi đè .env, đổi luôn secret rồi khoá admin thật ra ngoài).
Một điện thoại rơi trong phòng trồng là mất cả mesh, và vì secret dùng chung
nên không thu hồi riêng lẻ được.

BA PHẠM VI SAU KHI TÁCH:

    ┌──────────────┬──────────────────────┬──────────────────────────────────┐
    │ Phạm vi      │ Bí mật               │ Dùng cho                         │
    ├──────────────┼──────────────────────┼──────────────────────────────────┤
    │ server       │ IZIIAPP_SERVER_SECRET│ /peer-sync/*  (server ↔ server)  │
    │ admin        │ IZIIAPP_ADMIN_SECRET │ /admin/*      (quản trị)         │
    │ device       │ token riêng từng máy │ /sync/*, /api/v1/*  (thiết bị)   │
    └──────────────┴──────────────────────┴──────────────────────────────────┘

Token thiết bị được cấp qua luồng enrollment (xem routers/enrollment.py) và lưu
dưới dạng HASH trong bảng `device_tokens` — database bị lộ vẫn không mạo danh
được thiết bị.
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timezone
from typing import Optional

from fastapi import Header, HTTPException, Request

from server_config import CONFIG


# ── Băm token ───────────────────────────────────────────────────────────────

def hash_token(token: str) -> str:
    """
    SHA-256 của token. Không cần bcrypt/argon2 ở đây vì token là chuỗi ngẫu
    nhiên 32 byte do server sinh — không có entropy thấp như mật khẩu người
    dùng nên không sợ tấn công từ điển, và ta cần tra cứu nhanh theo hash.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_token(nbytes: int = 32) -> str:
    return secrets.token_urlsafe(nbytes)


def generate_enrollment_code(nbytes: int = 24) -> str:
    """
    Vé mời ngắn hơn token thiết bị vì phải nhét vừa thẻ NTAG213 (144 byte) cùng
    với URL. 24 byte ≈ 32 ký tự base64url — vẫn quá đủ để chống dò.
    """
    return secrets.token_urlsafe(nbytes)


def _constant_time_eq(a: Optional[str], b: Optional[str]) -> bool:
    """So sánh thời gian hằng định, an toàn với None."""
    if not a or not b:
        return False
    return hmac.compare_digest(a, b)


# ── Phạm vi: SERVER (peer-sync) ─────────────────────────────────────────────

def verify_server_secret(token: Optional[str]) -> None:
    if not CONFIG.server_secret:
        return  # chưa cấu hình → chế độ mở, đã cảnh báo lúc khởi động
    if not _constant_time_eq(token, CONFIG.server_secret):
        raise HTTPException(401, "Invalid or missing X-iZii-Server-Token")


# ── Phạm vi: ADMIN ──────────────────────────────────────────────────────────

def verify_admin_secret(token: Optional[str]) -> None:
    """
    Khác biệt quan trọng so với verify_server_secret: KHÔNG có chế độ mở.
    Chưa cấu hình admin secret thì từ chối mọi thao tác quản trị, thay vì cho
    qua. Thao tác admin xoá được cả database nên fail-closed là bắt buộc.
    """
    if not CONFIG.admin_secret:
        raise HTTPException(
            503,
            "Server chưa cấu hình IZIIAPP_ADMIN_SECRET (hoặc IZIIAPP_SERVER_SECRET) "
            "— từ chối mọi thao tác quản trị.",
        )
    if not _constant_time_eq(token, CONFIG.admin_secret):
        raise HTTPException(401, "Invalid or missing X-iZii-Admin-Token")


async def require_admin(
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    """
    Dependency cho các endpoint /admin/*.

    Chấp nhận cả header cũ `X-iZii-Server-Token` để bản app hiện tại không gãy
    ngay khi cập nhật server. Khi đã tách secret riêng, header cũ sẽ tự nhiên
    không còn khớp và client buộc phải chuyển sang header mới.
    """
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)


# ── Phạm vi: DEVICE ─────────────────────────────────────────────────────────

class DeviceIdentity:
    """
    Thông tin thiết bị đã xác thực, gắn vào request để ghi audit.

    `user_id` có HAI nguồn, ưu tiên theo thứ tự:
      1. Phiên làm việc đang mở (G1) — người thực sự đang cầm máy
      2. Giá trị lưu lúc đăng ký thiết bị — dùng khi máy cá nhân, không điểm danh

    `session_id` khác None nghĩa là danh tính người đến từ phiên đã điểm danh —
    đây là điều kiện để tạo công việc Alone Worker.
    """

    def __init__(self, device_id: str, device_name: str = "", user_id: str = "",
                 scope: str = "device", user_name: str = "", session_id: Optional[str] = None,
                 profile: str = "shared", session_max_hours: Optional[int] = None):
        self.device_id = device_id
        self.device_name = device_name
        self.user_id = user_id
        self.user_name = user_name
        self.scope = scope
        self.session_id = session_id
        self.profile = profile
        self.session_max_hours = session_max_hours

    @property
    def is_personal(self) -> bool:
        """
        Máy cá nhân (iPhone/iPad riêng của Manager, Supervisor).

        Danh tính đã xác định từ lúc cấp máy nên không cần điểm danh — và cũng
        không nên bắt điểm danh, vì máy mang về nhà dùng riêng chứ không dùng
        chung ca kíp.
        """
        return self.profile == "personal"

    @property
    def has_active_session(self) -> bool:
        return self.session_id is not None

    @property
    def identity_is_known(self) -> bool:
        """
        Có xác định được ĐÍCH DANH ai đang dùng máy này không.

        Đây mới là điều kiện đúng cho ràng buộc Alone Worker — không phải
        "có phiên hay không". Hai đường đều cho danh tính chắc chắn:
          • Máy dùng chung → phải có phiên điểm danh
          • Máy cá nhân    → chủ máy đã khai lúc cấp máy
        """
        if self.is_personal:
            return bool(self.user_id)
        return self.has_active_session


def lookup_device_by_token(conn, token: str) -> Optional[DeviceIdentity]:
    """
    Tra thiết bị theo token. Trả None nếu không tìm thấy hoặc đã bị thu hồi.

    Truy vấn theo token_hash chứ không quét toàn bảng rồi so sánh — có index
    idx_device_tokens_hash nên O(log n).
    """
    from database import sql

    row = conn.execute(
        sql(
            "SELECT device_id, device_name, user_id, scope, revoked_at, "
            "       profile, owner_user_id, owner_user_name, session_max_hours "
            "FROM device_tokens WHERE token_hash = ?"
        ),
        (hash_token(token),),
    ).fetchone()

    if not row or row["revoked_at"]:
        return None

    # Cập nhật last_used_at để màn hình quản lý thiết bị biết máy nào còn hoạt
    # động. Lỗi ở bước này không được phép chặn request.
    try:
        conn.execute(
            sql("UPDATE device_tokens SET last_used_at = ? WHERE device_id = ?"),
            (datetime.now(timezone.utc).isoformat(), row["device_id"]),
        )
        conn.commit()
    except Exception:
        pass

    profile = _col(row, "profile") or "shared"

    identity = DeviceIdentity(
        device_id=row["device_id"],
        device_name=row["device_name"] or "",
        # Máy cá nhân: danh tính LÀ chủ máy, có sẵn ngay cả khi không điểm danh.
        user_id=(_col(row, "owner_user_id") if profile == "personal" else None)
                or row["user_id"] or "",
        user_name=_col(row, "owner_user_name") or "",
        scope=row["scope"] or "device",
        profile=profile,
        session_max_hours=_col(row, "session_max_hours"),
    )

    # Phiên làm việc đang mở GHI ĐÈ user_id — người đang cầm máy mới là người
    # chịu trách nhiệm, không phải người đã đăng ký thiết bị từ tháng trước.
    #
    # Máy cá nhân cũng tra phiên: Manager có thể chủ động bấm "bắt đầu ca" khi
    # đến nhà máy để xuất hiện trong danh sách "ai đang trong ca". Không bấm thì
    # danh tính vẫn đúng, chỉ là không tính là đang có mặt tại hiện trường.
    try:
        from routers.sessions import get_active_session
        session = get_active_session(conn, identity.device_id)
        if session:
            identity.user_id = session["user_id"]
            identity.user_name = session["user_name"] or ""
            identity.session_id = session["id"]
    except Exception as e:
        # Không chặn request chỉ vì tra phiên lỗi — mất thông tin người dùng
        # vẫn tốt hơn là chặn cả nhà máy.
        print(f"⚠️  [AUTH] Không tra được phiên làm việc: {e}")

    return identity


def _col(row, name: str):
    """
    Đọc cột có thể chưa tồn tại trên DB cũ chưa chạy migration.
    sqlite3.Row ném IndexError, psycopg dict_row ném KeyError.
    """
    try:
        return row[name]
    except (IndexError, KeyError):
        return None


async def optional_device(
    request: Request,
    x_izii_device_token: Optional[str] = Header(None, alias="X-iZii-Device-Token"),
) -> Optional[DeviceIdentity]:
    """
    Dependency cho /sync/* và các API thiết bị.

    HAI CHẾ ĐỘ, chuyển bằng IZIIAPP_REQUIRE_DEVICE_TOKEN:

    - TẮT (mặc định): thiếu token vẫn cho qua, nhưng nếu CÓ token hợp lệ thì
      gắn danh tính vào request để ghi audit. Đây là giai đoạn chuyển tiếp —
      các máy chưa enroll vẫn chạy bình thường.
    - BẬT: thiếu hoặc sai token thì 401. Chỉ bật sau khi TẤT CẢ thiết bị đã
      enroll xong, nếu không cả nhà máy mất kết nối.
    """
    identity: Optional[DeviceIdentity] = None

    if x_izii_device_token:
        from dependencies import open_connection
        try:
            with open_connection() as conn:
                identity = lookup_device_by_token(conn, x_izii_device_token)
        except Exception as e:
            print(f"⚠️  [AUTH] Lỗi tra device token: {e}")

    if CONFIG.require_device_token and identity is None:
        raise HTTPException(
            401,
            "Thiếu hoặc sai X-iZii-Device-Token. Thiết bị cần đăng ký qua "
            "mã QR/thẻ NFC trước khi đồng bộ.",
        )

    # Gắn vào request.state để router lấy ra ghi actor mà không phải khai thêm
    # tham số ở mọi endpoint.
    request.state.device = identity
    return identity


def describe_scopes() -> str:
    """Một dòng in lúc khởi động, cho biết đang ở trạng thái nào."""
    parts = []
    parts.append("server=" + ("có" if CONFIG.server_secret else "TRỐNG"))
    if CONFIG.admin_secret and CONFIG.admin_secret == CONFIG.server_secret:
        parts.append("admin=DÙNG CHUNG server (nên tách)")
    else:
        parts.append("admin=" + ("riêng" if CONFIG.admin_secret else "TRỐNG"))
    parts.append(
        "device=" + ("BẮT BUỘC" if CONFIG.require_device_token else "tuỳ chọn")
    )
    return "🔑 [AUTH] Phạm vi bí mật — " + " · ".join(parts)
