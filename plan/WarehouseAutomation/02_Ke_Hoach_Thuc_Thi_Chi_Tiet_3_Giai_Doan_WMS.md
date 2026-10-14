# KẾ HOẠCH THỰC THI CHI TIẾT 3 GIAI ĐOẠN HOÀN THIỆN IZIÍAPP WAREHOUSE
## Lộ trình Chuyển đổi iZiiApp thành Hệ thống WMS & Intralogistics Doanh nghiệp Công nghiệp

---

| Thông số | Chi tiết kế hoạch |
| :--- | :--- |
| **Dự án** | Nâng cấp Phân hệ Kho Thông minh iZiiApp (iZiiApp Industrial WMS) |
| **Mục tiêu** | Xây dựng hoàn chỉnh hệ thống Quản lý Kho, Chuỗi Cung ứng và Logistics Phân xưởng tiêu chuẩn công nghiệp, hoạt động hoàn hảo trên nền tảng Offline-First |
| **Địa bàn thử nghiệm chuẩn** | Nhà máy Costa Mushroom (Plant M1 & M2, sản lượng 60 tấn/ngày) |
| **Tổng thời gian dự kiến** | 18 tuần (3 Giai đoạn, 9 Sprint × 2 tuần/Sprint) |
| **Vị trí lưu trữ tài liệu** | `plan/WarehouseAutomation/02_Ke_Hoach_Thuc_Thi_Chi_Tiet_3_Giai_Doan_WMS.md` |

---

## 1. TỔNG QUAN LỘ TRÌNH 3 GIAI ĐOẠN (EXECUTIVE ROADMAP)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              ROADMAP TỔNG THỂ 18 TUẦN                                  │
└────────────────────────────────────────────────────────────────────────────────────────┘

 [ Tuần 1 - 6 ]      GIAI ĐOẠN 1: NỀN TẢNG WMS CỐT LÕI & SỐ HÓA ĐÓNG GÓI
 ────────────────    • Chuẩn hóa dữ liệu: Cây Vị trí (Locations), Đơn vị tính (Multi-UoM).
                     • Quản lý Biển số Pallet (LPN) & Quản lý Lô/Hạn sử dụng (StockLots).
                     • Màn hình trạm cân đóng Pallet & Quét mã vạch công nghiệp cầm tay/xe nâng.
                     • Tái cấu trúc cơ chế Tồn kho (StockQuants) & Điều chuyển (StockPickings).

 [ Tuần 7 - 12 ]     GIAI ĐOẠN 2: LOGISTICS PHÂN XƯỞNG, ĐỊNH VỊ PUTAWAY, FEFO & KIỂM KÊ
 ────────────────    • Khép kín luồng Thu hoạch/MES sang Kho lạnh (Harvest-to-ColdStore).
                     • Thuật toán Gợi ý vị trí cất hàng tối ưu 3D (Directed Putaway Engine).
                     • Thuật toán Phân bổ hàng xuất kho theo hạn dùng (Auto FEFO / FIFO).
                     • Cổng kiểm soát chất lượng (QC Incoming & Harvest Release Gate).
                     • Kiểm kê luân phiên không dừng nhà máy (Perpetual Blind Cycle Count).

 [ Tuần 13 - 18 ]    GIAI ĐOẠN 3: GOM HÀNG WAVE PICK, GIÁM SÁT CHUỖI LẠNH & GIAO VẬN SỐ
 ────────────────    • Gom hàng đợt và gom nhóm xuất xưởng (Wave & Batch Picking Engine).
                     • Bàn đóng gói & Kiểm tra chênh lệch trọng lượng (Packing Verification).
                     • Giám sát nhiệt độ thùng xe lạnh qua Bluetooth (Cold-chain In-transit).
                     • Xác nhận giao hàng điện tử chữ ký & GPS (e-PoD Mobile Screen).
                     • Cổng kết nối điều khiển tự động hóa xe tự hành AGV/AMR (Chuẩn VDA 5050).
```

---

## 2. GIAI ĐOẠN 1: NỀN TẢNG WMS CỐT LÕI & SỐ HÓA ĐÓNG GÓI (TUẦN 1 – 6)

### 2.1 Mục tiêu Trọng tâm (Key Objectives)
* Xóa bỏ hoàn toàn định danh kho dạng chuỗi tự do, gắn kết trực tiếp dữ liệu tồn kho với Cây vị trí phân cấp (`Locations`).
* Xây dựng cấu trúc đóng gói đa cấp (**Multi-UoM**) và định danh biển số kiện hàng (**LPN - License Plate Number**).
* Hỗ trợ quản lý **Số Lô (Lot/Batch)**, Hạn sử dụng, và chuẩn hóa giải mã mã vạch công nghiệp **GS1-128 / GS1 DataMatrix**.
* Cung cấp giao diện quét mã vạch tốc độ cao trên thiết bị di động và máy tính bảng xe nâng (Forklift Terminals).

### 2.2 Chi tiết Công việc theo Sprint

#### Sprint 1 (Tuần 1 - 2): Tái cấu trúc Cơ sở Dữ liệu & Tầng Dữ liệu (Drift & Server Schema)
* **Backend & Database Migration**:
  1. Tạo file migration server `server/migrations/versions/0010_industrial_wms_foundation.sql`:
     * Bảng `product_uoms`: Cấu hình đơn vị cơ sở và tỷ lệ quy đổi (`ratio_to_base`).
     * Bảng `product_packagings`: Định nghĩa quy cách đóng gói (Kích thước D x R x C, trọng lượng bì, số lượng thùng/lớp, số thùng/pallet).
     * Bảng `stock_lots`: Quản lý mã lô, ngày sản xuất, hạn sử dụng (`expiry_date`), ngày mở lô, trạng thái kiểm định (`quarantine`, `approved`, `blocked`).
     * Bảng `stock_lpns`: Quản lý mã pallet, vị trí hiện tại (`location_id`), tổng khối lượng (`gross_weight_kg`), trạng thái (`staged`, `stored`, `in_transit`, `shipped`).
     * Bảng `stock_lpn_contents`: Chi tiết các mặt hàng và số lô nằm trên LPN.
  2. Cập nhật bảng `stock_quants`:
     * Thêm khóa ngoại `location_id` trỏ vào `locations(id)`.
     * Thêm `lot_id`, `lpn_id`, `reserved_qty`, `available_qty`.
     * Ràng buộc Unique Composite: `UNIQUE(product_id, location_id, lot_id, lpn_id)`.
  3. Cập nhật Drift Tables trên Client Flutter (`lib/modules/supply_chain/database/tables.dart`):
     * Đồng bộ toàn bộ các bảng trên sang Drift.
     * Chạy lệnh tạo code: `dart run build_runner build --delete-conflicting-outputs`.
* **Outbox Sync Engine Compatibility**:
  * Đăng ký các bảng mới vào danh sách đồng bộ ngoại tuyến (`sync_mutations`).

#### Sprint 2 (Tuần 3 - 4): Quản lý Biển số LPN & Trạm Đóng Pallet (Scale Station)
* **Service & Repositories**:
  1. Xây dựng `LpnService` (`lib/modules/supply_chain/services/lpn_service.dart`):
     * Hàm sinh mã LPN chuẩn hóa theo tiền tố xưởng và năm: `generateLpnCode(zone, plant)`.
     * Hàm tạo Pallet mới (`createPalletWithLines`).
     * Hàm gộp/tách pallet (Split/Merge LPN).
  2. Xây dựng `UomConverter` (`lib/core/utils/uom_converter.dart`):
     * Tính toán tự động số lượng quy đổi giữa Thùng $\leftrightarrow$ Pallet $\leftrightarrow$ Kg.
* **Giao diện Ứng dụng (UI/UX)**:
  1. Xây dựng màn hình **Trạm Cân & Đóng Pallet Thành phẩm** (`PalletScaleStationScreen`):
     * Giao diện màn hình lớn tối ưu cho máy tính bảng cảm ứng tại bàn đóng gói.
     * Chọn nhanh Loại nấm (Button / Cup / Flat), kích thước thùng (Box Type 1 / Type 2).
     * Kết nối cổng Serial/Bluetooth với Cân điện tử bàn (Electronic Weighing Scale) để tự động nhảy số kg thực tế.
     * Nút **"Hoàn tất & In Nhãn LPN"**: Tạo bản ghi LPN, gán vào vị trí `Staging Khu đóng gói`, và xuất lệnh in tem nhãn nhiệt (Zebra/TSC qua Wi-Fi/Bluetooth ESC/POS).

#### Sprint 3 (Tuần 5 - 6): Giao diện Quét Barcode Xe nâng & Luân chuyển Hàng
* **Bộ thư viện Giải mã GS1**:
  * Xây dựng Parser giải mã chuỗi mã vạch GS1-128 / DataMatrix: Phân tách tự động `(01)` GTIN, `(10)` Lot, `(17)` Expiry, `(3102)` Trọng lượng.
* **Giao diện Vận hành Xe nâng (Forklift Driver Screen)**:
  * Giao diện với nút bấm kích thước lớn, tương phản cao (phù hợp môi trường kho lạnh hơi nước mờ).
  * Quy trình thao tác 3 bước đơn giản:
    1. Quét mã **LPN Pallet** (Hệ thống đọc ra thông tin hàng, vị trí hiện tại).
    2. Quét mã **Vị trí đích** (Ô kệ cất hàng hoặc Cửa kho lạnh).
    3. Nhấn **Xác nhận di chuyển**: Tự động sinh `StockMoves` và cập nhật `StockQuants` trong một transaction SQLite nội bộ và đẩy vào Outbox Queue để sync server.
* **Kiểm thử Giai đoạn 1**:
  * Unit test cho logic tính quy đổi UoM và Transaction luân chuyển LPN.
  * Giả lập mất mạng hoàn toàn và thực hiện quét 100 pallet liên tục, sau đó bật mạng kiểm tra đối soát dữ liệu trên Postgres server.

---

## 3. GIAI ĐOẠN 2: LOGISTICS PHÂN XƯỞNG, ĐỊNH VỊ PUTAWAY, FEFO & KIỂM KÊ (TUẦN 7 – 12)

### 3.1 Mục tiêu Trọng tâm (Key Objectives)
* Xóa nhòa ranh giới giữa Phân xưởng Thu hoạch (MES) và Kho bảo quản (Warehouse).
* Tự động hóa hoàn toàn quy tắc xếp kho thông minh (**Directed Putaway**) dựa trên dung tích ô và sức chứa.
* Tự động hóa phân bổ hàng xuất theo nguyên tắc hạn sử dụng trước xuất trước (**FEFO Engine**).
* Tích hợp cổng kiểm tra chất lượng (QC Gate) và quy trình kiểm kê luân phiên không dừng hoạt động nhà máy (**Cycle Counting**).

### 3.2 Chi tiết Công việc theo Sprint

#### Sprint 4 (Tuần 7 - 8): Tích hợp MES Thu hoạch vào Kho Lạnh (Harvest-to-ColdStore Integration)
* **Khép kín quy trình Vận hành**:
  1. Khi một ca thu hoạch trong `lib/modules/mushrooms` hoàn tất:
     * Dữ liệu từ `MushroomHarvestPlans` và `MushroomRoomAssignments` cung cấp chi tiết số thùng nấm thu được theo từng phòng.
     * Hệ thống tự động kích hoạt tiến trình tạo lệnh nhập kho thành phẩm (`StockPickings` với type = `incoming_harvest`).
  2. Sinh mã Lô sản xuất (`StockLots`):
     * Quy tắc sinh mã tự động: `LOT-[Ngày Thu Hoạch]-[Mã Phòng]-[Chủng Loại Nấm]`.
     * Tự động tính toán ngày Best Before (+5 ngày) và Expiry Date (+7 ngày) dựa trên cấu hình bảo quản nhiệt độ lạnh $2^\circ\text{C} - 4^\circ\text{C}$.
  3. Luồng Vận chuyển Nội bộ & Dây chuyền Xử lý Trung tâm (Central Packhouse Inbound Line):
     * **Điều phối Box Mover**: Đội chuyển hàng (Box Mover) thu gom các thùng nấm (Boxes) từ cửa hành lang phòng trồng và đặt toàn bộ thùng lên hệ thống băng tải trung tâm nằm ở giữa xưởng.
     * **Trạm Kiểm tra & Thu thập Dữ liệu Tự động (Inline Inspection & Logging)**:
       - **Máy Dò Kim Loại (Inline Metal Detector)**: Kiểm soát dị vật an toàn thực phẩm; thùng phát hiện dị vật bị đẩy sang nhánh xả lỗi (Reject lane).
       - **Hệ thống Thị giác Máy (Vision Camera AI Inspection)**: Tự động chụp ảnh bề mặt thùng, nhận diện và đối soát phân loại chủng loại nấm (Button / Cup / Flat), đường kính mũ nấm và phát hiện các khuyết tật vỏ nấm.
       - **Trạm Cân Thùng Tự động (Inline Check-Weigher)**: Đo chính xác khối lượng từng thùng nấm khi lướt qua băng tải và tự động ghi nhận dữ liệu trọng lượng vào phần mềm quản lý iZiiApp theo thời gian thực (Real-time telemetry).
     * **Khu vực Đóng Pallet Trung tâm (Central Palletizing Area)**:
       - Các thùng đạt tiêu chuẩn sau khi qua cân được nhân viên/robot xếp gọn gàng lên Pallet tiêu chuẩn (Pallet Úc 1165 × 1165 mm) tại khu vực đóng gói ở giữa xưởng.
       - Gắn và in mã định danh Biển số Pallet (LPN Barcode) đại diện cho toàn bộ kiện hàng.
     * **Vận chuyển Xe nâng & Cân Pallet Cửa Kho Tự động**:
       - Xe nâng (Forklift) lấy kiện Pallet hoàn chỉnh di chuyển đến Cửa tự động kho lạnh (High-speed roll door).
       - **Trạm Cân Pallet Sàn (In-floor Weighbridge)**: Hệ thống tự động cân toàn bộ tải trọng Pallet trước cửa để đối chiếu tổng trọng lượng với tổng các thùng con đã ghi nhận trên băng tải.
       - Cửa tự động mở cho xe nâng đưa pallet vào vị trí lưu kho lạnh bảo quản (Cold Store).

#### Sprint 5 (Tuần 9 - 10): Định vị Cất hàng 3D & Phân bổ Xuất kho FEFO
* **Thuật toán Định vị Cất hàng (Directed Putaway Algorithm)**:
  1. Khi xe nâng quét mã LPN tại cửa kho lạnh, hệ thống gọi hàm `calculateOptimalPutawayLocation(lpnId)`:
     * Lọc danh sách ô kệ `Locations` có `isStorable = true` và `status = 'active'`.
     * Kiểm tra sức chứa: `current_weight + pallet_weight <= maxWeightKg` và `current_volume + pallet_volume <= maxVolumeM3`.
     * Tiêu chí tối ưu:
       * Ưu tiên cùng loại hàng (gộp cùng SKU / cùng Lô vào dãy kệ liền kề).
       * Trọng lượng nặng xếp tầng 1 (mặt đất), nhẹ xếp tầng cao.
       * Hàng luân chuyển nhanh (Fast-moving) xếp gần lối đi chính (Dựa trên depth và tọa độ `posY` gần cửa).
  2. Màn hình xe nâng hiển thị mũi tên chỉ dẫn và mã ô kệ mục tiêu (Ví dụ: `Ô ĐỀ XUẤT: WH1-COLD-A02-R01-L1`).
* **Thuật toán Phân bổ Xuất kho Tự động FEFO**:
  * Khi tạo đơn xuất kho, hệ thống chạy `allocateStockFefo(productId, requestedQty)`:
    * Truy vấn các `StockQuants` có `lot.status = 'approved'` và `available_qty > 0`.
    * Sắp xếp ưu tiên: `ORDER BY stock_lots.expiry_date ASC, stock_quants.quantity ASC`.
    * Khóa số lượng giữ chỗ (`reserved_qty += pick_qty`, `available_qty -= pick_qty`) để ngăn đơn hàng khác nhặt trùng.

#### Sprint 6 (Tuần 11 - 12): Cổng Kiểm soát Chất lượng (QC Gate) & Kiểm kê Luân phiên (Cycle Count)
* **Cổng Kiểm định Chất lượng (QC Gate Engine)**:
  * Khi hàng mới nhập (Vật tư bao bì từ NCC hoặc Nấm mới hái về kho), trạng thái mặc định của Lô là `quarantine`.
  * Xây dựng màn hình **QC Inspection Screen**:
    * Bộ tiêu chuẩn kiểm tra nhanh: Nhiệt độ lõi sản phẩm, độ ẩm bề mặt, màu sắc, tình trạng côn trùng/dị vật, độ sạch của thùng đựng.
    * Đạt yêu cầu $\rightarrow$ Nhấn **"Phê duyệt (Approve)"**: Chuyển trạng thái lô sang `approved`, tự động mở khóa cho phép thuật toán FEFO phân bổ xuất bán.
    * Vi phạm tiêu chuẩn $\rightarrow$ Nhấn **"Cách ly / Chặn (Block)"**: Khóa cứng lô hàng, sinh cảnh báo đỏ gửi quản lý xưởng.
* **Quy trình Kiểm kê Luân phiên Không dừng Nhà máy (Perpetual Cycle Counting)**:
  1. Bảng `cycle_count_sessions` và `cycle_count_lines`:
     * Cho phép tạo đợt kiểm kê theo từng Zone/Dãy kệ (Aisle) độc lập mà không cần đóng cửa toàn bộ kho.
  2. Chế độ Kiểm kê Mù (Blind Counting):
     * Nhân viên kiểm kê quét vị trí kệ, sau đó quét từng mã LPN/thùng và nhập số lượng đếm được.
     * Màn hình hoàn toàn KHÔNG hiển thị số dư tồn trên sổ sách để tránh hiện tượng nhân viên "nhìn số ghi lại".
  3. Báo cáo Sai lệch & Cân đối Kho (Discrepancy & Adjustment):
     * Tổng hợp danh sách chênh lệch (Thừa / Thiếu).
     * Chỉ người có quyền Level 3 (Warehouse Manager) mới được nhấn nút **"Duyệt Cân Đối Tồn Kho"**, tự động sinh `StockAdjustmentMove` để chỉnh số liệu về đúng thực tế.

---

## 4. GIAI ĐOẠN 3: GOM HÀNG WAVE PICK, GIÁM SÁT CHUỖI LẠNH & GIAO VẬN SỐ (TUẦN 13 – 18)

### 4.1 Mục tiêu Trọng tâm (Key Objectives)
* Tối ưu hóa năng suất xuất kho thông qua chiến lược gom hàng theo đợt (**Wave Picking**).
* Kiểm soát chặt chẽ quy trình đóng thùng, niêm phong và đối soát trọng lượng thành phẩm.
* Quản lý hành trình xe tải, tích hợp đo nhiệt độ chuỗi lạnh qua Bluetooth và xác nhận giao nhận điện tử (**e-PoD**).
* Mở cổng chuẩn hóa điều khiển thiết bị tự động hóa (AGV / AMR / Băng tải / Cửa kho lạnh).

### 4.2 Chi tiết Công việc theo Sprint

#### Sprint 7 (Tuần 13 - 14): Gom hàng theo Đợt (Wave Picking) & Trạm Đóng gói Đối soát
* **Engine Gom hàng Đợt (Wave Picking)**:
  1. Gom nhiều đơn đặt hàng (Sales Orders / Delivery Orders) có cùng tuyến vận chuyển hoặc cùng khung giờ xuất bến thành 1 `StockWave`.
  2. Bộ tối ưu đường đi lấy hàng (Pick-path Optimizer):
     * Sắp xếp thứ tự các điểm lấy hàng theo hình chữ S (S-shape traversal) trong lối đi nhà kho dựa trên chuỗi `Locations.path`.
     * Giúp tài xế xe nâng chỉ cần chạy 1 vòng qua kho là lấy đủ toàn bộ số lượng pallet/thùng cho toàn bộ đợt xuất hàng.
* **Bàn Đóng gói & Đối soát Khối lượng (Packing Verification Station)**:
  * Đặt trạm cân tại khu vực Staging cửa xuất kho.
  * Khi quét mã kiện hàng/pallet trước khi đưa lên xe, hệ thống cân tự động đọc khối lượng thực tế và đối chiếu khối lượng lý thuyết (Định mức vỏ thùng + Pallet gỗ + Khối lượng tịnh hàng hóa).
  * Nếu sai lệch vượt ngưỡng cho phép ($\pm 1.5\%$), hệ thống phát chuông cảnh báo và chặn không cho in phiếu vận đơn (Outbound Manifest) để nhân viên mở thùng kiểm đếm lại.

#### Sprint 8 (Tuần 15 - 16): Giám sát Chuỗi Lạnh Hành trình & Xác nhận Giao hàng Điện tử (e-PoD)
* **Giám sát Chuỗi Lạnh Xe Lạnh Vận chuyển (In-Transit Cold-Chain Telemetry)**:
  1. Sử dụng cảm biến nhiệt độ Bluetooth (BLE Temperature Data Logger) gắn cố định trong thùng xe tải bảo ôn.
  2. Ứng dụng di động của tài xế (`DriverMobileApp` tích hợp trong iZiiApp):
     * Tự động quét và kết nối với cảm biến qua BLE chạy ngầm (`ble_sync_manager`).
     * Cảnh báo âm thanh tức thì trên cabin xe nếu nhiệt độ thùng lạnh vượt quá ngưỡng tối đa cho phép ($> 5^\circ\text{C}$).
     * Khi xe đến kho nhận của khách hàng, ứng dụng tự động tải dữ liệu lịch sử đo nhiệt độ từng 5 phút trong suốt hành trình và đóng dấu vào báo cáo chất lượng chuyến đi.
* **Biên bản Giao nhận Điện tử (e-PoD - Electronic Proof of Delivery)**:
  * Màn hình giao hàng cho tài xế:
    1. Hiển thị danh sách kiện hàng cần giao theo điểm dừng (Delivery Stop).
    2. Chụp ảnh hiện trạng kiện hàng và tem niêm phong chì niêm xe tải lúc mở cửa.
    3. Cho đại diện khách hàng ký tên xác nhận trực tiếp bằng ngón tay/bút cảm ứng trên màn hình điện thoại.
    4. Ứng dụng tự động gắn thẻ định vị toạ độ GPS và tem thời gian chống gian lận.
    5. Cập nhật trạng thái đơn hàng thành `Delivered`, kích hoạt đồng bộ về máy chủ trung tâm để đối soát công nợ.

#### Sprint 9 (Tuần 17 - 18): Cổng Giao tiếp Tự động hóa AGV/AMR (VDA 5050) & Chốt Đóng gói Hệ thống
* **Chuẩn hóa Giao diện AGV / Robot Tự hành (VDA 5050 Gateway)**:
  1. Xây dựng router FastAPI trung gian `server/routers/agv_gateway.py`:
     * Đọc các lệnh di chuyển pallet `StockMoves` có `transport_type = 'agv'`.
     * Đóng gói lệnh thành gói tin chuẩn MQTT/WebSocket theo giao thức VDA 5050:
       * `orderId`: UUID của bước chuyển kho.
       * `nodes`: Tọa độ điểm đón (Pickup) và điểm trả (Dropoff) trích xuất từ `Locations.posX, posY, posZ`.
     * Nhận phản hồi trạng thái từ xe AGV (`executing`, `succeeded`, `failed`) để tự động hoàn thành phiếu kho.
* **Tích hợp Cảm biến Đóng/Mở Cửa Kho Lạnh**:
  * Tận dụng `AutomationRules` trong `warehouse_automation`: Khi xe nâng hoặc pallet tiến vào vùng cảm biến radar trước cửa kho lạnh, hệ thống gửi lệnh qua rơ-le kích hoạt mở cửa nhanh (Fast-action door) và tự động đóng sau 15 giây, triệt tiêu thất thoát nhiệt.
* **Tổng duyệt Nghiệm thu (E2E Factory Integration Testing)**:
  * Thực nghiệm toàn chu trình thực tế tại nhà máy:
    * *Thu hoạch nấm $\rightarrow$ Đóng pallet tại Trạm cân $\rightarrow$ Xe nâng cất vào Kho lạnh $\rightarrow$ Quét FEFO xuất hàng $\rightarrow$ Bốc lên xe tải lạnh $\rightarrow$ Giao hàng e-PoD*.
  * Đánh giá hiệu năng xử lý đồng bộ khi có 50 thiết bị cùng hoạt động ngoại tuyến.

---

## 5. MA TRẬN NHIỆM VỤ, PHÂN CÔNG & ĐÁNH GIÁ KẾT QUẢ

### 5.1 Bảng Phân công & Sản phẩm Bàn giao (Deliverables Matrix)

| Giai đoạn | Tuần | Nhóm Chức năng Chính | Sản phẩm Kỹ thuật Cụ thể (Deliverables) | Tiêu chí Hoàn thành (Definition of Done) |
| :--- | :--- | :--- | :--- | :--- |
| **P1** | T1 - 2 | Core WMS Schema & Multi-UoM | Migration `0010_industrial_wms_foundation.sql`, Drift Tables `ProductUoms`, `StockLots`, `StockLpns`. | Build runner client không lỗi; migrate server thành công; outbox sync thông suốt. |
| **P1** | T3 - 4 | Pallet Scale Station & LPN | `PalletScaleStationScreen`, `LpnService`, `UomConverter`, Driver máy in nhiệt Bluetooth/Wi-Fi. | Đóng pallet, nhảy cân thực tế, in tem LPN mã vạch GS1 trong dưới 3 giây. |
| **P1** | T5 - 6 | Forklift Screen & GS1 Scan | Màn hình xe nâng `ForkliftScanScreen`, Bộ phân tích cú pháp mã vạch GS1-128 Parser. | Quét mã LPN + vị trí đích hoàn thành điều chuyển kho trong 1 chạm; hoạt động offline 100%. |
| **P2** | T7 - 8 | MES Harvest $\rightarrow$ Central Conveyor $\rightarrow$ Cold Store | Service liên kết `MushroomHarvestPlan` với `StockPickings`, Tự động sinh `StockLots`, Driver kết nối dữ liệu Băng tải (Máy dò kim loại, Camera Vision AI, Cân thùng tự động, Cân sàn Pallet trước cửa tự động). | Đóng ca thu hoạch nấm tự động ghi nhận dữ liệu thùng qua băng tải, sinh Lô/Pallet LPN, cân pallet trước cửa tự động vào kho lạnh. |
| **P2** | T9 - 10 | Directed Putaway & Auto FEFO | Thuật toán `DirectedPutawayEngine`, Thuật toán `FefoAllocationEngine`. | Gợi ý chính xác ô cất theo tải trọng/thể tích; đơn xuất bán tự động chọn đúng lô có HSD gần nhất. |
| **P2** | T11 - 12| QC Gate & Blind Cycle Count | Màn hình `QcInspectionScreen`, Quy trình `BlindCycleCountScreen`, Báo cáo cân đối kho. | Lô mới nhập bị khóa cách ly cho đến khi QC duyệt; kiểm kê mù không lộ tồn kho sổ sách. |
| **P3** | T13 - 14| Wave Picking & Weight Check | Bộ tạo đợt xuất hàng `WavePickingBloc`, Trạm kiểm tra khối lượng thùng/pallet xuất. | Gom 20 đơn xuất vào 1 lộ trình nhặt hàng ngắn nhất; cảnh báo sai lệch trọng lượng quá 1.5%. |
| **P3** | T15 - 16| Cold-chain Telemetry & e-PoD | Module đọc cảm biến BLE xe lạnh, Màn hình tài xế `DriverPodScreen` có chữ ký và GPS. | Cảnh báo khi nhiệt độ thùng xe $> 5^\circ\text{C}$; giao hàng thành công sinh e-PoD đồng bộ tức thì. |
| **P3** | T17 - 18| VDA 5050 AGV & E2E Validation| API Router `agv_gateway.py`, Tích hợp đóng mở cửa kho lạnh, Báo cáo nghiệm thu nhà máy. | Xuất lệnh điều phối cho AGV chạy thử thành công; nghiệm thu toàn chu trình từ thu hoạch đến xuất xưởng. |

---

## 6. PHÂN TÍCH RỦI RO & PHƯƠNG ÁN GIẢM THIỂU (RISK MANAGEMENT)

| STT | Rủi ro Tiềm ẩn | Mức độ | Hậu quả Vận hành | Giải pháp Giảm thiểu (Mitigation Strategy) |
| :---: | :--- | :---: | :--- | :--- |
| **1** | Môi trường kho lạnh âm sâu / ẩm ướt làm mờ camera quét mã vạch điện thoại. | **Cao** | Công nhân không quét được hàng, làm tắc nghẽn khâu nhập xuất. | Tích hợp máy quét mã vạch chuyên dụng công nghiệp (Zebra/Honeywell Rugged Scanner) kết nối Bluetooth qua chuẩn SPP/HID với ứng dụng iZiiApp; tối ưu mã in cỡ lớn chuẩn GS1 DataMatrix có độ tương phản cao. |
| **2** | Xung đột đồng bộ khi nhiều xe nâng cùng cất hàng vào 1 ô trống khi mất mạng (Conflict Write). | **Trung bình** | Hai xe nâng cùng xếp 2 pallet vào cùng 1 ô đơn, gây quá tải kệ. | Áp dụng cơ chế Khóa mềm ô tạm thời (Soft-lock slot) tại máy chủ LAN cục bộ, đồng thời hiển thị cảnh báo trên màn hình xe nâng thứ hai yêu cầu quét chọn ô kế cận nếu phát hiện ô vừa bị chiếm. |
| **3** | Công nhân phân xưởng thao tác sai quy trình đóng pallet gây sai lệch số lượng. | **Trung bình** | Số lượng thực tế khác số lượng ghi nhận trên LPN. | Bắt buộc kiểm tra đối soát 2 lớp: Quét đếm số thùng khi xếp lên pallet kết hợp kiểm tra tổng trọng lượng trên trạm cân điện tử bàn trước khi cho phép in tem LPN. |
| **4** | Cảm biến BLE trên xe tải lạnh bị hết pin hoặc hỏng hóc giữa đường vận chuyển. | **Thấp** | Mất dữ liệu theo dõi nhiệt độ chuyến đi. | Sử dụng cảm biến công nghiệp có tuổi thọ pin trên 2 năm, cấu hình kiểm tra trạng thái pin (`batteryLevel`) trước mỗi lần xe xuất phát khỏi cổng nhà máy. |

---

## 7. KẾT LUẬN & BƯỚC HÀNH ĐỘNG TIẾP THEO

Bản kế hoạch 18 tuần này được thiết kế theo nguyên tắc **tiến hóa từng bước (Evolutionary Architecture)**, kế thừa 100% nền tảng công nghệ sẵn có của iZiiApp (Drift, FastAPI, Offline Sync, IoT Automation) mà **không làm gián đoạn hay đập bỏ** bất kỳ chức năng vận hành nào đang chạy tại các phân xưởng hiện hữu.

Ngay sau khi kế hoạch được phê duyệt, đội ngũ phát triển có thể tiến hành ngay **Sprint 1** bằng việc tạo migration `0010_industrial_wms_foundation.sql` và khai báo cấu trúc bảng `Multi-UoM`, `StockLots`, `StockLpns` trên Drift để đặt nền móng vững chắc cho toàn bộ hệ thống.
