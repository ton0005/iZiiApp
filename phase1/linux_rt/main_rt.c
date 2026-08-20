/* =========================================================================
 *  main_rt.c — Adapter Linux PREEMPT_RT cho giai đoạn 1
 * =========================================================================
 *
 *  CÙNG control_core.c với hai bản kia. Chỉ lớp vỏ khác.
 *
 *  ĐỌC PHẦN NÀY TRƯỚC KHI DÙNG — QUAN TRỌNG HƠN CODE BÊN DƯỚI
 *  -----------------------------------------------------------------------
 *  PREEMPT_RT đã vào nhân Linux chính thức từ phiên bản 6.12 (tháng 9/2024)
 *  cho x86, x86_64, ARM64 và RISC-V. Giờ chỉ cần bật CONFIG_PREEMPT_RT lúc
 *  biên dịch nhân, không phải vá tay như trước.
 *
 *  NHƯNG: PREEMPT_RT làm nhân có thể CHIẾM QUYỀN (preemptible), nó KHÔNG
 *  biến Linux thành hệ tất định như vi điều khiển trần. Độ trễ đo thực tế
 *  trên Raspberry Pi rất phân tán tuỳ phiên bản nhân, cấu hình và tải:
 *
 *      Pi 4 (64-bit), tinh chỉnh tốt ...... khoảng 30–40 µs đỉnh
 *      Pi 4, cấu hình thường .............. tới ~200 µs
 *      Pi 5, một số phép đo ............... 150 µs đến ~800 µs đỉnh
 *
 *  Với vòng điều khiển 1 kHz (chu kỳ 1000 µs), jitter 377 µs là 38% chu kỳ.
 *  Vòng vị trí servo cần jitter dưới ~5% chu kỳ để không sinh nhiễu mô-men.
 *
 *  ⇒ KHUYẾN NGHỊ THẲNG THẮN:
 *
 *      DÙNG máy Linux RT cho tầng L2:  lập kế hoạch quỹ đạo, quản lý đội
 *      xe, SLAM, tìm đường, HMI, giao tiếp với iZiiApp.
 *
 *      KHÔNG dùng nó thay STM32 ở vòng vị trí 1 kHz.
 *
 *  File này vì thế có HAI cách dùng, và bạn nên chọn cách (a):
 *    (a) Chạy tầng lập quỹ đạo + giao tiếp, gửi điểm đặt xuống STM32  ✅
 *    (b) Chạy cả vòng vị trí — CHỈ cho mô hình thí nghiệm, tốc độ thấp,
 *        và chỉ sau khi đã tự đo cyclictest trên đúng phần cứng của bạn ⚠
 *
 *  Biên dịch:
 *      cc -O2 -Wall -Wextra -std=c11 -I../common \
 *         -o axis_rt main_rt.c ../common/control_core.c -lm -lpthread
 *  Chạy (cần quyền để đặt SCHED_FIFO):
 *      sudo ./axis_rt
 * ========================================================================= */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sched.h>
#include <pthread.h>
#include <time.h>
#include <signal.h>
#include <stdatomic.h>
#include <sys/mman.h>
#include <unistd.h>

#include "control_core.h"

/* =========================================================================
 *  1. THAM SỐ
 * ========================================================================= */
#define NSEC_PER_SEC        1000000000L
#define PERIOD_POSCTRL_NS   1000000L     /* 1 ms  */
#define PERIOD_TRAJ_NS      10000000L    /* 10 ms */

/* Ưu tiên SCHED_FIFO: 1..99, SỐ LỚN = ƯU TIÊN CAO (giống FreeRTOS,
 * ngược Zephyr). Tránh 99 — để dành cho luồng nội bộ của nhân. */
#define RTPRIO_POSCTRL      80
#define RTPRIO_TRAJ         60

#define CPU_POSCTRL         3            /* CPU đã cách ly qua isolcpus */

#define MAX_SAFE_STACK      (64 * 1024)

/* =========================================================================
 *  2. TRẠNG THÁI
 * ========================================================================= */
static traj_slot_t     g_slot;
static pid_t           g_pid;
static shaper_t        g_shaper;
static safety_mirror_t g_safety;
static traj_limits_t   g_limits = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };

static _Atomic float g_pos_measured;
static _Atomic float g_pos_error;
static _Atomic float g_target_pos;
static atomic_int    g_new_target;
static atomic_int    g_running = 1;

/* Biểu đồ phân bố độ trễ — µs, gộp tất cả ≥ 1000 vào ô cuối */
#define HIST_BINS 1000
static unsigned long g_hist[HIST_BINS + 1];
static long g_lat_max_ns;

/* HAL — thay bằng giao tiếp thật (SPI/EtherCAT/CAN) */
extern float hal_encoder_read_position(void);
extern void  hal_drive_set_velocity(float v);
extern bool  hal_read_safety_relay_aux(void);
extern bool  hal_read_drive_sto_status(void);

/* =========================================================================
 *  3. CHUẨN BỊ MÔI TRƯỜNG THỜI GIAN THỰC
 * =========================================================================
 *  Ba việc dưới đây là BẮT BUỘC. Thiếu bất kỳ việc nào thì mọi con số đo
 *  được đều vô nghĩa, vì lỗi trang bộ nhớ (page fault) có thể gây trễ hàng
 *  mili giây một cách ngẫu nhiên.
 * ========================================================================= */

/* (1) Khoá toàn bộ bộ nhớ vào RAM — cấm hệ điều hành swap ra đĩa. */
static int lock_memory(void)
{
    if (mlockall(MCL_CURRENT | MCL_FUTURE) != 0) {
        fprintf(stderr, "mlockall that bai: %s\n"
                        "  -> chay bang sudo, hoac cap CAP_IPC_LOCK\n",
                strerror(errno));
        return -1;
    }
    return 0;
}

/* (2) Chạm trước toàn bộ stack, ép nhân cấp phát ngay bây giờ.
 *
 * VÌ SAO CẦN: mlockall khoá các trang ĐÃ ánh xạ. Stack lớn dần theo nhu
 * cầu, nên lần đầu hàm gọi sâu sẽ gây page fault — đúng vào lúc đang chạy
 * thời gian thực. Chạm trước để việc đó xảy ra lúc khởi động. */
static void prefault_stack(void)
{
    unsigned char dummy[MAX_SAFE_STACK];
    memset(dummy, 0, sizeof(dummy));
    /* Ngăn trình biên dịch loại bỏ đoạn trên */
    __asm__ __volatile__("" :: "r"(dummy) : "memory");
}

/* (3) Đặt lịch SCHED_FIFO và gắn vào một CPU cụ thể. */
static int set_realtime(int prio, int cpu)
{
    struct sched_param sp;
    memset(&sp, 0, sizeof(sp));
    sp.sched_priority = prio;

    if (sched_setscheduler(0, SCHED_FIFO, &sp) != 0) {
        fprintf(stderr, "sched_setscheduler that bai: %s\n", strerror(errno));
        return -1;
    }

    if (cpu >= 0) {
        cpu_set_t set;
        CPU_ZERO(&set);
        CPU_SET(cpu, &set);
        if (sched_setaffinity(0, sizeof(set), &set) != 0) {
            fprintf(stderr, "sched_setaffinity that bai: %s\n", strerror(errno));
            return -1;
        }
    }
    return 0;
}

static inline void timespec_add_ns(struct timespec *ts, long ns)
{
    ts->tv_nsec += ns;
    while (ts->tv_nsec >= NSEC_PER_SEC) {
        ts->tv_nsec -= NSEC_PER_SEC;
        ts->tv_sec++;
    }
}

static inline long timespec_diff_ns(const struct timespec *a,
                                    const struct timespec *b)
{
    return (a->tv_sec - b->tv_sec) * NSEC_PER_SEC + (a->tv_nsec - b->tv_nsec);
}

/* =========================================================================
 *  4. LUỒNG: VÒNG ĐIỀU KHIỂN VỊ TRÍ
 * ========================================================================= */
static void *thread_position_control(void *arg)
{
    (void)arg;

    if (set_realtime(RTPRIO_POSCTRL, CPU_POSCTRL) != 0) return NULL;
    prefault_stack();

    struct timespec next;
    clock_gettime(CLOCK_MONOTONIC, &next);
    float t_elapsed = 0.0f;

    while (atomic_load(&g_running)) {
        timespec_add_ns(&next, PERIOD_POSCTRL_NS);

        /* TIMER_ABSTIME là mấu chốt: ngủ đến MỘT MỐC TUYỆT ĐỐI, không phải
         * "ngủ thêm 1 ms". Cách tương đối tích luỹ sai số trôi vì thời gian
         * xử lý cộng dồn vào mỗi chu kỳ. Đây đúng là ý tưởng của
         * vTaskDelayUntil (FreeRTOS) và K_TIMEOUT_ABS_TICKS (Zephyr). */
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL);

        /* Đo độ trễ đánh thức: chênh giữa lúc ĐÁNG LẼ dậy và lúc THỰC SỰ
         * dậy. Đây chính là đại lượng cyclictest đo. */
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        const long lat_ns = timespec_diff_ns(&now, &next);
        if (lat_ns > g_lat_max_ns) g_lat_max_ns = lat_ns;
        {
            long us = lat_ns / 1000;
            if (us < 0) us = 0;
            g_hist[(us > HIST_BINS) ? HIST_BINS : us]++;
        }

        /* ---- Phần điều khiển: giống hệt hai bản RTOS kia ---- */
        const float pos = hal_encoder_read_position();
        atomic_store(&g_pos_measured, pos);

        float t_start = 0.0f;
        const traj_profile_t *prof = traj_slot_get(&g_slot, &t_start);

        traj_state_t sp;
        shaper_eval(&g_shaper, prof, t_elapsed - t_start, &sp);

        const float u = pid_step(&g_pid, &sp, pos);
        atomic_store(&g_pos_error, sp.pos - pos);

        g_safety.estop_active     = hal_read_safety_relay_aux();
        g_safety.drive_sto_active = hal_read_drive_sto_status();

        if (!safety_mirror_update(&g_safety, sp.pos - pos)) {
            hal_drive_set_velocity(0.0f);
        } else {
            hal_drive_set_velocity(u);
        }

        t_elapsed += 0.001f;
    }
    return NULL;
}

/* =========================================================================
 *  5. LUỒNG: SINH QUỸ ĐẠO — 10 ms
 * ========================================================================= */
static void *thread_trajectory(void *arg)
{
    (void)arg;

    if (set_realtime(RTPRIO_TRAJ, -1) != 0) return NULL;
    prefault_stack();

    struct timespec next;
    clock_gettime(CLOCK_MONOTONIC, &next);
    float t_now = 0.0f;

    while (atomic_load(&g_running)) {
        timespec_add_ns(&next, PERIOD_TRAJ_NS);
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL);
        t_now += 0.010f;

        int expected = 1;
        if (!atomic_compare_exchange_strong(&g_new_target, &expected, 0)) {
            continue;
        }

        shaper_init(&g_shaper, SHAPER_ZVD, 1.2f, 0.02f);

        traj_profile_t prof;
        const float p0 = atomic_load(&g_pos_measured);
        const float p1 = atomic_load(&g_target_pos);
        if (traj_plan(&prof, p0, p1, &g_limits)) {
            traj_slot_publish(&g_slot, &prof, t_now);
            g_safety.state = MACHINE_EXECUTE;
        }
    }
    return NULL;
}

/* =========================================================================
 *  6. BÁO CÁO ĐỘ TRỄ
 * ========================================================================= */
static void print_latency_report(void)
{
    unsigned long total = 0;
    for (int i = 0; i <= HIST_BINS; ++i) total += g_hist[i];
    if (total == 0) { printf("Chua co so lieu.\n"); return; }

    unsigned long acc = 0;
    long p50 = -1, p99 = -1, p999 = -1;
    for (int i = 0; i <= HIST_BINS; ++i) {
        acc += g_hist[i];
        if (p50  < 0 && acc * 1000UL >= total * 500UL)  p50  = i;
        if (p99  < 0 && acc * 1000UL >= total * 990UL)  p99  = i;
        if (p999 < 0 && acc * 1000UL >= total * 999UL)  p999 = i;
    }

    printf("\n=== PHAN BO DO TRE DANH THUC (%lu mau) ===\n", total);
    printf("  p50   = %ld us\n", p50);
    printf("  p99   = %ld us\n", p99);
    printf("  p99.9 = %ld us\n", p999);
    printf("  max   = %.1f us\n", (double)g_lat_max_ns / 1000.0);
    printf("\n  Chu ky 1000 us  =>  jitter dinh chiem %.1f%% chu ky\n",
           (double)g_lat_max_ns / 1000.0 / 1000.0 * 100.0);
    if ((double)g_lat_max_ns / 1000.0 > 50.0) {
        printf("  ⚠ Vuot 5%% chu ky. Xem lai muc \"KHUYEN NGHI THANG THAN\"\n"
               "    o dau file: may nay nen chay tang L2, khong nen chay\n"
               "    vong vi tri 1 kHz.\n");
    }
}

static void on_sigint(int s) { (void)s; atomic_store(&g_running, 0); }

/* =========================================================================
 *  7. main()
 * ========================================================================= */
int main(void)
{
    signal(SIGINT, on_sigint);

    if (lock_memory() != 0) {
        fprintf(stderr, "Khong khoa duoc bo nho — moi so lieu do se vo nghia.\n");
        return 1;
    }

    pid_init(&g_pid, 20.0f, 5.0f, 0.0f, 0.001f, -1.2f, 1.2f);
    g_pid.k_vff = 1.0f;
    shaper_init(&g_shaper, SHAPER_NONE, 0.0f, 0.0f);
    safety_mirror_init(&g_safety, 0.010f);

    traj_profile_t idle;
    traj_plan(&idle, 0.0f, 0.0f, &g_limits);
    traj_slot_publish(&g_slot, &idle, 0.0f);

    pthread_t t_ctrl, t_traj;
    pthread_create(&t_ctrl, NULL, thread_position_control, NULL);
    pthread_create(&t_traj, NULL, thread_trajectory, NULL);

    printf("Dang chay. Nhan Ctrl-C de dung va xem bao cao do tre.\n");

    pthread_join(t_ctrl, NULL);
    pthread_join(t_traj, NULL);

    hal_drive_set_velocity(0.0f);
    print_latency_report();
    return 0;
}

void app_set_target(float pos_m)
{
    atomic_store(&g_target_pos, pos_m);
    atomic_store(&g_new_target, 1);
}
