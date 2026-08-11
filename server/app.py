import sys
import io
import os

# Stable data directory resolution
from database import DB_PATH, get_stable_data_dir
from datetime import datetime, timezone

LOG_DIR = os.path.join(get_stable_data_dir(), "logs")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE_PATH = os.path.join(LOG_DIR, "server.log")

# Simple log rotation on startup (10MB limit)
if os.path.exists(LOG_FILE_PATH):
    try:
        if os.path.getsize(LOG_FILE_PATH) > 10 * 1024 * 1024:
            old_log = LOG_FILE_PATH + ".old"
            if os.path.exists(old_log):
                os.remove(old_log)
            os.rename(LOG_FILE_PATH, old_log)
    except Exception:
        pass

class DualLogger:
    def __init__(self, original_stream, log_file):
        self.original_stream = original_stream
        self.log_file = log_file

    @property
    def buffer(self):
        return getattr(self.original_stream, 'buffer', None)

    def write(self, message):
        try:
            self.original_stream.write(message)
        except Exception:
            pass
        if self.log_file:
            try:
                self.log_file.write(message)
            except Exception:
                pass

    def flush(self):
        try:
            self.original_stream.flush()
        except Exception:
            pass
        if self.log_file:
            try:
                self.log_file.flush()
            except Exception:
                pass

    def isatty(self):
        try:
            return self.original_stream.isatty()
        except Exception:
            return False

    @property
    def encoding(self):
        try:
            return self.original_stream.encoding
        except Exception:
            return 'utf-8'

    @property
    def errors(self):
        try:
            return self.original_stream.errors
        except Exception:
            return 'strict'

# Force UTF-8 encoding for standard output and error on Windows to prevent UnicodeEncodeError
if sys.platform.startswith('win'):
    if hasattr(sys.stdout, 'buffer') and not isinstance(sys.stdout, DualLogger):
        try:
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        except Exception:
            pass
    if hasattr(sys.stderr, 'buffer') and not isinstance(sys.stderr, DualLogger):
        try:
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
        except Exception:
            pass

try:
    log_file = open(LOG_FILE_PATH, "a", encoding="utf-8", errors="replace")
except Exception as e:
    print(f"⚠️ [LOG] Error opening log file: {e}")
    log_file = None

if log_file:
    if not isinstance(sys.stdout, DualLogger):
        sys.stdout = DualLogger(sys.stdout, log_file)
    if not isinstance(sys.stderr, DualLogger):
        sys.stderr = DualLogger(sys.stderr, log_file)
    print(f"📖 [LOG] Server log file initialized at: {LOG_FILE_PATH}")

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from typing import List, Optional
import hmac
import json
import os
from contextlib import asynccontextmanager

import asyncio
import httpx

from db_init import init_db, prune_old_mutations, prune_message_queue
from server_config import CONFIG
from server_discovery import ServerDiscovery
from dependencies import open_connection, make_sync_repo
from security_tls import httpx_client_kwargs, uvicorn_ssl_kwargs, describe as describe_tls
from routers import (
    sync, devices, messages, notifications, attachments,
    peer_sync, call, webhooks, admin, enrollment, sessions,
)
from security_auth import describe_scopes
from event_engine import iZiiEventEngine, close_http_client


# ══════════════════════════════════════════════════════════════════════════════
#  Multi-Server Peer Sync — Background Polling Task
# ══════════════════════════════════════════════════════════════════════════════

_peer_last_sync: dict[str, int] = {}  # peer_url -> seq cuối cùng đã đồng bộ từ peer đó
discovery: ServerDiscovery | None = None  # gán trong lifespan(), dùng bởi _peer_sync_loop


# Số trang tối đa kéo trong một chu kỳ, chặn trường hợp peer có log khổng lồ
# làm vòng lặp chạy mãi không nhả. Phần còn lại sẽ được kéo ở chu kỳ sau.
_MAX_PAGES_PER_CYCLE = 20


async def _sync_with_one_peer(client: httpx.AsyncClient, peer_url: str) -> None:
    """
    Kéo delta từ MỘT peer, lặp qua các trang cho tới khi hết hoặc chạm trần.

    Con trỏ dùng `after_seq` — số thứ tự đơn điệu trong log của PEER. Trước đây
    dùng `server_time` (chuỗi thời gian của peer) làm mốc; chỉ cần đồng hồ hai
    máy lệch vài giây là mutation bị bỏ sót vĩnh viễn mà không có lỗi nào.
    """
    # Con trỏ seq: ưu tiên RAM, không có thì đọc từ known_servers.
    after_seq = _peer_last_sync.get(peer_url)
    if after_seq is None:
        with open_connection() as conn:
            after_seq = make_sync_repo(conn).get_peer_last_seq(peer_url)

    headers = {}
    if CONFIG.server_secret:
        headers["X-iZii-Server-Token"] = CONFIG.server_secret

    total_applied = 0
    tables_touched: set[str] = set()
    remote_server_id = peer_url
    remote_zone = None

    for _page in range(_MAX_PAGES_PER_CYCLE):
        params: dict = {"requester_server_id": CONFIG.server_id}
        if after_seq is not None:
            params["after_seq"] = after_seq

        try:
            resp = await client.get(
                f"{peer_url}/peer-sync/pull", params=params, headers=headers, timeout=10.0
            )
            resp.raise_for_status()
            body = resp.json()
        except httpx.HTTPError as e:
            print(f"⚠️  [PEER-SYNC] Không kết nối được peer {peer_url}: {e} (có thể đang offline)")
            return   # KHÔNG cập nhật con trỏ -> chu kỳ sau kéo bù

        remote_server_id = body.get("server_id", peer_url)
        remote_zone = body.get("zone")
        updates = body.get("updates", [])
        next_cursor = body.get("next_cursor")
        has_more = bool(body.get("has_more"))

        if updates:
            now_utc = datetime.now(timezone.utc).isoformat()
            with open_connection() as conn:
                count = make_sync_repo(conn).push_mutations(updates, now_utc)
            total_applied += count
            tables_touched.update(m["table"] for m in updates)

        # Chỉ tiến con trỏ khi trang đã được ghi thành công.
        if next_cursor is not None:
            after_seq = next_cursor
            _peer_last_sync[peer_url] = after_seq
            with open_connection() as conn:
                make_sync_repo(conn).update_peer_sync_status(
                    peer_id=remote_server_id,
                    last_synced_seq=after_seq,
                    zone=remote_zone,
                    peer_url=peer_url,
                )

        if not has_more:
            break
    else:
        print(
            f"ℹ️  [PEER-SYNC] {peer_url} còn dữ liệu sau {_MAX_PAGES_PER_CYCLE} trang, "
            f"sẽ kéo tiếp ở chu kỳ sau."
        )

    if total_applied:
        print(f"🔁 [PEER-SYNC] Đã áp dụng {total_applied} mutations từ {peer_url}")
        # Relay tiếp cho các device đang connect trực tiếp WebSocket vào server này
        event_data = {
            "event": "sync_trigger",
            "data": {
                "tables": sorted(tables_touched),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
        }
        ws_manager = getattr(app.state, "ws_manager", None)
        if ws_manager:
            await ws_manager.broadcast(json.dumps(event_data), exclude=None)


async def _peer_sync_loop() -> None:
    print(
        f"🔁 [PEER-SYNC] Bắt đầu vòng lặp đồng bộ (mỗi {CONFIG.sync_interval_seconds}s). "
        f"Peer tĩnh (.env): {CONFIG.peers or '(không có)'}. "
        f"Peer qua mDNS sẽ được cộng dồn động khi phát hiện."
    )
    # Client mang theo chứng chỉ của server này (nếu bật mTLS) và CA nội bộ để
    # xác thực ngược lại peer. Không có TLS thì kwargs rỗng, hành vi như cũ.
    async with httpx.AsyncClient(**httpx_client_kwargs()) as client:
        while True:
            # Hợp nhất peer khai báo tĩnh (IZIIAPP_PEERS) với peer phát hiện
            # động qua mDNS — cho phép thêm server mới vào mạng mà không cần
            # sửa .env / khởi động lại các server đang chạy.
            static_peers = set(CONFIG.peers)
            dynamic_peers = set(discovery.get_discovered_peer_urls()) if discovery else set()
            all_peers = static_peers | dynamic_peers

            if not all_peers:
                await asyncio.sleep(CONFIG.sync_interval_seconds)
                continue

            await asyncio.gather(
                *(_sync_with_one_peer(client, peer) for peer in all_peers),
                return_exceptions=True,
            )
            await asyncio.sleep(CONFIG.sync_interval_seconds)


# ══════════════════════════════════════════════════════════════════════════════
#  Application Lifespan (replaces deprecated @app.on_event)
# ══════════════════════════════════════════════════════════════════════════════

@asynccontextmanager
async def lifespan(app: FastAPI):
    global discovery
    # Startup
    init_db()
    prune_old_mutations(days=30)
    # Dọn hàng đợi tin nhắn: xoá tin đã giao cũ, dead-letter tin kẹt quá lâu.
    # Chỉ chạy trên SQLite — bản PostgreSQL dùng job riêng.
    if CONFIG.db_backend != "postgres":
        prune_message_queue()
    print(f"✅ Database auto-initialized successfully at: {os.path.abspath(DB_PATH)}")
    print(f"✅ Production PRAGMAs applied: WAL, NORMAL sync, busy_timeout=5000, cache=64MB, mmap=256MB")
    print(f"🌐 Server identity: server_id={CONFIG.server_id} zone={CONFIG.zone}")
    print(f"🗄️  Database backend: {CONFIG.db_backend}")
    print(describe_tls())
    print(describe_scopes())

    discovery = ServerDiscovery(port=8080)
    try:
        await discovery.start_advertising()
        await discovery.start_discovery()
    except Exception as e:
        # mDNS không phải chức năng cốt lõi — nếu môi trường mạng chặn
        # multicast (vd 1 số cloud VM), server vẫn phải chạy bình thường,
        # chỉ mất tính năng auto-discovery, fallback về peer tĩnh (.env).
        print(f"⚠️  [mDNS] Không khởi động được advertise/discovery: {e}. "
              f"Vẫn dùng peer tĩnh khai báo trong IZIIAPP_PEERS.")

    peer_sync_task = asyncio.create_task(_peer_sync_loop())

    yield
    # Shutdown
    peer_sync_task.cancel()
    if discovery:
        await discovery.close()
    # Đóng httpx.AsyncClient dùng chung của event engine (webhook dispatch)
    await close_http_client()
    # Trả connection pool của Postgres về hệ thống (không làm gì nếu dùng SQLite)
    if CONFIG.db_backend == "postgres":
        try:
            from db_postgres import close_pool
            close_pool()
        except Exception as e:
            print(f"⚠️  [PG] Lỗi khi đóng pool: {e}")
    print("🛑 Server shutting down...")


# ══════════════════════════════════════════════════════════════════════════════
#  FastAPI Application
# ══════════════════════════════════════════════════════════════════════════════

app = FastAPI(
    title="iZiiApp Sync & E2EE Server (FastAPI Standalone)",
    version="2.0.0",
    description="Modular server with Repository Pattern (Architecture Plan v2)",
    lifespan=lifespan
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost(:\d+)?|127\.0\.0\.1(:\d+)?|10\.\d+\.\d+\.\d+(:\d+)?|172\.(1[6-9]|2[0-9]|3[01])\.\d+\.\d+(:\d+)?|192\.168\.\d+\.\d+(:\d+)?)$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

import re
from fastapi import Request

@app.middleware("http")
async def normalize_double_slashes(request: Request, call_next):
    if "//" in request.scope.get("path", ""):
        request.scope["path"] = re.sub(r"/+", "/", request.scope["path"])
    return await call_next(request)

# ── Register Routers (Architecture Plan Section 6 — Modular Endpoints) ──────
app.include_router(sync.router)
app.include_router(devices.router)
app.include_router(messages.router)
app.include_router(notifications.router)
app.include_router(attachments.router)
app.include_router(peer_sync.router)  # Server-to-Server delta sync (multi-server)
app.include_router(call.router)
app.include_router(webhooks.router)
app.include_router(webhooks.event_router)
app.include_router(admin.router)       # /admin/* — cần X-iZii-Admin-Token
app.include_router(enrollment.router)  # /devices/enroll — công khai, gác bằng vé mời
app.include_router(sessions.router)    # /sessions/* — điểm danh đầu ca (G1)

# Cho admin router chạm tới con trỏ sync đang nằm trong RAM, để lệnh reset xoá
# được cả bộ nhớ chứ không chỉ bảng known_servers dưới đĩa.
app.state.peer_last_sync = _peer_last_sync

# Mount static uploads directory for attachments serving
uploads_dir = os.path.join(get_stable_data_dir(), "uploads")
os.makedirs(uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")


@app.get("/health")
async def device_health_check():
    """
    Endpoint cho THIẾT BỊ LOCAL (iPhone/iPad/Samsung) dùng để kiểm tra server
    đang chọn còn sống hay không — khác với /peer-sync/health vốn chỉ dành
    cho server-to-server và trả thêm thông tin nội bộ (sync status).
    """
    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "status": "ok",
        "server_time": datetime.now(timezone.utc).isoformat(),
    }


# ══════════════════════════════════════════════════════════════════════════════
#  WebSockets (RFC 6455 over FastAPI) — Kept in app.py for ConnectionManager
# ══════════════════════════════════════════════════════════════════════════════

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"\n🔌 [WS] Client connected. Active clients: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        print(f"🔌 [WS] Client disconnected. Active clients: {len(self.active_connections)}")

    async def broadcast(self, message: str, exclude: WebSocket):
        for connection in self.active_connections:
            if connection is not exclude:
                try:
                    await connection.send_text(message)
                except Exception:
                    pass

ws_manager = ConnectionManager()
app.state.ws_manager = ws_manager


def _write_latency_sync(event_type: str, sent_at_str: str):
    try:
        if not sent_at_str:
            return
        client_dt = datetime.fromisoformat(sent_at_str.replace('Z', '+00:00'))
        server_dt = datetime.now(client_dt.tzinfo)
        diff = server_dt - client_dt
        latency_ms = diff.total_seconds() * 1000
        
        log_path = os.path.join(get_stable_data_dir(), "logs", "latency.log")
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now(timezone.utc).isoformat()}] EVENT: {event_type} | Sent: {sent_at_str} | Recv: {datetime.now(timezone.utc).isoformat()} | Latency: {latency_ms:.2f} ms\n")
    except Exception as e:
        print(f"Error logging latency: {str(e)}")


async def log_latency(event_type: str, sent_at_str: str):
    """Log latency measurements asynchronously without blocking event loop."""
    await asyncio.to_thread(_write_latency_sync, event_type, sent_at_str)


# Giữ tham chiếu tới task nền để GC không thu hồi giữa chừng.
_ws_background_tasks: set = set()


# ── WebSocket Authentication ────────────────────────────────────────────────
# Token bắt buộc cho MỌI kết nối /chat. Ưu tiên IZIIAPP_WS_SECRET; nếu không
# set thì dùng chung IZIIAPP_SERVER_SECRET để đỡ phải quản lý 2 secret.
# Client gửi token theo 1 trong 2 cách:
#   - query param:  ws://host:8080/chat?token=<secret>
#   - header:       X-iZii-WS-Token: <secret>
# (query param tiện cho Flutter/web vì WebSocket API của trình duyệt không
#  cho phép set header tuỳ ý khi handshake).
WS_SECRET = CONFIG.ws_secret or CONFIG.server_secret


def _ws_token_is_valid(token: Optional[str]) -> bool:
    if not token or not WS_SECRET:
        return False
    return hmac.compare_digest(token, WS_SECRET)


@app.websocket("/chat")
async def websocket_endpoint(websocket: WebSocket, token: Optional[str] = Query(None)):
    # Không cấu hình secret => từ chối tất cả, thay vì âm thầm mở toang.
    if not WS_SECRET:
        print(
            "⛔ [WS] Từ chối kết nối: chưa cấu hình IZIIAPP_WS_SECRET "
            "(hoặc IZIIAPP_SERVER_SECRET). Set biến môi trường rồi khởi động lại."
        )
        await websocket.close(code=1008, reason="Server chưa cấu hình WS secret")
        return

    supplied = token or websocket.headers.get("X-iZii-WS-Token")
    if not _ws_token_is_valid(supplied):
        print(f"⛔ [WS] Từ chối kết nối từ {websocket.client}: token thiếu hoặc sai.")
        await websocket.close(code=1008, reason="Invalid or missing token")
        return

    await ws_manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            print(f"💬 [WS] Broadcast message: {data[:120]}...")
            
            # Log latency measurement asynchronously for events containing 'sent_at' or 'timestamp'
            try:
                payload = json.loads(data)
                event = payload.get("event")
                msg_data = payload.get("data", {})
                if isinstance(msg_data, dict):
                    sent_at = msg_data.get("sent_at") or msg_data.get("timestamp")
                    if sent_at:
                        _t = asyncio.create_task(log_latency(f"WS_{event}", sent_at))
                        _ws_background_tasks.add(_t)
                        _t.add_done_callback(_ws_background_tasks.discard)
            except Exception:
                pass
                
            await ws_manager.broadcast(data, exclude=websocket)
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
    except Exception as e:
        print(f"⚠️ [WS] Connection error: {str(e)}")
        ws_manager.disconnect(websocket)


# ══════════════════════════════════════════════════════════════════════════════
#  Standalone Launcher Block using Uvicorn Runner
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    import uvicorn
    import sys
    import threading
    import os

    def monitor_parent_stdin():
        try:
            sys.stdin.read()
        except Exception:
            pass
        os._exit(0)

    # Start the daemon thread to monitor parent lifecycle
    if sys.stdin is not None:
        monitor_thread = threading.Thread(target=monitor_parent_stdin, daemon=True)
        monitor_thread.start()
    
    # Check if running as a compiled PyInstaller bundle
    is_frozen = getattr(sys, 'frozen', False)
    
    # Tham số TLS/mTLS — dict rỗng khi chưa cấu hình chứng chỉ, khi đó server
    # chạy HTTP thuần y như trước.
    ssl_kwargs = uvicorn_ssl_kwargs()

    if is_frozen:
        print("\n🚀 Starting iZiiApp Standalone Server v2.0 in Bundled Mode...")
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8080,
            **ssl_kwargs,
        )
    else:
        print("\n🚀 Starting iZiiApp Standalone Server v2.0 in Development Mode...")
        uvicorn.run(
            "app:app",
            host="0.0.0.0",
            port=8080,
            reload=True,
            reload_dirs=["./"],  # Watch server directory
            reload_excludes=["build", ".dart_tool", ".git", "data", "__pycache__", "certs"],
            **ssl_kwargs,
        )
