# iZiiApp — Danh sách Task & Kế hoạch Phát triển Chức năng

Dưới đây là bảng theo dõi tiến độ các tính năng cốt lõi hiện tại và danh sách các tính năng đề xuất bổ sung dựa trên hệ thống module của Odoo 19.0.

---

## 🛠️ Trạng thái Hệ thống Hiện tại (Current Codebase Status)

### 1. Khung ứng dụng & Giao diện (Core App Shell & Theme)
- [x] `lib/main.dart` — Điểm khởi chạy ứng dụng
- [x] `lib/app.dart` — MaterialApp + GoRouter
- [x] `lib/core/theme/izii_colors.dart` — Bảng màu thương hiệu
- [x] `lib/core/theme/izii_theme.dart` — Cấu hình Dark/Light theme
- [ ] `lib/core/theme/izii_typography.dart` — Định nghĩa Typography chuẩn (Outfit & Inter)
- [ ] `lib/core/theme/izii_spacing.dart` — Định nghĩa Spacing & BorderRadius tokens
- [x] `lib/core/navigation/app_router.dart` — Cấu hình GoRouter đa nền tảng
- [ ] `lib/core/widgets/` — Thư mục chứa các thành phần giao diện dùng chung (Common Widgets)

### 2. Cơ sở dữ liệu (Drift SQLite Engine)
- [x] `lib/core/database/app_database.dart` — Quản lý cơ sở dữ liệu và Migrations (Schema v6)
- [x] `lib/core/database/tables/` — Khai báo các bảng dữ liệu gốc (Contacts, Leads, Deals, Products, Stock, Booking...)
- [x] Quản lý tạo mã tự động Drift thông qua `build_runner`
- [x] Tích hợp database vào tất cả Repositories hiện có

### 3. Tương tác AI Agent (AI Engine)
- [x] `lib/core/ai_agent/models/chat_models.dart` — Khai báo các models chat & tool calls
- [x] `lib/core/ai_agent/llm_providers/llm_provider.dart` — Abstract class định nghĩa LLM Provider
- [x] `lib/core/ai_agent/llm_providers/gemini_provider.dart` — Tích hợp Google Gemini (mặc định)
- [ ] `lib/core/ai_agent/llm_providers/openai_provider.dart` — Tích hợp OpenAI GPT-4o (chưa hoàn thành)
- [ ] `lib/core/ai_agent/llm_providers/ondevice_provider.dart` — Tích hợp LLM chạy offline (Ollama / Llama.cpp) (chưa hoàn thành)
- [x] `lib/core/ai_agent/tools/` — Đăng ký, định tuyến và thực thi các Agent Tools tự động
- [x] Tích hợp luồng Xác nhận đặt dịch vụ (`requiresConfirmation`) bằng Card giao diện nổi bật (Gemini Booking Confirmation Card)
- [x] `lib/core/ai_agent/ui/` — Giao diện AI Chat bong bóng, Suggestion chips và Card xác nhận

### 4. Lớp Cộng đồng (Community Layer)
- [x] `lib/core/community/models/` — Định nghĩa Profile, TrustScore, Listing, Booking...
- [x] `lib/core/community/trust_network_service.dart` — Tính toán điểm tin cậy dựa trên mạng lưới giới thiệu
- [x] `lib/core/community/matching_engine.dart` — Công cụ gợi ý & kết hợp nhà cung cấp phù hợp
- [x] `lib/core/community/invite_service.dart` — Tạo link mời và quản lý referral chains
- [x] `lib/core/community/trust_score_calculator.dart` — Thuật toán tính điểm Trust Level (Newcomer, Trusted, Verified, Elite)

### 5. Quản lý Hệ thống Module (Module Manager)
- [x] `lib/core/modules/module_interface.dart` — Định nghĩa interface `IZiiModule` và manifest
- [x] `lib/core/modules/module_registry.dart` — Trình quản lý đăng ký và cài đặt module động
- [x] `lib/core/modules/module_dashboard_screen.dart` — Giao diện Dashboard module hiện đại (Active status, Quick Actions grid)
- [x] `lib/core/modules/module_directory_screen.dart` — Cửa hàng module (Module Store) cho phép bật/tắt module
- [ ] `lib/core/modules/dependency_graph.dart` — Thuật toán sắp xếp topological giải quyết xung đột/phụ thuộc khi cài đặt module (chưa hoàn thành)

### 6. Đồng bộ hóa Offline-First (Sync Engine)
- [x] `lib/core/database/tables.dart` -> Thêm bảng `OutboxMutations` lưu hàng đợi ngoại tuyến
- [x] `lib/core/sync/outbox_queue.dart` — Quản lý thêm, lấy, xoá hàng đợi offline trong database local
- [x] `lib/core/sync/sync_service.dart` — Đẩy dữ liệu (PUSH), Kéo dữ liệu (PULL), cập nhật trạng thái mạng (Connectivity)
- [x] **Step 1: Database Migration (Schema Version 12)**
  - [x] 1.1 Create `lib/modules/mushrooms/database/tables.dart` containing `MushroomRooms` and `MushroomJobs` tables
  - [x] 1.2 Update `lib/core/database/app_database.dart` with new tables, increment schema version to 12, and add migration blocks
  - [x] 1.3 Run Drift builder to regenerate database bindings
- [x] **Step 2: Repository Business Logic & Seeding**
  - [x] 2.1 Create `lib/modules/mushrooms/repository.dart` for seeding M2 Rooms 33–66 and handling pipeline progression
  - [x] 2.2 Implement solo safety countdown and alarm logic
- [x] **Step 3: UI Implementation**
  - [x] 3.1 Create `lib/modules/mushrooms/bloc/mushrooms_bloc.dart` for state management
  - [x] 3.2 Create `lib/modules/mushrooms/screens/mushrooms_dashboard_screen.dart` (Industrial UI Room List and Alarm Siren)
  - [x] 3.3 Implement Room Detail Sheet/View with timeline (blue = done, green = active) and solo safety countdown
- [x] **Step 4: Module & Routing Integration**
  - [x] 4.1 Create `lib/modules/mushrooms/mushrooms_module.dart` manifest and expose AI Agent tools
  - [x] 4.2 Register routes in `app_router.dart` and register module factory in `module_registry.dart`
  - [x] 4.3 Add localization keys in translation files `vi.dart` and `en.dart`
- [x] **Step 5: Verification & Analysis**
  - [x] 5.1 Run static analysis verification check
- [ ] `lib/core/sync/conflict_resolver.dart` — Triển khai cơ chế giải quyết xung đột (Last-Write-Wins, Merge fields, hoặc hỏi ý kiến người dùng)
- [ ] `lib/core/sync/sync_scheduler.dart` — Hẹn giờ đồng bộ nền định kỳ khi app bị đóng (WorkManager)

### 7. Các Module Nghiệp vụ Hiện có
- [x] **Sales & CRM Module**:
  - Giao diện quản lý Leads CRUD, Quick Status Changer cho Leads (Popup Menu)
  - Deal Pipeline dạng Kanban hỗ trợ thao tác Kéo & Thả (Drag-and-Drop) trơn tru
- [x] **Supply Chain Module**:
  - Quản lý kho hàng, sản phẩm CRUD, thêm SP nhanh bằng ảnh
  - Tích hợp quét mã vạch Barcode/QR bằng camera qua package `mobile_scanner` để tìm kiếm và điền mã tự động
- [x] **Services Module**:
  - Quản lý danh mục Dịch vụ (có trường tùy chỉnh Custom Fields), đặt lịch Booking hẹn khách
  - Hộp thoại tính tiền tự động dựa trên thời gian thực tế hoàn thành (`actual_hours * hourly_rate`)

---

## 🚀 Các Tính năng Cần Bổ sung (Đề xuất Mới & Gaps)

Dưới đây là các tính năng và module mới cần bổ sung để iZiiApp trở thành một siêu ứng dụng ERP hoàn chỉnh lấy cảm hứng từ Odoo 19.0.

### A) Hoàn thiện các Lỗ hổng Cốt lõi (Core Gaps)
- [x] **Multi-Language Support (Đa ngôn ngữ)**:
  - Triển khai `AppLocalizations` quản lý từ điển động và BuildContext extensions.
  - Tạo bảng dịch mặc định `vi.dart` (Tiếng Việt) và `en.dart` (Tiếng Anh) tinh gọn.
  - Tích hợp `locale` và settings lưu trữ ngôn ngữ vào `AppBloc` & `SettingsService`.
  - Thiết kế Card cấu hình Ngôn ngữ bằng ChoiceChips trong SettingsScreen.
  - Hỗ trợ các module tự đăng ký dịch động (`initialize()`) trên môi trường modular.
- [ ] **Auth Module (Xác thực & Người dùng)**:
  - Triển khai `lib/core/auth/auth_service.dart` (hỗ trợ JWT Login/Register/Logout).
  - Thêm màn hình Đăng nhập/Đăng ký với thiết kế Premium Glassmorphism.
  - Phân quyền người dùng (Role-based access control: Admin, Manager, Staff, Customer).
- [ ] **AI Config Screen (Cấu hình AI)**:
  - Cho phép người dùng cấu hình loại LLM (Gemini, OpenAI, Ollama), nhập API Key, cấu hình Prompt hệ thống của riêng mình.
- [ ] **Onboarding & KYC Screen**:
  - Giao diện hướng dẫn người dùng cung cấp giấy tờ định danh (KYC) để xác minh tài khoản, nâng cấp điểm Trust Score.
- [ ] **Typography & Spacing Tokens**:
  - Tách biệt định nghĩa style chữ và khoảng cách ra file riêng (`izii_typography.dart`, `izii_spacing.dart`) để giao diện thống nhất hơn.

### B) Các Module Nghiệp vụ Mới (New Odoo-inspired Modules)

#### 1. 🧾 Module Hóa đơn & Kế toán (Invoicing & Accounting)
*Hỗ trợ thanh toán và quản lý dòng tiền từ hoạt động Bán hàng (CRM) và Dịch vụ.*
- [ ] Khai báo bảng: `Invoices` (id, code, customer_id, issue_date, due_date, total, status: draft/unpaid/paid), `InvoiceItems` (id, invoice_id, description, quantity, price), `Payments` (id, invoice_id, amount, payment_method, transaction_date).
- [ ] Tính năng "Xuất Hoá đơn" nhanh từ một **Deal thắng (CRM)** hoặc **Booking hoàn thành (Services)**.
- [ ] Dashboard Tài chính: Thống kê doanh thu, chi phí, công nợ khách hàng dạng biểu đồ trực quan (sử dụng package `fl_chart`).
- [ ] Xuất hoá đơn ra file PDF hoặc xuất hóa đơn in nhiệt để gửi cho khách hàng.

#### 2. 👥 Module Nhân sự & Chấm công (Human Resources & Attendance)
*Quản lý nhân viên nội bộ, chấm công hàng ngày và xin nghỉ phép.*
- [ ] Khai báo bảng: `Employees` (id, user_id, job_title, department, manager_id), `Attendances` (id, employee_id, check_in, check_out, gps_latitude, gps_longitude), `LeaveRequests` (id, employee_id, start_date, end_date, reason, status: pending/approved/rejected).
- [ ] Chức năng **Chấm công thông minh (Check-in / Check-out)** bằng nút bấm lớn kèm định vị GPS hoặc xác thực sóng Wi-Fi văn phòng.
- [ ] Màn hình nộp đơn xin nghỉ phép (Time Off) và luồng duyệt đơn cho người quản lý.

#### 3. 📋 Module Quản lý Dự án & Task (Project & Task Management)
*Quản lý công việc của đội ngũ và ghi nhận thời gian hoàn thành.*
- [ ] Khai báo bảng: `Projects` (id, name, description, status), `ProjectTasks` (id, project_id, title, description, assignee_id, priority, status: todo/in_progress/done), `Timesheets` (id, task_id, employee_id, date, duration_hours, description).
- [ ] Bảng Kanban quản lý Task công việc hỗ trợ kéo thả trạng thái.
- [ ] Chức năng bấm giờ làm việc (Timesheet Timer) tự động ghi nhận giờ vào công việc cụ thể.

#### 4. 🛒 Module Mua hàng (Purchase Management)
*Đặt mua nguyên vật liệu/sản phẩm từ nhà cung cấp và nhập kho.*
- [ ] Khai báo bảng: `Vendors` (id, name, phone, email, address), `PurchaseOrders` (id, vendor_id, order_date, total_amount, status: draft/confirmed/received), `PurchaseOrderLines` (id, po_id, product_id, quantity, unit_price).
- [ ] Quy trình Mua hàng: Tạo đơn hàng gửi Nhà cung cấp -> Xác nhận giao hàng -> Tự động cộng số lượng tồn kho sản phẩm trong Supply Chain.

#### 5. 🏪 Module Điểm bán lẻ (Point of Sale - POS)
*Giao diện bán hàng nhanh tại quầy cho các cửa hàng bán lẻ.*
- [ ] Giao diện POS tối ưu hóa cho màn hình ngang (Tablet/Desktop) và dọc (Mobile): Chọn nhanh sản phẩm từ lưới danh mục -> Giỏ hàng -> Thanh toán.
- [ ] Thanh toán tiện lợi bằng mã QR động ngân hàng (VietQR) hoặc ví điện tử.
- [ ] Hỗ trợ quét mã vạch trực tiếp từ Camera để add sản phẩm vào giỏ hàng POS.
