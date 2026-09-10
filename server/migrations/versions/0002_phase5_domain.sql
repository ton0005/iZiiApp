-- Migration 0002: Phase 5 Domain Tables
-- Tables: mushroom_job_types, mushroom_attendance_events, mushroom_break_policies,
--         mushroom_daily_timesheets, mushroom_shifts, mushroom_payroll_calculations,
--         mushroom_job_safety_configs, mushroom_safety_checkin_logs,
--         grow_rooms, mushroom_jobs, tasks, picker_teams, departments, chat_messages

CREATE TABLE IF NOT EXISTS mushroom_job_types (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    plan_minutes INT DEFAULT 0,
    is_solo_job  INT DEFAULT 0,
    is_custom    INT DEFAULT 0,
    is_active    INT DEFAULT 1,
    color        TEXT,
    label        JSONB,
    icon         TEXT,
    sort_order   INT DEFAULT 100,
    created_at   TEXT
);

CREATE TABLE IF NOT EXISTS mushroom_attendance_events (
    id          TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL,
    plan_id     TEXT,
    event_type  TEXT NOT NULL,
    timestamp   TEXT NOT NULL,
    source      TEXT NOT NULL,
    location    TEXT,
    created_at  TEXT
);

CREATE INDEX IF NOT EXISTS idx_att_events_emp ON mushroom_attendance_events(employee_id, timestamp);

CREATE TABLE IF NOT EXISTS mushroom_break_policies (
    id                     TEXT PRIMARY KEY,
    standard_break_minutes INT DEFAULT 30,
    grace_minutes          INT DEFAULT 5,
    extra_break_rule       TEXT DEFAULT 'unpaid'
);

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
);

CREATE INDEX IF NOT EXISTS idx_timesheets_emp_date ON mushroom_daily_timesheets(employee_id, plan_date);

CREATE TABLE IF NOT EXISTS mushroom_shifts (
    id                  TEXT PRIMARY KEY,
    plan_id             TEXT,
    role                TEXT,
    employee_id         TEXT,
    start_time          TEXT,
    shed_room_list_json TEXT
);

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
);

CREATE TABLE IF NOT EXISTS mushroom_job_safety_configs (
    id                        TEXT PRIMARY KEY,
    job_id                    TEXT NOT NULL,
    check_in_interval_minutes INT DEFAULT 30,
    grace_period_minutes      INT DEFAULT 5,
    escalation_target         TEXT DEFAULT 'supervisor',
    auto_start_on_job_begin   INT DEFAULT 1,
    alarm_type                TEXT DEFAULT 'push_inapp',
    created_at                TEXT
);

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
);

CREATE INDEX IF NOT EXISTS idx_safety_logs_job ON mushroom_safety_checkin_logs(job_id);

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
);

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
);

CREATE TABLE IF NOT EXISTS tasks (
    id          TEXT PRIMARY KEY,
    project_id  TEXT,
    title       TEXT,
    description TEXT,
    status      TEXT,
    priority    TEXT,
    due_date    TEXT,
    created_at  TEXT
);

CREATE TABLE IF NOT EXISTS picker_teams (
    id              TEXT PRIMARY KEY,
    plan_id         TEXT,
    color_code      TEXT,
    team_leader_id  TEXT,
    headcount       INT DEFAULT 0,
    rate_estimate   REAL DEFAULT 0.0,
    member_ids_json TEXT,
    is_seed         INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS departments (
    id          TEXT PRIMARY KEY,
    name        TEXT,
    description TEXT,
    created_at  TEXT,
    is_seed     INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id              TEXT PRIMARY KEY,
    conversation_id TEXT,
    sender_id       TEXT,
    content         TEXT,
    created_at      TEXT,
    is_seed         INT DEFAULT 0
);
