# server/seeds/seed_loader.py
"""
Declarative Seed Framework for iZiiServer (Phase 1 - P1.3).

Features:
- Loads seed records from server/seeds/data/*.json
- Supports noupdate flag: never overwrites existing customer-modified records
- Marks inserted seed rows with is_seed = TRUE (or 1)
- Supports both PostgreSQL and SQLite
"""
from __future__ import annotations

import os
import sys
import json
import argparse
from datetime import datetime, timezone
from typing import Dict, Any, List

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from server_config import CONFIG

SEEDS_DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

FILE_TO_TABLE = {
    "break_policies.json": "mushroom_break_policies",
    "job_types.json":      "mushroom_job_types",
    "departments.json":    "departments",
}


def load_seeds(force_update: bool = False) -> Dict[str, Dict[str, int]]:
    backend = CONFIG.db_backend
    results = {}

    if not os.path.exists(SEEDS_DATA_DIR):
        return results

    if backend == "postgres":
        from db_postgres import pg_connection
        with pg_connection() as conn:
            for filename, table in FILE_TO_TABLE.items():
                filepath = os.path.join(SEEDS_DATA_DIR, filename)
                if not os.path.exists(filepath):
                    continue

                with open(filepath, "r", encoding="utf-8-sig") as f:
                    items = json.load(f)

                inserted, updated, skipped = 0, 0, 0
                for item in items:
                    item_id = item["id"]
                    noupdate = item.get("noupdate", False)

                    # Check if already exists
                    cur = conn.execute(f"SELECT is_seed FROM {table} WHERE id = %s", (item_id,))
                    row = cur.fetchone()

                    if row is not None:
                        is_seed = row["is_seed"] if isinstance(row, dict) else row[0]
                        if not is_seed:
                            conn.execute(f"UPDATE {table} SET is_seed = TRUE WHERE id = %s", (item_id,))
                            is_seed = True
                        # If record exists and noupdate is True, skip updating business fields!
                        if noupdate and not force_update:
                            skipped += 1
                            continue
                        else:
                            # Update seed fields
                            fields = [k for k in item.keys() if k not in ("id", "noupdate")]
                            if fields:
                                set_clause = ", ".join([f"{f} = %s" for f in fields])
                                values = [item[f] for f in fields] + [item_id]
                                conn.execute(f"UPDATE {table} SET {set_clause} WHERE id = %s", values)
                                updated += 1
                    else:
                        # Insert with is_seed = 1
                        clean_item = {k: v for k, v in item.items() if k != "noupdate"}
                        clean_item["is_seed"] = 1
                        cols = list(clean_item.keys())
                        placeholders = ", ".join(["%s"] * len(cols))
                        col_names = ", ".join(cols)
                        values = [clean_item[c] for c in cols]
                        conn.execute(
                            f"INSERT INTO {table} ({col_names}) VALUES ({placeholders})",
                            values,
                        )
                        inserted += 1

                conn.commit()
                results[table] = {"inserted": inserted, "updated": updated, "skipped": skipped}

    else:
        from database import get_db_connection
        conn = get_db_connection()
        try:
            cur = conn.cursor()
            for filename, table in FILE_TO_TABLE.items():
                filepath = os.path.join(SEEDS_DATA_DIR, filename)
                if not os.path.exists(filepath):
                    continue

                with open(filepath, "r", encoding="utf-8-sig") as f:
                    items = json.load(f)

                inserted, updated, skipped = 0, 0, 0
                for item in items:
                    item_id = item["id"]
                    noupdate = item.get("noupdate", False)

                    cur.execute(f"SELECT is_seed FROM {table} WHERE id = ?", (item_id,))
                    row = cur.fetchone()

                    if row is not None:
                        is_seed = row[0]
                        if not is_seed:
                            cur.execute(f"UPDATE {table} SET is_seed = 1 WHERE id = ?", (item_id,))
                            is_seed = 1
                        if noupdate and not force_update:
                            skipped += 1
                            continue
                        else:
                            fields = [k for k in item.keys() if k not in ("id", "noupdate")]
                            if fields:
                                set_clause = ", ".join([f"{f} = ?" for f in fields])
                                values = [item[f] for f in fields] + [item_id]
                                cur.execute(f"UPDATE {table} SET {set_clause} WHERE id = ?", values)
                                updated += 1
                    else:
                        clean_item = {k: v for k, v in item.items() if k != "noupdate"}
                        clean_item["is_seed"] = 1
                        cols = list(clean_item.keys())
                        placeholders = ", ".join(["?"] * len(cols))
                        col_names = ", ".join(cols)
                        values = [clean_item[c] for c in cols]
                        cur.execute(
                            f"INSERT INTO {table} ({col_names}) VALUES ({placeholders})",
                            values,
                        )
                        inserted += 1

                conn.commit()
                results[table] = {"inserted": inserted, "updated": updated, "skipped": skipped}
        finally:
            conn.close()

    return results


def main():
    parser = argparse.ArgumentParser(description="iZiiServer Declarative Seed Loader")
    parser.add_argument("--load", action="store_true", help="Load seed records")
    parser.add_argument("--force", action="store_true", help="Force update even if modified")
    args = parser.parse_args()

    print(f"⚙️  DB Backend: {CONFIG.db_backend}")
    print("Loading declarative seeds...")
    res = load_seeds(force_update=args.force)
    for table, counts in res.items():
        print(f"  [{table}]: inserted={counts['inserted']}, updated={counts['updated']}, skipped={counts['skipped']}")
    print("✅ Seed loading finished.")


if __name__ == "__main__":
    main()
