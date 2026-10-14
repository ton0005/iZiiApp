import sqlite3
import os
import sys

server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if server_dir not in sys.path:
    sys.path.insert(0, server_dir)

def inspect_sqlite(db_path: str):
    if not os.path.exists(db_path):
        print(f"[-] SQLite file does not exist: {db_path}")
        return
    print(f"\n==========================================")
    print(f"Inspecting SQLite DB: {db_path}")
    print(f"Size: {os.path.getsize(db_path)} bytes")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
    print(f"Tables ({len(tables)}): {', '.join(sorted(tables))}")

    # Check sync_mutations
    if "sync_mutations" in tables:
        rows = cur.execute('SELECT "table", count(*) FROM sync_mutations GROUP BY "table"').fetchall()
        print("\n  sync_mutations breakdown:")
        for r in rows:
            print(f"    {r[0]}: {r[1]} rows")
        
        # Check safety mutations
        for t in ["mushroom_job_safety_configs", "mushroom_safety_checkin_logs"]:
            m_rows = cur.execute('SELECT id, data FROM sync_mutations WHERE "table" = ?', (t,)).fetchall()
            if m_rows:
                print(f"\n  Mutations for {t} ({len(m_rows)}):")
                import json
                for mid, dstr in m_rows:
                    try:
                        d = json.loads(dstr) if dstr else {}
                        jid = d.get("job_id") or d.get("jobId")
                        wid = d.get("worker_id") or d.get("workerId")
                        print(f"    - id={d.get('id') or mid}, job_id={repr(jid)}, worker_id={repr(wid)}")
                    except Exception as e:
                        print(f"    - parse error: {e}")

    # Check job_safety_configs
    cfg_table = None
    for name in ["mushroom_job_safety_configs", "job_safety_configs"]:
        if name in tables:
            cfg_table = name
            break
    if cfg_table:
        total = cur.execute(f"SELECT count(*) FROM {cfg_table}").fetchone()[0]
        missing = cur.execute(f"SELECT count(*) FROM {cfg_table} WHERE job_id IS NULL OR job_id = ''").fetchone()[0]
        print(f"\n  {cfg_table}: Total={total}, missing job_id (NULL or ''): {missing}")
        if missing > 0:
            for row in cur.execute(f"SELECT id, job_id FROM {cfg_table} WHERE job_id IS NULL OR job_id = '' LIMIT 5").fetchall():
                print(f"    - id: {row[0]}, job_id: {repr(row[1])}")

    # Check safety_checkin_logs
    log_table = None
    for name in ["mushroom_safety_checkin_logs", "safety_checkin_logs"]:
        if name in tables:
            log_table = name
            break
    if log_table:
        total = cur.execute(f"SELECT count(*) FROM {log_table}").fetchone()[0]
        missing_job = cur.execute(f"SELECT count(*) FROM {log_table} WHERE job_id IS NULL OR job_id = ''").fetchone()[0]
        missing_worker = cur.execute(f"SELECT count(*) FROM {log_table} WHERE worker_id IS NULL OR worker_id = ''").fetchone()[0]
        print(f"\n  {log_table}: Total={total}, missing job_id: {missing_job}, missing worker_id: {missing_worker}")
        if missing_job > 0:
            for row in cur.execute(f"SELECT id, job_id, worker_id FROM {log_table} WHERE job_id IS NULL OR job_id = '' LIMIT 5").fetchall():
                print(f"    - id: {row[0]}, job_id: {repr(row[1])}, worker_id: {repr(row[2])}")

    # Check tasks (ghost rows)
    if "tasks" in tables:
        total = cur.execute("SELECT count(*) FROM tasks").fetchone()[0]
        ghost = cur.execute("SELECT count(*) FROM tasks WHERE (title IS NULL OR title = 'Untitled Task' OR title = '') AND (project_id IS NULL OR project_id = '')").fetchone()[0]
        print(f"\n  tasks: Total={total}, ghost tasks: {ghost}")

    # Check mushroom_jobs (empty jobs)
    if "mushroom_jobs" in tables:
        total = cur.execute("SELECT count(*) FROM mushroom_jobs").fetchone()[0]
        empty = cur.execute("SELECT count(*) FROM mushroom_jobs WHERE (room_id IS NULL OR room_id = '') AND (job_type IS NULL OR job_type = '')").fetchone()[0]
        print(f"\n  mushroom_jobs: Total={total}, empty jobs: {empty}")

    conn.close()

def inspect_postgres():
    try:
        from server_config import CONFIG
        from db_postgres import pg_connection
        print(f"\n==========================================")
        print(f"Inspecting Postgres DB: {CONFIG.pg_dsn}")
        with pg_connection() as conn:
            rows = conn.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'").fetchall()
            tables = [r["table_name"] for r in rows]
            print(f"Tables ({len(tables)}): {', '.join(sorted(tables))}")

            if "sync_mutations" in tables:
                m_rows = conn.execute('SELECT "table", count(*) AS cnt FROM sync_mutations GROUP BY "table"').fetchall()
                print("\n  sync_mutations breakdown:")
                for r in m_rows:
                    print(f"    {r['table']}: {r['cnt']} rows")

            for cfg_table in ["mushroom_job_safety_configs", "job_safety_configs"]:
                if cfg_table in tables:
                    total = conn.execute(f"SELECT count(*) AS cnt FROM {cfg_table}").fetchone()["cnt"]
                    missing = conn.execute(f"SELECT count(*) AS cnt FROM {cfg_table} WHERE job_id IS NULL OR job_id = ''").fetchone()["cnt"]
                    print(f"\n  {cfg_table}: Total={total}, missing job_id: {missing}")

            for log_table in ["mushroom_safety_checkin_logs", "safety_checkin_logs"]:
                if log_table in tables:
                    total = conn.execute(f"SELECT count(*) AS cnt FROM {log_table}").fetchone()["cnt"]
                    missing_job = conn.execute(f"SELECT count(*) AS cnt FROM {log_table} WHERE job_id IS NULL OR job_id = ''").fetchone()["cnt"]
                    missing_worker = conn.execute(f"SELECT count(*) AS cnt FROM {log_table} WHERE worker_id IS NULL OR worker_id = ''").fetchone()["cnt"]
                    print(f"\n  {log_table}: Total={total}, missing job_id: {missing_job}, missing worker_id: {missing_worker}")

            if "tasks" in tables:
                total = conn.execute("SELECT count(*) AS cnt FROM tasks").fetchone()["cnt"]
                ghost = conn.execute("SELECT count(*) AS cnt FROM tasks WHERE (title IS NULL OR title = 'Untitled Task' OR title = '') AND (project_id IS NULL OR project_id = '')").fetchone()["cnt"]
                print(f"\n  tasks: Total={total}, ghost tasks: {ghost}")

            if "mushroom_jobs" in tables:
                total = conn.execute("SELECT count(*) AS cnt FROM mushroom_jobs").fetchone()["cnt"]
                empty = conn.execute("SELECT count(*) AS cnt FROM mushroom_jobs WHERE (room_id IS NULL OR room_id = '') AND (job_type IS NULL OR job_type = '')").fetchone()["cnt"]
                print(f"\n  mushroom_jobs: Total={total}, empty jobs: {empty}")
    except Exception as e:
        import traceback
        print(f"[-] Postgres inspect failed: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    db_paths = [
        "data/iziiapp.db",
        "../data/izii_app_db.sqlite",
        "../dist/data/iziiapp.db",
        "../_reset_backup_20260803-130428/data.e0a240/iziiapp.db",
        "../build/windows/x64/runner/Release V1.0.37/server/dist/izii_server/data/iziiapp.db",
        "C:/Users/CHANH/AppData/Local/iZiiApp/server/iziiapp.db",
        "C:/Users/CHANH/AppData/Local/iZiiApp/server/iziiapp.db.backup-20260815-001901",
    ]
    for p in db_paths:
        inspect_sqlite(p)
    inspect_postgres()
