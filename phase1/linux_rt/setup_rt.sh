#!/usr/bin/env bash
# =============================================================================
#  setup_rt.sh — Tinh chỉnh Linux PREEMPT_RT cho điều khiển chuyển động
# =============================================================================
#  Chạy: sudo ./setup_rt.sh
#
#  Không có bước tinh chỉnh này, một nhân PREEMPT_RT vẫn cho độ trễ đỉnh
#  cao gấp nhiều lần mức đạt được. Phần lớn các bài than phiền "PREEMPT_RT
#  chẳng cải thiện gì" đến từ việc bỏ qua chính những mục dưới đây.
# =============================================================================
set -euo pipefail

RT_CPU="${RT_CPU:-3}"          # CPU dành riêng cho luồng điều khiển

echo "=== 0. Kiểm tra nhân có PREEMPT_RT không ==============================="
if uname -v | grep -qi 'PREEMPT_RT'; then
    echo "  ✅ Đang chạy nhân PREEMPT_RT: $(uname -r)"
else
    echo "  ❌ Nhân hiện tại KHÔNG phải PREEMPT_RT: $(uname -r)"
    echo "     PREEMPT_RT đã vào mainline từ Linux 6.12 (9/2024)."
    echo "     Cần nhân ≥ 6.12 biên dịch với CONFIG_PREEMPT_RT=y,"
    echo "     hoặc cài gói linux-image-rt-* của bản phân phối."
    echo "     Mọi bước sau đây sẽ không có tác dụng như mong đợi."
fi

echo
echo "=== 1. Tắt điều chỉnh tần số CPU ======================================="
# Tần số nhảy bậc gây jitter: CPU vừa "tỉnh" chạy chậm hơn CPU đang nóng máy.
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w "$g" ] && echo performance > "$g" && echo "  đặt performance: $g"
done || echo "  (không có cpufreq — bỏ qua)"

echo
echo "=== 2. Chặn CPU vào trạng thái ngủ sâu ================================="
# Thoát khỏi C-state sâu tốn hàng chục tới hàng trăm micro giây — đây thường
# là nguyên nhân của những đỉnh trễ hiếm mà khó giải thích.
if [ -w /dev/cpu_dma_latency ]; then
    # Giữ file mở ở nền; đóng file là mất tác dụng.
    (exec 3<> /dev/cpu_dma_latency; printf '\x00\x00\x00\x00' >&3; sleep infinity) &
    echo "  đã ghim cpu_dma_latency = 0 (PID $!)"
    echo "  ⚠ tiến trình này phải SỐNG suốt thời gian chạy thật"
else
    echo "  không ghi được /dev/cpu_dma_latency (cần quyền root)"
fi

echo
echo "=== 3. Trạng thái cách ly CPU =========================================="
echo "  Tham số dòng lệnh nhân hiện tại:"
cat /proc/cmdline | tr ' ' '\n' | grep -E 'isolcpus|nohz|rcu_nocbs' || \
    echo "    (chưa cách ly CPU nào)"
cat <<EOF

  Nếu chưa có, thêm vào dòng lệnh nhân rồi khởi động lại:

      isolcpus=${RT_CPU} nohz_full=${RT_CPU} rcu_nocbs=${RT_CPU}

  Trên Raspberry Pi: sửa /boot/firmware/cmdline.txt (một dòng duy nhất).
  Trên máy dùng GRUB: sửa GRUB_CMDLINE_LINUX_DEFAULT rồi chạy update-grub.

  Ý nghĩa:
    isolcpus   — bộ lập lịch không tự đưa tác vụ thường lên CPU này
    nohz_full  — bỏ ngắt hẹn giờ định kỳ trên CPU này
    rcu_nocbs  — chuyển việc dọn dẹp RCU sang CPU khác
EOF

echo
echo "=== 4. Dời ngắt (IRQ) khỏi CPU dành riêng =============================="
MASK_ALL=$(printf '%x' $(( (1 << $(nproc)) - 1 - (1 << RT_CPU) )))
moved=0
for irq in /proc/irq/[0-9]*; do
    [ -w "$irq/smp_affinity" ] || continue
    echo "$MASK_ALL" > "$irq/smp_affinity" 2>/dev/null && moved=$((moved+1)) || true
done
echo "  đã dời $moved ngắt ra khỏi CPU ${RT_CPU} (mặt nạ 0x$MASK_ALL)"
echo "  (một số ngắt không dời được — điều này bình thường)"

echo
echo "=== 5. Nới giới hạn thời gian chạy của tác vụ RT ======================="
# Mặc định nhân chỉ cho tác vụ RT dùng 950 ms mỗi giây, để tránh treo máy khi
# lập trình sai. -1 = bỏ giới hạn.
# ⚠ CHỈ đặt -1 khi đã tin chắc vòng lặp RT luôn nhả CPU. Một vòng lặp bận
#   không nhả sẽ TREO CỨNG máy, phải cắt điện.
echo "  giá trị hiện tại: $(cat /proc/sys/kernel/sched_rt_runtime_us) us / \
$(cat /proc/sys/kernel/sched_rt_period_us) us"
echo "  giữ nguyên mặc định (an toàn hơn khi đang phát triển)."
echo "  Khi đã sẵn sàng chạy thật:  sysctl -w kernel.sched_rt_runtime_us=-1"

echo
echo "=== 6. Đo cơ sở bằng cyclictest ========================================"
if command -v cyclictest >/dev/null 2>&1; then
    echo "  Chạy 60 giây trên CPU ${RT_CPU}, ưu tiên 80..."
    cyclictest -m -p80 -t1 -a"${RT_CPU}" -i1000 -D60 -q -h400 | tail -20
else
    echo "  Chưa cài cyclictest:  apt install rt-tests"
fi

cat <<'EOF'

=== ĐỌC KẾT QUẢ =========================================================

  Với vòng điều khiển 1 kHz (chu kỳ 1000 µs):

    Max < 50 µs   ✅ Tốt — jitter < 5% chu kỳ, dùng được cho vòng vị trí
    50–150 µs     ⚠  Tạm — chỉ nên dùng cho mô hình thí nghiệm tốc độ thấp
    > 150 µs      ❌ Không dùng cho vòng vị trí. Hãy để máy này chạy tầng
                     L2 (lập quỹ đạo, đội xe, SLAM, giao tiếp iZiiApp) và
                     giao vòng 1 kHz cho STM32.

  Đo TRONG LÚC CÓ TẢI THẬT, không phải lúc máy rảnh. Chạy song song:

      stress-ng --cpu 4 --io 2 --vm 2 --timeout 300s

  Con số đo lúc máy rảnh là con số vô dụng — sự cố không xảy ra lúc rảnh.

=========================================================================
EOF
