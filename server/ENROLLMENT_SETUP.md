# Đăng ký thiết bị bằng QR / NFC — Hướng dẫn cài đặt

> Dành cho **IT / quản trị hệ thống**.
> Tài liệu cho nhân viên sử dụng: [`HUONG_DAN_NHAN_VIEN.md`](HUONG_DAN_NHAN_VIEN.md)

---

## 1. Tính năng này giải quyết vấn đề gì

Trước đây mọi thiết bị dùng **chung một chuỗi bí mật** `IZIIAPP_SERVER_SECRET`.
Chuỗi đó cho phép gọi `/admin/reset` (xoá sạch database) và `/admin/config`
(ghi đè `.env`, đổi luôn secret). Một điện thoại rơi trong phòng trồng là mất
cả hệ thống, và vì dùng chung nên **không thu hồi riêng lẻ được** — muốn chặn
một máy phải đổi secret trên toàn bộ mesh rồi cấu hình lại mọi máy còn lại.

Sau khi triển khai:

| | Trước | Sau |
|---|---|---|
| Mỗi máy có | Cùng một secret | Token **riêng**, thu hồi độc lập |
| Mất máy | Đổi secret toàn hệ thống | Thu hồi 1 dòng, 5 giây |
| Ai làm gì | Không truy được | `actor_device_id` server xác thực |
| Cấp máy mới | Đọc secret qua bộ đàm / dán giấy | Quét QR hoặc chạm thẻ |

Ba phạm vi bí mật nay tách bạch:

```
IZIIAPP_SERVER_SECRET → /peer-sync/*   server ↔ server
IZIIAPP_ADMIN_SECRET  → /admin/*       quản trị (KHÔNG đưa cho máy công nhân)
device token          → /sync/*        cấp riêng từng máy qua QR/NFC
```

---

## 2. Chuẩn bị

### 2.1 Phần cứng (chỉ nếu dùng NFC)

| Loại thẻ | Dung lượng | Đánh giá |
|---|---|---|
| **NTAG213** | 144 byte | Đủ dùng, rẻ nhất — **khuyến nghị** |
| NTAG215 | 504 byte | Dư dả nếu muốn nhét thêm dữ liệu |

Mua thẻ trắng dạng sticker hoặc thẻ nhựa. Vài nghìn đồng một cái.

> Không có thẻ vẫn dùng được — đường **QR** hoạt động độc lập, không cần phần
> cứng gì thêm.

### 2.2 Cập nhật server

```powershell
cd C:\...\izii_app\server
python -c "import app"      # kiểm tra không lỗi import
```

Khởi động lại server. Log phải có dòng mới:

```
🔑 [AUTH] Phạm vi bí mật — server=có · admin=DÙNG CHUNG server (nên tách) · device=tuỳ chọn
```

Dòng `admin=DÙNG CHUNG server` là **cảnh báo** — xem bước 3.1.

### 2.3 Cập nhật app

```powershell
cd C:\...\izii_app
flutter pub get
flutter analyze
flutter build apk --release        # hoặc build windows
```

Quyền đã khai sẵn trong mã nguồn:

| Nền tảng | Quyền | Trạng thái |
|---|---|---|
| Android | `CAMERA` | ✅ có sẵn |
| Android | `NFC` + `uses-feature required=false` | ✅ vừa thêm |
| iOS | `NSCameraUsageDescription` | ✅ có sẵn |
| iOS | `NFCReaderUsageDescription` | ✅ vừa thêm |

> ⚠️ **iOS còn một bước thủ công:** mở Xcode → Runner → Signing & Capabilities
> → **+ Capability** → **Near Field Communication Tag Reading**. Không có bước
> này thì NFC im lặng không hoạt động trên iPhone (QR vẫn chạy bình thường).

---

## 3. Cấu hình

### 3.1 Tách secret admin — làm ngay

Mở `server\.env`, thêm dòng **mới** (khác hoàn toàn `IZIIAPP_SERVER_SECRET`):

```ini
IZIIAPP_ADMIN_SECRET=<chuỗi-ngẫu-nhiên-KHÁC>
```

Sinh chuỗi:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Khởi động lại. Log phải đổi thành `admin=riêng`.

> Bỏ trống thì server tạm dùng chung `SERVER_SECRET` để bản cũ không gãy — vẫn
> chạy được, nhưng lỗ hổng ban đầu vẫn còn nguyên.

### 3.2 Các tuỳ chọn khác

```ini
# Vé mời sống bao lâu (giây). 600 = 10 phút.
# Ghi thẻ NFC dán tường thì tăng lên, ví dụ 3600.
IZIIAPP_ENROLLMENT_TOKEN_TTL=600

# ⚠️ ĐỂ false CHO TỚI KHI TẤT CẢ máy đã đăng ký xong.
IZIIAPP_REQUIRE_DEVICE_TOKEN=false
```

### 3.3 Giai đoạn chuyển tiếp

`IZIIAPP_REQUIRE_DEVICE_TOKEN=false` nghĩa là máy **chưa đăng ký vẫn đồng bộ
được**. Đây là chủ ý:

1. Bật tính năng, mọi máy vẫn chạy bình thường
2. Đăng ký dần từng máy theo ca, không gián đoạn sản xuất
3. Khi màn hình quản lý cho thấy **đủ số máy**, mới đổi thành `true`

> 🔴 Bật `true` sớm = **toàn bộ nhà máy mất kết nối cùng lúc**.

---

## 4. Đăng ký máy đầu tiên

Máy đầu tiên phải là **máy quản lý** — nó cần quyền admin để cấp mã cho các máy sau.

1. Trên máy quản lý: **Settings → Sync Server**
   - Server URL: `http://192.168.x.x:8080`
   - Auth Token: đúng giá trị `IZIIAPP_ADMIN_SECRET`
2. **Settings → Thiết bị & Đăng ký → Cấp mã đăng ký**
3. Màn hình hiện QR kèm đồng hồ đếm ngược
4. Trên chính máy đó (hoặc máy thứ hai): nút tròn góc dưới màn hình Home →
   **Quét mã QR để đăng ký**

Nút tròn đổi từ **cam** sang **xanh** là xong.

---

## 4b. Hai loại thiết bị: dùng chung và cá nhân

Trên màn hình **Cấp mã đăng ký** có ô chọn **Loại thiết bị**. Chọn sai thì phải
thu hồi máy và đăng ký lại, nên chọn cẩn thận ngay từ đầu.

| | **Dùng chung** (mặc định) | **Cá nhân** |
|---|---|---|
| Máy điển hình | Tablet gắn tường phòng M1, M2, CR | iPhone/iPad của Manager, Supervisor |
| Ai dùng | Nhiều người, nhiều ca | Đúng một người, mang về nhà |
| Điểm danh đầu ca | **Bắt buộc** | **Không cần** |
| Phiên hết hạn sau | 12 giờ | Tuỳ chọn: 8/12/16/24 giờ hoặc không giới hạn |
| Danh tính ghi vào dữ liệu | Người vừa điểm danh | Chủ máy đã khai lúc cấp mã |
| Alone Worker | Chặn nếu chưa điểm danh | Cho qua ngay |

**Vì sao máy cá nhân được miễn điểm danh:** điểm danh tồn tại để trả lời câu hỏi
"ai đang cầm máy này". Với tablet dùng chung, câu trả lời đổi mỗi ca nên phải hỏi
lại mỗi ca. Với iPhone riêng của Manager, câu trả lời đã cố định từ lúc cấp máy —
bắt điểm danh mỗi sáng chỉ thêm thao tác mà không thêm chút an toàn nào.

### Cấp mã cho máy cá nhân

1. **Cấp mã đăng ký** → chọn **Cá nhân**
2. **Mã nhân viên chủ máy** — bắt buộc. Đây là danh tính thay cho việc điểm danh,
   nên phải khớp mã nhân viên thật trong hệ thống (VD: `EMP007`)
3. **Tên chủ máy** — hiện trên banner của máy đó và trong danh sách thiết bị
4. **Thời lượng ca tối đa** — chỉ áp dụng khi chủ máy tự bấm "Bắt đầu ca" để
   xuất hiện trong danh sách người có mặt tại nhà máy. Để **Không giới hạn** nếu
   không cần theo dõi giờ

> 🔒 Chế độ được ghi vào **vé mời** ở server, không nằm trong mã QR/NFC. Máy quét
> mã không tự khai được mình là `personal` để né điểm danh — nó chỉ nhận về chế
> độ mà quản lý đã chọn.

Trên máy cá nhân, banner đầu màn hình Home có màu **tím** kèm tên chủ máy và dòng
"Máy riêng · không cần điểm danh hằng ngày", thay cho dải cam cảnh báo.

Trong **Settings → Thiết bị & Đăng ký**, máy cá nhân có nhãn `CÁ NHÂN` và dòng
chủ máy — đây là ngoại lệ của quy tắc an toàn nên phải nhìn thấy được khi rà soát.

---

## 5. Ghi thẻ NFC

1. Máy quản lý: **Cấp mã đăng ký** → tạo mã
2. Kéo xuống, bấm **Ghi vé lên thẻ NFC**
3. Đưa thẻ vào mặt sau máy, giữ 2-3 giây
4. Hiện `✅ Đã ghi vé mời lên thẻ`

Thẻ này giờ dùng được cho **một** máy, trong thời gian TTL.

**Cách dùng thực tế cho onboarding hàng loạt:**

- Đặt TTL = 3600 (1 giờ), ghi thẻ đầu ca
- Dán thẻ lên cửa phòng thay đồ
- Từng công nhân chạm máy vào thẻ khi vào ca

> ⚠️ Vé **dùng một lần**. Nhiều máy thì phải ghi lại thẻ sau mỗi máy, hoặc cấp
> nhiều thẻ. Đây là chủ ý — thẻ rơi không thể dùng để đăng ký hàng loạt.

**Nên khoá thẻ chỉ đọc** sau khi ghi (dùng app NFC Tools), để không ai sửa nội
dung thẻ thành URL giả.

---

## 6. Vận hành

### 6.1 Xem và thu hồi thiết bị

**Settings → Thiết bị & Đăng ký → Danh sách thiết bị đã đăng ký**

| Cột | Ý nghĩa |
|---|---|
| Chấm xanh | Đang hoạt động |
| Chấm xám | Đã thu hồi |
| Hoạt động gần nhất | Lần cuối máy gọi API |

Thu hồi: bấm 🚫 bên phải. Có hộp thoại xác nhận.

> Thu hồi có hiệu lực **ngay lập tức**, không cần khởi động lại server. Dữ liệu
> máy đó đã đồng bộ trước đó vẫn giữ nguyên.

### 6.2 Máy mất — làm gì

1. Settings → Danh sách thiết bị → tìm máy → 🚫 **Thu hồi**
2. Xong. Không cần đụng vào máy nào khác.

### 6.3 Máy hỏng, thay máy mới

Thu hồi máy cũ, cấp mã mới cho máy thay thế. Máy mới có `device_id` khác nên
xuất hiện như một liên hệ mới trong Chat.

---

## 7. Ảnh hưởng tới Chat / Dịch vụ / Hàng hoá

Sau khi đăng ký, app chuyển từ **User demo** sang **danh tính thiết bị thật**:

```
User.id   = device_id      (server xác thực qua token)
User.name = tên thiết bị   (đặt lúc đăng ký)
```

Danh bạ Chat = danh sách máy đã đăng ký, lấy từ `GET /devices/directory`.

**Chuyển đổi tự động:** chưa có máy nào đăng ký → vẫn dùng danh bạ demo
(Quill Phan, Trần Thị Bích...). Có máy đăng ký → tự chuyển sang danh bạ thật.
Không cần sửa code hay cấu hình.

> ⚠️ **Giới hạn cần biết trước khi triển khai rộng:** mô hình hiện tại là
> **một thiết bị = một người**. Nếu một tablet dùng chung nhiều ca thì cả hai
> ca hiện là *cùng một người*.
>
> Với Chat chỉ hơi khó chịu. Với **Alone Worker thì nghiêm trọng** — cảnh báo
> "device-abc123 đang một mình trong Room 10" không cho biết phải đi cứu ai.
>
> Nếu có tablet dùng chung, cần bổ sung bước "check-in đầu ca" tách người khỏi
> máy. Hạ tầng đã sẵn sàng: mutation log mang `actor_device_id` và
> `actor_user_id` là hai trường riêng biệt.

---

## 8. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| "Không có quyền admin" khi cấp mã | Auth Token ≠ `IZIIAPP_ADMIN_SECRET` | Sửa ở Settings → Sync Server |
| "Máy chủ chưa cấu hình IZIIAPP_ADMIN_SECRET" | Chưa khai secret nào | Xem mục 3.1 |
| "Mã không hợp lệ hoặc đã hết hạn" | Vé quá TTL, hoặc đã dùng rồi | Cấp mã mới |
| "Thử quá nhiều lần" | Rate-limit 10 lần / 5 phút / IP | Đợi 5 phút |
| Nút NFC bị mờ | Máy không có NFC, hoặc NFC đang tắt | Bật NFC trong Settings máy; hoặc dùng QR |
| iPhone không đọc thẻ | Thiếu capability trong Xcode | Xem mục 2.3 |
| "Thẻ này không hỗ trợ NDEF" | Thẻ sai loại | Dùng NTAG213/215 |
| "Thẻ quá nhỏ" | Thẻ dưới 144 byte | Đổi NTAG213 trở lên |
| Danh bạ vẫn là user demo | Chưa máy nào đăng ký | Đăng ký ít nhất 1 máy, rồi **Đồng bộ danh bạ thiết bị** |

Xem log server:

```powershell
Get-Content data\logs\server.log -Tail 100 -Wait
```

Các dòng liên quan:

```
🎟️  [ENROLL] Đã cấp vé mời, hết hạn ...
✅ [ENROLL] Thiết bị izii-d-xxxx (Tablet M1) đã đăng ký từ 192.168.1.55
⛔ [ENROLL] Từ chối vé không hợp lệ từ 192.168.1.99
🚫 [ENROLL] Đã thu hồi token của thiết bị izii-d-xxxx
```

---

## 9. Kiểm chứng bằng dòng lệnh

```powershell
$admin = @{ 'X-iZii-Admin-Token' = '<IZIIAPP_ADMIN_SECRET>' }

# Cấp vé
$ticket = Invoke-RestMethod -Uri http://localhost:8080/admin/enrollment-token `
    -Method Post -Headers $admin -Body '{"note":"test"}' -ContentType 'application/json'
$ticket.payload_uri

# Đổi vé lấy token (mô phỏng thiết bị)
$body = @{ token = $ticket.token; device_id = 'test-device-01'; device_name = 'Máy test' } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/devices/enroll -Method Post `
    -Body $body -ContentType 'application/json'

# Dùng lại vé đó → phải bị TỪ CHỐI (vé dùng một lần)
Invoke-RestMethod -Uri http://localhost:8080/devices/enroll -Method Post `
    -Body $body -ContentType 'application/json'

# Danh sách
Invoke-RestMethod -Uri http://localhost:8080/admin/devices -Headers $admin

# Thu hồi
Invoke-RestMethod -Uri http://localhost:8080/admin/devices/test-device-01/revoke `
    -Method Post -Headers $admin
```

Lần gọi thứ hai **phải** trả lỗi 403. Nếu thành công thì cơ chế dùng-một-lần
đang hỏng — dừng triển khai và kiểm tra lại.

---

## 10. Bảng tra endpoint

| Endpoint | Quyền | Công dụng |
|---|---|---|
| `POST /admin/enrollment-token` | Admin | Cấp vé mời |
| `POST /devices/enroll` | Vé mời | Đổi vé lấy token |
| `GET /devices/directory` | Device token* | Danh bạ thiết bị |
| `GET /devices/enroll/status` | Không | Chính sách của server |
| `GET /admin/devices` | Admin | Danh sách đã đăng ký |
| `POST /admin/devices/{id}/revoke` | Admin | Thu hồi |

\* Chỉ bắt buộc khi `IZIIAPP_REQUIRE_DEVICE_TOKEN=true`.
