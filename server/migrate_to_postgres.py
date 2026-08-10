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
4. Chạy:
       cd server
       python migrate_to_postgres.py
5. Kiểm tra số dòng in ra khớp với SQLite, rồi mới đổi:
       IZIIAPP_DB_BACKEND=postgres
6. Khởi động lại server.

ĐIỂM QUAN TRỌNG NHẤT: `seq`
---------------------------
Script GIỮ NGUYÊN giá trị seq cũ thay vì để BIGSERIAL cấp lại. Bắt buộc phải
vậy, vì các thiết bị và peer server đang giữ con trỏ trỏ tới những seq đó. Nếu
đánh số lại, mọi client sẽ hoặc bỏ qua dữ liệu (con trỏ cũ lớn hơn seq mới)
hoặc nhận lại toàn bộ log.

Sau khi nạp xong, script đẩy sequence của Postgres lên quá giá trị seq lớn nhất
— quên bước này thì bản ghi mới sẽ đụng khoá trùng với bản ghi cũ.
"""
from __future__ import annotations

import os
import sqlite3
import sys

# Bảng cần chuyển và khoá chính tương ứng (dùng cho ON CONFLICT).
TABLES = [
    ("sync_mutations",        "id"),
    ("known_servers",         "server_id"),
    ("devices",               "device_id"),
    ("message_queue",         "id"),
    ("notifications",         "id"),
    ("notification_settings", "user_id, event_type"),
    ("webhook_subscriptions", "id"),
    ("webhook_dead_letters",  "id"),
    ("schema_migrations",     "name"),
]

BATCH = 500


def _sqlite_columns(sconn, table: str) -> list[str]:
    return [r[1] for r in sconn.execute(f"PRAGMA table_info({table})").fetchall()]


def _pg_columns(pconn, table: str) -> set[str]:
    rows = pconn.execute(
        "SELECT column_name FROM information_schema.columns WHERE table_name = %s",
        (table,),
    ).fetchall()
    return {r["column_name"] for r in rows}


def migrate() -> int:
    from server_config import CONFIG
    from database import DB_PATH
    from db_postgres import pg_connection
    from db_init_postgres import init_db_postgres

    if not CONFIG.pg_dsn:
        print("⛔ Thiếu IZIIAPP_PG_DSN trong .env — không biết nối tới đâu.")
        return 1

    if not os.path.exists(DB_PATH):
        print(f"⛔ Không tìm thấy file SQLite: {DB_PATH}")
        return 1

    print(f"📖 Nguồn : {DB_PATH}")
    print(f"🐘 Đích  : {CONFIG.pg_dsn.split('@')[-1]}")   # không in mật khẩu

    # Tạo schema đích trước.
    init_db_postgres()

    sconn = sqlite3.connect(DB_PATH)
    sconn.row_factory = sqlite3.Row

    total_rows = 0
    with pg_connection() as pconn:
        for table, pk in TABLES:
            try:
                scols = _sqlite_columns(sconn, table)
            except Exception:
                print(f"   [--] {table}: không có trong SQLite, bỏ qua.")
                continue
            if not scols:
                print(f"   [--] {table}: không có trong SQLite, bỏ qua.")
                continue

            pcols = _pg_columns(pconn, table)
            # Chỉ chuyển những cột TỒN TẠI Ở CẢ HAI BÊN — tránh vỡ khi hai
            # schema lệch nhau vài cột.
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

            rows = sconn.execute(f"SELECT {', '.join(chr(34)+c+chr(34) for c in cols)} FROM {table}").fetchall()
            n = 0
            batch: list[tuple] = []
            for r in rows:
                batch.append(tuple(r[c] for c in cols))
                if len(batch) >= BATCH:
                    pconn.cursor().executemany(insert_sql, batch)
                    n += len(batch)
                    batch = []
            if batch:
                pconn.cursor().executemany(insert_sql, batch)
                n += len(batch)
            pconn.commit()
            total_rows += n
            print(f"   [OK] {table}: {n} dòng")

        # Đẩy sequence của cột seq lên quá giá trị lớn nhất vừa nạp.
        # setval(..., is_called=true) nghĩa là lần nextval kế tiếp trả max+1.
        try:
            row = pconn.execute(
                "SELECT COALESCE(MAX(seq), 0) AS m FROM sync_mutations"
            ).fetchone()
            max_seq = int(row["m"])
            pconn.execute(
                "SELECT setval(pg_get_serial_sequence('sync_mutations', 'seq'), %s, true)",
                (max_seq if max_seq > 0 else 1,),
            )
            pconn.commit()
            print(f"   [OK] Đã đặt sequence seq = {max_seq} (bản ghi kế tiếp sẽ là {max_seq + 1})")
        except Exception as e:
            print(f"   [!!] Không đặt được sequence: {e}")
            print("        CẢNH BÁO: bản ghi mới có thể trùng seq với bản ghi cũ.")

    sconn.close()
    print(f"\n✅ Hoàn tất: {total_rows} dòng.")
    print("   Giờ đổi IZIIAPP_DB_BACKEND=postgres trong .env rồi khởi động lại server.")
    print("   Giữ lại file SQLite cũ vài ngày để đối chiếu trước khi xoá.")
    return 0


if __name__ == "__main__":
    sys.exit(migrate())
