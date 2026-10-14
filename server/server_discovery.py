# server/server_discovery.py
"""
mDNS Discovery Module — dùng chung cho 2 mục đích:

1. ADVERTISE: server này "quảng bá" chính mình trong mạng LAN qua mDNS
   (Bonjour/Zeroconf), để:
   - Thiết bị local (iPhone/iPad/Samsung) tự tìm thấy server mà không cần
     nhập IP thủ công (app dùng NSD/Bonjour phía Flutter để quét, xem ghi
     chú cuối file).
   - Các server khác trong mesh cũng tự phát hiện được nhau, bổ sung dần
     vào danh sách peer thay vì chỉ dựa vào IZIIAPP_PEERS tĩnh khai báo
     trong .env — hữu ích khi thêm server mới (Phase mở rộng, xem mục 7
     trong tài liệu kiến trúc multi-server).

2. DISCOVER: server này lắng nghe mDNS để phát hiện các iZiiApp server
   khác đang chạy trong cùng mạng, tự động thêm vào bảng `known_servers`
   và vào danh sách peer runtime (không cần khởi động lại server để nhận
   peer mới).

Service type dùng chung: "_iziiapp._tcp.local."
TXT record mang theo: server_id, zone, version.

Yêu cầu cài đặt:
    pip install zeroconf --break-system-packages
"""
from __future__ import annotations

import asyncio
import logging
import socket
from datetime import datetime, timezone
from typing import Callable, Optional

from zeroconf import IPVersion, ServiceStateChange, Zeroconf
from zeroconf.asyncio import AsyncServiceBrowser, AsyncServiceInfo, AsyncZeroconf

from server_config import CONFIG

logger = logging.getLogger("server_discovery")

SERVICE_TYPE = "_iziiapp._tcp.local."
SERVER_APP_VERSION = "2.0.0"  # nên đồng bộ với FastAPI app version trong app.py


def _get_local_ip() -> str:
    """Lấy IP LAN thật của máy (không phải 127.0.0.1) để advertise đúng địa chỉ."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Không thực sự gửi gói tin, chỉ dùng để OS chọn interface phù hợp
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


class ServerDiscovery:
    """
    Quản lý vòng đời mDNS cho 1 server: vừa advertise chính mình, vừa lắng
    nghe để phát hiện server khác. Dùng 1 instance duy nhất, khởi tạo trong
    lifespan() của app.py, đóng lại khi shutdown.
    """

    def __init__(self, port: int, on_peer_discovered: Optional[Callable[[dict], None]] = None):
        self.port = port
        self.on_peer_discovered = on_peer_discovered
        self._aiozc: Optional[AsyncZeroconf] = None
        self._browser: Optional[AsyncServiceBrowser] = None
        self._service_info: Optional[AsyncServiceInfo] = None
        # Lưu các peer đã phát hiện qua mDNS, tách biệt với peer tĩnh khai
        # báo qua IZIIAPP_PEERS, để dễ debug nguồn gốc từng peer.
        self.discovered_peers: dict[str, dict] = {}  # server_id -> {zone, host, port, discovered_at}

    # ---------------------------------------------------------------- advertise
    async def start_advertising(self) -> None:
        self._aiozc = AsyncZeroconf(ip_version=IPVersion.V4Only)
        local_ip = _get_local_ip()

        properties = {
            b"server_id": CONFIG.server_id.encode("utf-8"),
            b"zone": CONFIG.zone.encode("utf-8"),
            b"version": SERVER_APP_VERSION.encode("utf-8"),
        }

        self._service_info = AsyncServiceInfo(
            SERVICE_TYPE,
            name=f"{CONFIG.server_id}.{SERVICE_TYPE}",
            addresses=[socket.inet_aton(local_ip)],
            port=self.port,
            properties=properties,
            server=f"{CONFIG.server_id}.local.",
        )

        await self._aiozc.async_register_service(self._service_info)
        logger.info(
            "📡 [mDNS] Advertising server_id=%s zone=%s tại %s:%d",
            CONFIG.server_id, CONFIG.zone, local_ip, self.port,
        )

    # ----------------------------------------------------------------- discover
    async def start_discovery(self) -> None:
        if self._aiozc is None:
            self._aiozc = AsyncZeroconf(ip_version=IPVersion.V4Only)

        def on_service_state_change(
            zeroconf: Zeroconf, service_type: str, name: str, state_change: ServiceStateChange
        ) -> None:
            if state_change is ServiceStateChange.Added:
                asyncio.ensure_future(self._resolve_and_register(name))

        self._browser = AsyncServiceBrowser(
            self._aiozc.zeroconf, SERVICE_TYPE, handlers=[on_service_state_change]
        )
        logger.info("👂 [mDNS] Bắt đầu lắng nghe server khác trong mạng (service type=%s)", SERVICE_TYPE)

    async def _resolve_and_register(self, name: str) -> None:
        info = AsyncServiceInfo(SERVICE_TYPE, name)
        resolved = await info.async_request(self._aiozc.zeroconf, timeout=3000)
        if not resolved:
            logger.warning("⚠️  [mDNS] Không resolve được service %s", name)
            return

        props = info.properties or {}
        peer_server_id = (props.get(b"server_id") or b"").decode("utf-8")
        peer_zone = (props.get(b"zone") or b"").decode("utf-8")

        if not peer_server_id or peer_server_id == CONFIG.server_id:
            return  # bỏ qua chính mình hoặc service không hợp lệ

        addresses = info.parsed_scoped_addresses()
        if not addresses:
            return
        host = addresses[0]
        port = info.port

        is_new = peer_server_id not in self.discovered_peers
        self.discovered_peers[peer_server_id] = {
            "server_id": peer_server_id,
            "zone": peer_zone,
            "host": host,
            "port": port,
            "discovered_at": datetime.now(timezone.utc).isoformat(),
        }

        if is_new:
            logger.info(
                "✅ [mDNS] Phát hiện server mới: %s (zone=%s) tại %s:%d",
                peer_server_id, peer_zone, host, port,
            )
            if self.on_peer_discovered:
                self.on_peer_discovered(self.discovered_peers[peer_server_id])

    def get_discovered_peer_urls(self) -> list[str]:
        """Trả về danh sách URL peer đã phát hiện qua mDNS, dùng để hợp nhất
        với CONFIG.peers (khai báo tĩnh) trong vòng lặp polling sync.

        Scheme bám theo cấu hình TLS của CHÍNH SERVER NÀY: trong một mesh thì
        mọi server phải cùng bật hoặc cùng tắt TLS. Nếu ghép http với https,
        peer sẽ gặp lỗi bắt tay và im lặng không đồng bộ.
        """
        from security_tls import tls_enabled
        scheme = "https" if tls_enabled() else "http"
        return [f"{scheme}://{p['host']}:{p['port']}" for p in self.discovered_peers.values()]

    # -------------------------------------------------------------------- close
    async def close(self) -> None:
        if self._browser:
            await self._browser.async_cancel()
        if self._service_info and self._aiozc:
            await self._aiozc.async_unregister_service(self._service_info)
        if self._aiozc:
            await self._aiozc.async_close()
        logger.info("🛑 [mDNS] Đã dừng advertise + discovery cho %s", CONFIG.server_id)


# ------------------------------------------------------------------------------
# Ghi chú tích hợp phía thiết bị local (iPhone/iPad/Samsung — Flutter):
#
# Module này chỉ lo phần SERVER. Phía app Flutter cần quét cùng service type
# ("_iziiapp._tcp.local.") bằng:
#   - iOS: NSNetServiceBrowser (qua package `bonsoir` hoặc `multicast_dns`)
#   - Android: NsdManager (cũng qua `bonsoir` hoặc `multicast_dns`)
#
# Gói Flutter khuyến nghị: `multicast_dns` (thuần Dart, không cần platform
# channel riêng) hoặc `bonsoir` (wrap NSD/Bonjour native, ổn định hơn trên
# một số thiết bị Android cũ).
#
# Luồng phía app:
#   1. Quét mDNS service type "_iziiapp._tcp.local." trong X giây
#   2. Với mỗi service tìm được, đọc TXT record (server_id, zone, version)
#   3. Hiển thị danh sách cho nhân viên chọn (xem mockup "Chọn server để
#      kết nối" đã thiết kế trong tài liệu kiến trúc multi-server)
#   4. Lưu server đã chọn (IP:port) vào local storage làm mặc định
#   5. Nếu server mặc định không phản hồi /peer-sync/health hoặc endpoint
#      health tương đương cho device (nên thêm /health riêng, KHÔNG dùng
#      /peer-sync/health vì đó dành cho server-to-server) → quét lại
# ------------------------------------------------------------------------------
