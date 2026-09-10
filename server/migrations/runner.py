# server/migrations/runner.py
"""
Versioned Migration Runner for iZiiServer (Phase 1 - P1.2).

Features:
- Sequential migration execution from server/migrations/versions/*.sql
- Idempotency via schema_migrations registry
- Detailed reporting and status inspection
- Supports both PostgreSQL and SQLite
"""
from __future__ import annotations

import os
import sys
import argparse
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from server_config import CONFIG


VERSIONS_DIR = os.path.join(os.path.dirname(__file__), "versions")


def get_available_migrations() -> List[str]:
    if not os.path.exists(VERSIONS_DIR):
        return []
    files = [
        f for f in os.listdir(VERSIONS_DIR)
        if (f.endswith(".sql") or f.endswith(".py")) and not f.startswith("__")
    ]
    return sorted(files)


def get_applied_migrations(conn) -> set[str]:
    backend = CONFIG.db_backend
    cur = conn.cursor() if hasattr(conn, "cursor") else conn
    try:
        if backend == "postgres":
            cur.execute("SELECT name FROM schema_migrations")
        else:
            cur.execute("SELECT name FROM schema_migrations")
        rows = cur.fetchall()
        applied = set()
        for r in rows:
            name = r["name"] if isinstance(r, dict) else r[0]
            applied.add(name)
        return applied
    except Exception:
        return set()


def record_migration(conn, name: str, detail: str = "") -> None:
    backend = CONFIG.db_backend
    now = datetime.now(timezone.utc).isoformat()
    if backend == "postgres":
        conn.execute(
            "INSERT INTO schema_migrations (name, applied_at, detail) VALUES (%s, %s, %s) "
            "ON CONFLICT (name) DO UPDATE SET applied_at = EXCLUDED.applied_at",
            (name, now, detail),
        )
    else:
        conn.execute(
            "INSERT OR REPLACE INTO schema_migrations (name, applied_at, detail) VALUES (?, ?, ?)",
            (name, now, detail),
        )


def _clean_sql(content: str) -> List[str]:
    lines = []
    for line in content.splitlines():
        trimmed = line.strip()
        if trimmed.startswith("--"):
            continue
        lines.append(line)
    clean_content = "\n".join(lines)
    return [s.strip() for s in clean_content.split(";") if s.strip()]


def run_migrations() -> List[str]:
    available = get_available_migrations()
    backend = CONFIG.db_backend
    applied_now = []

    if backend == "postgres":
        from db_postgres import pg_connection
        with pg_connection() as conn:
            already_applied = get_applied_migrations(conn)
            for m in available:
                if m in already_applied:
                    continue
                file_path = os.path.join(VERSIONS_DIR, m)
                with open(file_path, "r", encoding="utf-8-sig") as f:
                    content = f.read()

                try:
                    conn.execute(content)
                except Exception as e:
                    # Fallback to statement-by-statement if needed
                    stmts = _clean_sql(content)
                    for stmt in stmts:
                        conn.execute(stmt)

                record_migration(conn, m, f"applied from {m}")
                conn.commit()
                applied_now.append(m)
                print(f"✅ [MIGRATION] Applied: {m}")
    else:
        from database import get_db_connection
        conn = get_db_connection()
        try:
            already_applied = get_applied_migrations(conn)
            for m in available:
                if m in already_applied:
                    continue
                file_path = os.path.join(VERSIONS_DIR, m)
                with open(file_path, "r", encoding="utf-8-sig") as f:
                    content = f.read()

                try:
                    conn.executescript(content)
                except Exception:
                    stmts = _clean_sql(content)
                    for stmt in stmts:
                        try:
                            conn.execute(stmt)
                        except Exception:
                            pass

                record_migration(conn, m, f"applied from {m}")
                conn.commit()
                applied_now.append(m)
                print(f"✅ [MIGRATION] Applied: {m}")
        finally:
            conn.close()

    return applied_now


def get_migration_status() -> List[Dict[str, Any]]:
    available = get_available_migrations()
    backend = CONFIG.db_backend
    status_list = []

    if backend == "postgres":
        from db_postgres import pg_connection
        with pg_connection() as conn:
            applied = get_applied_migrations(conn)
    else:
        from database import get_db_connection
        conn = get_db_connection()
        try:
            applied = get_applied_migrations(conn)
        finally:
            conn.close()

    for m in available:
        status_list.append({
            "name": m,
            "applied": m in applied,
        })
    return status_list


def main():
    parser = argparse.ArgumentParser(description="iZiiServer Migration Runner")
    parser.add_argument("--status", action="store_true", help="Show migration status")
    parser.add_argument("--migrate", action="store_true", help="Apply all pending migrations")
    args = parser.parse_args()

    print(f"⚙️  DB Backend: {CONFIG.db_backend}")
    if args.status or not args.migrate:
        print("\nMigration Status:")
        statuses = get_migration_status()
        for s in statuses:
            mark = "✅ Applied" if s["applied"] else "⏳ Pending"
            print(f"  {mark:12} {s['name']}")

    if args.migrate:
        print("\nApplying pending migrations...")
        applied = run_migrations()
        if not applied:
            print("Everything up-to-date!")
        else:
            print(f"Successfully applied {len(applied)} migration(s).")


if __name__ == "__main__":
    main()
