# server/server_config.py
"""
Cấu hình định danh server cho kiến trúc multi-server.

Mỗi PC/laptop chạy server sẽ có file .env riêng (hoặc biến môi trường hệ
thống) định nghĩa server_id, zone, và danh sách peer server khác — KHÔNG
hard-code trong code để cùng 1 bản build có thể deploy cho cả 3 server
(Server-M1, Server-M2, Server-CR) chỉ bằng cách đổi .env.

Ví dụ file .env trên máy chạy Server-M1:

    IZIIAPP_SERVER_ID=server-m1
    IZIIAPP_ZONE=M1
    IZIIAPP_PEERS=http://192.168.1.11:8080,http://192.168.1.12:8080
    IZIIAPP_SYNC_INTERVAL_SECONDS=45
"""
import os
import sys
import io
from dataclasses import dataclass, field

# Ensure UTF-8 output encoding on Windows consoles
if sys.platform.startswith('win'):
    try:
        if hasattr(sys.stdout, 'reconfigure'):
            sys.stdout.reconfigure(encoding='utf-8', errors='replace')
            sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass


def _load_env_file():
    """
    Lightweight .env file parser so server loads environment variables automatically
    without requiring external libraries or manual OS export.
    """
    candidate_paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"),
        os.path.join(os.getcwd(), ".env"),
    ]
    if getattr(sys, 'frozen', False):
        candidate_paths.insert(0, os.path.join(os.path.dirname(sys.executable), ".env"))
    for env_path in candidate_paths:
        if os.path.exists(env_path):
            try:
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#") or "=" not in line:
                            continue
                        k, v = line.split("=", 1)
                        k = k.strip()
                        v = v.strip().strip("'").strip('"')
                        if k and k not in os.environ:
                            os.environ[k] = v
                break
            except Exception as e:
                print(f"⚠️  [CONFIG] Could not parse .env file at {env_path}: {e}")


# Load .env file automatically on module import
_load_env_file()


def _parse_peers(raw: str) -> list[str]:
    return [p.strip().rstrip("/") for p in raw.split(",") if p.strip()]


@dataclass
class ServerConfig:
    server_id: str
    zone: str
    peers: list[str] = field(default_factory=list)
    sync_interval_seconds: int = 45
    server_secret: str = ""
    ws_secret: str = ""


def load_server_config() -> ServerConfig:
    server_id = os.environ.get("IZIIAPP_SERVER_ID", "server-standalone")
    zone = os.environ.get("IZIIAPP_ZONE", "default")
    peers_raw = os.environ.get("IZIIAPP_PEERS", "")
    interval = int(os.environ.get("IZIIAPP_SYNC_INTERVAL_SECONDS", "45"))
    secret = os.environ.get("IZIIAPP_SERVER_SECRET", "")
    ws_secret = os.environ.get("IZIIAPP_WS_SECRET", "")
    if not ws_secret and not secret:
        try:
            print(
                "⛔ [CONFIG] Chưa set IZIIAPP_WS_SECRET lẫn IZIIAPP_SERVER_SECRET — "
                "WebSocket /chat sẽ TỪ CHỐI mọi kết nối. Set 1 trong 2 biến này "
                "rồi khởi động lại server."
            )
        except Exception:
            pass
    if not secret:
        try:
            print(
                "⚠️  [CONFIG] IZIIAPP_SERVER_SECRET chưa được set — "
                "/peer-sync/* endpoints đang hoạt động ở chế độ mở (không yêu cầu X-iZii-Server-Token)."
            )
        except Exception:
            pass

    if server_id == "server-standalone":
        print(
            "⚠️  [CONFIG] IZIIAPP_SERVER_ID chưa được set — server đang chạy ở "
            "chế độ standalone (không tham gia multi-server sync). "
            "Set biến môi trường IZIIAPP_SERVER_ID / IZIIAPP_ZONE / IZIIAPP_PEERS "
            "nếu muốn tham gia mesh nhiều server."
        )

    return ServerConfig(
        server_id=server_id,
        zone=zone,
        peers=_parse_peers(peers_raw),
        sync_interval_seconds=interval,
        server_secret=secret,
        ws_secret=ws_secret,
    )


CONFIG = load_server_config()
