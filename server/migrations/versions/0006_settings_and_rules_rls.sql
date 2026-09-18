-- Migration 0006: Settings & Record Rules RLS (B2)
-- Enables Row-Level Security on settings and record_rules tables
-- Table projection_checkpoint remains global/admin.

-- 1. settings table
ALTER TABLE settings ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT 'default';
CREATE INDEX IF NOT EXISTS idx_settings_tenant_id ON settings(tenant_id, scope, key);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'settings' AND policyname = 'settings_tenant_isolation_policy') THEN
        CREATE POLICY settings_tenant_isolation_policy ON settings
        USING (
            scope = 'global'
            OR current_setting('app.tenant_id', true) IS NULL
            OR current_setting('app.tenant_id', true) = ''
            OR current_setting('app.tenant_id', true) = '*'
            OR tenant_id = current_setting('app.tenant_id', true)
        )
        WITH CHECK (
            scope = 'global'
            OR current_setting('app.tenant_id', true) IS NULL
            OR current_setting('app.tenant_id', true) = ''
            OR current_setting('app.tenant_id', true) = '*'
            OR tenant_id = current_setting('app.tenant_id', true)
        );
    END IF;
END $$;

-- 2. record_rules table
ALTER TABLE record_rules ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'record_rules' AND policyname = 'record_rules_tenant_isolation_policy') THEN
        CREATE POLICY record_rules_tenant_isolation_policy ON record_rules
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
