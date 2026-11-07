# iZiiApp Server — Ghi chú bản vá bảo mật (2026-11-04)

Đã sửa trực tiếp 6 file trong `server/`. Tất cả đã `py_compile` OK.

## Thay đổi theo file

### `security_auth.py` — MỚI: chống SSRF dùng chung
- Thêm `validate_outbound_url(url, allowed_hosts=None)`: chỉ cho http/https; resolve DNS và chặn mọi IP loopback/private/link-local/CGNAT/reserved/multicast (gồm `169.254.169.254` và IPv4-mapped `::ffff:127.0.0.1`); hỗ trợ allowlist domain; chống DNS-rebinding.
- Thêm import `ipaddress`, `socket`, `urllib.parse.urlparse`.

### `routers/webhooks.py` — vá C3 + H1
- Cả `/webhooks/*` và `/events/*` giờ yêu cầu **`X-iZii-Admin-Token`** (router-level `Depends(require_admin)`).
- `/webhooks/register` thay denylist 3-host bằng `validate_outbound_url()`.

### `routers/attachments.py` — vá H2
- `/upload` yêu cầu `optional_device` (ép token khi bật cờ).
- Allowlist phần mở rộng; chặn tuyệt đối `.html/.svg/.js/.php/.exe...` → không còn stored XSS qua `/uploads`.
- Giới hạn **25 MB**, đọc theo chunk (không nạp vô hạn vào RAM); chặn path traversal từ tên file; lỗi không còn lộ chi tiết exception.

### `routers/call.py` — vá H1
- `/stun-turn-config`, `/invite`: `Depends(optional_device)`.
- WebSocket `/call/ws/{client_id}`: khi `REQUIRE_DEVICE_TOKEN=1` thì kiểm token qua `?token=` hoặc header, sai/thiếu → đóng kết nối (4401).

### `routers/agv_gateway.py` — vá H1
- Router-level `optional_device` cho tất cả endpoint AGV.
- `/orders` và `/door-interlock/trigger` thêm **`require_admin`** (điều khiển vật lý/điều phối → fail-closed).

### `app.py` — vá M1
- `/docs`, `/redoc`, `/openapi.json` **tắt mặc định**; bật lại khi debug bằng `IZIIAPP_ENABLE_DOCS=1`.

## ⚠️ Thay đổi hành vi cần biết (có thể ảnh hưởng client)
1. **Webhook & events giờ cần admin token.** Nếu có hệ thống đang gọi `/webhooks/*` hoặc `/events/emit` mà không gửi `X-iZii-Admin-Token` → sẽ nhận 401/503. Cần cấp token cho hệ thống đó.
2. **AGV `/orders` và `/door-interlock/trigger` cần admin token.** Nếu phần mềm WMS/điều phối đang gọi 2 endpoint này, phải bổ sung header admin.
   - *Đề xuất tốt hơn:* tạo secret riêng cho gateway AGV (giống `radio_gateway_secret`) để WMS/AGV không phải cầm admin secret. Nói mình nếu muốn làm.
3. **Upload chỉ nhận loại tệp trong allowlist** và tối đa 25 MB. Chỉnh `ALLOWED_EXTENSIONS` / `MAX_UPLOAD_BYTES` trong `attachments.py` nếu cần.

## Việc cấu hình cần tự làm (KHÔNG sửa tự động để tránh gãy nhà máy)
- **C1:** sau khi mọi thiết bị đã enroll → đặt `IZIIAPP_REQUIRE_DEVICE_TOKEN=1` trong `.env`, khởi động lại.
- **C2:** firewall cổng 8080 về subnet nhà máy + bật TLS (code đã hỗ trợ `IZIIAPP_TLS_CERT_FILE/KEY/CA`); kiểm GCP VM firewall.
- **M1 (production):** để nguyên — docs đã tắt. Chỉ set `IZIIAPP_ENABLE_DOCS=1` khi cần.

## Test nhanh sau khi vá
```powershell
# 1. Server khởi động không lỗi import
python app.py   # hoặc lệnh chạy uvicorn hiện tại

# 2. Docs đã tắt (mong đợi 404)
(Invoke-WebRequest http://localhost:8080/docs -UseBasicParsing -SkipHttpErrorCheck).StatusCode

# 3. Webhook đòi admin token (mong đợi 401/503)
Invoke-WebRequest http://localhost:8080/webhooks/subscriptions -UseBasicParsing -SkipHttpErrorCheck

# 4. SSRF bị chặn (mong đợi 403) — cần gửi kèm admin token hợp lệ để qua auth trước:
#   body {"url":"http://169.254.169.254/"} → 403 "Địa chỉ nội bộ..."

# 5. Upload loại tệp cấm (mong đợi 415) với file .html
```

## pip-audit — chạy ĐÚNG venv của server
Bản `pip-audit.txt` vừa gửi quét nhầm môi trường (django/accelerate/torch — không phải deps của server). Chạy trong đúng venv đang chạy server:
```powershell
# kích hoạt venv của server trước, ví dụ:
.\venv\Scripts\Activate.ps1
pip install pip-audit
pip-audit                      # quét đúng fastapi/uvicorn/httpx/psycopg...
pip freeze > server\security\pip-freeze.txt
```
Gửi lại `pip-freeze.txt` + output `pip-audit` để mình đối chiếu CVE theo version thực tế.
