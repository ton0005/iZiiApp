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
        delivered_at TEXT,
        -- Số lần máy nhận đã thử giải mã mà thất bại. Không có cột này thì
        -- một tin hỏng sẽ kẹt trong hàng đợi vĩnh viễn: máy nhận không giải mã
        -- được nên không ack, server không xoá nên lần sau lại gửi tiếp — vòng
        -- lặp vô tận đã gặp trong log ngày 11/08 (1173 tin kẹt, 9286 request).
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        dead_lettered_at TEXT
    )""")

    # Migration cho database đã tồn tại trước khi có ba cột trên.
    cursor.execute("PRAGMA table_info(message_queue)")
    _mq_cols = {row[1] for row in cursor.fetchall()}
    for _col, _ddl in (
        ("failed_attempts", "INTEGER NOT NULL DEFAULT 0"),
        ("last_error", "TEXT"),
        ("dead_lettered_at", "TEXT"),
    ):
        if _col not in _mq_cols:
            cursor.execute(f"ALTER TABLE message_queue ADD COLUMN {_col} {_ddl}")

    # Hàng đợi luôn được truy vấn theo (người nhận, chưa giao) — thiếu index này
    # thì mỗi lần poll là một lần quét toàn bảng, 5 giây một lần, mỗi thiết bị.
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_mq_recipient_undelivered "
        "ON message_queue (recipient_device_id, delivered_at, sent_at)"
    )
    
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

    # 14. Phase 5 — Miền hiện trường: Chấm công, An toàn, Job types, và Read Models
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_job_types (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        plan_minutes INTEGER DEFAULT 0,
        is_solo_job INTEGER DEFAULT 0,
        is_custom INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        color TEXT,
        label TEXT,
        icon TEXT,
        sort_order INTEGER DEFAULT 100,
        created_at TEXT
    )""")
    cursor.execute('PRAGMA table_info(mushroom_job_types)')
    mjt_cols = {row[1] for row in cursor.fetchall()}
    for col, ddl in (
        ("color", "ALTER TABLE mushroom_job_types ADD COLUMN color TEXT"),
        ("label", "ALTER TABLE mushroom_job_types ADD COLUMN label TEXT"),
        ("icon", "ALTER TABLE mushroom_job_types ADD COLUMN icon TEXT"),
        ("sort_order", "ALTER TABLE mushroom_job_types ADD COLUMN sort_order INTEGER DEFAULT 100"),
    ):
        if col not in mjt_cols:
            cursor.execute(ddl)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_attendance_events (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        plan_id TEXT,
        event_type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        source TEXT NOT NULL,
        location TEXT,
        created_at TEXT
    )""")
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_att_events_emp ON mushroom_attendance_events(employee_id, timestamp)')

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_break_policies (
        id TEXT PRIMARY KEY,
        standard_break_minutes INTEGER DEFAULT 30,
        grace_minutes INTEGER DEFAULT 5,
        extra_break_rule TEXT DEFAULT 'unpaid'
    )""")
    cursor.execute("""
    INSERT OR IGNORE INTO mushroom_break_policies (id, standard_break_minutes, grace_minutes, extra_break_rule)
    VALUES ('default_policy', 30, 5, 'unpaid')
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_daily_timesheets (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        plan_date TEXT NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        total_break_taken_minutes INTEGER DEFAULT 0,
        standard_break_allowed_minutes INTEGER DEFAULT 0,
        extra_break_minutes INTEGER DEFAULT 0,
        gross_worked_minutes INTEGER DEFAULT 0,
        paid_minutes INTEGER DEFAULT 0,
        overtime_minutes INTEGER DEFAULT 0,
        assigned_team_color TEXT,
        assigned_rooms_json TEXT,
        status TEXT DEFAULT 'normal',
        created_at TEXT,
        updated_at TEXT
    )""")
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_timesheets_emp_date ON mushroom_daily_timesheets(employee_id, plan_date)')

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_shifts (
        id TEXT PRIMARY KEY,
        plan_id TEXT,
        role TEXT,
        employee_id TEXT,
        start_time TEXT,
        shed_room_list_json TEXT
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_payroll_calculations (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        pay_period TEXT NOT NULL,
        total_paid_hours REAL DEFAULT 0.0,
        total_overtime_hours REAL DEFAULT 0.0,
        base_pay REAL DEFAULT 0.0,
        overtime_pay REAL DEFAULT 0.0,
        total_pay REAL DEFAULT 0.0,
        created_at TEXT
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_job_safety_configs (
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL,
        check_in_interval_minutes INTEGER DEFAULT 30,
        grace_period_minutes INTEGER DEFAULT 5,
        escalation_target TEXT DEFAULT 'supervisor',
        auto_start_on_job_begin INTEGER DEFAULT 1,
        alarm_type TEXT DEFAULT 'push_inapp',
        created_at TEXT
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_safety_checkin_logs (
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL,
        worker_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        gps_latitude REAL,
        gps_longitude REAL,
        response_time_seconds INTEGER,
        notes TEXT,
        timestamp TEXT NOT NULL
    )""")
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_safety_logs_job ON mushroom_safety_checkin_logs(job_id)')

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS grow_rooms (
        id TEXT PRIMARY KEY,
        name TEXT,
        status TEXT,
        current_stage TEXT,
        day_in_cycle INTEGER DEFAULT 0,
        target_yield REAL DEFAULT 0.0,
        picked_yield REAL DEFAULT 0.0,
        created_at TEXT,
        updated_at TEXT
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_jobs (
        id TEXT PRIMARY KEY,
        room_id TEXT,
        job_type TEXT,
        name TEXT,
        status TEXT,
        assignee TEXT,
        priority TEXT,
        scheduled_at TEXT,
        started_at TEXT,
        completed_at TEXT,
        plan_details TEXT,
        prochloraz_rate TEXT,
        linked_task_id TEXT,
        is_solo_job INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        project_id TEXT,
        title TEXT,
        description TEXT,
        status TEXT,
        priority TEXT,
        due_date TEXT,
        created_at TEXT
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS picker_teams (
        id TEXT PRIMARY KEY,
        plan_id TEXT,
        color_code TEXT,
        team_leader_id TEXT,
        headcount INTEGER DEFAULT 0,
        rate_estimate REAL DEFAULT 0.0,
        member_ids_json TEXT,
        is_seed INTEGER DEFAULT 0
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS departments (
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        created_at TEXT,
        is_seed INTEGER DEFAULT 0
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT,
        sender_id TEXT,
        content TEXT,
        created_at TEXT,
        is_seed INTEGER DEFAULT 0
    )""")

    # Phase 1: Audit columns & tenant_id for domain tables (SQLite compatibility)
    domain_tables = [
        "tasks", "mushroom_jobs", "grow_rooms", "mushroom_job_types",
        "mushroom_attendance_events", "mushroom_daily_timesheets",
        "mushroom_break_policies", "mushroom_shifts", "mushroom_payroll_calculations",
        "mushroom_job_safety_configs", "mushroom_safety_checkin_logs",
        "picker_teams", "departments", "chat_messages",
    ]
    for tbl in domain_tables:
        cursor.execute(f"PRAGMA table_info({tbl})")
        existing_cols = {row[1] for row in cursor.fetchall()}
        for col, ddl in (
            ("tenant_id",        f"ALTER TABLE {tbl} ADD COLUMN tenant_id TEXT NOT NULL DEFAULT 'default'"),
            ("created_by",       f"ALTER TABLE {tbl} ADD COLUMN created_by TEXT"),
            ("created_at",       f"ALTER TABLE {tbl} ADD COLUMN created_at TEXT"),
            ("updated_by",       f"ALTER TABLE {tbl} ADD COLUMN updated_by TEXT"),
            ("updated_at",       f"ALTER TABLE {tbl} ADD COLUMN updated_at TEXT"),
            ("last_mutation_id", f"ALTER TABLE {tbl} ADD COLUMN last_mutation_id TEXT"),
            ("last_seq",         f"ALTER TABLE {tbl} ADD COLUMN last_seq INTEGER DEFAULT 0"),
            ("deleted_at",       f"ALTER TABLE {tbl} ADD COLUMN deleted_at TEXT"),
            ("is_seed",          f"ALTER TABLE {tbl} ADD COLUMN is_seed INTEGER DEFAULT 0"),
        ):
            if col not in existing_cols:
                try:
                    cursor.execute(ddl)
                except Exception:
                    pass
        cursor.execute(f"CREATE INDEX IF NOT EXISTS idx_{tbl}_tenant_id ON {tbl}(tenant_id, id)")

    # Phase 2: Module System, Tenant Modules & Model Registry (Q2)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS tenant_modules (
        tenant_id    TEXT NOT NULL,
        module_name  TEXT NOT NULL,
        version      TEXT NOT NULL,
        enabled      INTEGER NOT NULL DEFAULT 1,
        installed_at TEXT,
        settings     TEXT DEFAULT '{}',
        PRIMARY KEY (tenant_id, module_name)
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS model_registry (
        tenant_id     TEXT NOT NULL,
        model_name    TEXT NOT NULL,
        module_name   TEXT NOT NULL,
        table_name    TEXT NOT NULL,
        label         TEXT NOT NULL,
        is_syncable   INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (tenant_id, model_name)
    )""")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS field_registry (
        tenant_id     TEXT NOT NULL,
        model_name    TEXT NOT NULL,
        field_name    TEXT NOT NULL,
        data_type     TEXT NOT NULL,
        is_required   INTEGER NOT NULL DEFAULT 0,
        is_custom     INTEGER NOT NULL DEFAULT 0,
        label         TEXT NOT NULL,
        enum_values   TEXT,
        ui            TEXT DEFAULT '{}',
        PRIMARY KEY (tenant_id, model_name, field_name)
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


def prune_message_queue(delivered_days: int = 7, stuck_days: int = 3) -> int:
    """
    Dọn hàng đợi tin nhắn E2EE.

    Hai việc:
      1. Xoá tin đã giao quá [delivered_days] ngày — server chỉ là trạm trung
         chuyển, bản chính nằm ở máy nhận.
      2. Dead-letter tin CHƯA giao quá [stuck_days] ngày. Đây là lưới an toàn:
         nếu vì lý do nào đó máy nhận không báo lỗi được, tin vẫn phải ngừng
         được gửi lại. Lần test 11/08 có 1173 tin kẹt vì thiếu đúng cơ chế này.

    Tin dead-letter KHÔNG bị xoá — vẫn nằm trong bảng để điều tra.
    """
    from server_config import CONFIG
    if CONFIG.db_backend == "postgres":
        from db_init_postgres import prune_message_queue_postgres
        return prune_message_queue_postgres(delivered_days, stuck_days)

    from datetime import datetime, timezone, timedelta

    now = datetime.now(timezone.utc)
    delivered_cutoff = (now - timedelta(days=delivered_days)).isoformat()
    stuck_cutoff = (now - timedelta(days=stuck_days)).isoformat()

    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "DELETE FROM message_queue "
            "WHERE delivered_at IS NOT NULL AND delivered_at < ?",
            (delivered_cutoff,),
        )
        deleted = cursor.rowcount

        cursor.execute(
            "UPDATE message_queue SET dead_lettered_at = ?, "
            "       last_error = COALESCE(last_error, 'stuck_too_long') "
            "WHERE delivered_at IS NULL AND dead_lettered_at IS NULL "
            "  AND sent_at < ?",
            (now.isoformat(), stuck_cutoff),
        )
        dead = cursor.rowcount
        conn.commit()

        if deleted or dead:
            print(
                f"🧹 [MSG-QUEUE] Xoá {deleted} tin đã giao cũ, "
                f"dead-letter {dead} tin kẹt quá {stuck_days} ngày."
            )
        return deleted + dead
    except Exception as e:
        print(f"⚠️  [MSG-QUEUE] Không dọn được hàng đợi: {e}")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    init_db()
