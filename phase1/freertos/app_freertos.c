/* =========================================================================
 *  app_freertos.c — Adapter FreeRTOS cho giai đoạn 1 (STM32F7 + servo)
 * =========================================================================
 *
 *  Adapter này KHÔNG chứa thuật toán điều khiển. Toàn bộ toán nằm trong
 *  common/control_core.c đã được kiểm thử trên host (58/58 đạt).
 *  Việc của file này chỉ là: gọi đúng hàm, đúng lúc, đúng thứ tự ưu tiên.
 *
 *  Tập task và phân tích lịch biểu: xem mục 4.2–4.3 tài liệu
 *  integrate/iZiiApp_Thiet_Ke_He_Dieu_Khien_RealTime.md
 *      Tổng U = 0,670 < cận Liu&Layland 0,7286  ⇒ khả lịch
 *      R(vòng vị trí) = 380 µs < deadline 1000 µs
 *
 *  ⚠ AN TOÀN: file này KHÔNG triển khai chức năng an toàn nào. Chuỗi an
 *    toàn là phần cứng Category 3 độc lập (rơ-le an toàn → STO trên drive).
 *    Xem integrate/iZiiApp_GiaiDoan1_MachAnToan_Cat3.md.
 * ========================================================================= */

#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "control_core.h"

/* HAL của bạn — thay bằng header thực tế */
extern float    hal_encoder_read_position(void);   /* [m]  */
extern void     hal_drive_set_velocity(float v);   /* [m/s] */
extern bool     hal_read_safety_relay_aux(void);   /* tiếp điểm 41/42 */
extern bool     hal_read_drive_sto_status(void);
extern void     hal_dbg_pin_set(int pin, bool on);
extern uint32_t hal_ethercat_exchange(void);

/* =========================================================================
 *  1. ƯU TIÊN — GÁN THEO RATE MONOTONIC (chu kỳ ngắn ⇒ ưu tiên cao)
 * =========================================================================
 *  Quy tắc: KHÔNG BAO GIỜ gán ưu tiên theo "cảm giác quan trọng". Gán theo
 *  chu kỳ. Task "an toàn" nghe có vẻ quan trọng nhất nhưng chu kỳ 5 ms nên
 *  nó phải nằm DƯỚI vòng vị trí 1 ms — nếu không, phân tích lịch biểu ở
 *  mục 4.3 không còn giá trị và deadline có thể trượt.
 *
 *  (Đây là lý do chuỗi an toàn thật phải nằm ở phần cứng: nó không phải
 *  cạnh tranh CPU với bất cứ thứ gì.)
 * ========================================================================= */
#define PRIO_ETHERCAT   (configMAX_PRIORITIES - 1)   /* T = 1 ms   */
#define PRIO_POSCTRL    (configMAX_PRIORITIES - 2)   /* T = 1 ms   */
#define PRIO_SAFETY     (configMAX_PRIORITIES - 3)   /* T = 5 ms   */
#define PRIO_TRAJ       (configMAX_PRIORITIES - 4)   /* T = 10 ms  */
#define PRIO_COMM       (configMAX_PRIORITIES - 5)   /* T = 50 ms  */
#define PRIO_DIAG       (configMAX_PRIORITIES - 6)   /* T = 100 ms */

#define PERIOD_POSCTRL_MS   1
#define PERIOD_SAFETY_MS    5
#define PERIOD_TRAJ_MS      10
#define PERIOD_COMM_MS      50
#define PERIOD_DIAG_MS      100

#define TS_POSCTRL          0.001f      /* giây */

/* Chân gỡ lỗi để soi bằng oscilloscope — xem mục 4.7 */
#define DBG_PIN_POSCTRL     0
#define DBG_PIN_TRAJ        1

/* =========================================================================
 *  2. ĐO WCET BẰNG BỘ ĐẾM CHU KỲ DWT (Cortex-M)
 * =========================================================================
 *  Không xâm lấn, chính xác đến từng chu kỳ. Bật một lần lúc khởi động.
 *  Dùng cùng với toggle GPIO: DWT cho con số, oscilloscope cho jitter.
 * ========================================================================= */
#define DWT_CTRL    (*(volatile uint32_t *)0xE0001000UL)
#define DWT_CYCCNT  (*(volatile uint32_t *)0xE0001004UL)
#define DEMCR       (*(volatile uint32_t *)0xE000EDFCUL)

static inline void dwt_enable(void)
{
    DEMCR    |= (1UL << 24);   /* TRCENA */
    DWT_CYCCNT = 0;
    DWT_CTRL |= 1UL;           /* CYCCNTENA */
}
static inline uint32_t dwt_now(void) { return DWT_CYCCNT; }

typedef struct {
    uint32_t last, max, sum;
    uint32_t count;
} wcet_stat_t;

static inline void wcet_update(wcet_stat_t *s, uint32_t cycles)
{
    s->last = cycles;
    if (cycles > s->max) s->max = cycles;
    s->sum += cycles;
    s->count++;
}

/* =========================================================================
 *  3. TRẠNG THÁI TOÀN CỤC
 * ========================================================================= */
static traj_slot_t     g_traj_slot;     /* đệm đôi không khoá */
static pid_t           g_pid;
static shaper_t        g_shaper;
static safety_mirror_t g_safety;
static traj_limits_t   g_limits = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };

static volatile float  g_pos_measured;
static volatile float  g_pos_error;
static volatile float  g_target_pos;
static volatile bool   g_new_target;

static wcet_stat_t     g_wcet_posctrl, g_wcet_traj;

/* Cấp phát TĨNH toàn bộ — không malloc ở bất cứ đâu.
 * Heap động trên hệ điều khiển là nguồn lỗi không xác định thời gian. */
#define STACK_POSCTRL   512
#define STACK_SAFETY    384
#define STACK_TRAJ      768
#define STACK_COMM      512
#define STACK_DIAG      512

static StackType_t  st_posctrl[STACK_POSCTRL];
static StaticTask_t tcb_posctrl;
static StackType_t  st_safety[STACK_SAFETY];
static StaticTask_t tcb_safety;
static StackType_t  st_traj[STACK_TRAJ];
static StaticTask_t tcb_traj;
static StackType_t  st_diag[STACK_DIAG];
static StaticTask_t tcb_diag;

/* =========================================================================
 *  4. TASK: VÒNG ĐIỀU KHIỂN VỊ TRÍ — 1 ms, HARD REAL-TIME
 * =========================================================================
 *  Đây là task quan trọng nhất về mặt thời gian. Quy tắc trong hàm này:
 *    - Không malloc, không printf, không lấy mutex có thể bị giữ lâu
 *    - Không vòng lặp có số bước phụ thuộc dữ liệu
 *    - Dùng vTaskDelayUntil (KHÔNG dùng vTaskDelay) để chu kỳ không trôi
 * ========================================================================= */
static void task_position_control(void *arg)
{
    (void)arg;
    TickType_t wake = xTaskGetTickCount();
    float t_elapsed = 0.0f;

    for (;;) {
        vTaskDelayUntil(&wake, pdMS_TO_TICKS(PERIOD_POSCTRL_MS));

        hal_dbg_pin_set(DBG_PIN_POSCTRL, true);      /* ── bắt đầu đo ── */
        const uint32_t c0 = dwt_now();

        const float pos = hal_encoder_read_position();
        g_pos_measured = pos;

        /* Đọc hồ sơ quỹ đạo — KHÔNG CHẶN, không mutex.
         * Task quỹ đạo (10 ms) có thể đang ghi đệm còn lại; ta luôn đọc
         * được một hồ sơ nhất quán. Xem mục 4 control_core.h. */
        float t_start = 0.0f;
        const traj_profile_t *prof = traj_slot_get(&g_traj_slot, &t_start);

        traj_state_t sp;
        shaper_eval(&g_shaper, prof, t_elapsed - t_start, &sp);

        const float u = pid_step(&g_pid, &sp, pos);
        g_pos_error = sp.pos - pos;

        /* Bản sao mềm chỉ có quyền DỪNG, không có quyền CHO PHÉP. */
        if (g_safety.state == MACHINE_ABORTED) {
            hal_drive_set_velocity(0.0f);
        } else {
            hal_drive_set_velocity(u);
        }

        t_elapsed += TS_POSCTRL;

        wcet_update(&g_wcet_posctrl, dwt_now() - c0);
        hal_dbg_pin_set(DBG_PIN_POSCTRL, false);     /* ── kết thúc đo ── */
    }
}

/* =========================================================================
 *  5. TASK: GIÁM SÁT AN TOÀN (BẢN SAO MỀM) — 5 ms
 * =========================================================================
 *  ⚠ Nhắc lại: đây KHÔNG phải chức năng an toàn. Nó chỉ đọc trạng thái từ
 *    chuỗi phần cứng để hiển thị và dừng mềm. Rút nguồn con chip này thì
 *    E-Stop vẫn phải dừng được máy — đó là phép thử số 9 và 10 ở mục 7
 *    tài liệu mạch an toàn.
 * ========================================================================= */
static void task_safety_monitor(void *arg)
{
    (void)arg;
    TickType_t wake = xTaskGetTickCount();

    for (;;) {
        vTaskDelayUntil(&wake, pdMS_TO_TICKS(PERIOD_SAFETY_MS));

        g_safety.estop_active     = hal_read_safety_relay_aux();
        g_safety.drive_sto_active = hal_read_drive_sto_status();

        if (!safety_mirror_update(&g_safety, g_pos_error)) {
            hal_drive_set_velocity(0.0f);
            pid_reset(&g_pid);
        }
    }
}

/* =========================================================================
 *  6. TASK: SINH QUỸ ĐẠO — 10 ms
 * =========================================================================
 *  Đây là nơi ĐƯỢC PHÉP tính toán nặng (bisection trong traj_plan). Nó
 *  không nằm trong vòng 1 ms, và phân tích RTA ở mục 4.3 đã tính đến:
 *      R = 2400 µs < deadline 10000 µs
 * ========================================================================= */
static void task_trajectory(void *arg)
{
    (void)arg;
    TickType_t wake = xTaskGetTickCount();
    float t_now = 0.0f;

    for (;;) {
        vTaskDelayUntil(&wake, pdMS_TO_TICKS(PERIOD_TRAJ_MS));
        t_now += (float)PERIOD_TRAJ_MS * 0.001f;

        if (!g_new_target) continue;
        g_new_target = false;

        hal_dbg_pin_set(DBG_PIN_TRAJ, true);
        const uint32_t c0 = dwt_now();

        /* Cập nhật bộ tạo dạng theo chiều cao khung nâng.
         * Giai đoạn 1 (trục ngang) dùng hằng số. Sang giai đoạn 2, thay
         * bằng tra bảng f_n(chiều cao) đã đo bằng gia tốc kế — xem mục 5.3
         * tài liệu thiết kế. */
        shaper_init(&g_shaper, SHAPER_ZVD, /*f_n*/ 1.2f, /*zeta*/ 0.02f);

        traj_profile_t prof;
        if (traj_plan(&prof, g_pos_measured, g_target_pos, &g_limits)) {
            traj_slot_publish(&g_traj_slot, &prof, t_now);
            g_safety.state = MACHINE_EXECUTE;
        }

        wcet_update(&g_wcet_traj, dwt_now() - c0);
        hal_dbg_pin_set(DBG_PIN_TRAJ, false);
    }
}

/* =========================================================================
 *  7. TASK: CHẨN ĐOÁN — 100 ms
 * =========================================================================
 *  Theo dõi mức dùng stack và WCET thực đo. KHÔNG dùng printf ở đây —
 *  đẩy vào ring buffer, để tầng truyền thông gửi đi.
 * ========================================================================= */
typedef struct {
    uint32_t wcet_posctrl_max_cycles;
    uint32_t wcet_traj_max_cycles;
    uint16_t stack_free_posctrl;
    uint16_t stack_free_safety;
    uint16_t stack_free_traj;
    uint32_t safety_fault_count;
} diag_snapshot_t;

static volatile diag_snapshot_t g_diag;

static void task_diagnostics(void *arg)
{
    TaskHandle_t *handles = (TaskHandle_t *)arg;
    TickType_t wake = xTaskGetTickCount();

    for (;;) {
        vTaskDelayUntil(&wake, pdMS_TO_TICKS(PERIOD_DIAG_MS));

        g_diag.wcet_posctrl_max_cycles = g_wcet_posctrl.max;
        g_diag.wcet_traj_max_cycles    = g_wcet_traj.max;
        g_diag.safety_fault_count      = g_safety.fault_count;

        /* High water mark = số WORD stack còn CHƯA từng dùng.
         * Tiến gần 0 nghĩa là sắp tràn — tràn stack trên hệ điều khiển
         * biểu hiện thành lỗi ngẫu nhiên rất khó truy. Theo dõi ngay từ
         * ngày đầu, đừng đợi đến lúc gặp sự cố. */
        g_diag.stack_free_posctrl = (uint16_t)uxTaskGetStackHighWaterMark(handles[0]);
        g_diag.stack_free_safety  = (uint16_t)uxTaskGetStackHighWaterMark(handles[1]);
        g_diag.stack_free_traj    = (uint16_t)uxTaskGetStackHighWaterMark(handles[2]);
    }
}

/* =========================================================================
 *  8. KHỞI TẠO
 * ========================================================================= */
static TaskHandle_t g_handles[3];

void app_init(void)
{
    dwt_enable();

    pid_init(&g_pid, /*kp*/ 20.0f, /*ki*/ 5.0f, /*kd*/ 0.0f,
             TS_POSCTRL, /*out_min*/ -1.2f, /*out_max*/ 1.2f);
    g_pid.k_vff = 1.0f;    /* feedforward vận tốc — giảm sai số bám ~1000× */
    g_pid.k_aff = 0.0f;    /* bật sau khi đã nhận dạng quán tính           */

    shaper_init(&g_shaper, SHAPER_NONE, 0.0f, 0.0f);
    safety_mirror_init(&g_safety, /*ngưỡng sai số bám*/ 0.010f);

    /* Hồ sơ rỗng ban đầu: giữ nguyên vị trí, không chuyển động */
    traj_profile_t idle;
    traj_plan(&idle, 0.0f, 0.0f, &g_limits);
    traj_slot_publish(&g_traj_slot, &idle, 0.0f);

    g_handles[0] = xTaskCreateStatic(task_position_control, "posctrl",
                                     STACK_POSCTRL, NULL, PRIO_POSCTRL,
                                     st_posctrl, &tcb_posctrl);
    g_handles[1] = xTaskCreateStatic(task_safety_monitor, "safety",
                                     STACK_SAFETY, NULL, PRIO_SAFETY,
                                     st_safety, &tcb_safety);
    g_handles[2] = xTaskCreateStatic(task_trajectory, "traj",
                                     STACK_TRAJ, NULL, PRIO_TRAJ,
                                     st_traj, &tcb_traj);
    xTaskCreateStatic(task_diagnostics, "diag", STACK_DIAG, g_handles,
                      PRIO_DIAG, st_diag, &tcb_diag);

    vTaskStartScheduler();     /* không trở về */
}

/* API cho tầng truyền thông gọi khi nhận lệnh mới từ WCS */
void app_set_target(float pos_m)
{
    g_target_pos = pos_m;
    g_new_target = true;
}

/* =========================================================================
 *  9. BẮT LỖI CỦA FreeRTOS — ĐỪNG ĐỂ TRỐNG
 * =========================================================================
 *  Hai hàm này mặc định thường bị bỏ rỗng. Trên hệ điều khiển đó là sai
 *  lầm: chúng là tín hiệu sớm duy nhất cho hai lỗi chết người.
 * ========================================================================= */
void vApplicationStackOverflowHook(TaskHandle_t task, char *name)
{
    (void)task; (void)name;
    hal_drive_set_velocity(0.0f);     /* ưu tiên số một: dừng cơ cấu */
    taskDISABLE_INTERRUPTS();
    for (;;) { }                      /* để watchdog reset và ghi nhận */
}

void vApplicationMallocFailedHook(void)
{
    hal_drive_set_velocity(0.0f);
    taskDISABLE_INTERRUPTS();
    for (;;) { }
}
