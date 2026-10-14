# Device Enrollment via QR / NFC — Installation & Setup Guide
# Đăng ký thiết bị bằng QR / NFC — Hướng dẫn cài đặt

> **Language / Ngôn ngữ:** [Tiếng Việt](#tiếng-việt) | [English](#english)

---

# Tiếng Việt

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

---
---

# English

> For **IT Administrators and System Engineers**.
> Staff User Guide: [`HUONG_DAN_NHAN_VIEN.md`](HUONG_DAN_NHAN_VIEN.md)

---

## 1. What Problem This Feature Solves

Previously, all devices shared a **single master secret string** (`IZIIAPP_SERVER_SECRET`).
This secret allowed calling sensitive administrative routes such as `/admin/reset` (wiping the database entirely) and `/admin/config` (overwriting `.env` and rotating secrets). A single phone dropped or lost in a growing room could compromise the entire farm system. Furthermore, because the secret was shared, **individual revocation was impossible** — blocking a single compromised device required changing the secret across the entire mesh network and reconfiguring every remaining tablet and mobile phone manually.

After implementing Device Enrollment:

| | Before | After |
|---|---|---|
| Each device has | Identical shared secret | **Unique** device token, individually revocable |
| Lost device | Rotate secret across whole system | Revoke in 1 click, takes 5 seconds |
| Audit trail | Untraceable actor | Server-verified `actor_device_id` |
| New device onboarding | Dictate secret over radio / write on paper | Scan QR code or tap NFC tag |

Three separate secret security scopes are now enforced:

```
IZIIAPP_SERVER_SECRET → /peer-sync/*   server ↔ server communication
IZIIAPP_ADMIN_SECRET  → /admin/*       administration (DO NOT distribute to worker devices)
device token          → /sync/*        individually provisioned per device via QR/NFC
```

---

## 2. Prerequisites & Preparation

### 2.1 Hardware (NFC Only)

| Tag Type | Memory Capacity | Assessment |
|---|---|---|
| **NTAG213** | 144 bytes | Sufficient, lowest cost — **Recommended** |
| NTAG215 | 504 bytes | Ample space if additional payload is needed |

You can purchase blank NFC stickers or plastic cards.

> NFC tags are optional — the **QR code** enrollment path works independently without requiring any additional hardware.

### 2.2 Server Update

```powershell
cd C:\...\izii_app\server
python -c "import app"      # verify there are no import errors
```

Restart the server. The logs should include a new security scope line:

```
🔑 [AUTH] Secret scopes — server=present · admin=SHARED with server (should separate) · device=optional
```

The warning `admin=SHARED with server` indicates that admin secret separation is needed — see step 3.1.

### 2.3 App Update

```powershell
cd C:\...\izii_app
flutter pub get
flutter analyze
flutter build apk --release        # or build windows
```

Required permissions are pre-configured in the source code:

| Platform | Permission | Status |
|---|---|---|
| Android | `CAMERA` | ✅ Existing |
| Android | `NFC` + `uses-feature required=false` | ✅ Added |
| iOS | `NSCameraUsageDescription` | ✅ Existing |
| iOS | `NFCReaderUsageDescription` | ✅ Added |

> ⚠️ **Manual step for iOS:** In Xcode, open **Runner → Signing & Capabilities → + Capability → Near Field Communication Tag Reading**. Without this capability enabled in Xcode, NFC reading will fail silently on iOS (QR code scanning will continue to work normally).

---

## 3. Configuration

### 3.1 Separate Admin Secret — Action Required Immediately

Open `server\.env` and add a **new** secret key (completely distinct from `IZIIAPP_SERVER_SECRET`):

```ini
IZIIAPP_ADMIN_SECRET=<SEPARATE-UNIQUE-RANDOM-STRING>
```

Generate a secure random string:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Restart the server. The startup log should now display `admin=dedicated`.

> If left blank, the server temporarily falls back to `SERVER_SECRET` for backwards compatibility. While existing builds will still connect, the security vulnerability remains unpatched until a dedicated secret is set.

### 3.2 Additional Options

```ini
# Invitation ticket Time-To-Live in seconds. 600 = 10 minutes.
# Increase when writing wall-mounted NFC tags (e.g., 3600 for 1 hour).
IZIIAPP_ENROLLMENT_TOKEN_TTL=600

# ⚠️ KEEP false UNTIL ALL factory devices have completed enrollment.
IZIIAPP_REQUIRE_DEVICE_TOKEN=false
```

### 3.3 Transition & Rollout Strategy

Setting `IZIIAPP_REQUIRE_DEVICE_TOKEN=false` allows **unenrolled devices to continue syncing**. This enables seamless zero-downtime adoption:

1. Enable the enrollment service while keeping strict enforcement disabled.
2. Enroll active tablets and phones shift by shift without interrupting farm operations.
3. Once the Devices Management screen confirms **all active devices are enrolled**, switch `IZIIAPP_REQUIRE_DEVICE_TOKEN=true`.

> 🔴 Enabling `true` prematurely will **disconnect all unenrolled devices immediately across the entire facility**.

---

## 4. Enrolling the First Device

The first device enrolled must be an **Administrator / Manager device** to gain administrative authority to issue enrollment tickets to other worker devices.

1. On the manager device: Navigate to **Settings → Sync Server**
   - Server URL: `http://192.168.x.x:8080`
   - Auth Token: Enter the exact `IZIIAPP_ADMIN_SECRET` value
2. Go to **Settings → Devices & Enrollment → Issue Enrollment Code**
3. The screen will render a QR code with a countdown timer.
4. On that device (or a second device): Tap the circular action button at the bottom of the Home screen → **Scan QR Code to Enroll**.

The circular button icon changes from **orange** (unregistered) to **green** (enrolled).

---

## 4b. Two Device Types: Shared vs. Personal

On the **Issue Enrollment Code** screen, administrators must select the **Device Type**. Selecting the wrong type requires revoking the device and re-enrolling it, so choose carefully:

| | **Shared Device** (Default) | **Personal Device** |
|---|---|---|
| Typical Hardware | Wall-mounted tablets in M1, M2, Cool Room | Manager / Supervisor iPhone or iPad |
| Usage Pattern | Multiple workers across rotating shifts | Single assigned user, taken home |
| Shift Check-in | **Mandatory** | **Exempt** |
| Session Expiry | 12 hours | Options: 8 / 12 / 16 / 24 hours, or Unlimited |
| Identity on Records | Active checked-in worker | Device owner assigned at enrollment |
| Alone Worker Safety | Blocked if shift check-in is missing | Allowed immediately |

**Rationale for Personal Device Exemption:** Shift check-in exists to answer *"who is currently operating this terminal?"*. For shared room tablets, the answer changes every shift and must be refreshed. For a manager's personal device, the identity is permanently established at provisioning time; requiring daily check-ins introduces friction without providing any additional safety benefit.

### Provisioning a Personal Device

1. Open **Issue Enrollment Code** → Select **Personal**.
2. **Owner Employee ID** *(Required)*: This serves as the system identity in lieu of daily check-in. It must match a valid Employee ID in the database (e.g., `EMP007`).
3. **Owner Name**: Displayed on the device status banner and in the administrative device registry.
4. **Max Shift Duration**: Applicable only when the owner manually taps "Start Shift" to appear on the active on-site personnel roster. Set to **Unlimited** if time tracking is not required.

> 🔒 The mode is encoded into the **invitation ticket on the server**, not within the QR/NFC payload. A client device scanning the code cannot forge its mode to bypass check-in — it strictly inherits the permissions established by the admin.

On personal devices, the banner at the top of the Home screen is styled in **purple** displaying the owner's name and `"Personal Device · Daily check-in exempt"`, replacing the default orange warning strip.

Under **Settings → Devices & Enrollment**, personal terminals are marked with a distinct `PERSONAL` badge alongside the owner ID for regulatory compliance and safety auditing.

---

## 5. Writing to NFC Tags

1. Manager device: **Issue Enrollment Code** → Generate ticket.
2. Scroll down and tap **Write Ticket to NFC Tag**.
3. Hold the NFC tag against the back of the device for 2–3 seconds.
4. The system confirms with `✅ Enrollment ticket written to tag`.

The NFC tag is now valid for enrolling **one** device within the configured TTL window.

**Batch Onboarding Best Practice:**
- Set `IZIIAPP_ENROLLMENT_TOKEN_TTL=3600` (1 hour) and write the tag prior to shift startup.
- Mount the tag at the changing room or briefing room entrance.
- Workers tap their assigned handheld devices to the tag upon entering.

> ⚠️ Enrollment tickets are **strictly single-use**. To enroll multiple devices, write a new ticket after each scan or prepare distinct tags. This prevents lost tags from being used for unauthorized batch onboarding.

**Recommendation:** Lock tags to **Read-Only** after writing (e.g., using the *NFC Tools* utility) to prevent malicious overwriting with counterfeit server endpoints.

---

## 6. Operations & Maintenance

### 6.1 Inspecting and Revoking Devices

Navigate to **Settings → Devices & Enrollment → Enrolled Devices List**.

| Column / Indicator | Description |
|---|---|
| Green Dot | Active & authorized |
| Gray Dot | Revoked |
| Last Active | Timestamp of most recent API synchronization |

To revoke access: Tap the 🚫 icon on the right. Confirm the prompt.

> Revocation takes effect **instantaneously** without requiring a server restart. Data synchronized by the device prior to revocation remains intact.

### 6.2 Lost Device Protocol

1. Navigate to **Settings → Devices List** → Locate the compromised terminal → Tap 🚫 **Revoke**.
2. Revocation is complete in 5 seconds. No other hardware requires reconfiguration.

### 6.3 Hardware Replacement

Revoke the damaged device, then generate a new enrollment code for the replacement unit. The new device will receive a distinct `device_id` and register as an updated node in the mesh directory.

---

## 7. Impact on Chat, Services, and Operations

Following enrollment, the application transitions from **Demo Profiles** to **Verified Device Identities**:

```
User.id   = device_id      (verified by server via bearer token)
User.name = device_name    (assigned during enrollment)
```

The Chat Contacts Directory is populated dynamically from enrolled terminals via `GET /devices/directory`.

**Automatic Fallback:** When zero devices are enrolled, the client preserves fallback demo profiles (Quill Phan, Tran Thi Bich...). As soon as the first real device is enrolled, the system switches automatically to live hardware nodes.

> ⚠️ **Architecture Note for Shared Terminals:** The baseline device identity model links **one device = one node**. If a tablet is shared across multiple shifts without user check-in, all shifts will log under the same device identity.
>
> While manageable in messaging, this is critical for **Alone Worker safety** — an alert stating `"device-abc123 is alone in Room 10"` does not identify the specific worker requiring assistance.
>
> For shared wall tablets, ensure workers perform **Shift Check-in** to bind their individual worker profile to the active terminal. The underlying architecture isolates `actor_device_id` and `actor_user_id` as distinct audit fields in all mutation logs.

---

## 8. Troubleshooting

| Symptom | Probable Cause | Resolution |
|---|---|---|
| "Admin privileges required" when generating code | Auth Token does not match `IZIIAPP_ADMIN_SECRET` | Correct the token under Settings → Sync Server |
| "Server has not configured IZIIAPP_ADMIN_SECRET" | Admin secret not defined in `.env` | Refer to Section 3.1 |
| "Invalid or expired enrollment code" | Ticket exceeded TTL or has already been redeemed | Generate a new enrollment code |
| "Too many requests" | IP rate-limit triggered (10 attempts / 5 min / IP) | Wait 5 minutes before retrying |
| NFC button disabled / dimmed | Device lacks NFC hardware or NFC is disabled in OS | Enable NFC in system settings or use QR scanning |
| iPhone fails to read NFC tags | Missing NFC capability in Xcode build | Refer to Section 2.3 |
| "Tag does not support NDEF" | Incompatible tag standard | Use standard NTAG213 or NTAG215 tags |
| "Tag capacity too small" | Tag capacity below 144 bytes | Replace with NTAG213 or larger |
| Chat directory remains on demo users | No real devices enrolled yet | Enroll at least one device, then tap **Sync Device Directory** |

Monitor live server logs:

```powershell
Get-Content data\logs\server.log -Tail 100 -Wait
```

Expected log signatures:

```
🎟️  [ENROLL] Issued invitation ticket, expires at ...
✅ [ENROLL] Device izii-d-xxxx (Tablet M1) registered from 192.168.1.55
⛔ [ENROLL] Rejected invalid ticket from 192.168.1.99
🚫 [ENROLL] Revoked token for device izii-d-xxxx
```

---

## 9. Command-Line Verification

```powershell
$admin = @{ 'X-iZii-Admin-Token' = '<IZIIAPP_ADMIN_SECRET>' }

# 1. Issue an enrollment ticket
$ticket = Invoke-RestMethod -Uri http://localhost:8080/admin/enrollment-token `
    -Method Post -Headers $admin -Body '{"note":"test"}' -ContentType 'application/json'
$ticket.payload_uri

# 2. Exchange ticket for device token (simulating client terminal)
$body = @{ token = $ticket.token; device_id = 'test-device-01'; device_name = 'Test Unit' } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/devices/enroll -Method Post `
    -Body $body -ContentType 'application/json'

# 3. Attempt replay of the same ticket -> MUST RETURN 403 (Single-use enforcement)
Invoke-RestMethod -Uri http://localhost:8080/devices/enroll -Method Post `
    -Body $body -ContentType 'application/json'

# 4. List all registered devices
Invoke-RestMethod -Uri http://localhost:8080/admin/devices -Headers $admin

# 5. Revoke the test device
Invoke-RestMethod -Uri http://localhost:8080/admin/devices/test-device-01/revoke `
    -Method Post -Headers $admin
```

The second exchange call **must return HTTP 403 Forbidden**. If it succeeds, single-use ticket protection is compromised — halt deployment and inspect backend token validation logic.

---

## 10. API Endpoint Reference

| Endpoint | Required Authorization | Description |
|---|---|---|
| `POST /admin/enrollment-token` | Admin Secret | Issue single-use enrollment ticket |
| `POST /devices/enroll` | Valid Ticket | Exchange ticket for permanent device token |
| `GET /devices/directory` | Device Token* | Retrieve live mesh device directory |
| `GET /devices/enroll/status` | Public | Inspect server enrollment policy & state |
| `GET /admin/devices` | Admin Secret | Query all enrolled terminals |
| `POST /admin/devices/{id}/revoke` | Admin Secret | Revoke device access immediately |

\* Enforced strictly when `IZIIAPP_REQUIRE_DEVICE_TOKEN=true`.

