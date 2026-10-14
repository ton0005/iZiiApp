# Comprehensive Guide: Building & Running iZiiServer on Ubuntu / Linux

This document provides step-by-step instructions on how to install, build standalone Linux binaries, configure systemd daemon services, and deploy Docker containers for **iZiiServer** on **Ubuntu 20.04 / 22.04 / 24.04 LTS** (or Debian/Linux equivalents).

---

## Table of Contents
1. [System Prerequisites & Environment Setup](#1-system-prerequisites--environment-setup)
2. [Method 1: Direct Run with Python Virtualenv & Systemd Service (Recommended for Production)](#2-method-1-direct-run-with-python-virtualenv--systemd-service-recommended)
3. [Method 2: Building a Standalone Linux Binary with PyInstaller](#3-method-2-building-a-standalone-linux-binary-with-pyinstaller)
4. [Method 3: Docker & Docker Compose Deployment](#4-method-3-docker--docker-compose-deployment)
5. [Configuring Nginx Reverse Proxy & SSL (Optional)](#5-configuring-nginx-reverse-proxy--ssl-optional)
6. [Verification & Health Checks](#6-verification--health-checks)
7. [Troubleshooting Common Linux Issues](#7-troubleshooting-common-linux-issues)

---

## 1. System Prerequisites & Environment Setup

### 1.1. System Updates & Core Packages
Open your terminal on Ubuntu and execute:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv build-essential libsqlite3-dev curl git ufw
```

Verify Python version (**Python 3.11+ is required**):
```bash
python3 --version
```
> *Note:* If you are on Ubuntu 20.04 (where default is Python 3.8), install Python 3.11/3.12 from the deadsnakes PPA:
> ```bash
> sudo add-apt-repository ppa:deadsnakes/ppa -y
> sudo apt update
> sudo apt install -y python3.11 python3.11-venv python3.11-dev
> ```

### 1.2. Open Firewall Ports (UFW)
iZiiServer requires:
- **Port 8080 (TCP):** HTTP REST APIs & WebSocket Realtime Sync.
- **Port 5353 (UDP):** mDNS Zeroconf for automatic peer discovery across iPad/Laptop clients.

```bash
sudo ufw allow 8080/tcp comment 'iZiiServer HTTP & WebSocket'
sudo ufw allow 5353/udp comment 'iZiiServer mDNS Zeroconf'
sudo ufw enable
sudo ufw status
```

---

## 2. Method 1: Direct Run with Python Virtualenv & Systemd Service (Recommended)

### Step 2.1. Prepare Working Directory
```bash
sudo mkdir -p /opt/izii_server
sudo chown -R $USER:$USER /opt/izii_server

# Copy server files into /opt/izii_server/
cp -r server/* /opt/izii_server/
cd /opt/izii_server
```

### Step 2.2. Create Virtual Environment & Install Dependencies
```bash
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt
```

Verify dependencies:
```bash
python -c "import fastapi, uvicorn, httpx, zeroconf, multipart; print('✅ All dependencies ready!')"
```

### Step 2.3. Configure Environment Variables (`.env`)
```bash
cp .env.example .env
nano .env
```

Ensure standard production settings:
```ini
IZIIAPP_SERVER_ID=server-ubuntu
IZIIAPP_ZONE=DefaultZone

IZIIAPP_HOST=0.0.0.0
IZIIAPP_PORT=8080

IZIIAPP_SERVER_SECRET=iZiiServerSecretKey2026
IZIIAPP_ADMIN_SECRET=iZiiAdminSecret2026
IZIIAPP_WS_SECRET=iZiiServerSecretKey2026

IZIIAPP_DB_BACKEND=sqlite
IZIIAPP_DB_PATH=/opt/izii_server/data/iziiapp.db
IZIIAPP_ATTACHMENT_DIR=/opt/izii_server/data/attachments

IZIIAPP_SYNC_INTERVAL_SECONDS=45
IZIIAPP_PEERS=
```

Create required directories:
```bash
mkdir -p /opt/izii_server/data/logs /opt/izii_server/data/attachments
```

### Step 2.4. Setup Systemd Service
Create service file `/etc/systemd/system/iziiserver.service`:

```bash
sudo nano /etc/systemd/system/iziiserver.service
```

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

LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Step 2.5. Enable and Start the Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable iziiserver
sudo systemctl start iziiserver
sudo systemctl status iziiserver
```

Stream live logs:
```bash
sudo journalctl -u iziiserver -f
```

---

## 3. Method 2: Building a Standalone Linux Binary with PyInstaller

### Step 3.1. Install PyInstaller
```bash
cd /opt/izii_server
source venv/bin/activate
pip install pyinstaller
```

### Step 3.2. Run the Build
```bash
pyinstaller --noconfirm izii_server.spec
```

The compiled standalone bundle will be generated at:
`/opt/izii_server/dist/izii_server/`

### Step 3.3. Execute the Binary
```bash
cd /opt/izii_server/dist/izii_server
cp /opt/izii_server/.env .
mkdir -p data/logs data/attachments
./izii_server
```

---

## 4. Method 3: Docker & Docker Compose Deployment

### Step 4.1. `Dockerfile`
Located at `server/Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN mkdir -p data/logs data/attachments

EXPOSE 8080

CMD ["python", "app.py"]
```

### Step 4.2. `docker-compose.yml`
Located at `server/docker-compose.yml`:
```yaml
version: '3.8'

services:
  izii_server:
    build: .
    container_name: izii_server
    restart: always
    network_mode: "host"
    env_file:
      - .env
    volumes:
      - ./data:/app/data
```

### Step 4.3. Launch Containers
```bash
docker compose up -d --build
docker compose logs -f
```

---

## 5. Verification & Health Checks

Verify that the server is responding properly:
```bash
curl http://localhost:8080/devices/enroll/status
```

Expected output:
```json
{"server_id":"server-ubuntu","zone":"DefaultZone","status":"running",...}
```

Check listening port:
```bash
sudo ss -tulpn | grep 8080
```
