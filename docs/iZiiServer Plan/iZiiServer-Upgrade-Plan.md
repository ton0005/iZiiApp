# Kế hoạch Nâng cấp iZiiServer

**Nền tảng độc lập — học có chọn lọc từ Smartstore và Odoo**

| | |
| :--- | :--- |
| **Phiên bản tài liệu** | 2.0.0 |
| **Ngày lập** | 08/09/2026 |
| **Thay đổi so với v1.0.0** | **Bỏ hoàn toàn phụ thuộc Smartstore và Odoo.** Hai framework chỉ còn vai trò tham khảo kiến trúc. iZiiServer trở thành hệ thống độc lập, tự sở hữu dữ liệu |
| **Trạng thái** | Kế hoạch triển khai — chờ chốt 5 quyết định ở §11 |
| **Đối tượng đọc** | Team Dev iZiiServer, team Dev Flutter, PM |
| **Nguồn phân tích** | ~245.000 dòng `server.log` (V1.0.20, V1.0.34–36) · 2 file database thực tế · `Mushroom_Joblist.md` · `iziiapp_cqrs_pgvector_architecture.md` v2.0.0 · tài liệu kiến trúc Smartstore & Odoo (tham khảo) |

---

## Mục lục

- [0. Tóm tắt điều hành](#0-tóm-tắt-điều-hành)
- [1. Định vị iZiiServer](#1-định-vị-izii-server)
- [2. Học gì từ Smartstore và Odoo](#2-học-gì-từ-smartstore-và-odoo)
- [3. Bảy nguyên tắc thiết kế](#3-bảy-nguyên-tắc-thiết-kế)
- [4. Kiến trúc mục tiêu](#4-kiến-trúc-mục-tiêu)
- [5. Phạm vi](#5-phạm-vi)
- [6. Lộ trình 8 giai đoạn](#6-lộ-trình-8-giai-đoạn)
- [7. Đặc tả kỹ thuật](#7-đặc-tả-kỹ-thuật)
- [8. Sổ đăng ký lỗi](#8-sổ-đăng-ký-lỗi)
- [9. Migration & dọn dữ liệu](#9-migration--dọn-dữ-liệu)
- [10. Kiểm thử & tiêu chí nghiệm thu](#10-kiểm-thử--tiêu-chí-nghiệm-thu)
- [11. Quyết định cần chốt & rủi ro](#11-quyết-định-cần-chốt--rủi-ro)
- [12. Phụ lục](#12-phụ-lục)

---

## 0. Tóm tắt điều hành

### 0.1. Quyết định

**iZiiServer là hệ thống độc lập và là nguồn sự thật duy nhất của toàn bộ hệ sinh thái iZiiApp.** Không tích hợp Smartstore, không tích hợp Odoo, không phụ thuộc bất kỳ hệ thống ngoài nào.

Hai framework đó được dùng **chỉ như nguồn tham khảo kiến trúc**: chúng đã giải xong nhiều bài toán mà iZiiServer sắp gặp — mở rộng schema không cần migration, cấu hình phân theo phạm vi, hook nghiệp vụ khi dữ liệu đổi, phân quyền theo dòng, nhật ký thay đổi tự động. Ta lấy **ý tưởng**, không lấy **mã nguồn** và không lấy **phụ thuộc runtime**.

### 0.2. Ba trụ cột của bản nâng cấp

| Trụ cột | Nội dung | Nguồn cảm hứng |
| :--- | :--- | :--- |
| **1 · Sửa nền móng** | Write path đang có 4 lỗi làm hỏng dữ liệu thật. Phải sửa trước mọi thứ khác. | — (từ phân tích log) |
| **2 · Kiến trúc mở rộng được** | Module system + metadata-driven field registry + hooks. Thêm loại job, thêm trường, đổi màu phòng — **không cần build lại app Flutter**. | Smartstore (module, ISettings, DbSaveHook) + Odoo (ir.model, ir.rule, audit) |
| **3 · Hoàn thiện miền nghiệp vụ** | Chấm công, an toàn Alone Worker, 6 bảng đang không đồng bộ. | — (từ kiểm kê module) |

### 0.3. Điều quan trọng nhất — ý tưởng đáng giá nhất lấy từ Odoo

**Server khai báo mô hình dữ liệu và giao diện; client render theo khai báo đó.**

Hiện tại, để thêm một loại job mới (`clean_bed`, `clean_room`) hoặc đổi màu Grow Room, bạn phải sửa Dart, build lại app, phát hành lên store, và chờ 60.000 thiết bị cập nhật. Kết quả thực tế đã thấy trong log: bản Desktop cũ nhận đúng `current_stage = clean_room` nhưng **không đổi màu** vì bảng ánh xạ màu nằm cứng trong client (lỗi F1).

Sau nâng cấp: loại job và màu là **dữ liệu** trong bảng `model_registry` / `field_registry`, đẩy xuống thiết bị như mọi bản ghi khác. Thêm job type mới = thêm một dòng trong admin. Không build, không phát hành, không chờ.

Đây cũng chính là tính năng **"New Job có mục custom"** đã đề xuất trước đó — nhưng giải ở tầng kiến trúc thay vì hardcode thêm một trường hợp nữa.

### 0.4. Con số

| | |
| :--- | :--- |
| Tổng thời gian | **16–19 tuần** (~4 tháng) |
| Nhân lực đề xuất | 2 BE (Python/Postgres) · 1,5 Flutter · 0,5 DevOps |
| Lỗi phải sửa | **18** (10 từ log, 3 từ kiểm kê module, 5 từ duyệt blueprint) |
| Ý tưởng lấy từ Smartstore | 7 lấy · 1 loại bỏ |
| Ý tưởng lấy từ Odoo | 6 lấy · 2 loại bỏ |
| Phụ thuộc runtime bên ngoài | **0** |
| Chặn phát hành | Phase 0 chặn tất cả các phase còn lại |

### 0.5. Ba việc quan trọng nhất

1. **Phase 0 — sửa write path.** Bốn lỗi trong production (batch 409 nguyên gói, timestamp local naive, UPDATE không có INSERT, khoá ngoại bị rơi) đang âm thầm làm hỏng dữ liệu. Mọi thứ xây thêm lên trên đều kế thừa cái sai đó.
2. **Metadata-driven schema (Phase 3)** — mở khoá khả năng mở rộng mà không cần phát hành app. Đây là thứ quyết định iZiiServer có bán được cho khách hàng thứ hai hay không.
3. **Khối chấm công (Phase 5)** — `mushroom_attendance_events` và `mushroom_daily_timesheets` đang 0 dòng, chặn cùng lúc: job Alone Worker (server từ chối "chưa điểm danh"), Dashboard hiệu suất, và bài toán lương.

---

## 1. Định vị iZiiServer

### 1.1. iZiiServer là gì

**Nền tảng dữ liệu offline-first cho vận hành hiện trường và bán lẻ phân tán.**

Bốn năng lực cốt lõi mà không framework nào sẵn có cho không:

| Năng lực | Vì sao không mua sẵn được |
| :--- | :--- |
| **Đồng bộ offline-first hai chiều** | Mọi ERP/e-commerce phổ biến đều là request-response đồng bộ. Mutation log, con trỏ tuần tự, tombstone, snapshot bootstrap, phát hiện xung đột — phải tự xây |
| **Khoá chính do thiết bị tự sinh (UUID)** | Thiết bị offline phải tự cấp id mà không hỏi server. Mọi hệ dùng `int` identity đều không làm được |
| **Chạy được khi mất Internet** | Node LAN tại site giữ toàn bộ nghiệp vụ chạy suốt thời gian mất WAN |
| **Miền nghiệp vụ hiện trường** | Grow Room, Alone Worker, CO/CO₂, timeout an toàn, chấm công theo ca — không có trong bất kỳ sản phẩm thương mại nào |

### 1.2. iZiiServer KHÔNG là gì

- Không phải ERP kế toán. Không làm sổ cái, không làm thuế, không làm báo cáo tài chính chuẩn mực.
- Không phải nền tảng e-commerce. Không làm storefront, không làm SEO, không làm cổng thanh toán.
- Không phải BI. Báo cáo nằm ở mức vận hành (dashboard ca làm việc), không phải phân tích đa chiều.

Ba mảng trên, nếu khách hàng cần, **xuất dữ liệu ra** qua API công khai (§6 Phase 6) chứ iZiiServer không tự làm.

### 1.3. Vì sao độc lập là lựa chọn đúng

| Lý do | Giải thích |
| :--- | :--- |
| **Bỏ được hạng mục đắt nhất** | ETL hai chiều giữa ba hệ (catalog, đơn hàng, tồn kho, id mapping) là phần đắt nhất của kiến trúc trước — đắt hơn cả bản thân iZiiServer |
| **Không còn bài toán ba writer** | Một chủ sở hữu duy nhất cho mỗi bản ghi. Không cần bảng `id_map`, không cần `routing_rules`, không cần trọng tài |
| **Không kế thừa lịch trình của bên khác** | Không phải chờ team Smartstore bổ sung endpoint ghi, không phải chờ quyền JSON-RPC trên Odoo |
| **Bán được như sản phẩm riêng** | Với module system (Phase 2), iZiiApp bán được cho khách không dùng Smartstore/Odoo |
| **Một mô hình khoá chính duy nhất** | UUID xuyên suốt. Không còn bài toán ánh xạ `UUID ↔ int` |

### 1.4. Cửa thoát cho tích hợp sau này

Độc lập **không có nghĩa là đóng**. Giữ một khe tích hợp tối thiểu để không tự nhốt mình:

```sql
-- Bảng tuỳ chọn. KHÔNG dùng ở giai đoạn này. Chỉ để không phải sửa schema về sau.
CREATE TABLE external_refs (
    tenant_id   TEXT NOT NULL,
    entity      TEXT NOT NULL,           -- 'product' | 'order' | 'employee'
    local_uuid  TEXT NOT NULL,
    system      TEXT NOT NULL,           -- tên hệ ngoài, tự do
    external_id TEXT NOT NULL,
    synced_at   TIMESTAMPTZ,
    PRIMARY KEY (tenant_id, entity, local_uuid, system)
);
```

Cùng với API công khai ở Phase 6 (webhook + REST đọc), bất kỳ hệ nào cũng nối vào được sau này mà **không cần sửa lõi**.

---

## 2. Học gì từ Smartstore và Odoo

Đây là phần trọng tâm của bản v2.0.0. Hai framework này đã chạy production hàng chục năm và đã giải xong nhiều bài toán iZiiServer sắp gặp. Ta lấy ý tưởng đã được kiểm chứng, bỏ những thứ không hợp với mô hình offline-first.

### 2.1. Lấy từ Smartstore (.NET 10 · Modular Monolith · DDD)

| # | Ý tưởng | Nguyên bản | Áp dụng vào iZiiServer | Phase |
| :--- | :--- | :--- | :--- | :--- |
| **S1** | **Module system có manifest & vòng đời** | `module.json` + `Module.cs` + `Startup.cs`, cài/gỡ được, tự đăng ký DI | `modules/mushroom/`, `modules/retail/`, `modules/service/` — mỗi module có manifest, migration riêng, bảng riêng, route riêng. Bật/tắt theo tenant | **P2** |
| **S2** | **`GenericAttribute` — EAV động** | Thêm thuộc tính cho bất kỳ entity nào mà không `ALTER TABLE` | Bảng `entity_attributes` cho thuộc tính riêng của từng khách hàng. **Giới hạn:** chỉ dùng cho trường tuỳ biến, không dùng cho trường lõi | **P3** |
| **S3** | **`ISettings` — cấu hình strongly-typed, phân phạm vi** | Class C# lưu key-value, override theo `StoreId` | Bảng `settings` với scope `global / tenant / site / device`. Thay thế mô hình chỉ-env-var hiện tại | **P3** |
| **S4** | **`DbSaveHook` — hook trước/sau commit** | Kích hoạt logic nghiệp vụ tự động khi dữ liệu đổi | Hook engine: `on_job_started` → tạo safety config; `on_job_completed` → reset `current_stage`; `on_checkin_missed` → báo động | **P4** |
| **S5** | **Bounded Context** | `Catalog`, `Checkout`, `Customers`, `Stores` tách bạch | `core/` (sync, device, auth) · `field_ops/` (job, room, safety) · `workforce/` (chấm công, ca) · `inventory/` · `commerce/` | **P2** |
| **S6** | **Migration có version + seeder** | `FluentMigrator` timestamp + `DataSeeder` | Formalize `001_purge_naive_timestamps`, `002_backfill_mutation_seq` thành framework: mỗi module có thư mục `migrations/`, chạy theo thứ tự, idempotent | **P1** |
| **S7** | **`LocalizedProperty` — đa ngôn ngữ theo trường** | Bảng riêng lưu bản dịch cho từng trường của từng entity | Bảng `translations` cho tên job, tên phòng, nhãn trường. App Việt–Anh không cần hardcode | **P3** |
| **✕** | **Khoá chính `int` identity** | Tối ưu index B-Tree trên DB tập trung | **KHÔNG LẤY.** Offline-first bắt buộc UUID do thiết bị tự sinh | — |

### 2.2. Lấy từ Odoo (Python · PostgreSQL · Metadata-Driven ERP)

| # | Ý tưởng | Nguyên bản | Áp dụng vào iZiiServer | Phase |
| :--- | :--- | :--- | :--- | :--- |
| **O1** | **Trường audit tự động trên mọi bản ghi** | `create_uid`, `create_date`, `write_uid`, `write_date` | Thêm `created_by`, `created_at`, `updated_by`, `updated_at`, `last_mutation_id` vào **mọi** bảng, do framework ghi tự động. Giải quyết tận gốc lớp lỗi "không truy được dữ liệu sai đến từ đâu" | **P1** |
| **O2** | **Metadata model registry** | `ir.model`, `ir.model.fields` — schema là dữ liệu | `model_registry` + `field_registry`: khai báo entity, trường, kiểu, ràng buộc, nhãn, **màu**. Lát mỏng có chủ đích, không xây lại cả ORM | **P3** |
| **O3** | **Model-driven UI** | Server khai báo view; client render | Server đẩy `ui_descriptor` cho mỗi loại job/form. **Thêm job type mới không cần build lại app Flutter.** Giải luôn lỗi F1 (thiếu màu cho `clean_bed`/`clean_room`) | **P3** |
| **O4** | **`ir.rule` — record rule khai báo** | Bộ lọc bảo mật dòng bằng domain expression ở tầng ORM | Bảng `record_rules` với biểu thức JSON, áp tự động vào mọi query. Thay thế `RecordSharingPermissions` (đang 0 dòng) và bổ trợ RLS của Postgres | **P3** |
| **O5** | **`mail.thread` / chatter — nhật ký thay đổi theo bản ghi** | Lịch sử thay đổi trường + thảo luận gắn vào từng record | **Đã có sẵn nguyên liệu:** `sync_mutations` chính là nhật ký này. Chỉ cần API `GET /records/{table}/{id}/history` để đọc ra. Rẻ, và là công cụ audit cho hồ sơ an toàn lao động | **P4** |
| **O6** | **Seed data khai báo có cờ `noupdate`** | Dữ liệu tĩnh nạp từ XML/CSV, đánh dấu không ghi đè khi nâng cấp | Seed dạng YAML/JSON trong mỗi module + cột `is_seed`. Giải quyết lỗi M3 (22 đội hái, 3 bộ phận, 15 tin nhắn là seed nhưng bị đếm như dữ liệu thật) | **P1** |
| **O7** | **`_inherit` — module sau mở rộng model của module trước** | `_inherit = 'res.partner'` để thêm trường mà không gãy module cũ | Dạng nhẹ: module khai báo `extends: "core.employee"` và bổ sung trường qua `field_registry` + `entity_attributes` | **P2** |
| **✕** | **Tự động `ALTER TABLE` khi khởi động** | Odoo so khớp model Python với DB và tự sửa schema | **KHÔNG LẤY — nguy hiểm.** 60.000 thiết bị đang giữ SQLite cục bộ với schema riêng. Đổi schema phải được version hoá và **thương lượng** với client, không được áp tự động | — |
| **✕** | **ORM metadata-driven đầy đủ** | Toàn bộ menu, view, quyền đều là bản ghi trong bảng meta | **KHÔNG LẤY toàn bộ.** Đây là công trình nhiều năm. Chỉ lấy lát mỏng ở O2/O3/O4 | — |

### 2.3. Bảng đối chiếu: vấn đề hiện có → giải pháp mượn

| Vấn đề thực tế đã quan sát được | Ý tưởng mượn | Kết quả |
| :--- | :--- | :--- |
| F1 · Desktop không đổi màu phòng cho `clean_bed`/`clean_room` vì map màu nằm cứng trong client | **O3** Model-driven UI | Màu là dữ liệu server đẩy xuống. Thêm job type = thêm 1 dòng |
| Yêu cầu "New Job có mục custom" | **O2 + S2** Field registry + EAV | Khách tự định nghĩa loại job và trường riêng |
| M1 · `job_id`, `worker_id` bị rơi, không truy được nguồn | **O1 + O5** Audit fields + record history | Mọi dòng biết ai ghi, mutation nào ghi, đổi gì |
| M3 · Không phân biệt được seed và dữ liệu vận hành | **O6** Seed có `noupdate` | Báo cáo không đếm nhầm |
| F10 · `IZIIAPP_ADMIN_SECRET` chưa đặt, dùng chung token | **S3** Typed settings có scope | Cấu hình là first-class, có validation, admin sửa được |
| Alone Worker cần logic hẹn giờ + báo động | **S4** Save hooks | Logic khai báo, test được, không rải rác trong endpoint |
| `RecordSharingPermissions` 0 dòng, phân quyền chưa chạy | **O4** Record rules | Phân quyền khai báo, áp tự động |
| 19 bảng mushroom trộn lẫn với core | **S1 + S5** Module + bounded context | Bán được cho khách không nuôi nấm |
| Migration ad-hoc (`001_`, `002_` rời rạc) | **S6** Migration framework | Có thứ tự, idempotent, rollback được |

---

## 3. Bảy nguyên tắc thiết kế

Bảy nguyên tắc dưới đây ràng buộc mọi quyết định kỹ thuật. Thiết kế vi phạm là thiết kế sai.

**NT-1 · iZiiServer là nguồn sự thật duy nhất.**
Không phụ thuộc runtime vào hệ thống ngoài. Tích hợp, nếu có, đi qua API công khai và webhook — một chiều, tuỳ chọn, không nằm trên đường găng.

**NT-2 · Push là partial commit, không bao giờ all-or-nothing.**
Một item vi phạm quy tắc nghiệp vụ không được làm hỏng những item hợp lệ cùng batch.

**NT-3 · Không bao giờ upsert từ payload thiếu cột.**
UPDATE partial phải merge theo cột. UPDATE cho bản ghi chưa tồn tại phải yêu cầu bản đầy đủ, tuyệt đối không tạo stub.

**NT-4 · Đồng hồ của hệ thống là `seq` do server cấp, không phải timestamp của client.**
Mọi so sánh thứ tự, mọi LWW, mọi chống replay đều dùng `seq`. Timestamp chỉ để hiển thị.

**NT-5 · Thay đổi hành vi ưu tiên bằng dữ liệu, không bằng phát hành app.**
Thêm loại job, đổi màu, thêm trường, đổi quy tắc phân quyền — tất cả phải làm được qua cấu hình. Chỉ sửa mã khi thật sự cần logic mới.

**NT-6 · Thay đổi schema phải được version hoá và thương lượng.**
Client khai báo `schema_version` khi kết nối; server trả về những gì client hiểu được. **Không bao giờ tự `ALTER TABLE`** kiểu Odoo — 60.000 thiết bị đang giữ SQLite cục bộ.

**NT-7 · Mọi lỗi phải nhìn thấy được.**
Không có `except: return []`. Không có `status='rejected'` nằm im. Mọi mutation thất bại phải vào dead-letter kèm lý do, và phải có nơi để người vận hành nhìn thấy.

---

## 4. Kiến trúc mục tiêu

### 4.1. Topology

```
┌──────────────────────────────────────────────────────────────────────┐
│  THIẾT BỊ (iZiiApp — Flutter/Drift, SQLite, UUID)                   │
│  · Render UI theo ui_descriptor server đẩy xuống  ← O3               │
│  · Ghi offline 100%, hàng đợi outbox                                 │
└───────────────────────────────┬──────────────────────────────────────┘
                                │  /sync/push · /sync/pull · /snapshot
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  iZiiSERVER — EDGE NODE (mỗi site 1 node, LAN, SQLite/Postgres nhẹ)  │
│  · sync_mutations · device registry · hook engine                    │
│  · toàn bộ nghiệp vụ chạy được khi mất WAN                           │
└───────────────────────────────┬──────────────────────────────────────┘
                                │  peer-sync (đã có: server_id / zone)
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  iZiiSERVER — CENTRAL NODE (PostgreSQL 16+ · pgvector)              │
│                                                                      │
│  ┌── core/ ─────────────┐  ┌── modules/ ──────────────────────────┐ │
│  │ sync_mutations       │  │ mushroom/   field_ops               │ │
│  │ devices · auth       │  │ retail/     bán hàng · tồn kho      │ │
│  │ model_registry   ←O2 │  │ workforce/  chấm công · ca          │ │
│  │ field_registry   ←O2 │  │ service/    dịch vụ · lịch hẹn      │ │
│  │ settings         ←S3 │  │                                     │ │
│  │ record_rules     ←O4 │  │ mỗi module: manifest · migrations · │ │
│  │ entity_attributes←S2 │  │ bảng riêng · hooks · seed           │ │
│  │ translations     ←S7 │  │                          ↑ S1       │ │
│  │ hooks registry   ←S4 │  └─────────────────────────────────────┘ │
│  └──────────────────────┘                                           │
│                                                                      │
│  · read model + snapshot API · embedding queue · vector SOP         │
│  · API công khai + webhook (cửa tích hợp tuỳ chọn)                  │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.2. Bounded context (mượn S5)

| Context | Nội dung | Bảng chính |
| :--- | :--- | :--- |
| `core/` | Đồng bộ, thiết bị, xác thực, metadata, cấu hình | `sync_mutations`, `devices`, `model_registry`, `field_registry`, `settings`, `record_rules`, `entity_attributes`, `translations` |
| `modules/field_ops/` | Vận hành hiện trường | `grow_rooms`, `jobs`, `job_safety_configs`, `safety_checkin_logs`, `maintenance_tickets` |
| `modules/workforce/` | Nhân sự & chấm công | `employees`, `departments`, `attendance_events`, `daily_timesheets`, `break_policies`, `shifts`, `teams` |
| `modules/inventory/` | Kho & sản phẩm | `products`, `stock_quants`, `stock_moves`, `yield_surveys` |
| `modules/commerce/` | Bán hàng | `orders`, `order_lines`, `customers`, `price_lists` |
| `modules/collab/` | Trao đổi & công việc | `projects`, `tasks`, `chat_messages` |

> Bảng `mushroom_*` hiện tại đổi tên bỏ tiền tố, chuyển vào `modules/field_ops/` và `modules/workforce/`. Tiền tố `mushroom_` khoá sản phẩm vào một ngành — bỏ nó là điều kiện để bán cho khách hàng thứ hai.

### 4.3. Cấu trúc module (mượn S1)

```
modules/field_ops/
├─ manifest.json           # tên, version, phụ thuộc, bảng sở hữu, bật/tắt theo tenant
├─ migrations/
│  ├─ 001_create_grow_rooms.sql
│  └─ 002_add_stage_color.sql
├─ models/                 # khai báo entity → nạp vào model_registry
│  ├─ grow_room.yaml
│  └─ job.yaml
├─ hooks/                  # đăng ký vào hook engine
│  ├─ on_job_started.py
│  └─ on_checkin_missed.py
├─ seed/
│  └─ job_types.yaml       # noupdate: true
├─ routes.py
└─ services.py
```

**`manifest.json` mẫu:**

```json
{
  "name": "field_ops",
  "version": "1.0.0",
  "display_name": { "vi": "Vận hành hiện trường", "en": "Field Operations" },
  "depends": ["core", "workforce"],
  "owns_tables": ["grow_rooms", "jobs", "job_safety_configs", "safety_checkin_logs"],
  "extends": [],
  "min_client_schema_version": 12,
  "enabled_by_default": false
}
```

---

## 5. Phạm vi

### 5.1. Giữ (đã có, cần củng cố)

| Hạng mục | Trạng thái hiện tại |
| :--- | :--- |
| `sync_mutations` — write path append-only | Chạy tốt, 912 mutation trong DB mẫu |
| `/sync/push`, `/sync/pull` (`after_seq`) | Chạy; V1.0.36 đã chuyển `after_seq` — 8.409/8.626 lượt pull |
| Device registry, token auth | Chạy, nhưng `user_id` đang gán bằng `device_id` (lỗi F7) |
| WebSocket realtime + event engine | Chạy, đã hết lỗi 403 |
| Peer-sync giữa các node (`server_id` / `zone`) | Có sẵn, chưa dùng thật, cấu hình peer sai dải mạng |
| Miền mushroom: `jobs`, `grow_rooms` | Chạy & đồng bộ thật |

### 5.2. Thêm mới

| Hạng mục | Nguồn | Phase |
| :--- | :--- | :--- |
| Module system + manifest + lifecycle | S1 | P2 |
| `model_registry` + `field_registry` | O2 | P3 |
| `ui_descriptor` (model-driven UI) | O3 | P3 |
| `entity_attributes` (EAV có giới hạn) | S2 | P3 |
| `settings` (typed, có scope) | S3 | P3 |
| `record_rules` | O4 | P3 |
| `translations` | S7 | P3 |
| Hook engine + `hook_registry` | S4 | P4 |
| Trường audit trên mọi bảng | O1 | P1 |
| API `GET /records/{table}/{id}/history` | O5 | P4 |
| Migration framework có version | S6 | P1 |
| Seed khai báo + cờ `is_seed` | O6 | P1 |
| `attendance_events`, `daily_timesheets`, `break_policies` (đã có schema, 0 dòng) | — | P5 |
| `projection_checkpoint` | — | P4 |
| `embedding_queue` | — | P7 |
| `external_refs` (tuỳ chọn, chưa dùng) | — | P6 |

### 5.3. Điều chỉnh so với blueprint CQRS v2.0.0

| Blueprint đề xuất | Quyết định | Lý do |
| :--- | :--- | :--- |
| 60+ bảng quan hệ dựng một lượt | **Dựng theo module, từng miền một** | Module system cho phép sequencing. Không phải làm hết trước khi dùng được |
| Báo cáo tài chính toàn chuỗi | **Cắt** | iZiiServer không phải ERP kế toán. Xuất dữ liệu qua API cho hệ BI |
| pgai / vectorizer service | **Cắt** | Repo archive 27/05/2026, không còn bảo trì từ 02/2026 |
| Hàm LLM trong database | **Cắt** | Tiger Cloud gỡ từ 30/06/2026; và gọi HTTP trong transaction là sai nguyên tắc |
| pgvectorscale | **Hoãn** | Chưa cần dưới 5 triệu vector; không chạy trên RDS/Aurora |
| `vector(768)` | **Đổi `halfvec(768)`** | Giảm ~50% dung lượng, recall giảm không đáng kể |
| Tính RAM 2M × 3,14 KB ≈ 6,28 GB | **Sửa: ~14 GB** | HNSW của pgvector lưu bản sao đầy đủ vector **trong index**: ~3,7–3,8 KB/vector + bảng ~3,2 KB/vector |

---

## 6. Lộ trình 8 giai đoạn

| Phase | Tên | Thời gian | Phụ thuộc | Nhân lực |
| :--- | :--- | :--- | :--- | :--- |
| **0** | Ổn định write path | 2 tuần | **Chặn tất cả** | 2 BE + 1 FE |
| **1** | Nền tảng: audit, migration, seed, bảo mật | 2 tuần | Sau P0 | 1 BE + 0,5 DevOps |
| **2** | Module system & bounded context | 3 tuần | Sau P1 | 2 BE |
| **3** | Metadata, EAV, Settings, Record Rules | 3 tuần | Sau P2 | 2 BE + 1 FE |
| **4** | Projector, Snapshot, Hook engine | 3 tuần | Sau P1 | 1 BE |
| **5** | Miền hiện trường: chấm công & an toàn | 3 tuần | Sau P0 (song song P2–P4) | 1 BE + 1 FE |
| **6** | Topology hai tầng & API công khai | 2 tuần | Sau P2 | 1 BE + 0,5 DevOps |
| **7** | AI: embedding & hybrid search | 2 tuần | Sau P4 | 1 BE |
| **⊙** | Vận hành & quan sát | Xuyên suốt | — | 0,5 DevOps |

**Đường găng:** P0 → P1 → P2 → P3 = 10 tuần. P4, P5 song song. P6, P7 sau. Tổng **16–19 tuần**.

---

### Phase 0 — Ổn định write path

> **2 tuần · chặn toàn bộ · không được bỏ qua**

Bốn lỗi dưới đây đang âm thầm làm hỏng dữ liệu thật. Mọi kiến trúc xây thêm lên trên đều kế thừa cái sai đó.

| ID | Việc | DoD |
| :--- | :--- | :--- |
| **P0.1** | **Chốt mutation contract.** ADR trả lời: client gửi full-row hay dirty-field? Nếu dirty-field, trường nào luôn bắt buộc có? | ADR được duyệt bởi cả BE và FE; lưu ở `docs/adr/001-mutation-contract.md` |
| **P0.2** | **Partial commit cho `/sync/push`.** Bỏ 409 all-or-nothing. Trả `{accepted, rejected}` với HTTP 200. | Test: batch 18 item có 1 item vi phạm → 17 commit, 1 dead-letter, response liệt kê đúng |
| **P0.3** | **Chuẩn hoá UTC.** Client gửi `toUtc().toIso8601String()`. Server **từ chối** timestamp naive thay vì lặng lẽ ép kiểu. | Test: gửi `2026-08-26T12:52:07` → 400 `E_NAIVE_TIMESTAMP`. `latency.log` hết giá trị âm |
| **P0.4** | **Xử lý sequence gap.** `/sync/pull` chỉ trả seq nhỏ hơn watermark `pg_snapshot_xmin(pg_current_snapshot())`. | Test đồng thời 50 transaction: client không bỏ sót mutation nào |
| **P0.5** | **Thêm `last_seq` + `last_mutation_id`** vào mọi bảng read model. | Migration chạy được; projector ghi đủ hai trường |
| **P0.6** | **Outbox có retry.** `status='rejected'` phải kèm `reason`, backoff, và hiển thị được cho người dùng. | Test: mutation bị từ chối → retry 3 lần → dead-letter → UI hiện cảnh báo |
| **P0.7** | **Sửa 401 trên `/sessions/current`, `/sessions/active`, `/devices/me`.** | Client đọc được trạng thái điểm danh; nút Start Alone Worker bị vô hiệu hoá ở UI khi chưa điểm danh |

**Bằng chứng vì sao P0.2 và P0.7 phải đi cùng nhau:**

```
📥 [PUSH] Received 18 changes at 2026-08-26T03:34:06Z
⛔ [SESSION] Từ chối Alone Worker: 'Vinh Phan' chưa điểm danh (hoặc phiên đã hết hạn).
POST /sync/push  409 Conflict          ← 18 thay đổi hợp lệ bị huỷ theo

GET /sessions/current  401 Unauthorized  (19 lần)   ← client không thể biết trước
```

Server chặn ở tầng sync vì client không đọc được trạng thái điểm danh để chặn ở UI. Sửa một cái mà không sửa cái kia thì vòng lặp vẫn tiếp diễn.

---

### Phase 1 — Nền tảng: audit, migration, seed, bảo mật

> **2 tuần** · mượn **O1, O6, S6**

| ID | Việc | Nguồn | DoD |
| :--- | :--- | :--- | :--- |
| **P1.1** | **Trường audit tự động trên mọi bảng**: `created_by`, `created_at`, `updated_by`, `updated_at`, `last_mutation_id`, `last_seq`. Framework ghi, không phải endpoint ghi thủ công. | **O1** | Không bảng nghiệp vụ nào thiếu; truy được mọi dòng về mutation gốc |
| **P1.2** | **Migration framework có version.** Mỗi module có `migrations/`, chạy theo thứ tự, idempotent, ghi lại vào `schema_migrations`, rollback được. | **S6** | Chạy lại migration 2 lần không lỗi; rollback 1 bước hoạt động |
| **P1.3** | **Seed khai báo + cờ `is_seed`.** Seed từ YAML trong module, đánh dấu `noupdate` để nâng cấp không ghi đè dữ liệu người dùng đã sửa. | **O6** | Nâng cấp không mất chỉnh sửa của khách; báo cáo phân biệt được seed |
| **P1.4** | **PK là `(tenant_id, id)`** trên mọi bảng nghiệp vụ. | — | Không còn `id TEXT PRIMARY KEY` đơn |
| **P1.5** | **Partition `sync_mutations`** theo RANGE(`created_at`), 1 partition/tháng, retention 60 ngày bằng `DROP PARTITION`. | — | Job retention chạy; không dùng `DELETE` |
| **P1.6** | **Row-Level Security** + `SET LOCAL app.tenant_id`. | — | Query quên `WHERE tenant_id` trả 0 dòng |
| **P1.7** | **Tombstone `deleted_at`** thay hard DELETE. | — | Không còn `DELETE FROM` trong projector; snapshot trả cả bản ghi đã xoá |
| **P1.8** | **Text search config `vi`** với `unaccent`. | — | Gõ `phong 33` khớp `phòng 33`; `nam` khớp `nấm` |
| **P1.9** | **Tách `IZIIAPP_ADMIN_SECRET`** khỏi `IZIIAPP_SERVER_SECRET`. | — | `/admin/reset` không gọi được bằng token đồng bộ |
| **P1.10** | **Port guard** — kiểm tra port 8080 trước khi start. | — | Hết `[Errno 10048]` (hiện 11/16 lần khởi động thất bại) |

**DDL trường audit (áp cho mọi bảng nghiệp vụ):**

```sql
-- Template dùng chung — mượn ir.model của Odoo
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS created_by       TEXT;
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS created_at       TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS updated_by       TEXT;
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS updated_at       TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS last_mutation_id TEXT;
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS last_seq         BIGINT NOT NULL DEFAULT 0;
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS deleted_at       TIMESTAMPTZ;
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS is_seed          BOOLEAN NOT NULL DEFAULT FALSE;
```

**Text search tiếng Việt:**

```sql
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TEXT SEARCH CONFIGURATION vi (COPY = simple);
ALTER TEXT SEARCH CONFIGURATION vi
  ALTER MAPPING FOR hword, hword_part, word
  WITH unaccent, simple;
```

---

### Phase 2 — Module system & bounded context

> **3 tuần** · mượn **S1, S5, O7**

Đây là phase quyết định iZiiServer có bán được cho khách hàng thứ hai hay không.

| ID | Việc | Nguồn | DoD |
| :--- | :--- | :--- | :--- |
| **P2.1** | **Module loader** — đọc `manifest.json`, giải phụ thuộc theo thứ tự topo, đăng ký route/service/hook. | **S1** | Bật/tắt module không cần sửa mã lõi |
| **P2.2** | **Vòng đời module** — install / upgrade / uninstall, chạy migration của module theo thứ tự. | **S1** | Cài `field_ops` lên DB trống → tạo đủ bảng và seed |
| **P2.3** | **Bật/tắt module theo tenant** — bảng `tenant_modules`. | **S1** | Tenant A có `field_ops`, tenant B không, không ảnh hưởng nhau |
| **P2.4** | **Tách bounded context** theo §4.2. Đổi tên bảng `mushroom_*` → bỏ tiền tố, chuyển vào module. | **S5** | Không còn tiền tố ngành trong tên bảng lõi |
| **P2.5** | **Cơ chế `extends` nhẹ** — module sau bổ sung trường cho entity của module trước qua `field_registry`. | **O7** | Module `field_ops` thêm được trường vào `core.employee` mà không sửa `core` |
| **P2.6** | **Kiểm tra tương thích client** — `min_client_schema_version` trong manifest; server không đẩy bảng mà client cũ chưa hiểu. | **NT-6** | Client schema v10 không nhận bảng yêu cầu v12; không crash |

**Bảng `tenant_modules`:**

```sql
CREATE TABLE tenant_modules (
    tenant_id    TEXT NOT NULL,
    module_name  TEXT NOT NULL,
    version      TEXT NOT NULL,
    enabled      BOOLEAN NOT NULL DEFAULT TRUE,
    installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    settings     JSONB NOT NULL DEFAULT '{}',
    PRIMARY KEY (tenant_id, module_name)
);
```

---

### Phase 3 — Metadata, EAV, Settings, Record Rules

> **3 tuần** · mượn **O2, O3, O4, S2, S3, S7** · phase có giá trị dài hạn cao nhất

| ID | Việc | Nguồn | DoD |
| :--- | :--- | :--- | :--- |
| **P3.1** | **`model_registry` + `field_registry`** — khai báo entity và trường: kiểu, ràng buộc, nhãn đa ngôn ngữ, **màu**, thứ tự hiển thị. | **O2** | Thêm entity mới bằng cấu hình, không sửa mã |
| **P3.2** | **`ui_descriptor` + endpoint `GET /meta/ui/{model}`** — server khai báo form/list; client Flutter render theo. | **O3** | **Thêm loại job mới + màu, không build lại app** |
| **P3.3** | **`entity_attributes` (EAV có giới hạn)** — thuộc tính tuỳ biến theo khách hàng. **Chỉ cho trường tuỳ biến**, không cho trường lõi. | **S2** | Khách A thêm trường "Mã lô giống" mà khách B không thấy |
| **P3.4** | **`settings` typed có scope** `global / tenant / site / device`, có validation và admin UI. | **S3** | Đổi ngưỡng cảnh báo CO qua admin, hiệu lực ngay, không restart |
| **P3.5** | **`record_rules`** — biểu thức JSON áp tự động vào mọi query. Thay thế `RecordSharingPermissions` (đang 0 dòng). | **O4** | Nhân viên chỉ thấy job của bộ phận mình; quản lý thấy tất cả |
| **P3.6** | **`translations`** — nhãn theo trường theo ngôn ngữ. | **S7** | Đổi app sang tiếng Anh, nhãn job đổi theo, không hardcode |
| **P3.7** | **Đồng bộ metadata xuống client** — metadata đi qua chính `sync_mutations` như dữ liệu thường. | **O2 + O3** | Thiết bị offline vẫn render đúng theo metadata đã nhận |

**DDL `field_registry` — giải trực tiếp lỗi F1 và yêu cầu "custom job":**

```sql
CREATE TABLE model_registry (
    tenant_id     TEXT NOT NULL,
    model_name    TEXT NOT NULL,          -- 'job' | 'grow_room' | 'employee'
    module_name   TEXT NOT NULL,
    table_name    TEXT NOT NULL,
    label         JSONB NOT NULL,         -- {"vi": "Công việc", "en": "Job"}
    is_syncable   BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (tenant_id, model_name)
);

CREATE TABLE field_registry (
    tenant_id     TEXT NOT NULL,
    model_name    TEXT NOT NULL,
    field_name    TEXT NOT NULL,
    data_type     TEXT NOT NULL,          -- text | int | numeric | bool | datetime | enum | ref
    is_required   BOOLEAN NOT NULL DEFAULT FALSE,
    is_custom     BOOLEAN NOT NULL DEFAULT FALSE,   -- true → lưu ở entity_attributes
    label         JSONB NOT NULL,
    enum_values   JSONB,                  -- cho enum: [{value, label, color, icon}]
    ui            JSONB NOT NULL DEFAULT '{}',      -- {widget, order, group, readonly}
    constraints   JSONB NOT NULL DEFAULT '{}',      -- {min, max, regex}
    PRIMARY KEY (tenant_id, model_name, field_name)
);
```

**Ví dụ — thêm loại job `clean_bed` với màu, không cần build app:**

```sql
UPDATE field_registry
   SET enum_values = enum_values || '[
        {"value":"clean_bed",  "label":{"vi":"Vệ sinh luống","en":"Clean Bed"},
         "color":"#eb6834", "icon":"cleaning", "default_minutes":35},
        {"value":"clean_room", "label":{"vi":"Vệ sinh phòng","en":"Clean Room"},
         "color":"#1baf7a", "icon":"room",     "default_minutes":45}
       ]'::jsonb
 WHERE tenant_id = 'costa-m2'
   AND model_name = 'job'
   AND field_name = 'job_type';
```

Thay đổi này đi qua `sync_mutations` xuống mọi thiết bị như một bản ghi thường. Grow Room đổi màu đúng trên **mọi bản build**, kể cả bản cũ — vì client không còn giữ bảng màu trong mã.

**DDL `settings` (mượn S3):**

```sql
CREATE TABLE settings (
    scope       TEXT NOT NULL,            -- 'global' | 'tenant' | 'site' | 'device'
    scope_id    TEXT NOT NULL DEFAULT '', -- '' cho global
    key         TEXT NOT NULL,            -- 'safety.co_threshold_ppm'
    value       JSONB NOT NULL,
    data_type   TEXT NOT NULL,
    updated_by  TEXT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (scope, scope_id, key)
);
-- Độ ưu tiên khi đọc: device > site > tenant > global
```

**DDL `record_rules` (mượn O4):**

```sql
CREATE TABLE record_rules (
    tenant_id   TEXT NOT NULL,
    rule_name   TEXT NOT NULL,
    model_name  TEXT NOT NULL,
    role_key    TEXT NOT NULL,            -- 'picker' | 'supervisor' | 'manager'
    domain      JSONB NOT NULL,           -- [["department_id","=","$user.department_id"]]
    perm_read   BOOLEAN NOT NULL DEFAULT TRUE,
    perm_write  BOOLEAN NOT NULL DEFAULT FALSE,
    enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (tenant_id, rule_name)
);
```

**Giới hạn EAV — quan trọng:** `entity_attributes` chỉ dùng cho trường **tuỳ biến theo khách hàng**. Trường lõi (`job_type`, `status`, `room_id`, `started_at`) phải là cột thật. EAV dùng sai chỗ sẽ giết hiệu năng truy vấn — đây là lý do Smartstore cũng giữ `GenericAttribute` tách riêng chứ không dùng cho mọi thứ.

---

### Phase 4 — Projector, Snapshot, Hook engine

> **3 tuần** · mượn **S4, O5** · chạy song song P2–P3

| ID | Việc | Nguồn | DoD |
| :--- | :--- | :--- | :--- |
| **P4.1** | **Projector merge theo cột**, không upsert từ payload thiếu (NT-3). | — | Mutation `{id, status}` không làm rỗng `name`, `price` |
| **P4.2** | **UPDATE cho bản ghi chưa tồn tại → fetch full row**, không tạo stub. | — | Gửi update cho id lạ → gọi `GET /sync/record/{table}/{id}`, không sinh "Untitled" |
| **P4.3** | **Checkpoint giao dịch** — `projection_checkpoint` ghi cùng transaction với projection. | — | Kill worker giữa chừng → khởi động lại không mất, không nhân đôi |
| **P4.4** | **FK `NOT VALID`** + job validate định kỳ, không chặn ingest. | — | Order line tới trước product → không dừng pipeline |
| **P4.5** | **Snapshot API** trả `(rows, snapshot_seq)` trong **một** transaction `REPEATABLE READ`. | — | Snapshot rồi pull từ `snapshot_seq` → không mất, không trùng |
| **P4.6** | **Hook engine** — đăng ký `before_save` / `after_save` / `on_event` theo model, khai báo trong module. | **S4** | Alone Worker tự tạo safety config; job completed tự reset `current_stage` |
| **P4.7** | **Record history API** — `GET /records/{table}/{id}/history` đọc từ `sync_mutations`. | **O5** | Xem được toàn bộ lịch sử thay đổi của một job an toàn |
| **P4.8** | **Backfill chạy lại được từ đầu** (idempotent replay). | — | Xoá read model, replay toàn bộ mutation → kết quả giống hệt |

**Projector — merge theo cột (thay upsert của blueprint):**

```sql
UPDATE jobs j SET
    name       = COALESCE(m.name,   j.name),
    status     = COALESCE(m.status, j.status),
    -- ... các cột khác
    last_seq         = %(seq)s,
    last_mutation_id = %(mutation_id)s,
    updated_by       = %(actor)s,
    updated_at       = now()
FROM jsonb_populate_record(NULL::jobs, %(payload)s::jsonb) m
WHERE j.tenant_id = %(tenant)s
  AND j.id        = %(id)s
  AND %(seq)s > j.last_seq;      -- chống replay và out-of-order
```

**Hook engine — khai báo (mượn S4):**

```python
# modules/field_ops/hooks/on_job_started.py
@hook(model="job", event="after_save", when="status == 'in_progress'")
async def create_safety_config(ctx, record):
    if record["job_type"] != "alone_worker":
        return
    await ctx.create("job_safety_configs", {
        "job_id": record["id"],                       # ← sửa luôn lỗi M1
        "check_in_interval_minutes": await ctx.setting("safety.checkin_interval", 30),
        "grace_period_minutes":      await ctx.setting("safety.grace_period", 5),
        "escalation_target":         "supervisor",
    })
    await ctx.schedule("on_checkin_missed", record["id"],
                       delay_minutes=record["time_limit_minutes"])
```

Đây là nơi logic nghiệp vụ nên sống: khai báo, test được, tách khỏi endpoint. Hiện tại logic này rải rác trong controller và là lý do `job_id` bị rơi.

---

### Phase 5 — Miền hiện trường: chấm công & an toàn

> **3 tuần** · chạy song song P2–P4 · gỡ chặn nhiều thứ nhất

Bốn bảng `attendance_events`, `daily_timesheets`, `break_policies`, `shifts` **đã có schema đầy đủ và hợp lý nhưng đang trống 0 dòng**. Đây là nút thắt duy nhất gây ba hệ quả cùng lúc.

| ID | Việc | DoD |
| :--- | :--- | :--- |
| **P5.1** | **Màn hình điểm danh vào/ra** ghi `attendance_events`. | Nhân viên điểm danh được trên iPad; sự kiện lên server |
| **P5.2** | **Job cuối ca** tổng hợp sang `daily_timesheets` (break, gross, paid, OT). | Chạy 22:00 hằng ngày; khớp với sự kiện điểm danh |
| **P5.3** | **`break_policies` mặc định** (30 phút chuẩn, 5 phút ân hạn) qua seed khai báo. | Mỗi tenant có ít nhất 1 policy |
| **P5.4** | **Sửa M1 — khoá ngoại bị rơi.** `job_id`, `worker_id` của `safety_checkin_logs` và `job_safety_configs` đang là chuỗi rỗng trên **8/8 dòng**, dù server nhận đủ. | Tạo Alone Worker → cả hai bảng có `job_id` đúng |
| **P5.5** | **Ghi GPS + `response_time_seconds`** cho log an toàn (hiện chưa bao giờ được ghi). | Đo được tốc độ phản hồi cảnh báo |
| **P5.6** | **Đưa 6 bảng cục bộ vào sync**: `departments`, `employee_department_roles`, `picker_teams`, `yield_surveys`, `maintenance_tickets`, `chat_messages`. Cả 6 có dữ liệu thật nhưng **0 lần đồng bộ / 245.000 dòng log**. | Đổi máy không mất dữ liệu |
| **P5.7** | **Chuyển màu Grow Room sang `field_registry`** (thay vì thêm `stage_color` vào payload). | Job `clean_bed` / `clean_room` đổi màu đúng trên mọi bản build |
| **P5.8** | **Reset `current_stage` về `idle`** khi job completed/timeout + job dọn phòng kẹt — cài bằng hook (P4.6). | Room 10 & 12 (kẹt `alone_timeout`, `updated_at` cũ hơn `created_at` 23 ngày) được giải phóng |
| **P5.9** | **Cột thời gian cho `maintenance_tickets`** (`created_at`, `due_date`, `completed_at`). | Đo được thời gian xử lý sự cố |
| **P5.10** | **Nhập `base_rate` + `employment_type`** cho nhân viên (đang NULL trên cả 8 người). | Điều kiện cần để tính lương |
| **P5.11** | **Sửa F7** — `user_id` phải là mã nhân viên, không phải `device_id`. | Ba thiết bị của cùng một người chia sẻ đúng dữ liệu |

---

### Phase 6 — Topology hai tầng & API công khai

> **2 tuần**

| ID | Việc | DoD |
| :--- | :--- | :--- |
| **P6.1** | **Edge node** — mỗi site 1 node, LAN, SQLite hoặc Postgres nhẹ. | Site hoạt động đầy đủ khi mất WAN ≥ 24h |
| **P6.2** | **Central node** — PostgreSQL 16+, hợp nhất mọi site. | Central nhận mutation từ ≥ 2 edge node |
| **P6.3** | **Kích hoạt peer-sync** đã có sẵn. Sửa cấu hình peer sai dải mạng (đang trỏ `192.168.1.11/12` trong khi máy thật ở `10.107.156.x` / `172.22.170.x` → 3.968 lần fail). | `⚠️ [PEER-SYNC] Không kết nối được peer` = 0 |
| **P6.4** | **Store-and-forward** khi mất WAN, không mất thứ tự. | Ngắt WAN 2h, tạo 200 mutation, nối lại → đủ 200, đúng thứ tự |
| **P6.5** | **API công khai đọc** (`GET /api/v1/...`) + **webhook** khi bản ghi đổi. Đây là cửa tích hợp tuỳ chọn cho bất kỳ hệ nào sau này. | Hệ ngoài đọc được đơn hàng/tồn kho; webhook bắn khi có thay đổi |
| **P6.6** | **Bảng `external_refs`** — tạo sẵn, chưa dùng. | Có trong schema, không có mã phụ thuộc |

---

### Phase 7 — AI: embedding & hybrid search

> **2 tuần**

**pgai đã ngừng phát triển** — repo `timescale/pgai` archive 27/05/2026, README ghi *"As of February 2026, this project is no longer being maintained or supported."* Tiger Cloud gỡ managed vectorizer và hàm LLM trong DB từ 30/06/2026. Ta tự viết.

| ID | Việc | DoD |
| :--- | :--- | :--- |
| **P7.1** | **`embedding_queue` + worker stateless** (thay pgai Vectorizer). | Giết worker giữa chừng không mất việc |
| **P7.2** | **`content_hash`** — bỏ qua nếu text không đổi. | Đổi giá **không** kích hoạt re-embed |
| **P7.3** | **Tách embedding khỏi transaction projection.** | Embedding service chết → projection vẫn chạy |
| **P7.4** | **Dùng `halfvec(768)`.** | Dung lượng index giảm ~50% |
| **P7.5** | **Sửa A3 — RRF query đang lấy 50 dòng ngẫu nhiên.** | Recall@10 ≥ 0,9 trên bộ truy vấn tiếng Việt |
| **P7.6** | **Bật iterative index scans** (pgvector 0.8) cho post-filter đa tenant. | Lọc tenant nhỏ vẫn trả đủ kết quả |
| **P7.7** | Phạm vi: SOP, sự cố an toàn, tìm sản phẩm nội bộ. | Quy mô theo từng deployment, không phải 2M gộp |

**Sửa A3 — sắp xếp tường minh trước khi cắt:**

```sql
-- SAI (blueprint): ORDER BY trong OVER() KHÔNG sắp xếp kết quả trả về.
--                  LIMIT 50 lấy 50 dòng tuỳ ý theo thứ tự scan.
SELECT p.id, ..., ROW_NUMBER() OVER (ORDER BY pe.embedding <=> %s::vector) AS rank_vec
FROM products p JOIN product_embeddings pe ON p.id = pe.product_id
WHERE p.tenant_id = %s
LIMIT 50;

-- ĐÚNG
SELECT s.*, ROW_NUMBER() OVER () AS rank_vec
FROM (
    SELECT p.id, p.name, p.sku, p.price
    FROM products p JOIN product_embeddings pe ON p.id = pe.product_id
    WHERE p.tenant_id = %s AND p.is_active
    ORDER BY pe.embedding <=> %s::vector     -- ← bắt buộc
    LIMIT 50
) s;
```

**DDL `embedding_queue`:**

```sql
CREATE TABLE embedding_queue (
    id              BIGSERIAL PRIMARY KEY,
    table_name      TEXT NOT NULL,
    row_id          TEXT NOT NULL,
    tenant_id       TEXT NOT NULL,
    content_hash    TEXT NOT NULL,      -- bỏ qua nếu text không đổi
    model_version   TEXT NOT NULL,      -- để re-embed khi đổi model
    attempts        INT  NOT NULL DEFAULT 0,
    last_error      TEXT,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (table_name, row_id, model_version)
);

SELECT * FROM embedding_queue
 WHERE next_attempt_at <= now()
 ORDER BY id LIMIT 64
   FOR UPDATE SKIP LOCKED;
```

---

### ⊙ Vận hành & quan sát (xuyên suốt)

| Việc | DoD |
| :--- | :--- |
| `/metrics` (Prometheus): độ trễ push/pull, độ sâu queue, tỉ lệ dead-letter, lag projector | Có dashboard Grafana |
| Trang dead-letter cho người vận hành (xem, retry, bỏ qua) | Người không phải dev dùng được |
| Cảnh báo: dead-letter > 0, projector lag > 5 phút, edge mất kết nối > 30 phút | Cảnh báo tới Slack/email |
| `trace_id` xuyên suốt device → server → hook → projector | Truy được một mutation qua toàn bộ đường ống |
| Bắt `_ProactorBasePipeTransport._call_connection_lost` (28 lần trong log) | Log sạch |

---

## 7. Đặc tả kỹ thuật

### 7.1. Hợp đồng `/sync/push` (mới)

```http
POST /sync/push
Content-Type: application/json
X-Device-Id: izii-d-2a129af8

{
  "device_id": "izii-d-2a129af8",
  "tenant_id": "costa-m2",
  "client_schema_version": 12,
  "mutations": [
    {
      "mutation_id": "9f2c...",           // UUID, để idempotent
      "table": "jobs",
      "operation": "insert",
      "mode": "full",                     // "full" | "partial"  ← P0.1
      "data": { "id": "af4f...", "room_id": "room_34", ... },
      "client_ts": "2026-09-08T02:11:04.318Z"   // BẮT BUỘC có timezone
    }
  ]
}
```

```http
200 OK
{
  "server_seq_high": 91240,
  "accepted": [ { "mutation_id": "9f2c...", "seq": 91237 } ],
  "rejected": [
    {
      "mutation_id": "a71b...",
      "code": "E_ATTENDANCE_REQUIRED",
      "reason": "Nhân viên 'Vinh Phan' chưa điểm danh",
      "retryable": false
    }
  ]
}
```

**Mã lỗi chuẩn:**

| Mã | Ý nghĩa | Retry? |
| :--- | :--- | :--- |
| `E_NAIVE_TIMESTAMP` | Timestamp không có timezone | Không — client phải sửa |
| `E_ATTENDANCE_REQUIRED` | Chưa điểm danh (Alone Worker) | Không |
| `E_RULE_DENIED` | Vi phạm `record_rules` (O4) | Không |
| `E_STALE_SEQ` | `seq` cũ hơn `last_seq` của bản ghi | Không — đã bị ghi đè |
| `E_UNKNOWN_ROW` | UPDATE cho bản ghi chưa tồn tại | Có — sau khi fetch full row |
| `E_SCHEMA_TOO_NEW` | Client cũ hơn `min_client_schema_version` | Không — cần cập nhật app |
| `E_VALIDATION` | Vi phạm `constraints` trong `field_registry` | Không |

### 7.2. Endpoint metadata mới (O2 + O3)

```http
GET /meta/models?since_seq=91234        # danh sách entity + version
GET /meta/ui/job?locale=vi              # descriptor form/list cho model 'job'
GET /meta/settings?scope=site&id=M2     # settings hiệu lực cho site
GET /records/jobs/{id}/history          # lịch sử thay đổi (O5)
```

Metadata đi xuống thiết bị **qua chính `sync_mutations`**, nên thiết bị offline vẫn có metadata mới nhất mình đã nhận.

### 7.3. Hợp đồng `/sync/pull`

```http
GET /sync/pull?after_seq=91234&limit=500

200 OK
{
  "records": [ { "seq": 91235, "table": "...", "operation": "...", "data": {...} } ],
  "has_more": false,
  "watermark_seq": 91240      // ← chỉ trả seq < watermark (P0.4)
}
```

### 7.4. Snapshot API

```http
GET /snapshot/state?site_id=M2&tables=grow_rooms,jobs

200 OK
{
  "snapshot_seq": 91234,
  "taken_at": "2026-09-08T02:11:04.318Z",
  "schema_version": 12,
  "tables": { "grow_rooms": [...], "jobs": [...] }
}
```

Client lưu `snapshot_seq`, sau đó tiếp tục `GET /sync/pull?after_seq=91234`. Server phải lấy toàn bộ payload trong **một** transaction `REPEATABLE READ` — nếu không, khoảng giữa snapshot và lần pull đầu sẽ mất hoặc trùng mutation.

---

## 8. Sổ đăng ký lỗi

18 lỗi đã xác định, kèm phase xử lý.

### 8.1. Từ phân tích log server (F)

| ID | Lỗi | Mức | Phase |
| :--- | :--- | :--- | :--- |
| **F1** | Bảng ánh xạ stage → màu thiếu `clean_bed`, `clean_room` (nằm cứng trong client) | Cao | **P3.2** (metadata) + P5.7 |
| **F2** | Room 10 & 12 kẹt vĩnh viễn ở `alone_timeout` | Cao | P5.8 (hook) |
| **F3** | `/sync/push` huỷ cả batch khi 1 item sai (4 lần, 32 thay đổi bị huỷ) | **Nghiêm trọng** | P0.2 |
| **F4** | Outbox `status='rejected'` nằm chết, không retry, không báo | **Nghiêm trọng** | P0.6 |
| **F5** | UPDATE không có INSERT → client tạo row rỗng ("Untitled Task") | **Nghiêm trọng** | 🟡 **Đã xử lý cho tasks; còn mở cho projects/deals/chat** (P0.1, P0.1c, P4.2) |
| **F6** | 401 trên `/sessions/current` → client không biết trước ai chưa điểm danh | **Nghiêm trọng** | P0.7 |
| **F7** | `user_id` = `device_id`; mỗi thiết bị là một "user" riêng | Cao | P1.4, P5.11 |
| **F8** | Port 8080 xung đột — 11/16 lần khởi động thất bại | Cao | P1.10 |
| **F9** | Latency âm — trộn giờ local naive với UTC ở tầng WS | Cao | P0.3 |
| **F10** | `IZIIAPP_ADMIN_SECRET` chưa đặt, dùng chung token đồng bộ | Cao | P1.9 + P3.4 |

### 8.2. Từ kiểm kê module Mushroom (M)

| ID | Lỗi | Mức | Phase |
| :--- | :--- | :--- | :--- |
| **M1** | `job_id`, `worker_id` bị rơi khi ghi xuống máy trạm (8/8 dòng của 2 bảng an toàn) | **Nghiêm trọng** | P4.6 (hook) + P5.4 |
| **M2** | Nhiều cột có sẵn nhưng chưa bao giờ được ghi (`target_yield`, `picked_yield` rỗng 70/70 phòng; `base_rate` rỗng 8/8 nhân viên; GPS, response time) | Cao | P5.5, P5.10 |
| **M3** | Dữ liệu seed bị nhầm là dữ liệu vận hành (22 đội hái, 3 bộ phận, 15 tin nhắn) | Trung bình | **P1.3** (seed khai báo) |

### 8.3. Từ duyệt blueprint CQRS (A)

| ID | Lỗi | Mức | Phase |
| :--- | :--- | :--- | :--- |
| **A1** | Projector upsert bằng payload thiếu cột → ghi đè dữ liệu tốt | **Nghiêm trọng** | P4.1 |
| **A2** | Gọi embedding HTTP bên trong transaction projection; lỗi trả `[]` im lặng | **Nghiêm trọng** | P7.3 |
| **A3** | Truy vấn RRF lấy 50 dòng ngẫu nhiên (`ROW_NUMBER` + `LIMIT` thiếu `ORDER BY` ngoài) | **Nghiêm trọng** | P7.5 |
| **A4** | `seq` toàn cục có lỗ hổng khoảng trống → mất mutation vĩnh viễn | **Nghiêm trọng** | P0.4 |
| **A5** | FK cứng trong projection eventually-consistent → dừng pipeline khi sai thứ tự | Cao | P4.4 |

---

## 9. Migration & dọn dữ liệu

**Bản vá code không tự dọn dữ liệu hỏng đang có.** Chạy kèm mỗi lần phát hành.

### 9.1. Script dọn bắt buộc (sau Phase 4)

```sql
-- 1. Xoá task ma sinh ra từ lỗi F5/A1 (8 dòng "Untitled Task" trong DB mẫu)
DELETE FROM tasks
 WHERE (title IS NULL OR title = 'Untitled Task')
   AND project_id IS NULL
   AND description IS NULL;

-- 2. Xoá job rỗng (6 dòng trong DB mẫu)
DELETE FROM jobs
 WHERE room_id IS NULL AND job_type IS NULL AND name IS NULL;

-- 3. Giải phóng phòng kẹt (updated_at cũ hơn created_at — lỗi F2)
UPDATE grow_rooms
   SET current_stage = 'idle', status = 'idle', updated_at = now()
 WHERE updated_at < created_at
    OR (current_stage = 'alone_timeout'
        AND updated_at < now() - INTERVAL '24 hours');

-- 4. Đánh dấu dữ liệu seed (lỗi M3) — sau P1.3 thì cột is_seed đã có sẵn
UPDATE picker_teams SET is_seed = TRUE WHERE headcount = 0 AND member_ids_json IS NULL;
UPDATE departments  SET is_seed = TRUE WHERE created_at < '2026-08-27';
UPDATE chat_messages SET is_seed = TRUE WHERE created_at < '2026-08-27';
```

### 9.2. Khôi phục khoá ngoại đã mất (M1)

`job_id` và `worker_id` vẫn còn trong `sync_mutations` phía server — khôi phục được:

```sql
UPDATE safety_checkin_logs l
   SET job_id    = m.data->>'job_id',
       worker_id = m.data->>'worker_id'
  FROM sync_mutations m
 WHERE m."table" = 'mushroom_safety_checkin_logs'
   AND m.data->>'id' = l.id
   AND (l.job_id IS NULL OR l.job_id = '');
```

Chạy tương tự cho `job_safety_configs`.

### 9.3. Thứ tự phát hành

1. Server lên trước, **tương thích ngược** với client cũ (chấp nhận timestamp naive nhưng ghi cảnh báo).
2. Client lên sau, gửi UTC và xử lý `partial_commit`.
3. Sau khi ≥ 95% thiết bị lên bản mới → server bật chế độ nghiêm (từ chối naive timestamp).
4. Chạy script dọn dữ liệu §9.1 và §9.2.
5. Bật metadata-driven UI (P3.2) — client cũ vẫn chạy được nhờ `min_client_schema_version`.

### 9.4. Đổi tên bảng `mushroom_*` (P2.4)

Đây là breaking change ở tầng sync. Cách an toàn:

1. Tạo bảng mới với tên không tiền tố; copy dữ liệu.
2. Giữ **view** với tên cũ trỏ sang bảng mới, trong 2 phiên bản client.
3. Server chấp nhận cả hai tên trong mutation, ánh xạ qua `model_registry`.
4. Sau 2 phiên bản, bỏ view và bỏ tên cũ.

---

## 10. Kiểm thử & tiêu chí nghiệm thu

### 10.1. Test bắt buộc trước mỗi phát hành

| Kịch bản | Kỳ vọng |
| :--- | :--- |
| **Partial commit** — batch 18 item, 1 item vi phạm | 17 commit, 1 dead-letter, response liệt kê đúng |
| **Mất mạng 24h** — tạo 200 mutation offline, nối lại | Đủ 200, đúng thứ tự, không trùng |
| **Sequence gap** — 50 transaction song song | Client không bỏ sót mutation nào |
| **Replay** — xoá read model, replay toàn bộ mutation | Kết quả giống hệt lần đầu (idempotent) |
| **Snapshot + pull** — snapshot rồi pull từ `snapshot_seq` | Không mất, không trùng |
| **Partial update** — gửi `{id, status}` | `name`, `price` không bị rỗng |
| **UPDATE cho id lạ** | Fetch full row, không sinh stub |
| **Metadata mới, client cũ** | Client schema v10 bỏ qua model yêu cầu v12, không crash |
| **Thêm job type qua admin** | Xuất hiện trên iPad và Desktop **không cần build lại app** |
| **Record rule** — nhân viên bộ phận A | Không thấy job của bộ phận B, kể cả khi gọi API trực tiếp |
| **Hook** — job Alone Worker bắt đầu | `job_safety_configs` được tạo **có `job_id`** |
| **Bật/tắt module** | Tenant không bật `field_ops` không thấy bảng của module đó |
| **Embedding service chết** | Projection không bị ảnh hưởng; queue tồn đọng và retry |
| **Tenant isolation** — query quên `WHERE tenant_id` | RLS trả 0 dòng |
| **Tìm kiếm tiếng Việt** — gõ `phong 33` | Khớp `phòng 33` |

### 10.2. Chỉ số nghiệm thu

| Chỉ số | Ngưỡng |
| :--- | :--- |
| Tỉ lệ mutation vào dead-letter | < 0,1% |
| Độ trễ projector (mutation → read model) | p95 < 5 giây |
| Độ trễ `/sync/push` | p95 < 300 ms |
| Cold-start thiết bị mới (snapshot) | < 30 giây cho 1 site |
| Số bản ghi ma sinh mới | **0** |
| Số lượt `[Errno 10048]` | **0** |
| Thêm loại job mới → xuất hiện trên thiết bị | < 5 phút, **0 lần build app** |
| Recall@10 hybrid search (tiếng Việt) | ≥ 0,9 |

---

## 11. Quyết định cần chốt & rủi ro

### 11.1. Năm quyết định phải chốt trước khi bắt đầu

| # | Quyết định | Ảnh hưởng nếu chốt sai |
| :--- | :--- | :--- |
| **Q1** | **Full-row hay dirty-field?** (P0.1) | Quyết định toàn bộ logic projector. Đổi sau = viết lại Phase 4 |
| **Q2** | **Có đổi tên bảng `mushroom_*` không?** (P2.4) | Không đổi = khoá sản phẩm vào một ngành, không bán được cho khách thứ hai. Đổi = breaking change ở tầng sync, cần quy trình §9.4 |
| **Q3** | **Metadata-driven UI đi tới đâu?** Chỉ enum + màu, hay cả form layout? | Chỉ enum + màu: 1 tuần, giải lỗi F1 và "custom job". Cả form layout: 3 tuần, nhưng gần như không bao giờ phải build app vì lý do dữ liệu nữa |
| **Q4** | **Self-host hay RDS/Aurora?** | pgvectorscale **không chạy trên RDS/Aurora**. Nếu sau này cần mà đang ở RDS thì phải di trú toàn bộ database |
| **Q5** | **Giữ SQLite ở edge hay chuyển hết sang Postgres?** | SQLite nhẹ, hợp LAN node; Postgres đồng nhất hơn nhưng nặng hơn cho máy tại site |

### 11.2. Rủi ro

| Rủi ro | Mức | Giảm thiểu |
| :--- | :--- | :--- |
| Phase 0 bị bỏ qua vì "không thấy tính năng mới" | **Cao** | Trình bày rõ: đây là điều kiện tiên quyết, không phải tuỳ chọn. Mọi thứ xây thêm đều kế thừa cái sai đang có |
| Metadata layer bị làm quá tay, thành ORM mini | **Cao** | Chốt Q3 rõ ràng. Giữ lát mỏng: registry + enum + màu + validation. **Không** xây view engine đầy đủ như Odoo |
| EAV dùng sai chỗ, giết hiệu năng | Trung bình | Quy tắc cứng: trường lõi là cột thật, EAV chỉ cho trường tuỳ biến theo khách hàng |
| Đổi tên bảng làm gãy client cũ | **Cao** | Quy trình §9.4: view tương thích + `model_registry` ánh xạ, giữ 2 phiên bản |
| Module system phức tạp hoá code base | Trung bình | Bắt đầu bằng 2 module (`core` + `field_ops`), chỉ tách thêm khi thật cần |
| Dữ liệu hỏng hiện tại lan rộng | **Cao** | Script §9 chạy ngay sau Phase 4, trước khi mở rộng |
| pgvector/pgvectorscale đổi trạng thái (như pgai) | Thấp | Kiểm tra lại tình trạng dự án trước mỗi quyết định hạ tầng |

---

## 12. Phụ lục

### 12.1. Bảng mới — tổng hợp

| Bảng | Nguồn ý tưởng | Phase |
| :--- | :--- | :--- |
| `tenant_modules` | S1 | P2 |
| `model_registry` | O2 | P3 |
| `field_registry` | O2 + O3 | P3 |
| `entity_attributes` | S2 | P3 |
| `settings` | S3 | P3 |
| `record_rules` | O4 | P3 |
| `translations` | S7 | P3 |
| `hook_registry` | S4 | P4 |
| `projection_checkpoint` | — | P4 |
| `embedding_queue` | — | P7 |
| `external_refs` (tuỳ chọn) | — | P6 |
| `attendance_events`, `daily_timesheets`, `break_policies`, `shifts` | — (đã có schema, 0 dòng) | P5 |

### 12.2. Biến môi trường

Sau Phase 3, phần lớn cấu hình chuyển sang bảng `settings`. Env var chỉ giữ những gì cần trước khi DB sẵn sàng:

```ini
# Định danh node
IZIIAPP_SERVER_ID=edge-costa-m2
IZIIAPP_ZONE=M2
IZIIAPP_NODE_ROLE=edge            # edge | central
IZIIAPP_PEERS=10.107.156.10:8080  # SỬA: đang trỏ sai dải mạng 192.168.1.x

# Bảo mật — tách bạch (F10)
IZIIAPP_SERVER_SECRET=...
IZIIAPP_ADMIN_SECRET=...          # PHẢI khác server secret
IZIIAPP_WS_SECRET=...

# Kết nối DB
IZIIAPP_DB_URL=postgresql://...

# Embedding
EMBEDDING_MODEL=bge-m3
EMBEDDING_DIM=768
EMBEDDING_ENDPOINT=http://ai-service.internal:8000/embed
```

### 12.3. Cấu hình PostgreSQL (central node, 32 GB RAM)

```ini
shared_buffers = 8GB
work_mem = 48MB
maintenance_work_mem = 2GB          # cần khi build HNSW
effective_cache_size = 24GB
hnsw.ef_search = 40
max_connections = 300               # pgbouncer ở chế độ session (LISTEN cần session pooling)
```

> Blueprint đề xuất 32–64 GB cho 2 triệu vector với công thức 6,28 GB. Công thức đó lạc quan ~2,2 lần vì **HNSW của pgvector lưu bản sao đầy đủ vector trong index**. Với `halfvec` và phạm vi theo từng deployment, **32 GB là đủ**.

### 12.4. Nguồn kiểm chứng công nghệ (kiểm tra 04/09/2026)

| Khẳng định | Nguồn |
| :--- | :--- |
| pgai archive 27/05/2026, không bảo trì từ 02/2026 | `github.com/timescale/pgai` |
| Tiger Cloud gỡ managed vectorizer + hàm LLM từ 30/06/2026 | `tigerdata.com/docs/deploy/tiger-cloud/vectorizer-deprecation` |
| pgvectorscale còn hoạt động; có label-based filtered search; không có trên RDS/Aurora | `github.com/timescale/pgvectorscale` |
| pgvector 0.8 có iterative index scans; 0.7 có `halfvec` | `github.com/pgvector/pgvector/blob/master/CHANGELOG.md` |
| HNSW của pgvector lưu bản sao đầy đủ vector trong index | `lantern.dev/blog/pgvector-storage` |

### 12.5. Tài liệu tham khảo kiến trúc

| Tài liệu | Dùng để làm gì trong kế hoạch này |
| :--- | :--- |
| `Smartstore-Architecture-For-Developers.md` | Nguồn cho S1–S7: module lifecycle, GenericAttribute, ISettings, DbSaveHook, bounded context, FluentMigrator, LocalizedProperty |
| Odoo 19.0 (ORM & metadata layer) | Nguồn cho O1–O7: audit fields, ir.model/ir.model.fields, model-driven UI, ir.rule, mail.thread, seed noupdate, `_inherit` |
| `iziiapp_cqrs_pgvector_architecture.md` v2.0.0 | Blueprint gốc — kế hoạch này thay thế §7 (roadmap) và điều chỉnh §3 (schema), §6 (tính RAM) |
| `Mushroom_Joblist.md` | Danh sách trường đồng bộ khi tạo New Job |

> **Lưu ý pháp lý:** Smartstore (GPL-3.0) và Odoo (LGPL-3.0/OPL) chỉ được dùng làm **nguồn tham khảo ý tưởng kiến trúc**. Không sao chép mã nguồn, không tạo tác phẩm phái sinh, không phụ thuộc runtime. Các khái niệm kiến trúc (module system, EAV, metadata registry, record rules, save hooks) là mẫu thiết kế phổ biến trong ngành, không bị ràng buộc bản quyền.

---

*Kế hoạch này dựa trên phân tích dữ liệu vận hành thật, không phải giả định. Mọi con số và trích dẫn mã đều lấy nguyên văn từ log server và database đã kiểm tra. Nên cập nhật lại tài liệu sau mỗi phase hoàn thành.*
