# Báo cáo tư vấn Data Architecture — iZiiServer / iZiiApp

**Trả lời cho:** `plan/database/extend.md`
**Ngày:** 22/08/2026
**Phạm vi:** (1) Chiến lược backup theo chu kỳ · (2) Thiết kế hướng scalability · (3) Chuẩn bị migrate PostgreSQL / SQL Server

---

## 0. Bối cảnh — điền vào các chỗ trống của `extend.md`

`extend.md` để trống phần bối cảnh. Dưới đây là những gì **đọc được trực tiếp từ source code**, không phải giả định:

| Mục trong prompt | Thực tế trong repo | Nguồn |
|---|---|---|
| iZiiServer là gì | Hệ thống **nội bộ, tự viết**: FastAPI + Uvicorn (Python ≥3.11), đóng gói `.exe` bằng PyInstaller, chạy trên Windows | `server/requirements.txt`, `izii_server.spec` |
| DB engine hiện tại | **SQLite 3** ở chế độ WAL. Đã có sẵn backend **PostgreSQL song song** (chưa bật) | `server/database.py`, `server/db_postgres.py` |
| Vị trí file DB | `%LOCALAPPDATA%\iZiiApp\server\iziiapp.db` (Windows). Ghi đè bằng `IZIIAPP_DATA_DIR` / `IZIIAPP_SERVER_DB_PATH` | `database.py:get_stable_data_dir()` |
| Cấu hình PRAGMA | `journal_mode=WAL`, `synchronous=NORMAL`, `busy_timeout=5000`, `cache_size=64MB`, `mmap_size=256MB` | `database.py:get_db_connection()` |
| Quy mô dữ liệu | Rất nhỏ: `server/data/iziiapp.db` ≈ **168 KB**, bản cũ trong repo ≈ **1,8 MB**. Đây là dữ liệu dev, chưa phải production | `ls data/` |
| Số bảng | **14 bảng**, không có view / trigger / stored procedure / foreign key nào | `db_init.py`, `db_init_postgres.py` |
| Bảng tăng trưởng nhanh nhất | `sync_mutations` — mutation log append-only, mỗi thao tác của mọi thiết bị là một dòng | `db_init.py` §1 |
| Hạ tầng | **On-premise, edge mesh**: mỗi nhà máy (M1, M2, Cool Room) một node FastAPI + SQLite riêng, nối nhau qua Tailscale/WireGuard, delta-pull `/peer-sync/pull` mỗi **45 giây** | `multi_server_deployment_architecture.md` |
| Tần suất giao dịch | Thiết kế cho **200 DAU**; peak ~100 concurrent, ~500 req/phút, ~200 IOPS | `iziiapp_scale_ready_architecture.md` §8 |
| RTO/RPO | **Chưa được định nghĩa ở bất kỳ tài liệu nào** — xem §4, câu hỏi Q1 | — |

**Danh sách 14 bảng:** `sync_mutations`, `sync_sequence`, `known_servers`, `devices`, `message_queue`, `notifications`, `notification_settings`, `webhook_subscriptions`, `webhook_dead_letters`, `enrollment_tokens`, `device_tokens`, `work_sessions`, `employee_pins`, `schema_migrations`.

### Ba phát hiện quan trọng trước khi đọc tiếp

> **🔴 P1 — Hiện tại KHÔNG có backup nào đang chạy.**
> `iziiapp_scale_ready_architecture.md` §7 đã *đề xuất* một bảng backup và một script `scripts/backup_system.py`, nhưng thư mục `scripts/` **không tồn tại** trong repo. `multi_server_deployment_architecture.md` liệt kê "Phase 3 — Cross-Server Backup" ở trạng thái chưa triển khai. Nghĩa là RPO thực tế hôm nay = **toàn bộ dữ liệu kể từ lần copy tay gần nhất**.

> **🔴 P2 — `migrate_to_postgres.py` bỏ sót 4 bảng.**
> Danh sách `TABLES` trong script chỉ có 9 bảng. Bốn bảng **có trong cả schema SQLite lẫn schema PostgreSQL nhưng không nằm trong danh sách chuyển**: `enrollment_tokens`, `device_tokens`, `work_sessions`, `employee_pins`. Chạy migrate hôm nay sẽ **mất toàn bộ token thiết bị, PIN nhân viên và lịch sử phiên làm việc** — mà script vẫn in `✅ Hoàn tất` vì nó chỉ `continue` khi không tìm thấy bảng, không cảnh báo khi bảng tồn tại mà không được liệt kê.

> **🟠 P3 — Job dọn dẹp chỉ chạy lúc khởi động.**
> `prune_old_mutations(days=30)` và `prune_message_queue()` được gọi trong `lifespan()` của FastAPI (`app.py:306`, `:310`) — tức **một lần duy nhất khi server start**. Server chạy liên tục 3 tháng = 3 tháng `sync_mutations` không được dọn.

> **🔴 P4 — Trên PostgreSQL, hàng đợi tin nhắn không bao giờ được dọn.**
> `app.py:308` ghi: *"Chỉ chạy trên SQLite — bản PostgreSQL dùng job riêng"* và bỏ qua `prune_message_queue()` khi `db_backend == "postgres"`. Nhưng **job riêng đó không tồn tại**: `db_init_postgres.py` chỉ có `init_db_postgres()` và `prune_old_mutations_postgres()`, không có `prune_message_queue_postgres()`. Hệ quả sau khi migrate: tin đã giao không bao giờ bị xoá, và tin kẹt **không bao giờ được dead-letter** — tức tái diễn đúng sự cố 1.173 tin kẹt ngày 11/08 mà cơ chế này được viết ra để chặn.

---

## 1. Chiến lược backup theo chu kỳ

### 1.1 Nguyên tắc nền cho SQLite

Điểm dễ sai nhất: **không bao giờ copy file `.db` bằng `copy` / `xcopy` / OneDrive sync khi server đang chạy.** Ở chế độ WAL, các giao dịch mới nhất nằm trong `iziiapp.db-wal`; copy thiếu file `-wal` và `-shm` sẽ cho ra một bản backup thiếu dữ liệu hoặc corrupt — và lỗi chỉ lộ ra lúc cần restore.

Hai cách an toàn khi DB đang chạy:

| Cách | Lệnh | Đặc điểm |
|---|---|---|
| **`VACUUM INTO`** (khuyến nghị) | `sqlite3 iziiapp.db "VACUUM INTO 'backup.db'"` | SQLite ≥3.27. Ra 1 file đã nén/defrag, không cần `-wal`. Nhanh, đơn giản nhất. |
| **Online Backup API** | `src.backup(dst, pages=100)` trong Python | Không block writer, có progress callback. Là cách `scale_ready_architecture.md` §7 đã đề xuất. |

Ngoài file DB, **backup phải bao gồm 3 thứ nữa**, nếu không thì restore xong hệ thống vẫn hỏng:

1. `<data_dir>\uploads\` — file đính kèm lưu **trên đĩa**, không nằm trong DB (`routers/attachments.py:15`). Mất thư mục này = mọi ảnh/tài liệu trong app thành link chết.
2. `server\.env` — chứa `IZIIAPP_SERVER_SECRET`, `IZIIAPP_ADMIN_SECRET`, `IZIIAPP_WS_SECRET`, DSN, đường dẫn TLS. Mất = mọi device token và peer trust phải enroll lại.
3. Chứng chỉ TLS (`IZIIAPP_TLS_CERT_FILE` / `_KEY_FILE` / `_CA_FILE`) và cấu hình Windows Service (NSSM registry export).

### 1.2 Bảng đề xuất — giai đoạn SQLite (hiện tại)

| Tần suất | Phương pháp | Công cụ | Lưu ý |
|---|---|---|---|
| **Mỗi 15 phút** | Hot snapshot `VACUUM INTO` → `hot\iziiapp_HHmm.db` | Python script + Windows Task Scheduler | Giữ 24h rolling (96 file). DB 168 KB–vài chục MB nên chi phí gần như bằng 0. Đây là thứ quyết định RPO ≤ 15 phút. |
| **Hằng ngày 02:00** | Full snapshot + `robocopy /MIR` thư mục `uploads\` + copy `.env` (đã mã hoá) → nén `.7z` | Task Scheduler + 7-Zip CLI | Giữ **30 ngày**. Đặt tên `iziiapp_YYYYMMDD.7z`. Ghi log kết quả ra file để giám sát. |
| **Hằng ngày, sau bản daily** | Đẩy off-site | `rclone` hoặc `restic` → S3 / Backblaze B2 / Azure Blob | Giữ **90 ngày**. `restic` được ưu tiên: có dedup + mã hoá client-side, quan trọng vì `.env` chứa secret. |
| **Chủ nhật 03:00** | Weekly archive (copy bản daily gần nhất sang `weekly\`) | Task Scheduler | Giữ **12 tuần**. |
| **Ngày 1 hằng tháng** | Monthly archive | Task Scheduler | Giữ **12 tháng**. Đây là mức đáp ứng yêu cầu truy vết ATLĐ / đối soát ERP. |
| **Ngày 1/1 hằng năm** | Yearly archive → cold storage | rclone → S3 Glacier / B2 | Giữ **7 năm** hoặc theo yêu cầu pháp lý của Costa. |
| **Mỗi khi đổi cấu hình** | Export NSSM service + `.env` + TLS certs | `reg export`, copy thủ công | Giữ vĩnh viễn, versioned. |
| **Mỗi quý** | **Restore drill** — dựng lại server từ backup trên máy sạch | Thủ công, có checklist | *Backup chưa restore thử thì chưa phải backup.* Mục này quan trọng ngang mọi mục trên. |

### 1.3 Chiến lược 3-2-1 áp cho mesh nhiều node

Kiến trúc mesh cho phép làm 3-2-1 gần như miễn phí:

- **3 bản sao**: bản gốc trên node + snapshot local trên ổ D: + bản off-site cloud.
- **2 loại media**: SSD nội bộ + object storage cloud (hoặc NAS trong farm).
- **1 bản off-site**: cloud, hoặc tối thiểu là node ở **plant khác** (M1 giữ backup của M2 và ngược lại).

Đây chính là **Phase 3 "Cross-Server Backup"** đang treo trong `multi_server_deployment_architecture.md`. Cách rẻ nhất: thêm một task chạy `restic` đẩy repo của node M1 sang share của node CR qua Tailscale — không cần cloud, không tốn phí, và đã có sẵn đường mạng mã hoá.

**Lưu ý riêng cho mesh:** vì mọi mutation được replicate sang mọi peer, mất hẳn 1 node **không** mất dữ liệu — các node còn lại có bản sao của `sync_mutations`. Nhưng điều đó **không** thay thế backup, vì replication cũng nhân bản luôn thao tác xoá/hỏng dữ liệu sang tất cả node. Backup bảo vệ khỏi *lỗi logic và thao tác sai*; replication chỉ bảo vệ khỏi *hỏng phần cứng*.

### 1.4 Retention & archive — chính sách đề xuất

| Loại dữ liệu | Giữ nóng (trong DB) | Archive | Xoá |
|---|---|---|---|
| `sync_mutations` | 30 ngày (đã có `prune_old_mutations`) | Trước khi prune, dump ra Parquet/CSV theo tháng → cold storage | Sau 12 tháng archive, theo yêu cầu audit |
| `message_queue` (đã giao) | 7 ngày (đã có `prune_message_queue`) | Không cần | Xoá thẳng |
| `message_queue` (kẹt) | Dead-letter sau 3 ngày, **giữ lại để điều tra** | 90 ngày | Xoá sau khi đóng ticket |
| `webhook_dead_letters` | ⚠️ **Chưa có prune** — đang tăng vô hạn | 90 ngày | Cần bổ sung job |
| `enrollment_tokens` | TTL 600s nhưng ⚠️ **chưa có job xoá bản hết hạn** | — | Cần bổ sung job |
| `work_sessions` | Vô hạn — dữ liệu chấm công/ATLĐ | Archive theo năm | Theo luật lao động, tối thiểu vài năm |
| `devices`, `employee_pins` | Vô hạn (dữ liệu tham chiếu) | Có trong backup đầy đủ | Chỉ xoá khi off-board |
| File `uploads/` | Vô hạn | Đẩy sang object storage khi > 50 GB | Theo vòng đời tài liệu |

### 1.5 Việc cần làm ngay (theo thứ tự)

1. Viết `scripts/backup_izii.py` (`VACUUM INTO` + robocopy `uploads` + copy `.env`) — nửa ngày công.
2. Đăng ký 3 task trong Windows Task Scheduler: 15 phút / daily 02:00 / weekly CN 03:00. Chạy dưới tài khoản service, có "Run whether user is logged on or not".
3. Bổ sung `restic` off-site (hoặc cross-node) sau bản daily.
4. **Đổi `prune_*` từ gọi-lúc-startup sang job định kỳ** — thêm một `asyncio` task chạy mỗi 24h trong `lifespan()`, cùng chỗ với `_peer_sync_loop`.
5. Thêm prune cho `webhook_dead_letters` và `enrollment_tokens`.
6. Lịch restore drill quý đầu tiên, có biên bản.

---

## 2. Thiết kế hướng tới khả năng mở rộng

### 2.1 Đánh giá schema hiện tại

**Điểm mạnh — nên giữ:**

- `sync_mutations` là **append-only log có `seq` đơn điệu do server cấp**. Đây là quyết định thiết kế đúng nhất trong toàn hệ thống: con trỏ delta miễn nhiễm với lệch đồng hồ giữa các node — thứ đã từng gây bug "bỏ sót mutation vĩnh viễn, im lặng" khi còn so sánh chuỗi thời gian.
- **Không có trigger / view / stored procedure / foreign key**. Toàn bộ logic nằm ở Python. Điều này làm việc migrate sang engine khác trở nên *dễ khác thường* (xem §3).
- Kiến trúc **shared-nothing theo zone**: mỗi plant một DB độc lập. Đây đã là sharding theo địa lý — mở rộng bằng cách thêm node, không phải bằng cách làm DB to hơn.
- Bảng `schema_migrations` có ghi sổ, migration idempotent (`_migration_applied` / `_mark_migration`).

**Điểm yếu — cần xử lý:**

| Vấn đề | Hệ quả khi scale | Đề xuất |
|---|---|---|
| **Hai file schema song song** (`db_init.py` + `db_init_postgres.py`) sửa tay | Drift. Bằng chứng đã có: P2 ở trên. | Sinh DDL từ **một** nguồn duy nhất, hoặc dùng công cụ migration thật (Alembic / yoyo / sqitch) |
| **Thời gian lưu dạng TEXT ISO-8601**, so sánh bằng chuỗi | Đã từng gây bug `001_purge_naive_timestamps`. Không dùng được index theo range hiệu quả, không partition được theo thời gian | Chuyển sang `TIMESTAMPTZ` **ngay sau khi lên Postgres**, làm thành một migration riêng |
| **`seq` không có UNIQUE constraint** | Hai writer cấp trùng seq → client bỏ sót mutation, không có lỗi nào báo | Thêm `UNIQUE (origin_server_id, seq)` |
| **Không có foreign key nào** | `notifications.user_id`, `message_queue.recipient_device_id` có thể trỏ vào bản ghi đã xoá | Thêm FK khi lên Postgres (SQLite mặc định tắt FK enforcement nên hiện tại có khai báo cũng vô nghĩa) |
| **`data TEXT` chứa JSON** trong `sync_mutations` | Không query được theo nội dung mutation | PostgreSQL: đổi sang `JSONB` + GIN index. Đây là một trong những lý do mạnh nhất để chọn PG |
| **`prune` chạy 1 lần lúc start** | `sync_mutations` phình vô hạn trên server chạy dài | Job định kỳ (đã nêu §1.5) |

### 2.2 Bảng đề xuất — scalability

| Tần suất / Ngưỡng | Phương pháp | Công cụ | Lưu ý |
|---|---|---|---|
| **Ngay bây giờ** | Chuẩn hoá schema: 1 nguồn DDL, thêm `UNIQUE(origin_server_id, seq)`, chuẩn bị cột thời gian | Alembic hoặc script sinh DDL | Làm khi DB còn 168 KB thì gần như miễn phí. Làm sau khi có 50 GB thì là dự án riêng. |
| **< 400 DAU** | Giữ nguyên SQLite WAL + Uvicorn | — | Đã đủ dư. SSD NVMe cho 50k–200k IOPS, nhu cầu peak chỉ ~200 IOPS |
| **400–800 DAU** | Vertical: RAM 8→16 GB, tăng Uvicorn workers, DB sang SSD riêng | NSSM / Task Manager | ⚠️ Tăng worker với SQLite làm **tăng** tranh chấp writer, không giảm. `busy_timeout=5000` là thứ duy nhất đang che lỗi `database is locked` |
| **> 800 DAU hoặc xuất hiện `database is locked`** | Migrate sang PostgreSQL | `migrate_to_postgres.py` (sau khi sửa P2) | Đây là ranh giới thật: SQLite = **một writer duy nhất**. Nhiều adapter ERP/OPC-UA ghi song song sẽ chạm trần này trước cả khi DAU tăng |
| **Sau khi lên PG, khi `sync_mutations` > 50 triệu dòng** | **Partition theo RANGE trên `server_received_at`**, mỗi tháng 1 partition | PostgreSQL declarative partitioning + `pg_partman` | Bắt buộc đổi cột sang `TIMESTAMPTZ` trước. Prune 30 ngày trở thành `DROP PARTITION` — tức thì, thay vì `DELETE` quét bảng |
| **Khi báo cáo/dashboard làm chậm ghi** | Tách read/write: 1 primary + 1..n read replica | PostgreSQL streaming replication + `pgbouncer` | App hiện dùng **một pool duy nhất** (`db_postgres.py:get_pool()`). Cần thêm pool thứ hai read-only và định tuyến ở tầng repository — nên thiết kế interface sẵn từ bây giờ |
| **Khi thêm plant mới (M3, M4…)** | Thêm node vào mesh, khai báo `IZIIAPP_PEERS` | `.env` + Tailscale | Đã hỗ trợ sẵn. Chi phí ~0. Đây là hướng scale tự nhiên của hệ thống này |
| **Khi cần dữ liệu cảm biến kho lạnh theo thời gian** | Hypertable time-series riêng, không nhét vào `sync_mutations` | TimescaleDB (extension của PG) | Rất phù hợp bối cảnh Cool Room: nén 10–20×, continuous aggregate cho dashboard nhiệt độ |

### 2.3 Version hoá schema — đề xuất cụ thể

Cơ chế hiện tại (`CREATE TABLE IF NOT EXISTS` + `ALTER TABLE` thủ công + bảng `schema_migrations`) hoạt động được nhưng có ba giới hạn khi số node tăng:

1. Không biết một node đang ở **version schema nào** — chỉ biết migration nào đã chạy.
2. Không có **rollback**.
3. **Không kiểm tra tương thích giữa các peer.** Node M1 nâng cấp có cột mới, node M2 chưa — mutation từ M1 sang M2 sẽ mất cột đó *âm thầm*.

Đề xuất:

- Thêm `schema_version INTEGER` vào bảng `known_servers` và **trao đổi version trong handshake `/peer-sync/pull`**. Node nhận thấy peer có version cao hơn → log cảnh báo rõ ràng thay vì im lặng mất dữ liệu. (Cột `schema_version` đã có sẵn trên từng dòng `sync_mutations` — hạ tầng đã có, chỉ thiếu bước kiểm tra ở tầng peer.)
- Chuyển sang **Alembic**: mỗi thay đổi là một file `up`/`down` có số thứ tự, chạy được trên cả SQLite lẫn PostgreSQL, `alembic current` cho biết version tức thì.
- Quy tắc bắt buộc cho mesh: **mọi thay đổi schema phải backward-compatible ít nhất 1 version** (chỉ thêm cột nullable, không đổi tên, không xoá) — vì không thể nâng cấp cả 3 plant cùng lúc.

---

## 3. Chuẩn bị migrate sang PostgreSQL hoặc SQL Server

### 3.1 Tin tốt: 80% việc đã làm xong

Repo đã có sẵn một đường migrate PostgreSQL hoàn chỉnh: `db_postgres.py` (psycopg3 + connection pool), `db_init_postgres.py` (schema song song), `migrate_to_postgres.py` (copy dữ liệu, giữ nguyên `seq`, `setval` sequence), và hàm `sql()` trong `database.py` tự đổi placeholder `?` → `%s`. Bật bằng `IZIIAPP_DB_BACKEND=postgres` + `IZIIAPP_PG_DSN`.

**Với điều kiện sửa P2 trước** (bổ sung 4 bảng bị bỏ sót vào danh sách `TABLES`).

### 3.2 So sánh hai hướng trong bối cảnh WMS/WCS edge-mesh

| Tiêu chí | **PostgreSQL** | **SQL Server** |
|---|---|---|
| **Chi phí license** | 0 đ, mọi node | Express miễn phí nhưng **giới hạn 10 GB/DB, 1 socket, 1,4 GB buffer**. Standard tính theo core → nhân cho **mỗi** node edge |
| **Mức độ sẵn sàng của code** | ✅ Đã code xong, chỉ cần bật | ❌ Phải viết `db_mssql.py` + `db_init_mssql.py` + script migrate từ đầu (~2–3 tuần) |
| **Hợp với mesh nhiều node nhỏ** | ✅ Rất tốt — nhẹ, chạy được trên PC nhà máy, license 0đ nhân N node | ❌ Nặng và tốn license cho mô hình edge N node |
| **Môi trường Windows sẵn có** | Chạy tốt, nhưng team cần học vận hành PG | ✅ Native, IT nhà máy quen SSMS, maintenance plan có GUI |
| **Tích hợp ERP** | Qua webhook/ETL (đã có `webhook_subscriptions`) | ✅ Nếu ERP của Costa chạy MSSQL: Linked Server, SSIS, cùng hệ sinh thái |
| **JSON** | ✅ `JSONB` + GIN index — hợp với cột `data` của `sync_mutations` | `NVARCHAR(MAX)` + `JSON_VALUE`, yếu hơn rõ rệt |
| **Time-series (nhiệt độ kho lạnh)** | ✅ TimescaleDB | Không có tương đương |
| **Partitioning** | Declarative + `pg_partman`, dễ | Partitioned table — chỉ có ở Enterprise trước 2016 SP1, nay có ở Standard |
| **Backup / PITR** | `pg_dump` + WAL archiving; `pgBackRest`/WAL-G rất mạnh nhưng cần học | ✅ Điểm mạnh nhất của MSSQL: Full/Diff/Log backup + PITR đến từng giây, native, GUI |
| **HA** | Streaming replication, Patroni | AlwaysOn AG (Enterprise) |

**Khuyến nghị:**

> **PostgreSQL cho mọi node edge.** Lý do quyết định không phải là tính năng mà là **kinh tế của mô hình N node**: license MSSQL nhân cho mỗi plant, trong khi PG nhân cho 0. Cộng thêm việc code PG đã viết xong.
>
> **Chỉ cân nhắc SQL Server nếu** ERP/WMS trung tâm của Costa đã chạy MSSQL và yêu cầu đối soát trực tiếp qua Linked Server. Kể cả trong trường hợp đó, kiến trúc hợp lý vẫn là: **PG ở edge → ETL/webhook → MSSQL ở tầng trung tâm**, chứ không phải MSSQL ở từng nhà máy.

### 3.3 Bảng đề xuất — lộ trình migrate

| Tần suất / Giai đoạn | Phương pháp | Công cụ | Lưu ý |
|---|---|---|---|
| **Ngay — trước mọi thứ** | Sửa P2: thêm 4 bảng vào `TABLES` trong `migrate_to_postgres.py`; thêm assert "mọi bảng trong schema đều phải có mặt trong TABLES" | Sửa tay + unit test | Nếu bỏ qua bước này, migrate sẽ mất token/PIN/session mà **vẫn báo thành công** |
| **Tuần 1** | Dựng PG staging, chạy `migrate_to_postgres.py` trên **bản copy** của DB production | Docker `postgres:16` hoặc cài trực tiếp | So khớp `COUNT(*)` từng bảng hai bên. Đây là bước acceptance |
| **Tuần 1** | Chạy toàn bộ test suite với `IZIIAPP_DB_BACKEND=postgres` | pytest | Săn các query SQLite-only còn sót (xem §3.4) |
| **Tuần 2** | Đo hiệu năng song song: cùng workload, hai backend | Script benchmark | Kỳ vọng: latency đơn lẻ **tăng nhẹ** (TCP overhead), throughput ghi đồng thời **tăng mạnh** |
| **Tuần 3 — cutover** | Dừng server → `migrate_to_postgres.py` lần cuối → đổi `.env` → khởi động lại | Có sẵn quy trình 6 bước trong docstring của script | Giữ file SQLite cũ **tối thiểu 30 ngày** để đối chiếu. Cutover từng node một, không đồng loạt |
| **Sau cutover 2 tuần (ổn định)** | Migration riêng: `TEXT` → `TIMESTAMPTZ`, `data TEXT` → `JSONB`, thêm `UNIQUE(origin_server_id, seq)` | Alembic | **Không** gộp vào lần cutover. Trộn hai thay đổi rủi ro vào một lần là công thức gây sự cố |
| **Sau đó** | Bật WAL archiving + PITR, thay `pg_dump` daily bằng `pgBackRest` | pgBackRest / WAL-G | Lúc này RPO có thể xuống **dưới 1 phút** |

### 3.4 Khác biệt kỹ thuật cần lưu ý

| Khía cạnh | SQLite (hiện tại) | PostgreSQL | SQL Server |
|---|---|---|---|
| **Kiểu dữ liệu** | Động — cột `INT` nhận được cả chuỗi | Nghiêm ngặt — sai kiểu là lỗi ngay | Nghiêm ngặt |
| **Boolean** | `INT 0/1` (`enable_push`, `is_active`) | Nên đổi sang `BOOLEAN`; nếu giữ `INT` thì code Python phải nhất quán | `BIT` |
| **Thời gian** | `TEXT` ISO-8601 | Đang giữ `TEXT` để tương thích — **có chủ đích, đúng** cho bước 1 | `DATETIME2` |
| **Placeholder** | `?` | `%s` — đã có hàm `sql()` xử lý | `?` (pyodbc) — trùng SQLite, tiện |
| **Upsert** | `INSERT OR REPLACE` | `ON CONFLICT ... DO UPDATE` — đã chuyển đổi | `MERGE` (cú pháp khác hẳn, có lịch sử bug) |
| **Auto-increment** | Bảng đếm `sync_sequence` thủ công | `BIGSERIAL` — đã dùng | `IDENTITY` / `SEQUENCE` |
| **Identifier `"table"`** | Đã quote đúng | `"table"` — giữ nguyên | Phải đổi thành `[table]` |
| **Collation** | `BINARY` mặc định | `en_US.UTF-8` hoặc ICU. ⚠️ **`ORDER BY` tên tiếng Việt có dấu sẽ ra thứ tự KHÁC SQLite** | Cần `Vietnamese_CI_AI` hoặc `Latin1_General_100_CI_AI_SC_UTF8` |
| **Case-insensitive search** | `COLLATE NOCASE` | `ILIKE` hoặc `citext` — **`NOCASE` không tồn tại** | `CI` collation làm mặc định |
| **Isolation mặc định** | WAL: writer đơn, reader không bị chặn | `READ COMMITTED`, MVCC — reader không bị chặn | `READ COMMITTED` **có khoá** → reader **bị chặn** bởi writer. ⚠️ Phải bật `READ_COMMITTED_SNAPSHOT ON` để có hành vi giống PG/SQLite, nếu không sẽ gặp timeout bất ngờ |
| **Stored procedure / trigger** | **Không có** | — | — |
| **Foreign key** | **Không có** | Nên thêm | Nên thêm |
| **Connection** | Mở/đóng mỗi request, gần như miễn phí | ⚠️ **Bắt buộc dùng pool** — mở connection tốn hàng chục ms. Đã có `psycopg_pool` | Bắt buộc pool |

### 3.5 Thiết kế NGAY BÂY GIỜ để migrate sau này đỡ đau

Sáu việc, làm khi DB còn nhỏ thì gần như miễn phí:

1. **Repository pattern triệt để.** Đã có `repository/` với `interface.py` + `sqlite_repo.py` + `postgres_repo.py` — thiết kế đúng. Nhưng vẫn còn **SQL thô trong 4 router**: `routers/admin.py`, `routers/devices.py`, `routers/enrollment.py`, `routers/sessions.py`. Đây chính là những chỗ sẽ vỡ âm thầm khi đổi backend — đưa hết vào repository trước khi cutover.
2. **Không dùng đặc sản SQLite:** không `COLLATE NOCASE`, không `rowid`, không dựa vào kiểu động, không `INSERT OR REPLACE` ngoài repository.
3. **Mọi thời gian đều UTC-aware.** Đã có migration `001_purge_naive_timestamps` xử lý hậu quả — đừng để tái diễn.
4. **Một nguồn DDL duy nhất** thay cho hai file schema sửa tay.
5. **Test suite chạy được trên cả hai backend** trong CI (biến `IZIIAPP_DB_BACKEND`). Đây là lưới an toàn rẻ nhất chống drift.
6. **Không thêm foreign key vào SQLite rồi tưởng là có ràng buộc** — SQLite mặc định tắt enforcement. Ràng buộc phải kiểm ở tầng ứng dụng cho tới khi lên PG.

### 3.6 Công cụ hỗ trợ

| Việc | Công cụ | Ghi chú |
|---|---|---|
| Migrate dữ liệu SQLite → PG | **`migrate_to_postgres.py` sẵn có** (sau khi sửa P2) | Phù hợp quy mô hiện tại. Không cần công cụ ngoài |
| Phương án dự phòng | `pgloader` | Tự động suy ra kiểu, xử lý DB lớn. Chỉ cần nếu DB > vài GB |
| Version hoá schema | **Alembic** | Hỗ trợ cả SQLite lẫn PG, thuần Python, hợp stack hiện tại |
| So sánh schema hai bên | `apgdiff`, `migra` | Dùng trong CI để bắt drift |
| Backup PG | `pg_dump` (logical) + **`pgBackRest`** (PITR) | pgBackRest cho RPO < 1 phút |
| Backup SQLite | `VACUUM INTO` + `restic` | Đủ và tối ưu cho giai đoạn hiện tại |
| Giám sát PG | `pg_stat_statements`, Prometheus `postgres_exporter` | Bật `pg_stat_statements` ngay từ ngày đầu |
| Nếu chọn MSSQL | SSMA for SQLite (hạn chế), **Ola Hallengren Maintenance Solution** | Ola Hallengren là chuẩn de-facto cho backup/index job trên MSSQL |

---

## 4. Rủi ro & lưu ý

| # | Rủi ro | Mức độ | Ảnh hưởng | Giảm thiểu |
|---|---|---|---|---|
| R1 | **Không có backup nào đang chạy** (P1) | 🔴 Nghiêm trọng | Hỏng ổ SSD = mất toàn bộ dữ liệu vận hành | §1.5 mục 1–3, làm trong tuần này |
| R2 | **`migrate_to_postgres.py` bỏ sót 4 bảng** (P2) | 🔴 Nghiêm trọng | Mất device token, PIN nhân viên, lịch sử phiên — **script vẫn báo thành công** | Sửa `TABLES` + thêm assert đối chiếu với schema |
| R3 | Copy file `.db` khi đang chạy (kể cả OneDrive tự sync) | 🔴 Nghiêm trọng | Backup corrupt, chỉ phát hiện lúc cần restore | Chỉ dùng `VACUUM INTO` / Backup API. **Loại thư mục data khỏi phạm vi OneDrive sync** |
| R4 | Backup thiếu `uploads/`, `.env`, TLS certs | 🟠 Cao | Restore xong app vẫn hỏng: link chết, mọi thiết bị phải enroll lại | Đưa cả 3 vào script backup |
| R5 | `prune` chỉ chạy lúc startup (P3) | 🟠 Cao | `sync_mutations` phình vô hạn trên server chạy dài | Chuyển thành job định kỳ 24h |
| R6 | `webhook_dead_letters`, `enrollment_tokens` không có prune | 🟡 Trung bình | Tăng trưởng chậm nhưng không giới hạn | Bổ sung job |
| R6b | **`prune_message_queue_postgres()` không tồn tại** (P4) | 🔴 Nghiêm trọng | Sau khi lên PG: tin kẹt không được dead-letter → tái diễn sự cố 1.173 tin kẹt 11/08 | Viết hàm này **trước** khi cutover PG |
| R7 | Hai file schema sửa tay → drift | 🟠 Cao | R2 chính là hệ quả đã xảy ra | Một nguồn DDL + CI test hai backend |
| R8 | `seq` không UNIQUE | 🟠 Cao | Trùng seq → client **bỏ sót mutation, im lặng** | `UNIQUE (origin_server_id, seq)` |
| R9 | Peer khác version schema | 🟡 Trung bình | Mutation mất cột khi relay, không có lỗi | Trao đổi `schema_version` trong handshake peer-sync |
| R10 | Collation tiếng Việt đổi sau migrate | 🟡 Trung bình | `ORDER BY` tên nhân viên ra thứ tự khác; tìm kiếm không dấu hỏng | Quyết định collation **trước** cutover, có test case tên có dấu |
| R11 | Replication ≠ backup | 🟠 Cao | Xoá nhầm được nhân bản sang mọi node trong 45 giây | Backup độc lập theo thời điểm, có versioning |
| R12 | Nâng Uvicorn workers khi còn SQLite | 🟡 Trung bình | Tăng tranh chấp writer, xuất hiện `database is locked` | Tăng worker **sau** khi lên PG, không phải trước |
| R13 | Chưa có RTO/RPO được ký duyệt | 🟠 Cao | Không có tiêu chí để nghiệm thu chiến lược backup | Xem Q1 dưới đây |
| R14 | Chưa từng diễn tập restore | 🔴 Nghiêm trọng | Backup có thể đã hỏng từ lâu mà không ai biết | Restore drill mỗi quý, có biên bản |

---

## 5. Câu hỏi cần bổ sung để tư vấn chính xác hơn

Những phần trên đã dùng dữ liệu thật từ code. Sáu câu dưới đây là các chỗ **không thể suy ra từ repo** và sẽ thay đổi khuyến nghị:

**Q1 — RTO/RPO chấp nhận được là bao nhiêu?**
Downtime tối đa và lượng dữ liệu tối đa được phép mất. Ca thu hoạch nấm dừng 4 tiếng có chấp nhận được không? Mất 15 phút dữ liệu thu hoạch thì tổn thất thế nào? *Đây là con số quyết định toàn bộ §1 — mọi thứ khác chỉ là hệ quả.*

**Q2 — Số liệu production thật.** Repo chỉ có DB dev 168 KB. Cần: dung lượng `iziiapp.db` trên node đang chạy thật, `COUNT(*)` của `sync_mutations`, và mức tăng mỗi tháng. Không có con số này thì mọi ước lượng partition/retention chỉ là phỏng đoán.

**Q3 — ERP/WMS trung tâm của Costa chạy engine gì?**
Nếu là MSSQL và có yêu cầu đối soát trực tiếp, khuyến nghị ở §3.2 cần điều chỉnh. Nếu tích hợp chỉ qua API/webhook thì PostgreSQL là lựa chọn rõ ràng.

**Q4 — Ai vận hành DB sau khi lên PG?**
Có DBA nội bộ, hay IT nhà máy quen Windows/SSMS? Nếu là vế sau, cần tính thêm chi phí đào tạo hoặc cân nhắc PG managed (RDS/Azure Flexible Server) cho tầng trung tâm.

**Q5 — Có ràng buộc pháp lý về lưu trữ dữ liệu không?**
Dữ liệu ATLĐ và truy xuất nguồn gốc nông sản (Úc) thường có yêu cầu giữ nhiều năm. Có yêu cầu dữ liệu phải nằm trong lãnh thổ Úc không? Điều này quyết định chọn vùng cloud cho off-site backup.

**Q6 — Ngân sách và cửa sổ downtime cho cutover.**
Có được phép dừng 2–4 tiếng ngoài giờ ca không? Có ngân sách cho cloud storage off-site (~5–20 USD/tháng ở quy mô này), hay bắt buộc chỉ dùng hạ tầng nội bộ?

---

## 6. Tóm tắt — làm gì trước

| Ưu tiên | Việc | Công sức | Rủi ro nếu bỏ qua |
|---|---|---|---|
| **1** | Script backup + 3 task Scheduler (`VACUUM INTO` + `uploads` + `.env`) | 0,5 ngày | 🔴 Mất toàn bộ dữ liệu |
| **2** | Sửa `TABLES` trong `migrate_to_postgres.py` (4 bảng) | 1 giờ | 🔴 Mất dữ liệu lúc migrate |
| **2b** | Viết `prune_message_queue_postgres()` | 1 giờ | 🔴 Tin nhắn kẹt vô hạn sau cutover |
| **3** | Loại thư mục data khỏi phạm vi OneDrive sync | 15 phút | 🔴 Backup/DB corrupt |
| **4** | Off-site: `restic` sang cloud hoặc node plant khác | 0,5 ngày | 🟠 Không sống sót sự cố toàn site |
| **5** | Chuyển `prune_*` thành job định kỳ 24h | 2 giờ | 🟠 DB phình vô hạn |
| **6** | Chốt RTO/RPO với stakeholder (Q1) | 1 buổi họp | 🟠 Không nghiệm thu được |
| **7** | Restore drill lần đầu | 0,5 ngày | 🔴 Backup có thể vô dụng |
| **8** | Alembic + một nguồn DDL + CI hai backend | 2–3 ngày | 🟠 Drift tiếp diễn |
| **9** | PG staging + chạy thử migrate | 2 ngày | — |
| **10** | Cutover PG từng node | 1 ngày/node | — |

---

*Báo cáo dựa trên source code tại `izii_app` — commit hiện có trên máy, ngày 22/08/2026. Các số liệu vận hành thật (Q2) sẽ tinh chỉnh phần retention và partition.*
