# iZii Radio Bridge

Cầu nối giữa hệ thống Hytera (HP682 → repeater HR1062) và iZiiServer: nhận gói dữ liệu HSTRP/HDAP qua UDP,
đổi thành sự kiện SOS / Man Down / Lone Worker, đẩy sang `POST /api/v1/radio/events` (xem
`plan/Hytera/HUONG_DAN_TICH_HOP_HYTERA.md`, mục 3). Kèm **bộ giả lập HP682 + HR1062** để test khi chưa có phần cứng.

> **Trạng thái: đã test với thiết bị GIẢ, chưa test với Hytera thật.** Khuôn dạng gói trong simulator được dựng
> bằng chính ok-dmrlib mà bridge dùng để giải mã, nên test xanh chứng minh bridge *nhất quán với thư viện*,
> không chứng minh *khớp với HR1062*. Phần đó cần gói bắt thật + tài liệu ADK (mục "Khi có ADK").

> **Dev mới: đọc [DEV_GUIDE.md](DEV_GUIDE.md)** — kiến trúc, giả định chưa kiểm chứng, quy trình khi có ADK, runbook.

## Thành phần

| File | Vai trò |
|---|---|
| `codec.py` | **Duy nhất** chỗ dùng ok-dmrlib: PDU → `RadioEvent`. Thay file này khi có ADK |
| `bridge.py` | UDP asyncio (ACK/heartbeat do ok-dmrlib), bỏ gói trùng do mất ACK, gộp broadcast lặp của repeater, ghi gói lạ |
| `delivery.py` | Giao hàng bền vững: ghi `spool/<id>.json` trước khi gửi, thử lại, nạp lại sau khi khởi động lại |
| `simulator.py` | `SimHP682` (đếm giờ Lone Worker, góc nghiêng Man Down, Tx Cycles, huỷ khẩn cấp), `SimHR1062` (broadcast trạng thái) |
| `mock_izii.py` | iZiiServer giả (kiểm token, chèn lỗi, dùng `server/radio_events.py` để kiểm hợp đồng) |
| `commands.py` | Chiều xuống: lấy lệnh từ server (hỏi/bật/tắt Lone Worker, nhắn tin), gửi xuống bộ đàm, báo kết quả |
| `full_chain_local.py` | Bridge + simulator với iZiiServer **thật** (SQLite tạm): kịch bản `andrew` (Radio 507: Lone Worker + tin time out) và `sos` |

## Chạy

```bash
pip install -r radio_bridge/requirements.txt pytest
python -m pytest radio_bridge/tests -q                     # 30 test, ~45 s, không cần mạng/phần cứng

# Toàn chuỗi với server thật (server chạy bằng Python có phụ thuộc của server/):
SERVER_PYTHON=/path/to/server/python  python -m radio_bridge.full_chain_local [--scenario andrew|sos|all]

# Chạy bridge thật (token = IZIIAPP_RADIO_GATEWAY_SECRET của server):
IZII_RADIO_TOKEN=... python -m radio_bridge --izii-url http://server:8080 --ports 3002,3003,3005 \
    --capture capture.jsonl
# Bộ đàm giả bật liên tục, trả lời lệnh từ app, gõ lệnh tay (k, sos, down/up, lw on/off, s, q):
python -m radio_bridge.simulator --target 127.0.0.1:3005 --radio 507 --scenario serve
# hoặc chạy một kịch bản rồi tắt:
python -m radio_bridge.simulator --target 127.0.0.1:3005 --radio 1001 --scenario sos|man_down|lone_worker
```

**Test bằng app:** Safety → Hytera Radios → **Test Alone Worker**. Màn hình đi 5 bước: điểm danh (vd Andrew) → đăng ký
Radio 507 cho ca → hỏi/bật Lone Worker trên radio → giao job Alone Worker (1 phút) → khi hết giờ, xem server đã gửi tin
xuống Radio 507 và radio đã xác nhận chưa. Cần server + bridge + bộ đàm (hoặc simulator `serve` ở trên).

## Hành vi cần biết

* **Không mất báo động:** sự kiện ghi ra đĩa trước khi gửi; mạng/server lỗi, 401/403/503 (sai/thiếu secret) và 5xx
  được thử lại vô hạn; chỉ payload hỏng (4xx khác) mới vào `spool/dead/`.
* **Gói không giải mã được** không bị nuốt: đếm `undecoded`, log WARNING kèm hex, và ghi vào `--capture`.
* **Lone Worker:** `LONE_WORKER_REMINDER` chỉ là nhắc nhở (bấm phím là huỷ) nên mặc định KHÔNG chuyển thành báo
  động (`--forward-lone-reminder` để bật). Hết giờ thật đến dưới dạng Emergency.
* Qua đường repeater, SOS / Man Down / Lone Worker hết giờ đều là "emergency" (Hytera xác nhận) → có thể không
  phân biệt được; server xử lý cả ba như nhau.
* Bridge chỉ **lắng nghe** (passive); cổng mặc định 3002/3003/3005 là theo ví dụ ok-dmrlib, **chưa xác nhận**.

## Khi có ADK (sau NDA) — danh sách việc

1. Chạy bridge với `--capture` bên cạnh HR1062 thật (hoặc Wireshark), bấm thử SOS / để Man Down / Lone Worker hết
   giờ trên HP682; giải mã gói thô bằng `dmrlib-hytera-*` và **đối chiếu từng bản tin với ADK**.
2. Chốt các giả định trong đầu `codec.py` (value≠0 = đang xảy ra; call_type Emergency + sender_id; Man Down/Lone
   Worker có phân biệt được không). Sửa `codec.py` và `simulator.py` cho khớp rồi chạy lại 30 test.
3. Xác nhận cổng UDP, hướng kết nối (repeater tìm bridge hay ngược lại), cấu hình CPS repeater/radio. Nếu bridge phải
   chủ động kết nối, thêm vào `bridge.py`.
4. Cần bản tin "huỷ khẩn cấp" và "Emergency kèm vị trí": ok-dmrlib chưa giải mã được (`EmergencyReport` 0xB003,
   `CancelEmergencyAlarmWithSender` 0x0853) — tự bổ sung theo ADK.
5. Test thật theo bảng nghiệm thu mục 6 của `HUONG_DAN_TICH_HOP_HYTERA.md` (cả thao tác bấm thật trên HP682).
6. Đặt bridge chạy như dịch vụ Windows (NSSM) kèm giám sát: bridge chết là mất báo động. Hiện chưa có health-check.

## Giấy phép

`requirements.txt` kéo **ok-dmrlib (AGPL-3.0)**. Giữ `radio_bridge/` thành tiến trình riêng, không đóng gói vào
`izii_server.exe`, và xin ý kiến pháp lý trước khi phân phối cho khách hàng. Tài liệu ADK dưới NDA không được đưa vào repo
công khai.
