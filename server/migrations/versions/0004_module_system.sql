-- Migration 0004: Module System, Tenant Modules & Model Registry (Phase 2)
CREATE TABLE IF NOT EXISTS tenant_modules (
    tenant_id    TEXT NOT NULL,
    module_name  TEXT NOT NULL,
    version      TEXT NOT NULL,
    enabled      BOOLEAN NOT NULL DEFAULT TRUE,
    installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settings     JSONB NOT NULL DEFAULT '{}',
    PRIMARY KEY (tenant_id, module_name)
);

CREATE TABLE IF NOT EXISTS model_registry (
    tenant_id     TEXT NOT NULL,
    model_name    TEXT NOT NULL,
    module_name   TEXT NOT NULL,
    table_name    TEXT NOT NULL,
    label         JSONB NOT NULL,
    is_syncable   BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (tenant_id, model_name)
);

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
);
