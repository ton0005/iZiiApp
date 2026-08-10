# Kế hoạch hoàn thiện 6 khoảng trống bảo mật

> Nối tiếp slide 18 của bộ trình bày. Mỗi mục nêu rõ: vì sao cần, cái gì đã có sẵn,
> thiết kế đề xuất, công việc cụ thể, và tiêu chí nghiệm thu.

---

## Tổng quan ưu tiên

| # | Khoảng trống | Mức độ | Công sức | Đã có sẵn gì | Thứ tự |
|---|---|---|---|---|---|
| **G1** | Danh tính người dùng tách khỏi thiết bị | 🔴 Cao | 3–4 tuần | Bảng nhân viên, 2 trường actor riêng biệt | **1** |
| **G6** | Giám sát tập trung | 🟠 Vừa | 3–4 tuần | Log có sẵn, cần cấu trúc lại | **2** |
| **G2** | Chữ ký số trên bản ghi | 🟠 Vừa | 3 tuần | Cặp khoá Ed25519 đã sinh sẵn | **3** |
| **G4** | Mã hoá cơ sở dữ liệu | 🟡 Thấp–Vừa | 1 + 3 tuần | — | **4** |
| **G5** | Vòng đời chứng chỉ | 🟡 Thấp | 2 tuần | Script sinh chứng chỉ | **5** |
| **G3** | Kiểm định độc lập | 🔴 Cao | 4–6 tuần | — | **6** |

**Logic sắp xếp:** G1 đứng đầu vì đó là nghĩa vụ pháp lý, không phải kỹ thuật.
G3 đứng cuối vì kiểm định phải chạy trên mã nguồn đã ổn định — kiểm định code đang thay
đổi là trả tiền hai lần.

**Tổng thời lượng:** khoảng **6 tháng** cho một người làm toàn thời gian, hoặc **4 tháng**
nếu tách G3 (thuê ngoài) chạy song song ở cuối.

---

## G1 — Danh tính người dùng tách khỏi thiết bị

### Vì sao đây là mục số một

Không phải vì kỹ thuật, mà vì **trách nhiệm pháp lý về an toàn lao động**.

Hiện tại mô hình là *một thiết bị = một người*. Nếu một tablet dùng chung giữa hai ca,
hệ thống ghi cả hai ca là cùng một người. Với Chat thì chỉ khó chịu. Với **Alone Worker
thì nghiêm trọng**: cảnh báo *"device-abc123 đang một mình trong Room 10 quá 45 phút"*
không cho biết phải đi cứu ai.

Trong một vụ điều tra tai nạn lao động, câu hỏi đầu tiên của thanh tra là *"ai đang ở
trong phòng"*. Không trả lời được thì toàn bộ giá trị pháp lý của hệ thống ghi nhận sụp đổ.

### Cái gì đã có sẵn

Hạ tầng đã chuẩn bị đúng hướng từ trước:

- `sync_mutations` có **hai trường riêng biệt**: `actor_device_id` và `actor_user_id`
- Bảng `mushroom_employees` đã có danh sách nhân viên, phòng ban, vai trò
- `security_auth.DeviceIdentity` đã mang cả `device_id` lẫn `user_id`
- Hạ tầng NFC (`NfcUriService`) dùng lại được cho thẻ nhân viên

Nghĩa là **không phải xây lại** — chỉ cần thêm lớp phiên làm việc ở giữa.

### Thiết kế đề xuất

```
Thiết bị   ──đăng ký một lần──►  device_token   (server xác thực)
Người      ──điểm danh mỗi ca──►  work_session  (gắn user_id vào device_id)
Mutation   ──mang cả hai────────►  ai + máy nào
```

**Bảng mới trên server:**

```sql
CREATE TABLE IF NOT EXISTS work_sessions (
    id            TEXT PRIMARY KEY,
    device_id     TEXT NOT NULL,
    user_id       TEXT NOT NULL,      -- mã nhân viên
    user_name     TEXT,
    zone          TEXT,
    started_at    TEXT NOT NULL,
    ended_at      TEXT,               -- NULL = đang trong ca
    ended_reason  TEXT,               -- 'manual' | 'timeout' | 'shift_change'
    created_by    TEXT                -- device_id đã tạo phiên
);
CREATE INDEX idx_work_sessions_device ON work_sessions(device_id, ended_at);
```

**Ba cách điểm danh, chọn theo thực tế từng tổ:**

| Cách | Phù hợp khi | Ghi chú |
|---|---|---|
| **Thẻ nhân viên NFC** | Có ngân sách mua thẻ | Nhanh nhất, dùng được khi đeo găng. Tái dùng `NfcUriService` |
| **Chọn từ danh sách + PIN 4 số** | Tổ nhỏ, ít người | Không tốn phần cứng. PIN chống chọn nhầm tên người khác |
| **Máy cá nhân — bỏ qua điểm danh** | Mỗi người một điện thoại | Phiên tự tạo khi đăng ký, không hết hạn |

**Quy tắc vòng đời phiên:**

- Tự kết thúc sau **12 giờ** — tránh phiên treo qua đêm gán nhầm cho ca sau
- Điểm danh người mới trên cùng máy → tự đóng phiên cũ
- **Alone Worker bắt buộc có phiên đang mở** — không có thì từ chối tạo công việc

Quy tắc cuối là điểm mấu chốt: nó biến việc điểm danh từ *tuỳ chọn* thành *bắt buộc*
đúng ở chỗ cần nhất, mà không cản trở các công việc thông thường.

### Công việc

| # | Việc | Ước tính |
|---|---|---|
| 1 | Bảng `work_sessions` + migration (SQLite & PostgreSQL) | 2 ngày |
| 2 | Endpoint `POST /sessions/start`, `POST /sessions/end`, `GET /sessions/current` | 3 ngày |
| 3 | `optional_device` bổ sung tra phiên đang mở → gắn `user_id` thật | 2 ngày |
| 4 | Màn hình điểm danh đầu ca (Flutter) | 4 ngày |
| 5 | Thẻ nhân viên NFC — ghi & đọc | 3 ngày |
| 6 | Ràng buộc: Alone Worker yêu cầu phiên đang mở | 2 ngày |
| 7 | Báo cáo "ai đang trong ca" cho quản lý | 3 ngày |
| 8 | Cập nhật tài liệu hướng dẫn nhân viên | 1 ngày |

### Nghiệm thu

- [ ] Hai người dùng chung một tablet trong hai ca → nhật ký phân biệt được
- [ ] Cảnh báo Alone Worker hiển thị **tên người**, không phải mã máy
- [ ] Không tạo được công việc Alone Worker khi chưa điểm danh
- [ ] Phiên tự đóng sau 12 giờ

### Rủi ro

**Công nhân quên điểm danh đầu ca.** Giảm thiểu: màn hình chào bắt buộc khi mở app nếu
chưa có phiên; nhắc lại khi tạo công việc đầu tiên.

**Thẻ nhân viên bị mượn.** Đây là rủi ro quy trình, không phải kỹ thuật — cần quy định
nội bộ. Nhật ký vẫn ghi đúng thẻ nào được dùng.

---

## G6 — Giám sát tập trung

### Vì sao làm sớm

Đặt ở vị trí thứ hai không phải vì cấp bách nhất, mà vì **hai lý do thực dụng**:

1. **Bằng chứng cho kiểm định (G3).** Đơn vị kiểm định sẽ hỏi *"cho tôi xem log của
   30 ngày qua"*. Không có nhật ký tập trung thì phải đi thu thập thủ công từ 3 máy.
2. **Rẻ và không rủi ro.** Không đụng vào logic nghiệp vụ, làm song song được với việc khác.

### Hiện trạng

Nhật ký hiện là `print()` với emoji, ghi vào `data/logs/server.log`, xoay vòng ở 10MB,
**nằm cục bộ từng máy**. Đọc bằng mắt thì được, phân tích tự động thì không.

### Thiết kế đề xuất

**Bước 1 — Nhật ký có cấu trúc.** Chuyển sang JSON một dòng một sự kiện:

```json
{"ts":"2026-08-05T03:22:11Z","level":"warn","event":"enroll.rejected",
 "server_id":"server-m1","zone":"M1","client_ip":"192.168.1.99",
 "reason":"token_expired"}
```

Giữ song song bản đọc-được-bằng-mắt cho console; chỉ tệp mới ở dạng JSON.

**Bước 2 — Định nghĩa sự kiện an ninh cần theo dõi:**

| Sự kiện | Mức | Vì sao quan trọng |
|---|---|---|
| `auth.failed` | warn | Dò token, tấn công vét cạn |
| `enroll.rejected` | warn | Dò vé mời |
| `enroll.success` | info | Thiết bị mới vào hệ thống |
| `device.revoked` | info | Ai thu hồi máy nào, lúc nào |
| `admin.config_changed` | **warn** | Thay đổi cấu hình hệ thống |
| `admin.reset` | **crit** | Xoá dữ liệu |
| `ws.rejected` | info | Kết nối realtime bị từ chối |
| `peer.sync_failed` | warn | Mesh có vấn đề |
| `webhook.dead_letter` | warn | Sự kiện tích hợp bị mất |

**Bước 3 — Gom về trung tâm.** Ba lựa chọn theo bối cảnh:

| Cách | Phù hợp khi | Công sức |
|---|---|---|
| **Syslog** sang máy chủ log của công ty | Costa đã có hạ tầng syslog | Thấp |
| **Grafana Loki** tự dựng | Muốn tự chủ, có người vận hành | Vừa |
| **SIEM doanh nghiệp** | Đội bảo mật yêu cầu | Tuỳ chính sách công ty |

**Nên hỏi đội IT của Costa trước** — nhiều khả năng họ đã có sẵn nơi nhận log và chỉ cần
bạn gửi đúng định dạng. Tự dựng hệ thống thứ hai là lãng phí.

**Bước 4 — Cảnh báo tối thiểu:**

- `admin.reset` hoặc `admin.config_changed` → thông báo ngay cho quản trị
- Trên 20 `auth.failed` trong 5 phút → nghi vấn tấn công
- Một server không gửi log quá 15 phút → nghi ngờ đã chết

### Công việc

| # | Việc | Ước tính |
|---|---|---|
| 1 | Module logging có cấu trúc, thay `print()` ở các đường an ninh | 4 ngày |
| 2 | Chuẩn hoá danh mục sự kiện + mức độ | 2 ngày |
| 3 | Bộ đẩy log (syslog hoặc HTTP) có hàng đợi khi mất mạng | 4 ngày |
| 4 | Bảng theo dõi + cảnh báo | 4 ngày |
| 5 | Chính sách lưu giữ log (khuyến nghị 90 ngày) | 1 ngày |

### Nghiệm thu

- [ ] Toàn bộ 9 sự kiện an ninh xuất hiện ở hệ thống tập trung trong vòng 1 phút
- [ ] Mất mạng 10 phút → log được gửi bù, không mất
- [ ] Cảnh báo `admin.reset` đến được người trực trong 2 phút

---

## G2 — Chữ ký số trên bản ghi

### Vì sao cần

Hiện nhật ký ghi *ai đã thay đổi*, và danh tính đó **đã được server xác thực qua token** —
đủ tin cậy cho vận hành hằng ngày.

Nhưng có một lỗ hổng còn lại: **quản trị viên máy chủ có thể sửa database trực tiếp**.
Với kiểm toán an toàn lao động hoặc tranh chấp pháp lý, "hệ thống ghi vậy" chưa đủ nếu
không chứng minh được bản ghi chưa bị sửa sau khi tạo.

Chữ ký số đóng lỗ hổng này: chỉ thiết bị giữ khoá riêng mới tạo được chữ ký hợp lệ,
và khoá riêng **không bao giờ rời khỏi kho bảo mật của máy**.

### Cái gì đã có sẵn

`device_identity_service.dart` **đã sinh sẵn cặp khoá Ed25519** cho mỗi máy từ lần chạy
đầu tiên, và khoá công khai đã được gửi lên server lúc đăng ký, lưu trong
`devices.signing_public_key`.

Nghĩa là **toàn bộ hạ tầng khoá đã xong** — chỉ còn thiếu bước ký và bước kiểm.

### Thiết kế đề xuất

```
Client:  chuỗi_chuẩn_hoá(mutation) ──Ed25519 ký──► signature ──► gửi kèm
Server:  tra devices.signing_public_key ──► kiểm chữ ký ──► lưu cùng bản ghi
```

**Chỗ dễ hỏng nhất: chuẩn hoá chuỗi.** Client và server phải tạo ra **cùng một dãy byte**
từ cùng một mutation. Chỉ cần khác thứ tự khoá JSON, khác cách viết số thực, hay khác
khoảng trắng là chữ ký sai — mà lỗi này rất khó truy vì mọi thứ trông đều đúng.

Cách xử lý: dùng **chuỗi ghép tường minh** thay vì tuần tự hoá JSON:

```
id | table | operation | sha256(data_json_đã_sắp_khoá) | actor_device_id | server_received_at
```

Đơn giản, kiểm tra bằng mắt được, không phụ thuộc thư viện JSON hai bên.

**Triển khai ba giai đoạn — không bật kiểm ngay:**

| GĐ | Client | Server | Mục đích |
|---|---|---|---|
| 1 | Ký và gửi | Lưu, **chưa kiểm** | Thu thập dữ liệu thật |
| 2 | Ký và gửi | Kiểm, sai thì **ghi log** | Phát hiện lệch chuẩn hoá |
| 3 | Ký và gửi | Kiểm, sai thì **từ chối** | Thực thi |

Giai đoạn 2 là bắt buộc. Bật thẳng sang chế độ từ chối sẽ khiến toàn bộ thiết bị ngừng
đồng bộ nếu có bất kỳ khác biệt nhỏ nào trong chuẩn hoá.

### Công việc

| # | Việc | Ước tính |
|---|---|---|
| 1 | Hàm chuẩn hoá chuỗi, **viết test đối chiếu Dart ↔ Python** | 3 ngày |
| 2 | Client ký mutation trước khi đưa vào hàng đợi | 2 ngày |
| 3 | Cột `signature` + `signature_status` trong `sync_mutations` | 1 ngày |
| 4 | Server kiểm chữ ký, chế độ log-only | 3 ngày |
| 5 | Bảng theo dõi tỉ lệ chữ ký hợp lệ | 2 ngày |
| 6 | Chuyển sang chế độ từ chối + cờ cấu hình | 2 ngày |
| 7 | Công cụ kiểm tra lại toàn bộ nhật ký (dùng khi kiểm toán) | 2 ngày |

Mục 1 quan trọng nhất — bộ test đối chiếu hai ngôn ngữ là thứ ngăn dự án này thất bại.

### Nghiệm thu

- [ ] Tỉ lệ chữ ký hợp lệ đạt **>99,9%** trong 2 tuần chạy chế độ log-only
- [ ] Sửa một bản ghi trực tiếp trong database → công cụ kiểm phát hiện được
- [ ] Bật chế độ từ chối không làm gián đoạn thiết bị nào

---

## G4 — Mã hoá cơ sở dữ liệu

### Đánh giá thực tế trước khi làm

Đây là mục **dễ bị làm quá tay**. Cần phân biệt hai mối đe doạ:

| Mối đe doạ | Mã hoá DB có giúp không |
|---|---|
| Điện thoại bị mất, người khác cắm vào máy tính đọc file | ✅ Có |
| Máy chủ bị đánh cắp ổ cứng | ✅ Có |
| Kẻ tấn công có quyền quản trị trên máy đang chạy | ❌ Không — khoá nằm sẵn trong bộ nhớ |
| Kẻ tấn công qua API | ❌ Không |

Nghĩa là mã hoá DB chỉ bảo vệ **dữ liệu lúc nghỉ**, và phần lớn giá trị nằm ở thiết bị
di động — thứ dễ mất nhất.

### Thiết kế đề xuất — hai mức

**Mức 1 — Mã hoá toàn ổ đĩa (làm trước, 3 ngày)**

BitLocker trên máy chủ Windows, FileVault trên macOS, mã hoá thiết bị trên Android/iOS
(mặc định đã bật ở máy đời mới).

Rẻ, không đụng mã nguồn, và **thường đủ để đơn vị kiểm định thông qua**. Nên làm trước
rồi đánh giá xem có cần mức 2 không.

**Mức 2 — SQLCipher cho database của app (3 tuần)**

Drift hỗ trợ qua `sqlcipher_flutter_libs`. Khoá mã hoá sinh ngẫu nhiên lần chạy đầu và
lưu trong kho bảo mật hệ điều hành — cùng nơi đang giữ khoá Ed25519.

**Ba đánh đổi phải cân nhắc:**

- Chi phí hiệu năng ~5–15% cho thao tác đọc/ghi
- Sao lưu/khôi phục phức tạp hơn — bản sao lưu cũng mã hoá, mất khoá là mất dữ liệu
- Gỡ lỗi khó hơn — không mở database bằng công cụ thông thường được nữa

**Khuyến nghị:** làm mức 1 ngay. Mức 2 chỉ làm cho **database của app di động** (nơi có
dữ liệu nghiệp vụ và tin nhắn), **không làm cho server** — server nên chuyển sang
PostgreSQL với mã hoá ở tầng hạ tầng thay vì SQLCipher.

### Công việc

| # | Việc | Ước tính |
|---|---|---|
| 1 | Bật BitLocker/FileVault, ghi thành quy trình | 3 ngày |
| 2 | Tích hợp SQLCipher vào Drift | 4 ngày |
| 3 | Sinh & lưu khoá DB trong kho bảo mật | 3 ngày |
| 4 | Sửa luồng sao lưu/khôi phục cho DB đã mã hoá | 4 ngày |
| 5 | Quy trình khôi phục khi mất khoá | 2 ngày |
| 6 | Đo hiệu năng trước/sau | 2 ngày |

### Nghiệm thu

- [ ] Copy file DB sang máy khác → không mở được
- [ ] Sao lưu và khôi phục hoạt động bình thường
- [ ] Hiệu năng đồng bộ giảm không quá 15%

---

## G5 — Vòng đời chứng chỉ

### Hiện trạng

`gen_dev_certs.ps1` sinh CA nội bộ và chứng chỉ hiệu lực 825 ngày. Hoàn toàn thủ công:
không có cơ chế xoay vòng, không thu hồi được, không ai được nhắc khi sắp hết hạn.

Với 3 máy chủ thì làm tay chấp nhận được. Vấn đề là **quên**: chứng chỉ hết hạn giữa
đêm, mesh ngừng đồng bộ, và triệu chứng nhìn giống hệt lỗi mạng.

### Thiết kế đề xuất — thực dụng theo quy mô

**Không dựng ACME nội bộ cho 3 máy chủ.** Quá phức tạp so với lợi ích. Thay vào đó:

**1. Cảnh báo hết hạn** — bổ sung vào `/peer-sync/health`:

```json
{
  "tls": {
    "cert_expires_at": "2028-11-08T00:00:00Z",
    "days_remaining": 824,
    "status": "ok"          // ok | warning (<60 ngày) | critical (<14 ngày)
  }
}
```

Nối vào hệ thống giám sát của G6 → có cảnh báo tự động, không phụ thuộc trí nhớ.

**2. Quy trình xoay vòng thành văn bản** — bao gồm cả thứ tự thao tác để không đứt mesh
giữa chừng (chồng lấn chứng chỉ cũ và mới).

**3. Thu hồi** — với 3 máy chủ, cách đơn giản nhất là **sinh CA mới và cấp lại toàn bộ**.
Danh sách thu hồi CRL chỉ đáng làm khi số máy chủ vượt khoảng 10.

**4. Khi kết nối hạ tầng doanh nghiệp** — chuyển sang PKI của Costa. Lúc đó phần lớn
mục này trở nên không cần thiết, vì công ty đã có quy trình cấp phát và xoay vòng.
**Đây là lý do không nên đầu tư nhiều vào tự động hoá PKI riêng.**

### Công việc

| # | Việc | Ước tính |
|---|---|---|
| 1 | Đọc hạn chứng chỉ, đưa vào endpoint health | 2 ngày |
| 2 | Cảnh báo hết hạn nối vào G6 | 2 ngày |
| 3 | Quy trình xoay vòng có kiểm chứng từng bước | 3 ngày |
| 4 | Diễn tập xoay vòng trên môi trường thử | 2 ngày |
| 5 | Tài liệu chuyển sang PKI doanh nghiệp | 1 ngày |

### Nghiệm thu

- [ ] Cảnh báo xuất hiện khi còn 60 ngày và 14 ngày
- [ ] Diễn tập xoay vòng hoàn tất **không gián đoạn đồng bộ**
- [ ] Có tài liệu để đội IT Costa tiếp quản

---

## G3 — Kiểm định độc lập

### Vì sao đứng cuối

Kiểm định phải chạy trên mã nguồn **đã ổn định**. Thuê đánh giá code đang thay đổi từng
tuần là trả tiền cho một bản chụp lỗi thời ngay khi báo cáo được giao.

Nhưng **công tác chuẩn bị nên bắt đầu sớm** — tài liệu mô hình mối đe doạ và sơ đồ mạng
làm được ngay từ bây giờ, và bản thân việc viết chúng thường phát hiện ra vấn đề.

### Phạm vi đề xuất

| Hạng mục | Nội dung | Ưu tiên |
|---|---|---|
| **Kiểm thử xâm nhập API** | Toàn bộ endpoint từ trong LAN. Trọng tâm: `/devices/enroll`, `/admin/*`, `/peer-sync/*` | 🔴 Cao |
| **Rà soát mã đường xác thực** | `security_auth.py`, `routers/enrollment.py`, `routers/admin.py` | 🔴 Cao |
| **Rà soát cấu hình** | Cấu hình TLS, quyền tệp, biến môi trường | 🟠 Vừa |
| **Ứng dụng di động** | Lưu trữ khoá, đảo ngược mã, an toàn thẻ NFC | 🟠 Vừa |
| **Phân vùng mạng** | Tường lửa, phân tách VLAN | 🟡 Thấp |

### Chuẩn bị trước — làm ngay được

1. **Tài liệu mô hình mối đe doạ** (STRIDE hoặc tương đương) — 3 ngày
2. **Sơ đồ mạng** thể hiện phân vùng Purdue — 1 ngày
3. **Môi trường thử** giống production, có dữ liệu giả — 3 ngày
4. **Danh mục endpoint** kèm yêu cầu xác thực từng cái — 1 ngày

Mục 1 đáng làm nhất. Viết mô hình mối đe doạ thường tự phát hiện ra lỗ hổng trước cả
khi đơn vị kiểm định vào.

### Chọn đơn vị

Ưu tiên đơn vị **có kinh nghiệm hệ thống OT/ICS**, không phải chỉ web thuần. Hệ thống
này chạy tại biên nhà máy với ràng buộc rất khác web thông thường — người quen môi
trường IT sẽ đưa ra khuyến nghị không áp dụng được, ví dụ *"chuyển hết lên cloud"*.

Hỏi đội bảo mật của Costa trước: nhiều tập đoàn đã có nhà thầu kiểm định được phê duyệt,
dùng lại vừa nhanh vừa dễ được chấp nhận kết quả.

### Công việc

| # | Việc | Ước tính |
|---|---|---|
| 1 | Tài liệu mô hình mối đe doạ | 3 ngày |
| 2 | Sơ đồ mạng + danh mục endpoint | 2 ngày |
| 3 | Dựng môi trường thử | 3 ngày |
| 4 | Chọn nhà thầu, chốt phạm vi | 1 tuần |
| 5 | **Kiểm định** (bên ngoài thực hiện) | 2–3 tuần |
| 6 | Khắc phục phát hiện | 2–4 tuần |
| 7 | Kiểm tra lại | 1 tuần |

### Nghiệm thu

- [ ] Không còn phát hiện mức **Cao** hoặc **Nghiêm trọng** chưa xử lý
- [ ] Phát hiện mức Vừa có kế hoạch xử lý được chấp nhận
- [ ] Báo cáo kiểm tra lại xác nhận đã khắc phục

---

## Lộ trình tổng hợp

```
Tháng   1     2     3     4     5     6
        │     │     │     │     │     │
G1  ────█████████──┤                        Danh tính người dùng
G6  ────────█████████────┤                  Giám sát tập trung
G2  ──────────────█████████──┤              Chữ ký số
G4a ────█─┤                                 Mã hoá ổ đĩa (nhanh)
G4b ──────────────────█████████──┤          SQLCipher
G5  ────────────────────────█████─┤         Vòng đời chứng chỉ
G3p ──█████─┤                               Chuẩn bị kiểm định
G3  ────────────────────────────█████████   Kiểm định + khắc phục
```

**Ba việc làm ngay trong tuần đầu:**

1. **Mã hoá ổ đĩa** — 3 ngày, không đụng mã nguồn, giải quyết được một mục trong danh sách
2. **Tài liệu mô hình mối đe doạ** — thường tự phát hiện vấn đề trước khi thuê kiểm định
3. **Hỏi đội IT Costa** về hạ tầng log và nhà thầu kiểm định sẵn có — có thể tiết kiệm hàng tuần

---

## Nguồn lực và lưu ý

### Kỹ năng cần

| Hạng mục | Kỹ năng | Thuê ngoài được không |
|---|---|---|
| G1 | Flutter + Python, hiểu nghiệp vụ | ❌ Cần người trong đội |
| G2 | Mật mã học ứng dụng | ⚠️ Được, nhưng cần bàn giao kỹ |
| G3 | Kiểm thử xâm nhập | ✅ Nên thuê ngoài |
| G4 | Drift/SQLCipher | ✅ Được |
| G5 | PKI | ✅ Được, hoặc để đội IT Costa làm |
| G6 | Hạ tầng giám sát | ✅ Nên phối hợp với IT Costa |

### Chi phí cần dự trù

- **Kiểm định độc lập** — khoản lớn nhất, tuỳ phạm vi và nhà thầu
- **Thẻ NFC nhân viên** — vài nghìn đồng/thẻ, nhân số nhân viên
- **Hạ tầng giám sát** — bằng 0 nếu dùng lại hệ thống sẵn có của Costa

### Điều gì có thể làm hỏng kế hoạch

**Làm G3 quá sớm.** Kiểm định code đang thay đổi = trả tiền hai lần.

**Bật chế độ thực thi của G2 mà bỏ qua giai đoạn log-only.** Một khác biệt nhỏ trong
chuẩn hoá chuỗi sẽ khiến toàn bộ thiết bị ngừng đồng bộ.

**Làm SQLCipher trước khi đánh giá mã hoá ổ đĩa có đủ chưa.** Ba tuần công sức có thể
thay bằng ba ngày.

**Coi G1 là việc kỹ thuật.** Đây là thay đổi **quy trình làm việc** của công nhân.
Phần khó không nằm ở code mà ở việc khiến mọi người nhớ điểm danh đầu ca — cần trao đổi
với quản đốc từ sớm, không phải sau khi đã lập trình xong.
