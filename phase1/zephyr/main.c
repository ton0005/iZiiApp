/* =========================================================================
 *  main.c — Adapter Zephyr RTOS cho giai đoạn 1
 * =========================================================================
 *
 *  CÙNG control_core.c với bản FreeRTOS. Chỉ lớp vỏ RTOS khác.
 *  Đó chính là lợi ích của việc tách lõi điều khiển ra khỏi RTOS.
 *
 *  BỐN KHÁC BIỆT SO VỚI FreeRTOS — DỄ SAI NẾU CHUYỂN ĐỔI VỘI:
 *
 *   1. ƯU TIÊN NGƯỢC CHIỀU. Zephyr: SỐ NHỎ = ƯU TIÊN CAO.
 *      FreeRTOS thì ngược lại. Đây là lỗi số một khi port qua lại, và nó
 *      không gây lỗi biên dịch — chỉ làm lịch biểu sai âm thầm.
 *
 *   2. Ưu tiên ÂM = luồng hợp tác (cooperative), không bị chiếm quyền.
 *      Dùng cho vòng điều khiển thì phải rất cẩn thận: một luồng hợp tác
 *      không nhả CPU sẽ treo cả hệ.
 *
 *   3. CONFIG_FPU_SHARING BẮT BUỘC BẬT khi nhiều luồng dùng số thực.
 *      Quên nó ⇒ trạng thái FPU bị hỏng khi chuyển ngữ cảnh ⇒ kết quả
 *      tính toán sai ngẫu nhiên, không hề báo lỗi. Xem prj.conf.
 *
 *   4. Tick mặc định 100 Hz — KHÔNG đủ cho vòng 1 kHz. Phải nâng
 *      CONFIG_SYS_CLOCK_TICKS_PER_SEC hoặc dùng k_timer như dưới đây.
 *
 *  ĐIỂM MẠNH LỚN NHẤT CỦA ZEPHYR CHO DỰ ÁN NÀY: đích `native_sim` cho
 *  phép biên dịch TOÀN BỘ ứng dụng chạy trên máy tính như một tiến trình
 *  Linux thường — kể cả logic luồng và timing. Xem README.md mục 4.
 * ========================================================================= */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/timing/timing.h>
#include <zephyr/logging/log.h>

#include "control_core.h"

LOG_MODULE_REGISTER(axis_ctrl, LOG_LEVEL_INF);

/* HAL — thay bằng driver thật qua devicetree */
extern float hal_encoder_read_position(void);
extern void  hal_drive_set_velocity(float v);
extern bool  hal_read_safety_relay_aux(void);
extern bool  hal_read_drive_sto_status(void);

/* =========================================================================
 *  1. ƯU TIÊN — NHỚ: SỐ NHỎ = ƯU TIÊN CAO (ngược FreeRTOS)
 * ========================================================================= */
#define PRIO_POSCTRL    1      /* T = 1 ms   — cao nhất trong các luồng */
#define PRIO_SAFETY     3      /* T = 5 ms   */
#define PRIO_TRAJ       5      /* T = 10 ms  */
#define PRIO_DIAG       9      /* T = 100 ms */

#define STACK_POSCTRL   2048
#define STACK_SAFETY    1536
#define STACK_TRAJ      3072
#define STACK_DIAG      2048

#define TS_POSCTRL      0.001f

K_THREAD_STACK_DEFINE(stack_posctrl, STACK_POSCTRL);
K_THREAD_STACK_DEFINE(stack_safety,  STACK_SAFETY);
K_THREAD_STACK_DEFINE(stack_traj,    STACK_TRAJ);
K_THREAD_STACK_DEFINE(stack_diag,    STACK_DIAG);

static struct k_thread th_posctrl, th_safety, th_traj, th_diag;

/* =========================================================================
 *  2. NHỊP 1 kHz BẰNG k_timer
 * =========================================================================
 *  k_timer chạy trong ngữ cảnh ngắt của bộ đếm phần cứng nên nhịp ổn định
 *  hơn nhiều so với k_sleep() tương đối — vốn tích luỹ sai số trôi.
 *
 *  Tương đương vTaskDelayUntil() của FreeRTOS, nhưng tách bạch hơn: timer
 *  phát semaphore, luồng chờ semaphore.
 * ========================================================================= */
static K_SEM_DEFINE(sem_tick_1khz, 0, 1);

static void tick_1khz_handler(struct k_timer *t)
{
    ARG_UNUSED(t);
    k_sem_give(&sem_tick_1khz);
}
K_TIMER_DEFINE(timer_1khz, tick_1khz_handler, NULL);

/* =========================================================================
 *  3. TRẠNG THÁI DÙNG CHUNG
 * ========================================================================= */
static traj_slot_t     g_slot;
static pid_t           g_pid;
static shaper_t        g_shaper;
static safety_mirror_t g_safety;
static traj_limits_t   g_limits = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };

static float  g_pos_measured, g_pos_error;
static float  g_target_pos;
static atomic_t g_new_target = ATOMIC_INIT(0);

static uint64_t g_wcet_posctrl_ns_max;
static uint64_t g_wcet_traj_ns_max;

/* =========================================================================
 *  4. LUỒNG: VÒNG ĐIỀU KHIỂN VỊ TRÍ — 1 ms
 * ========================================================================= */
static void thread_position_control(void *a, void *b, void *c)
{
    ARG_UNUSED(a); ARG_UNUSED(b); ARG_UNUSED(c);

    float t_elapsed = 0.0f;
    k_timer_start(&timer_1khz, K_MSEC(1), K_MSEC(1));

    for (;;) {
        k_sem_take(&sem_tick_1khz, K_FOREVER);

        const timing_t t0 = timing_counter_get();

        const float pos = hal_encoder_read_position();
        g_pos_measured = pos;

        float t_start = 0.0f;
        const traj_profile_t *prof = traj_slot_get(&g_slot, &t_start);

        traj_state_t sp;
        shaper_eval(&g_shaper, prof, t_elapsed - t_start, &sp);

        const float u = pid_step(&g_pid, &sp, pos);
        g_pos_error = sp.pos - pos;

        if (g_safety.state == MACHINE_ABORTED) {
            hal_drive_set_velocity(0.0f);
        } else {
            hal_drive_set_velocity(u);
        }

        t_elapsed += TS_POSCTRL;

        const timing_t t1 = timing_counter_get();
        const uint64_t ns = timing_cycles_to_ns(timing_cycles_get(&t0, &t1));
        if (ns > g_wcet_posctrl_ns_max) g_wcet_posctrl_ns_max = ns;
    }
}

/* =========================================================================
 *  5. LUỒNG: GIÁM SÁT AN TOÀN (BẢN SAO MỀM) — 5 ms
 *  ⚠ Không phải chức năng an toàn. Chuỗi an toàn là phần cứng Cat 3.
 * ========================================================================= */
static void thread_safety(void *a, void *b, void *c)
{
    ARG_UNUSED(a); ARG_UNUSED(b); ARG_UNUSED(c);

    /* Mốc tuyệt đối: nhịp không trôi dù xử lý mất bao lâu. */
    int64_t next = k_uptime_ticks();

    for (;;) {
        next += k_ms_to_ticks_ceil64(5);
        k_sleep(K_TIMEOUT_ABS_TICKS(next));

        g_safety.estop_active     = hal_read_safety_relay_aux();
        g_safety.drive_sto_active = hal_read_drive_sto_status();

        if (!safety_mirror_update(&g_safety, g_pos_error)) {
            hal_drive_set_velocity(0.0f);
            pid_reset(&g_pid);
        }
    }
}

/* =========================================================================
 *  6. LUỒNG: SINH QUỸ ĐẠO — 10 ms
 * ========================================================================= */
static void thread_trajectory(void *a, void *b, void *c)
{
    ARG_UNUSED(a); ARG_UNUSED(b); ARG_UNUSED(c);

    int64_t next = k_uptime_ticks();
    float t_now = 0.0f;

    for (;;) {
        next += k_ms_to_ticks_ceil64(10);
        k_sleep(K_TIMEOUT_ABS_TICKS(next));
        t_now += 0.010f;

        if (!atomic_cas(&g_new_target, 1, 0)) continue;

        const timing_t t0 = timing_counter_get();

        shaper_init(&g_shaper, SHAPER_ZVD, 1.2f, 0.02f);

        traj_profile_t prof;
        if (traj_plan(&prof, g_pos_measured, g_target_pos, &g_limits)) {
            traj_slot_publish(&g_slot, &prof, t_now);
            g_safety.state = MACHINE_EXECUTE;
        }

        const timing_t t1 = timing_counter_get();
        const uint64_t ns = timing_cycles_to_ns(timing_cycles_get(&t0, &t1));
        if (ns > g_wcet_traj_ns_max) g_wcet_traj_ns_max = ns;
    }
}

/* =========================================================================
 *  7. LUỒNG: CHẨN ĐOÁN — 100 ms
 * ========================================================================= */
static void thread_diagnostics(void *a, void *b, void *c)
{
    ARG_UNUSED(a); ARG_UNUSED(b); ARG_UNUSED(c);

    for (;;) {
        k_sleep(K_MSEC(100));

        LOG_INF("WCET posctrl=%llu ns  traj=%llu ns  loi_an_toan=%u",
                g_wcet_posctrl_ns_max, g_wcet_traj_ns_max,
                g_safety.fault_count);

        /* CONFIG_THREAD_ANALYZER_AUTO=y sẽ tự in mức dùng stack định kỳ,
         * tương đương uxTaskGetStackHighWaterMark của FreeRTOS. */
    }
}

/* =========================================================================
 *  8. main()
 * ========================================================================= */
int main(void)
{
    timing_init();
    timing_start();

    pid_init(&g_pid, 20.0f, 5.0f, 0.0f, TS_POSCTRL, -1.2f, 1.2f);
    g_pid.k_vff = 1.0f;

    shaper_init(&g_shaper, SHAPER_NONE, 0.0f, 0.0f);
    safety_mirror_init(&g_safety, 0.010f);

    traj_profile_t idle;
    traj_plan(&idle, 0.0f, 0.0f, &g_limits);
    traj_slot_publish(&g_slot, &idle, 0.0f);

    k_thread_create(&th_posctrl, stack_posctrl, STACK_POSCTRL,
                    thread_position_control, NULL, NULL, NULL,
                    PRIO_POSCTRL, 0, K_NO_WAIT);
    k_thread_name_set(&th_posctrl, "posctrl");

    k_thread_create(&th_safety, stack_safety, STACK_SAFETY,
                    thread_safety, NULL, NULL, NULL,
                    PRIO_SAFETY, 0, K_NO_WAIT);
    k_thread_name_set(&th_safety, "safety");

    k_thread_create(&th_traj, stack_traj, STACK_TRAJ,
                    thread_trajectory, NULL, NULL, NULL,
                    PRIO_TRAJ, 0, K_NO_WAIT);
    k_thread_name_set(&th_traj, "traj");

    k_thread_create(&th_diag, stack_diag, STACK_DIAG,
                    thread_diagnostics, NULL, NULL, NULL,
                    PRIO_DIAG, 0, K_NO_WAIT);
    k_thread_name_set(&th_diag, "diag");

    return 0;
}

void app_set_target(float pos_m)
{
    g_target_pos = pos_m;
    atomic_set(&g_new_target, 1);
}
