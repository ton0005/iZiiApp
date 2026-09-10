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
        last_seen_at       TIMESTAMPTZ
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

    # ── 11. Phase 5 — Field domain tables: attendance, safety, jobs, rooms ─
    """
    CREATE TABLE IF NOT EXISTS mushroom_job_types (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        plan_minutes INT DEFAULT 0,
        is_solo_job INT DEFAULT 0,
        is_custom   INT DEFAULT 0,
        is_active   INT DEFAULT 1,
        color       TEXT,
        label       JSONB,
        icon        TEXT,
        sort_order  INT DEFAULT 100,
        created_at  TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS mushroom_attendance_events (
        id          TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        plan_id     TEXT,
        event_type  TEXT NOT NULL,
        timestamp   TEXT NOT NULL,
        source      TEXT NOT NULL,
        location    TEXT,
        created_at  TEXT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_att_events_emp ON mushroom_attendance_events(employee_id, timestamp)',
    """
    CREATE TABLE IF NOT EXISTS mushroom_break_policies (
        id                     TEXT PRIMARY KEY,
        standard_break_minutes INT DEFAULT 30,
        grace_minutes          INT DEFAULT 5,
        extra_break_rule       TEXT DEFAULT 'unpaid'
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS mushroom_daily_timesheets (
        id                             TEXT PRIMARY KEY,
        employee_id                    TEXT NOT NULL,
        plan_date                      TEXT NOT NULL,
        check_in_time                  TEXT,
        check_out_time                 TEXT,
        total_break_taken_minutes      INT DEFAULT 0,
        standard_break_allowed_minutes INT DEFAULT 0,
        extra_break_minutes            INT DEFAULT 0,
        gross_worked_minutes           INT DEFAULT 0,
        paid_minutes                   INT DEFAULT 0,
        overtime_minutes               INT DEFAULT 0,
        assigned_team_color            TEXT,
        assigned_rooms_json            TEXT,
        status                         TEXT DEFAULT 'normal',
        created_at                     TEXT,
        updated_at                     TEXT
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_timesheets_emp_date ON mushroom_daily_timesheets(employee_id, plan_date)',
    """
    CREATE TABLE IF NOT EXISTS mushroom_shifts (
        id                  TEXT PRIMARY KEY,
        plan_id             TEXT,
        role                TEXT,
        employee_id         TEXT,
        start_time          TEXT,
        shed_room_list_json TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS mushroom_payroll_calculations (
        id                   TEXT PRIMARY KEY,
        employee_id          TEXT NOT NULL,
        pay_period           TEXT NOT NULL,
        total_paid_hours     REAL DEFAULT 0.0,
        total_overtime_hours REAL DEFAULT 0.0,
        base_pay             REAL DEFAULT 0.0,
        overtime_pay         REAL DEFAULT 0.0,
        total_pay            REAL DEFAULT 0.0,
        created_at           TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS mushroom_job_safety_configs (
        id                        TEXT PRIMARY KEY,
        job_id                    TEXT NOT NULL,
        check_in_interval_minutes INT DEFAULT 30,
        grace_period_minutes      INT DEFAULT 5,
        escalation_target         TEXT DEFAULT 'supervisor',
        auto_start_on_job_begin   INT DEFAULT 1,
        alarm_type                TEXT DEFAULT 'push_inapp',
        created_at                TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS mushroom_safety_checkin_logs (
        id                    TEXT PRIMARY KEY,
        job_id                TEXT NOT NULL,
        worker_id             TEXT NOT NULL,
        event_type            TEXT NOT NULL,
        gps_latitude          REAL,
        gps_longitude         REAL,
        response_time_seconds INT,
        notes                 TEXT,
        timestamp             TEXT NOT NULL
    )
    """,
    'CREATE INDEX IF NOT EXISTS idx_safety_logs_job ON mushroom_safety_checkin_logs(job_id)',
    """
    CREATE TABLE IF NOT EXISTS grow_rooms (
        id            TEXT PRIMARY KEY,
        name          TEXT,
        status        TEXT,
        current_stage TEXT,
        day_in_cycle  INT DEFAULT 0,
        target_yield  REAL DEFAULT 0.0,
        picked_yield  REAL DEFAULT 0.0,
        created_at    TEXT,
        updated_at    TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS mushroom_jobs (
        id              TEXT PRIMARY KEY,
        room_id         TEXT,
        job_type        TEXT,
        name            TEXT,
        status          TEXT,
        assignee        TEXT,
        priority        TEXT,
        scheduled_at    TEXT,
        started_at      TEXT,
        completed_at    TEXT,
        plan_details    TEXT,
        prochloraz_rate TEXT,
        linked_task_id  TEXT,
        is_solo_job     INT DEFAULT 0,
        created_at      TEXT,
        updated_at      TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS tasks (
        id          TEXT PRIMARY KEY,
        project_id  TEXT,
        title       TEXT,
        description TEXT,
        status      TEXT,
        priority    TEXT,
        due_date    TEXT,
        created_at  TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS picker_teams (
        id               TEXT PRIMARY KEY,
        plan_id          TEXT,
        color_code       TEXT,
        team_leader_id   TEXT,
        headcount        INT DEFAULT 0,
        rate_estimate    REAL DEFAULT 0.0,
        member_ids_json  TEXT,
        is_seed          INT DEFAULT 0
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS departments (
        id          TEXT PRIMARY KEY,
        name        TEXT,
        description TEXT,
        created_at  TEXT,
        is_seed     INT DEFAULT 0
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS chat_messages (
        id              TEXT PRIMARY KEY,
        conversation_id TEXT,
        sender_id       TEXT,
        content         TEXT,
        created_at      TEXT,
        is_seed         INT DEFAULT 0
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
    """
    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'devices' AND column_name = 'last_seen_at' AND data_type = 'text'
        ) THEN
            ALTER TABLE devices
                ALTER COLUMN last_seen_at TYPE TIMESTAMPTZ USING (
                    CASE
                        WHEN last_seen_at IS NULL OR trim(last_seen_at) = '' THEN NULL
                        ELSE last_seen_at::timestamptz
                    END
                );
            RAISE NOTICE 'Da doi devices.last_seen_at sang TIMESTAMPTZ.';
        END IF;
    END $$;
    """,
    "ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS profile TEXT DEFAULT 'shared'",
    'ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS owner_user_id TEXT',
    'ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS owner_user_name TEXT',
    'ALTER TABLE enrollment_tokens ADD COLUMN IF NOT EXISTS session_max_hours INT',
    # Phase 5 columns on existing tables
    'ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS color TEXT',
    'ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS label JSONB',
    'ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS icon TEXT',
    'ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 100',
    'ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS is_seed INT DEFAULT 0',
    'ALTER TABLE departments ADD COLUMN IF NOT EXISTS is_seed INT DEFAULT 0',
    'ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS is_seed INT DEFAULT 0',
]

# ── Phase 1: Nền tảng: Audit, RLS, Tenant isolation & Text Search ─────────────
DOMAIN_TABLES = [
    "tasks",
    "mushroom_jobs",
    "grow_rooms",
    "mushroom_job_types",
    "mushroom_attendance_events",
    "mushroom_daily_timesheets",
    "mushroom_break_policies",
    "mushroom_shifts",
    "mushroom_payroll_calculations",
    "mushroom_job_safety_configs",
    "mushroom_safety_checkin_logs",
    "picker_teams",
    "departments",
    "chat_messages",
]

PHASE1_STATEMENTS = [
    "CREATE EXTENSION IF NOT EXISTS unaccent",
    """
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'vi') THEN
            CREATE TEXT SEARCH CONFIGURATION vi (COPY = simple);
            ALTER TEXT SEARCH CONFIGURATION vi
                ALTER MAPPING FOR hword, hword_part, word
                WITH unaccent, simple;
        END IF;
    END $$;
    """,
]

for tbl in DOMAIN_TABLES:
    PHASE1_STATEMENTS.extend([
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default'",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS created_by TEXT",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now()",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS updated_by TEXT",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS last_mutation_id TEXT",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ",
        f"ALTER TABLE {tbl} ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE",
        f"CREATE INDEX IF NOT EXISTS idx_{tbl}_tenant_id ON {tbl}(tenant_id, id)",
        f"ALTER TABLE {tbl} ENABLE ROW LEVEL SECURITY",
        f"""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_policies WHERE tablename = '{tbl}' AND policyname = 'tenant_isolation_policy'
            ) THEN
                CREATE POLICY tenant_isolation_policy ON {tbl}
                USING (
                    current_setting('app.tenant_id', true) IS NULL
                    OR current_setting('app.tenant_id', true) = ''
                    OR current_setting('app.tenant_id', true) = '*'
                    OR tenant_id = current_setting('app.tenant_id', true)
                )
                WITH CHECK (
                    current_setting('app.tenant_id', true) IS NULL
                    OR current_setting('app.tenant_id', true) = ''
                    OR current_setting('app.tenant_id', true) = '*'
                    OR tenant_id = current_setting('app.tenant_id', true)
                );
            END IF;
        END $$;
        """,
    ])


# ── Phase 2: Module System, Tenant Modules & Model Registry (Q2) ─────────────
PHASE2_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS tenant_modules (
        tenant_id    TEXT NOT NULL,
        module_name  TEXT NOT NULL,
        version      TEXT NOT NULL,
        enabled      BOOLEAN NOT NULL DEFAULT TRUE,
        installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        settings     JSONB NOT NULL DEFAULT '{}',
        PRIMARY KEY (tenant_id, module_name)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS model_registry (
        tenant_id     TEXT NOT NULL,
        model_name    TEXT NOT NULL,
        module_name   TEXT NOT NULL,
        table_name    TEXT NOT NULL,
        label         JSONB NOT NULL,
        is_syncable   BOOLEAN NOT NULL DEFAULT TRUE,
        PRIMARY KEY (tenant_id, model_name)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS field_registry (
        tenant_id     TEXT NOT NULL,
        model_name    TEXT NOT NULL,
        field_name    TEXT NOT NULL,
        data_type     TEXT NOT NULL,
        is_required   BOOLEAN NOT NULL DEFAULT FALSE,
        is_custom     BOOLEAN NOT NULL DEFAULT FALSE,
        label         JSONB NOT NULL,
        enum_values   JSONB,
        ui            JSONB NOT NULL DEFAULT '{}',
        PRIMARY KEY (tenant_id, model_name, field_name)
    )
    """,
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
        # Phase 1 statements (Audit, RLS, Text Search)
        for stmt in PHASE1_STATEMENTS:
            try:
                conn.execute(stmt)
            except Exception as e:
                print(f"⚠️  [PG] Bỏ qua PHASE1: {e}")
        # Phase 2 statements (Module System & Model Registry)
        for stmt in PHASE2_STATEMENTS:
            try:
                conn.execute(stmt)
            except Exception as e:
                print(f"⚠️  [PG] Bỏ qua PHASE2: {e}")
        # Ensure default break policy exists
        try:
            conn.execute(
                "INSERT INTO mushroom_break_policies (id, standard_break_minutes, grace_minutes, extra_break_rule) "
                "VALUES ('default_policy', 30, 5, 'unpaid') ON CONFLICT (id) DO NOTHING"
            )
        except Exception:
            pass
        conn.commit()
    print("🐘 [PG] Schema PostgreSQL và cấu hình Phase 1 + Phase 2 đã sẵn sàng.")


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

