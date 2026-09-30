Notification & Dữ liệu Window Action (Log issue) 
# Kế hoạch triển khai: Đồng bộ Notification & Dữ liệu Window Action (Log issue) giữa PC, iPad và Samsung

## 1. Mục tiêu & Hiện trạng

### Hiện trạng
- Tính năng **Window Action (Log issue)** trong màn hình Grow Room 3D hiện lưu trữ cục bộ 100% trong `SharedPreferences` với key `'izii_grow_room_window_issues_v1'`.
- `SyncService().queueMutation()` **không được gọi**, cơ sở dữ liệu Drift SQLite (Client) và PostgreSQL (Server) đều **chưa có bảng** lưu trữ `mushroom_window_issues`.
- Khi PC bấm tạo issue, chỉ có PC tự cập nhật chuông thông báo (Notification badge) cục bộ. iPad và Samsung không nhận được bất kỳ mutation nào từ server, dẫn đến lệch dữ liệu và không thể đồng bộ.

### Mục tiêu sau khi khắc phục
1. Dữ liệu **Window Action (Log issue)** được lưu trữ bền vững trong cơ sở dữ liệu Drift SQLite (Client) và PostgreSQL (Server).
2. Khi người dùng bấm **"Log Issue / Add Action"** trên bất kỳ thiết bị nào (PC, iPad hoặc Samsung):
   - Bản ghi được lưu vào SQLite cục bộ và tự động tạo mutation `mushroom_window_issues`.
   - Server tiếp nhận qua `/sync/push`, lưu vào PostgreSQL, và phát broadcast sự kiện `mushroom.window_issue_created` qua WebSocket.
   - Toàn bộ thiết bị còn lại tự động kéo dữ liệu (Pull) qua Sync Engine hoặc nhận WebSocket payload.
3. **Notification Badge** trên thanh AppBar (Home Screen) và thẻ Module Mushrooms tự động nhảy số theo thời gian thực (Real-time) trên tất cả các thiết bị.
4. Tự động di chuyển (migrate) dữ liệu sự cố cũ đang nằm trong `SharedPreferences` sang cơ sở dữ liệu để bảo toàn dữ liệu người dùng đã tạo trước đó.

---

## 2. Kế hoạch triển khai chi tiết

```mermaid
flowchart TD
    subgraph Client [Thiết bị tạo (PC hoặc iPad)]
        UI["Grow Room 3D (Log Issue Dialog)"] --> Service["WindowActionService.reportIssue()"]
        Service --> DBLocal[("Drift SQLite: mushroom_window_issues")]
        Service --> Queue["SyncService.queueMutation('mushroom_window_issues')"]
    end

    subgraph Server [iZiiServer (Backend)]
        Queue -->|HTTP POST /sync/push| PushRouter["Router: /sync/push"]
        PushRouter --> PG[("PostgreSQL: mushroom_window_issues")]
        PushRouter --> EventEngine["iZiiEventEngine: mushroom.window_issue_created"]
        EventEngine -->|WebSocket Broadcast| WSServer["WebSocket Hub"]
    end

    subgraph OtherClients [Thiết bị nhận (iPad / Samsung / PC)]
        WSServer -->|WS Event / Delta Pull| SyncServiceRecv["SyncService._upsertWindowIssue()"]
        SyncServiceRecv --> DBRemote[("Drift SQLite: mushroom_window_issues")]
        DBRemote --> NotifStream["WindowActionService.issuesStream"]
        NotifStream --> AppBarBadge["AppBar Notification Badge (Real-time)"]
    end
```

---

### Giai đoạn 1: Thiết kế Cơ sở dữ liệu trên PostgreSQL (Server)

1. **Tạo Migration PostgreSQL**:
   - File mới: `server/migrations/versions/0009_window_issues.sql`
   - Cấu trúc bảng `mushroom_window_issues`:
     ```sql
     CREATE TABLE IF NOT EXISTS mushroom_window_issues (
         id               TEXT PRIMARY KEY,
         room_name        TEXT NOT NULL,
         rack_index       INT DEFAULT 0,
         level_index      INT DEFAULT 0,
         window_index     INT DEFAULT 0,
         window_code      TEXT NOT NULL,
         category         TEXT NOT NULL,
         title            TEXT NOT NULL,
         description      TEXT,
         severity         TEXT DEFAULT 'normal',
         reporter_name    TEXT,
         status           TEXT DEFAULT 'open',
         temperature      REAL DEFAULT 19.0,
         humidity         REAL DEFAULT 90.0,
         co2              REAL DEFAULT 1150.0,
         casing_temp      REAL DEFAULT 19.5,
         created_at       TEXT,
         updated_at       TEXT,
         deleted_at       TIMESTAMPTZ,
         tenant_id        TEXT DEFAULT 'default',
         created_by       TEXT,
         updated_by       TEXT,
         last_seq         BIGINT,
         last_mutation_id TEXT
     );
     CREATE INDEX IF NOT EXISTS idx_win_issues_room ON mushroom_window_issues(room_name, status);
     ```
2. **Cập nhật Read-Model Projector & Event Engine**:
   - `server/projector.py`: Thêm ánh xạ logical alias `"window_issues": "mushroom_window_issues"`.
   - `server/event_engine.py`: Đăng ký Domain Event `"mushroom_window_issues": "mushroom.window_issue_created"` / `"mushroom.window_issue_updated"`.
3. **Thực thi Migration**:
   - Chạy migration runner để áp dụng bảng mới vào PostgreSQL database hiện hành (`postgresql://postgres:Admin@127.0.0.1:5432/iZiiApp`).

---

### Giai đoạn 2: Thiết kế Cơ sở dữ liệu Drift SQLite (Client Flutter)

1. **Khai báo bảng trong [tables.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/mushrooms/database/tables.dart)**:
   - Thêm lớp `MushroomWindowIssues`:
     ```dart
     class MushroomWindowIssues extends Table {
       TextColumn get id => text()(); // UUID / ACT-xxx
       TextColumn get roomName => text()();
       IntColumn get rackIndex => integer().withDefault(const Constant(0))();
       IntColumn get levelIndex => integer().withDefault(const Constant(0))();
       IntColumn get windowIndex => integer().withDefault(const Constant(0))();
       TextColumn get windowCode => text()();
       TextColumn get category => text()(); // disease, safety, qa, working, maintenance
       TextColumn get title => text()();
       TextColumn get description => text().nullable()();
       TextColumn get severity => text().withDefault(const Constant('normal'))();
       TextColumn get reporterName => text().nullable()();
       TextColumn get status => text().withDefault(const Constant('open'))();
       RealColumn get temperature => real().withDefault(const Constant(19.0))();
       RealColumn get humidity => real().withDefault(const Constant(90.0))();
       RealColumn get co2 => real().withDefault(const Constant(1150.0))();
       RealColumn get casingTemp => real().withDefault(const Constant(19.5))();
       DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
       DateTimeColumn get updatedAt => dateTime().nullable()();

       @override
       Set<Column> get primaryKey => {id};
     }
     ```
2. **Cập nhật [app_database.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/database/app_database.dart)**:
   - Thêm `MushroomWindowIssues` vào danh sách `tables`.
   - Nâng `schemaVersion` lên `32`.
   - Thêm câu lệnh xử lý nâng cấp an toàn trong `onUpgrade`:
     ```dart
     if (from < 32) {
       try {
         await m.createTable(mushroomWindowIssues);
       } catch (_) {}
     }
     ```
3. **Biên dịch mã Drift**:
   - Chạy `dart run build_runner build --delete-conflicting-outputs` để tạo tự động các lớp companion và DAO cho `MushroomWindowIssues`.

---

### Giai đoạn 3: Tích hợp Động cơ Đồng bộ (SyncService)

1. **Bổ sung bảng vào [sync_config_repository.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/sync/sync_config_repository.dart)**:
   - Gán `'mushroom_window_issues': 'mushroom_farm'` vào danh mục thực thể đồng bộ.
2. **Bổ sung xử lý PULL trong [sync_service.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/sync/sync_service.dart)**:
   - Thêm case `'mushroom_window_issues': return _upsertMushroomWindowIssue(data);`
   - Viết hàm `_upsertMushroomWindowIssue(Map<String, dynamic> data)`:
     - Hỗ trợ cả 2 định dạng trường camelCase (`roomName`) và snake_case (`room_name`).
     - Tự động thực hiện `insertOnConflictUpdate` vào bảng `mushroom_window_issues`.
   - Xử lý khi `operation == 'delete'`: xóa bản ghi trong bảng `mushroom_window_issues` tương ứng.
   - Kích hoạt `SyncEvent` chứa `'mushroom_window_issues'` để UI cập nhật tự động.

---

### Giai đoạn 4: Tái cấu trúc WindowActionService & Notification Real-Time

1. **Cập nhật [repository.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/mushrooms/repository.dart)**:
   - Thêm các hàm tương tác database:
     - `Future<List<WindowIssueReport>> getWindowIssues({String? roomName})`
     - `Stream<List<WindowIssueReport>> watchWindowIssues({String? roomName})`
     - `Future<void> saveWindowIssue(WindowIssueReport report, {bool isNew = true})`
     - `Future<void> deleteWindowIssue(String id)`
2. **Cải tiến [window_action_service.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/mushrooms/services/window_action_service.dart)**:
   - Thay thế việc ghi đọc trực tiếp từ `SharedPreferences` bằng database repository.
   - Trong `reportIssue()`:
     - Lưu vào database Drift.
     - Gọi `SyncService().queueMutation('mushroom_window_issues', 'insert', report.toJson())`.
   - Trong `updateIssueStatus()`:
     - Cập nhật trạng thái trong database.
     - Gọi `SyncService().queueMutation('mushroom_window_issues', 'update', {'id': issueId, 'status': newStatus, 'updated_at': nowIso})`.
   - Trong `deleteIssue()`:
     - Xóa khỏi database.
     - Gọi `SyncService().queueMutation('mushroom_window_issues', 'delete', {'id': issueId})`.
   - **Migration tự động**: Khi ứng dụng khởi chạy lần đầu với phiên bản mới, nếu phát hiện dữ liệu cũ trong `SharedPreferences` (`_prefKey`), tự động chuyển toàn bộ vào database và đồng bộ lên server.
   - Stream `issuesStream`: Lắng nghe reactive stream trực tiếp từ database hoặc sự kiện sync từ `SyncService`.

---

### Giai đoạn 5: Kiểm chứng & Đóng gói (Verification & Testing)

1. **Kiểm tra Unit Test của Server**:
   - Chạy `python -m unittest discover tests` đảm bảo 52/52 tests tiếp tục vượt qua 100%.
2. **Kiểm tra đồng bộ giữa các thiết bị**:
   - Kịch bản 1: Tạo một issue mới trên PC -> Xác nhận xuất hiện bản ghi trong PostgreSQL và có broadcast WebSocket.
   - Kịch bản 2: Thiết bị thứ hai (iPad / Samsung mô phỏng qua client test hoặc app) thực hiện Pull -> Xác nhận nhận được đúng issue và Notification badge tăng lên.
   - Kịch bản 3: Giải quyết sự cố (`status = 'resolved'`) -> Xác nhận Notification badge tự động giảm số trên cả 2 thiết bị.
3. **Biên dịch & Đóng gói**:
   - Rebuild lại Flutter Windows release: `flutter build windows --release`.
   - Đóng gói Inno Setup: `build_windows_installer.bat`.

---

## 3. Kế hoạch xác nhận (Verification Checklist)

| STT | Hạng mục kiểm tra | Phương pháp | Kết quả mong đợi |
|:---:|:---|:---|:---|
| 1 | Bảng PostgreSQL `mushroom_window_issues` | Chạy query SQL trên PostgreSQL | Bảng được tạo thành công với đầy đủ các cột và index |
| 2 | Bảng SQLite `MushroomWindowIssues` | Chạy `dart run build_runner build` | `app_database.g.dart` được cập nhật thành công, không có lỗi biên dịch |
| 3 | Xử lý Mutation trên Server | Gửi mutation giả lập qua `/sync/push` | Server nhận HTTP 200, lưu vào PostgreSQL, broadcast qua WebSocket |
| 4 | Xử lý PULL trên Client | Gọi `SyncService().pullDelta()` | Dữ liệu `mushroom_window_issues` được tải và lưu vào SQLite |
| 5 | Real-time Notification Badge | Kiểm tra UI `AppBar` trong `home_screen.dart` | Icon chuông 3D nhảy số tức thì khi có issue mới được thêm từ thiết bị khác |
| 6 | Trạng thái giải quyết (Resolved) | Đổi trạng thái sang `resolved` | Badge giảm số lượng tương ứng trên tất cả các máy |

---

Bạn có đồng ý với bản kế hoạch chi tiết trên để chúng ta bắt đầu tiến hành triển khai không? Vui lòng bấm **Proceed** hoặc phản hồi ý kiến của bạn.



Walkthrough:

# Kết quả khắc phục lỗi không đồng bộ Notification của Window Action (Log issue)

Đã hoàn thành phân tích log iZiiServer và xử lý triệt để nguyên nhân khiến **Window Action (Log issue)** cùng **Notification badge** không đồng bộ giữa PC, iPad và thiết bị di động (Samsung).

---

## 1. Nguyên nhân gốc rễ (Root Cause)

1. **Lưu trữ hoàn toàn cục bộ (Local-Only):**
   - Trước khi sửa, `WindowActionService` (`lib/modules/mushrooms/services/window_action_service.dart`) chỉ lưu trữ dữ liệu dạng JSON thô vào `SharedPreferences` cục bộ với key `'izii_grow_room_window_issues_v1'`.
   - `SyncService().queueMutation()` hoàn toàn không được tích hợp cho các thao tác Window Action (`reportIssue`, `updateIssueStatus`, `deleteIssue`).
2. **Thiếu bảng trên cả Server & Client Database:**
   - Server PostgreSQL và SQLite đều chưa từng có bảng `mushroom_window_issues`.
   - Client Drift Database (`AppDatabase`) chưa khai báo bảng `MushroomWindowIssues`.
3. **Hiện tượng thực tế:**
   - Khi tạo sự cố trên PC, chỉ PC tăng số lượng badge trên AppBar và Module Card.
   - Khi iPad hoặc Samsung mở ứng dụng, máy chỉ nạp 4 sự cố giả lập mẫu (`_createSeedIssues()`) từ bộ nhớ máy, hoàn toàn không nhận được cập nhật từ PC hay Server.

---

## 2. Các thay đổi và cải tiến đã thực hiện

### A. Phía Server (PostgreSQL, Sync Engine & Event Engine)
1. **Tạo Migration `0009_window_issues.sql`**:
   - File: [server/migrations/versions/0009_window_issues.sql](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/migrations/versions/0009_window_issues.sql)
   - Khởi tạo bảng `mushroom_window_issues` với đầy đủ 25 cột (bao gồm các chỉ số nhiệt độ, độ ẩm, CO2, casing, audit columns, RLS policy `tenant_isolation_policy`).
   - Đã áp dụng migration thành công vào PostgreSQL: `✅ Applied 0009_window_issues.sql`.
2. **Đăng ký Projection & Event Engine**:
   - [server/projector.py](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/projector.py): Thêm alias bảng `"window_issues": "mushroom_window_issues"`.
   - [server/event_engine.py](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/event_engine.py): Cấu hình domain events `"mushroom_window_issues"` -> `"mushroom.window_issue_created"` / `"mushroom.window_issue_updated"` phát qua WebSocket real-time.
   - [server/migrate_to_postgres.py](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/migrate_to_postgres.py): Đăng ký `("mushroom_window_issues", "id")` vào `TABLES`.
   - [server/db_init.py](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/db_init.py) & [server/db_init_postgres.py](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/server/db_init_postgres.py): Đăng ký bảng và audit columns vào danh sách `DOMAIN_TABLES`.
3. **Kiểm thử Server Suite**:
   - Chạy `python -m unittest discover tests` -> **62/62 tests PASS (100% OK)**.

---

### B. Phía Client Flutter (Drift Database, Sync Engine & Window Action Service)
1. **Khai báo bảng Drift và Migration**:
   - [lib/modules/mushrooms/database/tables.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/mushrooms/database/tables.dart): Thêm class `MushroomWindowIssues extends Table`.
   - [lib/core/database/app_database.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/database/app_database.dart):
     - Thêm `MushroomWindowIssues` vào `@DriftDatabase`.
     - Nâng `schemaVersion` lên **32**.
     - Thêm bước migration `if (from < 32) await m.createTable(mushroomWindowIssues);` và câu lệnh an toàn trong `beforeOpen`.
   - Chạy `build_runner` sinh mã nguồn `MushroomWindowIssue` và `MushroomWindowIssuesCompanion` trong `app_database.g.dart`.
2. **Đăng ký module mapping & sync engine**:
   - [lib/core/sync/sync_config_repository.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/sync/sync_config_repository.dart): Ánh xạ `'mushroom_window_issues': 'mushroom_farm'`.
   - [lib/core/sync/sync_service.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/core/sync/sync_service.dart):
     - Thêm xử lý `delete` và `upsert` cho bảng `mushroom_window_issues` trong `_applyServerUpdate`.
     - Triển khai hàm `_upsertMushroomWindowIssue(data)` hỗ trợ cả camelCase và snake_case.
3. **Repository & WindowActionService 2 chiều**:
   - [lib/modules/mushrooms/repository.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/mushrooms/repository.dart): Thêm các hàm `getWindowIssues()`, `watchWindowIssues()`, `saveWindowIssue()`, `updateWindowIssueStatus()`, `deleteWindowIssue()`.
   - [lib/modules/mushrooms/services/window_action_service.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/mushrooms/services/window_action_service.dart):
     - Chuyển đổi toàn bộ lưu trữ sang database SQLite thông qua `MushroomsRepository`.
     - Tự động di chuyển (auto-migrate) dữ liệu cũ từ `SharedPreferences` sang SQLite database và đồng bộ lên server ở lần khởi động đầu tiên.
     - Trên các thao tác `reportIssue`, `updateIssueStatus`, `deleteIssue`: lưu vào DB, gọi `SyncService().queueMutation()` và lập tức gọi `SyncService().flushOutbox()` để đẩy dữ liệu lên server (< 1s).
     - Lắng nghe `watchWindowIssues()` và `SyncService().syncEventStream` để cập nhật `issuesStream` ngay khi bất kỳ thiết bị nào khác cập nhật sự cố.
     - Notification badge trên AppBar và Module Card trên màn hình Home sẽ tự động nhảy số theo thời gian thực (real-time) trên mọi thiết bị kết nối.
4. **Sửa lỗi cú pháp tồn đọng**:
   - Đã xử lý lỗi UTF-8 và cú pháp thừa trong [lib/modules/mushrooms/screens/mushrooms_auth_screen.dart](file:///C:/Users/CHANH/OneDrive/Documents/Downloads/Compressed/izii_app/lib/modules/mushrooms/screens/mushrooms_auth_screen.dart), đưa file về trạng thái chuẩn xác 100%.

---

## 3. Quy trình đồng bộ thực tế giữa PC, iPad và Samsung

```mermaid
sequenceDiagram
    autonumber
    actor Staff as Nhân viên (PC / iPad)
    participant UI as Window Action Screen
    participant WAS as WindowActionService
    participant DB as Client SQLite (Drift)
    participant Sync as SyncService (Outbox)
    participant Svr as iZiiServer (PostgreSQL)
    participant Other as iPad / Samsung

    Staff->>UI: Báo cáo sự cố (Log Issue)
    UI->>WAS: reportIssue(...)
    WAS->>DB: saveWindowIssue(...)
    WAS->>Sync: queueMutation('mushroom_window_issues', 'insert', data)
    WAS->>Sync: flushOutbox()
    Sync->>Svr: POST /sync/push (mutations)
    Svr->>Svr: Ghi vào PostgreSQL & sync_mutations
    Svr-->>Other: WebSocket broadcast domain event
    Other->>Svr: Sync pull (delta)
    Other->>DB: _upsertMushroomWindowIssue(...)
    Other->>WAS: Drift watchWindowIssues() trigger
    WAS-->>Other: issuesStream phát danh sách mới
    Other->>Staff: Notification Badge nhảy số ngay lập tức!
```
