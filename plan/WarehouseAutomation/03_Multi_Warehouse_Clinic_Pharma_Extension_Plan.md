# KẾ HOẠCH MỞ RỘNG MULTI-WAREHOUSE & CHUYÊN BIỆT CHO CLINIC & PHARMA
## Tài liệu Thiết kế Kiến trúc & Lộ trình Tích hợp Đa Kho & Y Dược vào iZiiApp WMS

---

| Thông số | Chi tiết |
| :--- | :--- |
| **Hệ thống** | iZiiApp Enterprise Modular Platform |
| **Phân hệ mở rộng** | Multi-Warehouse Management & Clinic/Pharma GSP Extension |
| **Tiêu chuẩn tuân thủ** | GSP (Good Storage Practice), GDP (Good Distribution Practice), 21 CFR Part 11, GS1 Healthcare |
| **Tài liệu tham chiếu** | `01_Phan_Tich_Thiet_Ke_...`, `02_Ke_Hoach_Thuc_Thi_...` |
| **Vị trí lưu trữ** | `plan/WarehouseAutomation/03_Multi_Warehouse_Clinic_Pharma_Extension_Plan.md` |

---

## 1. PHÂN HỆ QUẢN TRỊ ĐA KHO (MULTI-WAREHOUSE ARCHITECTURE)

### 1.1 Cấu trúc Không gian & Cây Vị trí Đa Điểm (Multi-Site Topology)
Hệ thống sử dụng cơ chế **Cây Vị trí Phân cấp kép** (`Locations`: Adjacency List + Materialized Path) để mô hình hóa toàn bộ chuỗi cung ứng phân tán mà không bị giới hạn số lượng kho.

```
                           [MÁY CHỦ TRUNG TÂM / CLOUD]
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            ▼                                                     ▼
    [NHÀ MÁY / KHO TỔNG M1]                               [NHÀ MÁY / KHO TỔNG M2]
    (Zone: "plant_m1")                                    (Zone: "plant_m2")
    Path: /WH1                                            Path: /WH2
    ├── /WH1/COLD (Kho Lạnh Thành Phẩm)                   ├── /WH2/MAIN (Kho Chính)
    ├── /WH1/DRY  (Kho Khô & Bao Bì)                      └── /WH2/STAG (Khu Chuyển Tiếp)
    └── /WH1/RAW  (Kho Giá Thể / Hóa Chất)
            │                                                     ▲
            └─────────────── [LỆNH ĐIỀU CHUYỂN LIÊN KHO] ─────────┘
                             Vị trí Ảo: /TRANSIT/TRUCK-01
```

* **Nút Gốc (Root Sites)**: Mỗi cơ sở, nhà máy, hoặc chi nhánh được khai báo là một nút gốc với `parentId = NULL` và `depth = 0` (Ví dụ: `/WH1`, `/WH2`, `/CENTRAL-HUB`, `/CLINIC-HANOI`).
* **Truy vấn Độc lập theo Chi nhánh**:
  * Tồn kho Kho 1: `WHERE path LIKE '/WH1/%'`.
  * Tồn kho Tổng công ty: `SELECT SUM(quantity) GROUP BY SUBSTRING(path, 1, 4)`.
* **Vị trí Ảo trên đường Vận chuyển (Virtual In-Transit Locations)**:
  * Khi xuất hàng từ Kho A sang Kho B, hàng hóa được chuyển vào vị trí ảo `/TRANSIT/VEHICLE-XX`.
  * *Ý nghĩa tài chính*: Tồn kho tại Kho A giảm xuống, nhưng tổng tài sản của doanh nghiệp không bị hao hụt; rủi ro thất thoát trong quá trình tài xế vận chuyển được kiểm soát 100%.

### 1.2 Luồng Luân chuyển Hàng Liên Kho (Inter-Warehouse Transfer Workflow)
1. **Lập Lệnh Yêu cầu Điều chuyển (Transfer Request)**: Kho nhận tạo yêu cầu bổ sung hàng căn cứ vào mức tồn kho tối thiểu (Safety Stock).
2. **Xuất hàng tại Kho Gửi (Pick & Dispatch)**:
   * Chạy thuật toán FEFO tại Kho gửi để phân bổ lô hàng.
   * Quét mã LPN pallet/thùng, ghi nhận lệnh chuyển: Source `/WH1/COLD` $\rightarrow$ Dest `/TRANSIT/TRUCK-01`.
   * Trạng thái phiếu: `in_transit`.
3. **Giám sát Hành trình**: Cảm biến BLE gắn trên xe tự động ghi nhận nhiệt độ và gửi cảnh báo nếu thùng xe lạnh mất nguồn.
4. **Tiếp nhận & Cất hàng tại Kho Nhận (Receive & Putaway)**:
   * Kho nhận quét mã LPN: Source `/TRANSIT/TRUCK-01` $\rightarrow$ Dest `/WH2/STAGING`.
   * Hệ thống tự động kích hoạt thuật toán **Directed Putaway** tại Kho B để gợi ý ô cất hàng phù hợp.

---

## 2. PHÂN HỆ MỞ RỘNG DƯỢC PHẨM & PHÒNG KHÁM (CLINIC & PHARMA EXTENSION)

### 2.1 Ma trận Tương thích & Yêu cầu Tiêu chuẩn Y tế

| Tiêu chuẩn Dược | Thách thức Vận hành | Giải pháp Tích hợp trên iZiiApp WMS |
| :--- | :--- | :--- |
| **GSP (Good Storage Practice)** | Giám sát nhiệt độ 24/7 (2-8°C đối với vaccine/insulin, 15-25°C đối với thuốc thường). | Tận dụng bảng `IotDevices` và `SensorReadings`: cảnh báo còi hú thời gian thực, tự động khóa cách ly (`quarantine`) lô thuốc nếu sốc nhiệt. |
| **21 CFR Part 11 (Audit Trail)**| Bắt buộc ghi nhận mọi thao tác sửa đổi dữ liệu; không cho phép xóa đè dữ liệu lịch sử. | Schema thiết kế dạng Append-Only; mọi thao tác điều chỉnh kho đều yêu cầu nhập mã lý do (`reason_code`) và ký mã băm SHA-256. |
| **GS1 Serialization** | Chống thuốc giả: quản lý số serial duy nhất đến từng hộp thuốc/lọ sinh phẩm. | Bổ sung bảng `StockSerialNumbers`: giải mã mã vạch GS1 DataMatrix chứa: `(01) GTIN` + `(10) Lot` + `(17) Expiry` + `(21) Serial Number`. |
| **Thuốc Gây nghiện & Hướng thần** | Nghiêm cấm xuất kho tùy tiện; bắt buộc quy trình phê duyệt nghiêm ngặt. | Cơ chế **Ký duyệt kép (Dual Authorization / 4-Eyes Principle)**: Yêu cầu cả Bác sĩ/Dược sĩ trưởng và Thủ kho cùng xác thực sinh trắc học/mã PIN mới mở khóa xuất thuốc. |
| **Cấp phát Bệnh nhân (Dispensing)** | Sai sót cấp phát thuốc đe dọa trực tiếp đến tính mạng người bệnh. | Quy tắc **"5 Đúng" (5 Rights)**: Quét vòng đeo tay bệnh nhân $\rightarrow$ Quét mã vạch đơn thuốc $\rightarrow$ Quét mã hộp thuốc để đối soát 100%. |

---

### 2.2 Sơ đồ Cấu trúc Vị trí trong Phòng khám & Bệnh viện
Hệ thống cây `Locations` của iZiiApp dễ dàng biểu diễn sơ đồ khoa phòng y tế:

```
/HOSPITAL-01
├── /CENTRAL_PHARMACY               (Kho Dược Trung Tâm)
│   ├── /QUARANTINE_AREA            (Khu biệt trữ chờ kiểm nghiệm)
│   ├── /COLD_STORAGE_2_8C          (Kho lạnh bảo quản Vaccine / Sinh phẩm)
│   ├── /CONTROLLED_DRUGS_VAULT     (Két sắt bảo quản Thuốc hướng thần / Gây nghiện)
│   └── /GENERAL_DISPENSARY         (Quầy cấp phát thuốc ngoại trú)
├── /EMERGENCY_DEPT                 (Khoa Cấp Cứu)
│   ├── /CRASH_CART_01              (Xe thuốc cấp cứu cơ động số 1)
│   └── /BEDSIDE_CABINET_ROOM_101   (Tủ thuốc đầu giường phòng bệnh 101)
└── /OPERATING_ROOM_BLOCK           (Khu phẫu thuật)
    └── /ANESTHESIA_CART_OR2        (Tủ thuốc gây mê phòng mổ 2)
```

---

## 3. THIẾT KẾ DỮ LIỆU BỔ SUNG (PHARMA EXTENSION SCHEMA)

Để phân hệ Warehouse hỗ trợ toàn diện Clinic & Pharma, cơ sở dữ liệu Drift và Postgres được mở rộng thêm các bảng chuyên dụng sau:

```sql
-- 1. Bảng Định danh Số Serial Từng Hộp Thuốc (Serialization)
CREATE TABLE IF NOT EXISTS stock_serial_numbers (
    id             TEXT PRIMARY KEY,
    product_id     TEXT NOT NULL,
    lot_id         TEXT NOT NULL,
    serial_number  TEXT NOT NULL UNIQUE,     -- Mã định danh duy nhất của từng hộp/lọ thuốc
    location_id    TEXT NOT NULL,
    status         TEXT DEFAULT 'available', -- available, reserved, dispensed, destroyed, recalled
    created_at     TEXT,
    updated_at     TEXT
);

CREATE INDEX IF NOT EXISTS idx_serials_lot ON stock_serial_numbers(lot_id);
CREATE INDEX IF NOT EXISTS idx_serials_sn ON stock_serial_numbers(serial_number);

-- 2. Bảng Phê duyệt Kép cho Thuốc Kiểm Soát Đặc Biệt (4-Eyes Principle)
CREATE TABLE IF NOT EXISTS pharma_controlled_approvals (
    id                 TEXT PRIMARY KEY,
    picking_line_id    TEXT NOT NULL,
    product_id         TEXT NOT NULL,
    authorized_by_1    TEXT NOT NULL, -- Dược sĩ phụ trách (User ID)
    signature_1        TEXT NOT NULL, -- Chữ ký số / Auth PIN
    timestamp_1        TEXT NOT NULL,
    authorized_by_2    TEXT NOT NULL, -- Bác sĩ điều trị / Trưởng khoa (User ID)
    signature_2        TEXT NOT NULL,
    timestamp_2        TEXT NOT NULL,
    reason_notes       TEXT,
    created_at         TEXT
);

-- 3. Bảng Cấp phát Thuốc theo Đơn Bệnh án (Prescription Dispensing Log)
CREATE TABLE IF NOT EXISTS pharma_dispensing_logs (
    id                 TEXT PRIMARY KEY,
    prescription_id    TEXT NOT NULL,
    patient_id         TEXT NOT NULL,
    patient_barcode    TEXT NOT NULL, -- Mã quét từ vòng đeo tay bệnh nhân
    product_id         TEXT NOT NULL,
    lot_id             TEXT NOT NULL,
    serial_number_id   TEXT,
    dispensed_qty      REAL NOT NULL,
    dispensed_by       TEXT NOT NULL, -- Điều dưỡng cấp phát
    verified_at        TEXT NOT NULL
);
```

---

## 4. TỔNG KẾT & TÍNH KHẢ THI
1. **Kiến trúc Nhất quán**: Phân hệ Multi-Warehouse và Clinic/Pharma không phải là một ứng dụng tách biệt, mà là các lớp cấu hình nghiệp vụ (Business Profiles) được kích hoạt linh hoạt trên cùng một lõi WMS công nghiệp của iZiiApp.
2. **Khởi chạy Thực thi**: Toàn bộ các thực thể mở rộng này sẽ được tích hợp ngay vào file migration nền tảng `0010_industrial_wms_foundation.sql` của **Giai đoạn 1 (Sprint 1)** để đảm bảo cơ sở dữ liệu có khả năng mở rộng trọn vẹn trong tương lai.
