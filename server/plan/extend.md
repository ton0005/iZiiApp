# Plan: Mở rộng iZiiServer sang PostgreSQL

**Phạm vi:** kiểm tra `server/migrate_to_postgres.py` và toàn bộ đường migrate SQLite → PostgreSQL, đưa ra plan thực thi.
**Cập nhật:** 26/08/2026
**Tài liệu liên quan:** `plan/database/extend_report.md` (báo cáo tư vấn tổng thể: backup, scalability, so sánh PG vs MSSQL) · `server/POSTGRES_MIGRATION_GUIDE.md` + `server/HUONG_DAN_CHUYEN_DATABASE_POSTGRES.md` (quy trình vận hành 8 bước). File này là **plan kỹ thuật chi tiết cho riêng nhánh PostgreSQL**.

---

## TRẠNG THÁI — 26/08/2026

> **Giai đoạn 0 đã HOÀN THÀNH.** Toàn bộ M1 → M10 đã vá và được kiểm chứng bằng đối chiếu tự động lại trên code mới, không chỉ dựa vào khai báo. Thêm 7 điểm tồn đọng (R1 → R7) phát hiện trong đợt review ngày 26/08 cũng đã vá xong.
>
> **Bước kế tiếp: Giai đoạn 1 — dựng staging và chạy migrate thử trên BẢN COPY DB PRODUCTION.**

### Nhật ký

| Ngày | Việc | Kết quả |
|---|---|---|
| 25/08 | Audit `migrate_to_postgres.py` — phát hiện M1 → M10 | 3 blocker, 3 🟠, 4 🟡 |
| 26/08 | Vá M1 → M10 | ✅ Xong, xác minh lại bằng script đối chiếu schema |
| 26/08 | Review đợt 2 — phát hiện R1 → R7 | 2 🟠, 5 🟡 |
| 26/08 | Vá R1 → R7 + bổ sung smoke test T7/T11 vào 2 guide | ✅ Xong, có test tự động |

### M1 → M10 — đã đóng

| ID | Trạng thái | Bằng chứng kiểm chứng |
|---|---|---|
| M1 `TABLES` thiếu 4 bảng | ✅ | Script đối chiếu: `TABLES` = 13/13, "bảng ở cả hai schema mà không được migrate" = **rỗng** |
| M2 Đếm dòng giả | ✅ | `run_verify()` đếm `COUNT(*)` thật hai đầu, exit code ≠ 0 khi lệch |
| M3 `seq IS NULL` | ✅ | `_preflight()` chặn trước khi chèn — đã test với DB có `seq NULL` |
| M4 Lệch kiểu `dead_lettered_at` | ✅ | Cả hai bên đều `TEXT`; có `ALTER ... USING` cho DB đã lỡ tạo |
| M5 `fetchall()` tràn RAM | ✅ | `fetchmany(500)` + dùng lại một cursor |
| M6 Thiếu `prune_message_queue_postgres()` | ✅ | Hàm có thật, `db_init.py` điều hướng đúng, điều kiện chặn ở `app.py` đã bỏ |
| M7 `table_schema` | ✅ | `_pg_columns()` đã lọc `= 'public'` |
| M8 `--dry-run` / `--verify` | ✅ | Có, kèm UTF-8 Windows console |
| M9 `uploads/` + rollback | ✅ | Cả 2 guide có Bước 1 backup `uploads/` và §5 rollback + resync `sync_sequence` |
| M10 Validate kiểu dữ liệu | ✅ | `_preflight()` kiểm `typeof()` |
| P3 `prune` chỉ chạy lúc start | ✅ | `_maintenance_loop()` 24h, có `cancel()` lúc shutdown |

### R1 → R7 — tồn đọng phát hiện 26/08, đã đóng

| ID | Vấn đề | Mức | Cách sửa |
|---|---|---|---|
| **R1** | `_assert_table_coverage` chỉ so PG → `TABLES`. Bảng thêm vào `db_init.py` mà quên `db_init_postgres.py` sẽ **mất im lặng** — đúng lỗi M1, chiều ngược lại | 🟠 | Thêm `_assert_source_coverage(sconn)` đọc `sqlite_master`, cùng hằng `NOT_MIGRATED = {"sync_sequence"}` kèm lý do |
| **R2** | `--dry-run` không chạy kiểm tra độ phủ — chỗ đáng ra phải bắt sớm nhất | 🟠 | `_assert_source_coverage` chạy ở **mọi** chế độ; dry-run cũng kết nối PG để chạy `_assert_table_coverage` khi có DSN |
| **R3** | Dry-run trên DB dev không chứng minh được gì (`device_tokens`/`employee_pins`/`work_sessions` đều rỗng — bản chưa vá cũng "chạy thành công") | 🟠 | Dry-run liệt kê bảng rỗng và **cảnh báo thẳng** rằng chưa nghiệm thu được; guide ghi rõ phải dùng bản copy DB production |
| **R4** | Smoke test trong 2 guide thiếu T7 (peer-sync PG↔SQLite) và T11 (collation tiếng Việt) | 🟠 | Bổ sung mục 4/5/6 vào §4 của cả 2 guide, đánh dấu **BẮT BUỘC** |
| **R5** | Guard `dst_count` làm ngược ý định — `hasattr(row,"__getitem__")` đúng với cả tuple nên nhánh dự phòng chết; ở dòng đếm trong `migrate()` không có `try` → crash sau khi đã commit | 🟡 | Tách hàm `_row_value(row, key)` dùng `isinstance(dict)`; đổi truy vấn sang `COUNT(*) AS c` |
| **R6** | `ALTER COLUMN ... TYPE TEXT USING` chạy **mỗi lần khởi động**, lấy `ACCESS EXCLUSIVE` lock vô ích | 🟡 | Bọc trong khối `DO $$ ... IF data_type <> 'text' THEN ... END IF $$` |
| **R7** | `_check_server_running()` chỉ cảnh báo rồi chạy tiếp; không có hướng dẫn khi migrate lỗi giữa chừng | 🟡 | **Chặn** mặc định + cờ `--force`; docstring và §6 của 2 guide có quy trình `DROP DATABASE` + chạy lại |

### Kiểm chứng đã chạy cho R1 → R7

```
✅ py_compile migrate_to_postgres.py db_init_postgres.py            → exit 0
✅ pglast parse 42 câu DDL/ALTER (gồm khối DO $$)                    → 0 lỗi cú pháp
✅ _row_value: dict → 7, tuple → 7   (guard CŨ với tuple → TypeError)
✅ _assert_source_coverage: schema 14 bảng hiện tại                   → PASS
✅ _assert_source_coverage: thêm bảng lạ 'harvest_audit' chỉ ở SQLite → CHẶN đúng
✅ migrate(dry_run=True) trên DB giả schema đúng                      → exit 0
✅ migrate(dry_run=True) với seq NULL + typeof lệch + NOT NULL vi phạm → exit 1, liệt kê đủ 5 vấn đề
```

### Vẫn còn nợ (chưa chặn Giai đoạn 1)

| Vấn đề | Mức | Ghi chú |
|---|---|---|
| Vẫn commit theo **từng bảng**, không có transaction bao ngoài | 🟡 | Pre-flight giảm rủi ro; quy trình khôi phục đã ghi vào guide (§6, Lỗi 5). Chấp nhận được ở quy mô 13 bảng |
| **Hai file schema sửa tay song song** — nguyên nhân gốc của M1, M4, R1 | 🟠 | Chốt chặn hai chiều đã bịt triệu chứng, nhưng nguyên nhân còn nguyên. Xử lý dứt điểm ở **4.6 (Alembic)** |
| Backup PostgreSQL định kỳ chưa thiết lập | 🔴 | **Chặn Giai đoạn 3.** Xem `plan/database/extend_report.md` §1 |

---

## TL;DR (nguyên bản ngày 25/08 — giữ để đối chiếu)

Đường migrate PostgreSQL trong repo đã ở mức **hoàn thiện ~85%**. Tầng trừu tượng backend sạch, repository parity 100%, schema hai bên khớp cột 100%.

Nhưng **KHÔNG được chạy `migrate_to_postgres.py` ở trạng thái hiện tại.** Có 3 lỗi chặn (blocker), trong đó 2 lỗi gây **mất dữ liệu hoặc hỏng giữa chừng mà script vẫn in `✅ Hoàn tất`**.

| Trạng thái | Hạng mục |
|---|---|
| 🔴 **Chặn cutover** | M1 thiếu 4 bảng · M2 đếm dòng giả · M3 `seq IS NULL` làm crash giữa chừng |
| 🟠 **Phải sửa trước production** | M4 lệch kiểu `dead_lettered_at` · M5 `fetchall()` nạp cả bảng vào RAM · M6 thiếu `prune_message_queue_postgres()` |
| 🟡 **Nên sửa** | M7 → M10: `table_schema`, dry-run, uploads/, rollback, pre-flight validation |
| ✅ **Đã đúng, giữ nguyên** | Repository parity · `open_connection()` · giữ `seq` + `setval` · copy `schema_migrations` · `sql()` helper |

Ước tính: **2,5 ngày công** để sửa hết blocker + 🟠, cộng **1 tuần chạy staging** trước khi cutover node đầu tiên.

---

## 1. Kết quả kiểm tra — hiện trạng đường migrate

### 1.1 Những gì đã đúng (không cần đụng vào)

| Hạng mục | Bằng chứng | Đánh giá |
|---|---|---|
| **Trừu tượng hoá backend** | `dependencies.py:89 open_connection()` trả `pg_connection()` hoặc SQLite ctx; `make_sync_repo()` chọn repo đúng backend | ✅ Sạch. Router không cần biết backend nào |
| **Repository parity** | `interface.py` khai báo **24** method — `sqlite_repo.py` và `postgres_repo.py` **cài đủ cả 24**. Chênh lệch duy nhất là `_next_seq` (private, PG không cần vì dùng BIGSERIAL) | ✅ Không có lỗ hổng |
| **Schema parity** | Đối chiếu tự động 13 bảng chung: **khớp 100% tên cột**, kể cả các cột thêm bằng `ALTER TABLE` | ✅ |
| **SQL thô trong router** | `admin.py`, `devices.py`, `enrollment.py`, `sessions.py` có SQL thô, **nhưng đã rẽ nhánh theo backend**: `INSERT OR REPLACE` (SQLite) ↔ `ON CONFLICT DO UPDATE` (PG) | ✅ Đã xử lý |
| **Placeholder** | `database.py:sql()` đổi `?` → `%s` khi `db_backend == "postgres"`; được dùng 15 chỗ trong routers | ✅ |
| **Giữ nguyên `seq`** | Script không để BIGSERIAL cấp lại số, và `setval()` sau khi nạp | ✅ **Đây là quyết định quan trọng nhất và đã làm đúng.** Đánh số lại = mọi client mất đồng bộ |
| **Copy `schema_migrations`** | Nằm trong `TABLES` | ✅ Tránh chạy lại data migration trên PG |
| **Pool bắt buộc** | `db_postgres.py:get_pool()`, lazy import psycopg | ✅ Đúng — không dùng pool thì latency tăng vọt |
| **Fallback an toàn** | `server_config.py:214` — `db_backend=postgres` mà thiếu DSN thì quay về sqlite để server vẫn chạy | ✅ |

### 1.2 Bảng gap — 10 vấn đề tìm được

| ID | Vấn đề | Mức | Vị trí | Hệ quả |
|---|---|---|---|---|
| **M1** | `TABLES` chỉ liệt kê **9/13** bảng | 🔴 | `migrate_to_postgres.py:36-46` | **Mất dữ liệu, im lặng** |
| **M2** | Số dòng in ra là số dòng *gửi đi*, không phải số dòng *thực chèn* | 🔴 | `:117-124` | Bước nghiệm thu **không bao giờ phát hiện được sai lệch** |
| **M3** | `seq` NULL → vi phạm NOT NULL của BIGSERIAL | 🔴 | `db_init_postgres.py:34` vs `db_init.py:72` | Script **chết giữa chừng**, PG ở trạng thái nửa vời |
| **M4** | `dead_lettered_at`: `TEXT` (SQLite) vs `TIMESTAMPTZ` (PG) | 🟠 | `db_init.py:157` vs `db_init_postgres.py:234` | Lỗi chèn hoặc query trộn kiểu |
| **M5** | `fetchall()` nạp toàn bộ bảng vào RAM | 🟠 | `:113` | Vỡ khi `sync_mutations` lớn |
| **M6** | `prune_message_queue_postgres()` **không tồn tại** | 🟠 | `app.py:308` | Tin nhắn kẹt vô hạn sau cutover |
| **M7** | `_pg_columns` không lọc `table_schema` | 🟡 | `:56-59` | Lấy nhầm cột nếu trùng tên bảng ở schema khác |
| **M8** | Không có `--dry-run`, không kiểm tra server đã dừng | 🟡 | toàn file | Rủi ro thao tác |
| **M9** | Không migrate `uploads/`; không có thủ tục rollback | 🟡 | — | Cutover không trọn vẹn |
| **M10** | Không validate kiểu dữ liệu trước khi migrate | 🟡 | — | SQLite typing động → lỗi bất ngờ giữa chừng |

---

## 2. Chi tiết & cách sửa từng gap

### 🔴 M1 — `TABLES` thiếu 4 bảng

**Đối chiếu tự động:**

```
Bảng trong schema SQLite : 14   (13 + sync_sequence)
Bảng trong schema PG     : 13
Bảng trong TABLES        : 9
→ Có ở CẢ HAI schema nhưng KHÔNG được migrate:
     device_tokens, employee_pins, enrollment_tokens, work_sessions
```

**Vì sao im lặng:** script chỉ `continue` khi bảng **không tồn tại ở SQLite**. Bảng tồn tại nhưng không nằm trong `TABLES` thì không có nhánh nào chạm tới — không log, không cảnh báo, không lỗi. Kết thúc vẫn in `✅ Hoàn tất`.

**Hậu quả cụ thể từng bảng:**

| Bảng | Nội dung | Mất thì sao |
|---|---|---|
| `device_tokens` | Token xác thực của mọi thiết bị đã enroll | **Toàn bộ máy tablet/điện thoại ngoài hiện trường mất quyền truy cập, phải enroll lại từng máy** |
| `employee_pins` | PIN điểm danh đầu ca | Nhân viên không đăng nhập được → **ca sản xuất dừng** |
| `work_sessions` | Lịch sử phiên làm việc | Mất dữ liệu chấm công / truy vết ATLĐ — **không tái tạo được** |
| `enrollment_tokens` | Vé mời enroll (TTL 600s) | Nhẹ, nhưng vé đang phát dở sẽ hỏng |

**Patch:**

```python
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
    # ── BỔ SUNG: 4 bảng bị bỏ sót ──────────────────────────────────────────
    ("enrollment_tokens",     "token"),
    ("device_tokens",         "device_id"),
    ("work_sessions",         "id"),
    ("employee_pins",         "user_id"),
]
# sync_sequence CỐ Ý không có mặt: PostgreSQL dùng BIGSERIAL, không cần bộ đếm
# thủ công. Xem §5 (Rollback) để biết hệ quả khi cần quay ngược về SQLite.
```

**Và quan trọng hơn — thêm chốt chặn để lỗi này không tái diễn:**

```python
def _assert_table_coverage(pconn) -> None:
    """
    Mọi bảng có trong schema PostgreSQL đều PHẢI nằm trong TABLES.
    Thiếu một bảng = mất dữ liệu im lặng — đúng lỗi đã xảy ra với
    device_tokens / employee_pins / work_sessions / enrollment_tokens.
    """
    rows = pconn.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' AND table_type = 'BASE TABLE'"
    ).fetchall()
    in_pg      = {r["table_name"] for r in rows}
    in_script  = {t for t, _ in TABLES}
    missing    = in_pg - in_script
    if missing:
        raise SystemExit(
            f"⛔ DỪNG: {len(missing)} bảng có trong schema PostgreSQL nhưng "
            f"KHÔNG nằm trong TABLES: {sorted(missing)}\n"
            f"   Bổ sung vào TABLES rồi chạy lại. Chạy tiếp = mất dữ liệu."
        )
```

Gọi ngay sau `init_db_postgres()`.

---

### 🔴 M2 — Con số nghiệm thu là con số giả

Docstring bước 5 hướng dẫn: *"Kiểm tra số dòng in ra khớp với SQLite, rồi mới đổi"*. Nhưng:

```python
pconn.cursor().executemany(insert_sql, batch)
n += len(batch)          # ← đếm số dòng GỬI ĐI
```

Với `ON CONFLICT (...) DO NOTHING`, dòng bị bỏ qua vẫn được cộng vào `n`. Vì `n` được cộng từ chính số dòng đọc ra từ SQLite, con số in ra **luôn luôn bằng** `COUNT(*)` của SQLite — kể cả khi PostgreSQL thực tế không nhận dòng nào. Bước nghiệm thu này về mặt toán học không thể phát hiện sai lệch.

**Patch — đếm ở phía đích và so sánh tự động:**

```python
            # Đếm THẬT ở phía PostgreSQL, không tin con số tự cộng.
            src_count = sconn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            dst_count = pconn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()["count"]
            status = "OK" if dst_count >= src_count else "LỆCH"
            print(f"   [{status}] {table}: SQLite={src_count}  PostgreSQL={dst_count}")
            if dst_count < src_count:
                mismatches.append((table, src_count, dst_count))
```

Cuối script:

```python
    if mismatches:
        print("\n⛔ MIGRATE KHÔNG TOÀN VẸN — KHÔNG được đổi IZIIAPP_DB_BACKEND:")
        for t, s, d in mismatches:
            print(f"     {t}: thiếu {s - d} dòng")
        return 1
    print(f"\n✅ Hoàn tất: {total_rows} dòng, toàn bộ bảng khớp số lượng.")
    return 0
```

> Lưu ý dùng `>=` chứ không `==`: chạy lại script lần hai là hợp lệ (idempotent nhờ `ON CONFLICT DO NOTHING`), và PG có thể đã có sẵn dòng từ lần chạy trước.

---

### 🔴 M3 — `seq IS NULL` làm script chết giữa chừng

PostgreSQL: `seq BIGSERIAL` ⟹ ngầm định **`NOT NULL`**.
SQLite: `seq` được thêm bằng `ALTER TABLE ... ADD COLUMN seq INTEGER` (`db_init.py:72`) — **cho phép NULL**.

Migration `002_backfill_mutation_seq` (`db_init.py:438`) có nhiệm vụ điền các giá trị NULL đó, nhưng:

1. Nó chỉ chạy trong `lifespan()` lúc server **khởi động**;
2. Nó được bọc `try/except` và khi thất bại chỉ in cảnh báo rồi đi tiếp — *"sẽ thử lại lần khởi động sau"*.

Nghĩa là hoàn toàn có thể tồn tại một DB production còn dòng `seq IS NULL`. Khi đó `INSERT` sẽ ném `null value in column "seq" violates not-null constraint`, script chết ở giữa vòng lặp bảng — và vì `pconn.commit()` được gọi **sau mỗi bảng**, các bảng trước đó đã commit rồi. Kết quả: PostgreSQL ở trạng thái nửa vời, không có thông báo tổng thể nào cho biết đã tới đâu.

**Patch — pre-flight check, chạy TRƯỚC khi chèn dòng đầu tiên:**

```python
def _preflight(sconn) -> list[str]:
    """Các điều kiện phải thoả TRƯỚC khi bắt đầu chèn. Fail fast, không fail giữa chừng."""
    problems = []

    n = sconn.execute(
        "SELECT COUNT(*) FROM sync_mutations WHERE seq IS NULL"
    ).fetchone()[0]
    if n:
        problems.append(
            f"{n} dòng sync_mutations còn seq IS NULL. PostgreSQL dùng BIGSERIAL "
            f"(NOT NULL) nên sẽ lỗi. Khởi động server SQLite một lần để migration "
            f"002_backfill_mutation_seq chạy, kiểm tra log thấy '✅ [MIGRATION] 002', rồi thử lại."
        )

    # Cột NOT NULL ở phía PostgreSQL — SQLite có thể chứa NULL do typing lỏng.
    for table, col in (
        ("device_tokens", "token_hash"),
        ("employee_pins", "pin_hash"), ("employee_pins", "salt"),
        ("work_sessions", "device_id"), ("work_sessions", "user_id"),
        ("work_sessions", "started_at"),
    ):
        try:
            n = sconn.execute(
                f"SELECT COUNT(*) FROM {table} WHERE {col} IS NULL"
            ).fetchone()[0]
            if n:
                problems.append(f"{table}.{col}: {n} dòng NULL, nhưng PostgreSQL khai báo NOT NULL.")
        except Exception:
            pass   # bảng chưa tồn tại ở SQLite — không phải lỗi

    # Kiểu dữ liệu: SQLite typing động, cột INTEGER có thể chứa chuỗi (M10).
    for table, col in (("sync_mutations", "seq"), ("known_servers", "port"),
                       ("known_servers", "last_synced_seq")):
        try:
            n = sconn.execute(
                f"SELECT COUNT(*) FROM {table} "
                f"WHERE {col} IS NOT NULL AND typeof({col}) NOT IN ('integer','null')"
            ).fetchone()[0]
            if n:
                problems.append(f"{table}.{col}: {n} dòng không phải INTEGER (typeof lệch).")
        except Exception:
            pass

    return problems
```

Trong `migrate()`:

```python
    problems = _preflight(sconn)
    if problems:
        print("⛔ Pre-flight thất bại — chưa chèn dòng nào:")
        for p in problems:
            print(f"     • {p}")
        return 1
```

---

### 🟠 M4 — Lệch kiểu `dead_lettered_at`

| | Khai báo | Vị trí |
|---|---|---|
| SQLite | `dead_lettered_at TEXT` | `db_init.py:157`, `:166` |
| PostgreSQL | `dead_lettered_at TIMESTAMPTZ` | `db_init_postgres.py:234` |

Điều này **mâu thuẫn với chính docstring của `db_init_postgres.py`** (dòng 13-17), vốn nêu rõ nguyên tắc: *"thời gian vẫn lưu TEXT ISO-8601 UTC để TƯƠNG THÍCH TUYỆT ĐỐI với dữ liệu SQLite. Không đổi sang TIMESTAMPTZ ở bước này"*. Đây là một cột lọt lưới.

Hai hệ quả:

1. **Lúc migrate:** chèn chuỗi ISO-8601 từ SQLite vào cột `TIMESTAMPTZ` — psycopg3 gửi tham số dạng `text`, PostgreSQL có thể từ chối với `column "dead_lettered_at" is of type timestamp with time zone but expression is of type text`. **Bắt buộc test trên staging**, đừng phát hiện lúc cutover.
2. **Lúc chạy:** `prune_message_queue` so sánh `dead_lettered_at IS NULL AND sent_at < ?` — trộn một cột `TIMESTAMPTZ` với một cột `TEXT` trong cùng mệnh đề. Ngữ nghĩa so sánh khác nhau giữa hai backend.

**Patch (chọn phương án A cho bước 1):**

- **A — Thống nhất về TEXT ngay bây giờ** (khuyến nghị): đổi `db_init_postgres.py` thành `dead_lettered_at TEXT`, đúng nguyên tắc "bước 1 không đổi kiểu thời gian". Thêm vào `ALTER_STATEMENTS` để sửa các DB PG đã lỡ tạo:
  ```python
  'ALTER TABLE message_queue ALTER COLUMN dead_lettered_at TYPE TEXT '
  'USING dead_lettered_at::text',
  ```
- **B — Đổi toàn bộ sang `TIMESTAMPTZ`**: đúng về lâu dài nhưng phải làm cho **mọi** cột thời gian cùng lúc, kèm sửa mọi query so sánh. **Đây là việc của Giai đoạn 4** (§4), không phải của lần cutover đầu tiên. Trộn hai thay đổi rủi ro vào một lần là công thức gây sự cố.

---

### 🟠 M5 — `fetchall()` nạp toàn bộ bảng vào RAM

```python
rows = sconn.execute(f"SELECT ... FROM {table}").fetchall()
```

Hiện tại DB dev chỉ 168 KB nên không lộ. Nhưng `sync_mutations` là mutation log append-only — ở production sau vài tháng có thể vài triệu dòng, mỗi dòng chứa cột `data TEXT` là JSON. `fetchall()` sẽ dựng toàn bộ trong RAM trước khi chèn dòng đầu tiên.

**Patch — stream theo lô:**

```python
            cur = sconn.execute(f"SELECT {col_list} FROM {table}")
            while True:
                chunk = cur.fetchmany(BATCH)
                if not chunk:
                    break
                pgcur.executemany(insert_sql, [tuple(r[c] for c in cols) for r in chunk])
```

Đồng thời mở **một** cursor PG dùng lại cho cả bảng thay vì `pconn.cursor()` mới mỗi lô.

---

### 🟠 M6 — Không có `prune_message_queue_postgres()`

`app.py:307-310`:

```python
    # Dọn hàng đợi tin nhắn: xoá tin đã giao cũ, dead-letter tin kẹt quá lâu.
    # Chỉ chạy trên SQLite — bản PostgreSQL dùng job riêng.
    if CONFIG.db_backend != "postgres":
        prune_message_queue()
```

Nhưng "job riêng" đó **không tồn tại**. `db_init_postgres.py` chỉ định nghĩa 2 hàm: `init_db_postgres()` và `prune_old_mutations_postgres()`. Không có `prune_message_queue_postgres`.

Cơ chế dead-letter được viết ra chính xác để chặn sự cố **1.173 tin nhắn kẹt ngày 11/08** (ghi trong docstring `db_init.py:500`). Sau khi cutover sang PG, cơ chế đó biến mất hoàn toàn.

**Patch — thêm vào `db_init_postgres.py`:**

```python
def prune_message_queue_postgres(delivered_days: int = 7, stuck_days: int = 3) -> int:
    """Bản PostgreSQL của prune_message_queue — xem db_init.py:491 để biết lý do."""
    from datetime import datetime, timezone, timedelta

    now = datetime.now(timezone.utc)
    delivered_cutoff = (now - timedelta(days=delivered_days)).isoformat()
    stuck_cutoff     = (now - timedelta(days=stuck_days)).isoformat()

    with pg_connection() as conn:
        cur = conn.execute(
            "DELETE FROM message_queue "
            "WHERE delivered_at IS NOT NULL AND delivered_at < %s",
            (delivered_cutoff,),
        )
        deleted = cur.rowcount

        cur = conn.execute(
            "UPDATE message_queue SET dead_lettered_at = %s, "
            "       last_error = COALESCE(last_error, 'stuck_too_long') "
            "WHERE delivered_at IS NULL AND dead_lettered_at IS NULL "
            "  AND sent_at < %s",
            (now.isoformat(), stuck_cutoff),
        )
        dead = cur.rowcount
        conn.commit()

    if deleted or dead:
        print(f"🧹 [PG][MSG-QUEUE] Xoá {deleted} tin đã giao cũ, dead-letter {dead} tin kẹt.")
    return deleted + dead
```

Rồi trong `db_init.py:prune_message_queue()` thêm nhánh chuyển hướng giống hệt cách `prune_old_mutations` đang làm, và **bỏ điều kiện `if CONFIG.db_backend != "postgres"` ở `app.py`**:

```python
def prune_message_queue(delivered_days: int = 7, stuck_days: int = 3) -> int:
    from server_config import CONFIG
    if CONFIG.db_backend == "postgres":
        from db_init_postgres import prune_message_queue_postgres
        return prune_message_queue_postgres(delivered_days, stuck_days)
    ...
```

> **Đồng thời sửa luôn P3 (đã nêu ở báo cáo tổng):** cả hai hàm `prune_*` hiện chỉ chạy **một lần lúc server start**. Thêm một task định kỳ trong `lifespan()`, cạnh `_peer_sync_loop`:
>
> ```python
> async def _maintenance_loop():
>     while True:
>         await asyncio.sleep(24 * 3600)
>         try:
>             prune_old_mutations(days=30)
>             prune_message_queue()
>         except Exception as e:
>             print(f"⚠️  [MAINT] Lỗi job dọn dẹp: {e}")
> ```

---

### 🟡 M7 — M10 (gộp)

| ID | Sửa |
|---|---|
| **M7** | Thêm `AND table_schema = 'public'` vào truy vấn `information_schema.columns` trong `_pg_columns()` |
| **M8** | Thêm cờ `--dry-run` (chạy pre-flight + đếm, không chèn) và `--verify` (chỉ so `COUNT(*)` hai bên). Thêm kiểm tra sơ bộ "server đã dừng chưa" bằng cách thử `GET /health` tới `127.0.0.1:8080` và cảnh báo nếu còn trả lời |
| **M9** | Cutover phải copy cả `<data_dir>\uploads\` (file đính kèm nằm **trên đĩa**, không nằm trong DB — `routers/attachments.py:15`). Đưa vào checklist §3, không phải vào script |
| **M10** | Đã xử lý trong `_preflight()` ở M3 (kiểm tra `typeof()`) |

---

## 3. Lộ trình thực thi

### Giai đoạn 0 — Sửa code ✅ HOÀN THÀNH 26/08/2026

| # | Việc | File | Trạng thái |
|---|---|---|---|
| 0.1 | Bổ sung 4 bảng vào `TABLES` | `migrate_to_postgres.py` | ✅ |
| 0.2 | Thêm `_assert_table_coverage()` | `migrate_to_postgres.py` | ✅ |
| 0.3 | Thay đếm giả bằng `COUNT(*)` hai đầu + trả exit code ≠ 0 khi lệch | `migrate_to_postgres.py` | ✅ |
| 0.4 | Thêm `_preflight()` (seq NULL, NOT NULL, typeof) | `migrate_to_postgres.py` | ✅ |
| 0.5 | Đổi `dead_lettered_at` → `TEXT` + `ALTER` bổ sung | `db_init_postgres.py` | ✅ |
| 0.6 | Stream `fetchmany()` thay `fetchall()`, dùng lại cursor | `migrate_to_postgres.py` | ✅ |
| 0.7 | Viết `prune_message_queue_postgres()` + chuyển hướng + bỏ điều kiện ở `app.py` | `db_init_postgres.py`, `db_init.py`, `app.py` | ✅ |
| 0.8 | `_maintenance_loop()` chạy prune mỗi 24h | `app.py` | ✅ |
| 0.9 | `--dry-run` / `--verify` + cảnh báo server đang chạy | `migrate_to_postgres.py` | ✅ |
| 0.10 | `table_schema='public'` | `migrate_to_postgres.py` | ✅ |
| **0.11** | `_assert_source_coverage()` + `NOT_MIGRATED` — chốt chặn chiều ngược (R1) | `migrate_to_postgres.py` | ✅ |
| **0.12** | Chạy kiểm tra độ phủ ở `--dry-run`; cảnh báo bảng rỗng (R2, R3) | `migrate_to_postgres.py` | ✅ |
| **0.13** | `_row_value()` thay guard hỏng (R5) | `migrate_to_postgres.py` | ✅ |
| **0.14** | Bọc `ALTER COLUMN TYPE` trong khối `DO` có điều kiện (R6) | `db_init_postgres.py` | ✅ |
| **0.15** | **Chặn** khi server đang chạy + cờ `--force`; quy trình khôi phục khi lỗi giữa chừng (R7) | `migrate_to_postgres.py`, 2 guide | ✅ |
| **0.16** | Smoke test T7 (peer-sync PG↔SQLite), T11 (collation), hồi quy M1 (R4) | 2 guide | ✅ |

**Điều kiện hoàn thành Giai đoạn 0 — đã đạt:** `--dry-run` chạy sạch, pre-flight chặn đúng khi có dữ liệu xấu, cả hai chốt chặn độ phủ hoạt động ở cả hai chiều (có test).

> ⚠️ **Một điều kiện CHƯA đạt:** mới chỉ chạy `--dry-run` trên **DB dev 180 dòng**, trong đó `device_tokens`, `employee_pins`, `work_sessions` đều **rỗng** — đúng những bảng M1 từng bỏ sót. Trên dữ liệu này, **bản script chưa vá cũng sẽ báo thành công**. Việc đầu tiên của Giai đoạn 1 là chạy lại trên bản copy DB production có dữ liệu thật ở 4 bảng đó.

---

### Giai đoạn 1 — Dựng staging & migrate thử (2 ngày)

```bash
# 1. PostgreSQL 16 (Docker cho nhanh, hoặc cài native trên Windows)
docker run -d --name izii-pg -e POSTGRES_PASSWORD=matkhau \
  -e POSTGRES_USER=izii -e POSTGRES_DB=iziiapp \
  -p 5432:5432 postgres:16

# 2. Cài driver
pip install "psycopg[binary,pool]" --break-system-packages

# 3. Bỏ comment trong server/requirements.txt:
#    psycopg[binary,pool]>=3.1

# 4. .env — CHƯA đổi IZIIAPP_DB_BACKEND
IZIIAPP_PG_DSN=postgresql://izii:matkhau@127.0.0.1:5432/iziiapp

# 5. Chạy trên BẢN COPY của DB production, không phải bản gốc
copy "%LOCALAPPDATA%\iZiiApp\server\iziiapp.db" D:\staging\iziiapp.db
set IZIIAPP_SERVER_DB_PATH=D:\staging\iziiapp.db
cd server && python migrate_to_postgres.py --dry-run
python migrate_to_postgres.py
```

**Nghiệm thu Giai đoạn 1:**

- [ ] `COUNT(*)` khớp **cả 13 bảng** (script tự so, exit code = 0)
- [ ] `SELECT MAX(seq) FROM sync_mutations` ở PG **bằng đúng** giá trị bên SQLite
- [ ] `SELECT nextval(pg_get_serial_sequence('sync_mutations','seq'))` trả `MAX(seq) + 1`
- [ ] `SELECT COUNT(*) FROM device_tokens` > 0 *(bảng trước đây bị bỏ sót — đây là test hồi quy cho M1)*
- [ ] Bảng `schema_migrations` có đủ `001_purge_naive_timestamps`, `002_backfill_mutation_seq`

---

### Giai đoạn 2 — Chạy app trên PostgreSQL (3 ngày)

```bash
IZIIAPP_DB_BACKEND=postgres
```

**Kịch bản test bắt buộc** — mỗi cái nhắm vào một đoạn SQL thô đã rẽ nhánh backend:

| # | Kịch bản | Nhắm vào | Kỳ vọng |
|---|---|---|---|
| T1 | Enroll một thiết bị mới | `enrollment.py:135` `INSERT OR REPLACE` → `ON CONFLICT` | Thiết bị xuất hiện trong `devices` + `device_tokens` |
| T2 | Enroll **lại** đúng thiết bị đó | Nhánh upsert | Không tạo dòng trùng, `issued_at` được cập nhật |
| T3 | Đặt PIN nhân viên, rồi đặt lại | `sessions.py:492` | Chỉ một dòng trong `employee_pins`, hash mới |
| T4 | Bắt đầu & kết thúc một phiên làm việc | `work_sessions` | `started_at` / `ended_at` đúng |
| T5 | Sync mutation từ client, kiểm tra `seq` | BIGSERIAL cấp số | `seq` tăng đơn điệu, **không đụng** số cũ |
| T6 | Delta pull `?since=<seq>` | Con trỏ đồng bộ | Trả đúng tập mutation, không trùng, không sót |
| T7 | Peer-sync giữa 2 node (1 PG, 1 SQLite) | Tương thích mesh hỗn hợp | Mutation chạy được cả hai chiều |
| T8 | Gửi tin E2EE, để kẹt 4 ngày (chỉnh cutoff), chạy prune | **M6** | Tin được dead-letter, không kẹt vô hạn |
| T9 | Upload file đính kèm | `attachments.py` | File nằm ở `<data_dir>/uploads`, link mở được |
| T10 | Webhook fail → dead letter | `webhook_dead_letters` | Ghi nhận đúng |
| T11 | Sắp xếp danh sách nhân viên có dấu tiếng Việt | **Collation** | So sánh thứ tự với bản SQLite — **dự kiến sẽ khác**, cần chốt chấp nhận hay không |
| T12 | Restart server nhiều lần | `init_db_postgres()` idempotent | Không lỗi, không nhân bản |

> **T7 rất quan trọng và dễ bị bỏ qua:** kiến trúc mesh nhiều plant nghĩa là sẽ có giai đoạn **node M1 chạy PostgreSQL còn M2 vẫn SQLite**. Không thể cutover cả 3 nhà máy trong một đêm. Peer-sync phải chạy được ở cấu hình hỗn hợp — nếu không, lộ trình §3 phải đổi thành big-bang, rủi ro cao hơn hẳn.

**Đo hiệu năng song song** (cùng workload, hai backend):

| Chỉ số | Kỳ vọng |
|---|---|
| Latency một request đơn lẻ | **Tăng nhẹ** (~1-5 ms do TCP + xác thực) — bình thường |
| Throughput ghi đồng thời | **Tăng rõ rệt** — đây là lý do duy nhất để đổi |
| `database is locked` | **Về 0** |

Nếu throughput ghi đồng thời **không** tăng, dừng lại và tìm nguyên nhân (pool quá nhỏ? `pg_pool_max=10` mặc định có thể thấp) trước khi cutover.

---

### Giai đoạn 3 — Cutover production (1 ngày / node)

**Nguyên tắc: từng node một, không đồng loạt.** Bắt đầu bằng node ít rủi ro nhất (Cool Room), kết thúc bằng node bận nhất.

```
[ ] T-7 ngày : Thông báo cửa sổ bảo trì cho vận hành
[ ] T-1 ngày : Backup đầy đủ (DB + uploads/ + .env + TLS certs) — xem plan/database/extend_report.md §1
[ ] T-1 ngày : Dựng sẵn PostgreSQL trên node, test kết nối từ server
[ ] T-0  :
     1. Dừng dịch vụ Windows (NSSM) — XÁC NHẬN tiến trình đã tắt hẳn
     2. Backup lần cuối: VACUUM INTO + copy uploads/
     3. python migrate_to_postgres.py            # exit code phải = 0
     4. python migrate_to_postgres.py --verify   # so COUNT(*) lần hai
     5. Đổi .env: IZIIAPP_DB_BACKEND=postgres
     6. Khởi động dịch vụ
     7. Chạy smoke test T1, T3, T5, T6, T9
     8. Theo dõi log 30 phút — không có traceback
[ ] T+1 ngày : Kiểm tra job prune đã chạy (log có dòng 🧹 [PG])
[ ] T+7 ngày : Xác nhận ổn định → cutover node tiếp theo
[ ] T+30 ngày: Mới được xoá file SQLite cũ. KHÔNG xoá sớm hơn.
```

---

### Giai đoạn 4 — Sau khi ổn định (không làm cùng lúc cutover)

Chỉ bắt đầu khi **toàn bộ node** đã chạy PostgreSQL ổn định ≥ 2 tuần:

| # | Việc | Lợi ích |
|---|---|---|
| 4.1 | Migration `TEXT` → `TIMESTAMPTZ` cho **mọi** cột thời gian | Index range hiệu quả, chuẩn bị partitioning, hết bug so sánh chuỗi |
| 4.2 | `data TEXT` → `JSONB` + GIN index trên `sync_mutations` | Query được theo nội dung mutation |
| 4.3 | `UNIQUE (origin_server_id, seq)` | Chặn trùng seq — hiện đang **không có ràng buộc nào** |
| 4.4 | Thêm foreign key (`notifications.user_id`, `message_queue.recipient_device_id`…) | SQLite mặc định tắt FK enforcement nên trước giờ không có ý nghĩa; PG thì có |
| 4.5 | Partition `sync_mutations` theo RANGE trên `server_received_at` | Prune 30 ngày thành `DROP PARTITION` — tức thì thay vì `DELETE` quét bảng. **Cần 4.1 xong trước** |
| 4.6 | Chuyển sang **Alembic**, xoá cơ chế `CREATE TABLE IF NOT EXISTS` + `ALTER` thủ công | Chấm dứt drift giữa hai file schema — nguyên nhân gốc của M1 và M4 |
| 4.7 | Bật `pg_stat_statements`, `pgBackRest` + WAL archiving | RPO xuống dưới 1 phút |
| 4.8 | Read replica + pool thứ hai read-only cho báo cáo/dashboard | Báo cáo nặng không làm chậm ghi |

> **4.6 là việc quan trọng nhất trong giai đoạn này.** M1 và M4 không phải lỗi ngẫu nhiên — chúng là hệ quả tất yếu của việc duy trì **hai file schema sửa tay song song**. Chừng nào `db_init.py` và `db_init_postgres.py` còn tồn tại độc lập, drift sẽ tái diễn.

---

## 4. Rollback

Nếu phải quay về SQLite trong vòng 30 ngày:

```
1. Dừng dịch vụ
2. Đổi .env: IZIIAPP_DB_BACKEND=sqlite
3. Khôi phục file SQLite từ backup T-0
4. Khởi động lại
```

**Cái giá:** mọi thay đổi phát sinh trên PostgreSQL kể từ lúc cutover **sẽ mất**. Không có script migrate ngược.

**Ba lưu ý:**

- **`sync_sequence` sẽ lệch.** SQLite dùng bảng đếm thủ công; PostgreSQL dùng BIGSERIAL. Sau khi rollback, bộ đếm SQLite vẫn ở giá trị cũ trong khi client có thể đã thấy `seq` cao hơn (do PG cấp). Phải chạy tay:
  ```sql
  UPDATE sync_sequence
  SET current = (SELECT COALESCE(MAX(seq), 0) FROM sync_mutations)
  WHERE name = 'mutation';
  ```
- **Mesh phải đồng bộ trạng thái.** Nếu node M1 rollback mà M2 vẫn PG, con trỏ `last_synced_seq` trong `known_servers` có thể trỏ vượt quá dữ liệu M1 đang có. Reset con trỏ của các peer trỏ tới node vừa rollback.
- **Trên 30 ngày thì rollback không còn là lựa chọn** — dữ liệu mới đã tích luỹ quá nhiều. Lúc đó chỉ còn đường sửa tới.

---

## 5. Rủi ro tồn đọng

| # | Rủi ro | Mức | Giảm thiểu |
|---|---|---|---|
| E1 | Collation tiếng Việt: `ORDER BY` tên nhân viên ra thứ tự khác SQLite | 🟠 | T11. Chốt collation (`en_US.UTF-8` hoặc ICU `vi-VN`) **trước** cutover — đổi sau phải rebuild index |
| E2 | Peer-sync giữa node PG và node SQLite chưa từng được test | 🟠 | T7 là điều kiện tiên quyết của lộ trình cutover từng node |
| E3 | `pg_pool_max=10` mặc định có thể thấp cho nhiều Uvicorn worker | 🟡 | Đo ở Giai đoạn 2; công thức thô: `workers × 2 + 5` |
| E4 | Backup PostgreSQL chưa được thiết lập | 🔴 | **Cutover mà chưa có `pg_dump` định kỳ = tự nguyện mất dữ liệu.** Phải xong trước Giai đoạn 3 |
| E5 | IT nhà máy chưa quen vận hành PostgreSQL | 🟠 | Runbook 1 trang: start/stop, kiểm tra dung lượng, restore từ dump, đọc log |
| E6 | Drift schema tái diễn sau khi sửa xong M1/M4 | 🟠 | 4.6 (Alembic) + CI chạy test suite trên **cả hai** backend |

---

## 6. Việc cần làm — theo thứ tự

**Giai đoạn 0 (0.1 → 0.16) đã xong.** Danh sách dưới đây là phần còn lại.

| Ưu tiên | Việc | Công sức | Chặn cái gì |
|---|---|---|---|
| **1** | Chạy lại `--dry-run` + migrate thử trên **bản copy DB production** (không phải DB dev) | 0,5 ngày | Chặn mọi nghiệm thu — xem cảnh báo ở Giai đoạn 0 |
| **2** | E4 — Backup `pg_dump` / `pgBackRest` định kỳ | 0,5 ngày | 🔴 Chặn Giai đoạn 3 |
| **3** | Giai đoạn 1 — dựng PostgreSQL staging + migrate thử + nghiệm thu 5 mục | 2 ngày | — |
| **4** | Giai đoạn 2 — chạy T1 → T12; **T7 và T11 là bắt buộc** | 3 ngày | T7 quyết định có cutover từng node được không |
| **5** | Đo hiệu năng song song hai backend; chỉnh `IZIIAPP_PG_POOL_MAX` | 0,5 ngày | Chặn Giai đoạn 3 |
| **6** | Giai đoạn 3 — cutover từng node, bắt đầu từ Cool Room | 1 ngày/node | — |
| **7** | **4.6 — Alembic + một nguồn DDL duy nhất** | 2-3 ngày | Xử lý *nguyên nhân gốc* của M1, M4, R1 |
| **8** | Giai đoạn 4 còn lại — TIMESTAMPTZ, JSONB, `UNIQUE(origin_server_id, seq)`, FK, partition | 2-3 tuần | — |

> Mục **7** đáng được nâng ưu tiên nếu schema còn phải đổi trong vài tháng tới. M1, M4 và R1 đều là **cùng một lỗi lặp lại ba lần** dưới ba hình dạng khác nhau, và cả ba đều bắt nguồn từ việc `db_init.py` với `db_init_postgres.py` được duy trì song song bằng tay. Các chốt chặn vừa thêm bắt được triệu chứng, nhưng chúng chỉ là lưới an toàn — không phải cách chữa.

---

*Plan dựa trên source code `izii_app/server`. M1-M10 phát hiện ngày 25/08, R1-R7 phát hiện ngày 26/08 — tất cả được kiểm chứng bằng đối chiếu tự động giữa `db_init.py`, `db_init_postgres.py` và `migrate_to_postgres.py`, cộng test chạy thật trên DB SQLite dựng sẵn, không phải suy đoán.*
