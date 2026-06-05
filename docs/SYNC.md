Sync server (mock) — hướng dẫn sử dụng

Tổng quan
- Ứng dụng sử dụng một mock sync server (Python) để nhận/push mutations và trả về cập nhật cho thiết bị.
- Đồng bộ chỉ hoạt động khi process `sync_server.py` đang chạy trên máy phát triển.

Chạy mock server locally
1. Mở terminal trên thư mục gốc project (nơi chứa `sync_server.py`).
2. Chạy lệnh:

```bash
python sync_server.py
```

3. Màn hình sẽ in thông tin server, ví dụ:
   - http://127.0.0.1:8080
   - Kiểm tra trạng thái: http://127.0.0.1:8080/sync/status

Lưu ý khi test trên thiết bị di động / emulator
- Nếu dùng Android Emulator (hoặc thiết bị thật qua USB), đảm bảo kết nối mạng:
  - Với Android emulator: `adb reverse tcp:8080 tcp:8080` để ánh xạ port local vào emulator.
  - Với thiết bị thật trên cùng mạng Wi‑Fi: thay `127.0.0.1` bằng IP máy tính (ví dụ `http://192.168.1.100:8080`) và đảm bảo firewall cho phép kết nối.

Cấu hình trong ứng dụng
- Mặc định (thay đổi mã nguồn): `http://127.0.0.1:8080`.
- Mở `Đồng bộ Dữ liệu` (Settings → Sync). Nếu cần, thay đổi `Server URL` và `API Token` rồi nhấn `Lưu cấu hình`.
- Nhấn `Đồng bộ ngay` để thực hiện push/pull thủ công; app cũng sẽ tự động đồng bộ khi phát hiện mạng trở lại.

Xác minh hoạt động
- Khi app gửi dữ liệu, bạn sẽ thấy log `📥 [PUSH]` trong terminal chạy server.
- Khi app kéo cập nhật, bạn sẽ thấy log `📤 [PULL]` và server trả về `updates`.

Gợi ý debug
- Nếu app báo lỗi kết nối, kiểm tra:
  - Server đang chạy ở port 8080.
  - URL trong app đúng (http vs https).
  - Nếu dùng device/emulator: đã chạy `adb reverse` hay dùng IP máy chủ chính xác.
- Kiểm tra log app (Sync screen) và log terminal của `sync_server.py` để biết chi tiết.

Liên hệ
- Nếu cần thay đổi endpoint server thật, cập nhật trường `sync_server_url` trong `SharedPreferences` qua màn hình cấu hình hoặc thay đổi mặc định trong `lib/core/settings/settings_service.dart`.
