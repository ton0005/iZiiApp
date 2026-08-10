# iZiiServer — Hướng dẫn cài đặt từng bước

> Tài liệu vận hành. Làm theo đúng thứ tự, mỗi bước đều có phần **kiểm chứng**
> trước khi sang bước tiếp theo.

**Lộ trình khuyến nghị:** Phần A → B → C là đủ để chạy một server và kết nối
app. Phần D trở đi chỉ làm khi thực sự cần.

| Phần | Nội dung | Khi nào cần |
|---|---|---|
| [A](#a--chuẩn-bị-môi-trường) | Chuẩn bị môi trường | Luôn luôn |
| [B](#b--dựng-server-đầu-tiên) | Dựng server đầu tiên | Luôn luôn |
| [C](#c--kết-nối-app-flutter) | Kết nối app Flutter | Luôn luôn |
| [D](#d--mở-rộng-thành-mesh-3-server) | Mesh 3 server (M1/M2/CR) | Khi có nhiều khu |
| [E](#e--đóng-gói-thành-exe) | Đóng gói `.exe` | Khi deploy máy không có Python |
| [F](#f--tuỳ-chọn-bật-tlsmtls) | TLS / mTLS | Khi cần bảo mật đường truyền |
| [G](#g--tuỳ-chọn-chuyển-sang-postgresql) | PostgreSQL | Khi nhiều adapter ghi song song |
| [H](#h--vận-hành-hằng-ngày) | Vận hành hằng ngày | Sau khi chạy |
| [I](#i--xử-lý-sự-cố) | Xử lý sự cố | Khi có vấn đề |

**Tài liệu riêng cho từng tính năng:**

| Tài liệu | Nội dung |
|---|---|
| [`ENROLLMENT_SETUP.md`](ENROLLMENT_SETUP.md) | Đăng ký thiết bị bằng QR / NFC |
| [`DIEM_DANH_SETUP.md`](DIEM_DANH_SETUP.md) | Điểm danh đầu ca, thẻ nhân viên, mã PIN |
| [`HUONG_DAN_NHAN_VIEN.md`](HUONG_DAN_NHAN_VIEN.md) | Bản in cho công nhân — cả hai luồng |

---

## A — Chuẩn bị môi trường

### A1. Cài Python 3.11 trở lên

```powershell
python --version
```

Phải ra `Python 3.11.x` hoặc mới hơn. Nếu chưa có:

```powershell
winget install Python.Python.3.12
```

> ⚠️ Máy có nhiều bản Python thì gõ `python` có thể trỏ nhầm. Kiểm tra bằng
> `where python` — nếu ra nhiều dòng, dùng đường dẫn đầy đủ ở các bước sau.

### A2. Cài thư viện

```powershell
cd C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server
pip install -r requirements.txt
```

**Kiểm chứng:**

```powershell
python -c "import fastapi, uvicorn, httpx, zeroconf, multipart; print('OK')"
```

Phải in ra `OK`. Nếu báo thiếu `multipart` thì chức năng đính kèm file sẽ hỏng
về sau — cài lại `pip install python-multipart`.

### A3. Mở cổng 8080 trên tường lửa

Chỉ cần khi có thiết bị khác (điện thoại, máy khác) kết nối vào.

```powershell
# Chạy PowerShell với quyền Administrator
New-NetFirewallRule -DisplayName "iZiiServer 8080" -Direction Inbound `
    -Protocol TCP -LocalPort 8080 -Action Allow
```

mDNS auto-discovery cần thêm UDP 5353:

```powershell
New-NetFirewallRule -DisplayName "iZii mDNS" -Direction Inbound `
    -Protocol UDP -LocalPort 5353 -Action Allow
```

---

## B — Dựng server đầu tiên

### B1. Tạo file `.env`

```powershell
cd C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server
copy .env.example .env
notepad .env
```

Cấu hình tối thiểu cho **một server đứng riêng**:

```ini
IZIIAPP_SERVER_ID=server-m1
IZIIAPP_ZONE=M1
IZIIAPP_PEERS=
IZIIAPP_SYNC_INTERVAL_SECONDS=45

# Đổi thành chuỗi ngẫu nhiên của riêng bạn, đừng dùng giá trị ví dụ.
IZIIAPP_SERVER_SECRET=<chuỗi-bí-mật-của-bạn>
IZIIAPP_WS_SECRET=<chuỗi-bí-mật-của-bạn>

IZIIAPP_DB_BACKEND=sqlite
```

Sinh chuỗi bí mật ngẫu nhiên:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

> 🔴 **`IZIIAPP_WS_SECRET` là bắt buộc.** Bỏ trống cả nó lẫn
> `IZIIAPP_SERVER_SECRET` thì WebSocket `/chat` sẽ **từ chối mọi kết nối** và
> app mất tính năng realtime. Đây là thay đổi có chủ ý — thà chặn hết còn hơn
> mở toang.

> ⚠️ File `.env` chứa secret. Đã có trong `.gitignore`, đừng commit.

### B2. Khởi tạo database

```powershell
python db_init.py
```

**Kiểm chứng:** phải thấy dòng

```
SQLite Database initialized successfully at: ...\server\data\iziiapp.db
```

và file `server\data\iziiapp.db` xuất hiện.

### B3. Khởi động server

```powershell
.\run_server.bat
```

**Kiểm chứng — log khởi động phải có đủ các dòng sau:**

```
✅ Database auto-initialized successfully at: ...
✅ Production PRAGMAs applied: WAL, NORMAL sync, ...
🌐 Server identity: server_id=server-m1 zone=M1
🗄️  Database backend: sqlite
🔓 [TLS] Tắt — server chạy HTTP thuần ...
📡 [mDNS] Advertising server_id=server-m1 ...
🔁 [PEER-SYNC] Bắt đầu vòng lặp đồng bộ (mỗi 45s) ...
INFO:     Uvicorn running on http://0.0.0.0:8080
```

**Dấu hiệu cấu hình sai — nếu thấy các dòng này, quay lại B1:**

| Log | Nghĩa là |
|---|---|
| `⚠️ [CONFIG] IZIIAPP_SERVER_ID chưa được set` | `.env` không được đọc — sai vị trí file |
| `⛔ [CONFIG] Chưa set IZIIAPP_WS_SECRET lẫn IZIIAPP_SERVER_SECRET` | WebSocket sẽ chặn hết |
| `⚠️ [mDNS] Không khởi động được advertise/discovery` | Thiếu gói zeroconf hoặc firewall chặn UDP 5353 |

### B4. Kiểm tra từ bên ngoài

Mở PowerShell **thứ hai** (giữ nguyên cửa sổ đang chạy server):

```powershell
curl.exe http://localhost:8080/health
```

Kết quả mong đợi:

```json
{"server_id":"server-m1","zone":"M1","status":"ok","server_time":"2026-08-05T..."}
```

Kiểm tra thêm endpoint quản trị:

```powershell
curl.exe -H "X-iZii-Server-Token: <secret-của-bạn>" http://localhost:8080/peer-sync/health
```

Tài liệu API tự sinh: mở trình duyệt vào <http://localhost:8080/docs>

### B5. Lấy địa chỉ IP của máy chủ

```powershell
ipconfig | Select-String "IPv4"
```

Ghi lại địa chỉ dạng `192.168.x.x` — dùng ở phần C.

---

## C — Kết nối app Flutter

### C1. Cấu hình trong app

Mở app iZii → tab **Settings** → mục **Sync Server**:

| Trường | Giá trị |
|---|---|
| Server URL | `http://192.168.x.x:8080` (IP ở bước B5) |
| Auth Token | đúng giá trị `IZIIAPP_SERVER_SECRET` |

Nhấn **Save Settings**.

> Chạy app ngay trên máy chủ thì dùng `http://127.0.0.1:8080`.

### C2. Kiểm chứng

Vào tab **Settings** → mục **Cấu hình Server (.env)** → nhấn **Nạp cấu hình**.

Nạp được nghĩa là URL và token đều đúng. Màn hình sẽ hiện dải trạng thái đang
chạy: `DB: sqlite`, `TLS: tắt`, `Peers: 0`.

Bên phía server, log phải xuất hiện:

```
📥 [PUSH] Received N changes at ...
📤 [PULL] The device is downloading new updates...
🔌 [WS] Client connected. Active clients: 1
```

Không thấy `🔌 [WS] Client connected` → xem mục [I3](#i3--websocket-bị-từ-chối).

### C3. Kết nối điện thoại Android qua USB

Khi điện thoại không cùng Wi-Fi với máy chủ:

```powershell
adb reverse tcp:8080 tcp:8080
```

Sau đó trong app trên điện thoại đặt Server URL là `http://localhost:8080`.

> ⚠️ `adb reverse` chỉ mở đường cho **tiến trình chạy trên điện thoại** đi vào
> máy tính. Nó không phải một tuyến mạng — máy khác trong LAN không đi nhờ được.

---

## D — Mở rộng thành mesh 3 server

Mô hình: mỗi khu một server, chạy độc lập khi mất mạng, tự đồng bộ khi có mạng.

### D1. Lặp lại phần A và B trên từng máy

### D2. Sửa `.env` cho từng máy

Ba giá trị **phải khác nhau**, một giá trị **phải giống nhau**:

| Máy | `IZIIAPP_SERVER_ID` | `IZIIAPP_ZONE` | `IZIIAPP_PEERS` |
|---|---|---|---|
| M1 (192.168.1.10) | `server-m1` | `M1` | `http://192.168.1.11:8080,http://192.168.1.12:8080` |
| M2 (192.168.1.11) | `server-m2` | `M2` | `http://192.168.1.10:8080,http://192.168.1.12:8080` |
| CR (192.168.1.12) | `server-cr` | `CR` | `http://192.168.1.10:8080,http://192.168.1.11:8080` |

`IZIIAPP_SERVER_SECRET` **giống hệt nhau** trên cả ba.

> 🔴 **Lỗi hay gặp nhất:** copy nguyên `.env` từ máy này sang máy khác mà quên
> đổi `IZIIAPP_SERVER_ID`. Khi đó hai server coi nhau là chính mình, mDNS bỏ
> qua nhau và `/peer-sync/push` trả 400 *"Không thể peer-sync với chính mình"*.

> ⚠️ Khai báo `IZIIAPP_PEERS` tường minh, **đừng chỉ trông vào mDNS**. VLAN
> doanh nghiệp và Wi-Fi hotspot thường chặn multicast.

### D3. Kiểm chứng mesh

Từ máy M1, gọi sang M2:

```powershell
curl.exe -H "X-iZii-Server-Token: <secret>" http://192.168.1.11:8080/peer-sync/health
```

Phải trả về JSON có `"server_id":"server-m2"`. Ra `server-m1` nghĩa là bạn đang
tự gọi chính mình — kiểm tra lại IP.

Trong log của M1, sau tối đa 45 giây:

```
✅ [mDNS] Phát hiện server mới: server-m2 (zone=M2) tại 192.168.1.11:8080
🔁 [PEER-SYNC] Đã áp dụng N mutations từ http://192.168.1.11:8080
```

**Thử nghiệm đầu-cuối:** tạo một Job ở app nối M1, chờ 45 giây, kiểm tra Job
xuất hiện ở app nối M2.

---

## E — Đóng gói thành .exe

Dùng khi máy đích không cài Python.

### E1. Build

```powershell
cd C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app\server
pip install pyinstaller
pyinstaller --noconfirm izii_server.spec
```

> ⚠️ Phải chạy **từ trong thư mục `server`**. Spec ở thư mục gốc
> (`iziiapp_server.spec`) đã bị vô hiệu hoá vì thiếu zeroconf.

### E2. Kiểm chứng bản build

Thư mục `server\dist\izii_server\_internal\zeroconf\` **phải tồn tại**. Không có
nghĩa là mDNS sẽ hỏng âm thầm — server vẫn chạy nhưng mất auto-discovery.

### E3. Chạy

```powershell
.\run_izii_server.bat
```

Script tự phát hiện `.exe` và **tự copy `.env` sang cạnh file `.exe`** — bước
này hay bị quên khi làm thủ công.

---

## F — Tuỳ chọn: bật TLS/mTLS

Chỉ làm khi cần mã hoá đường truyền giữa các server. Bỏ qua nếu chạy trong LAN
cô lập.

### F1. Sinh chứng chỉ (làm MỘT LẦN, trên một máy)

```powershell
cd server
.\gen_dev_certs.ps1
```

Cần `openssl`. Không có thì dùng bản đi kèm Git: thêm
`C:\Program Files\Git\usr\bin` vào PATH.

### F2. Phân phối

| File | Đưa đi đâu |
|---|---|
| `izii-ca.crt` | **Mọi** máy |
| `server-m1.crt` + `.key` | **Chỉ** máy M1 |
| `server-m2.crt` + `.key` | **Chỉ** máy M2 |
| `server-cr.crt` + `.key` | **Chỉ** máy CR |

File `.key` là khoá bí mật — không gửi qua chat, không commit.

### F3. Bật từng bước

**Bước 1 — chỉ mã hoá.** Thêm vào `.env` mỗi máy:

```ini
IZIIAPP_TLS_CERT_FILE=certs/server-m1.crt
IZIIAPP_TLS_KEY_FILE=certs/server-m1.key
```

**Bước 2 — thêm mTLS:**

```ini
IZIIAPP_TLS_CA_FILE=certs/izii-ca.crt
IZIIAPP_TLS_REQUIRE_CLIENT_CERT=true
```

**Bước 3 — siết theo CN:**

```ini
IZIIAPP_TLS_ALLOWED_PEER_CNS=server-m1,server-m2,server-cr
```

### F4. Đổi `IZIIAPP_PEERS` sang `https://`

```ini
IZIIAPP_PEERS=https://192.168.1.11:8080,https://192.168.1.12:8080
```

> 🔴 **Bật đồng loạt trên cả ba máy.** Ghép `http` với `https` làm peer-sync
> hỏng ở bước bắt tay TLS mà không có thông báo lỗi rõ ràng.

### F5. Kiểm chứng

Log khởi động phải chuyển thành:

```
🔐 [TLS] mTLS BẬT — bắt buộc chứng chỉ client. CN cho phép: server-m1, server-m2, server-cr
```

```powershell
curl.exe --cacert certs/izii-ca.crt --cert certs/server-m1.crt --key certs/server-m1.key `
         -H "X-iZii-Server-Token: <secret>" `
         https://192.168.1.11:8080/peer-sync/health
```

App Flutter cũng phải đổi Server URL sang `https://`.

---

## G — Tuỳ chọn: chuyển sang PostgreSQL

Chỉ cần khi có nhiều adapter (SAP, OPC UA, Historian) ghi song song. SQLite chỉ
cho **một writer** — đủ dùng ở biên, nhưng sẽ thành nút cổ chai khi mở rộng.

### G1. Chuẩn bị

```powershell
pip install "psycopg[binary,pool]"
```

Trên máy chủ PostgreSQL:

```sql
CREATE DATABASE iziiapp;
CREATE USER izii WITH PASSWORD 'matkhau-manh';
GRANT ALL PRIVILEGES ON DATABASE iziiapp TO izii;
```

### G2. Khai DSN (chưa đổi backend)

```ini
IZIIAPP_PG_DSN=postgresql://izii:matkhau-manh@192.168.1.50:5432/iziiapp
```

### G3. Chuyển dữ liệu

**Dừng server trước** để không ai ghi thêm trong lúc copy.

```powershell
python migrate_to_postgres.py
```

Script in số dòng từng bảng. Đối chiếu với SQLite trước khi đi tiếp.

### G4. Đổi backend rồi khởi động lại

```ini
IZIIAPP_DB_BACKEND=postgres
```

**Kiểm chứng:** log phải có `🗄️ Database backend: postgres` và
`🐘 [PG] Connection pool sẵn sàng`.

Giữ file SQLite cũ vài ngày để đối chiếu trước khi xoá.

---

## H — Vận hành hằng ngày

### H1. Vị trí file

| Nội dung | Đường dẫn |
|---|---|
| Database | `server\data\iziiapp.db` |
| Log server | `server\data\logs\server.log` (tự xoay vòng ở 10MB) |
| Log độ trễ | `server\data\logs\latency.log` |
| File đính kèm | `server\data\uploads\` |
| Cấu hình | `server\.env` |

### H2. Chạy nền, không hiện cửa sổ

```powershell
wscript.exe start_background.vbs
```

### H3. Sao lưu

Sao lưu **cả ba** file, không chỉ file `.db` — WAL mode giữ dữ liệu chưa
checkpoint ở file phụ:

```
iziiapp.db
iziiapp.db-wal
iziiapp.db-shm
```

Hoặc dùng chức năng **Database Backup & Restore** trong tab Settings của app.

### H4. Reset toàn bộ dữ liệu

```powershell
.\reset_data.ps1
```

Xoá DB server, DB local, con trỏ đồng bộ và khoá thiết bị. Có sao lưu trước.

> 🔴 **Xoá dữ liệu trên các thiết bị khác TRƯỚC.** Bỏ qua bước này thì điện
> thoại sẽ đẩy toàn bộ dữ liệu cũ ngược lên server ngay lần sync đầu tiên.
> Android: Settings › Apps › iZiiApp › Storage › Clear data.

Reset chỉ phía server, không cần dừng tiến trình:

```powershell
$h = @{ 'X-iZii-Server-Token' = '<secret>' }
$b = @{ confirm = 'server-m1' } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/admin/reset -Method Post `
                  -Headers $h -Body $b -ContentType 'application/json'
```

### H5. Sửa cấu hình từ app

Tab **Settings** → **Cấu hình Server (.env)** → sửa → **Ghi vào .env**.

> ⚠️ Cấu hình chỉ được đọc **một lần lúc khởi động**. Sửa xong **phải khởi động
> lại server** thì mới có hiệu lực.

---

## I — Xử lý sự cố

### I1. Server không khởi động

| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| `ModuleNotFoundError` | Thiếu thư viện | `pip install -r requirements.txt` |
| `[Errno 10048] address in use` | Cổng 8080 đã bị chiếm | Xem lệnh bên dưới |
| `NameError` lúc khởi động | Lỗi code | `python -c "import app"` để xem chi tiết |

Giải phóng cổng 8080:

```powershell
Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess | Stop-Process -Force
```

### I2. App không kết nối được

1. Server có chạy không: `curl.exe http://localhost:8080/health`
2. Từ máy khác gọi được không: `curl.exe http://192.168.1.10:8080/health`
   → Không được thì kiểm tra firewall (bước A3)
3. Server URL trong app có đúng IP không (đừng dùng `127.0.0.1` từ máy khác)
4. Token có khớp `IZIIAPP_SERVER_SECRET` không

### I3. WebSocket bị từ chối

Log server hiện:

```
⛔ [WS] Từ chối kết nối: chưa cấu hình IZIIAPP_WS_SECRET
⛔ [WS] Từ chối kết nối từ ...: token thiếu hoặc sai.
```

- Dòng đầu: chưa set `IZIIAPP_WS_SECRET` trong `.env`
- Dòng sau: app gửi token sai

> Sửa `.env` xong **phải khởi động lại server**. Đây là lỗi hay gặp: sửa file
> rồi thấy vẫn bị từ chối vì tiến trình cũ còn giữ cấu hình cũ.

### I4. Hai server không đồng bộ

Kiểm tra theo thứ tự:

1. `IZIIAPP_SERVER_ID` có khác nhau không (lỗi phổ biến nhất)
2. `IZIIAPP_SERVER_SECRET` có giống nhau không
3. Gọi chéo được không:
   `curl.exe -H "X-iZii-Server-Token: <secret>" http://<ip-peer>:8080/peer-sync/health`
4. `IZIIAPP_PEERS` đã khai chưa (đừng chỉ dựa vào mDNS)
5. Nếu đã bật TLS: cả hai đều dùng `https://` chứ không lẫn `http://`

### I5. Dữ liệu cũ quay lại sau khi xoá DB

Nguyên nhân thường gặp nhất: file DB legacy trong OneDrive tự được copy lại,
hoặc thiết bị khác đẩy dữ liệu cũ lên. Dùng `reset_data.ps1` thay vì xoá file
thủ công — script xử lý đủ cả 5 nơi lưu dữ liệu.

### I6. Thiết bị ngừng nhận dữ liệu mới

Thường xảy ra sau khi reset chỉ phía server: con trỏ đồng bộ của thiết bị vượt
quá log của server.

Server đã **tự xử lý** — phát hiện con trỏ vượt quá và phục vụ lại từ đầu, log
app hiện `ℹ️ Server đã reset dữ liệu — con trỏ đồng bộ được đặt lại từ đầu.`

Nếu vẫn kẹt, xoá dữ liệu ứng dụng trên thiết bị đó.

### I7. Xem log

```powershell
Get-Content server\data\logs\server.log -Tail 100 -Wait
```

---

## Phụ lục — Bảng biến môi trường

| Biến | Bắt buộc | Mặc định | Ghi chú |
|---|---|---|---|
| `IZIIAPP_SERVER_ID` | ⭐ | `server-standalone` | Khác nhau trên từng máy |
| `IZIIAPP_ZONE` | ⭐ | `default` | Nhãn khu vực |
| `IZIIAPP_PEERS` | mesh | *(trống)* | URL peer, phân tách bằng dấu phẩy |
| `IZIIAPP_SYNC_INTERVAL_SECONDS` | | `45` | Chu kỳ polling |
| `IZIIAPP_SERVER_SECRET` | ⭐ | *(trống)* | Giống nhau trên cả mesh |
| `IZIIAPP_WS_SECRET` | ⭐ | *(trống)* | Trống thì `/chat` chặn hết |
| `IZIIAPP_SERVER_DB_PATH` | | `data/iziiapp.db` | Ghi đè đường dẫn DB |
| `IZIIAPP_DB_BACKEND` | | `sqlite` | `sqlite` \| `postgres` |
| `IZIIAPP_PG_DSN` | postgres | *(trống)* | Bắt buộc khi dùng postgres |
| `IZIIAPP_PG_POOL_MIN` / `_MAX` | | `1` / `10` | Kích thước pool |
| `IZIIAPP_TLS_CERT_FILE` | TLS | *(trống)* | Chứng chỉ server |
| `IZIIAPP_TLS_KEY_FILE` | TLS | *(trống)* | Khoá riêng |
| `IZIIAPP_TLS_CA_FILE` | mTLS | *(trống)* | CA nội bộ |
| `IZIIAPP_TLS_REQUIRE_CLIENT_CERT` | | `false` | Bật mTLS thực thụ |
| `IZIIAPP_TLS_ALLOWED_PEER_CNS` | | *(trống)* | Trống = mọi CN do CA ký |
| `IZIIAPP_OAUTH_TOKEN_URL` | ERP | *(trống)* | Chiều RA sang SAP |
| `IZIIAPP_OAUTH_CLIENT_ID` | ERP | *(trống)* | |
| `IZIIAPP_OAUTH_CLIENT_SECRET` | ERP | *(trống)* | |
| `IZIIAPP_OAUTH_SCOPE` | | *(trống)* | |
