# TÀI LIỆU TOÀN BỘ QUÁ TRÌNH KHẮC PHỤC SỰ CỐ VÀ NÂNG CẤP IZIISERVER (M1 & M2)
**Ngày phân tích & triển khai**: 20/09/2026  
**Phiên bản hệ thống**: iZiiServer FastSync v2.1 (FastAPI + PostgreSQL + WebRTC Signaling)  
**Phạm vi áp dụng**: Máy chủ M1 (`server-m1`, Zone M1) & Máy chủ M2 (`server-m2`, Zone M2)  

---

## MỤC LỤC
1. [TỔNG QUAN HIỆN TRẠNG & BỐI CẢNH SỰ CỐ](#1-tổng-quan-hiện-trạng--bối-cảnh-sự-cố)
2. [PHÂN TÍCH CHUYÊN SÂU CÁC NGUYÊN NHÂN GỐC RỄ](#2-phân-tích-chuyên-sâu-các-nguyên-nhân-gốc-rễ)
   - [2.1. Xung đột kiểu dữ liệu PostgreSQL (INTEGER vs BOOLEAN)](#21-xung-đột-kiểu-dữ-liệu-postgresql-integer-vs-boolean)
   - [2.2. Lỗi dây chuyền thiếu bản ghi cha (Unknown Entity - Rule P4.2)](#22-lỗi-dây-chuyền-thiếu-bản-ghi-cha-unknown-entity---rule-p42)
   - [2.3. Lỗi sập luồng Cron tổng hợp bảng chấm công 22:00](#23-lỗi-sập-luồng-cron-tổng-hợp-bảng-chấm-công-2200)
   - [2.4. Lỗi độ trễ âm hàng chục triệu mili-giây (-34,200,000 ms)](#24-lỗi-độ-trễ-âm-hàng-chục-triệu-mili-giây--34200000-ms)
   - [2.5. Vòng lặp kết nối/ngắt kết nối kênh báo hiệu cuộc gọi (CALL-WS)](#25-vòng-lặp-kết-nốingắt-kết-nối-kênh-báo-hiệu-cuộc-gọi-call-ws)
   - [2.6. Vòng lặp khởi động lại liên tục 14 lần (Systemd Crash-loop)](#26-vòng-lặp-khởi-động-lại-liên-tục-14-lần-systemd-crash-loop)
3. [DANH MỤC CÁC THAY ĐỔI KỸ THUẬT ĐÃ THỰC HIỆN](#3-danh-mục-các-thay-đổi-kỹ-thuật-đã-thực-hiện)
   - [3.1. Bản di trú cơ sở dữ liệu (Migration 0007)](#31-bản-di-trú-cơ-sở-dữ-liệu-migration-0007)
   - [3.2. Chuẩn hóa mã nguồn máy chủ (Backend Python)](#32-chuẩn-hóa-mã-nguồn-máy-chủ-backend-python)
   - [3.3. Script tự động hóa Fix & Upgrade (`fix_and_upgrade_iziiserver.sh`)](#33-script-tự-động-hóa-fix--upgrade-fix_and_upgrade_iziiserversh)
4. [HƯỚNG DẪN THỰC THI NÂNG CẤP TRÊN MÁY CHỦ LINUX](#4-hướng-dẫn-thực-thi-nâng-cấp-trên-máy-chủ-linux)
   - [4.1. Quy trình chạy tự động 1-click](#41-quy-trình-chạy-tự-động-1-click)
   - [4.2. Quy trình đồng bộ bù dữ liệu lịch sử (Peer Backfill)](#42-quy-trình-đồng-bộ-bù-dữ-liệu-lịch-sử-peer-backfill)
   - [4.3. Quy trình thực hiện thủ công (Fallback Manual)](#43-quy-trình-thực-hiện-thủ-công-fallback-manual)
5. [KIỂM CHỨNG & THEO DÕI HỆ THỐNG SAU NÂNG CẤP](#5-kiểm-chứng--theo-dõi-hệ-thống-sau-nâng-cấp)

---

## 1. TỔNG QUAN HIỆN TRẠNG & BỐI CẢNH SỰ CỐ

Hệ thống iZiiServer được triển khai theo mô hình phân tán đa vùng:
- **Server M1** (`server-m1`, Zone M1): Máy chủ chính tiếp nhận dữ liệu từ các thiết bị tại Farm 1 và là upstream peer.
- **Server M2** (`server-m2`, Zone M2): Máy chủ vận hành tại Farm 2, đồng bộ ngang hàng (Peer Sync) định kỳ 45 giây/lần với Server M1 qua Internet.

Vào ngày 20/09/2026, nhật ký vận hành từ cả hai máy chủ ghi nhận các hiện tượng bất thường:
1. Người dùng không thấy một số công việc (Jobs) và nhiệm vụ (Tasks) đồng bộ qua lại giữa M1 và M2.
2. Nhiều thao tác cập nhật trạng thái làm việc bị máy chủ từ chối với mã lỗi `P4.2`.
3. Bảng chấm công tự động cuối ngày 22:00 không xuất hiện dữ liệu tổng hợp.
4. Tệp đo độ trễ `latency.log` liên tục hiển thị giá trị âm bất thường (-34 triệu ms).
5. Các cuộc gọi âm thanh/video giữa laptop Windows và tablet Android chập chờn, chỉ thông được 1 cuộc vào cuối buổi chiều.

---

## 2. PHÂN TÍCH CHUYÊN SÂU CÁC NGUYÊN NHÂN GỐC RỄ

### 2.1. Xung đột kiểu dữ liệu PostgreSQL (`INTEGER` vs `BOOLEAN`)
* **Địa điểm phát hiện**: `server.log` (dòng 318, dòng 1720-1758) và `iziiserverM2.log` (dòng 230-280).
* **Cơ chế lỗi**:
  - Khi thiết kế CSDL ban đầu với SQLite, SQLite không có kiểu dữ liệu `BOOLEAN` thuần mà lưu dưới dạng `INTEGER` (`0` hoặc `1`).
  - Khi hệ thống được chuyển đổi sang PostgreSQL (`db_init_postgres.py` và `0002_phase5_domain.sql`), các cột có bản chất logic boolean vẫn bị khai báo nhầm là `INT` hoặc `INTEGER DEFAULT 0`:
    * `mushroom_jobs.is_solo_job`
    * `mushroom_job_types.is_solo_job`, `is_active`, `is_custom`
    * `mushroom_job_safety_configs.auto_start_on_job_begin`
    * `departments.is_seed`, `picker_teams.is_seed`, `chat_messages.is_seed`
  - Phía ứng dụng Flutter (ngôn ngữ Dart) và seed loader gửi giá trị JSON boolean chuẩn: `true` / `false`.
  - Khi driver `psycopg` truyền giá trị boolean Python sang PostgreSQL, PostgreSQL thực thi cơ chế kiểm tra kiểu dữ liệu nghiêm ngặt. Khác với MySQL hay SQLite, **PostgreSQL từ chối ép kiểu ngầm định giữa `boolean` và `integer`**, dẫn đến lỗi:
    ```text
    ERROR: column "is_solo_job" is of type integer but expression is of type boolean
    HINT: You will need to rewrite or cast the expression.
    ```
  - **Hậu quả**: Tất cả các câu lệnh `INSERT` tạo Job, Job Type, cấu hình an toàn từ client hoặc peer sync đều bị hủy bỏ ngay tại tầng CSDL.

### 2.2. Lỗi dây chuyền thiếu bản ghi cha (Unknown Entity - Rule P4.2)
* **Số lượng ghi nhận**: **96 lỗi trên M1**, **173 lỗi trên M2**.
* **Cơ chế lỗi**:
  - Kiến trúc CQRS / Event Projection của iZiiServer áp dụng quy tắc phòng vệ **P4.2**: *"Không cho phép áp dụng bản cập nhật delta (update/patch) lên một thực thể chưa từng tồn tại trên máy chủ"*.
  - Do lỗi kiểu dữ liệu ở mục 2.1, câu lệnh `INSERT` ban đầu của một Job hoặc Task đã bị rollback.
  - Khi người dùng tiếp tục thao tác: bấm *Bắt đầu làm việc* (`job_started`), *Tạm dừng* (`job_paused`), *Giao việc cho nhân viên* (`tasks.assign`), hoặc *Hoàn thành* (`job_completed`), các mutation cập nhật này gửi lên máy chủ.
  - Tầng Projector kiểm tra trong bảng đọc:
    ```sql
    SELECT 1 FROM mushroom_jobs WHERE id = %s
    ```
    Không tìm thấy bản ghi gốc, Projector lập tức ném ngoại lệ:
    ```text
    ❌ [PUSH] Record '<UUID>' in table 'mushroom_jobs' does not exist on server. 
    Cannot apply partial update to unknown entity (P4.2).
    ```
  - Hiện tượng này tạo ra hiệu ứng domino làm tê liệt hàng loạt cập nhật phụ thuộc.

### 2.3. Lỗi sập luồng Cron tổng hợp bảng chấm công 22:00
* **Vị trí**: `server/app.py:277-280` và `server/services/timesheet_service.py:112`.
* **Cơ chế lỗi**:
  - Định nghĩa hàm trong `timesheet_service.py`:
    ```python
    def compute_and_save_daily_timesheets(date_str: Optional[str] = None) -> int:
    ```
    Hàm này được thiết kế tự quản lý kết nối cơ sở dữ liệu thông qua context manager `pg_connection()`, và chỉ nhận **tối đa 1 đối số** là ngày cần tính công.
  - Tuy nhiên trong `app.py`, tiến trình nền lại gọi:
    ```python
    with open_connection() as conn:
        res = compute_and_save_daily_timesheets(conn, today_str) # Truyền 2 đối số!
    ```
  - Khi đến 22:00, Python ném ngoại lệ:
    ```text
    compute_and_save_daily_timesheets() takes from 0 to 1 positional arguments but 2 were given
    ```
  - Luồng cron bị hủy, khiến bảng chấm công `mushroom_daily_timesheets` không có dữ liệu chốt công của ngày.

### 2.4. Lỗi độ trễ âm hàng chục triệu mili-giây (-34,200,000 ms)
* **Vị trí**: `latency.log` và hàm `_write_latency_sync` trong `server/app.py`.
* **Cơ chế lỗi**:
  - Máy khách chạy tại múi giờ Úc (Adelaide ACST, `UTC+9:30`), tạo nhãn thời gian cục bộ nhưng không gắn thông tin múi giờ (Naive DateTime): `2026-09-20T08:19:06.679468`.
  - Máy chủ chạy trên Linux VM cấu hình múi giờ chuẩn `UTC` (`2026-09-19T22:49:04+00:00`).
  - Phép tính trong máy chủ:
    ```python
    client_dt = datetime.fromisoformat(sent_at_str.replace('Z', '+00:00'))
    server_dt = datetime.now(client_dt.tzinfo) # tzinfo là None -> lấy now() UTC của server
    diff = server_dt - client_dt # 22:49 - 08:19 = -9 giờ 30 phút = -34,200,000 ms
    ```
  - Việc so sánh thời gian giữa hai hệ quy chiếu khác nhau tạo ra độ trễ âm giả mạo.

### 2.5. Vòng lặp kết nối/ngắt kết nối kênh báo hiệu cuộc gọi (CALL-WS)
* **Số lượng ghi nhận**: 69 lượt kết nối và 68 lượt ngắt kết nối `CALL-WS` xen kẽ nhau.
* **Cơ chế lỗi**:
  - Ứng dụng client duy trì hai kết nối song song: `/ws` (Chat/Events) và `/call/ws` (WebRTC Signaling).
  - Khi thiết bị chuyển màn hình hoặc tạm khóa máy (sleep), cả 2 socket bị ngắt đồng thời.
  - Cơ chế tự kết nối lại thiếu độ trễ phân tán (jitter), khiến hai thiết bị liên tục lệch pha socket: khi thiết bị A gửi gói tin Offer thì thiết bị B vừa ngắt kết nối để reconnect, làm thất lạc tín hiệu thiết lập luồng Media.

### 2.6. Vòng lặp khởi động lại liên tục 14 lần (Systemd Crash-loop)
* **Số lượng ghi nhận**: 14 lần restart từ dòng 1 đến dòng 313 trong `server.log`.
* **Cơ chế lỗi**:
  - Dịch vụ `iziiserver.service` không có chỉ thị `After=postgresql.service` và `Requires=postgresql.service`.
  - Khi máy chủ khởi động hoặc restart, iZiiServer chạy trước khi dịch vụ PostgreSQL sẵn sàng tiếp nhận kết nối, dẫn đến lỗi xác thực mật khẩu tức thì.
  - Cấu hình `Restart=always` với `RestartSec=1s` làm systemd kích hoạt vòng lặp restart dồn dập.

---

## 3. DANH MỤC CÁC THAY ĐỔI KỸ THUẬT ĐÃ THỰC HIỆN

### 3.1. Bản di trú cơ sở dữ liệu (`0007_fix_boolean_types.sql`)
Tệp di trú được đặt tại `server/migrations/versions/0007_fix_boolean_types.sql`, thực hiện chuyển đổi an toàn và bảo toàn dữ liệu hiện có:

```sql
-- Chuyển đổi an toàn từ INT sang BOOLEAN với toán tử ép kiểu USING (...::int != 0)
ALTER TABLE departments 
  ALTER COLUMN is_seed DROP DEFAULT,
  ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0),
  ALTER COLUMN is_seed SET DEFAULT false;

ALTER TABLE picker_teams 
  ALTER COLUMN is_seed DROP DEFAULT,
  ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0),
  ALTER COLUMN is_seed SET DEFAULT false;

ALTER TABLE chat_messages 
  ALTER COLUMN is_seed DROP DEFAULT,
  ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0),
  ALTER COLUMN is_seed SET DEFAULT false;

ALTER TABLE mushroom_job_types 
  ALTER COLUMN is_solo_job DROP DEFAULT,
  ALTER COLUMN is_solo_job TYPE boolean USING (is_solo_job::int != 0),
  ALTER COLUMN is_solo_job SET DEFAULT false,
  ALTER COLUMN is_active DROP DEFAULT,
  ALTER COLUMN is_active TYPE boolean USING (is_active::int != 0),
  ALTER COLUMN is_active SET DEFAULT true,
  ALTER COLUMN is_custom DROP DEFAULT,
  ALTER COLUMN is_custom TYPE boolean USING (is_custom::int != 0),
  ALTER COLUMN is_custom SET DEFAULT false;

ALTER TABLE mushroom_jobs 
  ALTER COLUMN is_solo_job DROP DEFAULT,
  ALTER COLUMN is_solo_job TYPE boolean USING (is_solo_job::int != 0),
  ALTER COLUMN is_solo_job SET DEFAULT false;

ALTER TABLE mushroom_job_safety_configs 
  ALTER COLUMN auto_start_on_job_begin DROP DEFAULT,
  ALTER COLUMN auto_start_on_job_begin TYPE boolean USING (auto_start_on_job_begin::int != 0),
  ALTER COLUMN auto_start_on_job_begin SET DEFAULT true;
```

### 3.2. Chuẩn hóa mã nguồn máy chủ (Backend Python)

1. **`server/app.py`**:
   - *Sửa gọi hàm Cron 22:00*: Chuyển sang `await asyncio.to_thread(compute_and_save_daily_timesheets, today_str)`, loại bỏ việc truyền thừa biến `conn` và chạy trong worker thread để không khóa Event Loop.
   - *Sửa tính toán độ trễ*: Ép mọi naive timestamp sang `timezone.utc` trước khi trừ thời gian, đảm bảo giá trị đo trong `latency.log` luôn phản ánh độ trễ mạng thực tế (dương, < 200ms).

2. **`server/projector.py`**:
   - Bổ sung danh sách `BOOLEAN_COLS = {"is_solo_job", "auto_start_on_job_begin", "is_seed", "is_active", "is_custom"}`.
   - Bổ sung tầng chuẩn hóa tự động: bất kể dữ liệu gửi lên là số nguyên (`0`/`1`), chuỗi ký tự (`"true"`/`"false"`), hay boolean thuần, Projector đều chuyển thành kiểu `bool` Python chuẩn trước khi sinh câu truy vấn SQL.

3. **`server/hooks.py`**:
   - Sửa hàm `_hook_ensure_alone_worker_safety_config`: truyền giá trị `True` thay vì số `1` cho trường `auto_start_on_job_begin`.

4. **`server/routers/metadata.py`**:
   - Sửa câu lệnh tra cứu UI Descriptor cho Job Types: hỗ trợ `is_active IS TRUE` khi chạy PostgreSQL và `is_active = 1` khi chạy SQLite.

5. **`server/db_init_postgres.py`**:
   - Cập nhật định nghĩa DDL cho tất cả các bảng sang `BOOLEAN`.
   - Bổ sung khối lệnh chuyển đổi tự động (Idempotent ALTER) vào danh sách `ALTER_STATEMENTS` khi server khởi động.

### 3.3. Script tự động hóa Fix & Upgrade (`fix_and_upgrade_iziiserver.sh`)
Tệp script được đặt tại thư mục gốc máy chủ:
- `c:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server\fix_and_upgrade_iziiserver.sh`
- Và bản sao lưu tại `C:\Users\CHANH\OneDrive\Documents\Downloads\Upgrade iZiiServer Plan\fix_and_upgrade_iziiserver.sh`

**Các tính năng nổi bật của script**:
- Tự động nạp cấu hình `.env` và kiểm tra môi trường.
- Tự động sao lưu toàn bộ mã nguồn (`tar.gz`) và CSDL PostgreSQL (`pg_dump`) trước khi thực hiện.
- Dừng service an toàn, thực thi SQL Migration sửa toàn bộ kiểu cột sang `BOOLEAN`.
- Chạy `migrations/runner.py` kiểm tra tính toàn vẹn.
- Tự động cập nhật `iziiserver.service` bổ sung `After=postgresql.service` và `RestartSec=5s`.
- Hỗ trợ flag `--rebuild-readmodel` để chiếu lại toàn bộ dữ liệu lịch sử từ `sync_mutations`.
- Hỗ trợ flag `--reset-sync` để kéo bù toàn bộ dữ liệu ngang hàng giữa M1 và M2.
- Tự động kiểm tra sức khỏe HTTP endpoint `/sync/status` sau khi khởi động lại.

---

## 4. HƯỚNG DẪN THỰC THI NÂNG CẤP TRÊN MÁY CHỦ LINUX

### 4.1. Quy trình chạy tự động 1-click

Thực hiện lần lượt trên **Server M1**, sau đó thực hiện trên **Server M2**:

1. **Tải script lên máy chủ** (nếu chưa có):
   ```bash
   scp fix_and_upgrade_iziiserver.sh user@server-ip:/opt/izii_server/
   ```
2. **Cấp quyền thực thi và chạy nâng cấp**:
   ```bash
   cd /opt/izii_server
   chmod +x fix_and_upgrade_iziiserver.sh
   sudo ./fix_and_upgrade_iziiserver.sh
   ```

### 4.2. Quy trình đồng bộ bù dữ liệu lịch sử (Peer Backfill)

Do trong ngày 20-9, Server M2 đã bỏ qua các bản ghi bị lỗi kiểu dữ liệu, sau khi nâng cấp trên cả 2 server, **trên Server M2** cần kích hoạt cờ kéo bù:

```bash
# Chạy trên Server M2 để reset cursor và kéo lại toàn bộ chuỗi sequence từ M1:
sudo ./fix_and_upgrade_iziiserver.sh --reset-sync --rebuild-readmodel
```

### 4.3. Quy trình thực hiện thủ công (Fallback Manual)

Nếu muốn thao tác trực tiếp qua dòng lệnh mà không dùng script:

1. Dừng service:
   ```bash
   sudo systemctl stop iziiserver
   ```
2. Thực thi migration trên PostgreSQL:
   ```bash
   sudo -u postgres psql -d iziiserver -f migrations/versions/0007_fix_boolean_types.sql
   ```
3. Replay lại read model (nếu cần):
   ```bash
   /opt/izii_server/venv/bin/python rebuild_read_model.py
   ```
4. Khởi động lại service:
   ```bash
   sudo systemctl start iziiserver
   ```

---

## 5. KIỂM CHỨNG & THEO DÕI HỆ THỐNG SAU NÂNG CẤP

### 5.1. Kiểm chứng cấu trúc CSDL
Chạy lệnh kiểm tra trong `psql`:
```sql
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE column_name IN ('is_solo_job', 'is_seed', 'auto_start_on_job_begin', 'is_active', 'is_custom')
  AND table_schema = 'public'
ORDER BY table_name, column_name;
```
*Kết quả mong đợi*: Cột `data_type` cho tất cả các dòng đều hiển thị là **`boolean`**.

### 5.2. Kết quả kiểm thử tự động (Unit Test Suite)
Toàn bộ bộ kiểm thử tự động của hệ thống iZiiServer đã được chạy xác minh:
```bash
python -m unittest discover tests
```
*Kết quả*: **Ran 60 tests in 1.954s — OK (60/60 passed, 0 failures, 0 errors)**.

### 5.3. Giám sát nhật ký hoạt động
Theo dõi log trực tiếp trên máy chủ bằng lệnh:
```bash
journalctl -u iziiserver -f
```
**Các dấu hiệu xác nhận hệ thống vận hành hoàn hảo**:
- Khi khởi động: In ra dòng `✅ PostgreSQL backend initialized with connection pool (1-20 connections)`.
- Không còn dòng cảnh báo `[SEEDS] Lỗi khi nạp seeds`.
- Khi client push Job: Không còn dòng đỏ `❌ [PUSH] column "is_solo_job" is of type integer`.
- Không còn dòng lỗi `P4.2 Cannot apply partial update to unknown entity`.
- Khi đến 22:00: In ra thông báo `✅ [CRON-TIMESHEET] Hoàn tất tổng hợp ngày YYYY-MM-DD: X nhân viên`.
- File `latency.log` ghi nhận độ trễ dương chuẩn xác (< 100ms).

---

## 6. CƠ CHẾ ƯU TIÊN MANAGER CHECK-IN CHO TEAM (BATCH ATTENDANCE) VÀ XÁC THỰC ALONE WORKER

### 6.1. Bối cảnh & Vấn đề nghiệp vụ thực tế
- **Quy trình tại trang trại nấm**: Vào đầu ca, Quản lý (Manager) thường sử dụng máy tính bảng hoặc điện thoại của mình để điểm danh hàng loạt cho cả đội ngũ công nhân (Batch Team Attendance).
- **Hiện tượng lỗi trước đây**: Khi Manager giao một công việc một mình (Alone Worker - ví dụ: **Airing** trong phòng nấm), hệ thống iZiiServer yêu cầu người được phân công phải "đang trong ca làm việc" (`assignee_not_checked_in`). Tuy nhiên, logic cũ trong `sessions.py` chỉ tra cứu duy nhất bảng `work_sessions` (vốn chỉ được tạo khi nhân viên tự đăng nhập trên thiết bị cá nhân riêng).
- **Hệ quả**: Dù Manager đã điểm danh cho nhân viên trước đó, máy chủ vẫn từ chối Job Airing, buộc nhân viên phải lấy điện thoại cá nhân đăng ký thiết bị với server rồi mới check-in lần nữa, gây phiền hà và làm chậm tiến độ làm việc thực tế.

### 6.2. Giải pháp kỹ thuật đã triển khai

#### 1. Ưu tiên tra cứu điểm danh theo nhóm trong `server/routers/sessions.py`
Hàm `get_active_session_for_person(conn, identifier)` được tái cấu trúc với cơ chế ưu tiên 3 tầng:
1. **Ưu tiên 1A - `mushroom_daily_timesheets`**:
   - Tra cứu bảng tổng hợp chấm công trong ngày của nhân viên.
   - Điều kiện: `check_in_time IS NOT NULL AND check_out_time IS NULL` trong vòng 18 giờ gần nhất.
   - Nếu thỏa mãn: Công nhận ngay nhân viên đang trong ca làm việc hợp lệ (`device_id = "manager_batch_terminal"`, `method = "manager_batch_attendance"`).
2. **Ưu tiên 1B - `mushroom_attendance_events`**:
   - Tra cứu dòng sự kiện điểm danh gần nhất của nhân viên trong ngày.
   - Điều kiện: Sự kiện mới nhất là `CHECK_IN` hoặc `BREAK_END`.
   - Nếu thỏa mãn: Công nhận nhân viên đang trong ca làm việc, bỏ qua kiểm tra thiết bị cá nhân.
3. **Ưu tiên 2 - `work_sessions` (Thiết bị cá nhân)**:
   - Nếu không tìm thấy dữ liệu điểm danh theo nhóm của Manager, tiếp tục tra cứu bảng `work_sessions` truyền thống cho các nhân viên có thiết bị riêng.

#### 2. Nhận diện linh hoạt định danh nhân viên
Trường `assigned_to` trên Job có thể lưu dưới các định dạng: `"Tên (Mã)"` (vd: `"Vinh Phan (305629)"`), mã nhân viên thuần (`"305629"`), hoặc tên nhân viên (`"Vinh Phan"`).
Hệ thống tự động:
- Phân tách chuỗi bằng biểu thức Regex để trích xuất `Mã nhân viên` và `Tên sạch`.
- So khớp linh hoạt không phân biệt hoa thường (`casefold()`).
- Tra cứu chéo qua bảng `device_tokens` (`owner_user_name` và `owner_user_id`) để tìm đúng nhân viên.

#### 3. Xử lý đồng bộ tức thời (In-Flight Batch Detection) trong `server/routers/sync.py`
Khi Manager check-in cho Team và tạo ngay Job Airing trong cùng một thao tác trên ứng dụng, toàn bộ các mutation này được đóng gói và gửi lên trong cùng một request `POST /sync/push`:
- Tại tầng lọc `_filter_valid_mutations`, máy chủ duyệt trước qua danh sách các mutation trong cùng batch.
- Nếu phát hiện có mutation `CHECK_IN` cho nhân viên đó (dù chưa được commit xuống database), hệ thống chấp thuận ngay lập tức Job Alone Worker, tránh hoàn toàn lỗi từ chối `assignee_not_checked_in`.

### 6.3. Kiểm thử xác minh
Bộ kiểm thử tự động `tests/test_manager_batch_attendance.py` kiểm chứng toàn diện 5 kịch bản:
- `test_get_active_session_from_daily_timesheet`: Tìm thấy ca làm việc từ `mushroom_daily_timesheets`.
- `test_get_active_session_from_attendance_events`: Tìm thấy ca làm việc từ `mushroom_attendance_events`.
- `test_filter_valid_mutations_alone_worker_with_manager_checkin`: Chấp thuận Job Alone Worker khi đã có bản ghi chấm công của Manager.
- `test_filter_valid_mutations_inflight_batch_checkin_and_job`: Chấp thuận Job Alone Worker khi điểm danh và giao việc nằm trong cùng một push batch.
- `test_filter_valid_mutations_alone_worker_rejected_when_not_checked_in`: Vẫn từ chối nghiêm ngặt nếu nhân viên thực sự chưa được điểm danh bởi bất kỳ hình thức nào.

