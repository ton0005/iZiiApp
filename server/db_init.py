# server/db_init.py
import sqlite3
import os

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
    print(f"SQLite Database initialized successfully at: {os.path.abspath(DB_PATH)}")

if __name__ == "__main__":
    init_db()
