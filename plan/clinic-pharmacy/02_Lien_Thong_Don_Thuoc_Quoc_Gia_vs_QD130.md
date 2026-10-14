# LIÊN THÔNG HỆ THỐNG ĐƠN THUỐC QUỐC GIA — SO SÁNH VỚI QĐ 130

| Mục | Nội dung |
|---|---|
| Nguồn | `huong-dan-su-dung.pdf` — Hướng dẫn sử dụng Hệ thống thông tin quốc gia về quản lý kê đơn thuốc và bán thuốc theo đơn (Bộ Y tế, www.donthuocquocgia.vn) |
| Liên quan | `01_Ke_Hoach_Module_Clinic_Pharmacy_QD130.md` (kế hoạch chính) |
| Kết luận nhanh | Đây là **hệ thống thứ hai, độc lập với Cổng BHXH**. Theo TT 27/2021 và TT 04/2022, **mọi** cơ sở KCB kê đơn đều phải liên thông (kể cả phòng khám tư không khám BHYT). Ưu tiên cao hơn Cổng BHXH với phòng khám không có hợp đồng BHYT. |

---

## 1. TÀI LIỆU NÀY CÓ GÌ VÀ THIẾU GÌ

**Có:** quy trình đăng ký mã liên thông cho cơ sở và bác sĩ; trách nhiệm của cơ sở KCB, nhà cung cấp HIS, nhà thuốc; quy tắc mã đơn thuốc; các trường bắt buộc trên đơn (Phụ lục 4); quy định đẩy đơn ngoại trú/nội trú; FAQ.

**Không có:** endpoint, định dạng JSON, cách xác thực API, mã lỗi. Tài liệu chỉ dẫn chiếu tới:

- **QĐ 808/QĐ-BYT ngày 01/04/2022** — Tài liệu hướng dẫn kết nối. **Phụ lục II–VII** dành cho phần mềm HIS (kê đơn), **Phụ lục VIII–IX** dành cho phần mềm nhà thuốc (POS).
- Môi trường test và tài khoản: lấy qua cơ sở KCB (mã liên thông + mật khẩu) hoặc email `hotrokythuat@donthuocquocgia.vn`.

> **Việc cần làm trước khi code:** lấy toàn văn QĐ 808/QĐ-BYT (các Phụ lục II–IX) — đó mới là đặc tả API.

---

## 2. SO SÁNH VỚI QĐ 130

| Tiêu chí | QĐ 130/QĐ-BYT (Cổng giám định BHYT) | Hệ thống Đơn thuốc quốc gia (QĐ 808/QĐ-BYT) |
|---|---|---|
| Mục đích | Giám định, thanh toán chi phí KCB BHYT | Quản lý kê đơn và bán thuốc theo đơn |
| Cơ quan nhận | BHXH Việt Nam | Bộ Y tế (Cục Quản lý KCB) |
| Đối tượng bắt buộc | Cơ sở KCB BHYT (cần xác minh với cơ sở không BHYT) | **Mọi cơ sở KCB có kê đơn**; hạn chót theo TT 04/2022: BV hạng 3 trở lên 31/12/2022, cơ sở khác 30/06/2023 |
| Phạm vi dữ liệu | Toàn bộ đợt KCB: hành chính, chẩn đoán, thuốc, DVKT, VTYT, CLS, diễn biến, **tiền** | Chỉ **đơn thuốc**: người bệnh, chẩn đoán, thuốc, liều, lời dặn. Không có giá |
| Khóa liên kết | `MA_LK` (mã đợt điều trị) | **Mã đơn thuốc** 14 ký tự |
| Thời điểm gửi | Check-in khi phát sinh chi phí đầu tiên; XML1–5 khi kết thúc đợt | **Ngoại trú: theo thời gian thực** ngay sau khi kê. Nội trú: sau 15 ngày điều trị hoặc khi ra viện |
| Sửa/xóa sau khi gửi | Có quy trình gửi lại | **Không được sửa/xóa.** Thay đơn = tạo đơn mới |
| Mã cơ sở | `MA_CSKCB` 5 ký tự | Mã liên thông cơ sở = `01` + mã CSKCB |
| Mã bác sĩ | `MA_BAC_SI` = mã định danh y tế | Mã liên thông bác sĩ = `01` + số CCHN (**bỏ dấu `/`**) |
| Xác thực | Tài khoản Cổng BHXH của cơ sở | Mã liên thông + mật khẩu **của cơ sở và của từng bác sĩ**; nhà thuốc dùng `app-key` / `app-name` |
| **Mã giới tính** | **1 Nam, 2 Nữ, 3 Chưa xác định** | **1 Chưa có thông tin, 2 Nam, 3 Nữ** |
| Hình thức điều trị | `MA_LOAI_KCB` theo danh mục DMDC | `hinh_thuc_dieu_tri`: 1 Nội trú, 2 Ngoại trú |
| Mã thuốc | `MA_THUOC` = mã hoạt chất DMDC | `ma_thuoc` = **mã do Cục Quản lý Dược cấp** (≤ 20 ký tự); `biet_duoc` = biệt dược / hoạt chất (≤ 500). Chỉ có một mã cho mỗi thuốc |
| Chữ ký số | Theo yêu cầu Cổng (cần xác minh) | **Mâu thuẫn trong tài liệu**: mục 24 nói mỗi bác sĩ cần chữ ký số; FAQ 1.6 và 1.22 nói chưa triển khai, chờ công văn |

**Hai điểm dễ gây lỗi nhất khi dùng chung dữ liệu:**

1. **Mã giới tính ngược nhau.** Phải lưu giới tính theo giá trị nội bộ (`male` / `female` / `unknown`), và mỗi bộ xuất dữ liệu tự ánh xạ sang mã của hệ thống mình. Tuyệt đối không lưu sẵn mã số của một hệ thống.
2. **Mã thuốc khác nhau.** XML2 cần mã hoạt chất theo DMDC, còn đơn thuốc quốc gia cần mã do Cục Quản lý Dược cấp (`ma_thuoc`) kèm biệt dược/hoạt chất. Hai mã có thể không trùng nhau, nên `PrescriptionItems` phải lưu cả hai và ánh xạ qua bảng `ClinicDrugInfo`.

---

## 3. CÁC QUY TẮC NGHIỆP VỤ RÚT RA

| # | Quy tắc | Nguồn trong tài liệu |
|---|---|---|
| R1 | Mã đơn thuốc dạng `xxxxxyyyyyyy-z`: 5 ký tự mã CSKCB + 7 ký tự ngẫu nhiên `[0-9a-z]` duy nhất trong cơ sở + `-` + loại đơn | Phụ lục 4, FAQ 1.11 |
| R2 | Loại đơn: `N` gây nghiện, `H` hướng thần / tiền chất, `C` thông thường, **`Y` y học cổ truyền** (bổ sung so với bản trước). Trong API dùng chữ thường `c/h/n/y`, trong mã đơn dùng `-c/-h/-n/-y` (tài liệu không thống nhất hoa/thường, cần xác nhận) | QĐ 808 Phụ lục VII.1, mục 1 và 3 |
| R3 | Đơn ngoại trú gửi ngay khi kê; nội trú gửi theo đợt 15 ngày hoặc khi ra viện | Mục 20, Quy định 28 |
| R4 | Đơn đã gửi không sửa, không xóa; muốn thay phải tạo đơn mới | FAQ 1.19, Quy định 1.14 |
| R5 | Cân nặng bắt buộc với trẻ dưới 72 tháng tuổi; kèm tên bố/mẹ hoặc người đưa trẻ đến khám | Phụ lục 4 (mục 7, 16) |
| R6 | Số điện thoại người bệnh hoặc người chịu trách nhiệm là bắt buộc (TT 04/2022) | Phụ lục 4 (mục 15), FAQ 1.18 |
| R7 | Đơn `N` / `H`: ghi đợt dùng thuốc (từ ngày – đến ngày); người nhận thuốc xuất trình CCCD; đơn `N` vẫn in ra để người nhận ký và lưu tại nơi cấp thuốc | Phụ lục 4 (mục 13, 17), FAQ 1.16 |
| R8 | Chỉ bác sĩ/y sĩ được phân công kê đơn mới có mã liên thông; điều dưỡng, KTV, bác sĩ CĐHA/xét nghiệm không có | FAQ 1.7 |
| R9 | Bác sĩ làm nhiều nơi dùng cùng một mã liên thông; mỗi cơ sở thêm bác sĩ qua **API Thêm bác sĩ vào cơ sở**, và cập nhật giờ làm việc nếu bán thời gian | Mục 6.7, mục 19 |
| R10 | Bác sĩ nghỉ việc / bị đình chỉ: cơ sở phải dừng/hủy mã liên thông trên phần mềm và cập nhật ngày kết thúc lên hệ thống | Quy định 23 |
| R11 | Đơn có hiệu lực 5 ngày; nhà thuốc không bán đơn đã bán hết hoặc hết hạn | Mục 8.3 |
| R12 | Dược sĩ đại học được thay thuốc cùng hoạt chất, đường dùng, liều lượng khi người mua đồng ý; phải báo cáo thuốc thay thế lên hệ thống | Quy định 26 |
| R13 | Thực phẩm chức năng không được kê; nếu sản phẩm hỗ trợ điều trị có trong đơn thì vẫn phải liên thông | FAQ 1.15 |
| R14 | Đơn của người bệnh HIV/AIDS: thông tin định danh được mã hóa, chỉ người có thẩm quyền xem | FAQ 1.23 |
| R15 | Đăng nhập theo chuỗi: cơ sở lấy token (7 ngày) → **thêm bác sĩ vào cơ sở** (`/api/v1/them-bac-si`) → bác sĩ đăng nhập lấy token (7 ngày) → gửi đơn bằng token bác sĩ. Thiếu bước thêm bác sĩ thì đăng nhập bác sĩ bị từ chối (422) | QĐ 808 mục III, IV, VI |
| R16 | Ngày sinh gửi theo `d/m/Y` (khác QĐ 130 là `yyyymmddHHMM`). Ngày kê đơn `Y-m-d H:m:s` | QĐ 808 mục VII, bảng dữ liệu đầu vào STT 4, 26 |
| R17 | Thuốc nghiện (`n`) và hướng thần (`h`) bắt buộc có `dot_dung_thuoc` (đợt, từ ngày, đến ngày). Ngoại trú (`hinh_thuc_dieu_tri = 2`) và nội trú (`1`) khác nhau về đợt dùng | QĐ 808 mục VII (STT 14, 15) |
| R18 | `ngay_tai_kham` là **số ngày** kể từ ngày kê đơn, không phải ngày tháng | QĐ 808 mục VII (STT 25) |
| R19 | Đơn thuốc quốc gia trả về lỗi dạng danh sách (HTTP 422) — không có bảng mã lỗi | QĐ 808 mục III–VII |

---

## 4. HAI VAI TRÒ CỦA IZII — CẦN CHỌN PHẠM VI

| Vai trò | Việc phải làm | Tài khoản | Đặc tả |
|---|---|---|---|
| **HIS (phòng khám kê đơn)** | Gửi đơn thuốc lên hệ thống; quản lý mã liên thông bác sĩ; thêm/xóa bác sĩ qua API | Mã liên thông + mật khẩu của cơ sở và từng bác sĩ (do phòng khám cung cấp) | QĐ 808, Phụ lục II–VII |
| **POS (nhà thuốc bán theo đơn)** | Tra mã đơn → đón đơn → bán → cập nhật số lượng đã bán và thuốc thay thế lên hệ thống | `app-key` / `app-name` cấp cho **đơn vị làm phần mềm** qua `hotrokythuat@donthuocquocgia.vn` | QĐ 808, Phụ lục VIII–IX |

Lưu ý thêm về POS:

- Nhà thuốc bán lẻ cần phần mềm POS liên thông **Hệ thống Dược quốc gia** của Cục Quản lý Dược (TT 03/2018/TT-BYT; QĐ 540/QĐ-QLD, QĐ 777/QĐ-QLD). Đây là **hệ thống thứ ba**, khác với Đơn thuốc quốc gia, và là điều kiện đạt GPP.
- Để có tên trong danh sách nhà cung cấp trên donthuocquocgia.vn: HIS cần ít nhất 5 cơ sở đã liên thông và trên 20 đơn; POS cần ít nhất 5 đơn đã cập nhật số lượng bán.

**Đề xuất:** làm vai trò **HIS trước** (phòng khám dùng iZii bắt buộc phải có). Vai trò POS chỉ làm khi có nhà thuốc bán lẻ cho khách ngoài, và tách thành giai đoạn riêng vì kéo theo cả Hệ thống Dược quốc gia.

---

## 5. ẢNH HƯỞNG TỚI THIẾT KẾ DỮ LIỆU

| Bảng | Thêm / sửa |
|---|---|
| `ClinicFacility` | `maLienThongDtqg` (`01` + mã CSKCB), mật khẩu liên thông (**chỉ lưu ở server, mã hóa**) |
| `Doctors` | `soCchn`, `maLienThongDtqg` (`01` + CCHN bỏ `/`), `duocPhanCongKeDon` (bool), trạng thái mã (active / paused / revoked), ngày kết thúc hành nghề tại cơ sở, mật khẩu liên thông (**chỉ server**) |
| `Patients` | `phone` bắt buộc khi kê đơn (R6); giới tính lưu giá trị nội bộ, không lưu mã số |
| `Prescriptions` | `maDonThuoc` (14 ký tự, R1), `loaiDon` (N/H/C), `hinhThucDieuTri`, `canNang`, `tenNguoiGiamHo`, `dotDungTu` / `dotDungDen` (N/H), `loiDan`, `dtqgStatus` (draft → queued → sent → rejected), thời điểm gửi, phản hồi |
| `PrescriptionItems` | `maThuocCucQldd` (`ma_thuoc`, ≤ 20 ký tự), `bietDuoc`, `donViTinh`, `cachDung`, `soLuongBan` (cho API cập nhật bán), `dtqgItemId` (số thứ tự trong đơn, nếu cần — xem Phụ lục B, chưa có trường tương ứng trong đặc tả) |
| `Prescriptions` (bổ sung) | `ngayTaiKham` (số ngày, R18), `ngayGioKeDon` (`Y-m-d H:m:s`), `dotDungThuoc` (danh sách đợt, N/H), `loiDan` (≤ 2000), `maDonThuoc` (14 ký tự) |
| Mới: `ClinicDtqgSubmissions` | Nhật ký mỗi lần gửi đơn: mã đơn, payload hash, kết quả, mã lỗi, số lần thử |

**Quy tắc bất biến (R4):** khi `dtqgStatus = sent`, repository từ chối mọi sửa/xóa đơn và các dòng thuốc. Nút "Thay đơn" tạo một đơn mới với mã mới, đơn cũ giữ nguyên.

**Bảo mật thông tin đăng nhập:** mật khẩu liên thông của cơ sở và bác sĩ là bí mật bên ngoài, giống nhóm secret của server (xem `server/.env.example`). Chỉ lưu ở server (mã hóa khi lưu), không đồng bộ xuống thiết bị nhân viên, không ghi log. Server gửi đơn thay mặt bác sĩ.

---

## 6. LUỒNG KỸ THUẬT ĐỀ XUẤT (HIS)

```
Bác sĩ kê đơn (offline được)
  → sinh maDonThuoc (R1) tại client, kiểm tra duy nhất theo cơ sở
  → lưu Prescriptions(dtqgStatus = queued) + outbox
  → đồng bộ lên server iZii
  → DtqgGateway (server):
      1. POST /api/auth/dang-nhap-co-so-kham-chua-benh → token cơ sở (7 ngày, cache)
      2. POST /api/v1/them-bac-si (một lần cho mỗi bác sĩ; 422 nếu đã tồn tại thì bỏ qua)
      3. POST /api/auth/dang-nhap-bac-si → token bác sĩ (7 ngày, cache theo bác sĩ)
      4. POST /api/v1/gui-don-thuoc (Authorization: bearer) → ghi ClinicDtqgSubmissions
  → thành công: dtqgStatus = sent (khóa đơn)
  → lỗi: rejected + mã lỗi, hiển thị cho bác sĩ; lỗi mạng: thử lại theo hàng đợi
```

**Rủi ro trùng mã đơn khi offline:** 7 ký tự ngẫu nhiên `[0-9a-z]` cho khoảng 78 tỷ tổ hợp, xác suất trùng rất thấp, nhưng vẫn phải kiểm tra duy nhất khi đồng bộ về server và sinh lại mã nếu trùng **trước khi** gửi lên hệ thống quốc gia.

**"Thời gian thực" khi offline:** đơn ngoại trú phải gửi ngay. Khi mất mạng, đơn vẫn kê và in được, nhưng phải hiện rõ trạng thái "chưa liên thông" và gửi ngay khi có mạng. Cần hỏi Bộ Y tế/Sở Y tế về độ trễ chấp nhận được.

---

## 7. CHÈN VÀO LỘ TRÌNH

Thêm **Giai đoạn 2b — Liên thông Đơn thuốc quốc gia (HIS)** ngay sau Giai đoạn 2 (thuốc & kho), trước phần BHYT:

- Sprint 4b: dữ liệu ở mục 5, sinh mã đơn, khóa đơn đã gửi, mẫu in đơn theo TT 04/2022.
- Sprint 4c: `DtqgGateway` trên server theo QĐ 808 Phụ lục II–VII, hàng đợi gửi, màn hình trạng thái liên thông, API thêm/xóa bác sĩ.
- **Xong khi:** gửi thành công đơn `C` và đơn `N`/`H` lên môi trường test; đơn đã gửi không sửa được; đơn trẻ dưới 72 tháng bắt buộc nhập cân nặng và người giám hộ.

**Điều kiện tiên quyết:** toàn văn QĐ 808/QĐ-BYT; phòng khám đối tác đã có mã liên thông cơ sở và ít nhất một bác sĩ có mã liên thông.

---

## 8. CÂU HỎI CẦN CHỐT

1. **Đã có** `quyet-dinh-808.pdf` (27 trang, mục III–IX: API đăng nhập, thêm/xóa bác sĩ, gửi đơn, lấy đơn, cập nhật bán). **Còn thiếu:** mục I–II (phạm vi, định nghĩa, cấu trúc phần mềm) và các Phụ lục danh mục (mã ICD-10, mã thuốc Cục QLD, mã đường dùng, mã hình thức điều trị) nếu có trong toàn văn. Có văn bản nào sửa đổi không?
10. **Mã bảo hiểm y tế:** QĐ 808 ghi `ma_so_the_bao_hiem_y_te` **10 ký tự**, QĐ 130 ghi `MA_THE_BHYT` **15 ký tự**. Cần xác nhận khi gửi đơn có cắt về 10 hay không; hiện lưu đủ 15.
11. **Môi trường:** API đăng nhập/gửi đơn dùng `https://api.donthuocquocgia.vn`, còn lấy đơn và cập nhật bán dùng `www.donthuocquocgia.vn`. Xác nhận địa chỉ môi trường test và thật.
12. **Tài liệu tự mâu thuẫn:** (a) mã `chan_doan` ghi `ma_benh/ten_benh` trong bảng nhưng `ma_chan_doan/ten_chan_doan` trong ví dụ; (b) `ngay_gio_ke_don` ghi `H:m:s`, có thể là `H:i:s`; (c) `token_type` và `tocken_type`; (d) gửi dạng FormData nhưng header JSON. Cần hỏi kỹ thuật hỗ trợ.
13. **Mã đơn ID thứ tự của thuốc:** FAQ 1.12 nói phải đẩy kèm ID (1, 2, 3…) cho từng thuốc, nhưng đặc tả gửi đơn không có trường này. Cần xác nhận.
2. iZii chỉ làm HIS, hay làm cả POS cho nhà thuốc bán lẻ?
3. Chữ ký số trên đơn đã bắt buộc chưa (tài liệu tự mâu thuẫn)?
4. Phòng khám đối tác nào cung cấp mã liên thông và môi trường test?
5. Khi mất mạng, đơn ngoại trú được phép gửi trễ tối đa bao lâu?


---

## PHỤ LỤC B — ĐẶC TẢ API THEO QĐ 808/QĐ-BYT (`quyet-dinh-808.pdf`, mục III–IX)

> Nguồn: `plan/clinic-pharmacy/quyet-dinh-808.pdf` (27 trang). File **không có mục I–II** và **không có các Phụ lục danh mục**. Đây là đặc tả trên giấy, chưa kiểm thử trên môi trường thật.

### B.1 Bảng endpoint

| # | Mục | Method | Đường dẫn | Ai gọi | Xác thực | Ghi chú |
|---|---|---|---|---|---|---|
| III | Đăng nhập cơ sở KCB | POST | `https://api.donthuocquocgia.vn/api/auth/dang-nhap-co-so-kham-chua-benh` | HIS | Không (body: mã liên thông cơ sở + mật khẩu) | Trả `token`, `token_type: "bearer"`; hiệu lực **7 ngày** |
| IV | Thêm bác sĩ vào cơ sở | POST | `/api/v1/them-bac-si` | HIS | `Authorization: bearer <token cơ sở>` | Body: `ma_lien_thong_bac_si`. 200 "Bạn đã thêm bác sĩ thành công"; 422 danh sách lỗi (đã tồn tại, lỗi khác) |
| V | Xóa bác sĩ khỏi cơ sở | POST | `/api/v1/xoa-bac-si` | HIS | `bearer <token cơ sở>` | Body: `ma_lien_thong_bac_si`. Tài liệu ghi method POST |
| VI | Đăng nhập bác sĩ | POST | `/api/auth/dang-nhap-bac-si` | HIS | Không (body: mã liên thông bác sĩ + mã liên thông cơ sở + mật khẩu) | Trả `token`, hiệu lực **7 ngày**. 422 khi bác sĩ chưa được thêm vào cơ sở hoặc sai mã/mật khẩu |
| VII | Gửi đơn thuốc | POST | `/api/v1/gui-don-thuoc` | HIS | `bearer <token bác sĩ>` | 27 trường, xem B.3. 200 "Gửi đơn thuốc thành công"; 422 danh sách lỗi |
| VIII | Lấy đơn thuốc | GET | `https://www.donthuocquocgia.vn/api/v1/thong-tin-don-thuoc/{ma_don_thuoc}` | Nhà thuốc (POS) | Header `app-name`, `app-key` | 200 trả thông tin đơn; 404 không tìm thấy |
| IX | Cập nhật số lượng bán | POST | `https://www.donthuocquocgia.vn/api/v1/cap-nhat-don-thuoc` | Nhà thuốc (POS) | Header `app-name`, `app-key` | 200 "Cập nhật đơn thuốc đã bán thành công"; 404; 422 |

**Chuỗi gọi của HIS:** đăng nhập cơ sở → thêm bác sĩ (một lần cho mỗi bác sĩ) → đăng nhập bác sĩ → gửi đơn. Token cơ sở chỉ dùng để thêm/xóa bác sĩ; **token bác sĩ** mới dùng để gửi đơn.

### B.2 Xác thực và quản lý phiên

| Loại | Dùng cho | Cấp bởi | Lưu ở đâu (đề xuất) |
|---|---|---|---|
| Mã liên thông + mật khẩu của **cơ sở** | Đăng nhập HIS (lấy token cơ sở) | Hệ thống đơn thuốc quốc gia (sau phê duyệt) | Server, mã hóa |
| Mã liên thông + mật khẩu của **bác sĩ** | Đăng nhập bác sĩ (lấy token bác sĩ) | Như trên | Server, mã hóa, **không** xuống thiết bị |
| Token cơ sở / token bác sĩ | Gọi API | Hệ thống | Cache trên server, hết hạn sau 7 ngày → đăng nhập lại |
| `app-name` / `app-key` | Nhà thuốc POS | Đơn vị hỗ trợ vận hành (hotrokythuat@donthuocquocgia.vn) | Server, bí mật theo từng đơn vị phần mềm |

**Bổ sung vào thiết kế:** cần bảng `ClinicDtqgSession` (đối tượng, loại token, token, thời điểm hết hạn) và logic tự đăng nhập lại khi gặp lỗi do token hết hạn. Mật khẩu của **mọi bác sĩ** phải do cơ sở tự nhập vào hệ thống; iZii không nên giữ thay trừ khi có sự đồng ý rõ ràng.

### B.3 Các trường của `gui-don-thuoc` và ánh xạ sang iZii

| STT | Trường (API) | Kiểu / độ dài | Bắt buộc | Nguồn trong iZii | Ghi chú / xung đột |
|---|---|---|---|---|---|
| 1 | `loai_don_thuoc` | 1 ký tự: `c`, `h`, `n`, `y` | Có | `Prescriptions.loaiDon` | Thêm `y` (y học cổ truyền) |
| 2 | `ma_don_thuoc` | 14 ký tự | Có | `Prescriptions.maDonThuoc` | 5 ký tự mã CSKCB + 7 ký tự `[0-9a-z]` + `-` + 1 ký tự loại. Duy nhất |
| 3 | `ho_ten_benh_nhan` | chuỗi ≤ 500 | Có | `Patients.fullName` | |
| 4 | `ngay_sinh_benh_nhan` | **`d/m/Y`** | Có | `Patients.dob` | **Khác QĐ 130** (`yyyymmddHHMM`). Chuyển khi xuất |
| 5 | `ma_dinh_danh_y_te` | chuỗi ≤ 10 | Có | `Patients.maDinhDanhYte` | Cần có trong hồ sơ bệnh nhân |
| 6 | `ma_dinh_danh_cong_dan` | 12 chữ số | Không ghi rõ (không có dấu bắt buộc) | `Patients.soCccd` | Phù hợp với kế hoạch 01 cho phép trống; cần xác nhận khi thiếu thì gửi đơn có được không (xem ghi chú bên dưới) |
| 7 | `can_nang` | số | Không ghi rõ | Đợt KCB `canNang` | Phụ lục 4 của hướng dẫn yêu cầu với trẻ dưới 72 tháng |
| 8 | `gioi_tinh` | `1` chưa rõ, `2` Nam, `3` Nữ | Có | `Patients.gender` | Ánh xạ từ giá trị nội bộ (nguyên tắc 4b) |
| 9 | `ma_so_the_bao_hiem_y_te` | chuỗi ≤ 10 | Không | `Patients.maTheBhyt` | **Xung đột:** QĐ 130 là 15 ký tự (câu hỏi 10) |
| 10 | `thong_tin_nguoi_giam_ho` | chuỗi ≤ 500 | Bắt buộc khi trẻ dưới 72 tháng | Cần trường mới | Họ tên, số điện thoại, địa chỉ người giám hộ |
| 11 | `dia_chi` | chuỗi ≤ 500 | Có | `Patients.address` | |
| 12 | `chan_doan` | danh sách `{ma_benh, ten_benh, ket_luan}` | Có | `MedicalVisits` + ICD-10 | Tên khóa không thống nhất trong tài liệu (câu hỏi 12) |
| 13 | `luu_y` | chuỗi ≤ 2000 | Không | Ghi chú bác sĩ | |
| 14 | `hinh_thuc_dieu_tri` | số: `1` nội trú, `2` ngoại trú | Bắt buộc với đơn `c` | `MedicalVisits` | |
| 15 | `dot_dung_thuoc` | danh sách `{dot, tu_ngay, den_ngay}`, ngày `d/m/Y`; số thang với YHCT | Bắt buộc với đơn `h`, `n` | Cần trường mới | R17 |
| 16 | `thong_tin_don_thuoc` | danh sách (xem B.4) | Có | `PrescriptionItems` | |
| 17 | `loi_dan` | chuỗi ≤ 2000 | Không | Lời dặn của bác sĩ | Đơn YHCT cần mô tả cách sắc, cách uống |
| 18 | `so_dien_thoai_nguoi_kham_benh` | chuỗi số ≤ 12 | Có | `Patients.phone` | R6 |
| 19 | `ngay_tai_kham` | **số ngày** | Không | `Prescriptions.ngayTaiKham` | R18 |
| 20 | `ngay_gio_ke_don` | `Y-m-d H:m:s` | Có | `Prescriptions.createdAt` | Tài liệu ghi `H:m:s` — có thể là `H:i:s`; khác QĐ 130 |
| 21 | `signature` | chữ ký số của người kê đơn | Chưa rõ | Chưa có | FAQ 1.6 và 1.22: chưa triển khai |

**Ghi chú dòng 6:** `ma_dinh_danh_cong_dan` là mã định danh công dân 12 số, không được đánh dấu bắt buộc trong bảng QĐ 808. Điều này khớp với kế hoạch 01 (`Patients.soCccd` được phép trống). Tuy nhiên tài liệu không nói rõ khi thiếu mã thì đơn có được gửi hay không; cần hỏi kỹ thuật hỗ trợ trước khi code.

### B.4 Phần tử `thong_tin_don_thuoc` (mỗi dòng thuốc)

| Trường | Kiểu / độ dài | Bắt buộc | Nguồn trong iZii | Ghi chú |
|---|---|---|---|---|
| `ma_thuoc` | chuỗi ≤ 20 | Có | `PrescriptionItems.maThuocCucQldd` | Mã do Cục Quản lý Dược cấp — **không phải** mã hoạt chất DMDC |
| `biet_duoc` | chuỗi ≤ 500 | Có | `PrescriptionItems.bietDuoc` | Biệt dược / hoạt chất chính. YHCT: tên dược liệu, vị thuốc |
| `ten_thuoc` | chuỗi ≤ 500 | Có | `Products.name` | Tên thương mại |
| `don_vi_tinh` | chuỗi ≤ 500 | Có | `Products.unit` | |
| `so_luong` | số | Có | `PrescriptionItems.quantity` | |
| `cach_dung` | chuỗi ≤ 500 | Có | `PrescriptionItems.dosageInstructions` | Đường dùng, liều, thời gian dùng |

**Khoảng trống:** FAQ 1.12 yêu cầu đẩy kèm ID thứ tự của thuốc (1, 2, 3…), nhưng bảng trên không có trường này (câu hỏi 13).

### B.5 Dữ liệu trả về khi lấy đơn và cập nhật bán (POS)

- **`GET thong-tin-don-thuoc/{ma}`** trả các trường: `ma_don_thuoc`, `ho_ten_benh_nhan`, `ngay_sinh_benh_nhan`, `ma_dinh_danh_y_te`, `loai_don_thuoc`, `hinh_thuc_dieu_tri`, `dia_chi`, `gioi_tinh`, `can_nang`, `ma_so_the_bao_hiem_y_te`, `thong_tin_don_thuoc`, `dot_dung_thuoc`, `chan_doan`, `luu_y`, `loi_dan`, `ten_bac_si`, `ten_co_so_kham_chua_benh`, `so_dien_thoai_co_so_kham_chua_benh`, `ngay_gio_ke_don`.
- **`POST cap-nhat-don-thuoc`** gửi: `ma_don_thuoc`; mảng `thong_tin_thuoc` gồm `ma_thuoc_da_ke_don`, `ma_thuoc`, `biet_duoc`, `ten_thuoc`, `don_vi_tinh`, `so_luong`, `so_luong_ban`, `cach_dung`; kèm thông tin cơ sở cung ứng: `ma_dinh_danh_co_so_cung_ung_thuoc`, `ten_co_so_cung_ung_thuoc`, `so_dien_thoai_co_so_cung_ung_thuoc`, `dia_chi_co_so_cung_ung_thuoc`, `ma_hoa_don`.
- **Thay thuốc (R12):** khi bán thuốc thay thế, gửi `ma_thuoc` và tên của thuốc thay thế; `ma_thuoc_da_ke_don` giữ mã thuốc gốc trong đơn.

### B.6 Lỗi và mã trạng thái

- Lỗi nghiệp vụ trả **HTTP 422** kèm `danh_sach_cac_loi` (danh sách chuỗi). Tài liệu không có bảng mã lỗi.
- Không tìm thấy đơn: **HTTP 404**.
- Lưu nguyên văn danh sách lỗi vào `ClinicDtqgSubmissions` để bác sĩ đọc được; không rút gọn hay dịch.

### B.7 Ảnh hưởng đến kế hoạch 01 và lộ trình

| Điều chỉnh | Lý do |
|---|---|
| `loaiDon` thêm giá trị `y` | Mục VII, trường 1 |
| `maThuocCucQldd` thay cho "mã hoạt chất DMDC" khi gửi đơn | Mục VII, STT 16–17 |
| Thêm `ClinicDtqgSession` | Token 7 ngày, đăng nhập theo cơ sở và từng bác sĩ |
| Thêm bước "thêm bác sĩ vào cơ sở" vào luồng | Mục IV và FAQ 1.8 |
| Định dạng ngày theo nơi gửi: `d/m/Y` cho Đơn thuốc quốc gia, `yyyymmddHHMM` cho Cổng BHXH | Mục VII STT 4 |
| Thêm `dot_dung_thuoc`, `thong_tin_nguoi_giam_ho`, `ngay_tai_kham` (số ngày) | Mục VII STT 10, 15, 25 |
| Sprint 4c: làm và kiểm thử `DtqgGateway` trên môi trường test | Đã có đặc tả 4 endpoint của HIS và 2 endpoint của POS |

**Điều kiện để bắt đầu code:** (1) tài khoản thử nghiệm của cơ sở và bác sĩ từ phòng khám đối tác; (2) xác nhận các mâu thuẫn ở câu hỏi 10–13; (3) lấy mục I–II và danh mục mã nếu có.
