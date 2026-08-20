# Giai đoạn 1 — Khung code điều khiển trục, ba nền tảng RTOS

> Đi kèm:
> - `integrate/iZiiApp_Thiet_Ke_He_Dieu_Khien_RealTime.md` — thiết kế tổng thể
> - `integrate/iZiiApp_GiaiDoan1_MachAnToan_Cat3.md` — mạch an toàn phần cứng
>
> ⚠ **Code trong thư mục này KHÔNG chứa chức năng an toàn nào.** Chuỗi an toàn
> là phần cứng Category 3 độc lập. Đọc tài liệu mạch an toàn trước khi cấp điện.

---

## 1. Nguyên tắc kiến trúc: một lõi, ba lớp vỏ

```
                    ┌──────────────────────────┐
                    │   common/control_core.c  │
                    │   ─────────────────────  │
                    │   S-curve · Input shaping│
                    │   PID + Feedforward      │
                    │   Đệm đôi không khoá     │
                    │                          │
                    │   KHÔNG phụ thuộc RTOS   │
                    │   KHÔNG malloc/printf    │
                    └────────────┬─────────────┘
                                 │
            ┌────────────────────┼────────────────────┐
            │                    │                    │
   ┌────────▼───────┐  ┌─────────▼──────┐  ┌──────────▼────────┐
   │ freertos/      │  │ zephyr/        │  │ linux_rt/         │
   │ app_freertos.c │  │ main.c         │  │ main_rt.c         │
   │ STM32F7        │  │ STM32/nRF/...  │  │ x86 · Pi · ARM64  │
   └────────────────┘  └────────────────┘  └───────────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  test/test_control_core.c│
                    │  Chạy trên MÁY TÍNH      │
                    │  58/58 đạt               │
                    └──────────────────────────┘
```

**Vì sao tách như vậy — và nó đã trả công ngay lập tức:**

Trong lúc viết, bản đầu tiên của `traj_eval()` tính trạng thái cuối hành trình
bằng cách gọi đệ quy chính nó với `T_total - 1e-7f`. Nghe hợp lý. Nhưng với
`float` 32-bit, khi `T_total` đủ lớn thì `T_total - 1e-7f` **làm tròn về đúng
`T_total`** ⇒ đệ quy vô hạn ⇒ tràn stack.

- Trên host: AddressSanitizer chỉ ra trong **4 giây**, kèm ngăn xếp đầy đủ.
- Trên STM32: HardFault xuất hiện **ngẫu nhiên tuỳ độ dài hành trình**, không có
  thông báo, có thể mất nhiều ngày để truy — và có thể phá hỏng cơ cấu trong lúc
  thử nghiệm.

Đó là toàn bộ lý do tồn tại của `common/`.

---

## 2. Chạy test trên máy tính (làm trước tiên)

```bash
cd phase1
cc -O2 -Wall -Wextra -Wpedantic -std=c11 -I common \
   -o /tmp/test_cc test/test_control_core.c common/control_core.c -lm
/tmp/test_cc

# Nên chạy thêm bản có sanitizer — bắt được lỗi bộ nhớ và tràn số:
cc -O0 -g -std=c11 -fsanitize=address,undefined -I common \
   -o /tmp/test_asan test/test_control_core.c common/control_core.c -lm
/tmp/test_asan
```

Kết quả hiện tại: **58/58 đạt**, sạch dưới ASan + UBSan và `-O2 -Wpedantic`.

Vài con số test xác nhận, đối chiếu với tài liệu thiết kế:

| Kiểm chứng | Kết quả |
|---|---|
| Hệ số ZV / ZVD ($f_n$=1,2 Hz, $\zeta$=0,02) | Khớp mục 5.3 tài liệu thiết kế |
| Sai số bám **không** feedforward | **50,00 mm** |
| Sai số bám **có** feedforward | **0,05 mm** — cải thiện ~1000× |
| Tôn trọng giới hạn v/a/j trên toàn quỹ đạo | Đạt, quét 20 000 điểm |
| Bỏ E-Stop không tự phục hồi | Đạt — yêu cầu an toàn thật |

---

## 3. So sánh ba nền tảng

| Tiêu chí | FreeRTOS | Zephyr | Linux PREEMPT_RT |
|---|---|---|---|
| **Jitter điển hình @1 kHz** | < 5 µs | < 10 µs | 30–800 µs (rất phân tán) |
| **Dùng được cho vòng vị trí?** | ✅ Có | ✅ Có | ⚠ Chỉ khi tự đo đạt |
| Hướng ưu tiên | Số lớn = cao | **Số nhỏ = cao** | Số lớn = cao |
| Bộ nhớ tối thiểu | ~10 KB | ~30 KB | ~100 MB |
| Độ dốc học | Thấp | Trung bình–cao | Cao (nếu chưa quen Linux) |
| Mô tả phần cứng | Tay | Devicetree | Devicetree / ACPI |
| Test trên host | Qua `common/` | **`native_sim` — toàn bộ app** | Chạy trực tiếp |
| Mạng / TCP-IP | Cần thêm lwIP | **Tích hợp sẵn** | Đầy đủ |
| CAN / CANopen | Thêm ngoài | **Tích hợp sẵn** | SocketCAN |
| Hệ sinh thái driver | Nghèo | **Phong phú** | Rất phong phú |
| Phù hợp nhất cho | **L1: vòng điều khiển** | **L1 + kết nối mạng** | **L2: WCS, SLAM, đội xe** |

### 3.1 Khuyến nghị cho dự án của bạn

```
  ┌─────────────────────────────────────────────────────────┐
  │  L2 — Linux PREEMPT_RT (x86 mini-PC hoặc Pi)            │
  │       Lập kế hoạch, đội xe, SLAM, giao tiếp iZiiApp     │
  └──────────────────────────┬──────────────────────────────┘
                             │  EtherCAT / Modbus TCP
  ┌──────────────────────────▼──────────────────────────────┐
  │  L1 — STM32F7 + FreeRTOS (hoặc Zephyr)                  │
  │       Vòng vị trí 1 kHz, quỹ đạo, chống lắc             │
  └──────────────────────────┬──────────────────────────────┘
                             │  EtherCAT CiA 402
  ┌──────────────────────────▼──────────────────────────────┐
  │  L0 — Servo Drive: vòng dòng, vòng vận tốc, STO          │
  └─────────────────────────────────────────────────────────┘
```

**Chọn FreeRTOS hay Zephyr cho L1?**

- **FreeRTOS** nếu bạn muốn khởi động nhanh, đã quen STM32CubeIDE, và trục
  không cần nối mạng phức tạp. Ít khái niệm phải học, dễ suy luận về hành vi.
- **Zephyr** nếu bạn muốn `native_sim` (xem mục 4), cần CANopen/Ethernet tích
  hợp, hoặc dự tính chạy trên nhiều dòng chip khác nhau về sau.

Vì `common/control_core.c` giống hệt nhau ở cả hai, **chuyển đổi sau này tốn
khoảng một ngày**, không phải viết lại. Đừng để quyết định này chặn tiến độ.

---

## 4. `native_sim` — điểm mạnh riêng của Zephyr

Zephyr biên dịch **toàn bộ ứng dụng, kể cả bộ lập lịch và luồng**, thành một
tiến trình Linux thường:

```bash
west build -b native_sim -- \
    -DCONFIG_HW_STACK_PROTECTION=n -DCONFIG_FPU=n -DCONFIG_WATCHDOG=n
./build/zephyr/zephyr.exe
```

Khác biệt so với việc chỉ test `common/` trên host: bạn kiểm tra được cả **logic
đa luồng** — thứ tự ưu tiên, tranh chấp dữ liệu, bế tắc — mà không cần phần
cứng. Chạy được cả dưới `valgrind` và `gdb`.

Với hệ điều khiển có nhiều luồng tương tác, đây là lợi thế thật sự, không phải
tính năng phụ.

---

## 5. Ba khác biệt dễ gây lỗi khi chuyển giữa các nền tảng

| # | Vấn đề | Hậu quả nếu bỏ sót |
|---|---|---|
| 1 | **Hướng ưu tiên ngược nhau.** FreeRTOS: số lớn = cao. Zephyr: số nhỏ = cao. | Không lỗi biên dịch. Lịch biểu sai âm thầm, phân tích RTA mất giá trị. |
| 2 | **`CONFIG_FPU_SHARING` của Zephyr.** Bắt buộc khi ≥ 2 luồng dùng float. | Thanh ghi FPU hỏng khi chuyển ngữ cảnh ⇒ số liệu sai ngẫu nhiên, **không báo lỗi**. |
| 3 | **Chờ theo mốc tuyệt đối.** `vTaskDelayUntil` / `K_TIMEOUT_ABS_TICKS` / `clock_nanosleep(TIMER_ABSTIME)`. | Dùng kiểu tương đối ⇒ chu kỳ trôi dần, tần số lấy mẫu sai lệch tích luỹ. |

Cả ba đều thuộc loại lỗi **không gây sập ngay** mà làm sai lệch từ từ — loại tốn
nhiều thời gian nhất để truy ra.

---

## 6. Quy trình đưa lên phần cứng (theo thứ tự)

1. **Chạy test trên host** — phải 58/58 trước khi làm gì khác.
2. **Đấu và kiểm chứng mạch an toàn** theo `iZiiApp_GiaiDoan1_MachAnToan_Cat3.md`
   mục 7. Làm **trước** khi nạp firmware điều khiển.
3. Nạp firmware với động cơ **tháo rời khỏi cơ cấu** — chỉ quay trục không tải.
4. **Đo WCET thật** bằng toggle GPIO + oscilloscope. Đối chiếu với bảng mục 4.2
   tài liệu thiết kế. Nếu lệch quá 1,5 lần, tính lại lịch biểu trước khi đi tiếp.
5. Bật feedforward, chỉnh `k_vff`, đo sai số bám.
6. Gắn vào cơ cấu, chạy tốc độ thấp.
7. Đo tần số riêng bằng gia tốc kế → bật input shaping.
8. **Phép thử quyết định:** đang chạy tốc độ cao, rút cáp nguồn STM32.
   Trục **phải** dừng an toàn qua chuỗi phần cứng. Nếu không, kiến trúc sai —
   sửa phần cứng, không sửa code.

---

## 7. Việc chưa làm trong khung này

Trung thực về phạm vi — đây là khung giai đoạn 1, không phải sản phẩm:

- [ ] Lớp HAL thật (`hal_encoder_read_position` v.v. hiện là `extern`)
- [ ] Ghép EtherCAT / CiA 402 với drive
- [ ] Máy trạng thái PackML đầy đủ (mục 7 tài liệu thiết kế)
- [ ] Quy trình về gốc (homing)
- [ ] Bù backlash, bù nhiệt
- [ ] Nhận dạng tham số để đặt `k_aff`
- [ ] Watchdog và xử lý reset
- [ ] Lưu tham số vào bộ nhớ không mất điện
- [ ] Giao thức truyền thông với WCS

Các mục này thuộc giai đoạn 1 phần sau và giai đoạn 2. Đừng nhảy sang giai đoạn
2 khi phép thử ở mục 6.8 chưa đạt.
