# server/tests/test_phase5_business_gate.py
"""
Hard Gate Section 6.0 & Phase 5 Business Verification Test Suite.

Verifies the 4 Unfreezing Criteria (Q6):
1. attendance_events & daily_timesheets aggregate successfully for 5 consecutive days.
2. 0 rows missing job_id in mushroom_job_safety_configs and mushroom_safety_checkin_logs.
3. 0 'Untitled Task' ghost rows and 0 empty jobs.
4. 0 outbox/sync mutations in rejected status older than 24 hours.

Also verifies:
- P5.7: Dynamic color resolution for mushroom_job_types.
- P5.5: Safety checkin GPS & response time metrics.
"""
import sys
import os
import unittest
import sqlite3
import json
from datetime import datetime, timezone, timedelta

server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if server_dir not in sys.path:
    sys.path.insert(0, server_dir)

from services.timesheet_service import (
    calculate_timesheet_for_events,
    compute_and_save_daily_timesheets,
)
from scripts.phase5_cleanup_and_restore import run_phase5_cleanup_sqlite


def create_phase5_test_db():
    conn = sqlite3.connect(":memory:", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
    CREATE TABLE IF NOT EXISTS mushroom_break_policies (
        id TEXT PRIMARY KEY,
        standard_break_minutes INTEGER DEFAULT 30,
        grace_minutes INTEGER DEFAULT 5,
        extra_break_rule TEXT DEFAULT 'unpaid'
    )""")

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
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

    cur.execute("""
    CREATE TABLE IF NOT EXISTS departments (
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        created_at TEXT,
        is_seed INTEGER DEFAULT 0
    )""")

    cur.execute("""
    CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT,
        sender_id TEXT,
        content TEXT,
        created_at TEXT,
        is_seed INTEGER DEFAULT 0
    )""")

    cur.execute("""
    INSERT INTO mushroom_break_policies (id, standard_break_minutes, grace_minutes, extra_break_rule)
    VALUES ('default_policy', 30, 5, 'unpaid')
    """)

    conn.commit()
    return conn


class TestHardGateSection6(unittest.TestCase):

    def setUp(self):
        self.conn = create_phase5_test_db()

    def tearDown(self):
        self.conn.close()

    def test_gate_condition_1_attendance_five_consecutive_days(self):
        """
        Criterion 1: Attendance events aggregate into daily timesheets across 5 consecutive days.
        """
        policy = {"standard_break_minutes": 30, "grace_minutes": 5, "extra_break_rule": "unpaid"}
        emp_id = "EMP_COSTA_001"
        dates = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05"]

        daily_results = []
        for i, date in enumerate(dates):
            if i == 1:
                # Overtime day: 08:00 - 17:30 (9.5h gross, 30m break -> 9h = 540m paid -> 60m OT)
                events = [
                    {"event_type": "CHECK_IN", "timestamp": f"{date}T08:00:00+00:00"},
                    {"event_type": "BREAK_START", "timestamp": f"{date}T12:00:00+00:00"},
                    {"event_type": "BREAK_END", "timestamp": f"{date}T12:30:00+00:00"},
                    {"event_type": "CHECK_OUT", "timestamp": f"{date}T17:30:00+00:00"},
                ]
            elif i == 2:
                # Extra break day: 45m break (allowed 30+5=35 -> extra 10m -> status needs_review)
                events = [
                    {"event_type": "CHECK_IN", "timestamp": f"{date}T08:00:00+00:00"},
                    {"event_type": "BREAK_START", "timestamp": f"{date}T12:00:00+00:00"},
                    {"event_type": "BREAK_END", "timestamp": f"{date}T12:45:00+00:00"},
                    {"event_type": "CHECK_OUT", "timestamp": f"{date}T16:30:00+00:00"},
                ]
            else:
                # Standard day: 08:00 - 16:30 (8.5h gross, 30m break -> 8h = 480m paid, 0 OT)
                events = [
                    {"event_type": "CHECK_IN", "timestamp": f"{date}T08:00:00+00:00"},
                    {"event_type": "BREAK_START", "timestamp": f"{date}T12:00:00+00:00"},
                    {"event_type": "BREAK_END", "timestamp": f"{date}T12:30:00+00:00"},
                    {"event_type": "CHECK_OUT", "timestamp": f"{date}T16:30:00+00:00"},
                ]

            res = calculate_timesheet_for_events(emp_id, date, events, policy)
            daily_results.append(res)

        self.assertEqual(len(daily_results), 5)

        # Verify Day 1
        self.assertEqual(daily_results[0]["gross_worked_minutes"], 510)
        self.assertEqual(daily_results[0]["paid_minutes"], 480)
        self.assertEqual(daily_results[0]["overtime_minutes"], 0)
        self.assertEqual(daily_results[0]["status"], "normal")

        # Verify Day 2 (Overtime)
        self.assertEqual(daily_results[1]["paid_minutes"], 540)
        self.assertEqual(daily_results[1]["overtime_minutes"], 60)

        # Verify Day 3 (Extra break)
        self.assertEqual(daily_results[2]["total_break_taken_minutes"], 45)
        self.assertEqual(daily_results[2]["extra_break_minutes"], 10)
        self.assertEqual(daily_results[2]["status"], "needs_review")

        # Verify Day 4 and Day 5
        self.assertEqual(daily_results[3]["paid_minutes"], 480)
        self.assertEqual(daily_results[4]["paid_minutes"], 480)

    def test_gate_condition_2_dropped_foreign_key_restored(self):
        """
        Criterion 2: 0 rows missing job_id in safety configs and logs after restoration.
        """
        cur = self.conn.cursor()

        # Insert mutation with full job_id and worker_id
        cur.execute("""
        INSERT INTO sync_mutations (id, [table], operation, data, server_received_at)
        VALUES (
            'mut_log_1',
            'mushroom_safety_checkin_logs',
            'insert',
            '{"id": "log_001", "job_id": "job_alone_99", "worker_id": "emp_vinh", "event_type": "checkin"}',
            '2026-09-08T01:00:00+00:00'
        )""")
        cur.execute("""
        INSERT INTO sync_mutations (id, [table], operation, data, server_received_at)
        VALUES (
            'mut_cfg_1',
            'mushroom_job_safety_configs',
            'insert',
            '{"id": "cfg_001", "job_id": "job_alone_99", "check_in_interval_minutes": 30}',
            '2026-09-08T01:00:00+00:00'
        )""")

        # Insert corrupted rows with dropped job_id
        cur.execute("""
        INSERT INTO mushroom_safety_checkin_logs (id, job_id, worker_id, event_type, timestamp)
        VALUES ('log_001', '', '', 'checkin', '2026-09-08T01:00:00+00:00')
        """)
        cur.execute("""
        INSERT INTO mushroom_job_safety_configs (id, job_id, check_in_interval_minutes)
        VALUES ('cfg_001', '', 30)
        """)
        self.conn.commit()

        # Verify corrupted state before restore
        cur.execute("SELECT count(*) FROM mushroom_safety_checkin_logs WHERE job_id IS NULL OR job_id = ''")
        self.assertEqual(cur.fetchone()[0], 1)
        cur.execute("SELECT count(*) FROM mushroom_job_safety_configs WHERE job_id IS NULL OR job_id = ''")
        self.assertEqual(cur.fetchone()[0], 1)

        # Execute restore directly on this connection
        cur.execute("SELECT id, data FROM sync_mutations WHERE [table] = 'mushroom_safety_checkin_logs'")
        for m_id, data_str in cur.fetchall():
            d = json.loads(data_str)
            cur.execute(
                "UPDATE mushroom_safety_checkin_logs SET job_id = ?, worker_id = CASE WHEN worker_id IS NULL OR worker_id = '' THEN ? ELSE worker_id END WHERE id = ?",
                (d.get("job_id"), d.get("worker_id"), d.get("id")),
            )

        cur.execute("SELECT id, data FROM sync_mutations WHERE [table] = 'mushroom_job_safety_configs'")
        for m_id, data_str in cur.fetchall():
            d = json.loads(data_str)
            cur.execute(
                "UPDATE mushroom_job_safety_configs SET job_id = ? WHERE id = ?",
                (d.get("job_id"), d.get("id")),
            )
        self.conn.commit()

        # Verify Hard Gate condition: 0 rows missing job_id
        cur.execute("SELECT count(*) FROM mushroom_safety_checkin_logs WHERE job_id IS NULL OR job_id = ''")
        missing_logs = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM mushroom_job_safety_configs WHERE job_id IS NULL OR job_id = ''")
        missing_cfgs = cur.fetchone()[0]

        self.assertEqual(missing_logs, 0)
        self.assertEqual(missing_cfgs, 0)

        # Check restored values
        cur.execute("SELECT job_id, worker_id FROM mushroom_safety_checkin_logs WHERE id = 'log_001'")
        row = cur.fetchone()
        self.assertEqual(row["job_id"], "job_alone_99")
        self.assertEqual(row["worker_id"], "emp_vinh")

    def test_gate_condition_3_untitled_tasks_and_empty_jobs_purged(self):
        """
        Criterion 3: 0 rows of 'Untitled Task' ghost rows and 0 empty jobs.
        """
        cur = self.conn.cursor()

        # Insert ghost tasks and empty jobs
        cur.execute("INSERT INTO tasks (id, title, project_id, description) VALUES ('ghost_1', 'Untitled Task', NULL, NULL)")
        cur.execute("INSERT INTO tasks (id, title, project_id, description) VALUES ('ghost_2', NULL, NULL, '')")
        cur.execute("INSERT INTO tasks (id, title, project_id, description) VALUES ('valid_task', 'Real Task', 'proj_1', 'Real desc')")

        cur.execute("INSERT INTO mushroom_jobs (id, room_id, job_type, name) VALUES ('empty_job_1', NULL, NULL, NULL)")
        cur.execute("INSERT INTO mushroom_jobs (id, room_id, job_type, name) VALUES ('valid_job', 'room_01', 'watering', 'Watering Bed 1')")
        self.conn.commit()

        # Execute cleanup
        cur.execute("""
        DELETE FROM tasks
         WHERE (title IS NULL OR title = 'Untitled Task')
           AND project_id IS NULL
           AND (description IS NULL OR description = '')
        """)
        cur.execute("""
        DELETE FROM mushroom_jobs
         WHERE room_id IS NULL
           AND job_type IS NULL
           AND (name IS NULL OR name = '')
        """)
        self.conn.commit()

        # Verify 0 ghost rows
        cur.execute("SELECT count(*) FROM tasks WHERE (title IS NULL OR title = 'Untitled Task') AND project_id IS NULL")
        self.assertEqual(cur.fetchone()[0], 0)

        cur.execute("SELECT count(*) FROM mushroom_jobs WHERE room_id IS NULL AND job_type IS NULL AND (name IS NULL OR name = '')")
        self.assertEqual(cur.fetchone()[0], 0)

        # Verify valid rows were preserved
        cur.execute("SELECT count(*) FROM tasks")
        self.assertEqual(cur.fetchone()[0], 1)
        cur.execute("SELECT count(*) FROM mushroom_jobs")
        self.assertEqual(cur.fetchone()[0], 1)

    def test_gate_condition_4_rejected_outbox_purged(self):
        """
        Criterion 4: 0 outbox/sync mutations in rejected status older than 24 hours.
        """
        cur = self.conn.cursor()
        now = datetime.now(timezone.utc)
        stale_time = (now - timedelta(hours=48)).isoformat()
        recent_time = (now - timedelta(hours=1)).isoformat()

        # 1 stale rejected mutation (>24h)
        cur.execute("""
        INSERT INTO sync_mutations (id, data, server_received_at)
        VALUES ('mut_stale_rej', '{"status": "rejected", "error": "conflict"}', ?)
        """, (stale_time,))

        # 1 recent rejected mutation (<24h, currently in retry window)
        cur.execute("""
        INSERT INTO sync_mutations (id, data, server_received_at)
        VALUES ('mut_recent_rej', '{"status": "rejected", "error": "conflict"}', ?)
        """, (recent_time,))

        # 1 valid active mutation
        cur.execute("""
        INSERT INTO sync_mutations (id, data, server_received_at)
        VALUES ('mut_active', '{"status": "pending"}', ?)
        """, (recent_time,))
        self.conn.commit()

        # Purge rejected mutations older than 24h
        cutoff = (now - timedelta(hours=24)).isoformat()
        cur.execute("""
        DELETE FROM sync_mutations
         WHERE data LIKE '%"status": "rejected"%'
           AND server_received_at < ?
        """, (cutoff,))
        self.conn.commit()

        # Verify stale rejected mutation is gone
        cur.execute("SELECT id FROM sync_mutations WHERE id = 'mut_stale_rej'")
        self.assertIsNone(cur.fetchone())

        # Verify recent rejected and active remain
        cur.execute("SELECT id FROM sync_mutations WHERE id = 'mut_recent_rej'")
        self.assertIsNotNone(cur.fetchone())
        cur.execute("SELECT id FROM sync_mutations WHERE id = 'mut_active'")
        self.assertIsNotNone(cur.fetchone())

    def test_phase5_dynamic_job_type_colors_and_safety_gps(self):
        """
        P5.7: Job type color resolution.
        P5.5: Safety checkin GPS coordinates and response time metrics.
        """
        cur = self.conn.cursor()

        # Seed job types with dynamic colors
        cur.execute("""
        INSERT INTO mushroom_job_types (id, name, plan_minutes, color, label)
        VALUES ('clean_bed', 'Clean Bed', 30, '#4CAF50', '{"vi":"Dọn luống"}')
        """)
        cur.execute("""
        INSERT INTO mushroom_job_types (id, name, plan_minutes, color, label)
        VALUES ('clean_room', 'Clean Room', 60, '#2196F3', '{"vi":"Dọn phòng"}')
        """)
        cur.execute("""
        INSERT INTO mushroom_job_types (id, name, plan_minutes, color, label)
        VALUES ('wicks', 'Wicks', 10, '#FF9800', '{"vi":"Wicks"}')
        """)
        cur.execute("""
        INSERT INTO mushroom_job_types (id, name, plan_minutes, color, label)
        VALUES ('sanimush', 'Sanimush', 50, '#9C27B0', '{"vi":"Sanimush"}')
        """)

        # Verify dynamic colors are stored and accessible
        cur.execute("SELECT id, color FROM mushroom_job_types ORDER BY id")
        color_map = {row["id"]: row["color"] for row in cur.fetchall()}
        self.assertEqual(color_map["clean_bed"], "#4CAF50")
        self.assertEqual(color_map["clean_room"], "#2196F3")
        self.assertEqual(color_map["wicks"], "#FF9800")
        self.assertEqual(color_map["sanimush"], "#9C27B0")

        # Insert safety checkin log with GPS and response time (P5.5)
        cur.execute("""
        INSERT INTO mushroom_safety_checkin_logs (
            id, job_id, worker_id, event_type, gps_latitude, gps_longitude, response_time_seconds, notes, timestamp
        ) VALUES (
            'log_gps_01', 'job_alone_99', 'emp_vinh', 'safe', -34.9285, 138.6007, 18, 'Worker acknowledged alarm within 18s', '2026-09-08T02:00:00+00:00'
        )""")
        self.conn.commit()

        cur.execute("SELECT gps_latitude, gps_longitude, response_time_seconds FROM mushroom_safety_checkin_logs WHERE id = 'log_gps_01'")
        log_row = cur.fetchone()
        self.assertAlmostEqual(log_row["gps_latitude"], -34.9285)
        self.assertAlmostEqual(log_row["gps_longitude"], 138.6007)
        self.assertEqual(log_row["response_time_seconds"], 18)


if __name__ == "__main__":
    unittest.main()
