# iZiiApp — Scale-Ready Architecture
## IIS (Reverse Proxy) + Uvicorn (ASGI) + Windows + SQLite → Production-Ready

> **Branch:** `mushroom-farm-fork` | **Target:** 200 DAU → 5,000+ DAU  
> **Stack:** Flutter (Client) · IIS (SSL Termination & ARR) · Uvicorn (ASGI Server) · SQLite/PostgreSQL · Python/FastAPI

---

## 1. Tổng quan kiến trúc

Kiến trúc sản xuất sử dụng **IIS** đóng vai trò là Reverse Proxy chịu trách nhiệm SSL Termination, Rate Limiting và định tuyến yêu cầu. Toàn bộ logic ứng dụng Python/FastAPI được thực thi bởi máy chủ **Uvicorn (ASGI)** chạy dưới dạng một Windows Service độc lập. Dữ liệu được lưu trữ trên **SQLite** cấu hình WAL mode ở ổ đĩa SSD tốc độ cao.

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│   Flutter App (iOS · Android · Desktop)                         │
│   Local SQLite (Drift ORM) · BLE P2P Module · BLoC State       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS / WSS
┌──────────────────────────▼──────────────────────────────────────┐
│                  IIS (REVERSE PROXY LAYER)                      │
│   Windows Server · SSL Termination · URL Rewrite · ARR          │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ Default Web Site (Port 443)                             │   │
│   │ - Route /api/*  ──► Proxy to http://127.0.0.1:8000      │   │
│   │ - Route /ws/*   ──► Proxy to http://127.0.0.1:8000      │   │
│   └─────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTP / WS (Local Loopback)
┌──────────────────────────▼──────────────────────────────────────┐
│                  UVIVORN ASGI SERVER LAYER                      │
│   Windows Service (Managed by NSSM)                             │
│   Uvicorn (FastAPI Application · Port 8000)                     │
│   Running 4 Async Workers (Concurrency optimized)               │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Local File I/O (WAL + Busy Timeout)
┌──────────────────────────▼──────────────────────────────────────┐
│                       DATA LAYER                                │
│   SQLite (WAL mode) ──[migrate]──► PostgreSQL                   │
│   D:\data\iziiapp.db (SSD Drive)                                │
└─────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
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
Uvicorn          Uvicorn (Scale)  Uvicorn Cluster    Microservices
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

## 4. IIS & Uvicorn Configuration

### Cấu hình Uvicorn Windows Service (Sử dụng NSSM)

Để đảm bảo Uvicorn tự khởi động lại khi server reboot hoặc khi bị crash, chúng ta cài đặt Uvicorn làm Windows Service thông qua **NSSM (Non-Sucking Service Manager)**:

```bash
# Cài đặt dịch vụ Uvicorn
nssm install iZiiApp-Uvicorn "C:\Users\CHANH\AppData\Local\Programs\Python\Python311\python.exe" "-m uvicorn main:app --host 127.0.0.1 --port 8000 --workers 4"

# Thiết lập thư mục làm việc của dự án
nssm set iZiiApp-Uvicorn AppDirectory "C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app"

# Thiết lập ghi log xuất nhập của Uvicorn
nssm set iZiiApp-Uvicorn AppStdout "D:\logs\app\uvicorn_stdout.log"
nssm set iZiiApp-Uvicorn AppStderr "D:\logs\app\uvicorn_stderr.log"

# Khởi chạy dịch vụ
nssm start iZiiApp-Uvicorn
```

> **Lưu ý về số lượng Workers:**  
> Công thức tính worker tối ưu: `workers = (2 * CPU cores) + 1`.  
> Khi chạy SQLite với nhiều workers của Uvicorn, WAL mode và cấu hình `busy_timeout` là bắt buộc để tránh lock DB giữa các tiến trình worker.

### Cấu hình IIS Reverse Proxy (web.config)

IIS sẽ nhận kết nối ngoài (cổng 80/443), thực hiện giải mã SSL và chuyển tiếp yêu cầu đến Uvicorn tại địa chỉ `http://127.0.0.1:8000`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <!-- Proxy toàn bộ WebSocket connections lên Uvicorn -->
        <rule name="WebSocket Proxy" stopProcessing="true">
          <match url="^ws/(.*)" />
          <conditions>
            <add input="{HTTP_CONNECTION}" pattern="Upgrade" />
          </conditions>
          <action type="Rewrite" url="http://127.0.0.1:8000/ws/{R:1}" />
        </rule>
        
        <!-- Proxy toàn bộ HTTP API REST lên Uvicorn -->
        <rule name="API Proxy" stopProcessing="true">
          <match url="^(.*)" />
          <action type="Rewrite" url="http://127.0.0.1:8000/{R:1}" />
        </rule>
      </rules>
    </rewrite>
    
    <!-- Cho phép truyền header Authorization và cấu hình kích thước dữ liệu -->
    <security>
      <requestFiltering>
        <requestLimits maxAllowedContentLength="104857600" /> <!-- 100 MB -->
      </requestFiltering>
    </security>
  </system.webServer>
</configuration>
```

---

## 5. SQLite — Cấu hình Production

### Thiết lập PRAGMA tối ưu hóa hiệu năng & concurrency

Khi Uvicorn chạy ở chế độ đa tiến trình (multi-workers), SQLite cần được cấu hình các thông số PRAGMA đặc thù trên **mỗi connection khởi tạo** để đảm bảo không bị lock write tranh chấp.

```python
import sqlite3
from contextlib import contextmanager

DB_PATH = r"D:\data\iziiapp.db"

def get_db_connection():
    conn = sqlite3.connect(
        DB_PATH,
        timeout=10.0 # Timeout mặc định ở mức driver
    )
    conn.row_factory = sqlite3.Row
    
    # Kích hoạt chế độ ghi nhật ký WAL (Write-Ahead Logging)
    conn.execute("PRAGMA journal_mode=WAL;")
    
    # NORMAL giúp ghi đĩa bất đồng bộ, cân bằng giữa tốc độ và an toàn dữ liệu
    conn.execute("PRAGMA synchronous=NORMAL;")
    
    # busy_timeout (Bắt buộc cho Multi-workers Uvicorn):
    # Đợi giải phóng lock write tối đa 5000ms trước khi ném ra lỗi Database Locked
    conn.execute("PRAGMA busy_timeout=5000;")
    
    # Cấu hình cache size 64MB tăng hiệu suất đọc
    conn.execute("PRAGMA cache_size=-64000;")
    
    # Lưu bảng tạm trong bộ nhớ RAM thay vì ghi đĩa
    conn.execute("PRAGMA temp_store=MEMORY;")
    
    # Bật Memory-Mapped I/O lên 256MB tăng tốc độ truy xuất file lớn
    conn.execute("PRAGMA mmap_size=268435456;")
    
    return conn
```

---

## 6. Data Access Layer — Abstraction để dễ migrate

Để việc di chuyển từ SQLite sang PostgreSQL trong tương lai diễn ra trơn tru mà không cần sửa đổi mã nguồn business logic, chúng ta tách biệt hoàn toàn thông qua lớp Interface Repository và sử dụng Dependency Injection của FastAPI.

```python
# repository/interface.py
from abc import ABC, abstractmethod
from typing import List, Dict, Any

class IHarvestRepository(ABC):
    @abstractmethod
    def get_harvest_jobs(self, room_name: str) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def create_harvest_job(self, job_data: Dict[str, Any]) -> Dict[str, Any]:
        pass

    @abstractmethod
    def update_job_status(self, job_id: str, status: str) -> bool:
        pass


# repository/sqlite_repo.py
import sqlite3
from repository.interface import IHarvestRepository

class SQLiteHarvestRepository(IHarvestRepository):
    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def get_harvest_jobs(self, room_name: str) -> List[dict]:
        cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM harvest_jobs WHERE roomName = ?", (room_name,))
        return [dict(row) for row in cursor.fetchall()]

    def create_harvest_job(self, job_data: dict) -> dict:
        cursor = self.conn.cursor()
        cursor.execute(
            "INSERT INTO harvest_jobs (id, roomName, status) VALUES (?, ?, ?)",
            (job_data['id'], job_data['roomName'], job_data['status'])
        )
        self.conn.commit()
        return job_data

    def update_job_status(self, job_id: str, status: str) -> bool:
        cursor = self.conn.cursor()
        cursor.execute("UPDATE harvest_jobs SET status = ? WHERE id = ?", (status, job_id))
        self.conn.commit()
        return cursor.rowcount > 0


# dependencies.py (FastAPI Dependency Injection)
from fastapi import Depends
import sqlite3
from repository.sqlite_repo import SQLiteHarvestRepository

def get_db():
    # Khởi tạo db connection kèm PRAGMA tối ưu
    conn = sqlite3.connect(r"D:\data\iziiapp.db")
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA busy_timeout=5000;")
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()

def get_harvest_repo(conn: sqlite3.Connection = Depends(get_db)):
    return SQLiteHarvestRepository(conn)


# api/endpoints.py (Sử dụng Repository Interface)
from fastapi import APIRouter, Depends
from repository.interface import IHarvestRepository
from dependencies import get_harvest_repo

router = APIRouter()

@router.get("/rooms/{room_name}/jobs")
def read_jobs(room_name: str, repo: IHarvestRepository = Depends(get_harvest_repo)):
    return repo.get_harvest_jobs(room_name)
```

---

## 7. Backup Plan

| Loại | Công cụ | Tần suất | Giữ | Lưu ở đâu |
|---|---|---|---|---|
| Hot backup | SQLite Online Backup API | Mỗi 15 phút | 24h | `D:\data\backups\hot\` |
| Daily snapshot | Task Scheduler + script | 02:00 hàng đêm | 30 ngày | `D:\data\backups\daily\` |
| Weekly archive | Task Scheduler + script | Chủ nhật 03:00 | 12 tuần | `D:\data\backups\weekly\` |
| Off-site | Rclone → Cloud (B2/S3) | Sau mỗi daily | 90 ngày | Cloud storage |
| Uvicorn Service | Registry Export (NSSM) | Mỗi khi cập nhật service | Vĩnh viễn | `D:\data\backups\services\` |

### Script sao lưu Uvicorn Service và SQLite database an toàn:

```python
# scripts/backup_system.py
import sqlite3
import datetime
import os
import subprocess

DB_PATH = r"D:\data\iziiapp.db"
BACKUP_DIR = r"D:\data\backups\daily"
SERVICE_BACKUP_DIR = r"D:\data\backups\services"
KEEP_DAYS = 30

def backup():
    today = datetime.date.today().strftime("%Y%m%d")
    os.makedirs(BACKUP_DIR, exist_ok=True)
    os.makedirs(SERVICE_BACKUP_DIR, exist_ok=True)
    
    # 1. Hot Backup database sử dụng SQLite Online Backup API
    db_dst = os.path.join(BACKUP_DIR, f"iziiapp_{today}.db")
    src_conn = sqlite3.connect(DB_PATH)
    dst_conn = sqlite3.connect(db_dst)
    src_conn.backup(dst_conn, pages=100) # Backup an toàn không block write
    dst_conn.close()
    src_conn.close()
    print(f"[OK] Database Backup: {db_dst}")

    # 2. Backup registry cấu hình dịch vụ Uvicorn từ NSSM
    reg_dst = os.path.join(SERVICE_BACKUP_DIR, f"uvicorn_service_{today}.reg")
    try:
        subprocess.run(
            f'reg export HKLM\\System\\CurrentControlSet\\Services\\iZiiApp-Uvicorn "{reg_dst}" /y',
            shell=True,
            check=True
        )
        print(f"[OK] Service Configuration Backup: {reg_dst}")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Service Backup failed: {e}")

    # 3. Dọn dẹp các backup cũ
    cutoff = datetime.date.today() - datetime.timedelta(days=KEEP_DAYS)
    for f in os.listdir(BACKUP_DIR):
        if f.startswith("iziiapp_") and f.endswith(".db"):
            try:
                file_date = datetime.datetime.strptime(f[8:16], "%Y%m%d").date()
                if file_date < cutoff:
                    os.remove(os.path.join(BACKUP_DIR, f))
            except ValueError:
                pass

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
| < 400 DAU | Giữ SQLite WAL + Uvicorn Service — không cần thay đổi |
| 400–800 DAU | Nâng RAM lên 16 GB, tăng workers của Uvicorn |
| > 800 DAU | Lên kế hoạch migrate sang PostgreSQL |
| > 2,000 DAU | Triển khai Redis cache + PostgreSQL Cluster |

---

## 9. Checklist triển khai theo thứ tự ưu tiên

### Ngay lập tức
- [ ] Đăng ký Uvicorn làm Windows Service bằng NSSM, cấu hình tự động khởi chạy lại
- [ ] Chuyển SQLite data file sang ổ SSD chuyên dụng
- [ ] Bật chế độ WAL mode + Normal sync + Busy Timeout = 5s trên API Connection
- [ ] Thiết lập file script backup tự động SQLite Database + NSSM Service cấu hình

### Tuần này
- [ ] Cấu hình IIS Web Site làm Reverse Proxy thông qua URL Rewrite và Application Request Routing (ARR)
- [ ] Tắt hoàn toàn CGI/FastCGI App Pool không cần thiết trên IIS
- [ ] Bật IIS logging lưu trữ tại ổ đĩa log chuyên biệt `D:\logs\iis\`

### Khi thiết kế tính năng mới
- [ ] Luôn sử dụng Repository Pattern thông qua `IHarvestRepository`
- [ ] Quản lý toàn bộ thông số kết nối (DB path, port, workers, domains) qua file `.env`
- [ ] Không hardcode IP/domain ở phía client Flutter app

---

## 10. So sánh SQLite vs PostgreSQL (trong môi trường Uvicorn)

| Tiêu chí | SQLite (WAL + Uvicorn) | PostgreSQL (Uvicorn) |
|---|---|---|
| **Cài đặt & Vận hành** | Cực kỳ đơn giản, không cần cài engine | Phức tạp hơn, cần vận hành PostgreSQL service độc lập |
| **Concurrency (Write)** | Hỗ trợ ghi song song ở mức tiến trình nhờ `busy_timeout` khóa tạm thời | Hỗ trợ ghi song song thực sự, transaction isolation cấp cao |
| **Network overhead** | Bằng 0 (truy xuất trực tiếp file cục bộ SSD) | Có (truy xuất qua socket TCP/IP) |
| **Worker processes** | Tốt nhất khi giữ số lượng worker vừa phải | Không giới hạn, hỗ trợ hàng trăm workers |
| **Khả năng backup** | Hot backup online file cực kỳ tiện lợi | pg_dump / WAL-G phức tạp nhưng hỗ trợ khôi phục đến từng giây |
| **Độ tin cậy** | Hoàn hảo cho single-server < 800 DAU | Hoàn hảo cho multi-server, clustering, cloud native |

---

*Tài liệu này là thiết kế sống — cập nhật khi architecture thay đổi.*  
*Last updated: 2026-07-10*
