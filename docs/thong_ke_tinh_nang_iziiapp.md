# Thống kê Tính năng & Kiến trúc Dự án iZiiApp

Báo cáo thống kê toàn bộ các tính năng, mô-đun nghiệp vụ, công nghệ áp dụng và các thiết kế tích hợp nâng cao của hệ thống **iZiiApp (Enterprise Modular ERP & WHS Engine)**.

---

## 1. Tổng quan Hệ thống
**iZiiApp** là một nền tảng vận hành doanh nghiệp đa mô-đun kết hợp giữa quản trị thương mại (ERP), điều phối sản xuất (MES) và kiểm soát **An toàn lao động (WHS - Work Health & Safety)**. Hệ thống được xây dựng theo triết lý **Offline-First**, đảm bảo hoạt động liên tục ngay cả khi mất kết nối mạng toàn bộ phân xưởng hoặc nông trại.

---

## 2. Danh sách Mô-đun & Tính năng Nghiệp vụ

### 🍄 Mô-đun 1: Quản lý Nông nghiệp & Nông trại Nấm (Mushroom Farm Operations)
* **Quản lý Sơ đồ Phòng trồng (Grow Rooms Management)**:
  * Quản lý trạng thái và thông tin chi tiết từng phòng (mã phòng, giai đoạn vụ mùa/current stage, số ngày trong chu kỳ/day in cycle).
  * Đặt và theo dõi sản lượng mục tiêu (Target Yield) và sản lượng thực tế đã thu hoạch (Picked Yield).
* **Quản lý Vụ mùa & Thu hoạch (Growing & Harvest Control)**:
  * Nhật ký thu hoạch (Harvest Tab) ghi nhận sản lượng theo từng ca kíp / nhân viên.
  * Theo dõi quy trình sinh trưởng nấm theo thời gian thực.
  * Ghi nhận và theo dõi các chỉ số môi trường sinh trưởng (Nhiệt độ, Độ ẩm, CO, CO₂).

### 🛡️ Mô-đun 2: Kiểm soát An toàn Lao động (WHS / Alone Worker Safety Engine)
* **Giám sát Làm việc Độc lập (Alone Worker Control)**:
  * Đáp ứng tiêu chuẩn an toàn khi công nhân làm việc một mình trong không gian kín (phòng trồng khí nồng độ CO/CO₂ cao).
* **Đồng hồ Đếm ngược An toàn (Safety Countdown Timer & Check-in)**:
  * Tự động khởi tạo đếm ngược thời gian an toàn khi công nhân vào phòng thực hiện nhiệm vụ.
  * Yêu cầu công nhân nhấn nút **Check-in xác nhận an toàn** định kỳ (Check-in interval).
* **Còi Báo động & Leo thang Cảnh báo (Siren Red Alarm & Escalation)**:
  * Tự động kích hoạt **Siren Red Alarm** trên ứng dụng nếu công nhân quá giờ check-in mà chưa xác nhận.
  * Tự động gửi tín hiệu cảnh báo khẩn cấp (Escalation) tới máy của Giám sát viên (Supervisors / Site Leads) và phòng điều khiển.
* **Cảnh báo Khí độc CO / CO₂**: Theo dõi chỉ số khí nồng độ CO/CO₂ và đưa ra cảnh báo nguy hiểm kịp thời.

### 🔄 Mô-đun 3: Đồng bộ Dữ liệu Ngoại tuyến & Mạng Mesh (Offline-First Sync Engine)
* **Cơ chế Outbox Queue Pattern**:
  * Mọi thao tác sửa đổi dữ liệu (tạo job, check-in, ghi thu hoạch) khi không có mạng sẽ được lưu vào bảng local queue (`outbox_mutations`).
  * Tự động đồng bộ (Push/Pull) lên server ngay khi phát hiện có kết nối mạng.
* **Tự động Phát hiện Server trong LAN (mDNS / ZeroConf Discovery)**:
  * Ứng dụng tự động tìm kiếm và kết nối tới máy chủ local `izii_server` trong mạng nội bộ mà không cần nhập IP thủ công.
* **Đồng bộ Peer-to-Peer qua Bluetooth (BLE P2P Sync)**:
  * Đồng bộ dữ liệu trực tiếp giữa các thiết bị di động bằng Bluetooth Low Energy (BLE) khi hoàn toàn không có sóng Wi-Fi/LAN.
* **Mạng Mesh Đa Server (Multi-Server Mesh Peer-Sync)**:
  * Các nút `izii_server` ở từng nhà máy / phân xưởng tự tìm thấy nhau và đồng bộ song song dữ liệu qua giao thức peer-to-peer.

### 📦 Mô-đun 4: Quản lý Chuỗi cung ứng & Kho hàng (Supply Chain & Inventory)
* **Quản lý Vật tư & Sản phẩm**: Quản lý tồn kho giá thể, phân bón, hóa chất bảo vệ thực vật, bao bì và thành phẩm.
* **Tích hợp Tự động Quét Mã vạch (Barcode Scanner)**: Quét mã vạch phục vụ xuất/nhập/kiểm kê kho nhanh chóng.
* **Theo dõi Lô & Số Serial (Batch/Serial Tracking)**: Quản lý hạn sử dụng và nguồn gốc xuất xứ của từng lô sản phẩm.

### 💼 Mô-đun 5: Quản lý Bán hàng & Khách hàng (Sales & CRM)
* **Quản lý Khách hàng & Báo giá**: Quản lý danh mục đối tác/khách hàng, lập báo giá nhanh.
* **Đơn bán hàng (Sales Orders)**: Theo dõi trạng thái đơn hàng từ lúc chốt đơn đến khi giao hàng và đối soát tồn kho.

### 📊 Mô-đun 6: Quản lý Dự án & Tiến độ (Project Management)
* **Quản lý Công việc & Phân công (Task Assignment)**: Tạo job, giao việc cho công nhân, thiết lập thời gian hoàn thành (Time limit).
* **Theo dõi Tiến độ Thực tế**: Theo dõi trạng thái thực hiện công việc (Pending, In-Progress, Completed).

### 💬 Mô-đun 7: Truyền thông & Chat Nội bộ (Internal Communication)
* **Real-time Chat Engine (WebSockets)**: Cho phép trao đổi tin nhắn tức thời giữa nhân viên, quản lý và kỹ thuật viên.
* **P2P Attachment Sync**: Đồng bộ và chia sẻ tệp tin đính kèm giữa các thiết bị ngay cả trong môi trường ngoại tuyến.

### 🔐 Mô-đun 8: Bảo mật & Phân quyền Chi tiết (Security & Dynamic RBAC)
* **Mã hóa Bảo mật End-to-End (E2EE)**:
  * Sử dụng thuật toán X25519, AES-256-GCM và Ed25519 để mã hóa định danh thiết bị và dữ liệu nhạy cảm.
  * Lưu trữ Auth Token an toàn trong `flutter_secure_storage`.
* **Phân quyền 4 Cấp (Role-Based Access Control - RBAC)**:
  * **Level 3 (Manager / Site Lead)**: Toàn quyền cấu hình hệ thống, khởi tạo vụ mùa, phân công job, duyệt đè quyền.
  * **Level 2 (Supervisor / Lead)**: Quản lý nhóm công việc, theo dõi an toàn WHS.
  * **Level 1 (Specialist)**: Xem báo cáo chuyên môn, nhật ký kỹ thuật.
  * **Level 0 (Worker / Picker)**: Thực hiện công việc được giao, Check-in an toàn.
* **Granular Permission Overrides**: Hỗ trợ chèn đè cấp quyền cụ thể (`ALLOW` / `DENY`) linh hoạt cho từng nhân viên.

---

## 3. Các Thiết kế Kiến trúc & Tích hợp Doanh nghiệp nâng cao

### 🏷️ Cấp phát Thiết bị qua Thẻ NFC (NFC Provisioning Design)
* Thiết kế cơ chế chạm thẻ NFC (NDEF) để onboard thiết bị di động mới trong môi trường công nhân đeo găng / tay ướt.
* Sử dụng vé mời một lần (Enrollment Token 10 phút) để đăng ký thiết bị an toàn thay vì chia sẻ chuỗi secret chung.

### 🏢 Chiến lược Tích hợp Doanh nghiệp (ISA-95 MES Level 3)
* **Tích hợp SAP S/4HANA**: Chuẩn hóa luồng trao đổi dữ liệu hai chiều cho Lệnh sản xuất (PP), Thu hoạch/Báo sản lượng (Goods Receipt - MM), Hồ sơ Nhân sự (HR) và Lệnh bảo trì (PM) qua OData/IDoc.
* **Tích hợp SCADA / AVEVA Wonderware**: Đọc dữ liệu cảm biến CO/CO₂ từ Historian và đẩy ngược cảnh báo An toàn lao động (Alone Worker Red Alarm) trực tiếp lên màn hình HMI InTouch của phòng điều khiển trung tâm.

---

## 🛠️ 4. Nền tảng Công nghệ (Tech Stack)

| Tầng (Layer) | Công nghệ / Thư viện | Mục đích sử dụng |
| :--- | :--- | :--- |
| **Frontend Framework** | Flutter / Dart SDK `^3.5.0` | Xây dựng giao diện đa nền tảng (Mobile, Desktop) |
| **State Management** | Flutter BLoC `^9.0.0` | Quản lý trạng thái logic nghiệp vụ và UI |
| **Local Storage / ORM** | Drift (SQLite ORM) `^2.22.1` | Cơ sở dữ liệu SQLite tại thiết bị với mã hóa |
| **Network HTTP / REST** | Dio `^5.7.0` | REST API Client hỗ trợ interceptors, file upload |
| **Real-time Sync & Chat**| WebSockets (`web_socket_channel`) | Truyền nhận sự kiện đồng bộ tức thời và chat |
| **Network Discovery** | `multicast_dns` | Tự động phát hiện `izii_server` trong mạng LAN |
| **P2P & Peripheral** | BLE (`flutter_blue_plus`) | Đồng bộ dữ liệu ngoại tuyến qua Bluetooth |
| **Backend Framework** | Python FastAPI / Uvicorn | Backend Server siêu nhẹ, bất đồng bộ (`asyncio`) |
| **Service Discovery** | Zeroconf (Python) | Phát dịch vụ mDNS `_iziiapp._tcp.local.` trong LAN |
| **Cryptographic Engine** | `cryptography` `^2.7.0` | Mã hóa End-to-End (X25519, AES-256-GCM, SHA-256) |
| **Security Storage** | `flutter_secure_storage` `^10.3.0`| Lưu trữ token bảo mật trên hệ điều hành |
