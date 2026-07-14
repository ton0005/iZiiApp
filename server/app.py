import sys
import io
import os

# Stable data directory resolution
def get_stable_data_dir():
    if getattr(sys, 'frozen', False):
        return os.path.join(os.path.dirname(sys.executable), "data")
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

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

# Force UTF-8 encoding for standard output and error on Windows to prevent UnicodeEncodeError
if sys.platform.startswith('win'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    log_file = open(LOG_FILE_PATH, "a", encoding="utf-8", errors="replace")
except Exception as e:
    print(f"⚠️ [LOG] Error opening log file: {e}")
    log_file = None

class DualLogger:
    def __init__(self, original_stream, log_file):
        self.original_stream = original_stream
        self.log_file = log_file

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

if log_file:
    sys.stdout = DualLogger(sys.stdout, log_file)
    sys.stderr = DualLogger(sys.stderr, log_file)
    print(f"📖 [LOG] Server log file initialized at: {LOG_FILE_PATH}")

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import json
import os
from datetime import datetime
from contextlib import asynccontextmanager

from database import get_db_connection, DB_PATH
from routers import sync, devices, messages, notifications


# ══════════════════════════════════════════════════════════════════════════════
#  Database Schema Initialization
# ══════════════════════════════════════════════════════════════════════════════

def init_db():
    """Initialize the SQLite database schema using production-grade connection."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Sync Mutations Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS sync_mutations (
        id TEXT PRIMARY KEY,
        client_id TEXT,
        "table" TEXT,
        operation TEXT,
        data TEXT,
        server_received_at TEXT
    )""")
    
    # 2. Registered Devices
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS devices (
        device_id TEXT PRIMARY KEY,
        user_id TEXT,
        public_key TEXT,
        signing_public_key TEXT,
        device_name TEXT,
        platform TEXT,
        push_token TEXT,
        fingerprint TEXT,
        registered_at TEXT,
        last_seen_at TEXT
    )""")
    
    # 3. Encrypted Message Queue (E2EE Envelopes)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS message_queue (
        id TEXT PRIMARY KEY,
        conversation_id TEXT,
        sender_device_id TEXT,
        recipient_device_id TEXT,
        ciphertext TEXT,
        nonce TEXT,
        signature TEXT,
        sent_at TEXT,
        delivered_at TEXT
    )""")
    
    # 4. In-App Notifications
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT,
        body TEXT,
        event_type TEXT,
        resource_id TEXT,
        read_at TEXT,
        created_at TEXT
    )""")
    
    # 5. User Notification Settings
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notification_settings (
        user_id TEXT,
        event_type TEXT,
        enable_push INTEGER,
        enable_in_app INTEGER,
        enable_email INTEGER,
        digest_frequency TEXT,
        PRIMARY KEY (user_id, event_type)
    )""")
    
    conn.commit()
    conn.close()


# ══════════════════════════════════════════════════════════════════════════════
#  Application Lifespan (replaces deprecated @app.on_event)
# ══════════════════════════════════════════════════════════════════════════════

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db()
    print(f"✅ Database auto-initialized successfully at: {os.path.abspath(DB_PATH)}")
    print(f"✅ Production PRAGMAs applied: WAL, NORMAL sync, busy_timeout=5000, cache=64MB, mmap=256MB")
    yield
    # Shutdown
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
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Register Routers (Architecture Plan Section 6 — Modular Endpoints) ──────
app.include_router(sync.router)
app.include_router(devices.router)
app.include_router(messages.router)
app.include_router(notifications.router)


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


def log_latency(event_type: str, sent_at_str: str):
    """Log latency measurements for WebSocket events."""
    try:
        if not sent_at_str:
            return
        # Parse timezone-aware ISO string
        client_dt = datetime.fromisoformat(sent_at_str.replace('Z', '+00:00'))
        server_dt = datetime.now(client_dt.tzinfo)
        diff = server_dt - client_dt
        latency_ms = diff.total_seconds() * 1000
        
        # Use relative path instead of hardcoded absolute path
        log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "testlog.txt")
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now().isoformat()}] EVENT: {event_type} | Sent: {sent_at_str} | Recv: {datetime.now().isoformat()} | Latency: {latency_ms:.2f} ms\n")
    except Exception as e:
        print(f"Error logging latency: {str(e)}")


@app.websocket("/chat")
async def websocket_endpoint(websocket: WebSocket):
    await ws_manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            print(f"💬 [WS] Broadcast message: {data[:120]}...")
            
            # Log latency measurement for events containing 'sent_at' or 'timestamp'
            try:
                payload = json.loads(data)
                event = payload.get("event")
                msg_data = payload.get("data", {})
                if isinstance(msg_data, dict):
                    sent_at = msg_data.get("sent_at") or msg_data.get("timestamp")
                    if sent_at:
                        log_latency(f"WS_{event}", sent_at)
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
    
    if is_frozen:
        print("\n🚀 Starting iZiiApp Standalone Server v2.0 in Bundled Mode...")
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8080
        )
    else:
        print("\n🚀 Starting iZiiApp Standalone Server v2.0 in Development Mode...")
        uvicorn.run(
            "app:app",
            host="0.0.0.0",
            port=8080,
            reload=True,
            reload_dirs=["./"],  # Watch server directory
            reload_excludes=["build", ".dart_tool", ".git", "data", "__pycache__"]
        )
