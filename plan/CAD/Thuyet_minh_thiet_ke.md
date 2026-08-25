# Thuyết minh bản vẽ — Kho lạnh tự động Costa Mushroom

> **File nguồn:** `generate_cad.py` — mọi kích thước đều tính ra từ tham số, sửa
> tham số rồi chạy lại là ra bộ bản vẽ mới.
>
> **Sản phẩm:** `costa_coldstore.dxf` (CAD) · `dwg01_ga_plan.png` ·
> `dwg02_section.png` · `dwg03_palletiser_cell.png`

---

## 1. Kích thước nhà kho

Bạn cho: dài 30 m, diện tích 1.600 m², cao 8 m. Suy ra:

$$\text{cạnh còn lại} = \frac{1600}{30} = 53{,}33\ \text{m}$$

→ Nhà kho **30,00 × 53,33 m**, thông thuỷ **8,00 m**, thể tích 12.800 m³.

Tôi bố trí **30 m là mặt tiền** (nơi đặt 2 cửa container) và **53,33 m là chiều
sâu**, vì dòng hàng chạy thẳng từ khu xếp pallet ở cuối ra cửa xuất ở đầu. Nếu
thực tế ngược lại, đổi `W` và `D` trong file nguồn rồi chạy lại.

---

## 2. Phát hiện quan trọng nhất: chiều cao 8 m chỉ cho **4 tầng**

Đây là điều cần nói trước tiên vì nó **sửa một giả định trong proposal trước**.

| Thành phần | Kích thước |
|---|---|
| Hàng 9 lớp × 130 mm | 1.170 mm |
| Pallet AS 4068 | 150 mm |
| Xe con thoi + ray | 250 mm |
| Hở kỹ thuật | 100 mm |
| **Bước tầng** | **1.670 mm** |

Trừ 800 mm cho sprinkler, kết cấu mái và đèn → còn 7,20 m dùng được.
**7,20 ÷ 1,67 = 4 tầng.** Đỉnh hàng tầng 4 ở +6,58 m, còn 1,42 m tới trần.

> ⚠️ **Phương án C trong proposal (AS/RS 8 tầng) không khả thi ở nhà cao 8 m** —
> nó cần nhà cao khoảng 14 m. Với 8 m, kệ con thoi 4 tầng là lựa chọn đúng.

---

## 3. Phân vùng (tổng đúng 1.600 m²)

| Vùng | Chiều sâu | Diện tích | Nhiệt độ |
|---|---|---|---|
| Khu xuất hàng & tập kết | 9,00 m | 270 m² | 2–4 °C |
| Lối lấy hàng | 4,00 m | 120 m² | 0–2 °C |
| **Kệ con thoi xuyên suốt** | **22,00 m** | **660 m²** | **0–2 °C** |
| Lối nạp hàng | 4,00 m | 120 m² | 0–2 °C |
| Phòng làm lạnh sơ bộ | 5,00 m | 150 m² | 2–4 °C |
| Khu xếp pallet | 9,33 m | 280 m² | 8–12 °C |
| **Tổng** | **53,33 m** | **1.600 m²** | |

**Phòng làm lạnh sơ bộ 150 m²** là hạng mục tôi chủ động đưa vào — nó trả lời trực
tiếp phát hiện ở Mục 6.7 proposal: đóng pallet ở 20–25 °C làm tải lạnh tăng 44% và
tốc độ hô hấp của nấm gấp 15 lần. Rút nhiệt trước khi vào kho lưu trữ rẻ hơn nhiều
so với mở rộng công suất lạnh của cả kho.

---

## 4. Quyết định thiết kế quan trọng: lane **xuyên suốt**, không phải lane cụt

Đây là điểm kỹ thuật đáng chú ý nhất của bản vẽ.

Kệ con thoi thông thường có **một đầu vào duy nhất** → hàng vào sau ra trước
(**LIFO**). Với nấm hạn dùng 14–20 ngày, LIFO là **rủi ro nghiêm trọng**: pallet cũ
kẹt sâu trong lane, hết hạn trước khi được lấy ra.

Vì vậy tôi bố trí **lane xuyên suốt hai đầu**:

```
Khu xếp pallet → Lối NẠP (Y=35-39) → [ lane 22 m ] → Lối LẤY (Y=9-13) → Cửa xuất
                        nạp ở đầu này              lấy ở đầu kia
```

Hàng chảy một chiều qua lane → **FIFO tự nhiên theo cấu tạo cơ khí**, không phụ
thuộc vào phần mềm hay kỷ luật vận hành. Đây là cách rẻ nhất để bảo đảm FEFO.

---

## 5. Sức chứa

| Thông số | Giá trị |
|---|---|
| Bước lane (phương ngang) | 1.400 mm |
| Số lane | 21 |
| Vị trí mỗi lane (lane 22 m ÷ 1.215 mm) | 18 |
| Số tầng | 4 |
| **Sức chứa kết cấu đầy đủ** | **1.512 pallet** |
| **Giai đoạn 1 — 8 lane** | **576 pallet ≈ 2,8 ngày lưu** |

> **Khuyến nghị: lắp kệ theo giai đoạn.** Nhà kho này thừa sức chứa so với nhu cầu
> 208 pallet/ngày. Lắp đủ 1.512 vị trí ngay từ đầu là chôn vốn không cần thiết.
> Giai đoạn 1 lắp 8 lane (576 pallet, đủ đệm cuối tuần), chừa mặt bằng trống cho
> mở rộng. Kết cấu nhà và nền móng vẫn thiết kế cho đủ 21 lane.

---

## 6. Dây chuyền trong khu xếp pallet

```
Băng tải box vào → ĐỌC MÃ VẠCH → ROBOT 4 TRỤC (4 vị trí xếp P1–P4)
   → Quấn màng → CÂN TỰ ĐỘNG → Dán nhãn SSCC → Phòng làm lạnh sơ bộ → Lối nạp
```

| Thiết bị | Ghi chú |
|---|---|
| Cell robot | 9,0 × 8,0 m, tầm với R3,15 m, rào an toàn AS/NZS 4024 Category 3 |
| 4 vị trí xếp pallet | Phục vụ 4–6 SKU luân phiên nhờ băng tải con lăn ra/vào |
| Đọc mã vạch | Đặt **ngay trước điểm gắp** — tạo liên kết box → pallet tự động |
| Cân tự động | Đối chiếu khối lượng với số box khai báo, cảnh báo tại chỗ |
| Dán nhãn | SSCC theo chuẩn GS1 |

Vị trí đầu đọc mã vạch không phải chi tiết ngẫu nhiên — đó là điểm khiến máy xếp
pallet đồng thời trở thành thiết bị thu thập dữ liệu truy xuất nguồn gốc.

---

## 7. Cửa xuất container

2 cửa rộng 2,70 m, đặt tại X = 9,00 m và X = 21,00 m (cách nhau 12 m — thoải mái
cho xe container xoay trở).

Theo tính toán ở proposal: ~14,5 chuyến xe/ngày, làm việc 10 giờ → 1,45 xe/giờ.
Với hệ số đỉnh 1,5 thì **2 cửa là tối thiểu**; nếu sản lượng tăng nên tính tới cửa
thứ ba.

---

## 8. Cách dùng file DXF

File `costa_coldstore.dxf` là **CAD thật**, không phải ảnh:

- Định dạng **AutoCAD 2010 (AC1024)** — mở được bằng AutoCAD, BricsCAD, LibreCAD,
  DraftSight, QCAD
- Đơn vị **mét**
- **9 lớp** tách riêng: `00-TUONG`, `01-VUNG`, `02-KE`, `03-THIET-BI`,
  `04-BANG-TAI`, `05-CUA`, `06-KICH-THUOC`, `07-CHU`, `08-AN-TOAN`
- Phạm vi hình học khớp đúng 30,00 × 53,33 m

---

## 9. Những gì bản vẽ này **chưa** có

Trung thực về phạm vi — đây là bản vẽ bố trí sơ bộ (concept GA), chưa phải hồ sơ
thi công:

- [ ] Kết cấu nhà: cột, kèo, móng, tải trọng sàn
- [ ] Hệ thống lạnh: dàn lạnh, đường ống, máy nén, phòng máy
- [ ] Điện: tủ phân phối, chiếu sáng, ổ cắm, nối đất
- [ ] Sprinkler / PCCC — **có thể cần sprinkler trong kệ** với kho lạnh 4 tầng,
      phải xác nhận theo AS 2118
- [ ] Thoát nước sàn, dốc nền
- [ ] Cửa cách nhiệt giữa các vùng nhiệt độ, rèm nhựa
- [ ] Bố trí chi tiết dock leveller, gioăng chắn (dock seal)
- [ ] Mặt cắt B-B qua khu xếp pallet
- [ ] Sơ đồ bố trí thiết bị an toàn (rào, khoá liên động, nút E-Stop)

---

## 10. Giả định cần xác nhận

| # | Giả định | Ảnh hưởng nếu sai |
|---|---|---|
| 1 | 30 m là mặt tiền, 53,33 m là chiều sâu | Đảo lại toàn bộ bố trí |
| 2 | 8,00 m là **thông thuỷ**, không phải cao đỉnh mái | Nếu là cao đỉnh mái thì chỉ còn 3 tầng |
| 3 | Nền chịu được tải kệ 4 tầng | Cần kiểm tra kết cấu |
| 4 | Cửa container ở mặt 30 m | Vị trí cửa quyết định hướng dòng hàng |
| 5 | Box 400 × 300 × 130 mm, 72 box/pallet | Thay đổi số vị trí lưu và sơ đồ xếp |
| 6 | Khu đóng gói nằm ngoài nhà kho này | Nếu nằm trong, phải cắt bớt diện tích lưu trữ |

---

*Bản vẽ lập ngày 22/08/2026. Mọi kích thước tính bằng mét. Đây là bản vẽ bố trí sơ
bộ phục vụ trao đổi phương án, chưa dùng để thi công.*
