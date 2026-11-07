from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import List


def _bool(v: str) -> bool:
    return v.strip().lower() in ("1", "true", "yes", "on")


@dataclass
class BridgeConfig:
    izii_url: str = "http://127.0.0.1:8080"
    token: str = ""
    listen_host: str = "0.0.0.0"
    # CHƯA XÁC NHẬN với HR1062 thật — lấy từ CPS/ADK. Giá trị mặc định theo ví dụ của ok-dmrlib.
    ports: List[int] = field(default_factory=lambda: [3002, 3003, 3005])
    spool_dir: str = "./spool"
    capture_file: str = ""
    # LONE_WORKER_REMINDER chỉ là nhắc nhở trước báo động (bấm phím là huỷ) — không phải hết giờ.
    # Mặc định chỉ ghi log; hết giờ thật sẽ tới dưới dạng EMERGENCY.
    forward_lone_worker_reminder: bool = False
    # Repeater phát lại trạng thái nhiều lần trong một cuộc gọi khẩn cấp: gộp trong N giây.
    repeater_suppress_s: float = 5.0
    # Radio ID suy từ 3 byte cuối của IP nguồn (subnet.b1.b2.b3) khi gói không mang sender.
    id_from_ip: bool = True
    retry_initial_s: float = 1.0
    retry_max_s: float = 30.0
    request_timeout_s: float = 10.0
    stats_every_s: float = 60.0
    # Chiều xuống (lệnh iZii → bộ đàm)
    commands_enabled: bool = True
    command_poll_s: float = 1.0
    command_timeout_s: float = 5.0  # chờ bộ đàm trả lời
    dispatcher_id: int = 9000  # Radio ID "người gửi" của tin nhắn từ iZii — đặt theo CPS

    @staticmethod
    def from_env() -> "BridgeConfig":
        c = BridgeConfig()
        c.izii_url = os.environ.get("IZII_URL", c.izii_url)
        c.token = os.environ.get("IZII_RADIO_TOKEN", c.token)
        c.listen_host = os.environ.get("BRIDGE_LISTEN_HOST", c.listen_host)
        if os.environ.get("BRIDGE_PORTS"):
            c.ports = [int(p) for p in os.environ["BRIDGE_PORTS"].split(",") if p.strip()]
        c.spool_dir = os.environ.get("BRIDGE_SPOOL_DIR", c.spool_dir)
        c.capture_file = os.environ.get("BRIDGE_CAPTURE_FILE", c.capture_file)
        c.forward_lone_worker_reminder = _bool(os.environ.get("BRIDGE_FORWARD_LONE_REMINDER", "0"))
        return c
