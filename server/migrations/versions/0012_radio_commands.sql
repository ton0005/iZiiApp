-- Migration 0012: commands from iZiiApp to Hytera radios (via radio_bridge)
-- Query/enable Lone Worker on a radio, text message on Alone Worker timeout.
-- SQLite creates the same objects in db_init.py.

CREATE TABLE IF NOT EXISTS radio_commands (
    id            TEXT PRIMARY KEY,
    radio_id      TEXT NOT NULL,
    command       TEXT NOT NULL,
    params        TEXT,
    status        TEXT NOT NULL,
    dedup_key     TEXT UNIQUE,
    reason        TEXT,
    job_id        TEXT,
    attempts      INTEGER DEFAULT 0,
    created_at    TEXT NOT NULL,
    created_by    TEXT,
    sent_at       TEXT,
    done_at       TEXT,
    result        TEXT,
    error         TEXT
);

CREATE INDEX IF NOT EXISTS idx_radio_commands_status ON radio_commands(status, created_at);
CREATE INDEX IF NOT EXISTS idx_radio_commands_radio ON radio_commands(radio_id, created_at);

ALTER TABLE radio_devices ADD COLUMN IF NOT EXISTS lone_worker_state TEXT;
ALTER TABLE radio_devices ADD COLUMN IF NOT EXISTS lone_worker_checked_at TEXT;
