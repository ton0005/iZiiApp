-- Migration 0003: Audit Fields, Tenant Isolation & Row Level Security
-- Adds: tenant_id, created_by, created_at, updated_by, updated_at, last_mutation_id, last_seq, deleted_at, is_seed
-- Enables RLS & unaccent full-text search 'vi'

CREATE TABLE IF NOT EXISTS schema_migration_lock (
    id INT PRIMARY KEY DEFAULT 1,
    locked_at TEXT
);

CREATE EXTENSION IF NOT EXISTS unaccent;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'vi') THEN
        CREATE TEXT SEARCH CONFIGURATION vi (COPY = simple);
        ALTER TEXT SEARCH CONFIGURATION vi
            ALTER MAPPING FOR hword, hword_part, word
            WITH unaccent, simple;
    END IF;
END $$;

-- ── Apply Audit Columns & RLS Policy for all 14 Domain Tables ────────────────

-- 1. tasks
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_id ON tasks(tenant_id, id);
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'tasks' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON tasks
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

-- 2. mushroom_jobs
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_jobs ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_jobs_tenant_id ON mushroom_jobs(tenant_id, id);
ALTER TABLE mushroom_jobs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_jobs' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_jobs
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

-- 3. grow_rooms
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE grow_rooms ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_grow_rooms_tenant_id ON grow_rooms(tenant_id, id);
ALTER TABLE grow_rooms ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'grow_rooms' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON grow_rooms
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

-- 4. mushroom_job_types
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_job_types ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_job_types_tenant_id ON mushroom_job_types(tenant_id, id);
ALTER TABLE mushroom_job_types ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_job_types' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_job_types
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

-- 5. mushroom_attendance_events
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_attendance_events ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_attendance_events_tenant_id ON mushroom_attendance_events(tenant_id, id);
ALTER TABLE mushroom_attendance_events ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_attendance_events' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_attendance_events
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

-- 6. mushroom_daily_timesheets
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_daily_timesheets ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_daily_timesheets_tenant_id ON mushroom_daily_timesheets(tenant_id, id);
ALTER TABLE mushroom_daily_timesheets ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_daily_timesheets' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_daily_timesheets
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

-- 7. mushroom_break_policies
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_break_policies ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_break_policies_tenant_id ON mushroom_break_policies(tenant_id, id);
ALTER TABLE mushroom_break_policies ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_break_policies' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_break_policies
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

-- 8. mushroom_shifts
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_shifts ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_shifts_tenant_id ON mushroom_shifts(tenant_id, id);
ALTER TABLE mushroom_shifts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_shifts' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_shifts
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

-- 9. mushroom_payroll_calculations
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_payroll_calculations ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_payroll_calculations_tenant_id ON mushroom_payroll_calculations(tenant_id, id);
ALTER TABLE mushroom_payroll_calculations ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_payroll_calculations' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_payroll_calculations
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

-- 10. mushroom_job_safety_configs
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_job_safety_configs ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_job_safety_configs_tenant_id ON mushroom_job_safety_configs(tenant_id, id);
ALTER TABLE mushroom_job_safety_configs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_job_safety_configs' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_job_safety_configs
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

-- 11. mushroom_safety_checkin_logs
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE mushroom_safety_checkin_logs ADD COLUMN IF NOT EXISTS is_seed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_mushroom_safety_checkin_logs_tenant_id ON mushroom_safety_checkin_logs(tenant_id, id);
ALTER TABLE mushroom_safety_checkin_logs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'mushroom_safety_checkin_logs' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON mushroom_safety_checkin_logs
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

-- 12. picker_teams
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE picker_teams ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_picker_teams_tenant_id ON picker_teams(tenant_id, id);
ALTER TABLE picker_teams ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'picker_teams' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON picker_teams
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

-- 13. departments
ALTER TABLE departments ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE departments ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE departments ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE departments ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE departments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE departments ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE departments ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE departments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_departments_tenant_id ON departments(tenant_id, id);
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'departments' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON departments
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

-- 14. chat_messages
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS updated_by TEXT;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS last_seq BIGINT NOT NULL DEFAULT 0;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_chat_messages_tenant_id ON chat_messages(tenant_id, id);
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'chat_messages' AND policyname = 'tenant_isolation_policy') THEN
        CREATE POLICY tenant_isolation_policy ON chat_messages
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
