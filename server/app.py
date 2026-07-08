import sys
import io

# Force UTF-8 encoding for standard output and error on Windows to prevent UnicodeEncodeError
if sys.platform.startswith('win'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict
import sqlite3
import json
import uuid
import os
from datetime import datetime, timedelta

app = FastAPI(title="iZiiApp Sync & E2EE Server (FastAPI Standalone)", version="1.0.0")

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_PATH = os.path.join(".", "data", "iziiapp.db")

def init_db():
    # Ensure directory exists
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(DB_PATH)
    
    # Apply Production Optimizations
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA cache_size=-64000;")     # 64MB Cache
    conn.execute("PRAGMA temp_store=MEMORY;")
    conn.execute("PRAGMA mmap_size=268435456;")   # 256MB MMAP
    
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

@app.on_event("startup")
def startup_event():
    init_db()
    print(f"Database auto-initialized successfully at: {os.path.abspath(DB_PATH)}")

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# ── Pydantic Request Models ──────────────────────────────────────────────────

class MutationModel(BaseModel):
    id: str
    client_id: Optional[str] = None
    table: str
    operation: str
    data: dict

class PushPayload(BaseModel):
    mutations: List[MutationModel]

class DeviceRegister(BaseModel):
    device_id: str
    user_id: str
    public_key: Optional[str] = None
    public_key_base64: Optional[str] = None
    signing_public_key: Optional[str] = None
    signing_public_key_base64: Optional[str] = None
    device_name: str
    platform: str
    push_token: Optional[str] = None

class DeviceHeartbeat(BaseModel):
    device_id: str

class EncryptedPayload(BaseModel):
    ciphertext: str
    nonce: str
    signature: Optional[str] = None

class MessageSendPayload(BaseModel):
    conversation_id: str
    sender_device_id: str
    payloads: Dict[str, EncryptedPayload]

class MessageAckPayload(BaseModel):
    message_ids: List[str]

class NotificationReadPayload(BaseModel):
    user_id: str
    notification_ids: List[str]

class NotificationReadAllPayload(BaseModel):
    user_id: str

class NotificationSettingUpdatePayload(BaseModel):
    user_id: str
    event_type: str
    enable_push: Optional[bool] = True
    enable_in_app: Optional[bool] = True
    enable_email: Optional[bool] = True
    digest_frequency: Optional[str] = "instant"

# ══════════════════════════════════════════════════════════════════════════════
#  Track 1 — Sync Engine
# ══════════════════════════════════════════════════════════════════════════════

@app.post("/sync/push")
async def sync_push(payload: PushPayload):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    
    print(f"\n{'='*50}")
    print(f"📥 [PUSH] Received {len(payload.mutations)} changes at {now}")
    print(f"{'='*50}")
    
    try:
        for i, m in enumerate(payload.mutations):
            cursor.execute("""
                INSERT OR REPLACE INTO sync_mutations (id, client_id, "table", operation, data, server_received_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (m.id, m.client_id, m.table, m.operation, json.dumps(m.data), now))
            
            print(f"   [{i+1}] 🔹 Table: {m.table} | Operation: {m.operation}")
            for key, val in m.data.items():
                val_str = str(val)[:80]
                print(f"       - {key}: {val_str}")
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    return {"status": "success", "message": f"Processed {len(payload.mutations)} mutations"}

@app.get("/sync/pull")
async def sync_pull(since: Optional[str] = None):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    
    print(f"\n📤 [PULL] The device is downloading new updates...")
    if since:
        print(f"   🕐 Filtered since: {since}")
        
    try:
        if since:
            cursor.execute('SELECT * FROM sync_mutations WHERE server_received_at > ?', (since,))
        else:
            cursor.execute('SELECT * FROM sync_mutations')
        rows = cursor.fetchall()
        
        updates = []
        for r in rows:
            updates.append({
                "id": r["id"],
                "client_id": r["client_id"],
                "table": r["table"],
                "operation": r["operation"],
                "data": json.loads(r["data"]),
                "server_received_at": r["server_received_at"]
            })
            
        print(f"   📦 Sending {len(updates)} records")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    return {"updates": updates, "timestamp": now}

@app.get("/sync/status")
async def sync_status():
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute('SELECT "table", count(*) as cnt FROM sync_mutations GROUP BY "table"')
        rows = cursor.fetchall()
        tables = {r["table"]: r["cnt"] for r in rows}
        
        cursor.execute('SELECT count(*) as total FROM sync_mutations')
        total = cursor.fetchone()["total"]
    finally:
        conn.close()
        
    return {"total_records": total, "tables": tables}

# ══════════════════════════════════════════════════════════════════════════════
#  Track 3 — Device Identity
# ══════════════════════════════════════════════════════════════════════════════

@app.post("/api/v1/devices/register")
async def device_register(body: DeviceRegister):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    
    pub_key = body.public_key or body.public_key_base64
    sig_pub_key = body.signing_public_key or body.signing_public_key_base64
    
    if not pub_key:
        raise HTTPException(status_code=400, detail="Missing required field: public_key")
        
    # Generate human-readable fingerprint
    import hashlib
    fp_hash = hashlib.sha256(pub_key.encode()).hexdigest()
    fingerprint = fp_hash[:8].upper()
    
    try:
        cursor.execute("""
            INSERT OR REPLACE INTO devices (device_id, user_id, public_key, signing_public_key, device_name, platform, push_token, fingerprint, registered_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (body.device_id, body.user_id, pub_key, sig_pub_key, body.device_name, body.platform, body.push_token, fingerprint, now, now))
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    print(f"\n🔐 [DEVICE] Registered: {body.device_name} ({body.platform}) DID: {body.device_id[:16]}...")
    print(f"   👤 User: {body.user_id}")
    
    return {
        "status": "success", 
        "message": "Device registered successfully", 
        "device": {
            "device_id": body.device_id,
            "user_id": body.user_id,
            "public_key": pub_key,
            "signing_public_key": sig_pub_key,
            "device_name": body.device_name,
            "platform": body.platform,
            "push_token": body.push_token,
            "fingerprint": fingerprint,
            "registered_at": now,
            "last_seen_at": now
        }
    }

@app.post("/api/v1/devices/heartbeat")
async def device_heartbeat(body: DeviceHeartbeat):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    try:
        cursor.execute("UPDATE devices SET last_seen_at = ? WHERE device_id = ?", (now, body.device_id))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Device not found in registry")
        conn.commit()
    finally:
        conn.close()
        
    return {"status": "success", "message": "Heartbeat received"}

@app.get("/api/v1/devices/online")
async def devices_online(user_id: Optional[str] = None, exclude_device_id: Optional[str] = None):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now()
    online_threshold = timedelta(seconds=45)
    idle_threshold = timedelta(minutes=2)
    
    devices = []
    try:
        if user_id:
            cursor.execute("SELECT * FROM devices WHERE user_id = ?", (user_id,))
        else:
            cursor.execute("SELECT * FROM devices")
        rows = cursor.fetchall()
        
        for r in rows:
            if exclude_device_id and r["device_id"] == exclude_device_id:
                continue
                
            try:
                last_seen = datetime.fromisoformat(r["last_seen_at"])
            except Exception:
                continue
                
            elapsed = now - last_seen
            if elapsed <= online_threshold:
                status = "online"
            elif elapsed <= idle_threshold:
                status = "idle"
            else:
                continue # Offline devices are skipped
                
            devices.append({
                "device_id": r["device_id"],
                "user_id": r["user_id"],
                "device_name": r["device_name"],
                "platform": r["platform"],
                "public_key_base64": r["public_key"],
                "signing_public_key_base64": r["signing_public_key"],
                "registered_at": r["registered_at"],
                "fingerprint": r["fingerprint"],
                "last_seen_at": r["last_seen_at"],
                "status": status
            })
    finally:
        conn.close()
        
    print(f"\n📡 [ONLINE] Queried online devices → {len(devices)} active")
    return {"devices": devices}

@app.get("/api/v1/devices/{device_id}/key")
async def device_key_lookup(device_id: str):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,))
        r = cursor.fetchone()
        if not r:
            raise HTTPException(status_code=404, detail="Device not found")
            
        print(f"\n🔑 [KEY] Key lookup for device: {r['device_name']} DID: {device_id[:16]}...")
        
        return {
            "device_id": r["device_id"],
            "user_id": r["user_id"],
            "public_key_base64": r["public_key"],
            "signing_public_key_base64": r["signing_public_key"],
            "device_name": r["device_name"],
            "platform": r["platform"],
            "registered_at": r["registered_at"],
            "fingerprint": r["fingerprint"],
            "last_seen_at": r["last_seen_at"]
        }
    finally:
        conn.close()

# ══════════════════════════════════════════════════════════════════════════════
#  Track 3 — E2EE Messaging & Notifications
# ══════════════════════════════════════════════════════════════════════════════

@app.post("/api/v1/messages/send")
async def message_send(body: MessageSendPayload):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    created_ids = []
    
    try:
        for recipient_device_id, payload in body.payloads.items():
            msg_id = str(uuid.uuid4())
            cursor.execute("""
                INSERT INTO message_queue (id, conversation_id, sender_device_id, recipient_device_id, ciphertext, nonce, signature, sent_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (msg_id, body.conversation_id, body.sender_device_id, recipient_device_id, payload.ciphertext, payload.nonce, payload.signature, now))
            created_ids.append(msg_id)
            
            # Send Notification Dispatch Logic
            cursor.execute("SELECT user_id, device_name, push_token FROM devices WHERE device_id = ?", (recipient_device_id,))
            recipient = cursor.fetchone()
            if recipient:
                user_id = recipient["user_id"]
                
                # Check user settings
                cursor.execute("SELECT * FROM notification_settings WHERE user_id = ? AND event_type = 'new_message'", (user_id,))
                setting = cursor.fetchone()
                enable_push = setting["enable_push"] if setting else 1
                enable_in_app = setting["enable_in_app"] if setting else 1
                enable_email = setting["enable_email"] if setting else 1
                
                if enable_in_app:
                    notif_id = str(uuid.uuid4())
                    cursor.execute("""
                        INSERT INTO notifications (id, user_id, title, body, event_type, resource_id, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, (notif_id, user_id, "New Message", "You have received an encrypted private message.", "new_message", body.conversation_id, now))
                    print(f"   🔔 [IN-APP] Created notification for {user_id}")
                    
                if enable_push and recipient["push_token"]:
                    print(f"   📲 [PUSH] Dispatched Push Notification to token {recipient['push_token'][:16]}...")
                    
                if enable_email:
                    print(f"   ✉️ [EMAIL] Scheduled Delayed Email to {user_id} in 15 mins")
                    
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    return {"status": "success", "message": f"Sent to {len(body.payloads)} devices", "message_ids": created_ids}

@app.get("/api/v1/messages/pending")
async def messages_pending(device_id: str):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM message_queue WHERE recipient_device_id = ? AND delivered_at IS NULL", (device_id,))
        rows = cursor.fetchall()
        pending = []
        for r in rows:
            pending.append({
                "id": r["id"],
                "conversation_id": r["conversation_id"],
                "sender_device_id": r["sender_device_id"],
                "recipient_device_id": r["recipient_device_id"],
                "ciphertext": r["ciphertext"],
                "nonce": r["nonce"],
                "signature": r["signature"],
                "sent_at": r["sent_at"],
                "delivered_at": r["delivered_at"]
            })
            
        if pending:
            print(f"\n📬 [PENDING] {len(pending)} message(s) waiting for device {device_id[:16]}...")
    finally:
        conn.close()
        
    return {"messages": pending}

@app.post("/api/v1/messages/ack")
async def message_ack(body: MessageAckPayload):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    acked_count = 0
    try:
        for msg_id in body.message_ids:
            cursor.execute("UPDATE message_queue SET delivered_at = ? WHERE id = ? AND delivered_at IS NULL", (now, msg_id))
            acked_count += cursor.rowcount
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    print(f"\n✅ [ACK] Acknowledged {acked_count}/{len(body.message_ids)} message(s)")
    return {"status": "success", "message": f"Acknowledged {acked_count} message(s)", "acknowledged": acked_count}

# ── Notifications ────────────────────────────────────────────────────────────

@app.get("/api/v1/notifications")
async def notifications_get(user_id: str):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM notifications WHERE user_id = ?", (user_id,))
        rows = cursor.fetchall()
        notifs = []
        for r in rows:
            notifs.append({
                "id": r["id"],
                "user_id": r["user_id"],
                "title": r["title"],
                "body": r["body"],
                "event_type": r["event_type"],
                "resource_id": r["resource_id"],
                "read_at": r["read_at"],
                "created_at": r["created_at"]
            })
    finally:
        conn.close()
    return {"notifications": notifs}

@app.post("/api/v1/notifications/read")
async def notifications_read(body: NotificationReadPayload):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    updated_count = 0
    try:
        for notif_id in body.notification_ids:
            cursor.execute("UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ? AND read_at IS NULL", (now, notif_id, body.user_id))
            updated_count += cursor.rowcount
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    print(f"\n🔔 [NOTIF] Marked {updated_count} notification(s) as read for user {body.user_id}")
    return {"status": "success", "read_count": updated_count}

@app.post("/api/v1/notifications/read-all")
async def notifications_read_all(body: NotificationReadAllPayload):
    conn = get_db()
    cursor = conn.cursor()
    now = datetime.now().isoformat()
    try:
        cursor.execute("UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL", (now, body.user_id))
        updated_count = cursor.rowcount
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    print(f"\n🔔 [NOTIF] Marked all ({updated_count}) notifications as read for user {body.user_id}")
    return {"status": "success", "read_count": updated_count}

# ── Notification Settings ────────────────────────────────────────────────────

@app.get("/api/v1/notification-settings")
async def notification_settings_get(user_id: str):
    conn = get_db()
    cursor = conn.cursor()
    default_events = ['new_message', 'new_group_message', 'mention', 'added_to_group', 'missed_call']
    settings_list = []
    
    try:
        for event in default_events:
            cursor.execute("SELECT * FROM notification_settings WHERE user_id = ? AND event_type = ?", (user_id, event))
            r = cursor.fetchone()
            if r:
                settings_list.append({
                    "event_type": event,
                    "enable_push": bool(r["enable_push"]),
                    "enable_in_app": bool(r["enable_in_app"]),
                    "enable_email": bool(r["enable_email"]),
                    "digest_frequency": r["digest_frequency"]
                })
            else:
                settings_list.append({
                    "event_type": event,
                    "enable_push": True,
                    "enable_in_app": True,
                    "enable_email": True,
                    "digest_frequency": "instant"
                })
    finally:
        conn.close()
        
    return {"settings": settings_list}

@app.put("/api/v1/notification-settings")
@app.post("/api/v1/notification-settings")
async def notification_settings_update(body: NotificationSettingUpdatePayload):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT OR REPLACE INTO notification_settings (user_id, event_type, enable_push, enable_in_app, enable_email, digest_frequency)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (body.user_id, body.event_type, int(body.enable_push), int(body.enable_in_app), int(body.enable_email), body.digest_frequency))
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
        
    print(f"\n⚙️ [SETTINGS] Updated notifications config for user {body.user_id} - event {body.event_type}")
    return {"status": "success"}

# ══════════════════════════════════════════════════════════════════════════════
#  WebSockets (RFC 6455 over FastAPI)
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

def log_latency(event_type: str, sent_at_str: str):
    try:
        if not sent_at_str:
            return
        # Parse timezone-aware ISO string
        client_dt = datetime.fromisoformat(sent_at_str.replace('Z', '+00:00'))
        server_dt = datetime.now(client_dt.tzinfo)
        diff = server_dt - client_dt
        latency_ms = diff.total_seconds() * 1000
        
        log_path = r"C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server\testlog.txt"
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
    
    # Check if running as a compiled PyInstaller bundle
    is_frozen = getattr(sys, 'frozen', False)
    
    if is_frozen:
        print("\n🚀 Starting iZiiApp Standalone Server in Bundled Mode...")
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8080
        )
    else:
        print("\n🚀 Starting iZiiApp Standalone Server in Development Mode...")
        uvicorn.run(
            "server.app:app",
            host="0.0.0.0",
            port=8080,
            reload=True,
            reload_dirs=["./server"]  # Watch only this subdirectory, avoid scanning parent project
        )
