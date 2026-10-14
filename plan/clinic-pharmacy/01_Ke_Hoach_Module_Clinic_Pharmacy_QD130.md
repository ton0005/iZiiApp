# KẾ HOẠCH PHÁT TRIỂN MODULE CLINIC – PHARMACY THEO QĐ 130/QĐ-BYT

| Mục | Nội dung |
|---|---|
| Nhánh | `clinic-pharma-management` |
| Module | `lib/modules/clinic_pharma/` (Flutter/Drift) + `server/` (FastAPI) |
| Căn cứ | Quyết định 130/QĐ-BYT ngày 18/01/2023 — chuẩn và định dạng dữ liệu đầu ra phục vụ quản lý, giám định, thanh toán chi phí KCB BHYT (file gốc: `plan/clinic-pharmacy/1054324175-QUYẾT-ĐỊNH-130.docx`) |
| Tham khảo kỹ thuật | Danphe EMR (MIT) — mô hình kho thuốc theo lô, sổ giao dịch kho, sổ thuốc kiểm soát đặc biệt |
| Đơn thuốc quốc gia | `02_Lien_Thong_Don_Thuoc_Quoc_Gia_vs_QD130.md` — liên thông donthuocquocgia.vn (QĐ 808/QĐ-BYT), **bắt buộc với mọi cơ sở kê đơn**, so sánh với QĐ 130 |
| Ghi chú nghiên cứu | `notes_hoi_dap_AI_chua_kiem_chung.md` — định hướng kết nối Cổng/VNeID; **có nhiều lỗi kỹ thuật**, xem Phụ lục A |
| Trạng thái | Bản nháp kế hoạch — cần chốt các câu hỏi ở mục 9 trước khi bắt đầu Sprint 1 |

---

## 1. MỤC TIÊU

1. Phòng khám/nhà thuốc dùng iZiiApp để vận hành hằng ngày: tiếp đón, khám, chỉ định, kê đơn, cấp phát, thu tiền — chạy được khi mất mạng (offline-first như các module khác).
2. Dữ liệu được ghi nhận **đúng cấu trúc QĐ 130 ngay từ lúc nhập**, để cuối đợt khám xuất được bộ XML (Bảng check-in, XML1–XML5, và XML7/XML8 khi cần) mà không phải nhập lại.
3. Kho thuốc quản lý theo **lô + hạn dùng**, xuất theo **FEFO**, có sổ giao dịch kho bất biến và sổ thuốc kiểm soát đặc biệt.

**Ngoài phạm vi giai đoạn này:** XML6 (HIV/AIDS), XML9–XML12 (giấy chứng sinh, nghỉ dưỡng thai, nghỉ việc hưởng BHXH, giám định y khoa), điều trị nội trú đầy đủ (giường, buồng), **app cho người dân** (đặt lịch, khai báo trước — xem Giai đoạn 7). Thiết kế dữ liệu vẫn chừa chỗ để bổ sung sau.

---

## 2. TÓM TẮT QĐ 130 — PHẦN ÁP DỤNG CHO PHÒNG KHÁM

| Bảng | Nội dung | Số chỉ tiêu | Áp dụng | Khi nào gửi |
|---|---|---|---|---|
| Check-in | Trạng thái KCB | 18 | **Bắt buộc** | Ngay sau khi phát sinh chi phí KCB đầu tiên |
| XML1 | Tổng hợp đợt KCB | ~65 | **Bắt buộc** | Khi kết thúc đợt khám/điều trị |
| XML2 | Chi tiết thuốc | ~38 | **Bắt buộc** nếu có thuốc | Cùng XML1 |
| XML3 | Chi tiết DVKT & VTYT (gồm tiền khám) | ~45 | **Bắt buộc** (tiền khám luôn có) | Cùng XML1 |
| XML4 | Kết quả cận lâm sàng | 12 | Khi có xét nghiệm/CĐHA | Cùng XML1 |
| XML5 | Diễn biến lâm sàng | 9 | Khi có ghi diễn biến | Cùng XML1 |
| XML7 | Giấy ra viện | ~25 | Khi cấp giấy ra viện | Theo đợt |
| XML8 | Tóm tắt hồ sơ bệnh án | ~22 | Khi cấp tóm tắt HSBA | Theo đợt |

**Quy tắc chung rút ra từ văn bản:**

- `MA_LK` là khóa chính của một **đợt KCB**, nối mọi bảng XML với nhau. Mỗi lượt khám ngoại trú là một đợt.
- `STT` tăng từ 1 trong **mỗi lần gửi**, không phải ID lưu trữ.
- Định dạng thời gian: `yyyymmddHHMM` (12 ký tự) cho thời điểm; `yyyymmdd` (8 ký tự) cho ngày.
- Tiền là số; công thức bắt buộc, ví dụ `THANH_TIEN_BV = SO_LUONG * DON_GIA`, `THANH_TIEN_BH = SO_LUONG * DON_GIA * TYLE_TT_BH/100`.
- Tổng ở XML1 phải khớp tổng chi tiết: `T_TONGCHI_BV = Σ THANH_TIEN_BV (XML2 + XML3)`, tương tự cho `T_TONGCHI_BH`, `T_BNTT`, `T_BNCCT`, `T_BHTT`, `T_NGUONKHAC`.
- Hầu hết mã lấy từ **Bộ mã danh mục dùng chung (DMDC)** của Bộ Y tế: ICD-10, mã hoạt chất thuốc, mã DVKT, mã đường dùng, mã nhóm chi phí, mã đối tượng KCB, mã loại KCB, mã khoa…
- Mã bác sĩ (`MA_BAC_SI`, `MA_BS_DOC_KQ`, `NGUOI_THUC_HIEN`) là **mã định danh y tế** của nhân viên y tế.

> **Cần xác minh trước khi code (không có trong file QĐ 130 đính kèm):**
> - QĐ 130 đã được sửa đổi, bổ sung (theo hiểu biết của tôi là **QĐ 4750/QĐ-BYT ngày 29/12/2023**). Cần lấy bản hợp nhất mới nhất để có danh sách trường chính xác.
> - Cấu trúc **gói XML gửi lên Cổng** (thẻ bao `GIAMDINHHS`, mã hóa base64 từng file, chữ ký số) nằm trong hướng dẫn kỹ thuật của BHXH Việt Nam, không nằm trong QĐ 130. Cần tài liệu đặc tả API/Cổng tiếp nhận chính thức.
> - Bộ mã DMDC hiện hành (phiên bản, nguồn tải).
> - **Địa giới hành chính:** theo hiểu biết của tôi, từ 01/07/2025 Việt Nam bỏ cấp huyện và sắp xếp lại cấp tỉnh. QĐ 130 (bản 01/2023) vẫn có `MATINH_CU_TRU` / `MAHUYEN_CU_TRU` / `MAXA_CU_TRU`. Cần văn bản hướng dẫn mới nhất về cách ghi các trường này (để trống mã huyện? dùng danh mục tỉnh/xã mới?) trước khi thiết kế danh mục hành chính.
> - Quy định phòng khám **không khám BHYT** có phải gửi dữ liệu lên Cổng (để liên thông Sổ sức khỏe điện tử trên VNeID) hay không.

---

## 3. HIỆN TRẠNG MODULE `clinic_pharma`

| Thành phần | Có sẵn | Thiếu so với QĐ 130 |
|---|---|---|
| `Patients` | họ tên, ngày sinh, giới tính, SĐT, địa chỉ, `idNumber` (gộp CCCD/BHYT) | `MA_BN`; CCCD và thẻ BHYT tách riêng; `MA_DKBD`, `GT_THE_TU/DEN`, `NGAY_MIEN_CCT`; mã quốc tịch, dân tộc, nghề nghiệp; mã tỉnh/huyện/xã; `MA_KHUVUC`; mã định danh y tế |
| `Doctors` | tên, chuyên khoa, liên lạc | mã định danh y tế, số chứng chỉ hành nghề, mã khoa |
| `Appointments` | lịch hẹn, trạng thái | (không thuộc XML, giữ nguyên) |
| `MedicalVisits` | ngày khám, lý do, chẩn đoán text, ghi chú | `MA_LK`; `NGAY_VAO/NGAY_RA`; mã ICD-10 bệnh chính/kèm theo; `MA_LOAI_KCB`, `MA_DOITUONG_KCB`, `KET_QUA_DTRI`, `MA_LOAI_RV`; `MA_KHOA`; cân nặng; ngày tái khám; nơi chuyển đi/đến |
| `Prescriptions` / `PrescriptionItems` | thuốc, số lượng, đơn giá, `dosageInstructions` text | `LIEU_DUNG`, `CACH_DUNG` tách riêng; `NGAY_YL`; mã thuốc DMDC; đường dùng; phạm vi/tỷ lệ BHYT; phân tách tiền BV/BH/BN |
| Thuốc (dùng `Products` của supply_chain) | tên, giá, tồn | mã hoạt chất, hàm lượng, dạng bào chế, số đăng ký, thông tin thầu, mã nhóm, đơn vị tính nhỏ nhất, lô/hạn dùng |
| Dịch vụ kỹ thuật, VTYT, tiền khám | **Chưa có** | Toàn bộ XML3 |
| Cận lâm sàng | **Chưa có** | Toàn bộ XML4 |
| Diễn biến lâm sàng | **Chưa có** | Toàn bộ XML5 |
| Thu tiền / BHYT | **Chưa có** | Tính mức hưởng, cùng chi trả, các tổng của XML1 |
| Xuất XML | **Chưa có** | Toàn bộ |
| Server | Không có alias/migration cho bảng clinic | `TABLE_ALIASES` trong `server/projector.py`, migration `0012_*` |

**Lỗi đang tồn tại cần sửa trước:** `dispensePrescription` ([repository.dart](../../lib/modules/clinic_pharma/repository.dart)) cập nhật tồn kho từng dòng mà không bọc trong `transaction()`. Nếu lỗi giữa chừng thì có thuốc đã trừ, có thuốc chưa, và trạng thái đơn không khớp tồn kho.

---

## 4. KIẾN TRÚC ĐỀ XUẤT

```
┌──────────────────── Flutter (offline-first) ────────────────────┐
│ Tiếp đón → Đợt KCB (MA_LK) → Khám/Chẩn đoán ICD-10              │
│   → Chỉ định DVKT/CLS → Kết quả CLS → Kê đơn → Cấp phát (FEFO)  │
│   → Tính tiền (BV/BH/BN) → Kết thúc đợt                         │
│                                                                  │
│ Danh mục DMDC (ICD-10, thuốc, DVKT, đường dùng, mã nhóm…)        │
│ Kho thuốc theo lô + sổ giao dịch kho + sổ thuốc kiểm soát        │
└───────────────┬──────────────────────────────────────────────────┘
                │ outbox sync (như các module khác)
┌───────────────▼──────────────────── Server (FastAPI) ────────────┐
│ projector → bảng quan hệ clinic_*                                 │
│ Xml130Builder: check-in, XML1–5 (7, 8) → validate → đóng gói      │
│ Nhật ký gửi (lần gửi, STT, kết quả, gửi lại)                       │
│ (Giai đoạn sau) Gateway tới Cổng tiếp nhận BHXH                   │
└──────────────────────────────────────────────────────────────────┘
```

**Nguyên tắc thiết kế:**

1. **Lưu theo nghiệp vụ, không lưu theo XML.** Bảng Drift mô tả nghiệp vụ (đợt khám, chỉ định, đơn thuốc). XML được **sinh ra** từ dữ liệu đó. Riêng các trường mà XML cần, phải có cột tương ứng.
2. **Tiền tính một chỗ.** Một `BhytCostCalculator` thuần (không phụ thuộc UI/DB) tính mọi trường tiền cho từng dòng chi phí, có unit test đối chiếu công thức QĐ 130.
3. **Chụp giá tại thời điểm y lệnh.** Mỗi dòng chi phí lưu đơn giá, tỷ lệ, mức hưởng tại thời điểm ra y lệnh. Đổi bảng giá sau đó không làm sai đợt cũ.
4. **Sinh XML ở server, có bản dự phòng ở client.** Server là nơi đóng gói và gửi. Client có thể xuất file XML để tải lên Cổng thủ công khi chưa có kết nối API.
4b. **Lưu giá trị nội bộ, ánh xạ khi xuất.** Hai hệ thống dùng mã khác nhau cho cùng một ý nghĩa (ví dụ giới tính: QĐ 130 là 1 Nam/2 Nữ/3 Chưa xác định, Đơn thuốc quốc gia là 1 Chưa có thông tin/2 Nam/3 Nữ). DB lưu giá trị nội bộ; mỗi bộ xuất (XML 130, Đơn thuốc quốc gia) tự ánh xạ.
5. **Trường mã chỉ chọn từ danh mục.** ICD-10, mã thuốc, mã DVKT, đường dùng, hành chính… chỉ cho chọn (autocomplete) từ `ClinicCodeSets`, không cho gõ tự do.
6. **Lưu dạng dòng, không lưu JSON.** Đơn thuốc và chi phí lưu thành từng dòng (`PrescriptionItems`, `ClinicChargeLines`), không gộp vào một cột JSON — XML2/XML3 cần giá, tỷ lệ, tiền theo từng dòng và kho cần trừ theo lô.
7. **Gửi Cổng qua hàng đợi có retry.** Dùng lại cơ chế outbox sẵn có; mỗi lần gửi được ghi nhật ký riêng (`clinic_xml_submissions`), không chỉ một cờ trạng thái.
8. **Dữ liệu sức khỏe là dữ liệu cá nhân nhạy cảm.** Phân quyền theo vai trò, ghi nhật ký truy cập, không đưa dữ liệu bệnh nhân vào prompt AI agent nếu không có xác nhận (`requiresConfirmation`). Cần rà soát theo quy định bảo vệ dữ liệu cá nhân hiện hành (Nghị định 13/2023/NĐ-CP và văn bản thay thế nếu có).

---

## 5. THIẾT KẾ DỮ LIỆU (DRIFT + SERVER)

### 5.1 Danh mục dùng chung (mới)

| Bảng | Cột chính | Dùng cho |
|---|---|---|
| `ClinicCodeSets` | `setName` (icd10, route, cost_group, patient_type, kcb_type, treatment_result, discharge_type, ethnicity, nationality, occupation, admin_unit…), `code`, `name`, `validFrom`, `validTo`, `version` | Mọi trường mã trong XML |
| `ClinicFacility` | `maCskcb`, tên, địa chỉ, cấu hình kết nối Cổng | `MA_CSKCB` |
| `ClinicDepartments` | `maKhoa`, tên | `MA_KHOA` |
| `ClinicServices` | `maDichVu` (DMDC), tên, đơn vị tính, `donGiaBv`, `donGiaBh`, `maNhom`, `phamVi`, `tyleTtBh`, loại (khám, xét nghiệm, CĐHA, thủ thuật, VTYT) | XML3, check-in |
| `ClinicLabIndicators` | `maDichVu`, `maChiSo`, tên, đơn vị đo, khoảng tham chiếu | XML4 |

Danh mục được **nạp từ file DMDC** (Excel/CSV) bằng màn hình import, lưu `version`. Không nhập tay mã ICD-10 hay mã thuốc.

### 5.2 Mở rộng bảng hiện có

| Bảng | Thêm cột |
|---|---|
| `Patients` | `maBn`, `soCccd` (**cho phép trống**: trẻ em, người nước ngoài, cấp cứu chưa có giấy tờ), `maTheBhyt` (**lưu đủ 15 ký tự**), `maDkbd`, `gtTheTu`, `gtTheDen`, `ngayMienCct`, `maQuocTich`, `maDanToc`, `maNgheNghiep`, `maTinh`, `maHuyen`, `maXa`, `maKhuVuc`, `maDinhDanhYte` |
| `Doctors` | `maDinhDanhYte`, `soChungChiHanhNghe`, `maKhoa` |
| `MedicalVisits` → đổi vai trò thành **đợt KCB** | `maLk` (duy nhất), `maBn`, `ngayVao`, `ngayRa`, `lyDoVv`, `chanDoanVao`, `chanDoanRv`, `maBenhChinh`, `maBenhKt`, `maDoiTuongKcb`, `maLoaiKcb`, `maKhoa`, `ketQuaDtri`, `maLoaiRv`, `maNoiDi`, `maNoiDen`, `maTaiNan`, `canNang`, `ngayTaiKham`, `ghiChu`, `ngayTtoan`, `namQt`, `thangQt`, `status` (open → closed → exported → accepted/rejected) |
| `Products` (thuốc) — bảng phụ `ClinicDrugInfo` 1–1 | `maThuoc` (mã hoạt chất DMDC cho XML2), `maThuocCucQldd` (mã Cục Quản lý Dược cho đơn thuốc quốc gia, ≤ 20 ký tự), `bietDuoc` (≤ 500), `hamLuong`, `duongDung`, `dangBaoChe`, `soDangKy`, `ttThau`, `maNhom`, `donViTinh`, `phamVi`, `tyleTtBh`, `isControlled` |
| `PrescriptionItems` | `lieuDung`, `cachDung`, `ngayYl`, `lotId`, các trường tiền (xem 5.3) |

Dùng bảng phụ `ClinicDrugInfo` thay vì thêm cột vào `Products` để không ảnh hưởng `supply_chain` và module warehouse.

### 5.3 Dòng chi phí và tiền (mới)

| Bảng | Mục đích |
|---|---|
| `ClinicChargeLines` | Một dòng = một mục chi phí trong đợt KCB (thuốc, DVKT, VTYT, tiền khám). Lưu: `maLk`, `kind` (drug/service/supply), `refId`, `soLuong`, `donGiaBv`, `donGiaBh`, `tyleTtBh`, `tyleTtDv`, `mucHuong`, `thanhTienBv`, `thanhTienBh`, `tNguonKhac`, `tBntt`, `tBncct`, `tBhtt`, `maKhoa`, `maBacSi`, `ngayYl`, `ngayThYl`, `ngayKq`, `maPttt` |
| `ClinicInvoices` / `ClinicPayments` | Thu tiền phần người bệnh trả (`T_BNTT + T_BNCCT`), in phiếu thu |

`BhytCostCalculator` điền các cột tiền khi tạo/sửa dòng chi phí. XML2/XML3 đọc thẳng từ đây.

### 5.4 Lâm sàng (mới)

| Bảng | XML |
|---|---|
| `ClinicLabResults` (`maLk`, `maDichVu`, `maChiSo`, `tenChiSo`, `giaTri`, `donViDo`, `moTa`, `ketLuan`, `ngayKq`, `maBsDocKq`) | XML4 |
| `ClinicProgressNotes` (`maLk`, `dienBienLs`, `giaiDoanBenh`, `hoiChan`, `phauThuat`, `thoiDiemDbls`, `nguoiThucHien`) | XML5 |
| `ClinicDischargePapers` (theo trường XML7) | XML7 |

### 5.5 Kho thuốc (tái sử dụng WMS + bổ sung)

- Dùng `StockLots` (số lô, hạn dùng, trạng thái) và `FefoAllocationEngine` đã có trong module warehouse/supply chain.
- Thêm `ClinicStockTransactions`: chỉ insert, mỗi lần nhập/xuất/trả ghi một dòng (`lotId`, `inQty`, `outQty`, `refType`, `refId`, `userId`, `createdAt`).
- Thêm `ClinicControlledDrugLog`: thuốc gây nghiện/hướng thần/tiền chất — người nhận, bác sĩ kê, mã định danh/CCHN, số lô, số lượng, chữ ký/ảnh.

### 5.6 Server

- Migration `server/migrations/versions/0012_clinic_pharma.sql` tạo các bảng `clinic_*` tương ứng.
- Thêm entry `TABLE_ALIASES` trong `server/projector.py` (ví dụ `patients` → `clinic_patients`, `prescriptions` → `clinic_prescriptions`).
- Bảng `clinic_xml_submissions`: `maLk`, loại file, lần gửi, `stt`, nội dung đã đóng gói (hoặc hash), trạng thái, phản hồi Cổng.
- Theo đúng mô hình 3 secret của server: endpoint xuất/gửi XML chỉ dành cho vai trò quản trị phòng khám, không mở cho thiết bị nhân viên thường.

Mỗi thay đổi schema Drift: thêm bảng vào `@DriftDatabase`, tăng `schemaVersion` (hiện là 33), thêm khối `if (from < N)` trong `onUpgrade`, chạy `build_runner`.

---

## 6. ÁNH XẠ DỮ LIỆU → XML (TÓM TẮT)

| XML | Trường | Nguồn |
|---|---|---|
| Check-in | `MA_LK`, `MA_BN`, `HO_TEN`, `SO_CCCD`, `NGAY_SINH`, `GIOI_TINH`, `MA_THE_BHYT`, `MA_DKBD`, `GT_THE_TU/DEN` | Đợt KCB + `Patients` |
| Check-in | `MA_DOITUONG_KCB`, `NGAY`, `MA_LOAI_KCB`, `MA_CSKCB` | Đợt KCB + `ClinicFacility` |
| Check-in | `MADICHVU`, `TEN_DICH_VU`, `NGAY_YL` | Dòng chi phí **đầu tiên** của đợt (thường là tiền khám) |
| XML1 | Thông tin hành chính | `Patients` |
| XML1 | `CHAN_DOAN_*`, `MA_BENH_*`, `KET_QUA_DTRI`, `MA_LOAI_RV`, `NGAY_VAO/RA`, `SO_NGAY_DTRI` | Đợt KCB |
| XML1 | `T_THUOC`, `T_VTYT`, `T_TONGCHI_*`, `T_BNTT`, `T_BNCCT`, `T_BHTT`, `T_NGUONKHAC` | **Tổng hợp** từ `ClinicChargeLines` |
| XML2 | Một dòng / thuốc đã dùng | `ClinicChargeLines(kind=drug)` + `ClinicDrugInfo` + `PrescriptionItems` |
| XML3 | Một dòng / DVKT, VTYT, tiền khám | `ClinicChargeLines(kind=service/supply)` + `ClinicServices` |
| XML4 | Một dòng / chỉ số | `ClinicLabResults` |
| XML5 | Một dòng / lần ghi diễn biến | `ClinicProgressNotes` |

Bảng ánh xạ chi tiết từng trường (kèm định dạng, độ dài, bắt buộc/không) sẽ được sinh thành file cấu hình `xml130_spec` dùng chung cho builder và validator, viết trong Sprint 6.

---

## 7. LỘ TRÌNH (2 TUẦN / SPRINT)

### Giai đoạn 0 — Nền tảng (Sprint 1)
- Sửa `dispensePrescription`: bọc trong `transaction()`, kiểm tra tồn trong cùng giao dịch.
- `ClinicCodeSets`, `ClinicFacility`, `ClinicDepartments` + màn hình import DMDC (CSV/Excel).
- Tiện ích định dạng thời gian `yyyymmddHHMM` / `yyyymmdd`, sinh `MA_LK`, `MA_BN`.
- **Xong khi:** import được ICD-10 và danh mục đường dùng; test cấp phát lỗi giữa chừng không làm lệch tồn kho.

### Giai đoạn 1 — Hành chính & đợt KCB (Sprint 2–3)
- Mở rộng `Patients`, `Doctors`; form tiếp đón có thẻ BHYT, kiểm tra hạn thẻ.
- **Quét QR trên CCCD gắn chip / VNeID** ở bước tiếp đón để tự điền họ tên, số định danh, ngày sinh, giới tính, địa chỉ (dùng `mobile_scanner` đã có trong `pubspec.yaml`). Cần lấy mẫu QR thật để xác nhận định dạng chuỗi trước khi viết parser; nhân viên vẫn xác nhận lại trước khi lưu.
- `MedicalVisits` → đợt KCB có `MA_LK`, trạng thái, chẩn đoán ICD-10 (chọn từ danh mục), kết quả điều trị, loại ra viện.
- Migration server `0012_clinic_pharma.sql` + `TABLE_ALIASES`; đồng bộ các bảng clinic qua outbox.
- **Xong khi:** tạo được đợt khám đầy đủ trường XML1 phần hành chính và chẩn đoán; quét QR CCCD điền đúng thông tin trên mẫu thật; dữ liệu đồng bộ về server.

### Giai đoạn 2 — Thuốc & kho theo lô (Sprint 4)
- `ClinicDrugInfo`; nhập kho theo lô; cấp phát theo FEFO; `ClinicStockTransactions`; `ClinicControlledDrugLog`.
- Kê đơn: tách `LIEU_DUNG` / `CACH_DUNG`, ghi `NGAY_YL`.
- **Xong khi:** cấp phát trừ đúng lô hết hạn sớm nhất; mọi biến động kho có dòng giao dịch; thuốc kiểm soát bắt buộc nhập sổ.

### Giai đoạn 2b — Liên thông Đơn thuốc quốc gia (Sprint 4b–4c)
- Chi tiết tại `02_Lien_Thong_Don_Thuoc_Quoc_Gia_vs_QD130.md` (mục 5–7 và **Phụ lục B — đặc tả API từ `quyet-dinh-808.pdf`**): mã đơn thuốc 14 ký tự, loại đơn `c/h/n/y`, khóa đơn sau khi gửi, `DtqgGateway` trên server với 4 endpoint HIS (đăng nhập cơ sở, thêm bác sĩ, đăng nhập bác sĩ, gửi đơn) và 2 endpoint POS (lấy đơn, cập nhật số lượng bán).
- **Bắt buộc với mọi phòng khám kê đơn**, kể cả không khám BHYT — nếu phòng khám không có hợp đồng BHYT thì giai đoạn này quan trọng hơn Giai đoạn 5–6.
- **Điều kiện tiên quyết:** mã liên thông và mật khẩu của cơ sở và bác sĩ từ phòng khám đối tác (có thể dùng tài khoản thử nghiệm); xác nhận 4 mâu thuẫn trong tài liệu (mã BHYT 10 hay 15 ký tự; tên khóa chẩn đoán; định dạng `H:m:s`; có cần ID thứ tự thuốc hay không). Đã có đặc tả API, không còn chờ toàn văn QĐ 808 để bắt đầu.
- **Luồng đăng nhập theo chuỗi:** token cơ sở (7 ngày) → thêm bác sĩ (một lần cho mỗi bác sĩ) → token bác sĩ (7 ngày) → gửi đơn bằng token bác sĩ. Token được cache trên server và đăng nhập lại khi hết hạn.
- **Định dạng ngày khác nhau theo nơi gửi:** `d/m/Y` cho Đơn thuốc quốc gia, `yyyymmddHHMM` cho Cổng BHXH. Chuyển đổi khi xuất.

### Giai đoạn 3 — Dịch vụ, chi phí & thu tiền (Sprint 5)
- `ClinicServices` (tiền khám, DVKT, VTYT), chỉ định dịch vụ trong đợt khám.
- `ClinicChargeLines` + `BhytCostCalculator` (thuần Dart, có bộ test theo công thức QĐ 130).
- Thu tiền, phiếu thu, chốt đợt.
- **Xong khi:** tổng tiền đợt khám = tổng dòng chi phí; test tính tiền cho các trường hợp: không BHYT, BHYT đúng tuyến, có tỷ lệ thanh toán riêng, ngoài phạm vi.

### Giai đoạn 4 — Cận lâm sàng & diễn biến (Sprint 6)
- Nhập kết quả CLS theo chỉ số (`ClinicLabResults`), ghi diễn biến (`ClinicProgressNotes`), giấy ra viện (XML7) nếu phòng khám cần.
- Viết `xml130_spec` (danh sách trường, kiểu, độ dài, bắt buộc).
- **Xong khi:** đủ dữ liệu cho XML4/XML5 của một đợt khám mẫu.

### Giai đoạn 5 — Sinh và kiểm tra XML (Sprint 7–8)
- `Xml130Builder` trên server: check-in, XML1–XML5 (XML7/8 tùy chọn).
- Validator: độ dài, định dạng ngày, mã thuộc danh mục, **đối soát tổng XML1 với XML2+XML3**.
- Màn hình "Hồ sơ chờ gửi": danh sách đợt đã chốt, lỗi validate, xuất file XML để tải lên Cổng thủ công.
- `clinic_xml_submissions` ghi nhật ký mỗi lần xuất/gửi.
- **Xong khi:** bộ test golden-file: một đợt khám mẫu sinh ra XML khớp từng byte với file mẫu đã duyệt; validator bắt được ít nhất các lỗi: thiếu trường bắt buộc, sai độ dài, sai định dạng ngày, tổng không khớp.

### Giai đoạn 6 — Kết nối Cổng tiếp nhận BHXH (Sprint 9, phụ thuộc tài liệu và tài khoản)
- **Điều kiện tiên quyết:** iZii là bên làm phần mềm nên không tự xin được tài khoản. Cần **một phòng khám đối tác có giấy phép** đứng ra xin tài khoản thử nghiệm (sandbox), tài liệu API và URL endpoint, rồi giao lại cho đội kỹ thuật. Bắt đầu thủ tục này ngay từ Sprint 1 vì thời gian chờ không kiểm soát được.
- Gateway gửi check-in ngay khi phát sinh chi phí đầu tiên; gửi XML1–5 khi chốt đợt; hàng đợi gửi lại khi lỗi (dùng outbox).
- **Chữ ký số của cơ sở KCB:** module ký qua USB Token hoặc dịch vụ ký số từ xa (remote signing), ký trước khi gửi.
- Bắt và hiển thị mã lỗi trả về từ Cổng (sai định dạng ngày, sai mã ICD-10, chữ ký không hợp lệ…); đọc kết quả giám định.
- Nghiệm thu với cơ quan quản lý qua phòng khám đối tác để chuyển sang môi trường thật.
- **Xong khi:** gửi thành công trên môi trường thử nghiệm của Cổng, không còn lỗi.

### Giai đoạn 7 — App cho người dân (sau khi HIS ổn định, chưa ước lượng)
- Đặt lịch, chọn chuyên khoa/giờ khám, khai báo trước tiền sử và dị ứng.
- App sinh QR cho lịch hẹn; phòng khám quét QR để tiếp đón (nối vào `Appointments`).
- Đăng nhập bằng VNeID chỉ làm khi được Bộ Công an cấp phép; trước đó dùng quét QR CCCD để điền thông tin.

---

## 8. KIỂM THỬ

| Loại | Nội dung |
|---|---|
| Unit (Dart) | `BhytCostCalculator`, định dạng thời gian, sinh `MA_LK`, FEFO, cấp phát trong transaction |
| Unit (Python) | Builder từng bảng XML, validator, đóng gói |
| Golden file | 3–5 đợt khám mẫu (không BHYT; BHYT có thuốc + DVKT; có CLS; chuyển tuyến) → XML chuẩn đã được người nghiệp vụ duyệt |
| Đồng bộ | Tạo đợt khám offline trên 2 thiết bị → đồng bộ → server sinh XML đúng, không trùng `MA_LK` |
| Bảo mật | Thiết bị nhân viên không gọi được endpoint xuất/gửi XML; nhật ký truy cập hồ sơ bệnh nhân |

---

## 9. CÂU HỎI CẦN CHỐT TRƯỚC SPRINT 1

1. **Loại cơ sở:** phòng khám có ký hợp đồng KCB BHYT không? Nếu không, XML chỉ cần ở mức lưu trữ/báo cáo và Giai đoạn 6 có thể bỏ.
2. **Văn bản áp dụng:** bản hợp nhất QĐ 130 sau sửa đổi (QĐ 4750/QĐ-BYT và các văn bản sau, nếu có), và tài liệu kỹ thuật Cổng tiếp nhận của BHXH.
3. **Danh mục DMDC:** nguồn file chính thức và tần suất cập nhật.
4. **Phạm vi lâm sàng:** chỉ ngoại trú, hay có nội trú ban ngày? Có làm xét nghiệm/CĐHA tại chỗ không?
5. **Nhà thuốc:** bán lẻ cho khách vãng lai (không qua khám) có cần không? Có kết nối Hệ thống đơn thuốc quốc gia/liên thông nhà thuốc không?
6. **Chữ ký số:** phòng khám đã có chứng thư số chưa? Dùng USB Token hay ký số từ xa?
7. **Phòng khám đối tác:** đơn vị nào đứng ra xin tài khoản sandbox của Cổng tiếp nhận?
8. **Địa giới hành chính:** cách ghi `MAHUYEN_CU_TRU` và mã tỉnh sau sắp xếp đơn vị hành chính 2025.
9. **Đơn thuốc quốc gia:** đã có toàn văn QĐ 808/QĐ-BYT chưa? iZii làm vai trò HIS, hay cả POS cho nhà thuốc bán lẻ (xem file 02, mục 4 và 8)?

---

## 10. RỦI RO

| Rủi ro | Ảnh hưởng | Giảm thiểu |
|---|---|---|
| Văn bản sửa đổi làm thay đổi trường XML | Sinh XML sai, bị từ chối | Spec XML để dạng cấu hình (`xml130_spec`), không hard-code |
| Danh mục DMDC sai/thiếu phiên bản | Mã không hợp lệ | Import có `version`, validator kiểm tra mã theo danh mục còn hiệu lực tại `NGAY_YL` |
| Tính tiền BHYT phức tạp (mức hưởng, trần, cùng chi trả) | Lệch tiền, bị xuất toán | Calculator tách riêng, bộ test lớn, người nghiệp vụ duyệt golden file |
| Đồng bộ offline gây trùng `MA_LK`/`STT` | Hồ sơ trùng | `MA_LK` sinh từ mã cơ sở + thiết bị + thời gian + số tuần tự; `STT` chỉ sinh lúc đóng gói ở server |
| Dữ liệu sức khỏe bị lộ | Vi phạm pháp luật | Phân quyền, nhật ký truy cập, không gửi dữ liệu bệnh nhân cho AI nếu không xác nhận |
| Chưa có tài khoản sandbox của Cổng | Giai đoạn 6 bị chặn | Tìm phòng khám đối tác từ Sprint 1; Giai đoạn 5 vẫn xuất file XML để tải lên thủ công |
| Danh mục hành chính thay đổi sau sắp xếp 2025 | Sai mã nơi cư trú | Danh mục hành chính có `validFrom/validTo`; chờ hướng dẫn chính thức trước khi chốt cách ghi |
| Học theo phần mềm đối thủ bằng cách soi database | Rủi ro pháp lý (EULA thường cấm) | Chỉ tham khảo giao diện/luồng qua bản dùng thử; đặc tả dữ liệu lấy từ văn bản công khai |

---

## PHỤ LỤC A — LỖI TRONG `notes_hoi_dap_AI_chua_kiem_chung.md`

Đối chiếu với file gốc QĐ 130/QĐ-BYT. **Không dùng XML mẫu và schema trong file ghi chú đó.**

| Ghi chú viết | Đúng theo QĐ 130 |
|---|---|
| "QĐ 130/QĐ-BHXH" | 130/QĐ-BYT (Bộ Y tế ban hành) |
| `MA_QUAN_HUYEN`, `MA_PHUONG_XA` | `MATINH_CU_TRU`, `MAHUYEN_CU_TRU`, `MAXA_CU_TRU` |
| `MA_BENH`, `CHAN_DOAN` | `MA_BENH_CHINH`, `MA_BENH_KT`, `CHAN_DOAN_VAO`, `CHAN_DOAN_RV` |
| `TINH_TRANG_RA_VIEN` | `MA_LOAI_RV`: 1 Ra viện; 2 Chuyển tuyến theo yêu cầu chuyên môn; 3 Trốn viện; 4 Xin ra viện; 5 Chuyển tuyến theo yêu cầu người bệnh |
| `KET_QUA_DTRI` có 3 mã | 7 mã: 1 Khỏi; 2 Đỡ; 3 Không thay đổi; 4 Nặng hơn; 5 Tử vong; 6 Tiên lượng nặng xin về; 7 Chưa xác định |
| `NGAY_SINH` 8 ký tự | 12 ký tự `yyyymmddHHMM` |
| `MA_DUONG_DUNG` | `DUONG_DUNG` (chuỗi 4) |
| `MA_THUOC` = mã thuốc quốc gia | Mã **hoạt chất** theo Bộ mã DMDC (XML2). Đơn thuốc quốc gia dùng mã **Cục Quản lý Dược** (`ma_thuoc`) — hai mã khác nhau, xem file 02 Phụ lục B.4 |
| `bhxh_code VARCHAR(10)` "10 số cuối" | `MA_THE_BHYT` chuỗi 15 — lưu đủ mã thẻ |
| `citizen_id NOT NULL UNIQUE` | Phải cho phép trống |
| `full_name 100`, `phone 10` | `HO_TEN` 255, `DIEN_THOAI` 15 |
| `HO_TEN` bắt buộc viết hoa | QĐ 130 không quy định viết hoa |
| Đơn thuốc lưu `prescription_json` | Lưu từng dòng (xem nguyên tắc 6) |
| XML1 mẫu ~20 trường | XML1 ~65 trường, gồm toàn bộ phần tiền `T_*`, `STT`, `MA_DOITUONG_KCB`, `MA_KHOA`… |
| Thẻ bao `<HO_SO><CHECK_SUM>` MD5/SHA256 | Không có trong QĐ 130 — lấy theo tài liệu kỹ thuật chính thức của BHXH |
