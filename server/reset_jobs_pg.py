# server/reset_jobs_pg.py
"""
Script reset dữ liệu Job trên PostgreSQL cho iZiiServer.
Có thể chạy trực tiếp bằng: python reset_jobs_pg.py [options]
Hoặc gọi thông qua reset_jobs_postgres.ps1.

Các việc thực hiện:
  1. Đọc cấu hình từ .env (IZIIAPP_PG_DSN).
  2. Sao lưu toàn bộ dữ liệu Job (mushroom_jobs, tasks, safety configs, checkin logs,
     và các bản ghi sync_mutations liên quan) ra file JSON backup.
  3. Xoá dữ liệu các bảng Job trên PostgreSQL.
  4. QUAN TRỌNG: Xoá các mutation tương ứng trong bảng `sync_mutations`.
     (Nếu không xoá ở sync_mutations, khi client gọi /sync/pull thì dữ liệu cũ
     sẽ tự động tái sinh).
  5. Tuỳ chọn (--include-attendance): Xoá thêm điểm danh, timesheets, shifts, payroll.
  6. Tuỳ chọn (--clean-client): Xoá dữ liệu Job trong SQLite local của app Windows
     (%LOCALAPPDATA%/izii_app/data/izii_app_db.sqlite) để client không đẩy ngược
     lên server.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone

# Ensure stdout handles UTF-8 on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def load_env(env_path: str | None = None) -> dict[str, str]:
    if not env_path:
        server_dir = os.path.dirname(os.path.abspath(__file__))
        env_path = os.path.join(server_dir, ".env")
    
    config = {}
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    config[k.strip()] = v.strip().strip("'\"")
    return config


def connect_postgres(dsn: str):
    try:
        import psycopg
        from psycopg.rows import dict_row
        return psycopg.connect(dsn, row_factory=dict_row)
    except ImportError:
        print("❌ Lỗi: Chưa cài psycopg. Hãy chạy: pip install \"psycopg[binary]\"")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Không thể kết nối tới PostgreSQL ({dsn}): {e}")
        sys.exit(1)


def reset_postgres_jobs(
    dsn: str,
    backup_dir: str,
    include_attendance: bool = False,
    dry_run: bool = False,
) -> dict[str, int]:
    print(f"\n🐘 [POSTGRES] Kết nối tới database...")
    conn = connect_postgres(dsn)
    
    job_tables = [
        "mushroom_jobs",
        "tasks",
        "mushroom_job_safety_configs",
        "mushroom_safety_checkin_logs",
    ]
    if include_attendance:
        job_tables.extend([
            "mushroom_attendance_events",
            "mushroom_daily_timesheets",
            "mushroom_shifts",
            "mushroom_payroll_calculations",
        ])

    deleted_counts: dict[str, int] = {}
    backup_data: dict[str, list] = {}

    with conn:
        with conn.cursor() as cur:
            # 1. Kiểm tra các bảng có tồn tại trong PostgreSQL không
            cur.execute(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
            )
            existing_tables = {row["table_name"] for row in cur.fetchall()}

            # 2. Sao lưu dữ liệu các bảng trước khi xoá
            print(f"📦 [BACKUP] Đang sao lưu dữ liệu các bảng Job...")
            for table in job_tables:
                if table in existing_tables:
                    cur.execute(f'SELECT * FROM "{table}"')
                    rows = cur.fetchall()
                    # Convert non-serializable objects to str
                    serializable_rows = []
                    for r in rows:
                        row_dict = {}
                        for k, v in r.items():
                            if isinstance(v, (datetime,)):
                                row_dict[k] = v.isoformat()
                            else:
                                row_dict[k] = v
                        serializable_rows.append(row_dict)
                    backup_data[table] = serializable_rows
                    print(f"   - {table}: {len(rows)} bản ghi")
                else:
                    print(f"   - {table}: [bảng không tồn tại, bỏ qua]")

            # Sao lưu các mutation liên quan trong sync_mutations
            if "sync_mutations" in existing_tables:
                placeholders = ", ".join(["%s"] * len(job_tables))
                query = f'SELECT * FROM sync_mutations WHERE "table" IN ({placeholders})'
                cur.execute(query, job_tables)
                mut_rows = cur.fetchall()
                serializable_muts = []
                for r in mut_rows:
                    row_dict = {}
                    for k, v in r.items():
                        if isinstance(v, datetime):
                            row_dict[k] = v.isoformat()
                        else:
                            row_dict[k] = v
                    serializable_muts.append(row_dict)
                backup_data["sync_mutations"] = serializable_muts
                print(f"   - sync_mutations (cho Job): {len(mut_rows)} mutations")

            # Ghi file backup
            os.makedirs(backup_dir, exist_ok=True)
            backup_file = os.path.join(backup_dir, "postgres_jobs_backup.json")
            with open(backup_file, "w", encoding="utf-8") as f:
                json.dump(backup_data, f, ensure_ascii=False, indent=2)
            print(f"✅ [BACKUP] Đã lưu file sao lưu: {backup_file}")

            if dry_run:
                print("🔍 [DRY-RUN] Bỏ qua bước xoá thực sự.")
                return {t: len(backup_data.get(t, [])) for t in job_tables}

            # 3. Xoá dữ liệu trong các bảng nghiệp vụ
            print(f"\n🔥 [DELETE] Đang xoá dữ liệu trên PostgreSQL...")
            for table in job_tables:
                if table in existing_tables:
                    cur.execute(f'DELETE FROM "{table}"')
                    cnt = cur.rowcount if cur.rowcount and cur.rowcount > 0 else 0
                    deleted_counts[table] = cnt
                    print(f"   - Đã xoá {cnt} dòng trong {table}")

            # 4. Xoá mutation trong sync_mutations (BƯỚC THEN CHỐT)
            if "sync_mutations" in existing_tables:
                placeholders = ", ".join(["%s"] * len(job_tables))
                del_mut_query = f'DELETE FROM sync_mutations WHERE "table" IN ({placeholders})'
                cur.execute(del_mut_query, job_tables)
                cnt_mut = cur.rowcount if cur.rowcount and cur.rowcount > 0 else 0
                deleted_counts["sync_mutations"] = cnt_mut
                print(f"   - Đã xoá {cnt_mut} mutations liên quan đến Job trong sync_mutations")

        conn.commit()

    # Thu hồi dung lượng
    try:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("VACUUM")
        print("🧹 [VACUUM] Đã thu hồi dung lượng database thành công.")
    except Exception as e:
        print(f"⚠️ [VACUUM] Không thể chạy VACUUM: {e}")
    finally:
        conn.close()

    return deleted_counts


def reset_client_jobs(backup_dir: str, include_attendance: bool = False, dry_run: bool = False):
    """Xoá dữ liệu Job trong SQLite local của app Windows để không bị sync ngược."""
    client_data_dir = os.path.expandvars(r"%LOCALAPPDATA%\izii_app\data")
    db_path = os.path.join(client_data_dir, "izii_app_db.sqlite")

    if not os.path.exists(db_path):
        print("ℹ️ [CLIENT] Không tìm thấy DB client Windows (%LOCALAPPDATA%/izii_app). Bỏ qua.")
        return

    print(f"\n💻 [CLIENT] Phát hiện DB local Windows tại: {db_path}")

    # Backup local SQLite
    os.makedirs(backup_dir, exist_ok=True)
    sqlite_backup = os.path.join(backup_dir, "client_izii_app_db_before_job_reset.sqlite")
    try:
        import shutil
        shutil.copy2(db_path, sqlite_backup)
        print(f"✅ [CLIENT-BACKUP] Đã sao lưu DB SQLite client: {sqlite_backup}")
    except Exception as e:
        print(f"⚠️ [CLIENT-BACKUP] Không thể sao lưu file SQLite: {e}")

    if dry_run:
        print("🔍 [DRY-RUN] Bỏ qua xoá trên Client SQLite.")
        return

    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        
        # Get existing tables
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = {r[0] for r in cur.fetchall()}

        client_job_tables = [
            "mushroom_jobs",
            "tasks",
            "mushroom_job_safety_configs",
            "mushroom_safety_checkin_logs",
        ]
        if include_attendance:
            client_job_tables.extend([
                "mushroom_attendance_events",
                "mushroom_daily_timesheets",
                "mushroom_shifts",
                "mushroom_payroll_calculations",
            ])

        for t in client_job_tables:
            if t in tables:
                cur.execute(f"DELETE FROM {t}")
                print(f"   - [CLIENT] Đã xoá {cur.rowcount} dòng trong {t}")

        # Xoá queue outbox đồng bộ nếu có
        for q_table in ["sync_outbox", "outbox_mutations", "pending_sync"]:
            if q_table in tables:
                try:
                    cur.execute(f"DELETE FROM {q_table}")
                    print(f"   - [CLIENT] Đã dọn outbox {q_table}")
                except Exception:
                    pass

        conn.commit()
        conn.close()
        print("✅ [CLIENT] Đã xoá sạch Job trên local DB của Windows app.")
    except Exception as e:
        print(f"⚠️ [CLIENT] Lỗi khi xử lý DB local: {e}")


def main():
    parser = argparse.ArgumentParser(description="Reset dữ liệu Job trên PostgreSQL cho iZiiServer")
    parser.add_argument("--dsn", default=None, help="PostgreSQL DSN (mặc định lấy từ server/.env)")
    parser.add_argument("--env-file", default=None, help="Đường dẫn file .env")
    parser.add_argument("--backup-dir", default=None, help="Thư mục chứa bản sao lưu")
    parser.add_argument("--include-attendance", action="store_true", help="Xoá cả điểm danh, ca làm và timesheets")
    parser.add_argument("--clean-client", action="store_true", help="Xoá cả dữ liệu Job trong SQLite local của Windows app")
    parser.add_argument("--dry-run", action="store_true", help="Chỉ kiểm tra và sao lưu, không xoá")

    args = parser.parse_args()

    # Load config from .env
    env = load_env(args.env_file)
    dsn = args.dsn or env.get("IZIIAPP_PG_DSN") or "postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp"

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    server_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(server_dir)
    backup_dir = args.backup_dir or os.path.join(parent_dir, f"_reset_jobs_backup_{stamp}")

    print("+" + "-" * 62 + "+")
    print("|  iZiiServer - RESET DATA JOBS TREN POSTGRESQL                |")
    print("+" + "-" * 62 + "+")
    print(f"Postgres DSN : {dsn.split('@')[-1] if '@' in dsn else dsn}")
    print(f"Backup Dir   : {backup_dir}")
    print(f"Attendance   : {'Bao gồm điểm danh & ca làm' if args.include_attendance else 'Chỉ Job & Task'}")
    print(f"Clean Client : {'Có dọn dẹp local Windows client' if args.clean_client else 'Chỉ trên Server'}")
    if args.dry_run:
        print(f"Chế độ       : DRY-RUN (không xoá)")

    # Execute postgres reset
    deleted = reset_postgres_jobs(
        dsn=dsn,
        backup_dir=backup_dir,
        include_attendance=args.include_attendance,
        dry_run=args.dry_run,
    )

    # Execute client reset if requested
    if args.clean_client:
        reset_client_jobs(
            backup_dir=backup_dir,
            include_attendance=args.include_attendance,
            dry_run=args.dry_run,
        )

    print("\n" + "=" * 64)
    print("🎉 HOÀN TẤT RESET DỮ LIỆU JOB!")
    print(f"📁 Bản sao lưu được lưu tại: {backup_dir}")
    print("=" * 64)


if __name__ == "__main__":
    main()
