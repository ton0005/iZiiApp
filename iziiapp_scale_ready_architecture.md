# iZiiApp — Scale-Ready Architecture
## IIS + Windows + SQLite → Production-Ready

> **Branch:** `mushroom-farm-fork` | **Target:** 200 DAU → 5,000+ DAU  
> **Stack:** Flutter (Client) · IIS (Windows Server) · SQLite/PostgreSQL · Python/FastAPI

---

## 1. Tổng quan kiến trúc

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│   Flutter App (iOS · Android · Desktop)                         │
│   Local SQLite (Drift ORM) · BLE P2P Module · BLoC State       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS / WSS
┌──────────────────────────▼──────────────────────────────────────┐
│                      IIS / REVERSE PROXY                        │
│   Windows Server · SSL Termination · Rate Limiting              │
│   ┌──────────────────┐          ┌──────────────────────┐        │
│   │   API App Pool   │          │  WebSocket App Pool  │        │
│   │  (sync, CRUD)    │          │   (realtime, chat)   │        │
│   └────────┬─────────┘          └──────────┬───────────┘        │
└────────────┼──────────────────────────────┼────────────────────┘
             │                              │
┌────────────▼──────────────────────────────▼────────────────────┐
│                       DATA LAYER                                │
│   SQLite (WAL mode) ──[migrate]──► PostgreSQL                   │
│   D:\data\iziiapp.db                                            │
└────────────────────────────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────────────────┐
│                    NOTIFICATION LAYER                           │
│   FCM / APNS · Email (Delayed Queue) · In-app Inbox             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Lộ trình mở rộng theo số User

```
Phase 1          Phase 2          Phase 3          Phase 4
200 DAU    →     500 DAU    →     1,000 DAU  →     5,000+ DAU
────────         ────────         ─────────         ──────────
1 server         1 server         2 servers         N servers
8 GB RAM         16 GB RAM        32 GB RAM         Load Balancer
SSD 200 GB       SSD 500 GB       SSD 1 TB          PostgreSQL
SQLite WAL       SQLite WAL       PostgreSQL         Redis Cache
IIS 1 Pool       IIS 2 Pools      Reverse Proxy      Microservices
```

---

## 3. Phần cứng — Cấu hình theo Phase

### Phase 1 — Baseline (200 DAU)

| Thành phần | Yêu cầu | Ghi chú |
|---|---|---|
| CPU | 4 core / 2.5 GHz+ | IIS + SQLite không nặng CPU |
| RAM | **8 GB** | Windows ~2–3 GB · App ~2 GB · SQLite cache ~2 GB |
| OS Drive | SSD 60 GB | Boot, IIS binaries, logs |
| **Data Drive** | **SSD 100–200 GB** | **Bắt buộc SSD — HDD gây write bottleneck** |
| Network | 100 Mbps | Dư thừa cho 200 DAU |

> ⚠ **HDD tuyệt đối không dùng cho SQLite data file.**  
> Random I/O HDD ~100–150 IOPS sẽ tạo write queue và timeout ngay cả với tải nhỏ.

### Phase 2 — Growth (500 DAU)

| Thành phần | Nâng cấp |
|---|---|
| RAM | 16 GB |
| Data Drive | SSD 500 GB |
| IIS | Tách thành 2 App Pool riêng (API + WebSocket) |

### Phase 3 — Scale (1,000 DAU)

| Thành phần | Nâng cấp |
|---|---|
| RAM | 32 GB |
| Database | Migrate từ SQLite sang **PostgreSQL** |
| Storage | SSD 1 TB hoặc tách DB server riêng |
| App | Thêm 1 server, đặt reverse proxy phía trước |

### Phase 4 — Enterprise (5,000+ DAU)

| Thành phần | Nâng cấp |
|---|---|
| Architecture | Load Balancer + nhiều app node |
| Cache | Redis cho session, hot data, notification queue |
| Database | PostgreSQL cluster (primary + replica) |
| Notifications | Managed queue (Redis Queue / AWS SQS) |

---

## 4. IIS Configuration

### App Pool — Tách từ đầu (quan trọng)

```
IIS
├── App Pool: iZiiApp-API          ← Sync, CRUD, REST
│   ├── .NET CLR: No Managed Code (nếu dùng Python FastAPI)
│   ├── Pipeline: Integrated
│   └── Worker Processes: 1        ← PHẢI là 1 khi dùng SQLite
│
└── App Pool: iZiiApp-WebSocket    ← Realtime, Chat
    ├── Pipeline: Integrated
    └── Worker Processes: 1
```

> Giữ **1 worker process duy nhất** cho mỗi pool khi dùng SQLite.  
> Nhiều worker process tranh nhau file SQLite → lock conflict.

### IIS Reverse Proxy sang FastAPI (Python)

Cài module: `Application Request Routing (ARR)` + `URL Rewrite`

```xml
<!-- web.config -->
<system.webServer>
  <rewrite>
    <rules>
      <rule name="API Proxy" stopProcessing="true">
        <match url="^api/(.*)" />
        <action type="Rewrite" url="http://127.0.0.1:8000/{R:1}" />
      </rule>
      <rule name="WebSocket Proxy" stopProcessing="true">
        <match url="^ws/(.*)" />
        <action type="Rewrite" url="http://127.0.0.1:8001/{R:1}" />
      </rule>
    </rules>
  </rewrite>
</system.webServer>
```

---

## 5. SQLite — Cấu hình Production

### Bật WAL mode (bắt buộc)

```python
# Chạy 1 lần khi khởi động server
import sqlite3

conn = sqlite3.connect(r"D:\data\iziiapp.db")
conn.execute("PRAGMA journal_mode=WAL;")
conn.execute("PRAGMA synchronous=NORMAL;")   # Cân bằng safety vs speed
conn.execute("PRAGMA cache_size=-64000;")    # 64 MB page cache
conn.execute("PRAGMA temp_store=MEMORY;")
conn.execute("PRAGMA mmap_size=268435456;")  # 256 MB memory-mapped I/O
conn.close()
```

### WAL mode cho phép

```
Không có WAL          Có WAL
─────────────         ──────────────────────────────
Reader chờ Writer     Reader và Writer chạy song song
1 connection tại 1    N readers + 1 writer đồng thời
thời điểm             Throughput tăng 2–5x
```

### Cấu trúc thư mục data

```
D:\
├── app\
│   └── iziiapp\              ← IIS application files
├── data\
│   ├── iziiapp.db            ← SQLite main database
│   ├── iziiapp.db-wal        ← WAL file (tự động)
│   ├── iziiapp.db-shm        ← Shared memory (tự động)
│   └── backups\
│       ├── hot\              ← Backup mỗi 15 phút, giữ 24h
│       ├── daily\            ← Backup mỗi đêm, giữ 30 ngày
│       └── weekly\           ← Giữ 12 tuần
└── logs\
    ├── iis\
    └── app\
```

---

## 6. Data Access Layer — Abstraction để dễ migrate

Thiết kế interface từ đầu để swap SQLite → PostgreSQL không cần refactor business logic:

```python
# repository/interface.py
from abc import ABC, abstractmethod
from typing import List, Optional

class IDataRepository(ABC):

    @abstractmethod
    def get_harvest_jobs(self, room_id: str) -> List[dict]:
        pass

    @abstractmethod
    def create_harvest_job(self, job: dict) -> dict:
        pass

    @abstractmethod
    def update_job_status(self, job_id: str, status: str) -> bool:
        pass

# repository/sqlite_repo.py
class SQLiteRepository(IDataRepository):
    def __init__(self, db_path: str):
        self.db_path = db_path

    def get_harvest_jobs(self, room_id: str) -> List[dict]:
        # SQLite implementation
        ...

# repository/postgres_repo.py  ← Tương lai, swap in khi cần
class PostgreSQLRepository(IDataRepository):
    def __init__(self, connection_string: str):
        self.conn_str = connection_string

    def get_harvest_jobs(self, room_id: str) -> List[dict]:
        # PostgreSQL implementation — same interface
        ...

# main.py — chỉ đổi 1 dòng khi migrate
# repo = SQLiteRepository(r"D:\data\iziiapp.db")
repo = PostgreSQLRepository("postgresql://user:pass@localhost/iziiapp")
```

---

## 7. Backup Plan

| Loại | Công cụ | Tần suất | Giữ | Lưu ở đâu |
|---|---|---|---|---|
| Hot backup | SQLite Online Backup API | Mỗi 15 phút | 24h | `D:\data\backups\hot\` |
| Daily snapshot | Task Scheduler + script | 02:00 hàng đêm | 30 ngày | `D:\data\backups\daily\` |
| Weekly archive | Task Scheduler + script | Chủ nhật 03:00 | 12 tuần | `D:\data\backups\weekly\` |
| Off-site | Rclone → Cloud (B2/S3) | Sau mỗi daily | 90 ngày | Cloud storage |
| IIS config | `appcmd export config` | Mỗi khi deploy | Vĩnh viễn | Git repo |

### Script backup SQLite (Python — chạy qua Task Scheduler)

```python
# scripts/backup_sqlite.py
import sqlite3
import shutil
import datetime
import os

DB_PATH    = r"D:\data\iziiapp.db"
BACKUP_DIR = r"D:\data\backups\daily"
KEEP_DAYS  = 30

def backup():
    today = datetime.date.today().strftime("%Y%m%d")
    dst   = os.path.join(BACKUP_DIR, f"iziiapp_{today}.db")

    os.makedirs(BACKUP_DIR, exist_ok=True)

    # Dùng SQLite Online Backup API — an toàn kể cả khi DB đang write
    src_conn = sqlite3.connect(DB_PATH)
    dst_conn = sqlite3.connect(dst)
    src_conn.backup(dst_conn, pages=100)   # pages=100: backup từng chunk, không block
    dst_conn.close()
    src_conn.close()

    # Xóa backup cũ hơn KEEP_DAYS ngày
    cutoff = datetime.date.today() - datetime.timedelta(days=KEEP_DAYS)
    for f in os.listdir(BACKUP_DIR):
        if f.startswith("iziiapp_") and f.endswith(".db"):
            try:
                file_date = datetime.datetime.strptime(f[8:16], "%Y%m%d").date()
                if file_date < cutoff:
                    os.remove(os.path.join(BACKUP_DIR, f))
            except ValueError:
                pass

    print(f"[OK] Backup: {dst}")

if __name__ == "__main__":
    backup()
```

---

## 8. Concurrent Users — Ước tính tải thực tế

Với 200 DAU (daily active users):

| Thời điểm | Concurrent Users | Requests/phút | SQLite IOPS ước tính |
|---|---|---|---|
| Thường | 10–30 | ~50–150 | ~20–60 |
| Cao điểm (đầu/cuối ca) | 40–80 | ~200–400 | ~80–160 |
| Peak tệ nhất | ~100 | ~500 | ~200 |

SSD NVMe thông thường đạt 50,000–200,000 IOPS → **dư thừa hoàn toàn cho 200 DAU**.

| Ngưỡng DAU | Hành động cần thiết |
|---|---|
| < 400 DAU | Giữ SQLite WAL — không cần thay đổi |
| 400–800 DAU | Nâng RAM lên 16 GB, theo dõi write latency |
| > 800 DAU | Lên kế hoạch migrate sang PostgreSQL |
| > 2,000 DAU | Triển khai Redis cache + connection pooling |

---

## 9. Checklist triển khai theo thứ tự ưu tiên

### Ngay lập tức
- [ ] Chuyển SQLite data file sang SSD
- [ ] Bật WAL mode + PRAGMA tối ưu
- [ ] Cài backup script + Task Scheduler (hot 15 phút + daily)
- [ ] Cấu hình IIS: 1 worker process per app pool

### Tuần này
- [ ] Tách IIS thành 2 App Pool: API + WebSocket
- [ ] Cấu hình URL Rewrite / ARR nếu dùng reverse proxy
- [ ] Thiết lập off-site backup (Rclone → cloud)
- [ ] Bật IIS logging → `D:\logs\iis\`

### Khi thiết kế tính năng mới
- [ ] Dùng `IDataRepository` interface cho tất cả data access
- [ ] Đặt tất cả config (DB path, port, base URL) vào file `.env` / config
- [ ] Không hardcode IP/domain trong Flutter app

### Khi đạt 400+ DAU
- [ ] Theo dõi write latency SQLite (`PRAGMA compile_options` + logging)
- [ ] Nâng RAM server lên 16 GB
- [ ] Bắt đầu chuẩn bị PostgreSQL migration script

---

## 10. So sánh SQLite vs PostgreSQL

| Tiêu chí | SQLite (Phase 1–2) | PostgreSQL (Phase 3+) |
|---|---|---|
| Setup | Không cần cài đặt riêng | Cần cài + cấu hình service |
| Concurrent writes | 1 writer tại 1 thời điểm | N writers đồng thời |
| Backup | File copy / Online Backup API | pg_dump, point-in-time recovery |
| Replication | Không native | Streaming replication |
| Phù hợp | < 800 DAU, single server | > 800 DAU, multi-server |
| Migration effort | — | Trung bình (nếu dùng IDataRepository) |

---

*Tài liệu này là thiết kế sống — cập nhật khi architecture thay đổi.*  
*Last updated: {{ date }}*
