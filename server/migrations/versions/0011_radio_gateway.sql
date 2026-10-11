-- Migration 0011: Hytera radio (DMR / TETRA) integration for Alone Worker safety
-- radio_devices: which radio is issued to which employee (Radio ID / ISSI -> employee)
-- radio_events : immutable log of SOS / Man Down / Lone Worker alarms received from the
--                radio dispatch gateway (only the handling status columns are updated)
-- SQLite creates the same tables in db_init.py.

CREATE TABLE IF NOT EXISTS radio_devices (
    radio_id         TEXT PRIMARY KEY,
    system           TEXT DEFAULT 'dmr',
    model            TEXT,
    label            TEXT,
    employee_id      TEXT,
    employee_name    TEXT,
    active           INTEGER DEFAULT 1,
    last_seen_at     TEXT,
    last_event_type  TEXT,
    last_latitude    DOUBLE PRECISION,
    last_longitude   DOUBLE PRECISION,
    last_located_at  TEXT,
    last_battery     DOUBLE PRECISION,
    created_at       TEXT,
    updated_at       TEXT,
    updated_by       TEXT
);

CREATE TABLE IF NOT EXISTS radio_events (
    id               TEXT PRIMARY KEY,
    event_key        TEXT UNIQUE,
    radio_id         TEXT NOT NULL,
    system           TEXT,
    event_type       TEXT NOT NULL,
    raw_event_type   TEXT,
    is_alarm         INTEGER DEFAULT 0,
    status           TEXT NOT NULL,
    occurred_at      TEXT,
    received_at      TEXT NOT NULL,
    last_received_at TEXT,
    repeat_count     INTEGER DEFAULT 0,
    latitude         DOUBLE PRECISION,
    longitude        DOUBLE PRECISION,
    employee_id      TEXT,
    employee_name    TEXT,
    job_id           TEXT,
    room_id          TEXT,
    acked_at         TEXT,
    acked_by         TEXT,
    ack_note         TEXT,
    payload          TEXT
);

CREATE INDEX IF NOT EXISTS idx_radio_events_open ON radio_events(radio_id, event_type, status);
CREATE INDEX IF NOT EXISTS idx_radio_events_received ON radio_events(received_at);
