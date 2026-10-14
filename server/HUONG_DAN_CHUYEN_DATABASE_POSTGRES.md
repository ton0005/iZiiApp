# Hướng Dẫn Chi Tiết Chuyển Đổi Dữ Liệu SQLite Sang PostgreSQL
## Complete Guide: Migrating iZiiServer Database to PostgreSQL

**Hệ thống áp dụng:** iZiiApp Server (FastAPI Backend trên Windows)  
**Ngày cập nhật:** 26/08/2026  
**File script thực thi:** `server/migrate_to_postgres.py`  

---

## 📑 MỤC LỤC

1. [Tổng quan & Nguyên tắc an toàn](#1-tổng-quan--nguyên-tắc-an-toàn)
2. [Chuẩn bị trước khi chuyển đổi (Prerequisites)](#2-chuẩn-bị-trước-khi-chuyển-đổi-prerequisites)
3. [Quy trình 8 bước chuyển đổi chuẩn (Step-by-Step)](#3-quy-trình-8-bước-chuyển-đổi-chuẩn-step-by-step)
4. [Kiểm tra sau chuyển đổi (Post-Migration Smoke Test)](#4-kiểm-tra-sau-chuyển-đổi-post-migration-smoke-test)
5. [Quy trình Rollback (Nếu cần quay lại SQLite)](#5-quy-trình-rollback-nếu-cần-quay-lại-sqlite)
6. [Xử lý các lỗi thường gặp (Troubleshooting)](#6-xử-lý-các-lỗi-thường-gặp-troubleshooting)

---

## 1. Tổng quan & Nguyên tắc an toàn

Khi mở rộng quy mô hệ thống iZiiServer từ SQLite sang PostgreSQL (để xử lý tải ghi đồng thời cao, chống khóa file `database is locked`), quy trình chuyển đổi cần đảm bảo:

* **Không mất dữ liệu (Zero Data Loss):** Chuyển toàn bộ 13 bảng nghiệp vụ, token xác thực, tin nhắn, và lịch sử phiên làm việc.
* **Bảo toàn chuỗi sequence (`seq`):** Giữ nguyên số thứ tự đồng bộ `seq` để toàn bộ thiết bị di động (iPhone, iPad, Samsung) không bị mất mốc đồng bộ (cursor).
* **Minh bạch với Client:** Thiết bị di động ngoài hiện trường tiếp tục sử dụng bình thường mà không cần đăng nhập hay cài đặt lại.

---

## 2. Chuẩn bị trước khi chuyển đổi (Prerequisites)

### 2.1 Cài đặt PostgreSQL
* PostgreSQL phiên bản **15 hoặc 16** (cài đặt trực tiếp trên Windows hoặc qua Docker).
* Tạo database và tài khoản quản trị:
```sql
-- Đăng nhập vào PostgreSQL (pgAdmin hoặc psql)
CREATE DATABASE "iZiiApp" WITH ENCODING 'UTF8';
```

### 2.2 Cài đặt thư viện Python kết nối PostgreSQL
Mở **PowerShell** hoặc **Command Prompt** tại máy chủ và chạy:
```powershell
pip install "psycopg[binary,pool]>=3.1"
```

---

## 3. Quy trình 8 bước chuyển đổi chuẩn (Step-by-Step)

```mermaid
flowchart TD
    S1["Bước 1: Sao lưu file SQLite & uploads/"] --> S2["Bước 2: Cấu hình IZIIAPP_PG_DSN trong .env"]
    S2 --> S3["Bước 3: Dừng dịch vụ iZiiServer"]
    S3 --> S4["Bước 4: Chạy kiểm tra thử (--dry-run)"]
    S4 --> S5["Bước 5: Chạy migrate thật"]
    S5 --> S6["Bước 6: Đối soát số dòng (--verify)"]
    S6 --> S7["Bước 7: Kích hoạt IZIIAPP_DB_BACKEND=postgres"]
    S7 --> S8["Bước 8: Khởi động lại Server & Test"]
```

---

### Bước 1: Sao lưu an toàn trước khi thao tác
Tạo một bản sao lưu file SQLite hiện tại và thư mục `uploads/` sang vị trí an toàn (ví dụ ổ `D:\Backup_Pre_Migration`):
```powershell
# Tạo thư mục sao lưu
New-Item -ItemType Directory -Path "D:\Backup_Pre_Migration" -Force

# Sao chép file SQLite (mặc định tại %LOCALAPPDATA%\iZiiApp\server\iziiapp.db)
Copy-Item "$env:LOCALAPPDATA\iZiiApp\server\iziiapp.db" "D:\Backup_Pre_Migration\iziiapp.db" -Force

# Sao chép thư mục tệp đính kèm uploads
Copy-Item "$env:LOCALAPPDATA\iZiiApp\server\uploads" "D:\Backup_Pre_Migration\uploads" -Recurse -Force
```

---

### Bước 2: Cấu hình chuỗi kết nối PostgreSQL trong `.env`
Mở file `server/.env` và điền thông tin kết nối PostgreSQL vào biến `IZIIAPP_PG_DSN`.  
*(Lưu ý: Chưa đổi `IZIIAPP_DB_BACKEND` ở bước này)*:

```env
# Định dạng: postgresql://<user>:<password>@<host>:<port>/<database_name>
IZIIAPP_PG_DSN=postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp
IZIIAPP_PG_POOL_MIN=1
IZIIAPP_PG_POOL_MAX=10
```

---

### Bước 3: Dừng dịch vụ iZiiServer
Dừng server để đảm bảo không có máy di động nào ghi thêm dữ liệu dở dang trong lúc copy:
```powershell
# Nếu chạy dưới dạng Windows Service (qua NSSM):
nssm stop izii_server

# Hoặc nếu chạy bằng lệnh terminal / file .bat:
# Nhấn Ctrl+C trên cửa sổ terminal đang chạy server
```

---

### Bước 4: Chạy kiểm tra trước (`--dry-run`)
Chạy script ở chế độ chạy thử để kiểm tra tính toàn vẹn dữ liệu nguồn (kiểm tra `seq IS NULL`, kiểu dữ liệu và số lượng dòng hiện có):
```powershell
cd C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server
python migrate_to_postgres.py --dry-run
```
**Kỳ vọng:** Xuất hiện thông báo `✅ Pre-flight checks đạt yêu cầu.` và bảng danh sách số lượng dòng sẵn sàng migrate.

---

### Bước 5: Thực thi chuyển dữ liệu sang PostgreSQL
Chạy lệnh chuyển đổi chính thức:
```powershell
python migrate_to_postgres.py
```
**Quá trình script thực hiện:**
1. Tự động khởi tạo đầy đủ 13 bảng và các index trên PostgreSQL.
2. Kiểm tra độ phủ bảng (`_assert_table_coverage`).
3. Đọc dữ liệu từ SQLite theo từng lô 500 dòng (chống tràn RAM) và nạp vào PostgreSQL.
4. Đặt sequence của cột `seq` bằng giá trị `MAX(seq)` lớn nhất vừa nạp.
5. In ra dòng: `✅ Hoàn tất migrate thành công: ... dòng.`

---

### Bước 6: Chạy đối soát độc lập (`--verify`)
Xác nhận lại một lần nữa số dòng của toàn bộ 13 bảng trên cả 2 hệ thống:
```powershell
python migrate_to_postgres.py --verify
```
**Kỳ vọng:** Tất cả 13 bảng đều hiển thị trạng thái `[OK]` và `SQLite == PostgreSQL`.

---

### Bước 7: Kích hoạt Backend PostgreSQL
Mở file `server/.env` và đổi backend chính sang `postgres`:
```env
IZIIAPP_DB_BACKEND=postgres
```

---

### Bước 8: Khởi động lại Server
Khởi động lại dịch vụ iZiiServer:
```powershell
# Nếu dùng NSSM Service:
nssm start izii_server

# Hoặc chạy trực tiếp bằng python:
python app.py
```

---

## 4. Kiểm tra sau chuyển đổi (Post-Migration Smoke Test)

Sau khi server khởi động, thực hiện 6 bước kiểm tra. Mục 4 và 5 là **bắt buộc** —
không có chúng thì không thể khẳng định migrate thành công.

### 1. Kiểm tra log khởi động của Server:
Log phải có các dòng thông báo:
```text
🗄️  Database backend: postgres
🐘 [PG] Connection pool sẵn sàng (min=1, max=10)
🐘 [PG] Schema PostgreSQL đã sẵn sàng.
```

### 2. Kiểm tra API Health:
Mở trình duyệt hoặc curl:
```powershell
curl http://127.0.0.1:8080/sync/status
```
Kết quả trả về JSON có thông tin tổng số bản ghi và các bảng `grow_rooms`, `mushroom_jobs`, `tasks`, v.v.

### 3. Kiểm tra đồng bộ từ điện thoại (iPhone / iPad / Samsung):
* Mở ứng dụng iZiiApp trên thiết bị di động.
* Tạo một dữ liệu mới (ví dụ: tạo 1 công việc kiểm tra / ghi chú mới).
* Xác nhận trên màn hình app báo đã đồng bộ thành công `(Synced)`.
* Kiểm tra trong PostgreSQL:
  ```sql
  SELECT MAX(seq), COUNT(*) FROM sync_mutations;
  ```
  Số `seq` mới phải tăng tiếp đơn điệu (lớn hơn mốc cũ).

### 4. Kiểm tra hồi quy cho lỗi M1 — 4 bảng từng bị bỏ sót ⚠️ BẮT BUỘC

Bốn bảng `device_tokens`, `employee_pins`, `work_sessions`, `enrollment_tokens` trước đây
**không nằm trong danh sách chuyển** và bị mất im lặng. Đây là test chứng minh lỗi đó đã hết:

```sql
SELECT 'device_tokens'     AS bang, COUNT(*) FROM device_tokens
UNION ALL SELECT 'employee_pins',     COUNT(*) FROM employee_pins
UNION ALL SELECT 'work_sessions',     COUNT(*) FROM work_sessions
UNION ALL SELECT 'enrollment_tokens', COUNT(*) FROM enrollment_tokens;
```

Số đếm phải **khớp với SQLite**. Lưu ý: nếu ở SQLite các bảng này đang rỗng thì test này
**không chứng minh được gì** — bản script chưa vá cũng cho kết quả y hệt. Phải chạy trên
bản copy DB production có dữ liệu thật ở 4 bảng này.

Kiểm tra thực tế quan trọng hơn số đếm: **đăng nhập bằng PIN nhân viên**, và **mở app trên
một thiết bị đã enroll từ trước** (không enroll lại). Nếu `device_tokens` mất, thiết bị sẽ
bị đá ra đòi enroll lại — triệu chứng dễ nhận nhất.

### 5. Kiểm tra peer-sync giữa node PostgreSQL và node SQLite ⚠️ BẮT BUỘC

Không thể cutover cả 3 nhà máy trong một đêm, nên **chắc chắn sẽ có giai đoạn node M1 chạy
PostgreSQL còn M2/CR vẫn SQLite**. Nếu mesh không chạy được ở cấu hình hỗn hợp thì toàn bộ
lộ trình "cutover từng node" sụp, phải đổi sang big-bang rủi ro hơn nhiều.

1. Dựng 2 server: node A dùng `IZIIAPP_DB_BACKEND=postgres`, node B giữ `sqlite`.
   Khai báo cho nhau qua `IZIIAPP_PEERS`.
2. Tạo dữ liệu mới ở node A → chờ tối đa 45s (`IZIIAPP_SYNC_INTERVAL_SECONDS`) →
   kiểm tra dữ liệu đã xuất hiện ở node B.
3. Làm ngược lại: tạo ở node B → kiểm tra ở node A.
4. Kiểm tra con trỏ đồng bộ ở cả hai chiều:
   ```sql
   SELECT server_id, last_synced_seq, last_seen_online_at FROM known_servers;
   ```
   `last_synced_seq` phải tăng ở cả hai bên, không đứng yên và không quay lùi.
5. Ngắt mạng giữa A và B khoảng 5 phút, tạo dữ liệu ở cả hai, rồi nối lại → cả hai phải
   bắt kịp nhau, không mất và không nhân đôi bản ghi.

### 6. Kiểm tra collation tiếng Việt

PostgreSQL sắp xếp chuỗi theo collation của database, **khác với `BINARY` mặc định của
SQLite**. Tên nhân viên có dấu sẽ ra thứ tự khác — cần biết trước để chốt, vì đổi collation
sau khi đã chạy thì phải rebuild toàn bộ index.

```sql
SELECT user_name FROM work_sessions
WHERE user_name IS NOT NULL
ORDER BY user_name;
```

So thứ tự với kết quả cùng truy vấn chạy trên SQLite. Nếu khác và **không chấp nhận được**,
phải chốt collation (`en_US.UTF-8`, hoặc ICU `vi-VN`) **trước khi cutover**, không phải sau.
Cũng kiểm tra tìm kiếm không phân biệt hoa/thường: `COLLATE NOCASE` của SQLite **không tồn
tại** ở PostgreSQL — chỗ nào cần thì dùng `ILIKE`.

---

## 5. Quy trình Rollback (Nếu cần quay lại SQLite)

Nếu trong vòng vài ngày đầu vận hành gặp sự cố cần quay lại SQLite:

1. **Dừng dịch vụ Server:**
   ```powershell
   nssm stop izii_server
   ```
2. **Đổi lại file `.env`:**
   ```env
   IZIIAPP_DB_BACKEND=sqlite
   ```
3. **Đồng bộ lại bộ đếm `sync_sequence` trong SQLite:**
   *(Nếu trong thời gian chạy PostgreSQL đã phát sinh thêm các mutation mới, cần cập nhật lại bộ đếm SQLite để không bị trùng lặp số)*:
   ```powershell
   python -c "import sqlite3; from database import DB_PATH; conn=sqlite3.connect(DB_PATH); max_seq=conn.execute('SELECT COALESCE(MAX(seq), 0) FROM sync_mutations').fetchone()[0]; conn.execute('UPDATE sync_sequence SET current = ? WHERE name = \'mutation\'', (max_seq,)); conn.commit(); conn.close(); print('Đã khôi phục sync_sequence =', max_seq)"
   ```
4. **Khởi động lại dịch vụ:**
   ```powershell
   nssm start izii_server
   ```

---

## 6. Xử lý các lỗi thường gặp (Troubleshooting)

### 🔴 Lỗi 1: `connection to server at "127.0.0.1", port 5432 failed: Connection refused`
* **Nguyên nhân:** Dịch vụ PostgreSQL trên Windows chưa được bật.
* **Cách khắc phục:** 
  1. Nhấn `Win + R`, gõ `services.msc`.
  2. Tìm dịch vụ `postgresql-x64-15` (hoặc 16) $\rightarrow$ Chuột phải chọn **Start**.

### 🔴 Lỗi 2: `password authentication failed for user "postgres"`
* **Nguyên nhân:** Mật khẩu trong `IZIIAPP_PG_DSN` không đúng.
* **Cách khắc phục:** Kiểm tra lại mật khẩu lúc cài đặt PostgreSQL và cập nhật lại trong `.env`.

### 🔴 Lỗi 3: `database "iZiiApp" does not exist`
* **Nguyên nhân:** Tên database trong PostgreSQL chưa được tạo hoặc sai hoa/thường.
* **Cách khắc phục:** Tạo database trong PostgreSQL bằng pgAdmin hoặc lệnh SQL: `CREATE DATABASE "iZiiApp";`.

### 🔴 Lỗi 4: Mất file đính kèm hình ảnh sau khi chuyển server
* **Nguyên nhân:** Quên copy thư mục `uploads/` khi chuyển sang máy chủ vật lý mới.
* **Cách khắc phục:** Thư mục `uploads/` nằm độc lập trên ổ đĩa (`%LOCALAPPDATA%\iZiiApp\server\uploads\`). Cần copy thư mục này sang máy chủ mới đúng đường dẫn.

### 🔴 Lỗi 5: Script `migrate_to_postgres.py` dừng giữa chừng

* **Nguyên nhân:** Script commit theo **từng bảng**, không có transaction bao ngoài. Nếu
  lỗi ở bảng thứ N thì N-1 bảng trước đã nằm trong PostgreSQL.
* **Cách khắc phục:** Chạy lại là an toàn về mặt trùng lặp (`ON CONFLICT DO NOTHING`),
  nhưng **không dọn được dòng thừa** nếu nguyên nhân là dữ liệu sai. Cách sạch và dứt điểm:

  ```sql
  DROP DATABASE iziiapp;
  CREATE DATABASE iziiapp;
  ```
  ```powershell
  python migrate_to_postgres.py
  ```

  Chỉ làm được như vậy khi **chưa đổi** `IZIIAPP_DB_BACKEND=postgres` — tức chưa có dữ
  liệu mới nào chỉ tồn tại ở PostgreSQL. Sau khi đã cutover thì phải khôi phục từ backup
  ở Bước 1.

### 🔴 Lỗi 6: `⛔ DỪNG: iZiiServer đang chạy trên cổng 8080`

* **Nguyên nhân:** Script từ chối chạy khi server còn sống, vì mutation ghi trong lúc copy
  có thể bị bỏ sót im lặng.
* **Cách khắc phục:** Dừng dịch vụ trước (`nssm stop izii_server`, hoặc `Ctrl+C` ở
  cửa sổ terminal). Chỉ dùng `--force` khi chắc chắn không có ai đang ghi.

### 🔴 Lỗi 7: `⛔ DỪNG: N bảng có trong SQLite nhưng KHÔNG nằm trong TABLES`

* **Nguyên nhân:** Có bảng mới được thêm vào `db_init.py` nhưng chưa khai báo ở
  `migrate_to_postgres.py`. Đây chính là chốt chặn chống lặp lại lỗi mất 4 bảng trước đây.
* **Cách khắc phục:** Nếu bảng **cần** chuyển, thêm vào `TABLES` (kèm khoá chính) **và**
  thêm DDL tương ứng vào `db_init_postgres.py`. Nếu **cố ý** không chuyển, thêm tên bảng
  vào `NOT_MIGRATED` kèm lý do rõ ràng. Không bao giờ xoá chốt chặn này để "cho chạy được".
