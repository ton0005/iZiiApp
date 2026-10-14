# server/scripts/phase5_cleanup_and_restore.py
"""
Phase 5 - Data Cleanup and Foreign Key Restoration Script (Sections 9.1 and 9.2).

1. Restores dropped foreign keys (job_id, worker_id) from sync_mutations data.
2. Deletes 'Untitled Task' ghost rows and empty jobs.
3. Frees stale grow_rooms (updated_at < created_at or alone_timeout > 24h).
4. Tags seed data (is_seed = 1) for picker_teams, departments, chat_messages.
5. Cleans up rejected outbox mutations older than 24 hours.
"""
from __future__ import annotations

import json
import sys
import os
import sqlite3
import argparse
from datetime import datetime, timezone, timedelta

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from server_config import CONFIG


def run_phase5_cleanup_postgres() -> dict:
    from db_postgres import pg_connection
    results = {}

    with pg_connection() as conn:
        # 1. Section 9.2 Restore job_id & worker_id in mushroom_safety_checkin_logs
        cur = conn.execute("""
        UPDATE mushroom_safety_checkin_logs l
           SET job_id = COALESCE(NULLIF(l.job_id, ''), (m.data::jsonb)->>'job_id', (m.data::jsonb)->>'jobId'),
               worker_id = COALESCE(NULLIF(l.worker_id, ''), (m.data::jsonb)->>'worker_id', (m.data::jsonb)->>'workerId')
          FROM sync_mutations m
         WHERE m."table" = 'mushroom_safety_checkin_logs'
           AND (m.data::jsonb)->>'id' = l.id
           AND (l.job_id IS NULL OR l.job_id = '')
        """)
        results["safety_logs_job_id_repaired"] = cur.rowcount

        # Restore job_id in mushroom_job_safety_configs
        cur = conn.execute("""
        UPDATE mushroom_job_safety_configs c
           SET job_id = COALESCE(NULLIF(c.job_id, ''), (m.data::jsonb)->>'job_id', (m.data::jsonb)->>'jobId')
          FROM sync_mutations m
         WHERE m."table" = 'mushroom_job_safety_configs'
           AND (m.data::jsonb)->>'id' = c.id
           AND (c.job_id IS NULL OR c.job_id = '')
        """)
        results["safety_configs_job_id_repaired"] = cur.rowcount

        # 2. Section 9.1 Delete Ghost Tasks
        cur = conn.execute("""
        DELETE FROM tasks
         WHERE (title IS NULL OR title = 'Untitled Task' OR title = '')
           AND (project_id IS NULL OR project_id = '')
           AND (description IS NULL OR description = '')
        """)
        results["untitled_tasks_deleted"] = cur.rowcount

        # Delete Empty Jobs
        cur = conn.execute("""
        DELETE FROM mushroom_jobs
         WHERE (room_id IS NULL OR room_id = '')
           AND (job_type IS NULL OR job_type = '')
           AND (name IS NULL OR name = '')
        """)
        results["empty_jobs_deleted"] = cur.rowcount

        # 3. Free Stale Rooms
        now = datetime.now(timezone.utc).isoformat()
        cur = conn.execute("""
        UPDATE grow_rooms
           SET current_stage = 'idle', status = 'idle', updated_at = %s
         WHERE updated_at < created_at
            OR (current_stage = 'alone_timeout')
        """, (now,))
        results["stale_rooms_reset"] = cur.rowcount

        # 4. Mark Seed Data
        cur = conn.execute("""
        UPDATE picker_teams
           SET is_seed = 1
         WHERE (headcount = 0 OR headcount IS NULL)
           AND (member_ids_json IS NULL OR member_ids_json = '')
        """)
        results["picker_teams_seed_marked"] = cur.rowcount

        cur = conn.execute("""
        UPDATE departments
           SET is_seed = 1
         WHERE created_at < '2026-08-27'
        """)
        results["departments_seed_marked"] = cur.rowcount

        cur = conn.execute("""
        UPDATE chat_messages
           SET is_seed = 1
         WHERE created_at < '2026-08-27'
        """)
        results["chat_messages_seed_marked"] = cur.rowcount

        # 5. Outbox Rejected Mutations older than 24h
        cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
        cur = conn.execute("""
        DELETE FROM sync_mutations
         WHERE (data::jsonb)->>'status' = 'rejected'
           AND server_received_at < %s
        """, (cutoff,))
        results["sync_rejected_purged"] = cur.rowcount

        conn.commit()

    return results


def run_phase5_cleanup_sqlite(target=None) -> dict:
    should_close = False
    if target is None:
        from database import get_db_connection
        conn = get_db_connection()
        should_close = True
    elif isinstance(target, str):
        conn = sqlite3.connect(target, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        should_close = True
    else:
        conn = target

    results = {}
    try:
        cur = conn.cursor()
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]

        # 1. Restore job_id & worker_id from sync_mutations
        repaired_logs = 0
        if "mushroom_safety_checkin_logs" in tables and "sync_mutations" in tables:
            cur.execute("SELECT id, data FROM sync_mutations WHERE [table] = 'mushroom_safety_checkin_logs'")
            for m_id, data_str in cur.fetchall():
                try:
                    d = json.loads(data_str) if data_str else {}
                    job_id = d.get("job_id") or d.get("jobId")
                    worker_id = d.get("worker_id") or d.get("workerId")
                    log_id = d.get("id") or m_id
                    if job_id and log_id:
                        cur.execute(
                            "UPDATE mushroom_safety_checkin_logs "
                            "SET job_id = ?, worker_id = CASE WHEN worker_id IS NULL OR worker_id = '' THEN ? ELSE worker_id END "
                            "WHERE id = ? AND (job_id IS NULL OR job_id = '')",
                            (job_id, worker_id, log_id),
                        )
                        repaired_logs += cur.rowcount
                except Exception:
                    pass
        results["safety_logs_job_id_repaired"] = repaired_logs

        repaired_cfg = 0
        if "mushroom_job_safety_configs" in tables and "sync_mutations" in tables:
            cur.execute("SELECT id, data FROM sync_mutations WHERE [table] = 'mushroom_job_safety_configs'")
            for m_id, data_str in cur.fetchall():
                try:
                    d = json.loads(data_str) if data_str else {}
                    job_id = d.get("job_id") or d.get("jobId")
                    cfg_id = d.get("id") or m_id
                    if job_id and cfg_id:
                        cur.execute(
                            "UPDATE mushroom_job_safety_configs "
                            "SET job_id = ? WHERE id = ? AND (job_id IS NULL OR job_id = '')",
                            (job_id, cfg_id),
                        )
                        repaired_cfg += cur.rowcount
                except Exception:
                    pass
        results["safety_configs_job_id_repaired"] = repaired_cfg

        def has_col(tbl: str, col: str) -> bool:
            try:
                cols = [c[1] for c in cur.execute(f"PRAGMA table_info({tbl})").fetchall()]
                return col in cols
            except Exception:
                return False

        # 2. Ghost Tasks
        if "tasks" in tables and has_col("tasks", "title"):
            cur.execute("""
            DELETE FROM tasks
             WHERE (title IS NULL OR title = 'Untitled Task' OR title = '')
               AND (project_id IS NULL OR project_id = '')
               AND (description IS NULL OR description = '')
            """)
            results["untitled_tasks_deleted"] = cur.rowcount

        # Empty jobs
        if "mushroom_jobs" in tables and has_col("mushroom_jobs", "room_id"):
            cur.execute("""
            DELETE FROM mushroom_jobs
             WHERE (room_id IS NULL OR room_id = '')
               AND (job_type IS NULL OR job_type = '')
               AND (name IS NULL OR name = '')
            """)
            results["empty_jobs_deleted"] = cur.rowcount

        # 3. Stale rooms
        if "grow_rooms" in tables and has_col("grow_rooms", "current_stage"):
            now = datetime.now(timezone.utc).isoformat()
            cur.execute("""
            UPDATE grow_rooms
               SET current_stage = 'idle', status = 'idle', updated_at = ?
             WHERE updated_at < created_at
                OR (current_stage = 'alone_timeout')
            """, (now,))
            results["stale_rooms_reset"] = cur.rowcount

        # 4. Mark seed data
        if "picker_teams" in tables and has_col("picker_teams", "is_seed"):
            cur.execute("""
            UPDATE picker_teams
               SET is_seed = 1
             WHERE (headcount = 0 OR headcount IS NULL)
               AND (member_ids_json IS NULL OR member_ids_json = '')
            """)
            results["picker_teams_seed_marked"] = cur.rowcount

        if "departments" in tables and has_col("departments", "is_seed"):
            cur.execute("""
            UPDATE departments
               SET is_seed = 1
             WHERE created_at < '2026-08-27'
            """)
            results["departments_seed_marked"] = cur.rowcount

        if "chat_messages" in tables and has_col("chat_messages", "is_seed"):
            cur.execute("""
            UPDATE chat_messages
               SET is_seed = 1
             WHERE created_at < '2026-08-27'
            """)
            results["chat_messages_seed_marked"] = cur.rowcount

        # 5. Outbox rejected mutations
        if "sync_mutations" in tables:
            cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
            cur.execute("""
            DELETE FROM sync_mutations
             WHERE data LIKE '%"status": "rejected"%'
               AND server_received_at < ?
            """, (cutoff,))
            results["sync_rejected_purged"] = cur.rowcount

        conn.commit()
        return results
    finally:
        if should_close:
            conn.close()


def main():
    parser = argparse.ArgumentParser(description="Phase 5 Data Cleanup and Restoration")
    parser.add_argument("--sqlite-path", help="Target a specific SQLite database file to clean")
    parser.add_argument("--all", action="store_true", help="Clean Postgres and all discovered SQLite databases")
    args = parser.parse_args()

    print('===========================================================')
    print('*** iZiiServer Phase 5 - Data Cleanup and Restoration ***')
    print('===========================================================')

    if args.sqlite_path:
        print(f"\n--- Cleaning specific SQLite DB: {args.sqlite_path} ---")
        res = run_phase5_cleanup_sqlite(args.sqlite_path)
        for k, v in res.items():
            print(f'  - {k}: {v}')
        print('\n[SUCCESS] Phase 5 Cleanup completed for targeted SQLite DB!')
        return

    print(f'Configured DB Backend: {CONFIG.db_backend}')
    if CONFIG.db_backend == 'postgres':
        print("\n--- Cleaning PostgreSQL Database ---")
        res = run_phase5_cleanup_postgres()
        for k, v in res.items():
            print(f'  - {k}: {v}')
    else:
        print(f"\n--- Cleaning SQLite Database: {CONFIG.sqlite_db_path} ---")
        res = run_phase5_cleanup_sqlite()
        for k, v in res.items():
            print(f'  - {k}: {v}')

    # Also automatically discover and clean relevant SQLite DBs
    candidate_sqlite_paths = [
        "../data/izii_app_db.sqlite",
        "C:/Users/CHANH/AppData/Local/iZiiApp/server/iziiapp.db",
        "data/iziiapp.db",
    ]

    print("\n--- Cleaning Local SQLite Databases ---")
    for sp in candidate_sqlite_paths:
        if os.path.exists(sp):
            print(f"\nCleaning SQLite DB: {sp}")
            res_sp = run_phase5_cleanup_sqlite(sp)
            for k, v in res_sp.items():
                print(f'  - {k}: {v}')

    print('\n[SUCCESS] Phase 5 Cleanup and Restoration completed!')


if __name__ == '__main__':
    main()
