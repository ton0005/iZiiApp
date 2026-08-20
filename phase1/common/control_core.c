/* =========================================================================
 *  control_core.c — Triển khai lõi điều khiển, độc lập RTOS
 *  Xem control_core.h để biết nguyên tắc thiết kế.
 * ========================================================================= */

#include "control_core.h"
#include <math.h>
#include <string.h>

/* Rào cản bộ nhớ — cần cho mẫu đệm đôi không khoá ở mục 4.
 * Không có nó, trình biên dịch hoặc CPU có thể sắp xếp lại thứ tự ghi và
 * người đọc thấy chỉ số mới trỏ tới đệm chưa ghi xong. */
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L && !defined(__STDC_NO_ATOMICS__)
#  include <stdatomic.h>
#  define MEM_BARRIER() atomic_thread_fence(memory_order_seq_cst)
#elif defined(__GNUC__)
#  define MEM_BARRIER() __sync_synchronize()
#else
#  define MEM_BARRIER() do { } while (0)   /* ⚠ kiểm tra lại trên trình biên dịch của bạn */
#endif

#define EPS 1e-9f

/* Tự định nghĩa thay vì dùng M_PI: M_PI không thuộc chuẩn C (nó là phần mở
 * rộng POSIX). Biên dịch với -std=c11 nghiêm ngặt, hoặc trên nhiều toolchain
 * nhúng như arm-none-eabi newlib-nano, M_PI có thể không tồn tại. */
#define CC_PI 3.14159265358979323846f

/* =========================================================================
 *  1. QUỸ ĐẠO S-CURVE
 * ========================================================================= */

/* Quãng đường đi được khi tăng tốc từ 0 lên v, với giới hạn a_max/j.
 *
 * Hồ sơ gia tốc đối xứng quanh điểm giữa ⇒ vận tốc trung bình trong pha
 * tăng tốc đúng bằng v/2. Nhờ vậy quãng đường = v · T_acc / 2 (chính xác,
 * không xấp xỉ). */
static float accel_distance(float v, float a_max, float j,
                            float *out_Tj, float *out_Ta, float *out_apk)
{
    if (v <= EPS) {
        if (out_Tj)  *out_Tj  = 0.0f;
        if (out_Ta)  *out_Ta  = 0.0f;
        if (out_apk) *out_apk = 0.0f;
        return 0.0f;
    }

    /* Có đạt được a_max không? Trong hai pha jerk, vận tốc tăng a²/j.
     * Nếu lượng đó đã vượt v thì gia tốc đỉnh bị giới hạn bởi chính v. */
    float a_pk = a_max;
    if (a_max * a_max / j > v) {
        a_pk = sqrtf(v * j);      /* hồ sơ gia tốc hình tam giác */
    }

    const float Tj = a_pk / j;
    float Ta = (v - a_pk * a_pk / j) / a_pk;
    if (Ta < 0.0f) Ta = 0.0f;      /* chống sai số dấu phẩy động */

    const float T_acc = 2.0f * Tj + Ta;

    if (out_Tj)  *out_Tj  = Tj;
    if (out_Ta)  *out_Ta  = Ta;
    if (out_apk) *out_apk = a_pk;

    return v * T_acc * 0.5f;
}

/* Tính sẵn trạng thái tại biên 7 đoạn ⇒ traj_eval() thành O(1). */
static void build_segments(traj_profile_t *pr)
{
    const float Tj = pr->Tj, Ta = pr->Ta, Tv = pr->Tv, j = pr->j;

    const float dur[7] = { Tj, Ta, Tj, Tv, Tj, Ta, Tj };
    const float jrk[7] = { +j, 0.0f, -j, 0.0f, -j, 0.0f, +j };

    pr->t_s[0] = 0.0f;
    pr->p_s[0] = 0.0f;
    pr->v_s[0] = 0.0f;
    pr->a_s[0] = 0.0f;

    for (int i = 0; i < 7; ++i) {
        const float dt = dur[i], jj = jrk[i];
        const float p = pr->p_s[i], v = pr->v_s[i], a = pr->a_s[i];

        pr->t_s[i + 1] = pr->t_s[i] + dt;

        const float a_next = a + jj * dt;
        const float v_next = v + a * dt + 0.5f * jj * dt * dt;
        const float p_next = p + v * dt + 0.5f * a * dt * dt
                               + (1.0f / 6.0f) * jj * dt * dt * dt;

        if (i < 6) {
            pr->a_s[i + 1] = a_next;
            pr->v_s[i + 1] = v_next;
            pr->p_s[i + 1] = p_next;
        } else {
            /* Trạng thái cuối hành trình — lưu tường minh.
             *
             * ⚠ BÀI HỌC: bản đầu tiên tính trạng thái cuối bằng cách GỌI ĐỆ QUY
             * traj_eval(pr, T_total − 1e-7f, ...). Nghe hợp lý, nhưng với float
             * 32-bit, khi T_total đủ lớn thì (T_total − 1e-7f) LÀM TRÒN VỀ ĐÚNG
             * T_total ⇒ đệ quy vô hạn ⇒ tràn stack.
             *
             * Trên host, ASan chỉ ra ngay trong vài giây. Trên STM32 nó sẽ là
             * HardFault xuất hiện ngẫu nhiên tuỳ độ dài hành trình — loại lỗi
             * tốn nhiều ngày để truy ra. Đây chính là lý do lõi này được giữ
             * độc lập RTOS và test trên máy tính trước. */
            pr->p_end = p_next;
        }
    }
    pr->T_total = pr->t_s[7];
}

bool traj_plan(traj_profile_t *prof, float p_start, float p_end,
               const traj_limits_t *lim)
{
    if (!prof || !lim) return false;
    if (lim->v_max <= EPS || lim->a_max <= EPS || lim->j_max <= EPS) return false;

    memset(prof, 0, sizeof(*prof));

    const float D_signed = p_end - p_start;
    const float D = fabsf(D_signed);

    prof->p0  = p_start;
    prof->dir = (D_signed >= 0.0f) ? 1.0f : -1.0f;
    prof->j   = lim->j_max;

    if (D < EPS) {                 /* không phải di chuyển */
        prof->valid = true;
        build_segments(prof);
        return true;
    }

    float Tj, Ta, a_pk;
    float v_pk = lim->v_max;
    float d_acc = accel_distance(v_pk, lim->a_max, lim->j_max, &Tj, &Ta, &a_pk);

    if (2.0f * d_acc <= D) {
        /* Đạt được v_max, có đoạn chạy đều */
        prof->Tv = (D - 2.0f * d_acc) / v_pk;
    } else {
        /* Quãng đường quá ngắn: phải hạ vận tốc đỉnh.
         *
         * Dùng chia đôi thay vì giải kín. accel_distance() đơn điệu tăng
         * theo v nên chia đôi hội tụ chắc chắn. 60 vòng là thừa cho float.
         *
         * CHI PHÍ: chỉ chạy MỘT LẦN mỗi lệnh di chuyển, ở task 10 ms.
         * Không bao giờ nằm trong vòng điều khiển 1 kHz.
         * Đổi lại: tránh được phân tích nhiều trường hợp biên của lời giải
         * kín — nơi lỗi rất dễ lọt và rất khó phát hiện. */
        float lo = 0.0f, hi = v_pk;
        for (int i = 0; i < 60; ++i) {
            const float mid = 0.5f * (lo + hi);
            if (2.0f * accel_distance(mid, lim->a_max, lim->j_max,
                                      NULL, NULL, NULL) > D) {
                hi = mid;
            } else {
                lo = mid;
            }
        }
        v_pk  = lo;
        d_acc = accel_distance(v_pk, lim->a_max, lim->j_max, &Tj, &Ta, &a_pk);
        prof->Tv = 0.0f;
    }

    prof->v_peak = v_pk;
    prof->a_peak = a_pk;
    prof->Tj = Tj;
    prof->Ta = Ta;

    build_segments(prof);
    prof->valid = true;
    return true;
}

void traj_eval(const traj_profile_t *pr, float t, traj_state_t *out)
{
    if (!pr || !out) return;

    if (!pr->valid) {
        out->pos = pr ? pr->p0 : 0.0f;
        out->vel = out->acc = 0.0f;
        return;
    }

    if (t <= 0.0f) {
        out->pos = pr->p0;
        out->vel = out->acc = 0.0f;
        return;
    }
    if (t >= pr->T_total) {
        /* Đứng yên tại đích — dùng giá trị đã tính sẵn, KHÔNG đệ quy. */
        out->pos = pr->p0 + pr->dir * pr->p_end;
        out->vel = 0.0f;
        out->acc = 0.0f;
        return;
    }

    /* Tìm đoạn chứa t. Tối đa 7 lần so sánh — chặn trên cố định, không
     * phụ thuộc dữ liệu ⇒ WCET xác định. */
    int k = 0;
    for (int i = 0; i < 7; ++i) {
        if (t >= pr->t_s[i] && t < pr->t_s[i + 1]) { k = i; break; }
        k = i;
    }

    static const float JS[7] = { +1.0f, 0.0f, -1.0f, 0.0f, -1.0f, 0.0f, +1.0f };
    const float jj = JS[k] * pr->j;
    const float dt = t - pr->t_s[k];

    const float a = pr->a_s[k] + jj * dt;
    const float v = pr->v_s[k] + pr->a_s[k] * dt + 0.5f * jj * dt * dt;
    const float p = pr->p_s[k] + pr->v_s[k] * dt + 0.5f * pr->a_s[k] * dt * dt
                      + (1.0f / 6.0f) * jj * dt * dt * dt;

    out->pos = pr->p0 + pr->dir * p;
    out->vel = pr->dir * v;
    out->acc = pr->dir * a;
}

/* =========================================================================
 *  2. INPUT SHAPING
 * ========================================================================= */

void shaper_init(shaper_t *s, shaper_type_t type, float f_n, float zeta)
{
    if (!s) return;
    memset(s, 0, sizeof(*s));
    s->type = type;

    if (type == SHAPER_NONE || f_n <= EPS) {
        s->n = 1; s->A[0] = 1.0f; s->t[0] = 0.0f; s->extra_time = 0.0f;
        s->type = SHAPER_NONE;
        return;
    }

    if (zeta < 0.0f)   zeta = 0.0f;
    if (zeta > 0.95f)  zeta = 0.95f;

    const float rt = sqrtf(1.0f - zeta * zeta);
    const float K  = expf(-zeta * CC_PI / rt);
    const float Td = 1.0f / (f_n * rt);      /* chu kỳ tắt dần [s] */

    if (type == SHAPER_ZV) {
        const float den = 1.0f + K;
        s->n = 2;
        s->A[0] = 1.0f / den;   s->t[0] = 0.0f;
        s->A[1] = K / den;      s->t[1] = 0.5f * Td;
        s->extra_time = 0.5f * Td;
    } else {                                  /* ZVD */
        const float den = (1.0f + K) * (1.0f + K);
        s->n = 3;
        s->A[0] = 1.0f / den;          s->t[0] = 0.0f;
        s->A[1] = 2.0f * K / den;      s->t[1] = 0.5f * Td;
        s->A[2] = K * K / den;         s->t[2] = Td;
        s->extra_time = Td;
    }
}

void shaper_eval(const shaper_t *s, const traj_profile_t *prof,
                 float t, traj_state_t *out)
{
    if (!s || !prof || !out) return;

    if (s->type == SHAPER_NONE) {
        traj_eval(prof, t, out);
        return;
    }

    /* y(t) = Σ Aᵢ · profile(t − tᵢ)
     *
     * Với t − tᵢ < 0, traj_eval trả về vị trí xuất phát. Vì Σ Aᵢ = 1, tổng
     * tại t = 0 đúng bằng vị trí xuất phát — không có bước nhảy. */
    float p = 0.0f, v = 0.0f, a = 0.0f;
    for (int i = 0; i < s->n; ++i) {
        traj_state_t st;
        traj_eval(prof, t - s->t[i], &st);
        p += s->A[i] * st.pos;
        v += s->A[i] * st.vel;
        a += s->A[i] * st.acc;
    }
    out->pos = p; out->vel = v; out->acc = a;
}

/* =========================================================================
 *  3. PID + FEEDFORWARD
 * ========================================================================= */

void pid_init(pid_t *p, float kp, float ki, float kd, float ts,
              float out_min, float out_max)
{
    if (!p) return;
    memset(p, 0, sizeof(*p));
    p->kp = kp; p->ki = ki; p->kd = kd; p->ts = ts;
    p->out_min = out_min; p->out_max = out_max;
    p->k_vff = 0.0f; p->k_aff = 0.0f;
}

void pid_reset(pid_t *p)
{
    if (!p) return;
    p->e1 = p->e2 = 0.0f;
    p->u_fb = 0.0f;
    p->saturated = false;
}

float pid_step(pid_t *p, const traj_state_t *sp, float pv)
{
    if (!p || !sp) return 0.0f;

    const float e = sp->pos - pv;

    /* Dạng vi phân: tính LƯỢNG THAY ĐỔI của đầu ra, không phải đầu ra. */
    const float du = p->kp * (e - p->e1)
                   + p->ki * p->ts * e
                   + (p->kd / p->ts) * (e - 2.0f * p->e1 + p->e2);

    p->u_fb += du;

    /* Kẹp phần phản hồi TRƯỚC khi lưu — đây chính là cơ chế chống bão hoà
     * tích phân. Ở dạng vị trí thông thường phải viết logic riêng và rất
     * dễ viết sai. */
    bool clamped = false;
    if (p->u_fb > p->out_max) { p->u_fb = p->out_max; clamped = true; }
    if (p->u_fb < p->out_min) { p->u_fb = p->out_min; clamped = true; }

    /* Feedforward: bộ tạo quỹ đạo ĐÃ BIẾT vận tốc và gia tốc mong muốn,
     * nên khoản này gần như miễn phí và giảm sai số bám một bậc độ lớn.
     * Xem mục 5.5 tài liệu thiết kế. */
    const float u_ff = p->k_vff * sp->vel + p->k_aff * sp->acc;

    float u = p->u_fb + u_ff;

    /* Cờ chẩn đoán báo bão hoà ở CẢ HAI chỗ: phần phản hồi bị kẹp, hoặc
     * tổng đầu ra bị kẹp.
     *
     * Bản đầu chỉ kiểm tra tổng — và bỏ sót trường hợp phổ biến nhất: u_fb
     * đã bị kẹp đúng bằng out_max, feedforward bằng 0, nên tổng nằm ĐÚNG tại
     * giới hạn chứ không vượt. Cơ cấu chấp hành đã hết dư địa mà cờ vẫn im.
     * Test đơn vị bắt được điểm này. */
    p->saturated = clamped;
    if (u > p->out_max) { u = p->out_max; p->saturated = true; }
    if (u < p->out_min) { u = p->out_min; p->saturated = true; }

    /* GHI CHÚ TRUNG THỰC: khi feedforward lớn và đầu ra tổng bão hoà lâu,
     * cách kẹp đơn giản này vẫn có thể tích luỹ sai lệch. Nếu đo thấy hiện
     * tượng đó, chuyển sang chống bão hoà kiểu back-calculation:
     *     p->u_fb += k_aw * (u_clamped − u_unclamped);
     * Với cấu hình giai đoạn 1 thì cách hiện tại là đủ. */

    p->e2 = p->e1;
    p->e1 = e;
    return u;
}

/* =========================================================================
 *  4. ĐỆM ĐÔI KHÔNG KHOÁ
 * ========================================================================= */

void traj_slot_publish(traj_slot_t *slot, const traj_profile_t *prof,
                       float t_start)
{
    if (!slot || !prof) return;

    const uint32_t next = slot->active ^ 1u;   /* đệm đang rảnh */

    slot->buf[next]     = *prof;               /* ghi đầy đủ trước... */
    slot->t_start[next] = t_start;

    MEM_BARRIER();                             /* ...rồi mới công bố */
    slot->active = next;
    MEM_BARRIER();
}

const traj_profile_t *traj_slot_get(const traj_slot_t *slot, float *t_start)
{
    if (!slot) return NULL;

    const uint32_t idx = slot->active;
    MEM_BARRIER();
    if (t_start) *t_start = slot->t_start[idx];
    return &slot->buf[idx];
}

/* =========================================================================
 *  5. BẢN SAO MỀM TRẠNG THÁI AN TOÀN  (KHÔNG PHẢI chức năng an toàn)
 * ========================================================================= */

void safety_mirror_init(safety_mirror_t *s, float follow_err_max)
{
    if (!s) return;
    memset(s, 0, sizeof(*s));
    s->state = MACHINE_STOPPED;
    s->following_error_max = follow_err_max;
}

bool safety_mirror_update(safety_mirror_t *s, float pos_error)
{
    if (!s) return false;

    s->following_error = (fabsf(pos_error) > s->following_error_max);

    const bool fault = s->estop_active
                     || s->drive_sto_active
                     || s->limit_pos
                     || s->limit_neg
                     || s->following_error;

    if (fault) {
        if (s->state != MACHINE_ABORTED) {
            s->state = MACHINE_ABORTED;
            s->fault_count++;
        }
        return false;
    }

    /* Rời trạng thái ABORTED CHỈ bằng lệnh reset tường minh từ người vận
     * hành (safety_mirror_reset ở tầng adapter). Không tự phục hồi —
     * tự phục hồi sau lỗi là cách tạo ra khởi động bất ngờ. */
    return (s->state == MACHINE_EXECUTE || s->state == MACHINE_IDLE);
}
