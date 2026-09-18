-- Migration 0005: Settings, Record Rules & Projection Checkpoint (Phase 3 & Phase 4)
-- Tables: settings, record_rules, projection_checkpoint

CREATE TABLE IF NOT EXISTS settings (
    scope       TEXT NOT NULL,            -- 'global' | 'tenant' | 'site' | 'device'
    scope_id    TEXT NOT NULL DEFAULT '', -- '' cho global
    key         TEXT NOT NULL,
    value       JSONB NOT NULL DEFAULT '{}',
    data_type   TEXT NOT NULL DEFAULT 'json',
    updated_by  TEXT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (scope, scope_id, key)
);

CREATE TABLE IF NOT EXISTS record_rules (
    tenant_id   TEXT NOT NULL,
    rule_name   TEXT NOT NULL,
    model_name  TEXT NOT NULL,
    role_key    TEXT NOT NULL,            -- 'picker' | 'supervisor' | 'manager' | '*'
    domain      JSONB NOT NULL DEFAULT '[]',
    perm_read   BOOLEAN NOT NULL DEFAULT TRUE,
    perm_write  BOOLEAN NOT NULL DEFAULT FALSE,
    enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, rule_name)
);

CREATE TABLE IF NOT EXISTS projection_checkpoint (
    projection_name    TEXT PRIMARY KEY,
    last_projected_seq BIGINT NOT NULL DEFAULT 0,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index tra cứu settings theo scope và key
CREATE INDEX IF NOT EXISTS idx_settings_scope_key ON settings(scope, scope_id, key);

-- Index tra cứu record rules theo model và role
CREATE INDEX IF NOT EXISTS idx_record_rules_model_role ON record_rules(tenant_id, model_name, role_key);
