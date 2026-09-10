# ADR 001: Mutation Contract Dirty-Field & Anti-Replay Rules

- **Trạng thái**: Đã phê duyệt (Approved)
- **Ngày**: 08/09/2026
- **Quyết định liên quan**: Q1 (Dirty-field mutation contract)
- **Phạm vi**: iZiiServer (FastAPI, PostgreSQL/SQLite) và iZiiApp (Flutter / Drift)

---

## 1. Bối cảnh (Context)

Trước đây, khi client iZiiApp (Flutter) cập nhật một bản ghi, client gửi nguyên toàn bộ hàng (full row) lên server. Nếu hai thiết bị cùng cập nhật hai trường khác nhau của cùng một bản ghi khi offline, việc ghi đè cả row dẫn đến mất dữ liệu của thiết bị kia (Last Write Wins ở cấp độ row thay vì field).
Ngoài ra, khi projector server nhận được mutation thiếu cột mà thực hiện `INSERT ... ON CONFLICT DO UPDATE` trần (upsert), các cột không có trong mutation bị ghi đè thành NULL hoặc rỗng, sinh ra các bản ghi ma (lỗi F5/A1 — ví dụ "Untitled Task").

## 2. Quyết định (Decision)

Hệ thống iZiiApp & iZiiServer thống nhất áp dụng **Dirty-Field Mutation Contract** với 4 ràng buộc kỹ thuật bất khả xâm phạm:

### 2.1. Quy ước Khóa Vắng Mặt vs NULL Tường Minh
- **Khóa vắng mặt (Absent Key)**: Trường đó **KHÔNG THAY ĐỔI**. Giá trị hiện tại trong database được giữ nguyên tuyệt đối.
- **Khóa có mặt với giá trị `null` tường minh (`"field": null`)**: Người dùng hoặc hệ thống chủ động **XOÁ GIÁ TRỊ** (gán thành NULL trong database).
- **Khóa có mặt với giá trị khác null (`"field": "value"`)**: Cập nhật trường đó thành giá trị mới.

```jsonc
// Ví dụ mutation payload chuẩn:
{
  "id": "af4f92bc-381a-4d22-81f9-0192847a91bf",
  "status": "completed",       // Cập nhật status thành "completed"
  "assignee_id": null          // Xoá người được giao (gán NULL)
  // Các trường khác như "name", "room_id", "started_at" vắng mặt -> GIỮ NGUYÊN
}
```

### 2.2. Danh sách trường bắt buộc trong Mutation
Mỗi mutation đẩy lên `/sync/push` bắt buộc phải có:
1. `id`: UUID của bản ghi (do thiết bị tự sinh khi offline).
2. `tenant_id`: Mã định danh tenant (ví dụ `costa-m2` hoặc `*`) để đảm bảo cô lập dữ liệu nhiều khách hàng (RLS).
3. `table`: Tên bảng đích (ví dụ `jobs`, `mushroom_jobs`, `grow_rooms`).
4. `operation`: `insert`, `update`, hoặc `delete`.
5. `data`: Dictionary chứa các trường đã sửa (dirty fields).
6. `mutation_id`: UUID của chính mutation để đảm bảo tính Idempotent (chống trùng).
7. `client_ts`: Thời gian client sinh mutation định dạng ISO-8601 UTC (bắt buộc có timezone `Z` hoặc `+00:00`).

### 2.3. Projector Server Không Bao Giờ Upsert Trực Tiếp
- Lệnh UPDATE của Projector bắt buộc merge theo từng cột:
  - Trên PostgreSQL: Sử dụng `jsonb_populate_record(NULL::<table>, payload::jsonb)` kết hợp `COALESCE` và `jsonb_exists(payload, 'field')`.
  - Chỉ chấp nhận mutation có `seq > last_seq` của bản ghi để chống out-of-order và replay.

### 2.4. Xử lý UPDATE cho Bản Ghi Chưa Tồn Tại
- Khi Projector hoặc Client nhận được lệnh `update` cho một `id` chưa tồn tại trong cơ sở dữ liệu địa phương:
  - **TUYỆT ĐỐI KHÔNG** tự động tạo bản ghi stub/rỗng (nguyên nhân gây ra lỗi "Untitled Task").
  - Client / Projector phải gọi endpoint `GET /sync/record/{table}/{id}` để kéo bản ghi đầy đủ (full row) từ nguồn dữ liệu gốc trước khi áp dụng bản vá delta.

### 2.5. Quy định Bắt Buộc Về Backfill & Replay (Anti-Replay seq = 0)
- **NGHIÊM CẤM** công cụ vận hành replay mutation stream từ `seq = 0` lên một read model rỗng. Vì các mutation là partial (chỉ chứa dirty-fields), việc replay từ 0 sẽ làm mất dữ liệu của các trường không xuất hiện trong update sau cùng.
- **Quy trình Backfill chuẩn**:
  $$\text{Khởi tạo từ Snapshot đầy đủ tại } seq = N \longrightarrow \text{Replay delta mutations có } seq > N$$

---

## 3. Hệ quả (Consequences)
- Băng thông đồng bộ mạng giảm 60–80% vì chỉ truyền trường bị thay đổi.
- Drift DAO trên Flutter phải lắng nghe các trường dirty khi submit form.
- Projector trên server cần hỗ trợ merge logic thông minh thay vì câu lệnh `ON CONFLICT DO UPDATE` đơn giản.
