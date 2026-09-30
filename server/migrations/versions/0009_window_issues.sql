-- Migration 0009: Mushroom Window Issues (Window Action & Grow Room 3D Alerts)
-- Supports synchronization of Window Action (Log issue) between PC, iPad, and Android clients

CREATE TABLE IF NOT EXISTS mushroom_window_issues (
    id               TEXT PRIMARY KEY,
    room_name        TEXT NOT NULL,
    rack_index       INT DEFAULT 0,
    level_index      INT DEFAULT 0,
    window_index     INT DEFAULT 0,
    window_code      TEXT NOT NULL,
    category         TEXT NOT NULL,
    title            TEXT NOT NULL,
    description      TEXT,
    severity         TEXT DEFAULT 'normal',
    reporter_name    TEXT,
    status           TEXT DEFAULT 'open',
    temperature      REAL DEFAULT 19.0,
    humidity         REAL DEFAULT 90.0,
    co2              REAL DEFAULT 1150.0,
    casing_temp      REAL DEFAULT 19.5,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_win_issues_room ON mushroom_window_issues(room_name, status);
CREATE INDEX IF NOT EXISTS idx_win_issues_tenant_id ON mushroom_window_issues(tenant_id, id);

ALTER TABLE mushroom_window_issues ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_window_issues' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_window_issues
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
