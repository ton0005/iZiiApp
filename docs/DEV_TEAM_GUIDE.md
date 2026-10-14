# Hướng dẫn Dev Team — iZiiApp (nhánh `mushroom-farm-fork`)

Tài liệu onboarding cho dev mới và tham chiếu nhanh cho cả team. Nội dung được tổng hợp từ code hiện tại; khi code và tài liệu khác nhau, **code là chuẩn**. Các file ghi chú ở thư mục gốc (`walkthrough.md`, `implementation_plan*.md`, `debug_UI.txt`...) là ghi chú làm việc của các phiên trước, không phải tài liệu chính thức.

## 1. Tổng quan

iZiiApp là nền tảng nghiệp vụ/cộng đồng **local-first, chạy offline**, gồm hai nửa trong cùng một repo:

| Thành phần | Thư mục | Công nghệ |
|---|---|---|
| Client | `lib/` | Flutter (Android / iOS / Windows desktop), BLoC, Drift/SQLite |
| Server (iZiiServer) | `server/` | Python, FastAPI, SQLite (mặc định) hoặc PostgreSQL |

- Trên Windows desktop, app Flutter có thể tự khởi chạy `izii_server.exe` như một tiến trình con (`lib/core/server/server_manager.dart`) để bản desktop chạy độc lập.
- Nhánh `mushroom-farm-fork` là bản fork cho nghiệp vụ **quản lý trang trại nấm** (`lib/modules/mushrooms/`). Nhánh `main` là sản phẩm iZiiApp tổng quát. Quy trình nhánh xem `MUSHROOM_FARM_BRANCH_GUIDE.md`.

## 2. Thiết lập môi trường & lệnh thường dùng

### 2.1 Flutter client

```bash
flutter pub get
flutter analyze                      # lint (flutter_lints, xem analysis_options.yaml)
flutter test                         # chạy toàn bộ test trong test/
flutter test test/modules/mushrooms/services/mushrooms_shared_services_test.dart   # một file test
flutter build apk --debug
flutter build apk --release
flutter build ios --release
flutter build windows
```

**Codegen** (Drift, Freezed, JSON serializable) — bắt buộc chạy lại sau khi sửa file có `@freezed`, `@JsonSerializable`, `@DriftDatabase` hoặc khai báo bảng Drift:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Không sửa tay `*.g.dart` / `*.freezed.dart` (bị loại khỏi phân tích tĩnh).

### 2.2 Python server

```bash
cd server
pip install -r requirements.txt
python app.py                                     # dev mode (uvicorn reload, cổng mặc định 8080)
python -m unittest tests.test_phase1_foundation   # chạy một module test
python -m unittest discover tests                 # chạy toàn bộ test server
```

- Test dùng `unittest` thuần (không có cấu hình pytest) và import module server bằng cách thêm `server/` vào `sys.path` → **luôn chạy từ trong `server/`**.
- Biến môi trường: xem `server/.env.example` (là nguồn chuẩn).
- `server_config.py` có port-guard: server từ chối khởi động nếu cổng đã bị chiếm.

### 2.3 Đóng gói

```bash
# Server -> exe độc lập cho desktop
cd server
pyinstaller --clean izii_server.spec        # ra server/dist/izii_server/izii_server.exe

# Installer Windows (Inno Setup, gồm bản build Flutter + izii_server.exe)
build_windows_installer.bat                 # ở thư mục gốc, gọi windows/installer/build_installer.bat
```

Chi tiết: `SERVER_REBUILD_GUIDE.md`, `FLUTTER_BUILD_RELEASE_GUIDE.md`, `windows/installer/README.md`.

### 2.4 Nâng version

Khi tăng version phải sửa **đủ** các file sau:

- `pubspec.yaml` (`version:`)
- `lib/modules/supply_chain/manifest.dart`, `lib/modules/services/manifest.dart`, `lib/modules/sales_crm/manifest.dart` (`version:`)
- `windows/runner/Runner.rc` (`VERSION_AS_STRING`)

## 3. Kiến trúc Flutter client

### 3.1 Bố cục

- `lib/main.dart`, `lib/app.dart` — điểm vào; dựng `AppBloc` (settings/theme/locale) và `BlocProvider` của chat, rồi `MaterialApp.router` theo `core/navigation/app_router.dart` (go_router). Khi thoát app trên desktop sẽ gọi `ServerManager().stopServer()`.
- `lib/core/` — hạ tầng dùng chung: database, sync, bảo mật, định danh thiết bị, AI agent, điều hướng, theme, đa ngôn ngữ.
- `lib/modules/` — các module nghiệp vụ cắm-rút được.
- `lib/features/` — màn hình cấp ứng dụng không phải module nghiệp vụ (home, discover, profile, chọn server, chia sẻ).

### 3.2 Hệ thống module

Mỗi module implement `IZiiModule` (`lib/core/modules/module_interface.dart`) và khai báo: `ModuleManifest` (id/name/version/category), tên bảng Drift, các `AgentTool` cho AI agent, route và widget dashboard (tùy chọn). `lib/core/modules/module_registry.dart` là singleton đăng ký factory cho: `sales_crm`, `supply_chain`, `services`, `project`, `purchase`, `accountant`, `mushrooms`; module được khởi tạo lười (lazy) khi cài đặt.

> Thêm tính năng nghiệp vụ mới → làm theo đúng "hình dạng" module này, **không** gắn màn hình trực tiếp vào `app_router.dart`.

### 3.3 Dữ liệu cục bộ & đồng bộ

- `lib/core/database/app_database.dart` (+ `core_tables.dart`) — DB Drift/SQLite. Module đóng góp bảng riêng (ví dụ `lib/modules/mushrooms/database/`).
- `lib/core/sync/`:
  - `outbox_queue.dart` — hàng đợi các thay đổi cục bộ.
  - `sync_service.dart` — đẩy/kéo mutation qua các endpoint `/sync/*` của server.
  - `ble_sync_manager.dart` — đồng bộ thiết bị-với-thiết bị qua Bluetooth khi không có mạng/server.
  - `sharing_repository.dart`, `sync_config_repository.dart` — trạng thái chia sẻ và cấu hình kết nối server.

### 3.4 Định danh thiết bị, enrollment, bảo mật

- `lib/core/device_identity/` — định danh thiết bị, dò BLE thiết bị lân cận, handshake kiểu Noise (`noise_handshake_service.dart`), quản lý khóa (`crypto_service.dart`).
- `lib/core/enrollment/` — đưa thiết bị mới vào server bằng ticket QR/NFC (`enrollment_service.dart`, `nfc_enrollment_service.dart`); phản chiếu luồng `/devices/enroll` của server.
- `lib/core/security/` — `ble_p2p_handshake_service.dart` (mã hóa ghép đôi BLE), `image_key_kdf_engine.dart` (dẫn xuất khóa cho ảnh mã hóa).
- `lib/core/community/` — luồng mời, chấm điểm tin cậy, đồ thị mạng tin cậy.

### 3.5 AI Agent

`lib/core/ai_agent/` là chat agent gọi công cụ (tool-calling): `ai_agent_service.dart` điều phối qua giao diện `llm_provider.dart` (hiện là `gemini_provider.dart`, dùng `google_generative_ai`); `tools/agent_tool_registry.dart` gom các `AgentTool` do từng module cài đặt cung cấp (`IZiiModule.agentTools`); `bloc/chat_bloc.dart` điều khiển UI chat. Nhờ vậy module tự mở khả năng "nhờ AI làm X" mà agent không cần biết trước từng module.

### 3.6 Module Mushrooms (`lib/modules/mushrooms/`)

Mảng sản phẩm chính của nhánh này (Costa Mushrooms: khoảng 66 phòng trồng ở Plant M1/M2, kế hoạch công việc hằng ngày, kế hoạch thu hoạch, chấm công/timesheet, an toàn Solo-Job + radio gateway, mua hàng, xem phòng 3D).

Luồng chính: `mushrooms_module.dart` (manifest + `AgentTool`, một số có `requiresConfirmation`) → `bloc/mushrooms_bloc.dart` → `repository.dart` (một class lớn, nắm toàn bộ truy cập Drift và đưa mutation vào hàng đợi sync qua `SyncService`) → logic nghiệp vụ tách ở `services/*` (nhân viên, kế hoạch thu hoạch + import Excel, job list, xuất PDF, an toàn, radio gateway...) → các tab trong `screens/*`.

Lưu ý:
- Giao diện và nhiều comment bằng tiếng Việt.
- **ID phòng mang tính xác định** (`'Room 6A'` → `room_6a`) để seed trên các thiết bị hội tụ về cùng bản ghi. Giữ nguyên quy tắc này khi sửa phần seed.

## 4. Kiến trúc Python server (`server/`)

- `app.py` — entrypoint FastAPI. Khởi tạo DB (`db_init.py`), chạy migration SQL có version (`migrations/runner.py`, file ở `migrations/versions/`), nạp seed khai báo (`seeds/seed_loader.py`), khởi tạo module nghiệp vụ phía server (`modules/module_manager.py`, manifest ở `modules/{core,collab,field_ops,workforce}/manifest.json`), quảng bá/dò mDNS (`server_discovery.py`) để tự tìm peer trong LAN, và chạy các vòng asyncio nền: đồng bộ delta giữa các server và bảo trì hằng ngày (dọn mutation cũ / dead-letter).
- `routers/` — mỗi file là một nhóm API: `sync`, `devices`, `messages`, `notifications`, `attachments`, `peer_sync`, `call`, `webhooks`, `admin`, `enrollment`, `sessions`, cùng các router mảng nấm/field-ops: `radio_gateway`, `agv_gateway`, `workforce`.
- `repository/` — mẫu repository với hợp đồng `interface.py` và hai bản cài đặt: `sqlite_repo.py` (mặc định) và `postgres_repo.py` (bật bằng `IZIIAPP_DB_BACKEND=postgres` khi cần nhiều writer/nhiều site; xem `server/HUONG_DAN_CHUYEN_DATABASE_POSTGRES.md`, `server/POSTGRES_MIGRATION_GUIDE.md`).
- `dependencies.py` — DI của FastAPI: mở kết nối DB và chọn bản repo theo cấu hình.
- `services/timesheet_service.py` — tính timesheet hằng ngày.
- `sync_server.py` ở thư mục gốc là prototype cũ; server thật là `server/app.py`.

### 4.1 Mô hình xác thực: ba secret tách biệt

| Secret / token | Dùng cho | Ghi chú |
|---|---|---|
| `IZIIAPP_SERVER_SECRET` | Đồng bộ server ↔ server (peer sync) | |
| `IZIIAPP_ADMIN_SECRET` | `/admin/*` (header `X-iZii-Admin-Token`) | **Không bao giờ** cấp cho thiết bị nhân viên |
| Token theo thiết bị (cấp qua enrollment) | `/sync/*` | `/enrollment` là public nhưng cần ticket mời |
| `IZIIAPP_WS_SECRET` | WebSocket `/chat` | Fallback về `IZIIAPP_SERVER_SECRET`; nếu cả hai đều trống thì `/chat` từ chối mọi kết nối |

Không được gộp lẫn các secret này khi thêm endpoint mới.

### 4.2 Mạng nhiều server (mesh)

Mỗi server có `server_id` và `zone`. `_peer_sync_loop` trong `app.py` kéo delta từ các peer cấu hình tĩnh (`IZIIAPP_PEERS`) và peer tìm thấy qua mDNS, theo con trỏ `after_seq` đơn điệu — **cố ý không dùng thời gian thực** để tránh mất dữ liệu do lệch đồng hồ. Con trỏ được lưu theo từng peer trong bảng `known_servers`.

### 4.3 Mutation log → read model

Thiết bị đẩy mutation vào `sync_mutations`. `projector.py` chiếu chúng thành các bảng quan hệ chuẩn hóa (chủ yếu cho backend PostgreSQL): ánh xạ tên logic → bảng vật lý trong `TABLE_ALIASES` (ví dụ `jobs` → `mushroom_jobs`), merge theo từng cột ("dirty-field"), mở rộng qua `hooks.py`. `event_engine.py` biến thay đổi bảng thành domain event và phát qua WebSocket / webhook gửi ra ngoài. Hợp đồng mutation: `docs/adr/001-mutation-contract.md`.

## 5. Quy trình làm việc thường gặp

### 5.1 Đổi schema Drift (client)

1. Thêm bảng vào danh sách `@DriftDatabase` trong `app_database.dart` (hoặc thêm cột).
2. Tăng `schemaVersion` (hiện là **33**).
3. Thêm khối `if (from < N) { try { ... } catch (_) {} }` vào `onUpgrade`. Các khối hiện có nuốt lỗi để chạy lại được (idempotent) — làm theo cùng kiểu.
4. Chạy lại `dart run build_runner build --delete-conflicting-outputs`.

`AppDatabase` là singleton (`AppDatabase()`). Trong test, thay bằng `AppDatabase.testInstance = ...` hoặc tạo bằng `AppDatabase.forTesting(executor)`.

### 5.2 Thêm một entity cần đồng bộ

Thường cần đủ ba phần:
1. **Client:** bảng Drift + hàm repository tạo mutation đưa vào outbox.
2. **Server:** migration SQL mới trong `server/migrations/versions/` (số kế tiếp sau `0011_*`).
3. **Server:** thêm mục `TABLE_ALIASES` trong `projector.py`.

Đọc `docs/adr/001-mutation-contract.md` trước khi làm.

### 5.3 Thêm module nghiệp vụ mới

Tạo package trong `lib/modules/<tên>/` implement `IZiiModule` (manifest, `tableNames`, `agentTools`, route, dashboard), đăng ký factory trong `module_registry.dart`. Nếu module cần phía server, thêm thư mục `server/modules/<tên>/manifest.json`.

### 5.4 Thêm endpoint server

- Chọn đúng loại secret/token theo mục 4.1.
- Trước khi đổi hành vi auth hoặc schema, đọc các test bảo mật — chúng **đóng vai trò đặc tả**: `test_phase0_security_regression.py`, `test_phase1_foundation.py`, `test_phase2_module_system.py`, `test_phase5_business_gate.py`, `test_p0_10_security_e2e.py` (nội dung: audit field, RLS/multi-tenancy, migration, seed, mô hình ba secret).

## 6. Kiểm thử

- **Flutter:** `flutter test`. Test hiện có nằm ở `test/core/` (community, database, security) và `test/modules/` (mushrooms, sales_crm, supply_chain, warehouse_automation).
- **Server:** `python -m unittest discover tests` (chạy trong `server/`). Ngoài các test bảo mật ở trên còn có test cho projector (`test_phase4_projector.py`), metadata API, workforce, radio/AGV gateway, grow rooms sync, manager batch attendance.

## 7. Quy ước & lưu ý

- Không sửa tay các thư mục/tệp sinh ra: `server/venv/`, `server/build/`, `server/dist/`, `build/`, `.dart_tool/`, `*.g.dart`, `*.freezed.dart`.
- Nhiều comment phía server (và một số phía client) viết bằng **tiếng Việt** để giải thích *vì sao* — ví dụ lý do dùng `after_seq` thay vì thời gian, lý do tách secret. Hãy đọc chúng trước khi đổi thiết kế.
- Phát triển tính năng riêng cho Farm làm trên `mushroom-farm-fork`; không để thay đổi Farm ảnh hưởng trực tiếp `main`. Cách cherry-pick về `main`: xem `MUSHROOM_FARM_BRANCH_GUIDE.md`.
- Checklist release Farm (từ `MUSHROOM_FARM_BRANCH_GUIDE.md`): test trên thiết bị/emulator, `flutter analyze`, build release thành công, kiểm tra tên app/icon/theme riêng, lưu bản build cùng version code/name, tạo tag/release nếu cần.

## 8. Tài liệu tham khảo trong repo

| Chủ đề | File |
|---|---|
| Quy trình nhánh Farm | `MUSHROOM_FARM_BRANCH_GUIDE.md` |
| Build lại server | `SERVER_REBUILD_GUIDE.md` |
| Build release Flutter | `FLUTTER_BUILD_RELEASE_GUIDE.md` |
| Installer Windows | `windows/installer/README.md` |
| Chuyển sang PostgreSQL | `server/HUONG_DAN_CHUYEN_DATABASE_POSTGRES.md`, `server/POSTGRES_MIGRATION_GUIDE.md` |
| Hợp đồng mutation | `docs/adr/001-mutation-contract.md` |
| Kiến trúc tổng quan, sync, bảo mật | `docs/Architecture_iZiiApp.md`, `docs/SYNC.md`, `docs/AUTH_AND_SECURITY_PLAN.md`, `docs/Database_Security_Guide.md` |
| Cài đặt / triển khai server | `server/SETUP.md`, `server/ENROLLMENT_SETUP.md`, `server/DIEM_DANH_SETUP.md` |
