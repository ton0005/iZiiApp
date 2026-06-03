# 3 Tính năng nâng cấp iZiiApp

Kế hoạch triển khai tuần tự 3 tính năng mới dựa trên kiến trúc hiện tại.

---

## Phase 1 — AI Chat: Tự động đặt Dịch vụ qua Chat

> **Mục tiêu:** Người dùng nói *"Đặt cho tôi dịch vụ sửa điện vào 9h sáng mai"* → AI tạo đơn Booking trong Database.

### Hiện trạng

- Hệ thống AI Agent Tool đã hoạt động: `AgentTool` → `AgentToolRegistry` → `GeminiProvider` → Gemini 2.5 Flash
- Đã có `ServicesRepository.addBooking()` xử lý UUID, tính giá tự động, lưu DB
- Flag `requiresConfirmation` trên `AgentTool` **tồn tại nhưng chưa bao giờ được kiểm tra** — tool luôn chạy ngay

### Proposed Changes

#### [MODIFY] [services_module.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/services/services_module.dart)
- Thêm `AgentTool` mới: **`create_service_booking`**
  - Parameters: `service_name` (string, bắt buộc), `customer_name` (string, bắt buộc), `customer_phone` (string, tùy chọn), `scheduled_date` (string ISO 8601, tùy chọn), `notes` (string, tùy chọn)
  - Execute: Tìm service theo tên → gọi `addBooking()` → trả về tóm tắt đơn đặt
  - Set `requiresConfirmation: true`

---

#### [MODIFY] [ai_agent_service.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/ai_agent/ai_agent_service.dart)
- Trong callback `onToolCall`: **kiểm tra `tool.requiresConfirmation`** trước khi chạy
- Nếu `requiresConfirmation == true`:
  - Lưu `PendingToolCall(toolName, args)` vào một biến tạm
  - Trả về kết quả "PENDING_CONFIRMATION" (không thực thi)
  - Gemini sẽ nhận kết quả "chờ xác nhận" và phản hồi phù hợp
- Nếu `false`: chạy bình thường như hiện tại

---

#### [MODIFY] [chat_bloc.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/ai_agent/bloc/chat_bloc.dart)
- Thêm `PendingToolCall? pendingToolCall` vào `ChatState`
- Thêm events mới:
  - `ConfirmToolCallEvent` → thực thi tool đang chờ → gửi kết quả lại cho Gemini
  - `RejectToolCallEvent` → bỏ qua tool → thông báo Gemini rằng user từ chối

---

#### [MODIFY] [ai_chat_screen.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/ai_agent/ui/ai_chat_screen.dart)
- Khi `state.pendingToolCall != null`: hiển thị **Confirmation Card** phía trên input
  - Card tóm tắt: "AI muốn tạo đơn dịch vụ: Sửa điện — KH: Nguyễn Văn A — 9:00 ngày mai"
  - 2 nút: ✅ Xác nhận / ❌ Từ chối
  - Card dùng gradient + animation mượt mà

---

#### [MODIFY] [gemini_provider.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/ai_agent/llm_providers/gemini_provider.dart)
- Cập nhật system instruction để Gemini biết rằng khi tạo booking cần thu thập đủ thông tin: tên dịch vụ, tên khách, SĐT, ngày giờ hẹn
- Thêm mô tả rõ ràng cho `create_service_booking` tool trong prompt

> [!IMPORTANT]
> Với flow confirmation này, khi user nói "Đặt cho tôi dịch vụ sửa điện vào 9h sáng mai", Gemini sẽ gọi tool → App hiển thị card xác nhận → User bấm ✅ → Tool thực thi → Kết quả gửi lại Gemini → Gemini trả lời "Đã đặt thành công!"

---

## Phase 2 — Barcode/QR Scanner cho Kho Hàng

> **Mục tiêu:** Quét mã vạch/QR → tra cứu sản phẩm ngay hoặc thêm sản phẩm mới.

### Hiện trạng

- Bảng `Products` **KHÔNG có cột `barcode`** — chỉ có `sku`, `name`, `price`, `cost`, `customFields`
- **Không có** package barcode scanner trong `pubspec.yaml`
- Màn hình `ProductsScreen` không có nút scan hay search thực tế

### Proposed Changes

#### Thêm dependency mới
```yaml
# pubspec.yaml
mobile_scanner: ^6.0.5   # Camera-based barcode/QR scanning
```

---

#### [MODIFY] [tables.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/supply_chain/database/tables.dart)
- Thêm cột `barcode` (TEXT, nullable, unique) vào bảng `Products`

#### [MODIFY] [app_database.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/database/app_database.dart)
- Bump schema version 4 → 5
- Migration: `ALTER TABLE Products ADD COLUMN barcode TEXT`

---

#### [MODIFY] [repository.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/supply_chain/repository.dart)
- Thêm `getProductByBarcode(String barcode)` → tìm sản phẩm theo mã vạch
- Cập nhật `addProductWithStock()` nhận thêm param `barcode`
- Cập nhật `updateProductWithStock()` nhận thêm param `barcode`

---

#### [NEW] [barcode_scanner_screen.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/supply_chain/screens/barcode_scanner_screen.dart)
- Giao diện quét mã vạch toàn màn hình sử dụng `MobileScanner`
- Hiệu ứng viewfinder (khung quét) + animation scan line
- Khi quét được mã:
  - Tìm trong DB → nếu có: hiển thị **Bottom Sheet** thông tin sản phẩm (tên, giá, tồn kho) + nút Chỉnh sửa
  - Nếu không có: hiển thị Bottom Sheet "Sản phẩm mới" → nút Thêm mới (chuyển sang AddProductFromImageScreen với barcode đã điền sẵn)
- Hỗ trợ: đèn flash toggle, chuyển camera trước/sau

---

#### [MODIFY] [products_screen.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/supply_chain/screens/products_screen.dart)
- Thêm nút **Scan** vào AppBar (icon `qr_code_scanner`)
- Tap → mở `BarcodeScannerScreen`
- Hiển thị barcode trên mỗi product card (nếu có)

---

#### [MODIFY] [add_product_from_image_screen.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/supply_chain/screens/add_product_from_image_screen.dart)
- Thêm TextField `barcode` vào form
- Nhận barcode từ route params khi chuyển từ scanner → tự động điền

#### [MODIFY] [edit_product_screen.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/supply_chain/screens/edit_product_screen.dart)
- Thêm TextField `barcode` vào form (hiển thị và cho phép sửa)

---

## Phase 3 — CRM Pipeline Drag-and-Drop

> **Mục tiêu:** Kéo-thả Deal giữa các cột trạng thái (Đề xuất → Đàm phán → Thắng/Thua).

### Hiện trạng

- Pipeline hiện tại là **display-only** — dùng `FutureBuilder` truy cập DB trực tiếp, KHÔNG dùng BLoC
- **Không có** `Draggable` / `DragTarget` widget
- **Không có** event `UpdateDealStage` trong `CrmBloc`
- **Không có** method `updateDealStage()` trong repository
- `CrmState` chỉ có `leads`, **không có `deals`**

### Proposed Changes

#### [MODIFY] [crm_bloc.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/sales_crm/bloc/crm_bloc.dart)
- Thêm `List<Map<String, dynamic>> deals` vào `CrmState`
- Thêm events:
  - `LoadDealsEvent` → load deals với JOIN contacts/leads
  - `UpdateDealStageEvent(dealId, newStage)` → cập nhật stage + reload
  - `UpdateLeadStatusEvent(leadId, newStatus)` → cập nhật trạng thái lead
- Thêm methods tương ứng vào `CrmRepository`

---

#### [MODIFY] [repository.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/sales_crm/repository.dart)
- Thêm `updateDealStage(String dealId, String newStage)` sử dụng `DealsDao`
- Thêm `updateLeadStatus(String leadId, String newStatus)` sử dụng `LeadsDao`
- Thêm `getDealsGroupedByStage()` → trả về `Map<String, List<Map>>` cho pipeline

---

#### [MODIFY] [deal_pipeline.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/sales_crm/ui/deal_pipeline.dart) — **Viết lại hoàn toàn**
Chuyển từ `FutureBuilder` → `BlocBuilder<CrmBloc>`:

- Mỗi **cột stage** được bọc bằng `DragTarget<Map<String, dynamic>>`
  - `onAcceptWithDetails`: dispatch `UpdateDealStageEvent(deal['id'], thisStage)`
  - Visual feedback: highlight viền + đổi màu nền khi có item hover
- Mỗi **deal card** bọc bằng `LongPressDraggable<Map<String, dynamic>>`
  - `feedback`: card thu nhỏ (opacity 0.8) với elevation cao
  - `childWhenDragging`: card mờ (placeholder)
  - Tap (không kéo): mở bottom sheet chi tiết deal
- Stage columns: Đề xuất (xanh dương), Đàm phán (tím), Thắng (xanh lá), Thua (đỏ)
- AppBar: nút Refresh + nút Add Deal
- Micro-animations khi deal di chuyển sang cột mới (`flutter_animate`)

---

#### [MODIFY] [leads_screen.dart](file:///c:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/sales_crm/screens/leads_screen.dart)
- Thêm **Quick Status Buttons** trên mỗi lead card:
  - Chip/Popup menu cho phép chuyển trạng thái: New → Qualified → Won → Lost
  - Dispatch `UpdateLeadStatusEvent` qua CRM BLoC
  - Không cần mở EditLeadScreen chỉ để đổi status

---

## Cấu trúc thư mục thay đổi

```
lib/
├── core/
│   ├── ai_agent/
│   │   ├── ai_agent_service.dart          [MODIFY] — thêm confirmation flow
│   │   ├── bloc/chat_bloc.dart            [MODIFY] — thêm confirm/reject events
│   │   ├── ui/ai_chat_screen.dart         [MODIFY] — thêm confirmation card UI
│   │   └── llm_providers/gemini_provider.dart [MODIFY] — cập nhật system prompt
│   └── database/app_database.dart         [MODIFY] — schema v5, add barcode column
│
├── modules/
│   ├── services/
│   │   └── services_module.dart           [MODIFY] — thêm create_service_booking tool
│   │
│   ├── supply_chain/
│   │   ├── database/tables.dart           [MODIFY] — thêm barcode column
│   │   ├── repository.dart                [MODIFY] — thêm getProductByBarcode()
│   │   ├── screens/
│   │   │   ├── products_screen.dart       [MODIFY] — thêm nút scan
│   │   │   ├── barcode_scanner_screen.dart [NEW] — scanner screen
│   │   │   ├── add_product_from_image_screen.dart [MODIFY] — barcode field
│   │   │   └── edit_product_screen.dart   [MODIFY] — barcode field
│   │   └── supply_chain_module.dart       [MODIFY] — thêm route barcode
│   │
│   └── sales_crm/
│       ├── bloc/crm_bloc.dart             [MODIFY] — thêm deals state + events
│       ├── repository.dart                [MODIFY] — thêm update methods
│       ├── ui/deal_pipeline.dart          [MODIFY] — drag-and-drop rewrite
│       └── screens/leads_screen.dart      [MODIFY] — quick status buttons
```

## Verification Plan

### Automated Tests
1. `flutter pub run build_runner build` — generate Drift code cho schema v5
2. `flutter analyze` — verify zero compile errors

### Manual Verification
1. **AI Chat**: Gõ "Đặt dịch vụ sửa điện cho Nguyễn Văn A, SĐT 0901234567, lúc 9h sáng mai" → xác nhận card → kiểm tra booking trong DB
2. **Barcode**: Quét mã vạch sản phẩm → kiểm tra tra cứu/thêm mới hoạt động
3. **Pipeline**: Kéo deal từ cột "Đề xuất" → "Đàm phán" → verify stage đã đổi trong DB

## Thứ tự triển khai

| Thứ tự | Phase | Ước tính |
|--------|-------|----------|
| 1 | AI Chat — create_service_booking + confirmation | ~8 files |
| 2 | Barcode Scanner | ~7 files + 1 dependency |
| 3 | CRM Pipeline Drag-and-Drop | ~4 files |

> [!NOTE]
> Mỗi Phase có thể build & test độc lập. Phase 1 không phụ thuộc Phase 2/3.
