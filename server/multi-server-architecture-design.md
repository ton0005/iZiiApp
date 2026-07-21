# Thiết kế kiến trúc Multi-Server — iZiiApp / Costa Mushroom

## 1. Bối cảnh & Mục tiêu

**Hiện trạng:**
- 1 server duy nhất (PC/laptop) chạy `sync_server.py` qua Uvicorn (`--reload`), dữ liệu SQLite qua Drift ORM
- Đã xác định là bottleneck khi scale (~200 DAU hiện tại, roadmap 5,000+ DAU)
- Thiết bị local (iPhone, iPad, Samsung) sync qua BLE peer-to-peer + kết nối server qua IP:port cố định

**Mục tiêu multi-server:**
- Nhiều PC/laptop cùng chạy server song song, mỗi cái 1 IP riêng, cùng port `8080`
- Các server tự đồng bộ với nhau, tự backup chéo
- Dễ dàng thêm server mới không gián đoạn hệ thống đang chạy
- Thiết bị local tự tìm và chọn server dễ dàng

---

## 2. Mô hình phân vùng server — đề xuất

Có 2 lựa chọn, khuyến nghị **theo khu vực vật lý (zone-based)** vì khớp với cách vận hành nông trại thực tế (mỗi Plant có nhân viên cố định, ít di chuyển qua lại):

| Tiêu chí | Theo khu vực (Zone-based) | Theo tải (Load-based) |
|---|---|---|
| Độ phức tạp | Thấp — dễ hiểu, dễ vận hành | Cao — cần load balancer, phức tạp hơn |
| Phù hợp iZiiApp | Rất phù hợp — Plant M1, M2, Cool Room vốn đã tách biệt vật lý | Phù hợp hơn với web app tập trung, không hợp nông trại phân tán |
| Độ trễ (latency) | Thấp — nhân viên luôn gần server khu vực mình | Không đảm bảo — có thể route sang server xa |
| Khuyến nghị | ✅ **Chọn** | Chỉ cân nhắc khi 1 zone quá tải cần chia nhỏ thêm |

**Đề xuất cụ thể:**
```
Server-M1   → phụ trách Plant M1 (14 phòng dãy trên + 18 phòng dãy dưới = 32 phòng)
Server-M2   → phụ trách Plant M2 (33 phòng)
Server-CR   → phụ trách Cool Room (Orders, Nhập/Xuất kho)
Server-HUB  → (tuỳ chọn, giai đoạn sau) server trung tâm tổng hợp báo cáo toàn nông trại
```

Mỗi server độc lập vận hành được ngay cả khi mất kết nối tới các server khác (offline-first ở tầng server, không chỉ tầng device).

---

## 3. Sơ đồ kiến trúc tổng thể

```
                         ┌─────────────────────────┐
                         │   Server Registry /      │
                         │   Discovery Service      │   (nhẹ, có thể chạy
                         │   (mDNS broadcast hoặc   │    trên 1 trong các
                         │    lightweight registry) │    server hiện có)
                         └────────────┬────────────┘
                                      │ announce / discover
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
     ┌────────▼────────┐    ┌─────────▼────────┐    ┌─────────▼────────┐
     │   Server-M1      │    │   Server-M2       │    │   Server-CR      │
     │ 192.168.1.10:8080│    │ 192.168.1.11:8080 │    │ 192.168.1.12:8080│
     │ SQLite (Drift)   │◄──►│ SQLite (Drift)    │◄──►│ SQLite (Drift)   │
     │ sync_server.py   │    │ sync_server.py    │    │ sync_server.py   │
     └────────┬─────────┘    └─────────┬─────────┘    └─────────┬────────┘
              │  peer-to-peer sync (event-based, xem mục 4)      │
              └───────────────────────┴───────────────────────┘
                                      │
                    backup chéo (mục 5) chạy định kỳ giữa 3 server
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
 ┌──────▼──────┐             ┌────────▼───────┐             ┌───────▼──────┐
 │  iPhone      │             │  iPad          │             │  Samsung     │
 │  (auto-      │             │  (auto-        │             │  (auto-      │
 │  discover +  │             │  discover +    │             │  discover +  │
 │  chọn server)│             │  chọn server)  │             │  chọn server)│
 └──────────────┘             └────────────────┘             └──────────────┘
```

**Mô hình quan hệ giữa các server: Peer-to-peer (mesh), không phải Hub-and-spoke.**
Lý do chọn peer-to-peer: không có single point of failure; nếu dùng hub-and-spoke, server trung tâm chết là toàn hệ thống mất đồng bộ. Xem so sánh chi tiết ở mục 4.3.

---

## 4. Đồng bộ dữ liệu giữa các server (Server-to-Server Sync)

### 4.1. Polling vs Event-based — so sánh

| Tiêu chí | Polling (định kỳ) | Event-based (real-time) |
|---|---|---|
| Độ phức tạp cài đặt | Thấp | Trung bình — cần message queue hoặc webhook nội bộ |
| Độ trễ đồng bộ | Cao (tuỳ chu kỳ, vd 30s–5 phút) | Thấp (gần như tức thời) |
| Tải mạng | Cao hơn khi ít thay đổi (poll vô ích) | Thấp hơn — chỉ gửi khi có thay đổi thật |
| Phù hợp giai đoạn | Giai đoạn 1 (MVP, ít server) | Giai đoạn 2+ (nhiều server, cần realtime) |
| Khuyến nghị | ✅ Bắt đầu bằng polling (đơn giản, ít rủi ro) | Nâng cấp dần sang event-based khi ổn định |

**Đề xuất lộ trình:** Bắt đầu bằng **polling nhẹ** (mỗi 30–60 giây, chỉ gửi các bản ghi có `updated_at` mới hơn lần sync gần nhất — giống cơ chế delta-sync đang dùng qua BLE), sau đó nâng cấp sang **event-based qua WebSocket hoặc lightweight pub/sub** khi cần độ trễ thấp hơn (ví dụ khi Chat cần realtime giữa các Plant).

### 4.2. Cơ chế đồng bộ cụ thể (Delta Sync + Vector Clock)

Tái sử dụng logic delta-sync đã có ở tầng BLE (device ↔ server), áp dụng tương tự cho server ↔ server:

```
Mỗi bản ghi (Job, Room, Employee...) có:
- id (UUID, không dùng auto-increment để tránh trùng giữa các server)
- updated_at (timestamp)
- origin_server_id (server nào tạo/sửa gần nhất)
- version (tăng dần mỗi lần sửa)

Quy trình sync giữa Server-M1 và Server-M2:
1. Server-M1 gửi: "các bản ghi có updated_at > last_sync_timestamp"
2. Server-M2 nhận, so sánh version từng bản ghi:
   - Nếu record chưa tồn tại → insert mới
   - Nếu version bên gửi > version đang có → update
   - Nếu version bằng nhau nhưng nội dung khác (conflict thật) → áp dụng rule ở mục 4.3 bên dưới
3. Cập nhật last_sync_timestamp sau khi sync xong
```

### 4.3. Xử lý Conflict

**Nguyên tắc chung: Last-Write-Wins theo timestamp, có ngoại lệ cho dữ liệu nghiệp vụ quan trọng.**

| Loại dữ liệu | Rule xử lý conflict |
|---|---|
| Job status update (vd: cùng lúc 2 nơi update `updateJobStatus`) | Last-Write-Wins theo `updated_at` — vì trạng thái Job là tức thời, bản ghi mới nhất phản ánh đúng thực tế hơn |
| Tạo Job mới (`createJob`) trùng gần như đồng thời cho cùng Room | Giữ cả 2, không merge — vì đây là 2 Job khác nhau về nghiệp vụ (Manager có thể cố ý thêm nhiều Job). Chỉ cảnh báo UI nếu trùng loại Job trong cùng khung giờ |
| Thêm Room mới trùng số phòng | **Reject bản ghi đến sau** — Room number phải unique theo Plant, đây là conflict thật cần chặn cứng, không LWW |
| Employee permission override (Manager chỉnh quyền) | Version cao hơn thắng + ghi log audit cả 2 thay đổi để Manager xem lại nếu cần |

---

## 5. Backup

**2 lớp backup:**

1. **Local backup (tự backup chính mình):** Mỗi server tự động export SQLite snapshot định kỳ (vd mỗi đêm) ra thư mục local hoặc external drive.
2. **Backup chéo (cross-server backup):** Sau mỗi lần sync thành công, mỗi server lưu thêm 1 bản sao dữ liệu của các server khác (dạng snapshot nén) — không cần realtime, chạy nền lúc tải thấp.

```
Server-M1 backup:  [Data M1] + [Snapshot M2] + [Snapshot CR]
Server-M2 backup:  [Data M2] + [Snapshot M1] + [Snapshot CR]
Server-CR backup:  [Data CR] + [Snapshot M1] + [Snapshot M2]
```

→ Nếu 1 server hỏng hoàn toàn, dữ liệu của nó vẫn còn ở snapshot trên 2 server còn lại, restore lại bằng cách dựng server mới + import snapshot gần nhất.

**Failover cho thiết bị local:** Khi app không kết nối được server đang chọn (vd Server-M1 down), app tự động gợi ý chuyển sang server khác đang khả dụng (Server-M2 hoặc Server-CR) — nhưng cần lưu ý: dữ liệu hiển thị có thể là snapshot backup (không phải live), cần hiển thị rõ trạng thái "đang xem dữ liệu backup, có thể chưa cập nhật mới nhất" để tránh nhân viên hiểu nhầm.

---

## 6. Server Discovery — thiết bị local chọn server dễ dàng

**Công nghệ đề xuất: mDNS (Bonjour/Zeroconf)** — vì:
- Hoạt động tốt trong mạng LAN nội bộ (đúng bối cảnh nông trại, không cần internet ra ngoài)
- iOS hỗ trợ native (Bonjour), Android hỗ trợ qua NSD (Network Service Discovery) — không cần thư viện ngoài phức tạp
- Không cần server registry tập trung (tránh single point of failure)

**Cách hoạt động:**
```
1. Mỗi server khi khởi động sẽ "quảng bá" (advertise) chính nó qua mDNS:
   service type: _iziiapp._tcp.local.
   TXT record: { zone: "M1", name: "Server-M1", version: "1.2.0" }

2. App trên thiết bị local quét mDNS trong mạng → hiện danh sách:
   ┌─────────────────────────────────┐
   │  Chọn server để kết nối          │
   │  ● Server-M1  (192.168.1.10)     │
   │  ● Server-M2  (192.168.1.11)     │
   │  ● Server-CR  (192.168.1.12)     │
   │  ○ Nhập IP thủ công...           │
   └─────────────────────────────────┘

3. Nhân viên chọn 1 server → lưu làm mặc định (SharedPreferences/local storage)
4. Nếu server mặc định không phản hồi → app tự quét lại, gợi ý server khác khả dụng
```

**Fallback thủ công:** vẫn giữ tuỳ chọn nhập IP:port tay, vì mDNS đôi khi bị chặn bởi router/firewall doanh nghiệp — không nên phụ thuộc 100% vào auto-discovery.

---

## 7. Mở rộng (Extend) — thêm server mới

Nhờ kiến trúc peer-to-peer + mDNS discovery, thêm server mới **không cần cấu hình lại server cũ**:

```
Bước 1: Cài đặt sync_server.py lên PC/laptop mới, gán zone_id riêng (vd "M2-Extension")
Bước 2: Server mới tự advertise qua mDNS ngay khi khởi động
Bước 3: Các server cũ tự phát hiện server mới qua mDNS scan định kỳ, thêm vào danh sách peer
Bước 4: Server mới thực hiện "initial full sync" — kéo toàn bộ dữ liệu liên quan từ 1 server gần nhất (thường là server cùng Plant) để có baseline data
Bước 5: Từ đây trở đi, server mới tham gia vào chu kỳ delta-sync bình thường
```

---

## 8. Phase triển khai — không gián đoạn hệ thống đang chạy

| Phase | Nội dung | Rủi ro gián đoạn |
|---|---|---|
| **Phase 0** | Refactor `sync_server.py`: thêm `zone_id`, chuyển ID sang UUID, thêm cột `updated_at`/`version`/`origin_server_id` vào các bảng chính | Thấp — chạy migration script, server hiện tại vẫn hoạt động 1 mình trong lúc này |
| **Phase 1** | Dựng thêm 1 server thứ 2 (vd Server-M2), bật polling sync giữa 2 server, chưa bật cho device dùng | Thấp — chạy song song, chưa ảnh hưởng thiết bị đang dùng server cũ |
| **Phase 2** | Bật mDNS discovery, cho 1 nhóm nhỏ thiết bị test chuyển sang chọn server qua danh sách mới | Trung bình — cần rollback plan nếu discovery lỗi (giữ fallback nhập IP tay) |
| **Phase 3** | Dựng server thứ 3 (Cool Room), hoàn thiện backup chéo giữa 3 server | Thấp — backup chạy nền, không chặn hoạt động chính |
| **Phase 4** | Nâng polling sync → event-based (WebSocket) cho các module cần realtime (Chat, Safety Alarm) | Trung bình — cần test kỹ độ trễ, có thể giữ song song polling làm backup mechanism |
| **Phase 5** | Đánh giá lại: nếu 1 zone quá tải, cân nhắc chia nhỏ theo tải (load-based) thay vì chỉ theo khu vực | Thấp — chỉ áp dụng khi cần, không bắt buộc |

---

## 9. Tóm tắt quyết định kiến trúc

| Vấn đề | Quyết định |
|---|---|
| Mô hình phân vùng | Theo khu vực vật lý (Zone-based): M1, M2, Cool Room |
| Quan hệ giữa các server | Peer-to-peer (mesh), không Hub-and-spoke |
| Cơ chế sync | Bắt đầu Polling delta-sync → nâng cấp Event-based (WebSocket) sau |
| Conflict resolution | Last-Write-Wins theo mặc định, có rule riêng cho Room number (reject) và Job creation (giữ cả 2) |
| Backup | Local backup + Backup chéo giữa các server (snapshot định kỳ) |
| Server discovery | mDNS (Bonjour/NSD) + fallback nhập IP thủ công |
| Mở rộng server mới | Tự advertise qua mDNS, initial full sync từ server gần nhất, không cần cấu hình lại server cũ |
