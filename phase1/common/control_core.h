/* =========================================================================
 *  control_core.h — Lõi điều khiển chuyển động, ĐỘC LẬP HOÀN TOÀN VỚI RTOS
 * =========================================================================
 *
 *  NGUYÊN TẮC THIẾT KẾ QUAN TRỌNG NHẤT CỦA FILE NÀY:
 *
 *    File này KHÔNG include bất cứ header nào của FreeRTOS / Zephyr / Linux.
 *    Không có mutex, không có sleep, không có malloc, không có printf.
 *    Chỉ có toán học thuần tuý và trạng thái tường minh.
 *
 *  VÌ SAO:
 *    1. Test được trên máy tính (xem test/test_control_core.c) — bắt lỗi
 *       thuật toán trước khi nạp lên phần cứng, nơi gỡ lỗi đắt gấp mười lần.
 *    2. Hoán đổi RTOS mà không viết lại thuật toán. Ba adapter trong repo
 *       này (FreeRTOS / Zephyr / Linux RT) gọi chung đúng các hàm dưới đây.
 *    3. WCET chặn được: không vòng lặp nào phụ thuộc dữ liệu đầu vào trong
 *       đường chạy 1 kHz. Phần bisection tốn kém chỉ chạy MỘT LẦN mỗi lệnh
 *       di chuyển, ở task ưu tiên thấp — không nằm trong vòng điều khiển.
 *
 *  Đơn vị dùng thống nhất toàn bộ: mét, giây, m/s, m/s², m/s³.
 * ========================================================================= */

#ifndef CONTROL_CORE_H
#define CONTROL_CORE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------------
 *  1. BỘ TẠO QUỸ ĐẠO S-CURVE 7 ĐOẠN
 * ------------------------------------------------------------------ */

typedef struct {
    float v_max;   /* vận tốc tối đa            [m/s]   */
    float a_max;   /* gia tốc tối đa            [m/s²]  */
    float j_max;   /* jerk tối đa — THAM SỐ CHỐNG RUNG  [m/s³] */
} traj_limits_t;

/* Hồ sơ quỹ đạo đã tính sẵn. Tính MỘT LẦN khi nhận lệnh, sau đó chỉ
 * đánh giá (evaluate) ở mỗi chu kỳ điều khiển — đánh giá là O(1). */
typedef struct {
    float p0;        /* vị trí xuất phát        */
    float dir;       /* +1 hoặc -1              */
    float j;         /* jerk dùng thực tế       */
    float a_peak;    /* gia tốc đỉnh đạt được   */
    float v_peak;    /* vận tốc đỉnh đạt được   */
    float Tj;        /* thời lượng đoạn jerk    */
    float Ta;        /* thời lượng đoạn gia tốc không đổi */
    float Tv;        /* thời lượng đoạn vận tốc không đổi */
    float T_total;   /* tổng thời gian          */
    float p_end;     /* quãng đường tương đối cuối cùng (luôn ≥ 0) */
    /* Giá trị chốt tại biên các đoạn — tính trước để đánh giá O(1) */
    float p_s[7], v_s[7], a_s[7], t_s[8];
    bool  valid;
} traj_profile_t;

/* Trạng thái tức thời của quỹ đạo tại một thời điểm. */
typedef struct {
    float pos;   /* [m]     */
    float vel;   /* [m/s]   */
    float acc;   /* [m/s²]  */
} traj_state_t;

/**
 * Lập hồ sơ quỹ đạo điểm-tới-điểm, xuất phát và kết thúc ở trạng thái nghỉ.
 *
 * CHI PHÍ: có bisection ~40 vòng lặp. KHÔNG gọi hàm này trong vòng 1 kHz.
 *          Gọi ở task sinh quỹ đạo (10 ms) hoặc khi nhận lệnh mới.
 *
 * @return true nếu lập được hồ sơ hợp lệ.
 */
bool traj_plan(traj_profile_t *prof, float p_start, float p_end,
               const traj_limits_t *lim);

/**
 * Đánh giá quỹ đạo tại thời điểm t (giây, tính từ lúc bắt đầu di chuyển).
 * O(1), không vòng lặp phụ thuộc dữ liệu — an toàn cho vòng điều khiển.
 * t < 0 trả về trạng thái đầu; t > T_total trả về trạng thái cuối (đứng yên).
 */
void traj_eval(const traj_profile_t *prof, float t, traj_state_t *out);

/* ---------------------------------------------------------------------
 *  2. BỘ TẠO DẠNG ĐẦU VÀO (INPUT SHAPING) — CHỐNG LẮC CỘT
 * ------------------------------------------------------------------
 *  Triển khai ZV và ZVD theo mục 5.3 của tài liệu thiết kế.
 *
 *  Vì traj_eval() là hàm giải tích theo t, việc tạo dạng trở nên rất gọn:
 *  chỉ là tổ hợp tuyến tính của cùng một hồ sơ tại các thời điểm trễ khác
 *  nhau. Không cần bộ đệm vòng, không cần cấp phát.
 *
 *      y(t) = Σ Aᵢ · profile(t − tᵢ)
 *
 *  LƯU Ý: tần số riêng của cột AS/RS THAY ĐỔI theo chiều cao khung nâng.
 *  Gọi lại shaper_init() mỗi khi lập quỹ đạo mới, với f_n tra từ bảng đã
 *  đo bằng gia tốc kế. Xem mục 5.3 tài liệu thiết kế.
 * ------------------------------------------------------------------ */

typedef enum {
    SHAPER_NONE = 0,
    SHAPER_ZV   = 1,   /* 2 xung — nhanh hơn, nhạy với sai số tần số  */
    SHAPER_ZVD  = 2    /* 3 xung — bền hơn, KHUYẾN NGHỊ cho AS/RS     */
} shaper_type_t;

typedef struct {
    shaper_type_t type;
    int   n;           /* số xung: 0, 2 hoặc 3 */
    float A[3];        /* biên độ, tổng = 1    */
    float t[3];        /* thời điểm trễ [s]    */
    float extra_time;  /* thời gian cộng thêm vào chuyển động [s] */
} shaper_t;

/**
 * Khởi tạo bộ tạo dạng.
 * @param f_n  tần số riêng [Hz] — PHẢI ĐO, không suy đoán
 * @param zeta hệ số tắt dần (điển hình 0,01–0,05)
 */
void shaper_init(shaper_t *s, shaper_type_t type, float f_n, float zeta);

/** Đánh giá quỹ đạo ĐÃ TẠO DẠNG tại thời điểm t. O(1). */
void shaper_eval(const shaper_t *s, const traj_profile_t *prof,
                 float t, traj_state_t *out);

/* ---------------------------------------------------------------------
 *  3. PID DẠNG VI PHÂN (VELOCITY FORM) + FEEDFORWARD
 * ------------------------------------------------------------------
 *  Dạng vi phân tự chống bão hoà tích phân (anti-windup) vì đầu ra tích
 *  luỹ bị kẹp TRƯỚC khi làm cơ sở cho bước kế tiếp.
 *  Xem mục 5.4 tài liệu thiết kế.
 * ------------------------------------------------------------------ */

typedef struct {
    float kp, ki, kd;
    float k_vff;      /* hệ số feedforward vận tốc — xem mục 5.5 */
    float k_aff;      /* hệ số feedforward gia tốc               */
    float ts;         /* chu kỳ lấy mẫu [s]                      */
    float out_min, out_max;
    /* trạng thái */
    float e1, e2;     /* e(k-1), e(k-2) */
    float u_fb;       /* phần phản hồi đã tích luỹ */
    bool  saturated;  /* cờ chẩn đoán */
} pid_t;

void  pid_init(pid_t *p, float kp, float ki, float kd, float ts,
               float out_min, float out_max);
void  pid_reset(pid_t *p);

/**
 * Một bước điều khiển. Gọi ĐÚNG mỗi ts giây.
 * @param sp  trạng thái đặt (từ quỹ đạo, đã tạo dạng)
 * @param pv  vị trí đo được [m]
 * @return    lệnh gửi xuống drive (vận tốc [m/s] hoặc mô-men, tuỳ cấu hình)
 */
float pid_step(pid_t *p, const traj_state_t *sp, float pv);

/* ---------------------------------------------------------------------
 *  4. TRAO ĐỔI DỮ LIỆU KHÔNG KHOÁ (LOCK-FREE) GIỮA CÁC TASK
 * ------------------------------------------------------------------
 *  BÀI TOÁN: task sinh quỹ đạo (10 ms) ghi hồ sơ mới; vòng điều khiển
 *  (1 ms) đọc nó. Dùng mutex thì vòng 1 ms có thể bị chặn — không chấp
 *  nhận được với ràng buộc hard real-time.
 *
 *  GIẢI PHÁP: đệm đôi + chỉ số nguyên tử. Người ghi điền vào đệm rảnh rồi
 *  đổi chỉ số bằng một phép ghi nguyên tử duy nhất. Người đọc không bao
 *  giờ chờ và không bao giờ thấy hồ sơ ghi dở.
 *
 *  Đây là một seqlock đơn giản hoá cho trường hợp MỘT người ghi, MỘT
 *  người đọc — mô hình đúng của bài toán này.
 * ------------------------------------------------------------------ */

typedef struct {
    traj_profile_t buf[2];
    float          t_start[2];   /* mốc thời gian bắt đầu mỗi hồ sơ */
    volatile uint32_t active;    /* 0 hoặc 1 — chỉ số đệm đang dùng */
} traj_slot_t;

/** Người GHI (task quỹ đạo, ưu tiên thấp) — công bố hồ sơ mới. */
void traj_slot_publish(traj_slot_t *slot, const traj_profile_t *prof,
                       float t_start);

/** Người ĐỌC (vòng điều khiển 1 kHz) — lấy hồ sơ hiện hành. Không chặn. */
const traj_profile_t *traj_slot_get(const traj_slot_t *slot, float *t_start);

/* ---------------------------------------------------------------------
 *  5. BẢN SAO MỀM CỦA TRẠNG THÁI AN TOÀN
 * ------------------------------------------------------------------
 *  ⚠️ ĐỌC KỸ: đây KHÔNG PHẢI chức năng an toàn.
 *
 *  Chức năng an toàn thật nằm ở mạch phần cứng Category 3 (rơ-le an toàn
 *  → STO trên drive), hoàn toàn độc lập với con chip này. Xem tài liệu
 *  integrate/iZiiApp_GiaiDoan1_MachAnToan_Cat3.md.
 *
 *  Khối này chỉ để: (a) hiển thị trạng thái cho người vận hành, (b) dừng
 *  chuyển động một cách MỀM trước khi phần cứng phải can thiệp thô bạo,
 *  (c) ghi log phục vụ chẩn đoán.
 *
 *  Nếu bạn thấy mình đang viết logic cho phép chuyển động dựa trên khối
 *  này, dừng lại — kiến trúc đã sai.
 * ------------------------------------------------------------------ */

typedef enum {
    MACHINE_STOPPED = 0,
    MACHINE_IDLE,
    MACHINE_EXECUTE,
    MACHINE_HOLDING,
    MACHINE_ABORTED
} machine_state_t;

typedef struct {
    machine_state_t state;
    bool  estop_active;        /* đọc từ tiếp điểm phụ 41/42 của rơ-le */
    bool  drive_sto_active;    /* phản hồi trạng thái STO từ drive     */
    bool  limit_pos, limit_neg;
    bool  following_error;     /* sai số bám vượt ngưỡng */
    float following_error_max; /* ngưỡng [m] */
    uint32_t fault_count;
} safety_mirror_t;

void safety_mirror_init(safety_mirror_t *s, float follow_err_max);

/**
 * Cập nhật bản sao trạng thái. Gọi mỗi 5 ms.
 * @return true nếu ĐƯỢC PHÉP tiếp tục chuyển động (theo góc nhìn phần mềm).
 *         Giá trị false PHẢI làm dừng chuyển động; giá trị true KHÔNG
 *         phải là sự cho phép — phần cứng mới là nơi cho phép.
 */
bool safety_mirror_update(safety_mirror_t *s, float pos_error);

#ifdef __cplusplus
}
#endif
#endif /* CONTROL_CORE_H */
