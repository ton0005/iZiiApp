# server/migrate_to_postgres.py
"""
Chuyển toàn bộ dữ liệu từ SQLite sang PostgreSQL — chạy MỘT LẦN khi đổi backend.

CÁCH DÙNG
---------
1. Dựng PostgreSQL và tạo database rỗng:
       CREATE DATABASE iziiapp;
2. Đặt DSN vào .env (chưa đổi IZIIAPP_DB_BACKEND vội):
       IZIIAPP_PG_DSN=postgresql://izii:matkhau@192.168.1.50:5432/iziiapp
3. DỪNG server để không có ai ghi thêm trong lúc copy.
   (Script sẽ TỪ CHỐI chạy nếu phát hiện server còn sống — dùng --force để bỏ qua.)
4. Chạy kiểm tra thử (không ghi dữ liệu):
       python migrate_to_postgres.py --dry-run
5. Chạy migrate thật:
       python migrate_to_postgres.py
6. Kiểm tra lại đối soát:
       python migrate_to_postgres.py --verify
7. Đổi cấu hình trong .env:
       IZIIAPP_DB_BACKEND=postgres
8. Khởi động lại server.

ĐIỂM QUAN TRỌNG NHẤT: `seq`
---------------------------
Script GIỮ NGUYÊN giá trị seq cũ thay vì để BIGSERIAL cấp lại. Bắt buộc phải
vậy, vì các thiết bị và peer server đang giữ con trỏ trỏ tới những seq đó. Nếu
đánh số lại, mọi client sẽ hoặc bỏ qua dữ liệu (con trỏ cũ lớn hơn seq mới)
hoặc nhận lại toàn bộ log.

Sau khi nạp xong, script đẩy sequence của Postgres lên quá giá trị seq lớn nhất
— quên bước này thì bản ghi mới sẽ đụng khoá trùng với bản ghi cũ.

NẾU MIGRATE LỖI GIỮA CHỪNG
--------------------------
Script commit theo TỪNG BẢNG, không có transaction bao ngoài. Nếu lỗi ở bảng thứ
N thì N-1 bảng trước đã nằm trong PostgreSQL. Chạy lại là an toàn về mặt trùng
lặp (`ON CONFLICT DO NOTHING`), nhưng KHÔNG dọn được dòng thừa nếu nguyên nhân
lỗi là dữ liệu sai. Cách xử lý sạch và dứt điểm:

    DROP DATABASE iziiapp;
    CREATE DATABASE iziiapp;
    python migrate_to_postgres.py

Chỉ làm được vậy khi CHƯA đổi IZIIAPP_DB_BACKEND=postgres — tức chưa có dữ liệu
mới nào chỉ tồn tại ở PostgreSQL. Sau khi đã cutover thì phải khôi phục từ backup.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import os
import socket
import sqlite3
import sys

# Đảm bảo in tiếng Việt không bị lỗi charmap (cp1252) trên Windows console
if sys.platform == "win32":
    try:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Bảng cần chuyển và khoá chính tương ứng (dùng cho ON CONFLICT).
TABLES = [
    # Core tables
    ("sync_mutations",        "id"),
    ("known_servers",         "server_id"),
    ("devices",               "device_id"),
    ("message_queue",         "id"),
    ("notifications",         "id"),
    ("notification_settings", "user_id, event_type"),
    ("webhook_subscriptions", "id"),
    ("webhook_dead_letters",  "id"),
    ("schema_migrations",     "name"),
    ("enrollment_tokens",     "token"),
    ("device_tokens",         "device_id"),
    ("work_sessions",         "id"),
    ("employee_pins",         "user_id"),
    # Phase 5 & Domain business tables (14 tables)
    ("mushroom_job_types",           "id"),
    ("mushroom_attendance_events",    "id"),
    ("mushroom_break_policies",       "id"),
    ("mushroom_daily_timesheets",     "id"),
    ("mushroom_shifts",               "id"),
    ("mushroom_payroll_calculations", "id"),
    ("mushroom_job_safety_configs",   "id"),
    ("mushroom_safety_checkin_logs",  "id"),
    ("grow_rooms",                    "id"),
    ("mushroom_jobs",                 "id"),
    ("tasks",                         "id"),
    ("picker_teams",                  "id"),
    ("departments",                   "id"),
    ("chat_messages",                 "id"),
    # Phase 2: Module System & Model Registry (3 tables)
    ("tenant_modules",                "tenant_id, module_name"),
    ("model_registry",                "tenant_id, model_name"),
    ("field_registry",                "tenant_id, model_name, field_name"),
]

BATCH = 500

# Bảng CỐ Ý không chuyển hoặc bảng hệ thống nội bộ chỉ có ở một phía.
#   sync_sequence: bộ đếm seq thủ công của SQLite. PostgreSQL dùng BIGSERIAL nên
#                  không cần bảng này. Xem §Rollback trong plan/extend.md để biết
#                  hệ quả khi cần quay ngược về SQLite.
#   schema_migration_lock: bảng khoá migration của PostgreSQL runner.
NOT_MIGRATED = {"sync_sequence", "schema_migration_lock"}


def _check_server_running(port: int = 8080) -> bool:
    """Kiểm tra xem iZiiServer có đang chạy trên port cục bộ hay không (P1.10)."""
    try:
        from server_config import is_port_in_use
        return is_port_in_use(port)
    except Exception:
        return False


def _sqlite_columns(sconn: sqlite3.Connection, table: str) -> list[str]:
    return [r[1] for r in sconn.execute(f"PRAGMA table_info({table})").fetchall()]


def _pg_columns(pconn, table: str) -> set[str]:
    rows = pconn.execute(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_name = %s AND table_schema = 'public'",
        (table,),
    ).fetchall()
    return {_row_value(r, "column_name") for r in rows}


def _pg_column_types(pconn, table: str) -> dict[str, str]:
    rows = pconn.execute(
        "SELECT column_name, data_type FROM information_schema.columns "
        "WHERE table_name = %s AND table_schema = 'public'",
        (table,),
    ).fetchall()
    return {_row_value(r, "column_name"): _row_value(r, "data_type") for r in rows}


def _convert_val(col: str, val, target_type: str):
    """Chuyển đổi kiểu dữ liệu tương thích giữa SQLite và PostgreSQL."""
    if col in ("created_at", "updated_at") and not val:
        return datetime.now(timezone.utc).isoformat()
    if col == "tenant_id" and not val:
        return "default"
    if col == "last_seq" and val is None:
        return 0
    if col == "is_seed":
        if val is None:
            return False
        if isinstance(val, (int, str)):
            return str(val).strip().lower() in ("1", "true", "t", "yes")
        return bool(val)

    if val is None:
        return None

    if target_type == "boolean":
        if isinstance(val, (int, str)):
            return str(val).strip().lower() in ("1", "true", "t", "yes")
        return bool(val)

    return val


def _row_value(row, key: str):
    """
    Lấy giá trị từ một dòng kết quả, không phụ thuộc row_factory.

    VÌ SAO CẦN: db_postgres.py hiện ép `row_factory=dict_row` nên dòng trả về là
    dict. Nhưng KHÔNG được viết `row[key] if hasattr(row, "__getitem__") else row[0]`
    — tuple cũng có __getitem__, nên nhánh dự phòng sẽ không bao giờ chạy và
    `row["count"]` sẽ ném TypeError. Kiểm tra bằng isinstance(dict) mới đúng.
    """
    if isinstance(row, dict):
        return row[key]
    return row[0]


def _assert_table_coverage(pconn) -> None:
    """
    Mọi bảng có trong schema PostgreSQL đều PHẢI nằm trong TABLES.
    Thiếu một bảng = mất dữ liệu im lặng.
    """
    rows = pconn.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' AND table_type = 'BASE TABLE'"
    ).fetchall()
    in_pg = {_row_value(r, "table_name") for r in rows}
    in_script = {t for t, _ in TABLES}
    missing = in_pg - in_script - NOT_MIGRATED
    if missing:
        raise SystemExit(
            f"⛔ DỪNG: {len(missing)} bảng có trong schema PostgreSQL nhưng "
            f"KHÔNG nằm trong TABLES: {sorted(missing)}\n"
            f"   Bổ sung vào TABLES rồi chạy lại. Chạy tiếp = mất dữ liệu."
        )


def _assert_source_coverage(sconn: sqlite3.Connection) -> None:
    """
    Chiều NGƯỢC LẠI của _assert_table_coverage: mọi bảng có trong SQLite đều
    phải hoặc nằm trong TABLES, hoặc nằm trong NOT_MIGRATED (cố ý bỏ).

    VÌ SAO CẦN RIÊNG MỘT HÀM: _assert_table_coverage chỉ duyệt các bảng ĐANG CÓ
    ở PostgreSQL. Nếu ai thêm bảng vào db_init.py mà quên db_init_postgres.py
    thì bảng đó KHÔNG tồn tại ở PostgreSQL, KHÔNG nằm trong TABLES, và chốt kia
    không thể nhìn thấy nó — dữ liệu mất im lặng đúng như lỗi M1, chỉ đảo chiều.
    Chừng nào còn hai file schema sửa tay song song thì rủi ro này còn nguyên.
    """
    rows = sconn.execute(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
    ).fetchall()
    in_sqlite = {r[0] for r in rows}
    in_script = {t for t, _ in TABLES}
    missing = in_sqlite - in_script - NOT_MIGRATED
    if missing:
        raise SystemExit(
            f"⛔ DỪNG: {len(missing)} bảng có trong SQLite nhưng KHÔNG nằm trong "
            f"TABLES: {sorted(missing)}\n"
            f"   Nếu bảng này CẦN chuyển: thêm vào TABLES *và* vào db_init_postgres.py.\n"
            f"   Nếu CỐ Ý không chuyển: thêm vào NOT_MIGRATED kèm lý do.\n"
            f"   Chạy tiếp = mất dữ liệu."
        )


def _preflight(sconn: sqlite3.Connection) -> list[str]:
    """
    Các điều kiện phải thoả TRƯỚC khi bắt đầu chèn. Fail fast, không fail giữa chừng.
    """
    problems: list[str] = []

    # 1. Kiểm tra seq IS NULL trong sync_mutations (Postgres dùng BIGSERIAL NOT NULL)
    try:
        n = sconn.execute(
            "SELECT COUNT(*) FROM sync_mutations WHERE seq IS NULL"
        ).fetchone()[0]
        if n:
            problems.append(
                f"{n} dòng sync_mutations còn seq IS NULL. PostgreSQL dùng BIGSERIAL "
                f"(NOT NULL) nên sẽ lỗi. Khởi động server SQLite một lần để migration "
                f"002_backfill_mutation_seq chạy, kiểm tra log thấy '✅ [MIGRATION] 002', rồi thử lại."
            )
    except Exception:
        pass

    # 2. Cột NOT NULL ở phía PostgreSQL — SQLite có thể chứa NULL do typing lỏng
    not_null_checks = (
        ("device_tokens", "token_hash"),
        ("employee_pins", "pin_hash"),
        ("employee_pins", "salt"),
        ("work_sessions", "device_id"),
        ("work_sessions", "user_id"),
        ("work_sessions", "started_at"),
        ("mushroom_job_types", "name"),
        ("mushroom_attendance_events", "employee_id"),
        ("mushroom_attendance_events", "event_type"),
        ("mushroom_attendance_events", "timestamp"),
        ("mushroom_attendance_events", "source"),
        ("mushroom_daily_timesheets", "employee_id"),
        ("mushroom_daily_timesheets", "plan_date"),
        ("mushroom_payroll_calculations", "employee_id"),
        ("mushroom_payroll_calculations", "pay_period"),
        ("mushroom_job_safety_configs", "job_id"),
        ("mushroom_safety_checkin_logs", "job_id"),
        ("mushroom_safety_checkin_logs", "worker_id"),
        ("mushroom_safety_checkin_logs", "event_type"),
        ("mushroom_safety_checkin_logs", "timestamp"),
    )
    for table, col in not_null_checks:
        try:
            n = sconn.execute(
                f"SELECT COUNT(*) FROM {table} WHERE {col} IS NULL"
            ).fetchone()[0]
            if n:
                problems.append(f"{table}.{col}: {n} dòng NULL, nhưng PostgreSQL khai báo NOT NULL.")
        except Exception:
            pass  # Bảng chưa tồn tại ở SQLite — không phải lỗi

    # 3. Kiểu dữ liệu: SQLite typing động, cột INTEGER có thể chứa chuỗi (M10)
    type_checks = (
        ("sync_mutations", "seq"),
        ("known_servers", "port"),
        ("known_servers", "last_synced_seq"),
    )
    for table, col in type_checks:
        try:
            n = sconn.execute(
                f"SELECT COUNT(*) FROM {table} "
                f"WHERE {col} IS NOT NULL AND typeof({col}) NOT IN ('integer', 'null')"
            ).fetchone()[0]
            if n:
                problems.append(f"{table}.{col}: {n} dòng không phải INTEGER (typeof lệch).")
        except Exception:
            pass

    return problems


def run_verify(sconn: sqlite3.Connection, pconn) -> int:
    """Đối soát số dòng thực tế giữa SQLite và PostgreSQL."""
    print("\n🔍 Đang đối soát số lượng bản ghi giữa SQLite và PostgreSQL...")
    mismatches: list[tuple[str, int, int]] = []
    for table, _ in TABLES:
        try:
            s_row = sconn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()
            src_count = s_row[0] if s_row else 0
        except Exception:
            src_count = 0

        try:
            p_row = pconn.execute(f"SELECT COUNT(*) AS c FROM {table}").fetchone()
            dst_count = _row_value(p_row, "c")
        except Exception as e:
            print(f"   [!!] {table}: không đọc được COUNT(*) ở PostgreSQL: {e}")
            dst_count = -1

        status = "OK" if dst_count >= src_count else "LỆCH"
        print(f"   [{status}] {table:<22}: SQLite = {src_count:<6} | PostgreSQL = {dst_count:<6}")
        if dst_count < src_count:
            mismatches.append((table, src_count, dst_count))

    if mismatches:
        print("\n⛔ ĐỐI SOÁT THẤT BẠI — Có bảng bị thiếu dòng:")
        for t, s, d in mismatches:
            print(f"     • {t}: thiếu {s - d} dòng (SQLite={s}, PG={d})")
        return 1

    print("\n✅ Toàn bộ bảng khớp số lượng.")
    return 0


def migrate(dry_run: bool = False, verify_only: bool = False, force: bool = False) -> int:
    from server_config import CONFIG
    from database import DB_PATH
    from db_postgres import pg_connection
    from db_init_postgres import init_db_postgres

    if not CONFIG.pg_dsn:
        if dry_run:
            print("ℹ️  IZIIAPP_PG_DSN chưa cấu hình — chạy dry-run chỉ kiểm tra nguồn SQLite.")
        else:
            print("⛔ Thiếu IZIIAPP_PG_DSN trong .env — không biết nối tới đâu.")
            return 1

    if not os.path.exists(DB_PATH):
        print(f"⛔ Không tìm thấy file SQLite: {DB_PATH}")
        return 1

    # Server đang chạy = có thể có mutation ghi dở trong lúc copy → CHẶN, không
    # chỉ cảnh báo. Đây là script có thể mất dữ liệu; mặc định phải an toàn.
    # --dry-run và --verify không ghi gì nên vẫn cho chạy.
    server_port = int(os.environ.get("IZIIAPP_PORT", 8080))
    if _check_server_running(server_port):
        if dry_run or verify_only:
            print(
                f"ℹ️  iZiiServer đang chạy trên cổng {server_port} — "
                f"chế độ chỉ-đọc nên vẫn tiếp tục."
            )
        elif force:
            print(
                f"⚠️  iZiiServer ĐANG CHẠY trên cổng {server_port} nhưng có --force — "
                f"vẫn migrate. Dữ liệu ghi trong lúc copy có thể bị bỏ sót."
            )
        else:
            print(
                f"⛔ DỪNG: iZiiServer đang chạy trên cổng {server_port}.\n"
                f"   Migrate khi server còn ghi = mutation mới có thể bị bỏ sót im lặng.\n"
                f"   Dừng dịch vụ trước (nssm stop izii_server), hoặc thêm --force "
                f"nếu bạn chắc chắn không có ai đang ghi."
            )
            return 1

    print(f"📖 Nguồn : {DB_PATH}")
    if CONFIG.pg_dsn:
        print(f"🐘 Đích  : {CONFIG.pg_dsn.split('@')[-1]}")  # không in mật khẩu
    else:
        print("🐘 Đích  : (Chưa cấu hình)")

    sconn = sqlite3.connect(DB_PATH)
    sconn.row_factory = sqlite3.Row

    # Chốt chặn độ phủ chiều NGUỒN — không cần kết nối PostgreSQL nên chạy được
    # ở mọi chế độ, kể cả --dry-run.
    _assert_source_coverage(sconn)
    print("✅ Độ phủ bảng phía SQLite: mọi bảng đều nằm trong TABLES hoặc NOT_MIGRATED.")

    # Chạy Pre-flight checks
    problems = _preflight(sconn)
    if problems:
        print("\n⛔ Pre-flight thất bại — chưa chèn dòng nào:")
        for p in problems:
            print(f"     • {p}")
        sconn.close()
        return 1
    print("✅ Pre-flight checks đạt yêu cầu.")

    # Nếu chỉ verify
    if verify_only:
        with pg_connection() as pconn:
            res = run_verify(sconn, pconn)
        sconn.close()
        return res

    # Nếu dry-run
    if dry_run:
        print("\n🧪 [DRY-RUN] Kiểm tra schema và số lượng dòng hiện có ở SQLite:")
        total_src = 0
        empty_tables: list[str] = []
        for table, _ in TABLES:
            try:
                scols = _sqlite_columns(sconn, table)
                cnt = sconn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
                total_src += cnt
                if cnt == 0:
                    empty_tables.append(table)
                print(f"   • {table:<22}: {cnt:<6} dòng ({len(scols)} cột)")
            except Exception:
                print(f"   • {table:<22}: chưa có trong SQLite")

        # Chốt chặn độ phủ chiều ĐÍCH cũng phải chạy ở dry-run — đây là chỗ đáng
        # ra phải phát hiện sớm nhất một bảng bị bỏ sót, chứ không phải để lộ ra
        # lúc chạy thật.
        if CONFIG.pg_dsn:
            try:
                with pg_connection() as pconn:
                    _assert_table_coverage(pconn)
                print("✅ [DRY-RUN] Độ phủ bảng phía PostgreSQL: đầy đủ.")
            except SystemExit:
                raise
            except Exception as e:
                print(f"⚠️  [DRY-RUN] Không kiểm tra được schema PostgreSQL: {e}")
        else:
            print("⚠️  [DRY-RUN] Chưa có IZIIAPP_PG_DSN — BỎ QUA kiểm tra độ phủ "
                  "bảng phía PostgreSQL. Cấu hình DSN rồi chạy lại để kiểm tra đủ.")

        sconn.close()
        print(f"\n✅ [DRY-RUN] Hoàn tất kiểm tra: tổng cộng ~{total_src} dòng sẵn sàng migrate.")

        # Dry-run trên DB rỗng KHÔNG chứng minh được gì. Chính 4 bảng từng bị bỏ
        # sót (device_tokens, employee_pins, work_sessions, enrollment_tokens)
        # đang rỗng ở DB dev — bản script CHƯA vá cũng sẽ "chạy thành công" trên
        # dữ liệu này. Nói thẳng ra thay vì để người đọc tưởng đã nghiệm thu xong.
        if empty_tables:
            print(
                f"\n⚠️  {len(empty_tables)} bảng đang RỖNG: {', '.join(empty_tables)}\n"
                f"   Dry-run trên bảng rỗng không kiểm chứng được đường chuyển dữ liệu "
                f"của bảng đó.\n"
                f"   Trước khi cutover, hãy chạy lại trên BẢN COPY DB PRODUCTION có "
                f"dữ liệu thật ở các bảng này."
            )
        return 0

    # Tạo schema đích trước
    init_db_postgres()

    total_rows = 0
    with pg_connection() as pconn:
        # Kiểm tra độ phủ bảng
        _assert_table_coverage(pconn)

        pgcur = pconn.cursor()
        for table, pk in TABLES:
            try:
                scols = _sqlite_columns(sconn, table)
            except Exception:
                print(f"   [--] {table}: không có trong SQLite, bỏ qua.")
                continue
            if not scols:
                print(f"   [--] {table}: không có trong SQLite, bỏ qua.")
                continue

            ptypes = _pg_column_types(pconn, table)
            pcols = set(ptypes.keys())
            # Chỉ chuyển những cột TỒN TẠI Ở CẢ HAI BÊN
            cols = [c for c in scols if c in pcols]
            if not cols:
                print(f"   [!!] {table}: không có cột chung, bỏ qua.")
                continue

            quoted = ", ".join(f'"{c}"' for c in cols)
            placeholders = ", ".join(["%s"] * len(cols))
            insert_sql = (
                f'INSERT INTO {table} ({quoted}) VALUES ({placeholders}) '
                f'ON CONFLICT ({pk}) DO NOTHING'
            )

            # Stream theo lô bằng fetchmany thay vì nạp toàn bộ vào RAM
            cur = sconn.execute(f"SELECT {', '.join(chr(34)+c+chr(34) for c in cols)} FROM {table}")
            n = 0
            while True:
                chunk = cur.fetchmany(BATCH)
                if not chunk:
                    break
                batch_data = [
                    tuple(_convert_val(c, r[c], ptypes.get(c, "")) for c in cols)
                    for r in chunk
                ]
                pgcur.executemany(insert_sql, batch_data)
                n += len(batch_data)
            pconn.commit()
            total_rows += n

            # Đếm thật ở cả 2 đầu
            src_count = sconn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            dst_row = pconn.execute(f"SELECT COUNT(*) AS c FROM {table}").fetchone()
            dst_count = _row_value(dst_row, "c")
            status = "OK" if dst_count >= src_count else "LỆCH"
            print(f"   [{status}] {table:<22}: đã chuyển {n:<6} dòng (SQLite={src_count}, PG={dst_count})")

        # Đẩy sequence của cột seq lên quá giá trị lớn nhất vừa nạp
        try:
            row = pconn.execute(
                "SELECT COALESCE(MAX(seq), 0) AS m FROM sync_mutations"
            ).fetchone()
            max_seq = int(_row_value(row, "m"))
            pconn.execute(
                "SELECT setval(pg_get_serial_sequence('sync_mutations', 'seq'), %s, true)",
                (max_seq if max_seq > 0 else 1,),
            )
            pconn.commit()
            print(f"   [OK] Đã đặt sequence seq = {max_seq} (bản ghi kế tiếp sẽ là {max_seq + 1})")
        except Exception as e:
            print(f"   [!!] Không đặt được sequence: {e}")
            print("        CẢNH BÁO: bản ghi mới có thể trùng seq với bản ghi cũ.")

        # Đối soát lại lần cuối
        verify_status = run_verify(sconn, pconn)

    sconn.close()

    if verify_status != 0:
        print("\n⛔ MIGRATE KHÔNG TOÀN VẸN — KHÔNG được đổi IZIIAPP_DB_BACKEND!")
        return 1

    print(f"\n✅ Hoàn tất migrate thành công: {total_rows} dòng.")
    print("   Bước tiếp theo:")
    print("   1. Đổi trong .env: IZIIAPP_DB_BACKEND=postgres")
    print("   2. Khởi động lại server.")
    print("   3. Giữ lại file SQLite cũ vài ngày để đối chiếu trước khi xoá.")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate iZiiApp SQLite Database to PostgreSQL")
    parser.add_argument("--dry-run", action="store_true", help="Chạy kiểm tra pre-flight và đếm dòng, không ghi vào PostgreSQL")
    parser.add_argument("--verify", action="store_true", help="Đối soát số lượng dòng giữa SQLite và PostgreSQL hiện tại")
    parser.add_argument("--force", action="store_true", help="Vẫn migrate dù phát hiện iZiiServer đang chạy (rủi ro bỏ sót dữ liệu ghi dở)")
    args = parser.parse_args()

    sys.exit(migrate(dry_run=args.dry_run, verify_only=args.verify, force=args.force))
