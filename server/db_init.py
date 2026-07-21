# server/db_init.py
"""
Single source of truth cho schema database.

QUAN TRỌNG: file này KHÔNG tự mở SQLite connection riêng nữa (trước đây dùng
relative path "./data/iziiapp.db" — sai vị trí nếu chạy từ working directory
khác với app.py, dẫn đến 2 file .db khác nhau cùng tồn tại).

Từ giờ init_db() dùng chung get_db_connection() trong database.py — đảm bảo
CÙNG MỘT stable path (get_stable_data_dir(), tương thích cả khi bundle bằng
PyInstaller) và CÙNG MỘT bộ PRAGMA production, không bị lệch với phần còn
lại của hệ thống.

app.py KHÔNG được định nghĩa init_db() riêng nữa — chỉ import và gọi
db_init.init_db() để tránh 2 nơi định nghĩa schema có thể lệch nhau khi
1 trong 2 chỗ được sửa mà quên chỗ kia.
"""
import os
from database import get_db_connection, DB_PATH


def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Sync Mutations Table
    # origin_server_id: server_id đầu tiên NHẬN mutation này từ device
    # (khác với server đang lưu bản ghi này, vốn có thể là do relay từ peer khác).
    # NULL = mutation cũ trước khi có multi-server, coi như thuộc server hiện tại.
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS sync_mutations (
        id TEXT PRIMARY KEY,
        client_id TEXT,
        "table" TEXT,
        operation TEXT,
        data TEXT,
        server_received_at TEXT,
        origin_server_id TEXT
    )""")

    # 1b. Migration nhẹ: nếu DB cũ đã tồn tại trước khi có cột này, thêm cột
    # bằng ALTER TABLE (CREATE TABLE IF NOT EXISTS không tự thêm cột cho bảng
    # đã có sẵn).
    cursor.execute('PRAGMA table_info(sync_mutations)')
    existing_cols = {row[1] for row in cursor.fetchall()}
    if "origin_server_id" not in existing_cols:
        cursor.execute('ALTER TABLE sync_mutations ADD COLUMN origin_server_id TEXT')

    # 2. Server Registry — danh sách các peer server đã biết (phục vụ
    # multi-server sync + mDNS discovery cache).
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS known_servers (
        server_id TEXT PRIMARY KEY,
        zone TEXT,
        host TEXT,
        port INTEGER,
        last_synced_at TEXT,
        last_seen_online_at TEXT
    )""")
    
    # 3. Registered Devices
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
    
    # 4. Encrypted Message Queue (E2EE Envelopes)
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
    
    # 5. In-App Notifications
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
    
    # 6. User Notification Settings
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
