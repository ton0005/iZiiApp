# Báo cáo kiểm thử bảo mật — iZiiApp Server (FastAPI)

**Phạm vi:** backend tại `C:\...\izii_app\server`, đang chạy `uvicorn` trên `http://0.0.0.0:8080`
**Ngày:** 2026-11-04
**Hình thức:** review mã nguồn (white-box) trên hệ thống của chính chủ sở hữu.
**Tóm tắt rủi ro:** Phần lõi (tách secret 3 scope, token hash SHA-256, admin fail-closed, CORS theo regex private-IP) được thiết kế **tốt**. Nhưng server bind `0.0.0.0` + **chạy HTTP không TLS** + **device-auth đang TẮT** + **4 router không có auth** tạo thành một bề mặt tấn công lớn cho bất kỳ ai truy cập được mạng tới cổng 8080.

Mức độ: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

---

## 🔴 C1 — Device authentication đang bị TẮT → toàn bộ API dữ liệu mở

- **Nơi:** `.env` → `IZIIAPP_REQUIRE_DEVICE_TOKEN=` (rỗng); `server_config.py` parse chuỗi rỗng ⇒ `False`. `security_auth.py::optional_device` ở chế độ mở sẽ cho qua request **không có token**.
- **Hệ quả:** Mọi endpoint `/sync/*`, `/api/v1/*` dùng `optional_device` đều gọi được mà **không cần `X-iZii-Device-Token`**. Bất kỳ ai tới được cổng 8080 đều có thể `GET /sync/pull` (đọc toàn bộ mutation: công việc, điểm danh, tin nhắn...) và `POST /sync/push` (chèn/sửa dữ liệu).
- **Khai thác (PoC trên chính mạng của bạn):**
  ```bash
  curl http://<server>:8080/sync/pull?after_seq=0&limit=100   # đọc dữ liệu, không cần token
  ```
- **Vá:**
  1. Đặt `IZIIAPP_REQUIRE_DEVICE_TOKEN=1` **sau khi** tất cả thiết bị đã enroll.
  2. Trong `server_config.py`, cân nhắc đổi mặc định an toàn hơn và **cảnh báo lớn khi chạy mở trên interface không phải loopback**.
  3. Kết hợp bắt buộc với C2 (không expose ra ngoài LAN).

---

## 🔴 C2 — Bind `0.0.0.0:8080` chạy HTTP thuần, không TLS

- **Nơi:** `.env` → `IZIIAPP_TLS_CERT_FILE/KEY/CA` đều rỗng, `IZIIAPP_TLS_REQUIRE_CLIENT_CERT=` rỗng ⇒ server chạy HTTP. Lệnh khởi động bind `0.0.0.0` (mọi interface).
- **Hệ quả:** Token thiết bị, admin token (`X-iZii-Admin-Token`), ws secret và toàn bộ dữ liệu đi **plaintext** trên mạng → nghe lén/sửa gói (MITM). `0.0.0.0` nghĩa là nếu máy có IP public hoặc bị port-forward thì cả Internet chạm tới được.
- **Vá:**
  1. Đặt reverse proxy (Caddy/Nginx) chấm dứt TLS phía trước, hoặc bật TLS sẵn có trong code (đã hỗ trợ `tls_cert_file/...`).
  2. Firewall: chỉ mở 8080 cho subnet nhà máy; chặn ở mức VM/GCP firewall.
  3. Nếu chỉ phục vụ LAN, bind `0.0.0.0` vẫn ổn **nhưng phải có firewall**; đừng để GCP VM mở 8080 ra 0.0.0.0/0.

---

## 🔴 C3 — SSRF qua `/webhooks/register` (denylist quá yếu)

- **Nơi:** `routers/webhooks.py` — **không auth**. Chỉ chặn 3 host `{169.254.169.254, 0.0.0.0, ::1}`. `event_engine.py` dùng `httpx.AsyncClient` `POST` tới URL do người dùng đăng ký khi có event.
- **Hệ quả:** Kẻ tấn công đăng ký webhook trỏ vào nội bộ → server tự POST tới đó. Denylist bỏ sót:
  - `http://127.0.0.1`, `http://localhost`, `http://127.1`, `http://[::ffff:127.0.0.1]`
  - IP LAN: `10.x`, `192.168.x`, `172.16-31.x`
  - **`http://metadata.google.internal/...`** (VM Google Cloud!) — chặn theo IP `169.254.169.254` nhưng **không chặn hostname** này.
  - IP mã hoá thập phân/bát phân (`http://2130706433`).
  > Lưu ý phạm vi chính xác: `httpx` mặc định **không** follow redirect và webhook là **POST**, nên đánh cắp token metadata (vốn cần GET) bị hạn chế; nhưng SSRF POST tới dịch vụ nội bộ, quét cổng, và lạm dụng là có thật và cần vá.
- **Vá:**
  1. **Allowlist** domain đích thay vì denylist.
  2. Resolve DNS → kiểm tra IP đích **không** thuộc dải private/loopback/link-local (và chặn rebinding bằng cách chốt IP đã resolve khi gửi).
  3. Thêm auth cho `/webhooks/*` (chỉ admin được đăng ký webhook).

---

## 🟠 H1 — 4 router không có bất kỳ auth nào

`routers/attachments.py`, `routers/webhooks.py`, `routers/call.py`, `routers/agv_gateway.py` không tham chiếu một dependency auth nào.

- **`/api/v1/attachments/upload`** — xem H2.
- **`/webhooks/*`, `/events/emit`** — xem C3. Thêm: `POST /events/emit` cho phép **bất kỳ ai phát event tuỳ ý** (giả cảnh báo SOS/Man-Down, bắn thông báo, kích email) → broadcast WebSocket + dispatch webhook.
- **`/api/v1/call/stun-turn-config`** — có thể lộ credential TURN; `/invite`, WebSocket `/ws/{client_id}` nhận `client_id` tuỳ ý (giả danh/nghe lén tín hiệu cuộc gọi).
- **`/api/v1/agv/door-interlock/trigger`, `/orders`, `/state`** — điều khiển cửa kho lạnh & điều phối AGV. *Hiện tại* chỉ đổi trạng thái trong RAM + log (chưa thấy drive relay vật lý trong code), nhưng đây là **control-plane cho thiết bị vật lý**: khi nối relay thật sẽ thành rủi ro an toàn. Cần auth ngay từ bây giờ.
- **Vá:** gắn `Depends(optional_device)`/`require_admin` phù hợp cho từng router; với nhóm điều khiển vật lý (AGV/door) và webhook nên yêu cầu admin scope.

---

## 🟠 H2 — Upload file không auth + serve tĩnh → Stored XSS & DoS

- **Nơi:** `routers/attachments.py` `POST /upload` (không auth) ghi vào `uploads/`; `app.py:472` `app.mount("/uploads", StaticFiles(...))` serve lại tại `/uploads/<hash><ext>`.
- **Hệ quả:**
  1. **Stored XSS / HTML injection:** tên file do client đặt → `file_ext` tuỳ ý (`.html`, `.svg`). File phục vụ **cùng origin** với API → nhúng `<script>` chạy trong ngữ cảnh ứng dụng web.
  2. **DoS bộ nhớ:** `contents = await file.read()` nạp **toàn bộ** file vào RAM, không giới hạn kích thước.
  3. **DoS đĩa:** không giới hạn số lượng/tổng dung lượng, không auth → nhồi đầy ổ.
- **Vá:**
  1. Yêu cầu auth cho upload.
  2. Allowlist phần mở rộng + kiểm MIME thực tế (magic bytes); **không** tin `file.filename`.
  3. Giới hạn kích thước (stream theo chunk, chặn theo `Content-Length` + giới hạn cứng).
  4. Serve attachment với `Content-Disposition: attachment` và `Content-Type` ép (hoặc từ domain/bucket riêng), tránh render inline.

---

## 🟡 M1 — Swagger/OpenAPI phơi bày công khai

- **Nơi:** `app.py` `FastAPI(title=...)` không đặt `docs_url=None`/`redoc_url=None`/`openapi_url=None`.
- **Hệ quả:** `/docs`, `/redoc`, `/openapi.json` mở → lộ toàn bộ bản đồ endpoint, càng nguy hiểm khi nhiều endpoint đang không auth.
- **Vá:** tắt docs ở production, hoặc đặt sau auth/chỉ cho LAN quản trị.

---

## 🟡 M2 — Fail-open ở peer-sync khi thiếu `IZIIAPP_SERVER_SECRET`

- **Nơi:** `security_auth.py::verify_server_secret` return (cho qua) nếu `server_secret` rỗng. Hiện `.env` **đã set** (24 ký tự) nên tạm an toàn, nhưng phụ thuộc hoàn toàn vào vận hành.
- **Rủi ro:** nếu .env không nạp được (vấn đề PyInstaller đã ghi trong chú thích code — Release không đọc được .env), secret rỗng ⇒ `/peer-sync/*` mở.
- **Vá:** cân nhắc fail-closed cho peer-sync khi chạy không phải loopback; log mức ERROR rõ ràng; thêm health-check xác nhận secret đã nạp lúc khởi động.

---

## 🟡 M3 — `last_used_at` update trên đường xác thực (ghi mỗi request)

- **Nơi:** `lookup_device_by_token` chạy `UPDATE device_tokens SET last_used_at=...` + `commit()` cho **mỗi** request có token.
- **Rủi ro:** tăng tải ghi/contention; có thể bị lạm dụng để gây áp lực DB. (Chức năng, không phải lỗ hổng trực tiếp — ưu tiên thấp.)
- **Vá:** cập nhật theo nhịp (throttle, ví dụ tối đa 1 lần/phút/thiết bị) hoặc ghi async/bỏ commit riêng.

---

## 🔵 L1 — Dependencies pin kiểu `>=` (không khoá version)

- **Nơi:** `requirements.txt` dùng `fastapi>=0.110`, `httpx>=0.26`, `python-multipart>=0.0.9`, `psycopg[binary,pool]>=3.1`...
- **Rủi ro:** không tái lập được build; có thể dính CVE của bản cũ nếu môi trường cài bản thấp. Ví dụ cần kiểm: `python-multipart` < 0.0.18 từng có CVE DoS (CVE-2024-53981) — floor `>=0.0.9` cho phép dính.
- **Vá:**
  1. Pin version chính xác (`==`) hoặc dùng lockfile (`pip-compile`/`uv lock`).
  2. **Chạy trên chính host server (Windows/GCP):**
     ```powershell
     pip install pip-audit
     pip-audit
     ```
  3. Gửi lại output `pip-audit` để mình đối chiếu CVE cụ thể theo version thực tế.

---

## ✅ Điểm làm tốt (giữ nguyên)

- Tách 3 phạm vi secret (server / admin / device) — chặn leo thang từ thiết bị công nhân lên admin.
- Admin **fail-closed** (503 khi chưa cấu hình admin secret).
- Token thiết bị lưu **hash SHA-256**, so sánh **constant-time** (`hmac.compare_digest`).
- CORS giới hạn bằng regex chỉ localhost + dải private IP (không `*`).
- `/admin/reset` xoá bảng từ **hằng số nội bộ** (`_LOG_TABLES`/`_DEVICE_TABLES`), có xác nhận `confirm == server_id` → **không** SQLi, không xoá bảng tuỳ ý.
- Radio gateway có secret riêng, fail-closed.

---

## Thứ tự vá đề xuất (ưu tiên)

1. **C2 + C1:** firewall cổng 8080 về LAN/subnet nhà máy + bật TLS; bật `REQUIRE_DEVICE_TOKEN=1` sau khi enroll xong. (Chặn ngay 80% rủi ro.)
2. **H1 + H2 + C3:** gắn auth cho 4 router; khoá upload (auth + type/size limit + serve an toàn); thay denylist webhook bằng allowlist + chặn private IP.
3. **M1:** tắt `/docs` ở production.
4. **M2 / M3 / L1:** fail-closed peer-sync, throttle `last_used_at`, pin + `pip-audit`.

> Ghi chú: các PoC trong báo cáo chỉ nên chạy trên hệ thống của chính bạn trong môi trường kiểm thử.
