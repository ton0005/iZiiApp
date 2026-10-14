# Hướng dẫn chi tiết Build & Chạy iZiiServer trên Ubuntu / Linux

Tài liệu này hướng dẫn chi tiết từng bước cách cài đặt, đóng gói (build binary), cấu hình dịch vụ hệ thống (systemd) và triển khai Docker cho **iZiiServer** trên hệ điều hành **Ubuntu 20.04 / 22.04 / 24.04 LTS** (hoặc Debian/Linux tương đương).

---

## Mục lục
1. [Yêu cầu hệ thống & Chuẩn bị môi trường](#1-yêu-cầu-hệ-thống--chuẩn-bị-môi-trường)
2. [Cách 1: Chạy trực tiếp với Python Virtualenv & Systemd Service (Khuyến nghị cho Production)](#2-cách-1-chạy-trực-tiếp-với-python-virtualenv--systemd-service-khuyến-nghị)
3. [Cách 2: Build file nhị phân độc lập (Standalone Linux Binary) bằng PyInstaller](#3-cách-2-build-file-nhị-phân-độc-lập-bằng-pyinstaller)
4. [Cách 3: Triển khai bằng Docker & Docker Compose](#4-cách-3-triển-khai-bằng-docker--docker-compose)
5. [Cấu hình Nginx Reverse Proxy & SSL (Tuỳ chọn)](#5-cấu-hình-nginx-reverse-proxy--ssl-tuỳ-chọn)
6. [Kiểm tra & Xác minh hoạt động](#6-kiểm-tra--xác-minh-hoạt-động)
7. [Xử lý sự cố thường gặp trên Linux](#7-xử-lý-sự-cố-thường-gặp-trên-linux)

---

## 1. Yêu cầu hệ thống & Chuẩn bị môi trường

### 1.1. Cập nhật hệ thống và cài đặt gói phụ thuộc
Mở Terminal trên Ubuntu và chạy các lệnh sau:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv build-essential libsqlite3-dev curl git ufw
```

Kiểm tra phiên bản Python (yêu cầu Python **3.11** trở lên):
```bash
python3 --version
```
> *Lưu ý:* Nếu Ubuntu của bạn là bản 20.04 (mặc định Python 3.8), hãy cài Python 3.11 hoặc 3.12 từ PPA `deadsnakes`:
> ```bash
> sudo add-apt-repository ppa:deadsnakes/ppa -y
> sudo apt update
> sudo apt install -y python3.11 python3.11-venv python3.11-dev
> ```

### 1.2. Mở cổng tường lửa (UFW Firewall)
iZiiServer sử dụng:
- **Cổng 8080 (TCP):** HTTP API & WebSocket Sync.
- **Cổng 5353 (UDP):** Giao thức mDNS Zeroconf để các thiết bị iPad/Laptop tự động tìm thấy máy chủ trong mạng LAN.

```bash
sudo ufw allow 8080/tcp comment 'iZiiServer HTTP & WebSocket'
sudo ufw allow 5353/udp comment 'iZiiServer mDNS Zeroconf'
sudo ufw enable
sudo ufw status
```

---

## 2. Cách 1: Chạy trực tiếp với Python Virtualenv & Systemd Service (Khuyến nghị)

Phương pháp này đảm bảo server chạy nền như một dịch vụ Linux chuẩn: tự khởi động cùng hệ thống khi bật máy, tự khởi động lại khi gặp sự cố, và lưu log tập trung.

### Bước 2.1. Đưa source code vào thư mục làm việc
Tạo thư mục ứng dụng tại `/opt/izii_server`:

```bash
sudo mkdir -p /opt/izii_server
# Phân quyền cho user hiện tại (ví dụ: $USER hoặc ubuntu)
sudo chown -R $USER:$USER /opt/izii_server
```

Copy toàn bộ thư mục `server/` vào `/opt/izii_server/`:
```bash
# Ví dụ nếu bạn đang ở thư mục chứa project:
cp -r server/* /opt/izii_server/
cd /opt/izii_server
```

### Bước 2.2. Tạo môi trường ảo (Virtualenv) & Cài đặt thư viện
```bash
python3 -m venv venv
source venv/bin/activate

# Nâng cấp pip và cài đặt thư viện
pip install --upgrade pip
pip install -r requirements.txt
```

**Kiểm tra cài đặt:**
```bash
python -c "import fastapi, uvicorn, httpx, zeroconf, multipart; print('✅ Tất cả thư viện đã sẵn sàng!')"
```

### Bước 2.3. Tạo file cấu hình môi trường `.env`
```bash
cp .env.example .env
nano .env
```
Postgres:

# iZiiServer Configuration (.env)
# Multi-Server Mesh & Sync Settings for iZiiApp Backend
#
# ⚠️  FILE NÀY CHỨA SECRET — không commit lên Git.
#     Nếu trước đây đã lỡ commit, chạy: git rm --cached server/.env

# Unique identifier for this server instance (e.g. server-m1, server-m2, server-cr)
IZIIAPP_SERVER_ID=server-m1

# Zone identifier (e.g. M1, M2, CR)
IZIIAPP_ZONE=M1

# Comma-separated URLs of peer servers in the mesh (mDNS will also discover peers dynamically)
# Example: IZIIAPP_PEERS=http://192.168.1.11:8080,http://192.168.1.12:8080
IZIIAPP_PEERS=

# Background peer sync polling interval in seconds
IZIIAPP_SYNC_INTERVAL_SECONDS=45

# Shared secret for authenticated Server-to-Server peer sync (/peer-sync/* endpoints).
# Phải giống nhau trên cả 3 server (M1 / M2 / CR).
# TODO: đổi giá trị này — secret cũ (iZiiServerSecretKey2026) có thể đã nằm
#       trong lịch sử commit nên coi như đã lộ.
IZIIAPP_SERVER_SECRET=iZiiServerSecretKey2026

# Secret cho WebSocket /chat — client Flutter phải gửi kèm:
#     ws://<host>:8080/chat?token=<giá trị bên dưới>
# hoặc header X-iZii-WS-Token. Mọi kết nối thiếu/sai token đều bị đóng (1008).
IZIIAPP_WS_SECRET=iZiiServerSecretKey2026

# Optional: Path override for SQLite database file (default is server/data/iziiapp.db)
# IZIIAPP_SERVER_DB_PATH=C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/data/iziiapp.db

# Thêm bởi màn hình Settings lúc 2026-08-13T02:43:23.976277+00:00
IZIIAPP_SERVER_DB_PATH=
IZIIAPP_ADMIN_SECRET=
IZIIAPP_REQUIRE_DEVICE_TOKEN=
IZIIAPP_ENROLLMENT_TOKEN_TTL=
IZIIAPP_DB_BACKEND=postgres
IZIIAPP_PG_DSN=postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp
IZIIAPP_PG_POOL_MIN=1
IZIIAPP_PG_POOL_MAX=10
IZIIAPP_TLS_CERT_FILE=
IZIIAPP_TLS_KEY_FILE=
IZIIAPP_TLS_CA_FILE=
IZIIAPP_TLS_REQUIRE_CLIENT_CERT=
IZIIAPP_TLS_ALLOWED_PEER_CNS=
IZIIAPP_OAUTH_TOKEN_URL=
IZIIAPP_OAUTH_CLIENT_ID=
IZIIAPP_OAUTH_CLIENT_SECRET=
IZIIAPP_OAUTH_SCOPE=




Điền nội dung cấu hình chuẩn:
```ini
# Định danh máy chủ
IZIIAPP_SERVER_ID=server-ubuntu
IZIIAPP_ZONE=DefaultZone

# Cấu hình IP và Port
IZIIAPP_HOST=0.0.0.0
IZIIAPP_PORT=8080

# Bí mật xác thực bảo mật (phải khớp với iZiiApp client)
IZIIAPP_SERVER_SECRET=iZiiServerSecretKey2026
IZIIAPP_ADMIN_SECRET=iZiiAdminSecret2026
IZIIAPP_WS_SECRET=iZiiServerSecretKey2026

# Cơ sở dữ liệu SQLite
IZIIAPP_DB_BACKEND=sqlite
IZIIAPP_DB_PATH=/opt/izii_server/data/iziiapp.db

# Kho lưu trữ đính kèm
IZIIAPP_ATTACHMENT_DIR=/opt/izii_server/data/attachments

# Chu kỳ đồng bộ mesh (giây)
IZIIAPP_SYNC_INTERVAL_SECONDS=45
IZIIAPP_PEERS=
```

Tạo các thư mục dữ liệu cần thiết:
```bash
mkdir -p /opt/izii_server/data/logs /opt/izii_server/data/attachments
```

### Bước 2.4. Tạo Systemd Service để tự động chạy nền
Tạo file cấu hình dịch vụ `/etc/systemd/system/iziiserver.service`:

```bash
sudo nano /etc/systemd/system/iziiserver.service
```

Dán nội dung sau vào file (thay `ubuntu` bằng tên username của bạn nếu khác):

```ini
[Unit]
Description=iZiiServer Standalone Service
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/izii_server
EnvironmentFile=/opt/izii_server/.env
ExecStart=/opt/izii_server/venv/bin/python /opt/izii_server/app.py
Restart=always
RestartSec=5s

# Giới hạn tài nguyên và bảo mật
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Bước 2.5. Kích hoạt và khởi động dịch vụ
```bash
# Nạp lại cấu hình systemd
sudo systemctl daemon-reload

# Kích hoạt tự khởi động cùng hệ thống
sudo systemctl enable iziiserver

# Khởi động server
sudo systemctl start iziiserver

# Xem trạng thái hoạt động
sudo systemctl status iziiserver
```

**Xem log thời gian thực:**
```bash
sudo journalctl -u iziiserver -f
# hoặc
tail -f /opt/izii_server/data/logs/server.log
```

---

## 3. Cách 2: Build file nhị phân độc lập bằng PyInstaller

Nếu bạn muốn tạo một thư mục chạy độc lập (Binary ELF) để phân phối hoặc chạy trên các máy Ubuntu khác mà không cần cài đặt Python, hãy sử dụng PyInstaller.

### Bước 3.1. Cài đặt PyInstaller
Trong môi trường ảo của bạn:
```bash
cd /opt/izii_server
source venv/bin/activate
pip install pyinstaller
```

### Bước 3.2. Thực hiện Build
Chạy lệnh đóng gói dựa trên file `izii_server.spec`:
```bash
pyinstaller --noconfirm izii_server.spec
```

Sau khi hoàn tất, kết quả build sẽ nằm tại:
`/opt/izii_server/dist/izii_server/`

### Bước 3.3. Chạy file nhị phân vừa build
```bash
cd /opt/izii_server/dist/izii_server

# Copy file .env vào cùng thư mục binary
cp /opt/izii_server/.env .

# Tạo thư mục data
mkdir -p data/logs data/attachments

# Chạy server
./izii_server
```

> **Mẹo đóng gói phân phối:**
> Bạn có thể nén thư mục này thành file `.tar.gz` để mang sang bất kỳ máy Ubuntu x64 nào khác chạy trực tiếp:
> ```bash
> cd /opt/izii_server/dist
> tar -czvf izii_server_linux_x64.tar.gz izii_server/
> ```

---

## 4. Cách 3: Triển khai bằng Docker & Docker Compose

Nếu bạn muốn chạy server trong container Docker hoàn toàn cô lập:

### Bước 4.1. Tạo `Dockerfile` tại thư mục `/opt/izii_server/Dockerfile`
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Cài đặt các gói hệ thống cần thiết
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Cài đặt dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Tạo thư mục dữ liệu
RUN mkdir -p data/logs data/attachments

EXPOSE 8080

CMD ["python", "app.py"]
```

### Bước 4.2. Tạo `docker-compose.yml` tại `/opt/izii_server/docker-compose.yml`
```yaml
version: '3.8'

services:
  izii_server:
    build: .
    container_name: izii_server
    restart: always
    network_mode: "host" # Bắt buộc dùng host mode để mDNS Zeroconf broadcast qua LAN
    env_file:
      - .env
    volumes:
      - ./data:/app/data
```

### Bước 4.3. Khởi động Container
```bash
# Build và chạy ngầm
docker compose up -d --build

# Xem log container
docker compose logs -f
```

---

## 5. Cấu hình Nginx Reverse Proxy & SSL (Tuỳ chọn)

Nếu bạn muốn truy cập qua tên miền (Domain), port 80/443 hoặc cấu hình HTTPS / WSS:

### 5.1. Cài đặt Nginx
```bash
sudo apt install -y nginx
```

### 5.2. Cấu hình Nginx Virtual Host
Tạo file `/etc/nginx/sites-available/iziiserver`:
```bash
sudo nano /etc/nginx/sites-available/iziiserver
```

Dán cấu hình sau (hỗ trợ đầy đủ HTTP và WebSocket):
```nginx
server {
    listen 80;
    server_name your-server-ip-or-domain;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        
        # Hỗ trợ kết nối WebSocket (/chat, /call/ws)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

Kích hoạt cấu hình:
```bash
sudo ln -s /etc/nginx/sites-available/iziiserver /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 6. Kiểm tra & Xác minh hoạt động

Sau khi khởi động iZiiServer trên Ubuntu, hãy chạy các lệnh kiểm tra sau:

### 6.1. Kiểm tra trạng thái máy chủ
```bash
curl http://localhost:8080/devices/enroll/status
```
**Kết quả mong đợi:**
`{"server_id":"server-ubuntu","zone":"DefaultZone","status":"running",...}`

### 6.2. Kiểm tra cổng lắng nghe
```bash
sudo ss -tulpn | grep 8080
```
Phải thấy tiến trình `python` hoặc `izii_server` đang lắng nghe ở `0.0.0.0:8080`.

### 6.3. Kiểm tra từ máy tính khác trong mạng LAN
Mở trình duyệt trên Laptop hoặc iPad và truy cập:
`http://<IP_CUA_UBUNTU>:8080/devices/enroll/status`
*(Ví dụ: `http://192.168.1.50:8080/devices/enroll/status`)*

---

## 7. Xử lý sự cố thường gặp trên Linux

### 7.1. Lỗi `[Errno 98] Address already in use` (Cổng 8080 bị chiếm dụng)
- **Hiện tượng:** Server không khởi động được do cổng 8080 đang bị tiến trình khác chiếm.
- **Cách xử lý:**
  ```bash
  # Tìm PID đang chiếm port 8080
  sudo lsof -i :8080
  # hoặc giải phóng trực tiếp:
  sudo fuser -k 8080/tcp
  ```

### 7.2. Lỗi `Permission denied` khi ghi dữ liệu vào SQLite hoặc Logs
- **Hiện tượng:** Log báo `sqlite3.OperationalError: unable to open database file`.
- **Cách xử lý:** Đảm bảo quyền sở hữu thư mục dữ liệu:
  ```bash
  sudo chown -R $USER:$USER /opt/izii_server/data
  chmod -R 755 /opt/izii_server/data
  ```

### 7.3. Thiết bị iPad / Samsung không tự động tìm thấy Server qua mDNS
- **Hiện tượng:** Trên app phải nhập IP thủ công chứ không tự quét ra server.
- **Cách xử lý:**
  1. Kiểm tra đã mở cổng UDP 5353 trên UFW chưa: `sudo ufw allow 5353/udp`.
  2. Nếu chạy qua Docker, bắt buộc phải dùng `network_mode: "host"`.
  3. Đảm bảo Ubuntu và iPad cùng cắm chung mạng LAN (cùng lớp mạng subnet, không bị chặn bởi router multicast).

---
*Tài liệu được cập nhật ngày 27/08/2026 cho iZiiServer Standalone v2.0.*
