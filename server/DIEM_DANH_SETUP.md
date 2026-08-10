# Điểm danh đầu ca — Hướng dẫn cài đặt

> Dành cho **IT / quản trị hệ thống**.
> Tài liệu cho nhân viên: [`HUONG_DAN_NHAN_VIEN.md`](HUONG_DAN_NHAN_VIEN.md)
> Đăng ký thiết bị: [`ENROLLMENT_SETUP.md`](ENROLLMENT_SETUP.md)

---

## 1. Vấn đề đang giải quyết

Mô hình trước đây coi **một thiết bị = một người**. Máy tính bảng dùng chung giữa
hai ca khiến hệ thống ghi cả hai ca là *cùng một người*.

Với Chat thì chỉ khó chịu. Với **Alone Worker thì nghiêm trọng**:

> Cảnh báo *"device-abc123 đang một mình trong Room 10 quá 45 phút"*
> **không cho biết phải đi cứu ai.**

Trong điều tra tai nạn lao động, câu hỏi đầu tiên của thanh tra là *"ai đang ở
trong phòng"*. Không trả lời được thì toàn bộ giá trị pháp lý của nhật ký sụp đổ.

### Mô hình mới

```
Thiết bị  ──đăng ký MỘT LẦN──►  device_token   (server xác thực qua hash)
Người     ──điểm danh MỖI CA──►  work_session   (gắn người vào máy)
Mutation  ──mang cả hai──────►  ai + máy nào
```

| | Trước | Sau |
|---|---|---|
| Danh tính người | Cố định theo máy | Theo phiên, đổi mỗi ca |
| Tablet dùng chung | Hai ca = một người | Phân biệt được |
| Cảnh báo Alone Worker | "máy nào" | **"ai"** |
| Ai đang trong nhà máy | Không biết | Màn hình giám sát thời gian thực |

---

## 2. Ba cách điểm danh

Hiện đồng thời trên cùng một màn hình — mỗi tổ chọn cách tiện nhất, không cần
cấu hình gì.

| Cách | Mã | Phù hợp khi | Ghi chú |
|---|---|---|---|
| **Thẻ nhân viên NFC** | `nfc_badge` | Đeo găng, phòng thiếu sáng | Nhanh nhất. Cần mua thẻ NTAG213 |
| **Chọn tên từ danh sách** | `list` | Mặc định, luôn dùng được | Không cần phần cứng gì thêm |
| **Chọn tên + mã PIN** | `pin` | Cần chống chọn nhầm/mạo danh | Quản lý đặt PIN trước |

Nhân viên đã được đặt PIN sẽ **tự động** phải nhập PIN — biểu tượng khoá 🔒 hiện
bên cạnh tên trong danh sách. Nhân viên chưa có PIN thì chạm tên là vào ca ngay.

---

## 3. Cài đặt

### 3.1 Cập nhật server

```powershell
cd C:\...\izii_app\server
python -c "import app"      # kiểm tra không lỗi import
.\run_server.bat
```

Hai bảng mới tạo tự động lúc khởi động: `work_sessions` và `employee_pins`.

**Kiểm chứng:**

```powershell
cd data
sqlite3 iziiapp.db ".tables" | Select-String "work_sessions|employee_pins"
```

### 3.2 Cập nhật app

```powershell
cd C:\...\izii_app
flutter pub get
flutter analyze
flutter build apk --release
```

Không cần thêm quyền mới — NFC và camera đã khai từ phần đăng ký thiết bị.

### 3.3 Điều kiện tiên quyết

Điểm danh **yêu cầu máy đã đăng ký** (có `device_token`). Phiên gắn với
`device_id` nên không có thiết bị thì không có gì để gắn.

Thứ tự triển khai đúng: **đăng ký thiết bị trước → điểm danh sau**.

---

## 4. Đặt mã PIN cho nhân viên

Chỉ làm khi tổ đó chọn cách điểm danh bằng PIN.

```powershell
$admin = @{ 'X-iZii-Admin-Token' = '<IZIIAPP_ADMIN_SECRET>' }
$body  = @{ user_id = 'EMP001'; pin = '4728' } | ConvertTo-Json

Invoke-RestMethod -Uri http://localhost:8080/sessions/pin -Method Post `
    -Headers $admin -Body $body -ContentType 'application/json'
```

**Quy tắc PIN:**

- 4–6 chữ số
- Server từ chối các dãy dễ đoán: `0000`, `1111`, `1234`, `123456`, `000000`, `111111`
- Lưu dạng **hash PBKDF2 200.000 vòng** kèm salt riêng cho từng người

> PIN chỉ 4–6 chữ số nên không gian tìm kiếm rất nhỏ (10.000–1.000.000). Hash nhanh
> sẽ bị vét cạn trong vài giây nếu database lộ. PBKDF2 với 200.000 vòng làm việc đó
> tốn hàng giờ cho mỗi PIN — đủ để phát hiện và xử lý.

PIN lưu ở **server**, cố ý không để trong bảng nhân viên phía app: nếu để trong
mutation log thì nó sẽ được đồng bộ xuống **mọi thiết bị**.

---

## 5. Cấp thẻ nhân viên NFC

Hệ thống nay có **ba loại thẻ NFC** — đừng nhầm lẫn:

| Loại | Nội dung | Vòng đời | Ai giữ |
|---|---|---|---|
| **Đăng ký thiết bị** | Vé mời | Dùng **một lần**, hết hạn 10 phút | Quản lý phát tạm |
| **Công việc phòng** | Phòng + loại việc | Dán **cố định** ở cửa phòng | Dán tường |
| **Nhân viên** | Mã + tên nhân viên | Cấp cho từng người, **dùng lâu dài** | Nhân viên giữ |

App tự nhận diện và báo rõ nếu chạm nhầm loại thẻ, ví dụ:
*"Đây là thẻ ĐĂNG KÝ THIẾT BỊ, không phải thẻ nhân viên."*

**Ghi thẻ nhân viên** — dùng `EmployeeBadgeService.write()` từ màn hình quản lý,
hoặc ghi thủ công bằng app NFC Tools với nội dung URI:

```
izii://staff?u=EMP001&n=Nguy%E1%BB%85n%20V%C4%83n%20An&d=Growing
```

> ⚠️ **Thẻ nhân viên KHÔNG PHẢI giấy tờ tuỳ thân.** Nó chỉ chứa mã nhân viên,
> không chứa bí mật nào. Ai nhặt được cũng đọc được — nhưng mã nhân viên vốn không
> phải bí mật. Tổ nào cần chống mạo danh thì **kết hợp thêm PIN**.

**Nên khoá thẻ chỉ đọc** sau khi ghi, để không ai sửa nội dung thành mã người khác.

---

## 6. Quy tắc vòng đời phiên

| Quy tắc | Giá trị | Vì sao |
|---|---|---|
| Tự hết hạn | **12 giờ** (máy dùng chung) | Công nhân hiếm khi bấm "kết thúc ca" — họ cất máy rồi về. Không giới hạn thì phiên treo qua đêm và mọi thao tác ca sau bị gán nhầm cho người ca trước |
| Tự hết hạn | **Tuỳ chỉnh / không giới hạn** (máy cá nhân) | Máy một người dùng, không có "người ca sau" để gán nhầm |
| Điểm danh mới đóng phiên cũ | Tự động | Ca sau chỉ cần điểm danh, không phải nhớ kết thúc hộ người ca trước |
| Alone Worker | **Bắt buộc có phiên** | Cảnh báo an toàn phải nói được đích danh ai |
| Công việc khác | Không bắt buộc | Không cản trở sản xuất |

Lý do đổi `ended_reason` ghi rõ trong database: `manual` · `timeout` · `replaced`.

---

## 6b. Ngoại lệ: máy cá nhân của Manager / Supervisor

Không phải máy nào cũng phải điểm danh. Khi cấp mã đăng ký, quản lý chọn **Loại
thiết bị** (chi tiết ở `ENROLLMENT_SETUP.md` mục 4b):

| | Máy **dùng chung** | Máy **cá nhân** |
|---|---|---|
| Điểm danh đầu ca | Bắt buộc | Không cần |
| Danh tính lấy từ | Phiên đang mở | `owner_user_id` khai lúc cấp máy |
| Phiên hết hạn | 12 giờ | Tuỳ chỉnh, mặc định không giới hạn |
| Banner trên Home | Cam (chưa điểm danh) / Xanh (đang trong ca) | Tím, kèm tên chủ máy |
| Alone Worker | Chặn nếu chưa điểm danh | Cho qua |

**Điều kiện an toàn không bị nới lỏng.** Ràng buộc thật là *"hệ thống phải biết
đích danh ai đang cầm máy"*, chứ không phải *"phải có phiên"*. Server kiểm bằng
`DeviceIdentity.identity_is_known`:

```python
# security_auth.py
@property
def identity_is_known(self) -> bool:
    if self.is_personal:
        return bool(self.user_id)   # chủ máy đã khai lúc cấp máy
    return self.has_active_session  # phải điểm danh
```

Máy cá nhân **chưa khai chủ máy** vẫn bị chặn như máy chưa điểm danh — server từ
chối cấp vé `personal` nếu thiếu `owner_user_id`, nên trường hợp này chỉ xảy ra
với dữ liệu cũ trước khi migration.

Máy cá nhân vẫn **bấm "Bắt đầu ca" được** (không bắt buộc) để xuất hiện trong
danh sách ai đang có mặt tại nhà máy — hữu ích khi Manager xuống hiện trường.

**Kiểm tra nhanh:** máy cá nhân gọi `GET /sessions/current` phải nhận:

```json
{ "profile": "personal", "requires_check_in": false, "identity_is_known": true }
```

---

## 7. Ràng buộc Alone Worker

Đây là ràng buộc quan trọng nhất của toàn bộ tính năng.

**Kiểm ở hai tầng:**

| Tầng | Vai trò |
|---|---|
| **Client** (`growing_tab_screen`) | Mở luôn màn hình điểm danh thay vì báo lỗi khó hiểu — trải nghiệm |
| **Server** (`sync.py`) | Trả **409** nếu không có phiên — **ràng buộc thật** |

Client chỉ là tiện lợi. Ai sửa app hoặc gọi API trực tiếp vẫn bị server chặn.

**Thử nghiệm:**

```powershell
# Chưa điểm danh mà tạo alone_worker → phải nhận 409
$h = @{ 'X-iZii-Device-Token' = '<device_token>' }
$b = @{ mutations = @(@{
    id = [guid]::NewGuid().ToString()
    table = 'mushroom_jobs'
    operation = 'insert'
    data = @{ id = 'test'; room_id = 'room_10'; job_type = 'alone_worker' }
}) } | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri http://localhost:8080/sync/push -Method Post `
    -Headers $h -Body $b -ContentType 'application/json'
```

Kết quả mong đợi: **HTTP 409** với `"error": "no_active_work_session"`.

Nếu thành công thì ràng buộc đang hỏng — dừng triển khai và kiểm tra lại.

---

## 8. Màn hình giám sát "Ai đang trong ca"

Mở từ thanh điểm danh trên Home → biểu tượng 👥.

| Cột | Ý nghĩa |
|---|---|
| Tên | Người đang trong ca |
| Phòng ban · Zone | Nơi làm việc |
| Máy | Thiết bị đang dùng |
| Cách điểm danh | thẻ NFC / mã PIN / chọn tên |
| Thời gian | Đã làm bao lâu |

**Mã màu theo thời lượng:**

- 🟢 Xanh — dưới 8 giờ, bình thường
- 🟠 Cam — trên 8 giờ, ca dài
- 🔴 Đỏ — trên 10 giờ, cần kiểm tra

Ca dài bất thường có thể là quên kết thúc ca, cũng có thể là người thực sự còn
trong nhà máy quá lâu. **Cả hai đều đáng để quản lý biết.**

Màn hình tự làm mới mỗi 30 giây — để mở được trên máy phòng điều khiển.

---

## 9. Bảng tra endpoint

| Endpoint | Quyền | Công dụng |
|---|---|---|
| `POST /sessions/start` | Device token | Điểm danh đầu ca |
| `POST /sessions/end` | Device token | Kết thúc ca |
| `GET /sessions/current` | Device token | Phiên đang mở của máy này |
| `GET /sessions/active` | Device token | Ai đang trong ca (toàn hệ thống) |
| `POST /sessions/pin` | **Admin** | Đặt/đổi PIN cho nhân viên |
| `GET /sessions/pin/status` | Device token | Danh sách ai đã có PIN |

---

## 10. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| "Máy này chưa đăng ký" khi điểm danh | Chưa có `device_token` | Đăng ký thiết bị trước (xem `ENROLLMENT_SETUP.md`) |
| "Nhân viên này chưa được đặt mã PIN" | Chọn cách PIN nhưng chưa đặt | Đặt PIN qua API, hoặc chọn tên trực tiếp |
| "Mã PIN không đúng" | Gõ sai | Quản lý đặt lại PIN mới |
| Không thấy nút "Chạm thẻ nhân viên" | Máy không có NFC hoặc NFC tắt | Bật NFC, hoặc dùng cách chọn tên |
| Tạo Alone Worker bị chặn | Chưa điểm danh | App tự mở màn hình điểm danh — làm theo |
| Phiên biến mất giữa ca | Quá 12 giờ | Điểm danh lại. Nếu ca dài hơn 12 giờ thì báo để điều chỉnh `SESSION_MAX_HOURS` |
| Người đang làm mà không hiện ở màn hình giám sát | Chưa điểm danh | Nhắc nhân viên |

**Xem log:**

```powershell
Get-Content data\logs\server.log -Tail 100 -Wait | Select-String "SESSION"
```

Các dòng liên quan:

```
👤 [SESSION] Nguyễn Văn An điểm danh trên izii-d-xxxx (cách: nfc_badge)
👤 [SESSION] Trần Thị Bích điểm danh ... — thay phiên của Nguyễn Văn An
👋 [SESSION] Nguyễn Văn An kết thúc ca.
⏰ [SESSION] Tự đóng 2 phiên quá 12 giờ.
⛔ [SESSION] PIN sai cho EMP001 từ máy izii-d-xxxx
⛔ [SESSION] Từ chối tạo Alone Worker: chưa điểm danh đầu ca.
```

---

## 11. Triển khai theo giai đoạn

Đây là thay đổi **quy trình làm việc**, không chỉ là tính năng phần mềm. Phần khó
không nằm ở code mà ở việc khiến mọi người nhớ điểm danh đầu ca.

| Tuần | Việc | Mục tiêu |
|---|---|---|
| 1 | Cập nhật server + app. Phổ biến cho quản đốc từng tổ | Mọi người hiểu vì sao |
| 2 | Chạy thử **một tổ** — tổ có nhiều Alone Worker nhất | Phát hiện vướng mắc thực tế |
| 3 | Mở rộng các tổ còn lại. Cấp thẻ NFC nếu chọn cách đó | Toàn nhà máy |
| 4 | Theo dõi màn hình giám sát mỗi ngày | Phát hiện ai hay quên |

**Chỉ số theo dõi:** số công việc Alone Worker bị chặn vì chưa điểm danh. Con số
này phải **giảm dần về gần 0** sau 2 tuần. Nếu không giảm, vấn đề nằm ở khâu phổ
biến chứ không phải phần mềm.
