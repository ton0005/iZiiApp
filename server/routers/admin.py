# server/routers/admin.py
"""
Admin Router — thao tác vận hành nguy hiểm, KHÔNG dành cho thiết bị thường.

Hiện chỉ có 1 endpoint: POST /admin/reset — xoá sạch dữ liệu của server này
để bắt đầu lại từ đầu.

VÌ SAO CẦN ENDPOINT NÀY thay vì chỉ xoá file .db:
- Xoá file thôi là chưa đủ. Server giữ con trỏ đồng bộ với từng peer ở HAI nơi:
  bảng `known_servers` (bền vững) và dict `_peer_last_sync` trong RAM của
  tiến trình đang chạy (app.py). Nếu chỉ xoá file rồi khởi động lại thì RAM
  sạch, nhưng nếu KHÔNG khởi động lại thì server vẫn nghĩ nó đã sync tới mốc
  cũ và sẽ bỏ qua toàn bộ dữ liệu mới.
- Endpoint này xử lý cả hai, nên reset được mà không cần dừng tiến trình.

BẢO MẬT: bắt buộc header X-iZii-Server-Token khớp IZIIAPP_SERVER_SECRET, và
body phải chứa `confirm` = đúng server_id của chính server này. Hai lớp này
để tránh gọi nhầm vào server sản xuất khi đang định reset server test.
"""
import os
import shutil
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel

from database import sql
from dependencies import open_connection
from security_auth import (
    generate_enrollment_code,
    hash_token,
    verify_admin_secret,
)
from server_config import CONFIG

router = APIRouter(prefix="/admin", tags=["Admin (Dangerous)"])


# ══════════════════════════════════════════════════════════════════════════════
#  Quản lý cấu hình .env từ xa (màn hình Settings của app)
# ══════════════════════════════════════════════════════════════════════════════
# Giá trị thay thế cho secret khi TRẢ VỀ client. Nếu client gửi lại đúng chuỗi
# này nghĩa là "không đổi" — nhờ vậy admin sửa một trường mà không vô tình xoá
# trắng các secret khác.
SECRET_MASK = "••••••••"

# Chỉ những khoá trong danh sách này mới được đọc/ghi. Danh sách trắng chứ
# không phải danh sách đen: thêm khoá mới phải sửa ở đây, tránh việc ai đó ghi
# đè biến môi trường tuỳ ý của tiến trình.
_EDITABLE_KEYS: Dict[str, bool] = {
    # key                              : có phải secret không
    "IZIIAPP_SERVER_ID":                False,
    "IZIIAPP_ZONE":                     False,
    "IZIIAPP_PEERS":                    False,
    "IZIIAPP_SYNC_INTERVAL_SECONDS":    False,
    "IZIIAPP_SERVER_SECRET":            True,
    "IZIIAPP_WS_SECRET":                True,
    "IZIIAPP_SERVER_DB_PATH":           False,
    # B1 — phân tách phạm vi bí mật & đăng ký thiết bị
    "IZIIAPP_ADMIN_SECRET":             True,
    "IZIIAPP_REQUIRE_DEVICE_TOKEN":     False,
    "IZIIAPP_ENROLLMENT_TOKEN_TTL":     False,
    # 6.3 — Database backend
    "IZIIAPP_DB_BACKEND":               False,
    "IZIIAPP_PG_DSN":                   True,   # chứa mật khẩu trong chuỗi
    "IZIIAPP_PG_POOL_MIN":              False,
    "IZIIAPP_PG_POOL_MAX":              False,
    # 6.4 — TLS / mTLS
    "IZIIAPP_TLS_CERT_FILE":            False,
    "IZIIAPP_TLS_KEY_FILE":             False,
    "IZIIAPP_TLS_CA_FILE":              False,
    "IZIIAPP_TLS_REQUIRE_CLIENT_CERT":  False,
    "IZIIAPP_TLS_ALLOWED_PEER_CNS":     False,
    # 6.4 — OAuth2 chiều ra
    "IZIIAPP_OAUTH_TOKEN_URL":          False,
    "IZIIAPP_OAUTH_CLIENT_ID":          False,
    "IZIIAPP_OAUTH_CLIENT_SECRET":      True,
    "IZIIAPP_OAUTH_SCOPE":              False,
}


def _env_path() -> str:
    """
    Đường dẫn .env mà server đang thực sự dùng — phải khớp với thứ tự dò trong
    server_config._load_env_file(), nếu không admin sẽ sửa nhầm file.
    """
    import sys
    candidates = []
    if getattr(sys, "frozen", False):
        candidates.append(os.path.join(os.path.dirname(sys.executable), ".env"))
    # admin.py nằm trong routers/ nên phải lùi một cấp để ra thư mục server/
    candidates.append(
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
    )
    candidates.append(os.path.join(os.getcwd(), ".env"))
    for c in candidates:
        if os.path.exists(c):
            return c
    return candidates[0]


def _read_env_file() -> Dict[str, str]:
    path = _env_path()
    values: Dict[str, str] = {}
    if not os.path.exists(path):
        return values
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            values[k.strip()] = v.strip().strip("'").strip('"')
    return values


def _write_env_file(updates: Dict[str, str]) -> str:
    """
    Ghi đè các khoá trong .env, GIỮ NGUYÊN chú thích và thứ tự dòng.

    Không dùng cách "đọc dict rồi ghi lại toàn bộ" vì sẽ xoá sạch phần chú
    thích giải thích trong .env — thứ mà người vận hành cần khi đọc file trực
    tiếp trên máy chủ.
    """
    path = _env_path()

    # Sao lưu trước khi sửa — cấu hình sai có thể làm server không khởi động lại được.
    if os.path.exists(path):
        backup = f"{path}.bak-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        try:
            shutil.copy2(path, backup)
        except Exception as e:
            print(f"⚠️  [ADMIN-CONFIG] Không sao lưu được .env: {e}")

    lines: list[str] = []
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            lines = f.read().splitlines()

    remaining = dict(updates)
    out: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            key = stripped.split("=", 1)[0].strip()
            if key in remaining:
                out.append(f"{key}={remaining.pop(key)}")
                continue
        out.append(line)

    if remaining:
        out.append("")
        out.append(f"# Thêm bởi màn hình Settings lúc {datetime.now(timezone.utc).isoformat()}")
        for k, v in remaining.items():
            out.append(f"{k}={v}")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")

    return path


# Nhật ký đồng bộ + hàng đợi phái sinh. Luôn bị xoá khi reset.
#
# ⚠️ CỐ Ý KHÔNG có `sync_sequence` trong danh sách này. Bộ đếm seq phải LUÔN
# tăng, kể cả sau khi xoá sạch mutation log. Nếu reset nó về 0 thì các seq mới
# sẽ trùng với seq cũ mà client/peer còn nhớ, khiến chúng tưởng đã nhận rồi và
# BỎ QUA dữ liệu mới. Đừng "dọn dẹp" thêm bảng này.
_LOG_TABLES = [
    "sync_mutations",       # mutation log — nguồn khiến dữ liệu "sống lại"
    "known_servers",        # con trỏ sync với peer (bền vững)
    "webhook_dead_letters",
]

# Danh tính thiết bị + hộp thư. Chỉ xoá khi keep_devices = False.
_DEVICE_TABLES = [
    "message_queue",
    "notifications",
    "notification_settings",
    "devices",
]


def _verify_admin_token(token: Optional[str]) -> None:
    """
    Xác thực phạm vi ADMIN — nay tách khỏi phạm vi server (B1).

    Ưu tiên IZIIAPP_ADMIN_SECRET; chưa khai thì server_config tự fallback về
    IZIIAPP_SERVER_SECRET kèm cảnh báo, nên bản triển khai cũ không gãy ngay.
    """
    verify_admin_secret(token)


class ConfigUpdatePayload(BaseModel):
    # Chỉ gửi những khoá muốn đổi. Secret giữ nguyên thì gửi lại SECRET_MASK
    # hoặc bỏ hẳn khỏi payload.
    values: Dict[str, str]


@router.get("/config")
async def get_config(
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token")
):
    """
    Đọc cấu hình hiện tại để hiển thị trên màn hình Settings.

    Secret LUÔN bị che. Không có cách nào lấy lại giá trị secret qua API này —
    nếu quên thì phải đặt giá trị mới, đó là chủ ý.
    """
    _verify_admin_token(x_izii_server_token)

    from security_tls import tls_enabled, mtls_enabled

    stored = _read_env_file()
    values: Dict[str, Any] = {}
    for key, is_secret in _EDITABLE_KEYS.items():
        raw = stored.get(key, "")
        if is_secret and raw:
            values[key] = SECRET_MASK
        else:
            values[key] = raw

    # Trạng thái file chứng chỉ — giúp admin biết ngay vì sao mTLS chưa bật
    # mà không phải SSH vào máy chủ kiểm tra.
    def _file_status(path: str) -> Dict[str, Any]:
        if not path:
            return {"path": "", "exists": False}
        abs_path = path if os.path.isabs(path) else os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))), path
        )
        return {"path": path, "exists": os.path.exists(abs_path)}

    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "env_file": _env_path(),
        "env_file_exists": os.path.exists(_env_path()),
        "values": values,
        "secret_mask": SECRET_MASK,
        # Trạng thái ĐANG CHẠY — có thể khác giá trị trong .env nếu chưa restart.
        "runtime": {
            "db_backend": CONFIG.db_backend,
            "tls_enabled": tls_enabled(),
            "mtls_enabled": mtls_enabled(),
            "oauth_configured": bool(
                CONFIG.oauth_token_url and CONFIG.oauth_client_id and CONFIG.oauth_client_secret
            ),
            "peers_configured": CONFIG.peers,
        },
        "certs": {
            "cert": _file_status(CONFIG.tls_cert_file),
            "key": _file_status(CONFIG.tls_key_file),
            "ca": _file_status(CONFIG.tls_ca_file),
        },
    }


@router.put("/config")
async def update_config(
    payload: ConfigUpdatePayload,
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    """
    Ghi cấu hình vào .env. KHÔNG áp dụng ngay — server đọc config đúng một lần
    lúc import module, nên bắt buộc phải khởi động lại.
    """
    _verify_admin_token(x_izii_server_token)

    updates: Dict[str, str] = {}
    rejected: list[str] = []
    for key, value in payload.values.items():
        if key not in _EDITABLE_KEYS:
            rejected.append(key)
            continue
        # Secret giữ nguyên mask = admin không đụng tới trường đó.
        if _EDITABLE_KEYS[key] and value == SECRET_MASK:
            continue
        updates[key] = value.strip()

    if rejected:
        raise HTTPException(
            status_code=400,
            detail=f"Các khoá không được phép sửa qua API: {', '.join(rejected)}",
        )

    if not updates:
        return {"status": "noop", "message": "Không có thay đổi nào.", "requires_restart": False}

    # Chặn cấu hình chắc chắn làm server không khởi động lại được.
    backend = updates.get("IZIIAPP_DB_BACKEND")
    if backend and backend not in ("sqlite", "postgres"):
        raise HTTPException(400, "IZIIAPP_DB_BACKEND chỉ nhận 'sqlite' hoặc 'postgres'.")
    if backend == "postgres":
        dsn = updates.get("IZIIAPP_PG_DSN") or _read_env_file().get("IZIIAPP_PG_DSN", "")
        if not dsn:
            raise HTTPException(400, "Chọn backend postgres thì phải có IZIIAPP_PG_DSN.")

    # Chặn tự khoá mình ra ngoài: xoá trắng admin secret trong khi server secret
    # cũng trống nghĩa là sau khi khởi động lại KHÔNG AI gọi được /admin/* nữa,
    # kể cả để sửa lại. Lúc đó chỉ còn cách sửa .env trực tiếp trên máy chủ.
    if "IZIIAPP_ADMIN_SECRET" in updates and not updates["IZIIAPP_ADMIN_SECRET"]:
        stored = _read_env_file()
        fallback = updates.get("IZIIAPP_SERVER_SECRET", stored.get("IZIIAPP_SERVER_SECRET", ""))
        if not fallback:
            raise HTTPException(
                400,
                "Không thể xoá trắng IZIIAPP_ADMIN_SECRET khi IZIIAPP_SERVER_SECRET "
                "cũng trống — sau khi khởi động lại sẽ không ai vào được /admin/* "
                "để sửa lại. Đặt một trong hai giá trị trước.",
            )

    # Bật bắt buộc device token khi chưa có thiết bị nào đăng ký = cả nhà máy
    # mất kết nối ngay lần khởi động sau.
    if str(updates.get("IZIIAPP_REQUIRE_DEVICE_TOKEN", "")).lower() in ("1", "true", "yes"):
        try:
            with open_connection() as conn:
                row = conn.execute(
                    "SELECT COUNT(*) AS c FROM device_tokens WHERE revoked_at IS NULL"
                ).fetchone()
            active = int(row["c"]) if row else 0
        except Exception:
            active = 0
        if active == 0:
            raise HTTPException(
                400,
                "Chưa có thiết bị nào đăng ký mà bật IZIIAPP_REQUIRE_DEVICE_TOKEN "
                "sẽ khiến MỌI thiết bị mất kết nối sau khi khởi động lại. "
                "Đăng ký ít nhất một máy trước.",
            )

    try:
        path = _write_env_file(updates)
    except Exception as e:
        raise HTTPException(500, f"Không ghi được .env: {e}")

    print(f"⚙️  [ADMIN-CONFIG] Đã cập nhật {len(updates)} khoá trong {path}")
    return {
        "status": "success",
        "env_file": path,
        "updated_keys": sorted(updates.keys()),
        "requires_restart": True,
        "message": (
            "Đã ghi vào .env. Cấu hình CHỈ có hiệu lực sau khi khởi động lại server "
            "— config được đọc một lần lúc nạp module."
        ),
    }


# ══════════════════════════════════════════════════════════════════════════════
#  Enrollment — cấp "vé mời" đăng ký thiết bị (B2)
# ══════════════════════════════════════════════════════════════════════════════

class EnrollmentTokenPayload(BaseModel):
    # Ghi chú tự do để admin nhớ vé này cấp cho ai/việc gì.
    note: Optional[str] = None
    # Cho phép ghi đè TTL, ví dụ vé dán lên thẻ NFC cần sống lâu hơn.
    ttl_seconds: Optional[int] = None

    # ── Chế độ thiết bị ─────────────────────────────────────────────────────
    # 'shared'   : tablet dùng chung tại phòng → BẮT BUỘC điểm danh mỗi ca
    # 'personal' : iPhone/iPad riêng của Manager, Supervisor → KHÔNG cần điểm
    #              danh, danh tính đã xác định từ lúc cấp máy
    #
    # Quản lý chọn lúc CẤP MÃ chứ không phải lúc quét: người nhận máy không
    # chọn sai được, và không cần hiểu sự khác biệt.
    profile: str = "shared"
    owner_user_id: Optional[str] = None      # bắt buộc khi profile='personal'
    owner_user_name: Optional[str] = None
    # Số giờ tối đa của một ca trên máy này. None = mặc định theo chế độ
    # (shared: 12 giờ · personal: không giới hạn).
    session_max_hours: Optional[int] = None


@router.post("/enrollment-token")
async def create_enrollment_token(
    payload: EnrollmentTokenPayload,
    request: Request,
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    """
    Sinh vé mời dùng MỘT LẦN để đăng ký thiết bị mới.

    Vé này là thứ được ghi lên thẻ NFC hoặc hiển thị dưới dạng QR — KHÔNG PHẢI
    secret của hệ thống. Mất vé chỉ mất một cơ hội đăng ký trong vài phút.
    """
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)

    from datetime import timedelta

    profile = (payload.profile or "shared").strip().lower()
    if profile not in ("shared", "personal"):
        raise HTTPException(400, "profile chỉ nhận 'shared' hoặc 'personal'.")

    # Máy cá nhân PHẢI có chủ. Không có chủ thì danh tính vô định — mà đó lại
    # chính là lý do tồn tại của chế độ này (thay cho việc điểm danh).
    if profile == "personal" and not (payload.owner_user_id or "").strip():
        raise HTTPException(
            400,
            "Máy cá nhân phải khai owner_user_id — đây là danh tính thay cho việc "
            "điểm danh đầu ca.",
        )

    max_hours = payload.session_max_hours
    if max_hours is not None:
        # 0 hoặc âm = không giới hạn (dùng cho máy cá nhân mang về nhà).
        max_hours = None if max_hours <= 0 else min(max_hours, 24 * 30)

    ttl = payload.ttl_seconds or CONFIG.enrollment_token_ttl
    # Chặn TTL vô lý: quá ngắn thì không kịp chạm thẻ, quá dài thì mất ý nghĩa
    # bảo mật của vé ngắn hạn.
    ttl = max(60, min(ttl, 86400))

    now = datetime.now(timezone.utc)
    token = generate_enrollment_code()
    expires_at = (now + timedelta(seconds=ttl)).isoformat()

    with open_connection() as conn:
        # Dọn vé hết hạn để bảng không phình theo thời gian.
        try:
            conn.execute(
                sql("DELETE FROM enrollment_tokens WHERE expires_at < ? AND used_at IS NULL"),
                (now.isoformat(),),
            )
        except Exception:
            pass
        conn.execute(
            sql(
                "INSERT INTO enrollment_tokens "
                "(token, created_by, created_at, expires_at, note, profile, "
                " owner_user_id, owner_user_name, session_max_hours) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            ),
            (token, CONFIG.server_id, now.isoformat(), expires_at, payload.note,
             profile, payload.owner_user_id, payload.owner_user_name, max_hours),
        )
        conn.commit()

    print(
        f"🎟️  [ENROLL] Đã cấp vé mời ({profile}), hết hạn {expires_at}"
        + (f" — chủ máy: {payload.owner_user_name or payload.owner_user_id}"
           if profile == "personal" else "")
    )

    # Client dùng chuỗi này để sinh QR hoặc ghi lên thẻ NDEF.
    #
    # CỐ Ý KHÔNG nhét profile vào URI: vé đã ghi sẵn chế độ trong database, máy
    # nhận sẽ biết khi đổi vé. Nhét thêm vào URI vừa tốn dung lượng thẻ NTAG213
    # vừa cho phép sửa chuỗi để tự nâng máy mình thành 'personal'.
    from urllib.parse import quote
    base = str(request.base_url).rstrip("/")
    base_encoded = quote(base, safe='')
    return {
        "token": token,
        "expires_at": expires_at,
        "ttl_seconds": ttl,
        "server_url": base,
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "profile": profile,
        "owner_user_id": payload.owner_user_id,
        "owner_user_name": payload.owner_user_name,
        "session_max_hours": max_hours,
        "payload_uri": f"izii://enroll?t={token}&u={base_encoded}&z={CONFIG.zone}",
    }


@router.get("/devices")
async def list_enrolled_devices(
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    """Danh sách thiết bị đã đăng ký, phục vụ màn hình quản lý + thu hồi."""
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)

    with open_connection() as conn:
        rows = conn.execute(
            "SELECT device_id, device_name, user_id, scope, issued_at, "
            "last_used_at, revoked_at, profile, owner_user_id, owner_user_name, "
            "session_max_hours FROM device_tokens ORDER BY issued_at DESC"
        ).fetchall()

    def _col(row, name):
        # Database chưa chạy migration thì thiếu cột — trả None thay vì 500.
        try:
            return row[name]
        except (IndexError, KeyError):
            return None

    return {
        "devices": [
            {
                "device_id": r["device_id"],
                "device_name": r["device_name"],
                "user_id": r["user_id"],
                "scope": r["scope"],
                "issued_at": r["issued_at"],
                "last_used_at": r["last_used_at"],
                "revoked_at": r["revoked_at"],
                "active": r["revoked_at"] is None,
                "profile": _col(r, "profile") or "shared",
                "owner_user_id": _col(r, "owner_user_id"),
                "owner_user_name": _col(r, "owner_user_name"),
                "session_max_hours": _col(r, "session_max_hours"),
            }
            for r in rows
        ],
        "require_device_token": CONFIG.require_device_token,
    }


@router.post("/devices/{device_id}/revoke")
async def revoke_device(
    device_id: str,
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    """
    Thu hồi token của MỘT thiết bị — điện thoại mất, nhân viên nghỉ việc.

    Đây chính là điều không làm được khi dùng chung một secret: trước đây muốn
    chặn một máy thì phải đổi secret trên toàn bộ mesh và cấu hình lại mọi
    thiết bị còn lại.
    """
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)

    now = datetime.now(timezone.utc).isoformat()
    with open_connection() as conn:
        cur = conn.execute(
            sql("UPDATE device_tokens SET revoked_at = ? WHERE device_id = ? AND revoked_at IS NULL"),
            (now, device_id),
        )
        affected = cur.rowcount
        conn.commit()

    if not affected:
        raise HTTPException(404, f"Không tìm thấy thiết bị đang hoạt động: {device_id}")

    print(f"🚫 [ENROLL] Đã thu hồi token của thiết bị {device_id}")
    return {"status": "success", "device_id": device_id, "revoked_at": now}


class ResetPayload(BaseModel):
    # Phải bằng đúng CONFIG.server_id — chống gõ nhầm vào server khác.
    confirm: str
    # True = giữ lại thiết bị đã đăng ký (không phải ghép cặp/đăng ký lại).
    keep_devices: bool = False


@router.post("/reset")
async def admin_reset(payload: ResetPayload, request: Request,
                      x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token")):
    _verify_admin_token(x_izii_server_token)

    if payload.confirm != CONFIG.server_id:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Trường 'confirm' phải bằng đúng server_id của server này "
                f"('{CONFIG.server_id}') để xác nhận. Nhận được: '{payload.confirm}'."
            ),
        )

    tables = list(_LOG_TABLES)
    if not payload.keep_devices:
        tables += _DEVICE_TABLES

    deleted: dict[str, int] = {}
    with open_connection() as conn:
        for table in tables:
            try:
                cur = conn.execute(f"DELETE FROM {table}")
                deleted[table] = cur.rowcount if cur.rowcount and cur.rowcount > 0 else 0
            except Exception as e:
                # Bảng có thể chưa tồn tại trên DB cũ — không để chết cả request.
                deleted[table] = -1
                print(f"⚠️  [ADMIN-RESET] Bỏ qua bảng {table}: {e}")
        conn.commit()

        # Thu hồi dung lượng. VACUUM phải chạy NGOÀI transaction ở cả hai
        # backend, nhưng cách tắt transaction thì khác nhau.
        try:
            if CONFIG.db_backend == "postgres":
                conn.commit()
                old_autocommit = conn.autocommit
                conn.autocommit = True
                conn.execute("VACUUM")
                conn.autocommit = old_autocommit
            else:
                conn.isolation_level = None
                conn.execute("VACUUM")
        except Exception as e:
            print(f"⚠️  [ADMIN-RESET] VACUUM thất bại (không nghiêm trọng): {e}")

    # Xoá con trỏ sync đang nằm trong RAM của tiến trình — nếu bỏ bước này,
    # server vẫn nghĩ đã đồng bộ tới mốc cũ và sẽ bỏ qua dữ liệu mới cho tới
    # khi khởi động lại.
    peer_cursor = getattr(request.app.state, "peer_last_sync", None)
    cleared_peers = 0
    if isinstance(peer_cursor, dict):
        cleared_peers = len(peer_cursor)
        peer_cursor.clear()

    total = sum(v for v in deleted.values() if v > 0)
    print(
        f"🔥 [ADMIN-RESET] Đã xoá {total} bản ghi trên {len(tables)} bảng, "
        f"reset {cleared_peers} con trỏ peer. keep_devices={payload.keep_devices}"
    )

    return {
        "status": "success",
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "keep_devices": payload.keep_devices,
        "deleted_rows": deleted,
        "cleared_peer_cursors": cleared_peers,
        "reset_at": datetime.now(timezone.utc).isoformat(),
        "note": (
            "Các thiết bị vẫn giữ con trỏ 'last_sync_timestamp' riêng trong "
            "SharedPreferences. Phải xoá dữ liệu ứng dụng trên TỪNG thiết bị, "
            "nếu không chúng sẽ đẩy dữ liệu cũ ngược lên server."
        ),
    }


# ══════════════════════════════════════════════════════════════════════════════
#  Phase 2 — Quản lý Module & Bounded Context (P2.1, P2.3)
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/modules", summary="Liệt kê toàn bộ module và trạng thái kích hoạt theo tenant")
async def list_modules(
    tenant_id: str = "default",
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)
    from modules.module_manager import MODULE_MANAGER

    active = set(MODULE_MANAGER.get_active_modules(tenant_id))
    installed_models = MODULE_MANAGER.get_model_registry(tenant_id)

    res = []
    for mod_name in MODULE_MANAGER.sorted_modules:
        manifest = MODULE_MANAGER.manifests[mod_name]
        res.append({
            "name": manifest.name,
            "version": manifest.version,
            "display_name": manifest.display_name,
            "depends": manifest.depends,
            "owns_tables": manifest.owns_tables,
            "models": manifest.models,
            "min_client_schema_version": manifest.min_client_schema_version,
            "enabled": mod_name in active,
            "installed": MODULE_MANAGER.is_module_installed(mod_name, tenant_id),
        })

    return {
        "tenant_id": tenant_id,
        "modules": res,
        "active_modules": list(active),
        "models_count": len(installed_models),
    }


@router.post("/modules/{name}/enable", summary="Kích hoạt module cho tenant")
async def enable_module_endpoint(
    name: str,
    tenant_id: str = "default",
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)
    from modules.module_manager import MODULE_MANAGER
    try:
        MODULE_MANAGER.enable_module(name, tenant_id)
        return {
            "status": "success",
            "module": name,
            "tenant_id": tenant_id,
            "enabled": True,
            "active_modules": MODULE_MANAGER.get_active_modules(tenant_id),
        }
    except ValueError as e:
        raise HTTPException(400, detail=str(e))


@router.post("/modules/{name}/disable", summary="Tắt module cho tenant")
async def disable_module_endpoint(
    name: str,
    tenant_id: str = "default",
    x_izii_admin_token: Optional[str] = Header(None, alias="X-iZii-Admin-Token"),
    x_izii_server_token: Optional[str] = Header(None, alias="X-iZii-Server-Token"),
):
    verify_admin_secret(x_izii_admin_token or x_izii_server_token)
    from modules.module_manager import MODULE_MANAGER
    try:
        MODULE_MANAGER.disable_module(name, tenant_id)
        return {
            "status": "success",
            "module": name,
            "tenant_id": tenant_id,
            "enabled": False,
            "active_modules": MODULE_MANAGER.get_active_modules(tenant_id),
        }
    except ValueError as e:
        raise HTTPException(400, detail=str(e))
