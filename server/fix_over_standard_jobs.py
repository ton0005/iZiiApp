# server/fix_over_standard_jobs.py
"""
Script điều chỉnh giờ hoàn thành Job (completed_at) trên PostgreSQL để không vượt quá thời gian tiêu chuẩn (Over Standard).
Đồng thời tạo sync_mutations để tự động đồng bộ xuống client (iPad, Windows PC).
Hỗ trợ cập nhật trực tiếp SQLite local nếu tồn tại.

Cách chạy:
    python fix_over_standard_jobs.py [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import uuid
from datetime import datetime, timezone, timedelta

# Đảm bảo stdout hiển thị tiếng Việt trên Windows CMD/PowerShell
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


DEFAULT_PLAN_MINUTES = {
    "filling": 60.0,
    "packup_tree": 50.0,
    "watering": 25.0,
    "clean_room": 45.0,
    "clean_bed": 35.0,
    "airing": 20.0,
    "floor_wet": 25.0,
    "prochloraz": 30.0,
    "alone_worker": 40.0,
    "special_solo": 40.0,
}


def load_env(env_path: str | None = None) -> dict[str, str]:
    if not env_path:
        server_dir = os.path.dirname(os.path.abspath(__file__))
        env_path = os.path.join(server_dir, ".env")
        if not os.path.exists(env_path):
            env_path = os.path.join(os.path.dirname(server_dir), "server", ".env")

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
        print("❌ Lỗi: Chưa cài đặt psycopg. Vui lòng chạy: pip install \"psycopg[binary]\"")
        sys.exit(1)


def parse_datetime_utc(val: str | None) -> datetime | None:
    if not val:
        return None
    val_clean = str(val).strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(val_clean)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def get_plan_minutes(job_type: str | None, is_solo: bool, plan_details_json: str | None, job_types_map: dict[str, float]) -> float:
    jt = (job_type or "").strip().lower()
    
    # Check if plan_details has custom timeLimitMinutes
    if is_solo and plan_details_json:
        try:
            details = json.loads(plan_details_json) if isinstance(plan_details_json, str) else plan_details_json
            if isinstance(details, dict):
                custom_limit = details.get("time_limit_minutes") or details.get("timeLimitMinutes")
                if custom_limit:
                    return float(custom_limit)
        except Exception:
            pass

    return job_types_map.get(jt, DEFAULT_PLAN_MINUTES.get(jt, 30.0))


def main():
    parser = argparse.ArgumentParser(description="Chỉnh sửa giờ hoàn thành Job không vượt quá Standard trên PostgreSQL")
    parser.add_argument("--dry-run", action="store_true", help="Chỉ kiểm tra và hiển thị danh sách, không lưu vào database")
    parser.add_argument("--factor", type=float, default=0.85, help="Hệ số thời gian chuẩn để gán cho Job (mặc định: 0.85, ví dụ plan 60p -> 51p)")
    parser.add_argument("--dsn", type=str, default=None, help="PostgreSQL DSN kết nối (mặc định đọc từ server/.env)")
    args = parser.parse_args()

    env_config = load_env()
    dsn = args.dsn or os.environ.get("IZIIAPP_PG_DSN") or env_config.get("IZIIAPP_PG_DSN", "postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp")
    server_id = os.environ.get("IZIIAPP_SERVER_ID") or env_config.get("IZIIAPP_SERVER_ID", "izii_main_srv")

    print("================================================================================")
    print("      IZIIAPP - CÔNG CỤ ĐIỀU CHỈNH GIỜ HOÀN THÀNH JOB (POSTGRESQL)")
    print("================================================================================")
    if args.dry_run:
        print("⚠️  CHẾ ĐỘ THỬ NGHIỆM (DRY-RUN): Không có thay đổi nào được ghi vào cơ sở dữ liệu.")
    print(f"🔗 Kết nối PostgreSQL: {dsn}")
    print()

    pg_conn = connect_postgres(dsn)
    now_utc = datetime.now(timezone.utc)
    now_iso = now_utc.isoformat()

    # 1. Tải bảng định mức thời gian job_types
    cur_jt = pg_conn.execute("SELECT id, plan_minutes FROM mushroom_job_types WHERE deleted_at IS NULL")
    job_types_map = {}
    for r in cur_jt.fetchall():
        jid = str(r["id"]).strip().lower()
        pmin = r["plan_minutes"]
        if pmin is not None:
            job_types_map[jid] = float(pmin)

    # 2. Quét các job đã hoàn thành
    cur_jobs = pg_conn.execute("""
        SELECT id, room_id, job_type, name, started_at, completed_at, created_at, 
               status, is_solo_job, on_time_override, plan_details
        FROM mushroom_jobs
        WHERE completed_at IS NOT NULL
        ORDER BY completed_at ASC
    """)
    completed_jobs = cur_jobs.fetchall()

    print(f"📊 Tổng số Job đã hoàn thành kiểm tra: {len(completed_jobs)}")
    print("-" * 80)

    over_jobs = []
    for j in completed_jobs:
        start_str = j.get("started_at") or j.get("created_at")
        end_str = j.get("completed_at")
        start_dt = parse_datetime_utc(start_str)
        end_dt = parse_datetime_utc(end_str)

        if not start_dt or not end_dt:
            continue

        is_solo = bool(j.get("is_solo_job"))
        plan_min = get_plan_minutes(j.get("job_type"), is_solo, j.get("plan_details"), job_types_map)
        actual_min = (end_dt - start_dt).total_seconds() / 60.0

        # Nếu thời gian thực hiện vượt quá thời gian định mức (hoặc vượt quá plan_min)
        if actual_min > plan_min:
            # Tính thời gian hoàn thành mới sao cho hoàn toàn hợp lệ trong mức tiêu chuẩn
            # Thời lượng mới = plan_min * factor (ví dụ 60p * 0.85 = 51p)
            target_dur_min = max(5.0, round(plan_min * args.factor, 1))
            new_end_dt = start_dt + timedelta(minutes=target_dur_min)
            new_end_iso = new_end_dt.isoformat()

            over_jobs.append({
                "job": j,
                "start_dt": start_dt,
                "old_end_dt": end_dt,
                "new_end_dt": new_end_dt,
                "new_end_iso": new_end_iso,
                "plan_min": plan_min,
                "old_actual_min": actual_min,
                "new_actual_min": target_dur_min,
            })

    if not over_jobs:
        print("🎉 Tuyệt vời! Không có Job nào bị vượt thời gian tiêu chuẩn (Over Standard).")
        pg_conn.close()
        return

    print(f"⚠️  Tìm thấy {len(over_jobs)} Job bị VƯỢT QUÁ tiêu chuẩn (Over Standard):\n")
    print(f"{'STT':<4} | {'Job ID':<36} | {'Loại Job':<12} | {'Định mức':<8} | {'Cũ (phút)':<10} | {'Mới (phút)':<10} | {'Chênh lệch'}")
    print("-" * 105)

    for idx, item in enumerate(over_jobs, start=1):
        j = item["job"]
        jid = str(j["id"])
        jtype = str(j.get("job_type") or "")
        pmin = item["plan_min"]
        old_m = item["old_actual_min"]
        new_m = item["new_actual_min"]
        diff_m = old_m - new_m
        print(f"{idx:<4} | {jid:<36} | {jtype:<12} | {pmin:<8.1f} | {old_m:<10.1f} | {new_m:<10.1f} | Giảm {diff_m:.1f}p")

    print("-" * 105)
    print()

    if args.dry_run:
        print("💡 Dry-run kết thúc. Để thực hiện điều chỉnh thật, chạy lại không có cờ --dry-run.")
        pg_conn.close()
        return

    # 3. Thực hiện cập nhật PostgreSQL trong Transaction
    print("🚀 Đang tiến hành cập nhật PostgreSQL và tạo sync mutations...")
    mutations_created = 0
    updated_jobs_count = 0

    try:
        with pg_conn.transaction():
            for item in over_jobs:
                j = item["job"]
                jid = str(j["id"])
                new_end_iso = item["new_end_iso"]

                # Cập nhật trực tiếp bảng mushroom_jobs
                pg_conn.execute("""
                    UPDATE mushroom_jobs
                    SET completed_at = %s,
                        on_time_override = TRUE,
                        updated_at = %s,
                        updated_by = 'admin_fix_script'
                    WHERE id = %s
                """, (new_end_iso, now_iso, jid))
                updated_jobs_count += 1

                # Tạo sync mutation để đồng bộ xuống iPad và PC
                mutation_id = str(uuid.uuid4())
                mutation_payload = {
                    "id": jid,
                    "completed_at": new_end_iso,
                    "on_time_override": True,
                    "updated_at": now_iso,
                }

                cur_mut = pg_conn.execute("""
                    INSERT INTO sync_mutations
                        (id, client_id, "table", operation, data, server_received_at, origin_server_id, actor_user_id, schema_version)
                    VALUES
                        (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING seq
                """, (
                    mutation_id,
                    "admin_fix_tool",
                    "mushroom_jobs",
                    "update",
                    json.dumps(mutation_payload),
                    now_iso,
                    server_id,
                    "admin",
                    1,
                ))
                row_seq = cur_mut.fetchone()
                seq = row_seq["seq"] if row_seq else None
                mutations_created += 1

        pg_conn.commit()
    except Exception as e:
        pg_conn.rollback()
        print(f"❌ Lỗi khi cập nhật PostgreSQL: {e}")
        pg_conn.close()
        sys.exit(1)

    print(f"✅ Đã cập nhật thành công {updated_jobs_count} Job trên PostgreSQL.")
    print(f"✅ Đã ghi nhận {mutations_created} bản ghi `sync_mutations` mới (sẵn sàng đẩy về client khi Pull).")

    # 4. Cập nhật trực tiếp SQLite local nếu tồn tại
    local_sqlite_path = os.path.expandvars(r"%LOCALAPPDATA%\izii_app\data\izii_app_db.sqlite")
    if os.path.exists(local_sqlite_path):
        print(f"\n🔍 Phát hiện cơ sở dữ liệu SQLite local: {local_sqlite_path}")
        try:
            sqlite_conn = sqlite3.connect(local_sqlite_path, timeout=5.0)
            with sqlite_conn:
                for item in over_jobs:
                    jid = str(item["job"]["id"])
                    new_end_epoch = int(item["new_end_dt"].timestamp())
                    now_epoch = int(now_utc.timestamp())
                    sqlite_conn.execute("""
                        UPDATE mushroom_jobs
                        SET completed_at = ?,
                            on_time_override = 1,
                            updated_at = ?
                        WHERE id = ?
                    """, (new_end_epoch, now_epoch, jid))
            sqlite_conn.close()
            print("✅ Đã cập nhật đồng bộ SQLite local thành công!")
        except Exception as e:
            print(f"⚠️  Không thể cập nhật SQLite local (có thể app đang mở): {e}")
            print("   (Không sao, app sẽ tự động cập nhật qua sync_mutations khi đồng bộ với server).")

    # 5. Xác minh lại trên PostgreSQL
    print("\n🔍 Kiểm tra lại trên PostgreSQL:")
    cur_recheck = pg_conn.execute("""
        SELECT COUNT(*) as cnt
        FROM mushroom_jobs
        WHERE completed_at IS NOT NULL
          AND on_time_override IS NOT TRUE
    """)
    # Let's count jobs where actual > plan
    cur_all = pg_conn.execute("""
        SELECT id, job_type, started_at, completed_at, created_at, is_solo_job, plan_details, on_time_override
        FROM mushroom_jobs
        WHERE completed_at IS NOT NULL
    """)
    remaining_over = 0
    for r in cur_all.fetchall():
        start_str = r.get("started_at") or r.get("created_at")
        end_str = r.get("completed_at")
        s_dt = parse_datetime_utc(start_str)
        e_dt = parse_datetime_utc(end_str)
        if s_dt and e_dt:
            p_min = get_plan_minutes(r.get("job_type"), bool(r.get("is_solo_job")), r.get("plan_details"), job_types_map)
            actual_min = (e_dt - s_dt).total_seconds() / 60.0
            override = r.get("on_time_override")
            if actual_min > p_min and not override:
                remaining_over += 1

    print(f"   - Số Job bị Over Standard còn lại: {remaining_over}")
    if remaining_over == 0:
        print("   - Trạng thái: HOÀN HẢO! 100% các Job đã nằm trong mức tiêu chuẩn On-Time.")
    print("\n================================================================================")
    print("                             HOÀN THÀNH")
    print("================================================================================")
    pg_conn.close()


if __name__ == "__main__":
    main()
