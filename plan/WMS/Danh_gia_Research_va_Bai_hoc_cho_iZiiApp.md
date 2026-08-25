# Đánh giá `Research.txt` và bài học cho WMS của iZiiApp

> **Nguồn:** `plan/WMS/Research.txt` — báo cáo dự án WMS dùng thuật toán Dijkstra
> để tối ưu đường lấy hàng.
>
> **Code kiểm chứng:** `plan/WMS/routing_benchmark.py` — chạy được, số liệu trong
> tài liệu này lấy trực tiếp từ đó.
>
> **Liên quan:** `plan/Costa_Mushroom_Proposal_Kho_Lanh.md`,
> `integrate/iZiiApp_Schema_Warehouse_Automation.md`

---

## 1. Tóm tắt đánh giá

Tài liệu là một báo cáo dự án học thuật ngắn. Đánh giá thẳng thắn:

| Nội dung | Đánh giá |
|---|---|
| Nhận định "lấy hàng chiếm 55–65% chi phí vận hành kho" | ✅ **Đúng** — số liệu này được trích dẫn rộng rãi trong tài liệu quốc tế |
| Danh mục tham khảo | ✅ **Chuẩn** — Bartholdi & Hackman, Theys et al. là nguồn thật, chất lượng |
| Ý tưởng "suggestion system" xếp hàng theo tần suất bán | ✅ **Đúng hướng** — đây chính là *slotting theo ABC*, một tính năng WMS thật |
| **Chọn Dijkstra làm thuật toán chính** | ❌ **Sai bài toán** — xem Mục 2 |
| Không nhắc tới Ratliff & Rosenthal (1983) | ❌ **Bỏ sót nghiêm trọng** — bài toán này đã có lời giải chính xác từ 1983 |
| Quy mô thử nghiệm: đồ thị 11 nút, 18 cạnh | ⚠️ Bài toán đồ chơi, không phản ánh kho thật |
| Phạm vi WMS được đề cập | ⚠️ Chỉ ~1 trong 10 nhóm chức năng của một WMS thật — xem Mục 4 |

**Kết luận sử dụng:** tài liệu **không dùng được làm cơ sở thiết kế**, nhưng rất
đáng đọc như một ví dụ về cách một bài toán tối ưu hoá dễ bị mô hình hoá sai. Bài
học rút ra ở Mục 2 và Mục 5 mới là phần có giá trị cho iZiiApp.

---

## 2. Lỗi cốt lõi: Dijkstra không giải bài toán mà tài liệu tự mô tả

### 2.1 Tài liệu tự mâu thuẫn

Ngay ở đoạn mở đầu, tài liệu viết:

> *"...given a map (a set of racks and their positions in a warehouse), one wants to
> find **an order for visiting** the corresponding racks in such a way that the
> distance is minimal."*

Đó là định nghĩa của bài toán **người bán hàng rong (TSP)** — tìm **thứ tự** thăm N
điểm. Nhưng tài liệu lại chọn **Dijkstra**, vốn giải bài toán hoàn toàn khác: tìm
**đường đi ngắn nhất giữa hai điểm**.

Hai bài toán này khác nhau về bản chất:

| | Dijkstra | TSP |
|---|---|---|
| Câu hỏi | Đi từ A đến B thế nào cho ngắn nhất? | Thăm N điểm theo thứ tự nào cho ngắn nhất? |
| Độ phức tạp | O(E + V log V) — dễ | NP-hard nói chung |
| Đầu ra | Một đường đi | Một hoán vị |

Điều trớ trêu: **tài liệu tham khảo đúng bài báo cần thiết** — Theys et al. (2010),
*"Using a TSP heuristic for routing order pickers in warehouses"* — nhưng lại không
áp dụng nội dung của nó.

### 2.2 Vậy Dijkstra dùng vào đâu?

Nó **là bước trung gian**, không phải lời giải:

```
Sơ đồ kho (đồ thị)
      │
      ├─► Dijkstra ──► Ma trận khoảng cách giữa các điểm lấy hàng
      │                (metric closure)
      │                        │
      └────────────────────────┴─► Bộ giải TSP ──► Thứ tự đi tối ưu
                                                          │
                                                          ▼
                                                   Lộ trình cho nhân viên
```

Trong `routing_benchmark.py`, Dijkstra được dùng đúng vai trò này — hàm `dmatrix()`
xây ma trận khoảng cách, sau đó mới đưa vào các bộ giải TSP.

### 2.3 Bài toán này đã có lời giải chính xác từ năm 1983

Đây là điều tài liệu bỏ sót đáng tiếc nhất.

**Ratliff & Rosenthal (1983)**, *"Order-Picking in a Rectangular Warehouse: A Solvable
Case of the Traveling Salesman Problem"*, Operations Research 31(3), 507–521, đã chứng
minh: với **kho chữ nhật một khối** (lối ngang chỉ ở hai đầu), bài toán định tuyến lấy
hàng **giải được chính xác bằng quy hoạch động, thời gian đa thức** — cụ thể là **tuyến
tính theo số lối đi**.

Nghĩa là: với đúng cấu hình kho mà tài liệu mô tả, **không cần heuristic nào cả**.
Bài toán không NP-hard trong trường hợp riêng này.

---

## 3. Nhưng tối ưu không phải lúc nào cũng đúng — số liệu thực nghiệm

Tôi đã dựng mô phỏng để định lượng. Kho 10 lối × 20 vị trí, lối rộng 3,0 m, bước vị
trí 1,2 m, 120 đơn hàng ngẫu nhiên mỗi kịch bản.

### 3.1 Kết quả

| Chiến lược | 4 điểm/đơn | 8 điểm/đơn | 12 điểm/đơn |
|---|---|---|---|
| S-shape (zic-zac) | +21,3% | +31,0% | +30,6% |
| Largest gap | +6,5% | +7,2% | +6,1% |
| Nearest neighbour | +2,9% | +6,3% | +6,5% |
| **NN + 2-opt** | **+0,1%** | **+0,8%** | **+1,5%** |
| TSP chính xác (Held-Karp) | 0% (mốc) | 0% | 0% |

Khoảng chênh **21–31%** giữa S-shape và tối ưu khớp tốt với dải **7–34%** mà tài liệu
nghiên cứu quốc tế báo cáo — xác nhận mô phỏng hợp lệ.

### 3.2 Ba bài học từ bảng này

**① Không cần thuật toán chính xác.** `NN + 2-opt` đạt trong vòng **0,1–1,5%** của
tối ưu, chạy nhanh, và **không giới hạn quy mô**. Held-Karp là O(2ⁿ·n²) — chỉ dùng
được đến ~14 điểm. Với sản phẩm thương mại, NN + 2-opt là lựa chọn đúng.

**② Largest gap tốt hơn S-shape rất nhiều** (6% so với 30%) mà vẫn đơn giản, dễ giải
thích cho nhân viên. Đây là điểm ngọt nếu cần một quy tắc con người theo được.

**③ Và đây là điều quan trọng nhất:** trong thực tế, **S-shape vẫn được dùng rộng rãi
dù kém 30%.** Lý do không nằm ở thuật toán:

- Lộ trình tối ưu trông **ngẫu nhiên** với người đi — họ đi sai, quay lại, hoặc bỏ qua
- Trong lối hẹp, hai xe gặp nhau là **tắc**; S-shape có hướng đi nhất quán nên ít tắc
- Thời gian **thực tế** gồm cả thời gian với tay lấy hàng, quét mã, xác nhận — quãng
  đường đi chỉ là một phần
- Đào tạo và tuân thủ có chi phí thật

> **Bài học cho iZiiApp:** một tính năng tối ưu hoá chỉ tạo giá trị khi **con người
> hoặc máy thực sự làm theo được nó**. Đây là loại sai lầm mà một dự án học thuật
> không nhìn thấy, còn một sản phẩm thương mại thì trả giá.

---

## 4. Phần 80% mà tài liệu không đề cập

Tài liệu coi WMS ≈ tối ưu đường lấy hàng. Thực tế đường lấy hàng chỉ là **một mục nhỏ
trong một nhóm chức năng**. Dưới đây là mô hình năng lực của một WMS thật, kèm hiện
trạng iZiiApp:

| Nhóm chức năng | Nội dung | iZiiApp hiện có? |
|---|---|---|
| **Nhập hàng** | ASN, nhận hàng, kiểm tra, tạm giữ QC, cất hàng | ⚠️ Một phần (`StockMoves`) |
| **Tồn kho** | LPN/pallet, lô/batch, hạn dùng, quy đổi đơn vị, kiểm kê chu kỳ, điều chỉnh | ⚠️ Cơ bản (`StockQuants`) |
| **Vị trí lưu trữ** | Mô hình vị trí phân cấp, slotting, bổ sung hàng (replenishment), gom vị trí | ❌ **Thiếu — đã thiết kế, chưa triển khai** |
| **Xuất hàng** | Quản lý đơn, phân bổ (FEFO/FIFO), lập sóng/lô, lấy hàng, đóng gói, tập kết, xếp xe | ❌ Thiếu |
| **Bãi & cửa xuất** | Đặt lịch xe, gán cửa, quản lý bãi chờ | ❌ Thiếu |
| **Nhân lực** | Xen kẽ tác vụ, định mức lao động, năng suất | ⚠️ Có chấm công, chưa có định mức |
| **Tích hợp** | ERP, TMS, hãng vận chuyển, EDI | ⚠️ Có nền (`event_engine`, webhooks) |
| **Truy xuất** | Phả hệ lô, thu hồi, hồ sơ nhiệt độ | ⚠️ Mạnh ở phía nông trại, đứt ở phía kho |
| **Xử lý ngoại lệ** | Thiếu hàng, hư hỏng, trả hàng, tồn lệch | ❌ Thiếu |
| **Định tuyến lấy hàng** | *Chủ đề duy nhất của tài liệu* | ❌ Chưa có — và **không nên làm sớm** |

Nhìn bảng này thì thấy rõ: nếu iZiiApp bắt đầu bằng tối ưu đường lấy hàng, đó sẽ là
việc **cuối cùng đáng làm** được làm **đầu tiên**.

---

## 5. Áp dụng cho Costa: phần lớn KHÔNG áp dụng — và vì sao điều đó quan trọng

Đây là kết luận có giá trị nhất từ việc đọc tài liệu này.

### 5.1 Costa không có bài toán lấy hàng lẻ

| | Kho trong tài liệu | **Kho lạnh Costa** |
|---|---|---|
| Đơn vị xuất | Món lẻ (piece) | **Nguyên pallet** |
| Nhân viên đi bộ gom hàng | Có — chiếm 55% chi phí | **Không có** |
| Số điểm dừng mỗi đơn | 5–20 | **1** (lấy pallet, đưa ra cửa) |
| Bài toán trọng tâm | Thứ tự thăm các kệ | **Mật độ lưu trữ, hạn dùng, nhiệt độ** |

Costa là mô hình **pallet vào — pallet ra**. Xe nâng lấy một pallet và đưa thẳng ra
container. **Không có lộ trình nhiều điểm để tối ưu.** Toàn bộ nội dung Dijkstra/TSP
của tài liệu không áp dụng được cho dự án Costa.

### 5.2 Nhưng một ý tưởng thì áp dụng được — với điều kiện sửa mục tiêu

Tài liệu đề xuất "suggestion system": xếp hàng bán chạy ra kệ gần lối ra. Đó là
**slotting theo tốc độ luân chuyển (ABC)** — một tính năng WMS thật và hữu ích.

**Nhưng với hàng tươi sống, tối ưu theo tốc độ bán là SAI mục tiêu.**

| Loại hàng | Mục tiêu slotting đúng |
|---|---|
| Hàng khô, lâu hỏng | Tốc độ luân chuyển (ABC) — hàng bán chạy để gần |
| **Nấm tươi (Costa)** | **Thời điểm xuất + hạn dùng (FEFO)** — pallet đi trước để gần cửa |

Với nấm hạn dùng 14–20 ngày ở 1 °C, việc **để lọt một pallet cũ ở sâu trong kho** tốn
kém hơn nhiều so với việc đi thêm vài chục mét. Nên quy tắc slotting cho Costa là:

> **Ưu tiên 1 — FEFO:** pallet cũ nhất phải được lấy trước, không có ngoại lệ.
> **Ưu tiên 2 — gần cửa xuất theo đơn:** pallet dành cho container sắp tới đặt gần cửa.
> **Ưu tiên 3 — gom cùng SKU:** giảm số lần di chuyển khi xếp container.

Đây là điều chỉnh nhỏ về mục tiêu nhưng đảo ngược hoàn toàn kết quả so với ABC.

---

## 6. Thứ tự nên xây WMS cho iZiiApp

Dựa trên Mục 4 và Mục 5, đây là thứ tự tôi đề xuất — **ngược hoàn toàn với thứ tự
mà tài liệu gợi ý**:

| # | Hạng mục | Vì sao trước | Trạng thái |
|---|---|---|---|
| 1 | **Mô hình vị trí phân cấp** | Không có nó thì không có gì khác chạy được | ✅ Đã thiết kế trong `iZiiApp_Schema_Warehouse_Automation.md` |
| 2 | **LPN/pallet + gom box (SSCC)** | Chính là phạm vi dự án Costa; mở khoá truy xuất | 🔨 Đang làm |
| 3 | **Phân bổ FEFO** | Bắt buộc với hàng tươi; là điểm khác biệt bán hàng | ❌ Chưa |
| 4 | **Cất hàng có chỉ dẫn** (theo FEFO + gần cửa + vùng nhiệt) | Nơi tạo giá trị vận hành thật cho Costa | ❌ Chưa |
| 5 | **Kiểm kê chu kỳ** | Không có nó, độ chính xác tồn kho suy giảm âm thầm | ❌ Chưa |
| 6 | **Quản lý đơn xuất & sóng** | Cần cho khách hàng thứ hai trở đi | ❌ Chưa |
| 7 | **Xen kẽ tác vụ (task interleaving)** | Chỉ đáng làm khi lưu lượng xe nâng đủ lớn | ❌ Chưa |
| 8 | **Tối ưu đường lấy hàng** | **Chỉ cần khi có khách hàng lấy lẻ (3PL, bán lẻ)** | ❌ Chưa — và không vội |

### 6.1 Khi nào mới nên làm mục 8

Tối ưu đường lấy hàng chỉ tạo giá trị khi **cả ba** điều kiện dưới đây đúng:

1. Khách hàng có nghiệp vụ **lấy lẻ**, nhiều điểm dừng mỗi đơn
2. Nhân viên (hoặc robot) **thực sự đi theo** lộ trình được chỉ định
3. Lối đi **đủ rộng** để việc đi theo lộ trình không gây tắc

Nếu iZiiApp mở rộng sang 3PL hoặc phân phối bán lẻ tại Úc thì cả ba điều kiện đều
thoả, và lúc đó `routing_benchmark.py` là điểm khởi đầu sẵn sàng — dùng **NN + 2-opt**,
không dùng Dijkstra đơn thuần, không cần Held-Karp.

---

## 7. Bổ sung mô hình dữ liệu

Ba trường cần thêm vào thiết kế schema đã có, để mở khoá FEFO và slotting:

```dart
// Bổ sung vào bảng Locations (đã thiết kế)
IntColumn  get dockDistance   => integer().nullable()();  // mét tới cửa xuất gần nhất
TextColumn get tempZone       => text().withDefault(const Constant('chilled'))();
                                  // chilled · ambient · staging

// Bổ sung vào bảng pallet/LPN
DateTimeColumn get builtAt    => dateTime()();            // mốc FEFO — KHÔNG dùng thời điểm nhập kho
DateTimeColumn get bestBefore => dateTime().nullable()();
TextColumn     get allocatedOrderId => text().nullable()();
```

**Lưu ý về `builtAt`:** mốc FEFO phải là **thời điểm đóng pallet**, không phải thời
điểm cất vào kho. Hai mốc này lệch nhau khi pallet bị chờ, và dùng nhầm mốc sẽ làm
FEFO sai một cách âm thầm — đúng loại lỗi khó phát hiện nhất.

Truy vấn phân bổ FEFO trở nên đơn giản:

```sql
SELECT p.sscc, p.built_at, l.dock_distance
FROM pallets p
JOIN locations l ON l.id = p.location_id
WHERE p.sku_id = :sku
  AND p.status = 'stored'
  AND p.allocated_order_id IS NULL
ORDER BY p.built_at ASC,          -- FEFO: ưu tiên tuyệt đối
         l.dock_distance ASC       -- rồi mới tới khoảng cách
LIMIT :qty;
```

Thứ tự hai cột `ORDER BY` chính là toàn bộ khác biệt giữa slotting cho hàng khô và
cho hàng tươi.

---

## 8. Điều đáng học nhất từ tài liệu này

Không phải thuật toán, mà là một bài học về phương pháp:

> **Tài liệu mô hình hoá sai bài toán ngay ở câu đầu tiên, rồi triển khai đúng lời
> giải cho bài toán sai đó.**

Mọi thứ phía sau — code, giao diện Django, kết luận — đều nhất quán và chỉn chu. Sai
sót không nằm ở khâu thực thi. Nó nằm ở khâu **xác định bài toán**, và không có
lượng công sức thực thi nào bù lại được.

Ứng dụng trực tiếp vào iZiiApp: trước khi xây bất kỳ tính năng tối ưu hoá nào, hãy
trả lời bằng **số liệu đo được**:

1. Chi phí thật của hoạt động này hiện là bao nhiêu?
2. Trần lý thuyết của việc tối ưu là bao nhiêu phần trăm?
3. Con người/máy có thực sự làm theo được kết quả không?
4. Có hạng mục nào khác rẻ hơn mà lợi hơn không?

Với Costa, câu trả lời cho câu 1 là "gần như bằng không" — vì họ không có nghiệp vụ
lấy lẻ. Đó là lý do bản đề xuất kho lạnh tập trung vào **mật độ lưu trữ, truy xuất
nguồn gốc và nhiệt độ**, không phải vào tối ưu lộ trình.

---

## Phụ lục — Kiểm chứng

### A.1 Đã xác minh từ nguồn chính thức

| Nội dung | Kết quả | Nguồn |
|---|---|---|
| Ratliff & Rosenthal (1983) | Xác nhận: Operations Research 31(3), 507–521. QHĐ **thời gian đa thức**, tuyến tính theo số lối | INFORMS / Semantic Scholar |
| Lấy hàng chiếm >55% chi phí kho | Xác nhận, được trích dẫn rộng rãi | Tài liệu tổng quan ngành |
| Tối ưu so với S-shape | Xác nhận: giảm **7–34%** tuỳ bố trí kho | Nghiên cứu so sánh định tuyến |
| Largest gap tốt hơn S-shape khi ít điểm/lối | Xác nhận: có lợi khi < ~3 điểm mỗi lối | Như trên |

### A.2 Đã kiểm chứng bằng mô phỏng

Chạy `python3 plan/WMS/routing_benchmark.py`. Kết quả ở Mục 3.1 tái lập được với
`seed=7`. Mô phỏng dùng khoảng cách theo phương trục (rectilinear), phù hợp với kho
lối song song.

### A.3 Giới hạn của phân tích này

- Mô phỏng chỉ xét kho **một khối**. Kho nhiều khối (có lối ngang giữa) khó hơn và
  Ratliff–Rosenthal không áp dụng trực tiếp.
- Chỉ đo **quãng đường**, không đo thời gian thật (chưa gồm thời gian với tay lấy
  hàng, quét mã, tắc lối). Trong thực tế quãng đường thường chiếm 50–70% thời gian.
- Không mô phỏng **nhiều người lấy hàng đồng thời** — nơi tắc nghẽn phát sinh và
  lợi thế của lộ trình tối ưu suy giảm.
- Tôi **chưa đọc được mã nguồn** của dự án gốc, chỉ đọc bản mô tả. Có thể phần cài
  đặt thực tế đã bổ sung TSP mà bản mô tả không nêu.
