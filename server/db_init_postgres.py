# server/db_init_postgres.py
"""
Schema PostgreSQL — bản song song của db_init.py.

KHÁC BIỆT ĐÁNG CHÚ Ý SO VỚI BẢN SQLITE:

1. `seq` dùng BIGSERIAL thay cho bảng đếm thủ công `sync_sequence`.
   Bản SQLite phải tự quản bộ đếm vì `id` là TEXT (UUID do client sinh) nên
   không thể vừa làm rowid tăng dần. Postgres có sequence thật, an toàn tuyệt
   đối với nhiều writer đồng thời — đây chính là lý do chuyển sang Postgres.

2. `INSERT OR REPLACE` → `INSERT ... ON CONFLICT (id) DO UPDATE`.

3. Kiểu dữ liệu: TEXT giữ nguyên, INTEGER → BIGINT/INT, thời gian vẫn lưu TEXT
   ISO-8601 UTC để TƯƠNG THÍCH TUYỆT ĐỐI với dữ liệu SQLite đang có. Không đổi
   sang TIMESTAMPTZ ở bước này — việc đó nên làm thành một migration riêng sau
   khi đã chạy ổn định, tránh trộn hai thay đổi rủi ro vào cùng một lần.
"""
from __future__ import annotations

from db_postgres import pg_connection

DDL_STATEMENTS = [
    # ── 1. Mutation log ─────────────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS sync_mutations (
        id                 TEXT PRIMARY KEY,
        client_id          TEXT,
        "table"            TEXT,
        operation          TEXT,
        data               TEXT,
        server_received_at TEXT,
        origin_server_id   TEXT,
        seq                BIGSERIAL,
        actor_user_id      TEXT,
        actor_device_id    TEXT,
        schema_version     INT DEFAULT 1
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_sync_mutations_seq ON sync_mutations(seq)',
    'CREATE INDEX IF NOT EXISTS idx_sync_mutations_received_at ON sync_mutations(server_received_at)',
    'CREATE INDEX IF NOT EXISTS idx_sync_mutations_origin ON sync_mutations(origin_server_id)',
    'CREATE INDEX IF NOT EXISTS idx_sync_mutations_table ON sync_mutations("table")',

    # ── 2. Server registry ──────────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS known_servers (
        server_id           TEXT PRIMARY KEY,
        zone                TEXT,
        host                TEXT,
        port                INT,
        peer_url            TEXT,
        last_synced_at      TEXT,
        last_synced_seq     BIGINT,
        last_seen_online_at TEXT
    )
    """,

    # ── 3. Devices ──────────────────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS devices (
        device_id          TEXT PRIMARY KEY,
        user_id            TEXT,
        public_key         TEXT,
        signing_public_key TEXT,
        device_name        TEXT,
        platform           TEXT,
        push_token         TEXT,
        fingerprint        TEXT,
        registered_at      TEXT,
        last_seen_at       TEXT
    )
    """,

    # ── 4. E2EE message queue ───────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS message_queue (
        id                  TEXT PRIMARY KEY,
        conversation_id     TEXT,
        sender_device_id    TEXT,
        recipient_device_id TEXT,
        ciphertext          TEXT,
        nonce               TEXT,
        signature           TEXT,
        sent_at             TEXT,
        delivered_at        TEXT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_message_queue_recipient ON message_queue(recipient_device_id, delivered_at)',

    # ── 5. Notifications ────────────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS notifications (
        id          TEXT PRIMARY KEY,
        user_id     TEXT,
        title       TEXT,
        body        TEXT,
        event_type  TEXT,
        resource_id TEXT,
        read_at     TEXT,
        created_at  TEXT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id)',

    # ── 6. Notification settings ────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS notification_settings (
        user_id          TEXT,
        event_type       TEXT,
        enable_push      INT,
        enable_in_app    INT,
        enable_email     INT,
        digest_frequency TEXT,
        PRIMARY KEY (user_id, event_type)
    )
    """,

    # ── 7. Webhooks ─────────────────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS webhook_subscriptions (
        id           TEXT PRIMARY KEY,
        url          TEXT NOT NULL,
        event_filter TEXT,
        secret_token TEXT,
        is_active    INT DEFAULT 1,
        created_at   TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS webhook_dead_letters (
        id          TEXT PRIMARY KEY,
        url         TEXT NOT NULL,
        event_id    TEXT,
        event_type  TEXT,
        payload     TEXT,
        last_error  TEXT,
        attempts    INT,
        failed_at   TEXT,
        replayed_at TEXT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_webhook_dead_letters_failed_at ON webhook_dead_letters(failed_at)',

    # ── 8. Enrollment & device tokens ───────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS enrollment_tokens (
        token      TEXT PRIMARY KEY,
        created_by TEXT,
        created_at TEXT,
        expires_at TEXT,
        used_at    TEXT,
        used_by    TEXT,
        note       TEXT,
        profile           TEXT DEFAULT 'shared',
        owner_user_id     TEXT,
        owner_user_name   TEXT,
        session_max_hours INT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_enrollment_tokens_expires ON enrollment_tokens(expires_at)',
    """
    CREATE TABLE IF NOT EXISTS device_tokens (
        device_id    TEXT PRIMARY KEY,
        token_hash   TEXT NOT NULL,
        scope        TEXT DEFAULT 'device',
        device_name  TEXT,
        user_id      TEXT,
        issued_at    TEXT,
        last_used_at TEXT,
        revoked_at   TEXT,
        profile           TEXT DEFAULT 'shared',
        owner_user_id     TEXT,
        owner_user_name   TEXT,
        session_max_hours INT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_device_tokens_hash ON device_tokens(token_hash)',

    # ── 9. Work sessions & employee PINs (G1) ───────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS work_sessions (
        id           TEXT PRIMARY KEY,
        device_id    TEXT NOT NULL,
        user_id      TEXT NOT NULL,
        user_name    TEXT,
        department   TEXT,
        zone         TEXT,
        method       TEXT,
        started_at   TEXT NOT NULL,
        ended_at     TEXT,
        ended_reason TEXT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_work_sessions_open ON work_sessions(device_id, ended_at)',
    'CREATE INDEX IF NOT EXISTS idx_work_sessions_user ON work_sessions(user_id, started_at)',
    """
    CREATE TABLE IF NOT EXISTS employee_pins (
        user_id    TEXT PRIMARY KEY,
        pin_hash   TEXT NOT NULL,
        salt       TEXT NOT NULL,
        updated_at TEXT,
        updated_by TEXT
    )
    """,

    # ── 10. Migration tracking ──────────────────────────────────────────────
    """
    CREATE TABLE IF NOT EXISTS schema_migrations (
        name       TEXT PRIMARY KEY,
        applied_at TEXT,
        detail     TEXT
    )
    """,
]

# Migration bổ sung cột cho database Postgres đã tồn tại từ trước.
# Postgres hỗ trợ ADD COLUMN IF NOT EXISTS nên không cần dò PRAGMA như SQLite.
ALTER_STATEMENTS = [
    'ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS origin_server_id TEXT',
    'ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS actor_user_id TEXT',
    'ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS actor_device_id TEXT',
    'ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS schema_version INT DEFAULT 1',
    'ALTER TABLE known_servers ADD COLUMN IF NOT EXISTS peer_url TEXT',
    'ALTER TABLE known_servers ADD COLUMN IF NOT EXISTS last_synced_seq BIGINT',
    # Profile thiết bị (shared / personal)
    "ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS profile TEXT DEFAULT 'shared'",
    'ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS owner_user_id TEXT',
    'ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS owner_user_name TEXT',
    'ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS session_max_hours INT',
    # Hàng đợi tin nhắn: chống kẹt vô hạn khi máy nhận không giải mã được.
    'ALTER TABLE message_queue ADD COLUMN IF NOT EXISTS failed_attempts INT NOT NULL DEFAULT 0',
    'ALTER TABLE message_queue ADD COLUMN IF NOT EXISTS last_error TEXT',
    'ALTER TABLE message_queue ADD COLUMN IF NOT EXISTS dead_lettered_at TEXT',
    # Sửa các database PostgreSQL đã lỡ tạo cột này ở kiểu TIMESTAMPTZ.
    #
    # VÌ SAO BỌC TRONG KHỐI DO THAY VÌ ALTER TRỰC TIẾP: init_db_postgres() chạy ở
    # MỖI LẦN server khởi động. `ALTER TABLE ... ALTER COLUMN ... TYPE` luôn lấy
    # khoá ACCESS EXCLUSIVE trên bảng — chặn mọi đọc/ghi trong lúc thực thi — kể
    # cả khi kiểu đã đúng và không cần rewrite. Với message_queue lớn thì đó là
    # một khoảng đứng hình ở mỗi lần start, hoàn toàn không cần thiết.
    # Kiểm tra information_schema trước để lần thứ hai trở đi là no-op thật sự.
    """
    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name   = 'message_queue'
              AND column_name  = 'dead_lettered_at'
              AND data_type   <> 'text'
        ) THEN
            ALTER TABLE message_queue
                ALTER COLUMN dead_lettered_at TYPE TEXT USING dead_lettered_at::text;
            RAISE NOTICE 'Da doi message_queue.dead_lettered_at sang TEXT.';
        END IF;
    END $$;
    """,
    "ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS profile TEXT DEFAULT 'shared'",
    'ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS owner_user_id TEXT',
    'ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS owner_user_name TEXT',
    'ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS session_max_hours INT',
]


def init_db_postgres() -> None:
    with pg_connection() as conn:
        for stmt in DDL_STATEMENTS:
            conn.execute(stmt)
        for stmt in ALTER_STATEMENTS:
            try:
                conn.execute(stmt)
            except Exception as e:
                print(f"⚠️  [PG] Bỏ qua ALTER: {e}")
        conn.commit()
    print("🐘 [PG] Schema PostgreSQL đã sẵn sàng.")


def prune_old_mutations_postgres(days: int = 30) -> int:
    from datetime import datetime, timezone, timedelta
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    with pg_connection() as conn:
        cur = conn.execute(
            "DELETE FROM sync_mutations WHERE server_received_at < %s", (cutoff,)
        )
        deleted = cur.rowcount
        conn.commit()
    if deleted > 0:
        print(f"🧹 [PG] Đã dọn {deleted} mutation cũ hơn {days} ngày.")
    return deleted


def prune_message_queue_postgres(delivered_days: int = 7, stuck_days: int = 3) -> int:
    """Bản PostgreSQL của prune_message_queue — xem db_init.py:491 để biết lý do."""
    from datetime import datetime, timezone, timedelta

    now = datetime.now(timezone.utc)
    delivered_cutoff = (now - timedelta(days=delivered_days)).isoformat()
    stuck_cutoff = (now - timedelta(days=stuck_days)).isoformat()

    with pg_connection() as conn:
        cur = conn.execute(
            "DELETE FROM message_queue "
            "WHERE delivered_at IS NOT NULL AND delivered_at < %s",
            (delivered_cutoff,),
        )
        deleted = cur.rowcount

        cur = conn.execute(
            "UPDATE message_queue SET dead_lettered_at = %s, "
            "       last_error = COALESCE(last_error, 'stuck_too_long') "
            "WHERE delivered_at IS NULL AND dead_lettered_at IS NULL "
            "  AND sent_at < %s",
            (now.isoformat(), stuck_cutoff),
        )
        dead = cur.rowcount
        conn.commit()

    if deleted or dead:
        print(f"🧹 [PG][MSG-QUEUE] Xoá {deleted} tin đã giao cũ, dead-letter {dead} tin kẹt.")
    return deleted + dead

