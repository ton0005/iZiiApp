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
from dataclasses import dataclass, field


def _parse_peers(raw: str) -> list[str]:
    return [p.strip().rstrip("/") for p in raw.split(",") if p.strip()]


@dataclass
class ServerConfig:
    server_id: str
    zone: str
    peers: list[str] = field(default_factory=list)
    sync_interval_seconds: int = 45


def load_server_config() -> ServerConfig:
    server_id = os.environ.get("IZIIAPP_SERVER_ID", "server-standalone")
    zone = os.environ.get("IZIIAPP_ZONE", "default")
    peers_raw = os.environ.get("IZIIAPP_PEERS", "")
    interval = int(os.environ.get("IZIIAPP_SYNC_INTERVAL_SECONDS", "45"))

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
    )


CONFIG = load_server_config()
