# KẾ HOẠCH MODULE CLINIC – PHARMACY (BẢN CẬP NHẬT) — CHỈ THEO QĐ 808/QĐ-BYT VÀ HƯỚNG DẪN ĐƠN THUỐC QUỐC GIA

| Mục | Nội dung |
|---|---|
| Nhánh | `clinic-pharma-management` |
| Module | `lib/modules/clinic_pharma/` (Flutter/Drift) + `server/` (FastAPI) |
| Căn cứ **duy nhất** | `quyet-dinh-808.pdf` (QĐ 808/QĐ-BYT ngày 01/04/2022, 24 trang, mục III–IX: API) và `huong-dan-su-dung.pdf` (Hướng dẫn sử dụng Hệ thống thông tin quốc gia về quản lý kê đơn thuốc và bán thuốc theo đơn, 101 trang) |
| Thay thế | `01_Ke_Hoach_Module_Clinic_Pharmacy_QD130.md` — **không còn áp dụng** (QĐ 130, BHYT, XML, Cổng BHXH bị loại khỏi phạm vi). `02_...vs_QD130.md` — nội dung đặc tả API được chuyển sang file này, phần so sánh QĐ 130 bỏ |
| Quyết định (2026-10-16) | (1) **Làm cả HIS và POS nhà thuốc bán theo đơn.** (2) donthuocquocgia.vn cấp mã liên thông và môi trường test. (3) **Không kê đơn `N`/`H`/`Y`** → chỉ đơn loại `c`; bỏ đợt dùng thuốc, sổ thuốc kiểm soát, người nhận + CCCD |
| Trạng thái | Bản nháp. Đã đối chiếu với text trích từ hai PDF; những chỗ PDF mâu thuẫn hoặc không nói được ghi ở mục 9 |

---

## 1. PHẠM VI MỚI

**Làm:**
1. Vận hành phòng khám/nhà thuốc hằng ngày: tiếp đón, khám, kê đơn, cấp phát, quản lý kho thuốc — chạy offline-first như các module khác.
2. **Vai trò HIS**: kê đơn điện tử đúng chuẩn Phụ lục 4 của Hướng dẫn, và **gửi đơn lên donthuocquocgia.vn theo thời gian thực** (đơn ngoại trú) qua QĐ 808 Phụ lục II–VII.
3. Quản lý mã liên thông của cơ sở và bác sĩ (thêm/xóa bác sĩ, dừng kê đơn).
4. In đơn thuốc theo mẫu TT 04/2022 (có mã đơn); với đơn `N`/`H` có chỗ người nhận thuốc ký và ghi CCCD.
5. **Vai trò POS** (đã chốt làm, Giai đoạn E) cho nhà thuốc: lấy đơn theo mã, bán, cập nhật số lượng bán (Phụ lục VIII–IX).

**Bỏ hẳn khỏi kế hoạch cũ:** bảng Check-in và XML1–XML8, `Xml130Builder` và validator, `BhytCostCalculator`, `ClinicChargeLines` / tính mức hưởng BHYT, bộ mã DMDC (ICD-10, mã DVKT, mã nhóm chi phí…) dưới dạng bắt buộc, `MA_LK`/`MA_BN`, `clinic_xml_submissions`, Cổng tiếp nhận BHXH, chữ ký số cho gói XML, phụ lục lỗi của file ghi chú AI. Dữ liệu tiền chỉ còn ở mức **giá bán thuốc để thu tiền tại quầy**, không phân tách BV/BH/BN.

**Hệ quả:** không cần thiết kế lại `MedicalVisits` thành "đợt KCB" theo QĐ 130. Chỉ bổ sung các cột mà đơn thuốc cần (mục 4).

---

## 2. ĐẶC TẢ API — TÓM TẮT (đã đối chiếu `quyet-dinh-808.pdf`)

| # | Mục | Method | Đường dẫn | Ai gọi | Xác thực |
|---|---|---|---|---|---|
| III | Đăng nhập cơ sở | POST | `https://api.donthuocquocgia.vn/api/auth/dang-nhap-co-so-kham-chua-benh` | HIS | Body `ma_lien_thong_co_so_kham_chua_benh`, `password`. Token hiệu lực **7 ngày** |
| IV | Thêm bác sĩ vào cơ sở | POST | `/api/v1/them-bac-si` | HIS | `Authorization: bearer <token cơ sở>`; body `ma_lien_thong_bac_si` |
| V | Xóa bác sĩ khỏi cơ sở | POST | `/api/v1/xoa-bac-si` | HIS | `bearer <token cơ sở>` |
| VI | Đăng nhập bác sĩ | POST | `/api/auth/dang-nhap-bac-si` | HIS | Body: mã liên thông bác sĩ + mã liên thông cơ sở + mật khẩu. Token **7 ngày** |
| VII | Gửi đơn thuốc | POST | `/api/v1/gui-don-thuoc` | HIS | `bearer <token bác sĩ>`; 200 "Gửi đơn thuốc thành công", 422 `danh_sach_cac_loi` |
| VIII | Lấy đơn | GET | `https://www.donthuocquocgia.vn/api/v1/thong-tin-don-thuoc/{ma_don_thuoc}` | POS | Header `app-name`, `app-key`; 404 nếu không có |
| IX | Cập nhật số lượng bán | POST | `https://www.donthuocquocgia.vn/api/v1/cap-nhat-don-thuoc` | POS | `app-name`, `app-key` |

**Chuỗi gọi của HIS:** đăng nhập cơ sở → thêm bác sĩ (một lần/bác sĩ) → đăng nhập bác sĩ → gửi đơn bằng token bác sĩ. Thiếu bước thêm bác sĩ thì đăng nhập bác sĩ bị 422.

### 2.1 Các trường `gui-don-thuoc` (27 STT trong PDF)

Cột "BB" lấy đúng dấu `x` trong bảng dữ liệu đầu vào của PDF; "TT04" là yêu cầu thêm từ Phụ lục 4 của Hướng dẫn.

| STT | Trường | Kiểu / độ dài | BB | Nguồn trong iZii | Ghi chú |
|---|---|---|---|---|---|
| 1 | `loai_don_thuoc` | `c`/`h`/`n`/`y` | x | `Prescriptions.loaiDon` | c cơ bản; h hướng thần + tiền chất; n gây nghiện; y cổ truyền |
| 2 | `ma_don_thuoc` | 14 ký tự | x | `Prescriptions.maDonThuoc` | `xxxxxyyyyyyy-z`: 5 mã CSKCB + 7 `[0-9a-z]` + `-` + loại. Duy nhất trong cơ sở |
| 3 | `ho_ten_benh_nhan` | ≤ 500 | x | `Patients.fullName` | |
| 4 | `ngay_sinh_benh_nhan` | `d/m/Y` | x | `Patients.dob` | |
| 5 | `ma_dinh_danh_y_te` | ≤ 10 | không | `Patients.maDinhDanhYte` | PDF không đánh dấu bắt buộc (kế hoạch cũ ghi "Có" là sai) |
| 6 | `ma_dinh_danh_cong_dan` | 12 số | không | `Patients.soCccd` | Cho phép trống |
| 7 | `can_nang` | số | không | `Prescriptions.canNang` | TT04: **phải ghi với trẻ < 72 tháng** |
| 8 | `gioi_tinh` | số | x | `Patients.gender` (nội bộ `male/female/unknown`) | 1 chưa có thông tin, 2 Nam, 3 Nữ — ánh xạ khi gửi |
| 9 | `ma_so_bao_hiem_y_te` | ≤ 10 | không | `Patients.maTheBhyt` | Tên khóa khác nhau: bảng ghi `ma_so_bao_hiem_y_te`, ví dụ ghi `ma_so_the_bao_hiem_y_te`. TT04 cho phép thay bằng số định danh công dân |
| 10 | `thong_tin_nguoi_giam_ho` | ≤ 500 | có điều kiện | `Prescriptions.nguoiGiamHo` | Bắt buộc khi trẻ < 72 tháng: họ tên, SĐT, địa chỉ |
| 11 | `dia_chi` | ≤ 500 | x | `Patients.address` | |
| 12 | `chan_doan` | danh sách | x | `Prescriptions.chanDoan` (mới) | Phần tử: `ma_benh`/`ten_benh`/`ket_luan` (bảng) hay `ma_chan_doan`/`ten_chan_doan`/`ket_luan` (ví dụ) — xem mục 9 |
| 13 | `luu_y` | ≤ 2000 | không | `Prescriptions.notes` | |
| 14 | `hinh_thuc_dieu_tri` | số | có điều kiện (đơn `c`) | `Prescriptions.hinhThucDieuTri` | PDF chỉ nói "danh mục do Bộ Y tế ban hành", **không nêu giá trị**. Giá trị 1 nội trú / 2 ngoại trú ở bản cũ chưa kiểm chứng |
| 15 | `dot_dung_thuoc` | danh sách `{dot, tu_ngay, den_ngay, so_thang}` | có điều kiện | `Prescriptions.dotDungThuoc` (mới) | **Bắt buộc với `h`, `n` và `y`** (kế hoạch cũ chỉ ghi h, n). `so_thang` yêu cầu với thuốc cổ truyền |
| 16 | `thong_tin_don_thuoc` | danh sách | x | `PrescriptionItems` | Xem 2.2 |
| 23 | `loi_dan` | ≤ 2000 | không | `Prescriptions.loiDan` | Đơn `y`: mô tả cách sắc, cách uống |
| 24 | `so_dien_thoai_nguoi_kham_benh` | số ≤ 12 | không đánh dấu | `Patients.phone` | TT04 mục 15 coi là bắt buộc → **vẫn bắt buộc khi kê** |
| 25 | `ngay_tai_kham` | **số ngày** | không | `Prescriptions.ngayTaiKham` | |
| 26 | `ngay_gio_ke_don` | `Y-m-d H:m:s` | không đánh dấu | `Prescriptions.createdAt` | Luôn gửi. Có thể là `H:i:s` — xem mục 9 |
| 27 | `signature` | chữ ký số | không đánh dấu | — | Xem mục 9 |

(STT 17–22 là các cột của `thong_tin_don_thuoc` bên dưới. PDF đánh số theo bảng, không theo thứ tự trong JSON.)

### 2.2 Mỗi dòng `thong_tin_don_thuoc` (đều bắt buộc)

| Trường | Giới hạn | Nguồn |
|---|---|---|
| `ma_thuoc` | ≤ 20 | `ClinicDrugInfo.maThuocCucQldd` — **mã do Cục Quản lý Dược cấp** |
| `biet_duoc` | ≤ 500 | `ClinicDrugInfo.bietDuoc` (đơn `y`: tên dược liệu/vị thuốc) |
| `ten_thuoc` | ≤ 500 | `Products.name` (tên thương mại) |
| `don_vi_tinh` | ≤ 500 | đơn vị của thuốc |
| `so_luong` | số | `PrescriptionItems.quantity` |
| `cach_dung` | ≤ 500 | `PrescriptionItems.dosageInstructions` (đường dùng, liều, thời gian) |

### 2.3 Lỗi
HTTP 422 kèm `danh_sach_cac_loi`; 404 khi không thấy đơn. **Không có bảng mã lỗi.** Lưu nguyên văn danh sách lỗi để bác sĩ đọc.

---

## 3. QUY TẮC NGHIỆP VỤ (từ Hướng dẫn)

| # | Quy tắc | Nguồn |
|---|---|---|
| R1 | Mã đơn `xxxxxyyyyyyy-z`; loại `N`/`H`/`C`/`Y`; gạch ngang ở vị trí 13 | Phụ lục 4 mục 1; QĐ 808 VII |
| R2 | Ngoại trú (và đơn thêm cho nội trú ngoài BHYT) gửi **theo thời gian thực**. Nội trú: tổng hợp sau khi ra viện hoặc sau 15 ngày | Quy định 28 (1.11–1.13) |
| R3 | Đơn đã kê, đã đẩy và đã xuất cho người bệnh **không thể xóa**; thay đơn = tạo đơn mới | 1.14 |
| R4 | Cân nặng bắt buộc với trẻ < 72 tháng; kèm tên bố/mẹ/người đưa trẻ | Phụ lục 4 mục 7, 16 |
| R5 | Đơn `N`/`H`: ghi đợt dùng thuốc; người nhận xuất trình CCCD/CMND (ghi vào đơn) | Phụ lục 4 mục 13, 17 |
| R6 | Đơn có hiệu lực **5 ngày**; nhà thuốc không bán đơn hết hạn hoặc đã bán hết | 8.3 |
| R7 | Cơ sở có trách nhiệm đưa mã liên thông của người kê đơn và của cơ sở vào mỗi đơn | 5.6 |
| R8 | Bác sĩ nhiều nơi dùng cùng một mã liên thông; mỗi cơ sở thêm bác sĩ qua API | 6.7 |
| R9 | Bác sĩ tạm dừng/nghỉ/bị đình chỉ/thu hồi CCHN: dừng hoặc hủy mã tại phần mềm và cập nhật ngày kết thúc hành nghề lên hệ thống | Quy định 23 |
| R10 | Dược sĩ ĐH được thay thuốc cùng hoạt chất, đường dùng, liều khi người mua đồng ý; phải báo cáo thuốc thay thế (POS) | Quy định 26 |
| R11 | Gửi đơn điện tử cho người bệnh (email, SMS, app) để tiến tới bỏ đơn giấy | 5.10 |
| R12 | Đăng nhập theo chuỗi 4 bước, token 7 ngày | QĐ 808 III–VII |
| R13 | Mã liên thông cơ sở/bác sĩ chỉ có sau khi được Sở Y tế phê duyệt (3–5 ngày); mật khẩu chính là mật khẩu khi đăng ký trên donthuocquocgia.vn | 5.1–5.4, 6.1–6.4 |
| R14 | Một người kê đơn cần chữ ký số riêng (xem mục 9, tài liệu tự mâu thuẫn) | Quy định 24 |

---

## 4. THIẾT KẾ DỮ LIỆU (Drift + server)

Nguyên tắc: **lưu theo nghiệp vụ, xuất theo hệ thống đích.** Giới tính lưu giá trị nội bộ; ngày lưu `DateTime`; chỉ ánh xạ sang `d/m/Y`, `Y-m-d H:i:s`, `1/2/3` khi dựng payload.

### 4.1 Mở rộng bảng hiện có (cột thêm, không đổi cột cũ)

| Bảng | Thêm |
|---|---|
| `Patients` | `maDinhDanhYte`, `soCccd` (có thể trống), `maTheBhyt` (lưu đủ chuỗi người dùng nhập), `guardianName`, `guardianPhone`, `guardianAddress` |
| `Doctors` | `soCchn`, `maLienThongDtqg` (`01` + số CCHN, **bỏ dấu `/`** — Hướng dẫn FAQ 1.17), `duocKeDon` (bool), `dtqgStatus` (`pending`/`active`/`paused`/`revoked`), `ngayKetThuc` |
| `MedicalVisits` | `canNang`, `hinhThucDieuTri`, `ngayTaiKham` (số ngày) |
| `Prescriptions` | `maDonThuoc` (duy nhất), `loaiDon`, `chanDoanJson` (danh sách mã/tên/kết luận), `dotDungThuocJson`, `nguoiGiamHo`, `loiDan`, `ngayTaiKham`, `nguoiNhanThuoc` + `cccdNguoiNhan` (N/H), `dtqgStatus` (`draft` → `queued` → `sent` / `rejected`), `dtqgSentAt`, `dtqgLastError` |
| `PrescriptionItems` | `maThuocCucQldd`, `bietDuoc`, `donViTinh`, `cachDung` (tách khỏi `dosageInstructions` nếu cần), `soLuongBan` (POS) |

`chanDoanJson` và `dotDungThuocJson` là danh sách cố định nhỏ gắn vào đơn, gửi nguyên khối trong payload nên được phép dùng JSON. Dòng thuốc **vẫn lưu từng dòng** vì kho cần trừ theo lô.

### 4.2 Bảng mới (tối thiểu)

| Bảng | Mục đích |
|---|---|
| `ClinicFacility` | Tên, địa chỉ, SĐT cơ sở (in lên đơn), `maCskcb` 5 ký tự, `maLienThongDtqg` của cơ sở. **Mật khẩu liên thông không nằm ở đây** |
| `ClinicDrugInfo` (1–1 với `Products`) | `maThuocCucQldd`, `bietDuoc`, `donViTinh`, `loaiKiemSoat` (`none`/`h`/`n`), `isTraditional` |
| `ClinicDtqgSubmissions` | Mỗi lần gửi: `maDonThuoc`, lần thử, HTTP status, `danh_sach_cac_loi` nguyên văn, thời điểm, hash payload |
| `ClinicControlledDrugLog` | Sổ thuốc `N`/`H`: người nhận, CCCD, bác sĩ kê, lô, số lượng |
| `ClinicStockTransactions` | Sổ giao dịch kho chỉ-thêm (giữ từ kế hoạch cũ: nhập/xuất/trả theo lô) |
| Server: `clinic_dtqg_session` | Token cơ sở và token từng bác sĩ + hạn dùng |
| Server: `clinic_dtqg_credentials` | Mật khẩu liên thông, **mã hóa khi lưu**, không đồng bộ xuống thiết bị, không ghi log |

**Quy tắc bất biến (R3):** khi `dtqgStatus = sent`, repository từ chối sửa/xóa đơn và dòng thuốc. Nút "Thay đơn" tạo đơn mới với mã mới; đơn cũ giữ nguyên.

**Danh mục mã:** chỉ cần danh mục **thuốc Cục QLD** (mã `ma_thuoc`) và ICD-10 để chọn chẩn đoán. Nguồn danh mục chưa có trong hai PDF (mục 9) nên trước mắt cho nhập tay có kiểm tra độ dài, thay bằng import khi lấy được file.

Mỗi thay đổi schema Drift: thêm bảng vào `@DriftDatabase`, tăng `schemaVersion` (hiện 33), khối `if (from < N)` trong `onUpgrade`, chạy `build_runner`. Server: migration `0012_clinic_pharma.sql` + `TABLE_ALIASES` trong `server/projector.py`.

---

## 5. LUỒNG KỸ THUẬT (HIS)

```
Bác sĩ kê đơn (offline được)
  → kiểm tra điều kiện (mục 6) → sinh maDonThuoc (R1) → khóa nội dung
  → Prescriptions(dtqgStatus = queued) + outbox
  → server iZii: DtqgGateway
      1. đăng nhập cơ sở (token cache 7 ngày)
      2. thêm bác sĩ (bỏ qua nếu 422 đã tồn tại)
      3. đăng nhập bác sĩ (token cache 7 ngày / bác sĩ)
      4. gửi đơn → ghi ClinicDtqgSubmissions
  → 200: sent (khóa). 422: rejected + hiển thị lỗi nguyên văn. Lỗi mạng/token hết hạn: retry theo hàng đợi, đăng nhập lại
```

- **Mật khẩu liên thông chỉ ở server**; server gửi thay mặt bác sĩ. Cần sự đồng ý rõ ràng của bác sĩ/cơ sở khi giao mật khẩu cho iZii (Hướng dẫn 6.3: người kê đơn có trách nhiệm bảo quản mã và mật khẩu của chính mình).
- **Mất mạng:** vẫn kê và in được; hiển thị rõ "chưa liên thông" và gửi ngay khi có mạng. R2 yêu cầu thời gian thực nên màn Nhà thuốc cảnh báo đơn `queued` quá hạn (ngưỡng chờ xác nhận ở mục 9).
- **Trùng mã đơn:** 7 ký tự ngẫu nhiên ≈ 78 tỷ tổ hợp; vẫn kiểm tra duy nhất khi đồng bộ về server và sinh lại **trước** khi gửi.

---

## 6. ĐIỀU KIỆN CHẶN KHI KÊ ĐƠN (validation)

1. Bệnh nhân: họ tên, ngày sinh, giới tính, địa chỉ, **số điện thoại** (R-TT04).
2. Bệnh nhân < 72 tháng: bắt buộc `canNang` và thông tin người giám hộ.
3. Có ít nhất một chẩn đoán (mã + tên).
4. Mỗi dòng thuốc: `maThuocCucQldd` (≤ 20), `bietDuoc`, `tenThuoc`, `donViTinh`, `soLuong > 0`, `cachDung` (≤ 500).
5. Đơn `N`/`H`/`Y`: có ít nhất một đợt dùng thuốc; `N`/`H` thêm người nhận + CCCD khi cấp.
6. Đơn `c`: có `hinhThucDieuTri`.
7. Bác sĩ phải có `dtqgStatus = active` và `duocKeDon = true`; điều dưỡng/KTV không kê được.
8. Loại đơn tự suy từ thuốc: có thuốc `n` → đơn `n`; có `h` → `h`; thuốc cổ truyền → `y`; còn lại `c`. Trộn loại trong một đơn bị chặn, bắt tách đơn.

---

## 7. LỘ TRÌNH

### Giai đoạn A — Giao diện PC/iPad (**đã xong**)
- `ClinicWorkspaceScreen` (route `/clinic/workspace`): NavigationRail ≥ 1100px (PC), rail thu gọn 700–1100px (iPad), bottom nav dưới 700px. Tiếp đón, Bệnh nhân (master-detail), Khám bệnh (form + đơn thuốc hai khung), Nhà thuốc (hàng đợi cấp phát + tồn kho).
- Sửa `dispensePrescription` chạy trong một transaction; thêm `getPrescriptionsByStatus`.
- **Chưa kiểm thử trên thiết bị thật**; cần chạy thử Windows và iPad (cả xoay ngang/dọc).

### Giai đoạn B — Dữ liệu đơn thuốc (Sprint 1–2) — **đang làm, chỉ loại đơn `c`**

**Tiến độ (2026-10-16):** đã xong — schema Drift v34 (cột mới + `ClinicFacility`), `DtqgRules` (mã đơn, ánh xạ, validate, dựng payload), repository (sinh mã đơn duy nhất, khóa đơn `sent`, cơ sở, trạng thái liên thông), form bệnh nhân/bác sĩ/thuốc, form khám có ICD-10/cân nặng/người giám hộ/lời dặn, cài đặt cơ sở, mã đơn trên bản in, migration server `0012_clinic_pharma.sql` + `TABLE_ALIASES`; 20 test Dart đạt. **Còn lại:** mẫu in đủ 17 mục Phụ lục 4 (hiện chỉ thêm mã đơn + chẩn đoán), chạy thử UI trên Windows/iPad, chạy migration trên Postgres thật.

> Đơn giản hóa theo quyết định: không có `dot_dung_thuoc`, `ClinicControlledDrugLog`, `nguoiNhanThuoc`/`cccdNguoiNhan`. Thông tin thuốc (`maThuocCucQldd`, `bietDuoc`, `donViTinh`) lưu trong `customFields` của `Products` thay vì bảng `ClinicDrugInfo` riêng, để không đổi `supply_chain`.
- Cột mới ở 4.1, `ClinicFacility`, `ClinicDrugInfo`; sinh `maDonThuoc`; khóa đơn đã gửi; validation mục 6.
- Màn hình: form bệnh nhân bổ sung (CCCD, người giám hộ); chọn loại đơn; đợt dùng thuốc; thông tin cơ sở; khai báo mã Cục QLD cho thuốc.
- Mẫu in TT 04/2022 (Phụ lục 4) + mã đơn kèm QR — **đã xong** (địa chỉ/SĐT cơ sở, ngày sinh, số thẻ BHYT/CCCD, SĐT liên hệ, người giám hộ, tái khám; mục 13 và 17 chỉ áp dụng đơn N/H nên không in).
- **Xong khi:** kê được đơn `c`, `n`, `h`, `y` đủ trường; đơn trẻ < 72 tháng bắt buộc cân nặng và người giám hộ; đơn khóa sau khi `sent`.

### Giai đoạn C — Kho thuốc theo lô (Sprint 3)
- `StockLots` + FEFO có sẵn từ warehouse; `ClinicStockTransactions`; `ClinicControlledDrugLog` cho `N`/`H`.
- **Xong khi:** cấp phát trừ đúng lô hết hạn sớm nhất; mọi biến động có dòng giao dịch; thuốc kiểm soát bắt buộc ghi sổ.

### Giai đoạn D — `DtqgGateway` (Sprint 4–5)

**Tiến độ (2026-10-17): code xong, kiểm thử trên MOCK dựng theo PDF — chưa chạm hệ thống thật.**
- Server: `dtqg_client.py` (HTTP), `dtqg_service.py` (chuỗi đăng nhập → thêm bác sĩ → đăng nhập bác sĩ → gửi; cache token 7 ngày; 401 → đăng nhập lại một lần; chống gửi lặp), `dtqg_payload.py` (dựng + kiểm tra body), `dtqg_crypto.py` (Fernet), `routers/dtqg.py` (`/api/v1/dtqg/*`), vòng nền `_dtqg_queue_loop`, migration `0013_dtqg_gateway.sql`.
- Mock: `server/tests/mock_dtqg_server.py` — `python -m tests.mock_dtqg_server` (cổng 9099), đặt `IZIIAPP_DTQG_API_BASE` và `IZIIAPP_DTQG_WEB_BASE` về `http://127.0.0.1:9099`. Điểm PDF không nêu (mã 401 khi token hết hạn, nội dung câu lỗi) đánh dấu "GIẢ ĐỊNH" trong mock.
- Test: `python -m unittest tests.test_dtqg_gateway tests.test_dtqg_pos tests.test_dtqg_router` (57 test).
- **Còn lại:** chạy lại toàn bộ trên môi trường test thật; chốt các mâu thuẫn ở mục 9 (tên khóa, `H:i:s`, JSON vs form-data); (đã xong 2026-10-17) tab "Liên thông" trong app: lọc theo trạng thái, lỗi nguyên văn, nút Gửi ngay/Gửi lại, tự làm mới 20 giây (nguồn: `GET /api/v1/dtqg/prescriptions`).
- Server: 4 endpoint HIS, `clinic_dtqg_session`, hàng đợi gửi, retry, `ClinicDtqgSubmissions`.
- Màn hình trạng thái liên thông: đơn `queued`/`sent`/`rejected`, lỗi nguyên văn, nút gửi lại; quản lý bác sĩ (thêm/xóa, dừng kê đơn, ngày kết thúc).
- **Điều kiện tiên quyết:** tài khoản test hoặc thật của một cơ sở đã được phê duyệt + ít nhất một bác sĩ có mã liên thông. iZii không tự xin được; cần phòng khám đối tác (Hướng dẫn mục 13–16, mất 3–5 ngày duyệt).
- **Xong khi:** gửi thành công đơn `c` và `n`/`h` lên môi trường test; lỗi 422 hiển thị đúng nguyên văn; token hết hạn tự đăng nhập lại.

### Giai đoạn E — POS nhà thuốc (đã chốt làm, sau D)

**Tiến độ (2026-10-17): code xong, kiểm thử trên mock.** Server `dtqg_pos.py` (tra đơn, hiệu lực 5 ngày, cộng dồn số đã bán, bán nhiều lần, thay thuốc giữ `ma_thuoc_da_ke_don`, lưu lần bán trước khi gọi mạng, gửi lại khi lỗi mạng); app tab "Bán theo đơn" trong Nhà thuốc + `DtqgService` (Dart) + `dispenseLines` trừ kho trong transaction. Chỉ trừ kho khi server GHI NHẬN bán; hệ thống từ chối (404/422) thì không trừ. Quét QR/mã vạch mã đơn bằng camera (Android/iOS/macOS) và súng quét USB (Windows) đã xong. In biên nhận (khổ cuộn 80mm, có dòng thay thế) đã xong. **Chưa làm:** báo cáo thuốc thay thế riêng ngoài `cap-nhat-don-thuoc` (PDF không có endpoint riêng).

**Khi có mã liên thông và môi trường test:** làm theo `04_Runbook_Kiem_Thu_Moi_Truong_Test_DTQG.md`; script thử nhanh `server/scripts/dtqg_smoke.py`.
- `GET thong-tin-don-thuoc`, nhập đơn vào màn Nhà thuốc, bán từng thuốc, `cap-nhat-don-thuoc` (gồm `ma_hoa_don`, thông tin cơ sở cung ứng, thuốc thay thế).
- **Điều kiện:** `app-name`/`app-key` cấp cho đơn vị làm phần mềm qua `hotrokythuat@donthuocquocgia.vn`. Nhà thuốc bán lẻ còn phải dùng phần mềm được Cục Quản lý Dược công nhận (Hướng dẫn 8.1) — nằm ngoài hai PDF này.
- Để có tên trong danh sách nhà cung cấp: HIS ≥ 5 cơ sở đã liên thông và > 20 đơn; POS ≥ 5 đơn đã cập nhật bán (Hướng dẫn FAQ, mục đăng ký công bố nhà cung cấp; gửi hồ sơ tới `hotrokythuat@donthuocquocgia.vn`).

### Giai đoạn F — Gửi đơn điện tử cho người bệnh (R11, sau D)
- Gửi mã đơn qua SMS/email/app; tra cứu đơn bằng mã. App người dân (đặt lịch, khai báo trước) để sau.

---

## 8. KIỂM THỬ

| Loại | Nội dung |
|---|---|
| Unit (Dart) | Sinh `maDonThuoc` (độ dài 14, ký tự hợp lệ, hậu tố đúng loại); suy loại đơn; validation mục 6; ánh xạ giới tính; định dạng `d/m/Y` và `Y-m-d H:i:s`; tuổi < 72 tháng; FEFO; cấp phát trong transaction (lỗi giữa chừng không lệch tồn) |
| Unit (Python) | Dựng payload `gui-don-thuoc`; token cache và đăng nhập lại; xử lý 422/404 |
| Contract | Mock server dựng theo PDF: chuỗi 4 bước, 422 khi chưa thêm bác sĩ |
| Đồng bộ | Hai thiết bị kê đơn offline → đồng bộ → không trùng mã đơn, không gửi hai lần |
| Bất biến | Đơn `sent` không sửa/xóa được qua repository và qua API đồng bộ |
| Giao diện | Chạy workspace ở 1400, 1024, 820, 600px; xoay ngang/dọc iPad; bàn phím ảo che form khám |
| Bảo mật | Thiết bị nhân viên không đọc được mật khẩu/token liên thông; nhật ký truy cập hồ sơ |

---

## 9. CÂU HỎI CẦN CHỐT / MÂU THUẪN TRONG TÀI LIỆU

**Mâu thuẫn trong PDF (hỏi `hotrokythuat@donthuocquocgia.vn` hoặc thử trên môi trường test):**
1. Khóa chẩn đoán: bảng ghi `ma_benh`/`ten_benh`, ví dụ ghi `ma_chan_doan`/`ten_chan_doan`.
2. Khóa số thẻ BHYT: `ma_so_bao_hiem_y_te` (bảng) so với `ma_so_the_bao_hiem_y_te` (ví dụ). Độ dài 10 ký tự — thẻ BHYT thật dài 15, có cắt không?
3. `ngay_gio_ke_don` ghi `Y-m-d H:m:s` (`m` là tháng trong PHP, phút là `i`) — nhiều khả năng là `H:i:s`.
4. Header ghi `Content-Type: application/json` nhưng mục "FormData" — gửi JSON hay form-data?
5. `token_type` / `tocken_type` (trong mục III–VI) và cấu trúc phản hồi đăng nhập.
6. Chữ ký số: Hướng dẫn mục 24 nói **mỗi bác sĩ cần chữ ký số riêng**, nhưng FAQ 1.6 và 1.22 nói **chưa có kế hoạch triển khai**, Bộ Y tế sẽ ra công văn. Trường `signature` (STT 27) không đánh dấu bắt buộc → tạm để trống, giữ chỗ trong payload.
7. Giá trị của `hinh_thuc_dieu_tri` — "danh mục do Bộ Y tế ban hành" nhưng PDF không có danh mục.
8. FAQ 1.12 nói khi kéo đơn về hệ thống sẽ cấp thêm **ID (1, 2, 3…) cho từng thuốc** và "khi đẩy đơn lên thì đẩy kèm ID này", nhưng bảng gửi đơn của QĐ 808 không có trường này (chỉ có `ma_thuoc_da_ke_don` ở API POS). Nhiều khả năng chỉ liên quan đến POS; xác nhận với hỗ trợ kỹ thuật.
9. **Mã thuốc `ma_thuoc`:** FAQ 1.12 ghi "mã thuốc dùng chung cả nước, hiện tại Cục Khám chữa bệnh **chưa có quy định**". Tức chưa chắc có danh mục mã thuốc chuẩn để import — cần hỏi xem được nhập mã nội bộ hay phải theo danh mục nào.

**Việc cần quyết định:**
1. iZii chỉ làm HIS, hay làm cả POS (Giai đoạn E)?
2. Phòng khám đối tác nào cung cấp mã liên thông và môi trường test?
3. Khi mất mạng, đơn ngoại trú được gửi trễ tối đa bao lâu?
4. Nguồn danh mục mã thuốc Cục QLD và ICD-10 (hai PDF này không có).
5. Phòng khám có kê thuốc cổ truyền (`y`) và thuốc `N`/`H` không? Nếu không, bỏ qua `dot_dung_thuoc`, `so_thang` và sổ thuốc kiểm soát ở giai đoạn đầu.
6. Quy ước mã cơ sở: nếu chưa có mã BHYT, hệ thống tự sinh mã theo QĐ 384/QĐ-BYT (FAQ 1.20); tỉnh dùng hết mã số thì sinh `01aaa`, `01aab`… Khi sinh `maDonThuoc` phải lấy đúng 5 ký tự này từ cơ sở đã đăng ký, không tự đặt.

---

## 10. RỦI RO

| Rủi ro | Ảnh hưởng | Giảm thiểu |
|---|---|---|
| Chưa có tài khoản liên thông | Giai đoạn D bị chặn | Tìm phòng khám đối tác ngay; làm B–C trước, in đơn có mã nhưng trạng thái "chưa liên thông" |
| Đặc tả tự mâu thuẫn (mục 9) | Gửi bị 422 | Payload dựng qua một lớp mapping duy nhất, tên khóa nằm trong cấu hình; thử trên môi trường test trước khi chốt |
| Bắt buộc thời gian thực nhưng phòng khám mất mạng | Vi phạm R2 | Hàng đợi retry, cảnh báo đơn quá hạn, cho phép gửi từ thiết bị khác |
| Lộ mật khẩu liên thông | Giả mạo đơn | Chỉ ở server, mã hóa, không log, bác sĩ đồng ý bằng văn bản |
| Đơn sai đã gửi, không sửa được | Hồ sơ sai | Màn hình xem trước bắt buộc, "Thay đơn" tạo đơn mới |
| Dữ liệu sức khỏe là dữ liệu cá nhân nhạy cảm | Pháp lý | Phân quyền theo vai trò, nhật ký truy cập, không đưa dữ liệu bệnh nhân vào prompt AI nếu không xác nhận; rà soát Nghị định 13/2023/NĐ-CP |
| Đơn người bệnh HIV/AIDS | FAQ 1.23: thông tin định danh được mã hóa, chỉ người có thẩm quyền truy cập; PDF không nêu cách gửi | Hỏi hỗ trợ kỹ thuật trước khi hỗ trợ loại đơn này |
