# Hướng Dẫn Nâng Cấp Cơ Sở Dữ Liệu PostgreSQL Cho iZiiServer
*(PostgreSQL Database Upgrade & Migration Guide)*

Tài liệu hướng dẫn chi tiết quy trình chuẩn bị, cấu hình, sao lưu, thực thi nâng cấp và nghiệm thu Cơ sở dữ liệu **PostgreSQL** trên máy chủ **iZiiServer** (áp dụng cho cả **Central Node** đám mây/máy chủ trung tâm và **Edge Node** tại nông trại/chi nhánh theo kế hoạch kiến trúc V4.2.0 - Q5/P1.11).

---

## 📑 Mục Lục
1. [Tổng Quan & Phạm Vi Nâng Cấp](#1-tổng-quan--phạm-vi-nâng-cấp)
2. [Yêu Cầu Hạ Tầng & Chuẩn Bị (Prerequisites)](#2-yêu-cầu-hạ-tầng--chuẩn-bị-prerequisites)
3. [Tối Ưu Cấu Hình Tham Số PostgreSQL (`postgresql.conf`)](#3-tối-ưu-cấu-hình-tham-số-postgresql-postgresqlconf)
4. [Quy Trình Sao Lưu Dữ Liệu An Toàn (Pre-Upgrade Backup)](#4-quy-trình-sao-lưu-dữ-liệu-an-toàn-pre-upgrade-backup)
5. [Các Bước Thực Hiện Nâng Cấp Database (Step-by-Step)](#5-các-bước-thực-hiện-nâng-cấp-database-step-by-step)
6. [Di Trú Dữ Liệu Cũ & Đối Chiếu Tính Toàn Vẹn (Data Migration & Parity)](#6-di-trú-dữ-liệu-cũ--đối-chiếu-tính-toàn-vẹn-data-migration--parity)
7. [Kiểm Thử & Nghiệm Thu Sau Nâng Cấp (Post-Upgrade Verification)](#7-kiểm-thử--nghiệm-thu-sau-nâng-cấp-post-upgrade-verification)
8. [Vận Hành & Bảo Trì Định Kỳ (Housekeeping)](#8-vận-hành--bảo-trì-định-kỳ-housekeeping)
9. [Xử Lý Sự Cố & Kịch Bản Rollback (Troubleshooting & Rollback)](#9-xử-lý-sự-cố--kịch-bản-rollback-troubleshooting--rollback)

---

## 🎯 1. Tổng Quan & Phạm Vi Nâng Cấp

### 1.1 Bối cảnh kiến trúc
- **Trước nâng cấp**: Server hỗ trợ song song SQLite (`data/iziiapp.db`) và PostgreSQL sơ khai. SQLite gặp hạn chế lớn khi nhiều thiết bị đẩy mutation đồng thời (lỗi file lock, phải tự quản bộ đếm sequence).
- **Sau nâng cấp (Q5 / P1.11)**:
  - Chuẩn hoá **toàn bộ server (Central & Edge)** sang **PostgreSQL 16+**. SQLite chỉ còn duy nhất trên thiết bị client (Flutter / Drift v30).
  - Tận dụng `BIGSERIAL` cho `seq` tăng dần an toàn tuyệt đối với nhiều client kết nối.
  - Tận dụng `jsonb_populate_record` cho CDC/Read-model projection.
  - Áp dụng phân quyền đa người thuê (**Row-Level Security - RLS**) và tìm kiếm tiếng Việt toàn văn (**Full-Text Search với `unaccent`**).
  - Mở rộng hệ thống Module động (**Module System & Model Registry** - Phase 2).

### 1.2 Các phiên bản Schema & Migrations được nạp
1. **Core Schema (`0001_initial_schema.sql`)**: `sync_mutations`, `known_servers`, `devices`, `message_queue`, `notifications`, `device_tokens`, `work_sessions`, `employee_pins`...
2. **Phase 5 Domain (`0002_phase5_domain.sql`)**: `mushroom_job_types`, `mushroom_attendance_events`, `mushroom_daily_timesheets`, `mushroom_shifts`, `mushroom_job_safety_configs`, `mushroom_safety_checkin_logs`, `grow_rooms`, `mushroom_jobs`, `tasks`...
3. **Phase 1 Audit & RLS (`0003_audit_and_rls.sql`)**: Audit fields (`tenant_id`, `created_at`, `updated_at`, `is_seed`), chính sách bảo vệ RLS `tenant_isolation_policy`, cấu hình FTS tiếng Việt `vi`.
4. **Phase 2 Module System (`0004_module_system.sql`)**: `tenant_modules`, `model_registry`, `field_registry`.

---

## 🖥️ 2. Yêu Cầu Hạ Tầng & Chuẩn Bị (Prerequisites)

### 2.1 Phiên bản phần mềm
- **PostgreSQL**: Phiên bản **16.x** trở lên (tối thiểu 15.x).
- **Python**: Phiên bản **3.11+** (có cài sẵn `psycopg`, `psycopg-pool`).
- **Extensions PostgreSQL**:
  - `unaccent` (Bắt buộc — hỗ trợ tìm kiếm tiếng Việt không dấu).
  - `pgcrypto` (Khuyến nghị — hỗ trợ UUID và mã hóa mật khẩu).
  - `vector` / `pgvector` (Khuyến nghị nếu triển khai Phase 4 AI Semantic Search).

### 2.2 Tạo Database và User chuyên dụng
Đăng nhập vào PostgreSQL bằng tài khoản `postgres` (hoặc tài khoản quản trị):

```sql
-- 1. Tạo User riêng cho ứng dụng (thay đổi mật khẩu mạnh)
CREATE USER izii_user WITH PASSWORD 'IziiSecurePassword2026!@#';

-- 2. Tạo Database
CREATE DATABASE "iZiiApp" WITH OWNER izii_user ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';

-- 3. Cấp quyền
GRANT ALL PRIVILEGES ON DATABASE "iZiiApp" TO izii_user;

-- Kết nối vào database iZiiApp
\c iZiiApp

-- 4. Kích hoạt Extension unaccent (cần quyền superuser thực hiện 1 lần)
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 5. Cấp quyền sử dụng schema public cho izii_user
GRANT ALL ON SCHEMA public TO izii_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO izii_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO izii_user;
```

---

## ⚙️ 3. Tối Ưu Cấu Hình Tham Số PostgreSQL (`postgresql.conf`)

Tùy theo cấu hình phần cứng của máy chủ, áp dụng các tham số tối ưu sau:

### 3.1 Central Node (Máy chủ trung tâm / Cloud, RAM 16GB - 32GB)
Mở file `postgresql.conf` (hoặc tạo file cấu hình con `conf.d/iziiapp.conf`):

```ini
# Memory Configuration
shared_buffers = 8GB                  # 25% tổng RAM
work_mem = 48MB                       # Bộ nhớ sắp xếp cho mỗi query
maintenance_work_mem = 2GB            # Cần thiết khi tạo index HNSW / Fulltext
effective_cache_size = 24GB           # Ước tính cache của OS (75% RAM)

# Connections & Concurrency
max_connections = 300                 # Kết hợp Connection Pooling (PgBouncer)
max_worker_processes = 8
max_parallel_workers_per_gather = 4

# Write-Ahead Log (WAL) & Checkpoints
wal_level = replica
checkpoint_completion_target = 0.9
max_wal_size = 16GB
min_wal_size = 2GB

# Network & Search
listen_addresses = '*'
```

### 3.2 Edge Node (Máy trạm tại Site / Nông trại, RAM 8GB - 16GB)

```ini
shared_buffers = 2GB                  # 25% RAM 8GB
work_mem = 16MB
maintenance_work_mem = 512MB
effective_cache_size = 6GB
max_connections = 100
checkpoint_completion_target = 0.9
max_wal_size = 4GB
min_wal_size = 512MB
```

*Sau khi sửa `postgresql.conf`, khởi động lại dịch vụ:*
```bash
# Windows
Restart-Service postgresql-x64-16

# Linux
sudo systemctl restart postgresql
```

---

## 💾 4. Quy Trình Sao Lưu Dữ Liệu An Toàn (Pre-Upgrade Backup)

> [!CAUTION]
> **Quy tắc bất di bất dịch:** KHÔNG BAO GIỜ thực hiện nâng cấp hoặc chạy migration trên cơ sở dữ liệu production nếu chưa tạo ít nhất một bản backup được kiểm tra hợp lệ!

### 4.1 Trường hợp 1: Máy chủ đang chạy PostgreSQL
Sử dụng `pg_dump` để xuất dữ liệu ra file nén nhị phân:

```powershell
# Đặt biến môi trường mật khẩu tạm thời
$env:PGPASSWORD="IziiSecurePassword2026!@#"

# Tạo bản sao lưu toàn bộ (Schema + Data) định dạng nén Custom
pg_dump -h 127.0.0.1 -p 5432 -U izii_user -d iZiiApp -Fc -b -v -f "backup_izii_pre_upgrade_$(Get-Date -Format 'yyyyMMdd_HHmmss').dump"

# Tạo bản sao lưu Schema dạng văn bản rõ để đối chiếu
pg_dump -h 127.0.0.1 -p 5432 -U izii_user -d iZiiApp --schema-only -f "schema_pre_upgrade_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
```

### 4.2 Trường hợp 2: Edge Node chuyển đổi từ SQLite sang PostgreSQL (Q5)
Nếu Edge Node đang chạy SQLite (`data/iziiapp.db`):
1. Dừng tiến trình server: `Stop-Process -Name "izii_server" -Force`
2. Tạo bản sao lưu file SQLite:
```powershell
$backupDir = "server/data/backups/sqlite_pre_pg_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force
Copy-Item "server/data/iziiapp.db*" -Destination $backupDir -Verbose
```
> [!IMPORTANT]
> Bản lưu trữ SQLite này **phải được giữ tối thiểu 30 ngày** để đối chiếu và dự phòng tình huống rollback.

---

## 🚀 5. Các Bước Thực Hiện Nâng Cấp Database (Step-by-Step)

### Bước 5.1: Cấu hình Biến Môi Trường (`.env`)
Mở hoặc tạo file `.env` tại thư mục máy chủ (hoặc thư mục ổn định `AppData/Local/izii_server/data/.env`):

```ini
# Chuyển sang backend PostgreSQL
IZIIAPP_DB_BACKEND=postgres

# Chuỗi kết nối PostgreSQL (Connection DSN)
IZIIAPP_DB_URL=postgresql://izii_user:IziiSecurePassword2026!@#@127.0.0.1:5432/iZiiApp

# Cấu hình Connection Pool
IZIIAPP_PG_MIN_CONN=2
IZIIAPP_PG_MAX_CONN=20

# Phân tách bí mật bảo mật theo F10/F11 (PHẢI KHÁC NHAU)
IZIIAPP_SERVER_SECRET=a8f9c2d1e0b34759281a6c5e4d3f2b1a
IZIIAPP_ADMIN_SECRET=c7b1e4f9203847561a2b3c4d5e6f7a8b
IZIIAPP_WS_SECRET=e5d4c3b2a10987654321fedcba098765

# Định danh Node
IZIIAPP_SERVER_ID=server-central-01
IZIIAPP_ZONE=CENTRAL
```

### Bước 5.2: Khởi tạo Cấu trúc Bảng & Phase 1 - 2
Chạy lệnh khởi tạo schema PostgreSQL thông qua Python:

```powershell
# Chuyển vào thư mục server
cd server

# Kích hoạt môi trường ảo (nếu có)
.\venv\Scripts\Activate.ps1

# Chạy module khởi tạo database postgres
python -c "from db_init_postgres import init_db_postgres; init_db_postgres()"
```

Output kỳ vọng:
```text
⚙️  [CONFIG] Đã nạp cấu hình từ .../.env
🐘 [PG] Schema PostgreSQL và cấu hình Phase 1 + Phase 2 đã sẵn sàng.
```

Lệnh này sẽ tự động:
- Tạo các bảng lõi và chỉ mục tối ưu (`sync_mutations`, `devices`, `message_queue`...).
- Thực thi các lệnh `ALTER TABLE ADD COLUMN IF NOT EXISTS` an toàn.
- Kích hoạt Full-text Search Tiếng Việt (`CREATE TEXT SEARCH CONFIGURATION vi`).
- Thêm các cột Audit (`tenant_id`, `created_at`, `updated_at`, `is_seed`...).
- Bật bảo vệ **Row-Level Security (RLS)** trên tất cả 14 bảng domain.
- Khởi tạo bảng danh mục Module (`tenant_modules`, `model_registry`, `field_registry`).

### Bước 5.3: Thực thi Bộ Điều Phối Migration (`migrations/runner.py`)
Hệ thống sử dụng Versioned Migration Runner để quản lý các thay đổi schema có thứ tự và không chạy trùng lặp:

1. **Kiểm tra trạng thái các bản migration**:
```powershell
python migrations/runner.py --status
```
Output:
```text
⚙️  DB Backend: postgres

Migration Status:
  ⏳ Pending     0001_initial_schema.sql
  ⏳ Pending     0002_phase5_domain.sql
  ⏳ Pending     0003_audit_and_rls.sql
  ⏳ Pending     0004_module_system.sql
```

2. **Thực thi áp dụng tất cả các bản migration**:
```powershell
python migrations/runner.py --migrate
```
Output:
```text
Applying pending migrations...
✅ [MIGRATION] Applied: 0001_initial_schema.sql
✅ [MIGRATION] Applied: 0002_phase5_domain.sql
✅ [MIGRATION] Applied: 0003_audit_and_rls.sql
✅ [MIGRATION] Applied: 0004_module_system.sql
Successfully applied 4 migration(s).
```

3. **Xác nhận lại trạng thái**:
```powershell
python migrations/runner.py --status
```
Kết quả tất cả phải hiển thị `✅ Applied`.

### Bước 5.4: Nâng Cấp Tự Động Toàn Diện trên Ubuntu (`upgrade_ubuntu.sh`)
Nếu máy chủ chạy hệ điều hành **Ubuntu / Debian Linux**, bạn có thể sử dụng file script tự động hóa 1-click [`server/upgrade_ubuntu.sh`](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/upgrade_ubuntu.sh) để thực hiện trọn gói toàn bộ chu trình nâng cấp:

```bash
# 1. Cấp quyền thực thi
chmod +x server/upgrade_ubuntu.sh

# 2. Chạy nâng cấp tự động
cd server
./upgrade_ubuntu.sh

# Các tuỳ chọn nâng cao (nếu cần):
# ./upgrade_ubuntu.sh --skip-backup     (bỏ qua bước sao lưu nếu đã sao lưu trước đó)
# ./upgrade_ubuntu.sh --skip-tests      (bỏ qua chạy unittest)
# ./upgrade_ubuntu.sh --no-pull         (không pull mã nguồn mới từ git)
# ./upgrade_ubuntu.sh --service-name my_service
```

Script này tự động:
- Kiểm tra môi trường Python 3.11+.
- Dừng dịch vụ `iziiserver.service` nhẹ nhàng.
- Sao lưu toàn bộ cấu hình `.env`, thư mục `data/` và tạo bản dump PostgreSQL (`pg_dump`).
- Nạp migration tuần tự và khởi tạo schema Phase 1 - 2.
- Chạy toàn bộ 33 unit test; nếu có lỗi hồi quy sẽ tự động cảnh báo và hướng dẫn rollback.
- Khởi động lại dịch vụ qua systemd và gọi kiểm tra `/health` tự động.

---

## 🔄 6. Di Trú Dữ Liệu Cũ & Đối Chiếu Tính Toàn Vẹn (Data Migration & Parity)

Khi chuyển từ cơ sở dữ liệu cũ (SQLite hoặc phiên bản Postgres cũ) sang PostgreSQL mới:

### 6.1 Đồng bộ Sequence `BIGSERIAL`
Nếu bạn vừa import dữ liệu bảng `sync_mutations` từ bên ngoài, sequence của cột `seq` có thể chưa được cập nhật giá trị lớn nhất:

```sql
-- Cập nhật sequence của bảng sync_mutations khớp với MAX(seq) hiện tại
SELECT setval(
    pg_get_serial_sequence('sync_mutations', 'seq'),
    COALESCE((SELECT MAX(seq) FROM sync_mutations), 0) + 1,
    false
);
```

### 6.2 Đối chiếu số lượng bản ghi (Row Count Parity Check)
Quy tắc: **Khớp số dòng 100%**, không chấp nhận sai lệch dữ liệu.

Chạy truy vấn kiểm tra số dòng trên PostgreSQL:
```sql
SELECT 
    schemaname,
    relname AS table_name,
    n_live_tup AS estimated_rows
FROM pg_stat_user_tables
ORDER BY relname;
```

Hoặc dùng script đếm chính xác:
```sql
SELECT 'sync_mutations' AS tbl, count(*) FROM sync_mutations
UNION ALL SELECT 'mushroom_jobs', count(*) FROM mushroom_jobs
UNION ALL SELECT 'tasks', count(*) FROM tasks
UNION ALL SELECT 'grow_rooms', count(*) FROM grow_rooms
UNION ALL SELECT 'mushroom_daily_timesheets', count(*) FROM mushroom_daily_timesheets
UNION ALL SELECT 'mushroom_safety_checkin_logs', count(*) FROM mushroom_safety_checkin_logs;
```

So sánh kết quả này với số dòng tương ứng trong file backup SQLite cũ.

### 6.3 Kiểm tra dữ liệu rác & Khoá ngoại mồ côi (P0.14 Guard)
Chạy script kiểm tra dữ liệu chuyên dụng:
```powershell
python scripts/inspect_db.py
```
Đảm bảo:
- `mushroom_job_safety_configs missing job_id = 0`
- `mushroom_safety_checkin_logs missing job_id = 0`
- `tasks Untitled and empty project/desc = 0`

---

## ✅ 7. Kiểm Thử & Nghiệm Thu Sau Nâng Cấp (Post-Upgrade Verification)

Sau khi nâng cấp database, thực hiện các bài kiểm thử xác nhận trước khi đưa vào vận hành:

### 7.1 Chạy Toàn Bộ Test Suite Tự Động (33/33 Tests)
```powershell
python -m unittest discover -s tests -p "test_*.py"
```
Kỳ vọng: **Ran 33 tests in ~1.5s - OK**.
Bao gồm:
- 4 bài test bảo mật F11, F12, P0.1c, /sync/record (`test_phase0_security_regression.py`).
- 12 bài test nền tảng Phase 1: Audit, RLS, unaccent FTS (`test_phase1_foundation.py`).
- 10 bài test Module System Phase 2 (`test_phase2_module_system.py`).
- 5 bài test dọn dẹp Phase 5 (`test_phase5_safety_cleanup.py`).
- 2 bài test P0.10 & timesheet.

### 7.2 Kiểm tra Trực Tiếp Endpoint Health & Devices Online
Khởi động server (`python app.py` hoặc `izii_server.exe`):

```powershell
# 1. Kiểm tra trạng thái máy chủ
Invoke-RestMethod -Uri "http://127.0.0.1:8080/health"

# Output chuẩn:
# server_id zone status server_time
# --------- ---- ------ -----------
# server-m1 M1   ok     2026-09-10T...

# 2. Kiểm tra truy vấn thiết bị online (Xác nhận F13 / TIMESTAMPTZ không lỗi)
Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/v1/devices/online"
# Phản hồi 200 OK kèm danh sách JSON []
```

### 7.3 Kiểm tra Cơ Chế Row-Level Security (RLS)
Mở `psql` và kiểm tra xem tenant isolation có hoạt động chính xác không:

```sql
-- Đặt tenant là tenant_a
SET app.tenant_id = 'tenant_a';
INSERT INTO tasks (id, title, tenant_id) VALUES ('t-1', 'Task của Tenant A', 'tenant_a');

-- Chuyển sang tenant_b
SET app.tenant_id = 'tenant_b';
-- Truy vấn này PHẢI trả về 0 dòng
SELECT * FROM tasks WHERE id = 't-1';

-- Chuyển sang tenant * (Super Admin)
SET app.tenant_id = '*';
-- Truy vấn này PHẢI thấy được task t-1
SELECT id, title, tenant_id FROM tasks WHERE id = 't-1';

-- Dọn dẹp bản ghi thử nghiệm
DELETE FROM tasks WHERE id = 't-1';
RESET app.tenant_id;
```

### 7.4 Kiểm tra Tìm Kiếm Tiếng Việt (FTS unaccent)
```sql
SELECT to_tsvector('vi', 'Phòng Nuôi Nấm Số 33') @@ to_tsquery('vi', 'phong & 33');
-- Kết quả trả về: true (Khớp chính xác không phân biệt dấu)
```

---

## 🧹 8. Vận Hành & Bảo Trì Định Kỳ (Housekeeping)

Để duy trì hiệu năng cao trên PostgreSQL, thực hiện các tác vụ định kỳ sau:

### 8.1 Dọn dẹp Mutation cũ và Dead-Letter Queue
Server có tích hợp sẵn 2 hàm dọn dẹp an toàn trong `db_init_postgres.py`:
- `prune_old_mutations_postgres(days=30)`: Xóa các mutation cũ hơn 30 ngày.
- `prune_message_queue_postgres(delivered_days=7, stuck_days=3)`: Dọn tin nhắn E2EE đã giao cũ và đánh dấu tin nhắn bị kẹt quá lâu.

Có thể cấu hình chạy hàng tuần qua script:
```powershell
python -c "from db_init_postgres import prune_old_mutations_postgres, prune_message_queue_postgres; prune_old_mutations_postgres(30); prune_message_queue_postgres(7, 3)"
```

### 8.2 Tối ưu hóa Index & Thống Kê (VACUUM & ANALYZE)
Mặc định PostgreSQL tự động chạy `autovacuum`. Đối với bảng có tần suất ghi cao như `sync_mutations`, thiết lập cấu hình riêng:

```sql
ALTER TABLE sync_mutations SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);
```

Chạy thủ công định kỳ vào cuối tuần:
```sql
VACUUM (VERBOSE, ANALYZE) sync_mutations;
VACUUM (VERBOSE, ANALYZE) message_queue;
```

---

## 🛡️ 9. Xử Lý Sự Cố & Kịch Bản Rollback (Troubleshooting & Rollback)

### 9.1 Các Lỗi Thường Gặp & Cách Khắc Phục

| Triệu chứng | Nguyên nhân | Cách khắc phục |
| :--- | :--- | :--- |
| `FATAL: password authentication failed for user "izii_user"` | Sai mật khẩu hoặc chưa cấu hình file `pg_hba.conf` | Kiểm tra lại chuỗi kết nối `IZIIAPP_DB_URL` trong `.env`. Cập nhật `pg_hba.conf` cấp quyền `scram-sha-256` hoặc `md5` cho IP client. |
| `psycopg.OperationalError: connection refused` | Dịch vụ PostgreSQL chưa chạy hoặc sai cổng 5432 | Kiểm tra `Get-Service postgresql*` hoặc `netstat -ano \| findstr 5432`. |
| `permission denied for schema public` | PostgreSQL 15+ mặc định thu hồi quyền CREATE trên schema public | Chạy: `GRANT ALL ON SCHEMA public TO izii_user;` bằng tài khoản superuser. |
| `text search configuration "vi" does not exist` | Chưa chạy `init_db_postgres()` hoặc thiếu extension `unaccent` | Chạy `CREATE EXTENSION unaccent;` rồi tạo config `vi` theo mục 5.2. |
| `invalid input syntax for type timestamp with time zone` | Trường thời gian lưu chuỗi rỗng `""` thay vì NULL | Đã được xử lý ở F13; đảm bảo dữ liệu cập nhật dùng `TIMESTAMPTZ` an toàn hoặc chuỗi ISO-8601 UTC. |

### 9.2 Kịch Bản Khôi Phục Sự Cố (Rollback Procedure)

Nếu việc nâng cấp trên PostgreSQL thất bại và cần quay trở lại trạng thái trước khi nâng cấp:

#### Khôi phục PostgreSQL từ bản backup:
```powershell
# 1. Dừng tiến trình iZiiServer
Stop-Process -Name "izii_server" -Force

# 2. Xóa và tạo lại Database sạch
dropdb -h 127.0.0.1 -U postgres "iZiiApp"
createdb -h 127.0.0.1 -U postgres -O izii_user "iZiiApp"

# 3. Phục hồi từ file dump đã tạo ở Bước 4.1
pg_restore -h 127.0.0.1 -p 5432 -U izii_user -d iZiiApp -v "backup_izii_pre_upgrade_<timestamp>.dump"

# 4. Khởi động lại iZiiServer
```

#### Khôi phục SQLite tại Edge Node (Nếu cần khẩn cấp):
Nếu Edge Node gặp sự cố mạng hoặc cấu hình tại hiện trường:
1. Sửa lại `.env`:
   ```ini
   IZIIAPP_DB_BACKEND=sqlite
   ```
2. Sao chép lại file `server/data/backups/sqlite_pre_pg_.../iziiapp.db` về lại `server/data/iziiapp.db`.
3. Khởi động lại server: Edge Node sẽ tiếp tục vận hành bình thường ở chế độ SQLite cục bộ mà không làm gián đoạn sản xuất.
