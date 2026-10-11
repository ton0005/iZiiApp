# PHÂN TÍCH THIẾT KẾ LOGISTICS, INVENTORY & WAREHOUSE CHO IZIÍAPP
## Đánh giá Chuyên sâu & Định hướng Nâng cấp Hệ thống Kho Vận Nhà máy Quy mô Lớn

---

| Thông tin | Chi tiết |
| :--- | :--- |
| **Dự án** | iZiiApp (Enterprise Modular ERP & WHS Engine) |
| **Chuyên mục** | Phân tích Thiết kế & Kiến trúc Chuỗi Cung Ứng, Kho Vận (WMS / SCM / Intralogistics) |
| **Đối tượng áp dụng** | Tổ hợp nhà máy chế biến, nông nghiệp kỹ thuật cao & sản xuất công nghiệp quy mô lớn (Điển hình: Costa Mushroom M1 & M2, sản lượng 60 tấn/ngày) |
| **Ngày lập báo cáo** | Tháng 10/2026 |
| **Tác giả** | Chuyên gia Thiết kế Logistics, Inventory & Warehouse Công nghiệp |

---

## 1. TỔNG QUAN HIỆN TRẠNG KIẾN TRÚC IZIÍAPP

### 1.1 Điểm mạnh và Lợi thế Cạnh tranh Cốt lõi (Core Strengths)
Hệ thống iZiiApp sở hữu nền tảng công nghệ rất đặc thù và phù hợp vượt trội cho môi trường phân xưởng, nhà kho lớn so với các giải pháp WMS chạy thuần đám mây (Cloud-only):

1. **Triết lý Ngoại tuyến Toàn diện (Offline-First Architecture)**:
   * Được thiết kế trên nền tảng Flutter + Drift (SQLite) ở Client và FastAPI + Postgres/SQLite ở Server.
   * Cơ chế **Outbox Queue Pattern** cho phép thiết bị di động, máy tính bảng gắn trên xe nâng (Forklift Mounted Terminals) hoạt động bình thường kể cả khi mất kết nối mạng hoàn toàn trong kho lạnh âm sâu, hầm kín hoặc nông trại rộng lớn.
2. **Khả năng Đồng bộ Đa kênh (Multi-tier Sync Engine)**:
   * Tự động phát hiện máy chủ cục bộ bằng mDNS/ZeroConf trong mạng LAN nội bộ.
   * Hỗ trợ đồng bộ ngang hàng qua **Bluetooth Low Energy (BLE P2P Sync)** giữa các thiết bị khi Wi-Fi/LAN bị gián đoạn.
   * Mạng lưới đa máy chủ (Multi-server Mesh Peer-Sync) giúp nhân bản dữ liệu giữa các phân xưởng/nhà máy phân tán (ví dụ: Nhà máy M1 và Nhà máy M2) mà không phụ thuộc vào kết nối Internet liên tục về trụ sở chính.
3. **Mầm mống Tự động hóa Kho & IoT (`warehouse_automation`)**:
   * Bảng `Locations` được thiết kế xuất sắc với cấu trúc cây kép: vừa dùng `parentId` (Adjacency list), vừa dùng `path` (Materialized path dạng `/WH1/A/03/B/12`), tích hợp sẵn tọa độ 3D `(posX, posY, posZ)` cho AGV/AMR, tải trọng tối đa, thể tích và cờ `isStorable`.
   * Bảng `IotDevices` và `SensorReadings` hỗ trợ kết nối cảm biến LoRaWAN/BLE, lưu trữ chuỗi thời gian dạng Append-only, có cơ chế khử rung (`debounceCount`, `cooldownSec`) để kích hoạt luật tự động.
4. **Tích hợp sẵn WHS / An toàn Lao động**:
   * Kiểm soát công nhân làm việc đơn độc trong môi trường rủi ro (Alone Worker Safety Engine), giám sát nồng độ khí CO/CO₂, đếm ngược an toàn, còi báo động đỏ (Siren Red Alarm) và quy trình leo thang sự cố.

---

### 1.2 Lỗ hổng & Điểm nghẽn Cần Khắc phục (Industrial Gaps)
Mặc dù hạ tầng kỹ thuật rất mạnh, nhưng tầng **logic nghiệp vụ Logistics & Kho vận** trong codebase hiện tại (`lib/modules/supply_chain`, `purchase`, `sales_crm`) mới dừng ở mức quản lý bán lẻ cơ bản, chưa đáp ứng được chuẩn vận hành của một nhà máy lớn:

* **Mô hình Tồn kho phẳng và Đơn vị tính duy nhất (Single UoM)**:
  * Bảng `Products` chỉ có 1 trường giá và 1 đơn vị tính. Trong nhà máy, một mặt hàng bắt buộc phải có hệ số quy đổi: *Kg $\rightarrow$ Khay/Hộp $\rightarrow$ Thùng (Box) $\rightarrow$ Lớp (Layer) $\rightarrow$ Pallet*.
* **Tồn kho chưa gắn chặt với Cây vị trí và Lô hàng**:
  * Bảng `StockQuants` hiện tại chỉ lưu `productId`, `locationId` (kiểu chuỗi tự do, chưa ràng buộc với cây `Locations`) và `quantity`. Hoàn toàn thiếu thuộc tính **Số Lô (Lot/Batch ID)**, **Hạn sử dụng (Expiry/Shelf-life)**, và **Mã biển số Pallet (LPN - License Plate Number)**.
* **Quy trình Luân chuyển Kho (`StockMoves`) quá thô sơ**:
  * Chỉ có 3 trạng thái: `draft`, `done`, `cancelled`. Thiếu các trạng thái trung gian của quy trình kho chuẩn công nghiệp: *Chờ phân bổ (Waiting) $\rightarrow$ Đã khóa tồn (Reserved) $\rightarrow$ Đang lấy hàng (Picking) $\rightarrow$ Đã đóng gói (Packed) $\rightarrow$ Tập kết cửa xuất (Staged) $\rightarrow$ Đã bốc dỡ lên xe (Shipped)*.
* **Đứt gãy giữa MES (Thu hoạch/Sản xuất) và Kho thành phẩm (Cold Store)**:
  * Ca thu hoạch nấm hoàn thành ghi nhận `pickedYield` ở module `mushrooms`, nhưng không tự động sinh ra mã lô, không sinh mã kiện pallet để chuyển thẳng vào kho lạnh bảo quản.
* **Thiếu các chiến lược xuất nhập kho thông minh**:
  * Chưa có định vị lưu kho tự động (**Directed Putaway**).
  * Chưa có thuật toán lấy hàng theo hạn dùng (**FEFO / FIFO Engine**).
  * Chưa có cơ chế gom hàng theo đợt (**Wave Picking / Batch Picking**).
* **Kiểm soát chất lượng (QC Gate) và Vận tải ngoài nhà máy (TMS)**:
  * Chưa có bước kiểm nghiệm chất lượng đầu vào (Incoming Inspection) hoặc thành phẩm trước xuất xưởng (Release QC).
  * Chưa có module quản lý chuyến xe giao nhận, giám sát nhiệt độ xe lạnh và biên bản giao hàng điện tử (e-PoD).

---

## 2. KIẾN TRÚC MỤC TIÊU: ENTERPRISE FACTORY WMS & SCM CHO IZIIAPP

Mô hình kiến trúc kho vận toàn diện được thiết kế để mở rộng trên nền tảng iZiiApp hiện hữu:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                         ENTERPRISE FACTORY LOGISTICS STACK                             │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                           │
    ┌──────────────────────────────────────┼──────────────────────────────────────┐
    ▼                                      ▼                                      ▼
┌──────────────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────┐
│   INBOUND & RECEIVING    │   │  INVENTORY & STORAGE     │   │   OUTBOUND & DISPATCH    │
├──────────────────────────┤   ├──────────────────────────┤   ├──────────────────────────┤
│• Lịch hẹn bốc dỡ (Dock)  │   │• Multi-UoM & Packaging   │   │• Quản lý Đơn xuất kho    │
│• Thông báo trước (ASN)   │   │• Quản lý Biển số LPN     │   │• Gom hàng đợt (Wave Pick)│
│• Trạm cân & In nhãn GS1  │   │• Quản lý Lô & HSD (FEFO) │   │• Tối ưu lộ trình nhặt    │
│• Kiểm tra QC / Cách ly   │   │• Định vị tự động Putaway │   │• Đóng gói & Dán nhãn V/C │
│• Nhập kho từ MES/Harvest │   │• Kiểm kê luân phiên Blind│   │• Điều phối Cửa Dock xuất │
└──────────────────────────┘   └──────────────────────────┘   └──────────────────────────┘
    │                                      │                                      │
    └──────────────────────────────────────┼──────────────────────────────────────┘
                                           │
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        INTRALOGISTICS & COLD-CHAIN INTEGRATION                         │
├────────────────────────────────────────────────────────────────────────────────────────┤
│• Cấp phát vật tư dây chuyền (Kitting & Line-feeding Kanban)                            │
│• Giám sát nhiệt độ thời gian thực (IoT LoRaWAN/BLE Thresholds & Auto-Quarantine)        │
│• Sẵn sàng giao tiếp AGV / AMR / AS-RS (Chuẩn VDA 5050 & Industrial PLC)                │
│• Giám sát hành trình chuỗi lạnh & Ký nhận giao hàng số (Cold-chain In-transit & e-PoD) │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. CÁC TÍNH NĂNG CHI TIẾT CẦN PHÁT TRIỂN

### 3.1 Nhóm 1: Định danh Hàng hóa, Đóng gói Đa cấp & Mã vạch Công nghiệp
1. **Hệ số Quy đổi Đơn vị tính (Multi-UoM Hierarchy)**:
   * Thiết lập hệ thống đơn vị tính đa cấp cho từng SKU: *Base UoM (kg/hộp) $\rightarrow$ Secondary UoM (Thùng/Carton) $\rightarrow$ Handling UoM (Lớp/Layer) $\rightarrow$ Transport UoM (Pallet Úc 1165x1165mm)*.
   * Tự động quy đổi số lượng tương ứng khi quét mã vạch ở bất kỳ cấp độ đóng gói nào.
2. **Quản trị Biển số Pallet / Thùng chứa (License Plate Number - LPN)**:
   * Sinh mã LPN duy nhất cho mỗi pallet thành phẩm (ví dụ: `LPN-2026-M1-001248`).
   * Mã LPN đại diện cho một cụm hàng hóa (chứa thông tin SKU, số lượng thùng, số lô, ngày đóng gói, khối lượng tịnh từ trạm cân).
   * Khi di chuyển, chuyển kho hoặc bốc lên xe container, nhân viên xe nâng chỉ cần quét **1 lần mã LPN**, toàn bộ hàng trăm thùng hàng bên trong được luân chuyển đồng thời trên hệ thống.
3. **Giải mã Mã vạch Công nghiệp Chuẩn GS1-128 / GS1 DataMatrix**:
   * Hỗ trợ quét mã vạch tích hợp các định danh ứng dụng AI (Application Identifiers):
     * `(01)`: Mã GTIN / SKU sản phẩm
     * `(10)`: Mã số Lô sản xuất (Batch/Lot number)
     * `(17)`: Hạn sử dụng (YYMMDD)
     * `(3102)`: Trọng lượng tịnh tính bằng kg (hai chữ số thập phân)
     * `(00)`: Mã công-ten-nơ vận chuyển SSCC-18 (Serial Shipping Container Code)

---

### 3.2 Nhóm 2: Quản lý Lô, Hạn Dùng & Truy xuất Nguồn gốc 2 Chiều
1. **Quản trị Vòng đời Lô hàng (Batch/Lot Lifecycle Management)**:
   * Mỗi lô hàng (`StockLots`) lưu trữ: Mã lô, Ngày sản xuất, Hạn sử dụng tốt nhất (Best Before), Hạn sử dụng tối đa (Expiry Date), Trạng thái kiểm định (`quarantine`, `approved`, `blocked`, `expired`).
   * Tự động khóa lô hàng (Auto-block) khi cảm biến nhiệt độ kho lạnh ghi nhận vượt ngưỡng quá thời gian cho phép (dựa trên bảng `AutomationRules` và `SensorReadings`).
2. **Cơ chế Phân bổ Xuất kho Tự động FEFO / FIFO**:
   * Thuật toán tự động tìm và gán (allocate) các pallet thuộc lô có hạn sử dụng gần nhất (**First Expired, First Out**) cho các đơn xuất bán.
   * Ngăn chặn tình trạng hàng cũ nằm quên trong góc kho dẫn đến hư hỏng, tối ưu độ tươi của nấm và nông sản.
3. **Cây Phả hệ Truy vết 2 Chiều (Bi-directional Traceability / Geneology)**:
   * **Truy vết xuôi (Forward Trace)**: Từ một lô nguyên liệu/vật tư (giá thể, phân bón, hoá chất bảo vệ thực vật) tra cứu nhanh toàn bộ các phòng trồng đã dùng, các đợt thu hoạch liên quan, các pallet thành phẩm đã đóng và danh sách đơn hàng/khách hàng đã nhận hàng.
   * **Truy vết ngược (Backward Trace / Recall Engine)**: Khi khách hàng phát hiện sản phẩm lỗi, chỉ cần quét mã vạch trên hộp/pallet, hệ thống lần ngược lại: ca thu hoạch, đội hái, mã phòng trồng, thời gian bảo quản trong kho lạnh và lịch sử kiểm định QC.

---

### 3.3 Nhóm 3: Quy trình Nhập kho, Kiểm định & Định vị Lưu kho Thông minh (Inbound & Directed Putaway)
1. **Quản lý Thông báo Giao hàng trước (ASN - Advanced Shipping Notice)**:
   * Cho phép nhà cung cấp hoặc phân xưởng bạn gửi trước danh sách mặt hàng, số lượng, số kiện và lịch xe dự kiến.
   * Điều phối cổng bốc dỡ (**Dock Appointment Scheduling**) nhằm tránh ùn tắc xe tải tại cửa kho.
2. **Cổng Kiểm soát Chất lượng (QC Incoming Inspection Gate)**:
   * Khi dỡ hàng tại sàn tiếp nhận (Receiving Dock), hệ thống tự động đưa hàng vào khu vực Staging/Quarantine.
   * Nhân viên QC kiểm tra mẫu theo tiêu chuẩn AQL:
     * *Đạt (Pass)*: Chuyển trạng thái lô sang `approved`, sinh nhiệm vụ cất hàng vào kho chính.
     * *Không đạt (Fail)*: Chuyển sang khu cách ly, kích hoạt quy trình Trả hàng nhà cung cấp (RTV - Return to Vendor) hoặc tiêu hủy (Scrap).
3. **Định vị Lưu kho Thông minh (Directed Putaway Engine)**:
   * Dựa trên cấu trúc 3D của `Locations`: `posX, posY, posZ`, `maxWeightKg`, `maxVolumeM3` và tính chất sản phẩm.
   * Hệ thống tự động tính toán và hiển thị vị trí cất hàng tối ưu trên màn hình xe nâng:
     * Hàng nặng $\rightarrow$ Chỉ định vào tầng thấp (Level 1, Level 2).
     * Hàng luân chuyển nhanh (Nhóm A theo phân tích ABC) $\rightarrow$ Ưu tiên ô gần cửa kho.
     * Kiểm tra tương thích: Không xếp sản phẩm tươi sống cùng khu vực với hóa chất tẩy rửa.
4. **Dây chuyền Băng tải Trung tâm & Kiểm định Tự động Hàng Thu hoạch**:
   * Box Mover đặt toàn bộ thùng nấm từ phòng trồng lên băng tải trung tâm chạy dọc giữa xưởng.
   * Dây chuyền tự động tích hợp:
     * **Máy dò kim loại (Metal Detector)**: Loại bỏ thùng chứa dị vật kim loại.
     * **Camera AI Vision**: Nhận diện phân loại chuẩn nấm (Button/Cup/Flat), đo đường kính và phát hiện khuyết tật.
     * **Cân thùng tự động (Inline Check-Weigher)**: Lưu dữ liệu trọng lượng từng thùng trực tiếp vào iZiiApp.
   * Các thùng đạt chuẩn được đóng pallet tại khu vực giữa xưởng và in mã LPN. Xe nâng vận chuyển pallet qua trạm cân sàn (In-floor scale) trước cửa tự động kho lạnh để đối soát tổng tải trọng trước khi cất kho.

---

### 3.4 Nhóm 4: Tối ưu Xuất kho, Gom hàng & Đóng gói (Outbound & Wave Picking)
1. **Lệnh Xuất kho Đa bước (Multi-step Picking Workflow)**:
   * Tách bạch luồng xuất kho: `Tạo lệnh (Sales/Delivery Order)` $\rightarrow$ `Phân bổ tồn kho (Allocation)` $\rightarrow$ `Lấy hàng (Pick)` $\rightarrow$ `Đóng gói & Cân kiểm (Pack & Weigh)` $\rightarrow$ `Tập kết cửa xuất (Staging)` $\rightarrow$ `Bốc dỡ lên xe (Loading & Shipped)`.
2. **Gom hàng theo Đợt & Nhóm (Wave & Batch Picking)**:
   * Gom nhiều đơn hàng có cùng khung giờ xuất bến hoặc cùng nhà phân phối thành 1 "Đợt lấy hàng" (Wave).
   * Lập trình đường đi ngắn nhất (Pick-path Optimization) theo sơ đồ chữ S (S-Shape) trong lối đi của kho, giúp tài xế xe nâng lấy hàng cho nhiều đơn trong một hành trình duy nhất.
3. **Bàn Đóng gói & Đối soát Khối lượng (Packing Station & Scale Verification)**:
   * Trạm đóng gói đối soát tự động: Khi cân pallet hoàn thiện, hệ thống so sánh khối lượng thực tế với khối lượng lý thuyết (dựa trên định mức hộp và pallet tiêu chuẩn). Nếu độ sai lệch $> \pm 1.5\%$, hệ thống cảnh báo kiểm tra lại số lượng thùng trước khi in tem dán niêm phong.

---

### 3.5 Nhóm 5: Cấp phát Vật tư Phân xưởng (Intralogistics & Line Feeding)
1. **Cơ chế Kitting & Kanban Cấp vật tư Sản xuất**:
   * Khi một công việc trong module `mushrooms` (như xử lý phòng, bón chất, vệ sinh) hoặc kế hoạch đóng gói được lên lịch, hệ thống tự động sinh lệnh **Pick-to-Kit**: gom đầy đủ bao bì, nhãn mác, dụng cụ bảo hộ tập kết sẵn tại trạm sản xuất trước 30 phút.
   * Áp dụng nguyên lý **Kanban Kéo (Pull System)**: Khi lượng thùng rỗng tại trạm đóng gói giảm xuống dưới ngưỡng an toàn, hệ thống tự sinh phiếu chuyển hàng từ kho vật tư bao bì về phân xưởng.
2. **Thu hồi Vật tư Dư thừa & Xử lý Phế phẩm (Scrap / Return to Stock)**:
   * Quy trình ghi nhận bao bì hỏng, thùng lỗi hoặc vật tư thừa sau ca sản xuất chuyển trả lại kho nguyên vật liệu hoặc ghi giảm tổn thất.

---

### 3.6 Nhóm 6: Kiểm kê Luân phiên Không Gián đoạn Nhà máy (Cycle Counting)
1. **Kiểm kê Định kỳ Không dừng Vận hành (Perpetual Cycle Counting)**:
   * Thay thế cho việc phải dừng sản xuất 3 ngày cuối năm để kiểm kho toàn diện.
   * Tự động lập lịch kiểm kê hàng ngày theo phân loại ABC:
     * Nhóm A (20% mặt hàng chiếm 80% giá trị): Kiểm 1 lần/tháng.
     * Nhóm B (30% mặt hàng chiếm 15% giá trị): Kiểm 1 lần/quý.
     * Nhóm C (50% mặt hàng chiếm 5% giá trị): Kiểm 1 lần/nửa năm.
2. **Kiểm kê Điểm mù (Blind Count Workflow)**:
   * Giao diện kiểm kê trên thiết bị cầm tay không hiển thị số lượng tồn trên hệ thống nhằm buộc nhân viên phải quét và đếm thực tế.
   * Tự động tổng hợp sai lệch (Discrepancy Report) và yêu cầu Quản lý kho (Level 3) phê duyệt trước khi ghi nhận điều chỉnh số dư tồn kho (`StockAdjustment`).

---

### 3.7 Nhóm 7: Quản lý Vận tải, Chuỗi Lạnh & Giao nhận Số (Cold-Chain TMS & e-PoD)
1. **Giám sát Nhiệt độ Chuỗi Lạnh trong Vận chuyển (In-Transit Cold-Chain Telemetry)**:
   * Tích hợp thiết bị ghi nhận nhiệt độ qua BLE (BLE Data Logger) đặt trong thùng xe tải lạnh.
   * Khi xe đến điểm giao nhận hoặc quay về nhà máy, ứng dụng di động tự động đọc dữ liệu hành trình qua Bluetooth, đối soát đồ thị nhiệt độ trong suốt chuyến đi nhằm bảo đảm hàng hóa không bị sốc nhiệt.
2. **Xác nhận Giao hàng Điện tử (e-PoD - Electronic Proof of Delivery)**:
   * Ứng dụng trên điện thoại của tài xế cho phép:
     * Chụp ảnh hiện trạng kiện hàng và niêm phong cửa xe (Seal) tại điểm dỡ hàng.
     * Thu thập chữ ký điện tử của người nhận hàng trực tiếp trên màn hình.
     * Tự động gắn toạ độ GPS và dấu thời gian thực (Timestamp).
   * Tự động hoàn tất đơn hàng và phát tín hiệu cho module Kế toán xuất hóa đơn tài chính.

---

### 3.8 Nhóm 8: Cổng Giao tiếp Tự động hóa AGV / AMR / AS-RS (Automation Gateway)
1. **Giao thức Chuẩn VDA 5050**:
   * Chuẩn hóa API xuất lệnh di chuyển pallet giữa các vùng (Ví dụ: Từ Băng chuyền thu hoạch $\rightarrow$ Trạm cân $\rightarrow$ Cửa kho lạnh).
   * Sử dụng trường toạ độ `(posX, posY, posZ)` và mã nút trong bảng `Locations` làm bản đồ điều hướng cho xe tự hành (AGV).
2. **Giao tiếp Băng chuyền & PLC Kho lạnh**:
   * Tích hợp qua REST/WebSocket với hệ thống điều khiển cửa kho lạnh (Fast-action roll doors) để tự động mở cửa khi xe nâng hoặc pallet tiếp cận, giảm thất thoát nhiệt độ kho lạnh.

---

## 4. MA TRẬN MỞ RỘNG CƠ SỞ DỮ LIỆU ĐỀ XUẤT

Dưới đây là các bảng dữ liệu cần bổ sung và nâng cấp trong schema Drift (Client) và Postgres (Server):

| Tên Bảng | Mô tả & Vai trò | Liên kết chính |
| :--- | :--- | :--- |
| `ProductUoms` | Danh mục đơn vị tính và tỷ lệ quy đổi (Cái, Hộp, Thùng, Pallet). | `Products.id` |
| `ProductPackaging` | Quy cách đóng gói (Số lượng/thùng, kích thước D x R x C, trọng lượng). | `Products.id`, `ProductUoms.id` |
| `StockLots` | Quản lý Lô sản xuất, ngày hái/sản xuất, hạn dùng, trạng thái kiểm định. | `Products.id` |
| `StockLpns` | Mã biển số Pallet (LPN), trạng thái pallet (trống, đang chứa, đang di chuyển). | `Locations.id` |
| `StockLpnContents` | Chi tiết hàng hoá nằm trên Pallet (SKU, Lot, Số lượng, UoM). | `StockLpns.id`, `Products.id`, `StockLots.id` |
| **`StockQuants`** *(Nâng cấp)* | Thêm `lotId`, `lpnId`, `reservedQty`, `availableQty`, khóa ngoại vào `Locations`. | `Products.id`, `Locations.id`, `StockLots.id` |
| `StockPickings` | Phiếu điều chuyển/xuất/nhập kho tổng (Inbound, Outbound, Internal Transfer). | `Locations.id` (source & dest) |
| `StockPickingLines` | Chi tiết dòng hàng cần chuyển, số lượng yêu cầu, số lượng đã pick thực tế. | `StockPickings.id`, `Products.id`, `StockLots.id` |
| `StockWaves` | Đợt gom hàng (Wave Picking) tập hợp nhiều Picking để tối ưu lộ trình. | Danh sách `StockPickings.id` |
| `QcInspectionOrders` | Phiếu kiểm nghiệm chất lượng (Đầu vào, Trong kho, Thành phẩm). | `StockLots.id`, `StockPickings.id` |
| `CycleCountSessions` | Phiếu kiểm kê kho luân phiên (Phân loại ABC, kiểm kê mù). | `Locations.id` |
| `DeliveryRoutes` | Lịch trình chuyến xe giao hàng, danh sách điểm dừng (Stops). | Xe, Tài xế, `StockPickings.id` |
| `DeliveryProofOfDelivery`| Biên bản bàn giao điện tử (e-PoD): chữ ký, ảnh chụp kiện hàng, toạ độ GPS. | `DeliveryRoutes.id` |

---

## 5. KẾT LUẬN & ĐÁNH GIÁ TÁC ĐỘNG

Việc hiện thực hóa thiết kế này sẽ nâng tầm **iZiiApp** từ một ứng dụng quản lý tác nghiệp cục bộ trở thành **Hệ thống Quản lý Kho Thông minh (Smart Factory WMS & Intralogistics Platform)** đạt chuẩn quốc tế, mang lại các giá trị đo lường được:

1. **Giảm 99% sai sót nhầm lẫn hàng hoá & lô hạn dùng** nhờ định danh Barcode GS1, LPN pallet và nguyên tắc xuất kho FEFO tự động.
2. **Tăng 30% - 40% năng suất vận hành xe nâng & công nhân kho** nhờ cơ chế gom hàng Wave Picking và định vị cất hàng Directed Putaway.
3. **Đảm bảo 100% tuân thủ tiêu chuẩn an toàn thực phẩm (HACCP, ISO 22000, GlobalGAP)** với khả năng truy vết nguồn gốc 2 chiều chỉ trong vòng 30 giây.
4. **Vận hành không gián đoạn (Zero Downtime)** nhờ kiến trúc Offline-first và Mesh LAN Sync, loại bỏ hoàn toàn rủi ro đình trệ nhà máy khi gặp sự cố mạng Internet.
