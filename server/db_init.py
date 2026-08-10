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
    """
    Khởi tạo schema. Tự chuyển hướng sang PostgreSQL khi
    IZIIAPP_DB_BACKEND=postgres — app.py không cần biết đang chạy backend nào.
    """
    from server_config import CONFIG
    if CONFIG.db_backend == "postgres":
        from db_init_postgres import init_db_postgres
        init_db_postgres()
        return

    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Sync Mutations Table
    # origin_server_id: server_id đầu tiên NHẬN mutation này từ device
    # (khác với server đang lưu bản ghi này, vốn có thể là do relay từ peer khác).
    # NULL = mutation cũ trước khi có multi-server, coi như thuộc server hiện tại.
    # seq: SỐ THỨ TỰ ĐƠN ĐIỆU do server này cấp, tăng dần tuyệt đối.
    #
    # Vì sao cần: con trỏ delta cũ dùng `WHERE server_received_at > ?` tức so
    # sánh CHUỖI thời gian. Trong mesh LAN 3 máy thì tạm ổn, nhưng khi thêm
    # site hoặc adapter doanh nghiệp, chỉ cần lệch đồng hồ vài giây là mutation
    # bị BỎ SÓT VĨNH VIỄN mà không có lỗi nào — kiểu hỏng tệ nhất vì im lặng.
    # seq do chính server cấp nên miễn nhiễm với lệch đồng hồ và với việc chỉnh
    # giờ hệ thống lùi lại.
    #
    # actor_user_id / actor_device_id: phục vụ audit — "AI đã đổi cái gì".
    # Bắt buộc cho kiểm toán an toàn lao động và cho đối soát với ERP.
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS sync_mutations (
        id TEXT PRIMARY KEY,
        client_id TEXT,
        "table" TEXT,
        operation TEXT,
        data TEXT,
        server_received_at TEXT,
        origin_server_id TEXT,
        seq INTEGER,
        actor_user_id TEXT,
        actor_device_id TEXT,
        schema_version INTEGER DEFAULT 1
    )""")

    # 1b. Migration nhẹ cho DB đã tồn tại — CREATE TABLE IF NOT EXISTS không tự
    # thêm cột vào bảng có sẵn.
    cursor.execute('PRAGMA table_info(sync_mutations)')
    existing_cols = {row[1] for row in cursor.fetchall()}
    for col, ddl in (
        ("origin_server_id", 'ALTER TABLE sync_mutations ADD COLUMN origin_server_id TEXT'),
        ("seq",              'ALTER TABLE sync_mutations ADD COLUMN seq INTEGER'),
        ("actor_user_id",    'ALTER TABLE sync_mutations ADD COLUMN actor_user_id TEXT'),
        ("actor_device_id",  'ALTER TABLE sync_mutations ADD COLUMN actor_device_id TEXT'),
        ("schema_version",   'ALTER TABLE sync_mutations ADD COLUMN schema_version INTEGER DEFAULT 1'),
    ):
        if col not in existing_cols:
            cursor.execute(ddl)

    # Indexes for fast mutation delta lookup.
    # idx_sync_mutations_seq là index QUAN TRỌNG NHẤT — mọi truy vấn delta mới
    # đều đi qua nó.
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_sync_mutations_seq ON sync_mutations(seq)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_sync_mutations_received_at ON sync_mutations(server_received_at)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_sync_mutations_origin ON sync_mutations(origin_server_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_sync_mutations_table ON sync_mutations("table")')

    # 1c. Bộ đếm seq — giữ riêng thay vì dùng AUTOINCREMENT vì `id` đã là
    # PRIMARY KEY dạng TEXT (UUID do client sinh), không thể vừa là rowid tăng
    # dần. Bảng 1 dòng, cập nhật bằng UPDATE ... RETURNING trong cùng
    # transaction với INSERT nên không có race giữa các connection.
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS sync_sequence (
        name    TEXT PRIMARY KEY,
        current INTEGER NOT NULL DEFAULT 0
    )""")
    cursor.execute("INSERT OR IGNORE INTO sync_sequence (name, current) VALUES ('mutation', 0)")

    # 2. Server Registry — danh sách các peer server đã biết (phục vụ
    # multi-server sync + mDNS discovery cache).
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS known_servers (
        server_id TEXT PRIMARY KEY,
        zone TEXT,
        host TEXT,
        port INTEGER,
        peer_url TEXT,
        last_synced_at TEXT,
        last_synced_seq INTEGER,
        last_seen_online_at TEXT
    )""")

    cursor.execute('PRAGMA table_info(known_servers)')
    ks_cols = {row[1] for row in cursor.fetchall()}
    for col, ddl in (
        ("peer_url", 'ALTER TABLE known_servers ADD COLUMN peer_url TEXT'),
        # Con trỏ đồng bộ với peer, dạng seq. Thay thế last_synced_at (chuỗi
        # thời gian của peer) vốn phụ thuộc đồng hồ máy peer.
        ("last_synced_seq", 'ALTER TABLE known_servers ADD COLUMN last_synced_seq INTEGER'),
    ):
        if col not in ks_cols:
            cursor.execute(ddl)
    
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
    
    # 7. Webhook Subscriptions
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS webhook_subscriptions (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        event_filter TEXT,
        secret_token TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
    )""")

    # 8. Webhook Dead-Letter Queue — event đã hết số lần retry mà vẫn không
    # gửi được. Trước đây những event này mất im lặng (chỉ còn dòng print).
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS webhook_dead_letters (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        event_id TEXT,
        event_type TEXT,
        payload TEXT,
        last_error TEXT,
        attempts INTEGER,
        failed_at TEXT,
        replayed_at TEXT
    )""")
    cursor.execute(
        'CREATE INDEX IF NOT EXISTS idx_webhook_dead_letters_failed_at ON webhook_dead_letters(failed_at)'
    )

    # 9. Enrollment Tokens — "vé mời" dùng MỘT LẦN để đăng ký thiết bị mới.
    #
    # Thay cho việc phát IZIIAPP_SERVER_SECRET cho mọi máy: vé hết hạn sau vài
    # phút và chỉ dùng được một lần, nên mất thẻ NFC / ảnh chụp QR không đồng
    # nghĩa với mất cả hệ thống.
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS enrollment_tokens (
        token       TEXT PRIMARY KEY,
        created_by  TEXT,
        created_at  TEXT,
        expires_at  TEXT,
        used_at     TEXT,
        used_by     TEXT,
        note        TEXT,
        -- Vé mời mang sẵn CHẾ ĐỘ thiết bị. Quản lý quyết định lúc cấp mã, máy
        -- chỉ việc quét — công nhân không phải chọn gì và không chọn sai được.
        profile          TEXT DEFAULT 'shared',   -- 'shared' | 'personal'
        owner_user_id    TEXT,                    -- bắt buộc khi profile='personal'
        owner_user_name  TEXT,
        session_max_hours INTEGER                 -- NULL = dùng mặc định của chế độ
    )""")
    cursor.execute(
        'CREATE INDEX IF NOT EXISTS idx_enrollment_tokens_expires ON enrollment_tokens(expires_at)'
    )
    # Migration cho DB đã tồn tại
    cursor.execute('PRAGMA table_info(enrollment_tokens)')
    et_cols = {row[1] for row in cursor.fetchall()}
    for col, ddl in (
        ("profile", "ALTER TABLE enrollment_tokens ADD COLUMN profile TEXT DEFAULT 'shared'"),
        ("owner_user_id", "ALTER TABLE enrollment_tokens ADD COLUMN owner_user_id TEXT"),
        ("owner_user_name", "ALTER TABLE enrollment_tokens ADD COLUMN owner_user_name TEXT"),
        ("session_max_hours", "ALTER TABLE enrollment_tokens ADD COLUMN session_max_hours INTEGER"),
    ):
        if col not in et_cols:
            cursor.execute(ddl)

    # 10. Device Tokens — token RIÊNG của từng thiết bị.
    #
    # Lưu HASH chứ không lưu token gốc: database bị lộ thì kẻ tấn công vẫn
    # không mạo danh được thiết bị. Cùng nguyên tắc với lưu mật khẩu.
    # HAI CHẾ ĐỘ THIẾT BỊ:
    #
    #   shared   — máy dùng chung (tablet đặt tại phòng). Nhiều ca dùng chung
    #              một máy nên BẮT BUỘC điểm danh đầu ca, phiên hết hạn 12 giờ.
    #
    #   personal — máy cá nhân của Manager/Supervisor (iPhone, iPad riêng, mang
    #              về nhà). Danh tính đã xác định từ lúc cấp máy nên KHÔNG cần
    #              điểm danh; thời lượng ca tuỳ chỉnh hoặc không giới hạn.
    #
    # Phân biệt này quan trọng vì ràng buộc Alone Worker: yêu cầu điểm danh chỉ
    # có ý nghĩa khi máy dùng chung. Bắt Manager điểm danh trên iPhone riêng là
    # thủ tục vô nghĩa mà vẫn không tăng thêm chút an toàn nào.
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS device_tokens (
        device_id   TEXT PRIMARY KEY,
        token_hash  TEXT NOT NULL,
        scope       TEXT DEFAULT 'device',
        device_name TEXT,
        user_id     TEXT,
        issued_at   TEXT,
        last_used_at TEXT,
        revoked_at  TEXT,
        profile           TEXT DEFAULT 'shared',
        owner_user_id     TEXT,
        owner_user_name   TEXT,
        session_max_hours INTEGER
    )""")
    cursor.execute(
        'CREATE INDEX IF NOT EXISTS idx_device_tokens_hash ON device_tokens(token_hash)'
    )
    cursor.execute('PRAGMA table_info(device_tokens)')
    dt_cols = {row[1] for row in cursor.fetchall()}
    for col, ddl in (
        ("profile", "ALTER TABLE device_tokens ADD COLUMN profile TEXT DEFAULT 'shared'"),
        ("owner_user_id", "ALTER TABLE device_tokens ADD COLUMN owner_user_id TEXT"),
        ("owner_user_name", "ALTER TABLE device_tokens ADD COLUMN owner_user_name TEXT"),
        ("session_max_hours", "ALTER TABLE device_tokens ADD COLUMN session_max_hours INTEGER"),
    ):
        if col not in dt_cols:
            cursor.execute(ddl)

    # 11. Work Sessions — PHIÊN LÀM VIỆC (G1)
    #
    # Tách danh tính NGƯỜI khỏi danh tính MÁY.
    #
    # Trước đây mô hình là "một thiết bị = một người": tablet dùng chung nhiều ca
    # thì cả hai ca ghi là cùng một người. Với Chat chỉ khó chịu, nhưng với cảnh
    # báo Alone Worker thì nghiêm trọng — "device-abc123 đang một mình trong
    # Room 10" không cho biết phải đi cứu ai.
    #
    # Nay: máy đăng ký MỘT LẦN (device_tokens), người điểm danh MỖI CA
    # (work_sessions). Mutation mang cả hai: actor_device_id do server xác thực
    # qua token, actor_user_id lấy từ phiên đang mở.
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS work_sessions (
        id            TEXT PRIMARY KEY,
        device_id     TEXT NOT NULL,
        user_id       TEXT NOT NULL,
        user_name     TEXT,
        department    TEXT,
        zone          TEXT,
        method        TEXT,          -- 'list' | 'pin' | 'nfc_badge' | 'auto'
        started_at    TEXT NOT NULL,
        ended_at      TEXT,          -- NULL = đang trong ca
        ended_reason  TEXT           -- 'manual' | 'timeout' | 'replaced'
    )""")
    # Index cho truy vấn nóng nhất: "máy này có phiên nào đang mở không".
    cursor.execute(
        'CREATE INDEX IF NOT EXISTS idx_work_sessions_open '
        'ON work_sessions(device_id, ended_at)'
    )
    cursor.execute(
        'CREATE INDEX IF NOT EXISTS idx_work_sessions_user ON work_sessions(user_id, started_at)'
    )

    # 12. Employee PINs — mã PIN điểm danh.
    #
    # Lưu ở SERVER chứ không trong bảng nhân viên phía app: PIN là bí mật, không
    # nên đồng bộ xuống mọi thiết bị qua mutation log. Chỉ lưu HASH kèm salt.
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS employee_pins (
        user_id    TEXT PRIMARY KEY,
        pin_hash   TEXT NOT NULL,
        salt       TEXT NOT NULL,
        updated_at TEXT,
        updated_by TEXT
    )""")

    # 13. Schema Migrations — theo dõi các migration dữ liệu chỉ được chạy MỘT
    # LẦN (khác với CREATE TABLE IF NOT EXISTS vốn idempotent tự nhiên).
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS schema_migrations (
        name TEXT PRIMARY KEY,
        applied_at TEXT,
        detail TEXT
    )""")

    conn.commit()

    _run_data_migrations(conn)

    conn.close()
    print(f"SQLite Database initialized successfully at: {os.path.abspath(DB_PATH)}")


def _migration_applied(conn, name: str) -> bool:
    row = conn.execute("SELECT 1 FROM schema_migrations WHERE name = ?", (name,)).fetchone()
    return row is not None


def _mark_migration(conn, name: str, detail: str = "") -> None:
    from datetime import datetime, timezone
    conn.execute(
        "INSERT OR REPLACE INTO schema_migrations (name, applied_at, detail) VALUES (?, ?, ?)",
        (name, datetime.now(timezone.utc).isoformat(), detail),
    )
    conn.commit()


def _run_data_migrations(conn) -> None:
    """
    Các migration dữ liệu chạy một lần duy nhất, có ghi sổ trong
    schema_migrations để lần khởi động sau không chạy lại.
    """
    # ── 001: dọn timestamp naive ────────────────────────────────────────────
    # Trước đây server_received_at được ghi bằng datetime.now() (naive, giờ
    # local). Sau khi chuyển sang UTC-aware, hai định dạng cùng tồn tại trong
    # một cột TEXT:
    #     naive: 2026-08-01T13:00:00.123456
    #     UTC:   2026-08-01T03:30:00.123456+00:00
    # Truy vấn delta dùng `WHERE server_received_at > ?` tức so sánh CHUỖI. Giờ
    # local (UTC+9:30) luôn lớn hơn giờ UTC cùng thời điểm, nên mọi hàng naive
    # sẽ luôn thoả điều kiện và bị trả về lặp lại ở mỗi chu kỳ sync 45s.
    #
    # sync_mutations là MUTATION LOG (nhật ký thay đổi), không phải bảng state:
    # client Drift đã áp dụng và lưu dữ liệu thật ở local rồi. Vì vậy xoá các
    # hàng định dạng cũ là an toàn và dứt điểm.
    name = "001_purge_naive_timestamps"
    if not _migration_applied(conn, name):
        try:
            cur = conn.execute(
                "DELETE FROM sync_mutations "
                "WHERE server_received_at IS NOT NULL "
                "  AND server_received_at NOT LIKE '%+00:00' "
                "  AND server_received_at NOT LIKE '%Z'"
            )
            deleted = cur.rowcount
            conn.commit()
            _mark_migration(conn, name, f"deleted={deleted}")
            if deleted > 0:
                print(
                    f"🧹 [MIGRATION] {name}: đã xoá {deleted} mutation có timestamp "
                    f"định dạng cũ (naive local-time)."
                )
            else:
                print(f"✅ [MIGRATION] {name}: không có bản ghi nào cần dọn.")
        except Exception as e:
            print(f"⚠️  [MIGRATION] {name} thất bại: {e} — sẽ thử lại lần khởi động sau.")

    # ── 002: cấp seq cho các mutation đã có ─────────────────────────────────
    # Các bản ghi ghi trước khi có cột seq đang để NULL. Nếu cứ để vậy thì truy
    # vấn `WHERE seq > ?` sẽ BỎ QUA chúng hoàn toàn (NULL không thoả mọi phép
    # so sánh) → thiết bị mới sẽ không bao giờ nhận được dữ liệu lịch sử.
    #
    # Gán seq theo thứ tự server_received_at tăng dần để giữ đúng trình tự nhân
    # quả, rồi đẩy bộ đếm lên quá giá trị lớn nhất.
    name = "002_backfill_mutation_seq"
    if not _migration_applied(conn, name):
        try:
            rows = conn.execute(
                "SELECT id FROM sync_mutations WHERE seq IS NULL "
                "ORDER BY server_received_at ASC, id ASC"
            ).fetchall()
            start = conn.execute(
                "SELECT COALESCE(MAX(seq), 0) FROM sync_mutations"
            ).fetchone()[0]
            n = start
            for r in rows:
                n += 1
                conn.execute("UPDATE sync_mutations SET seq = ? WHERE id = ?", (n, r[0]))
            conn.execute(
                "UPDATE sync_sequence SET current = ? WHERE name = 'mutation' AND current < ?",
                (n, n),
            )
            conn.commit()
            _mark_migration(conn, name, f"backfilled={len(rows)} max_seq={n}")
            print(f"✅ [MIGRATION] {name}: đã cấp seq cho {len(rows)} mutation (max_seq={n}).")
        except Exception as e:
            print(f"⚠️  [MIGRATION] {name} thất bại: {e} — sẽ thử lại lần khởi động sau.")


def prune_old_mutations(days: int = 30) -> int:
    """
    Prunes mutations older than `days` days from sync_mutations table
    to prevent unlimited table growth.
    """
    from server_config import CONFIG
    if CONFIG.db_backend == "postgres":
        from db_init_postgres import prune_old_mutations_postgres
        return prune_old_mutations_postgres(days)

    from datetime import datetime, timezone, timedelta
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM sync_mutations WHERE server_received_at < ?", (cutoff,))
        deleted_count = cursor.rowcount
        conn.commit()
        if deleted_count > 0:
            try:
                print(f"🧹 [DB] Pruned {deleted_count} mutations older than {days} days.")
            except Exception:
                print(f"[DB] Pruned {deleted_count} mutations older than {days} days.")
        return deleted_count
    finally:
        conn.close()


if __name__ == "__main__":
    init_db()
