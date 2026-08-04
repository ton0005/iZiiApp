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
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel

from database import get_db_connection
from server_config import CONFIG

router = APIRouter(prefix="/admin", tags=["Admin (Dangerous)"])


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
    if not CONFIG.server_secret:
        raise HTTPException(
            status_code=503,
            detail=(
                "Server chưa cấu hình IZIIAPP_SERVER_SECRET — từ chối thao tác reset. "
                "Set secret trong .env rồi khởi động lại server."
            ),
        )
    if token != CONFIG.server_secret:
        raise HTTPException(status_code=401, detail="Invalid or missing X-iZii-Server-Token")


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
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        for table in tables:
            try:
                cursor.execute(f"DELETE FROM {table}")
                deleted[table] = cursor.rowcount if cursor.rowcount > 0 else 0
            except Exception as e:
                # Bảng có thể chưa tồn tại trên DB cũ — không để chết cả request.
                deleted[table] = -1
                print(f"⚠️  [ADMIN-RESET] Bỏ qua bảng {table}: {e}")
        conn.commit()

        # VACUUM phải chạy ngoài transaction, nên tắt autocommit ngầm của sqlite3.
        try:
            conn.isolation_level = None
            conn.execute("VACUUM")
        except Exception as e:
            print(f"⚠️  [ADMIN-RESET] VACUUM thất bại (không nghiêm trọng): {e}")
    finally:
        conn.close()

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
