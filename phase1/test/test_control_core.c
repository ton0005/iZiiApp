/* =========================================================================
 *  test_control_core.c — Kiểm thử lõi điều khiển TRÊN MÁY TÍNH
 * =========================================================================
 *
 *  Chạy:
 *      cc -O2 -Wall -Wextra -I../common -o test_cc \
 *         test_control_core.c ../common/control_core.c -lm && ./test_cc
 *
 *  VÌ SAO ĐÁNG LÀM: bắt lỗi thuật toán ở đây tốn vài giây. Bắt cùng lỗi đó
 *  trên phần cứng cần nạp firmware, gắn oscilloscope, và có khi làm hỏng
 *  cơ cấu. Đây chính là lợi ích của việc giữ control_core.c không phụ thuộc
 *  RTOS.
 * ========================================================================= */

#include "control_core.h"
#include <stdio.h>
#include <math.h>
#include <stdlib.h>

static int g_pass = 0, g_fail = 0;

static void check(int cond, const char *name, const char *detail)
{
    if (cond) { g_pass++; printf("  [OK]   %s\n", name); }
    else      { g_fail++; printf("  [FAIL] %s  -- %s\n", name, detail); }
}

static void check_near(float got, float want, float tol,
                       const char *name)
{
    char buf[192];
    const int ok = fabsf(got - want) <= tol;
    snprintf(buf, sizeof buf, "got=%.9f want=%.9f tol=%.9f diff=%.3e",
             (double)got, (double)want, (double)tol,
             (double)fabsf(got - want));
    check(ok, name, buf);
}

/* Quét toàn bộ quỹ đạo, kiểm tra các bất biến vật lý. */
static void scan_profile(const traj_profile_t *pr, const traj_limits_t *lim,
                         const char *tag)
{
    const int   N  = 20000;
    const float dt = pr->T_total / (float)N;

    float v_abs_max = 0.0f, a_abs_max = 0.0f, j_abs_max = 0.0f;
    float prev_pos = 0.0f, prev_acc = 0.0f, max_pos_jump = 0.0f;

    for (int i = 0; i <= N; ++i) {
        const float t = (float)i * dt;
        traj_state_t s;
        traj_eval(pr, t, &s);

        if (fabsf(s.vel) > v_abs_max) v_abs_max = fabsf(s.vel);
        if (fabsf(s.acc) > a_abs_max) a_abs_max = fabsf(s.acc);

        if (i > 0) {
            const float jump = fabsf(s.pos - prev_pos);
            if (jump > max_pos_jump) max_pos_jump = jump;
            const float jerk = fabsf(s.acc - prev_acc) / dt;
            if (jerk > j_abs_max) j_abs_max = jerk;
        }
        prev_pos = s.pos;
        prev_acc = s.acc;
    }

    char buf[192];
    printf("  -- %s: v_max=%.4f (gh %.4f)  a_max=%.4f (gh %.4f)  "
           "j_max=%.1f (gh %.1f)  T=%.4fs\n",
           tag, (double)v_abs_max, (double)lim->v_max,
           (double)a_abs_max, (double)lim->a_max,
           (double)j_abs_max, (double)lim->j_max, (double)pr->T_total);

    snprintf(buf, sizeof buf, "v_max=%.6f > gioi han %.6f",
             (double)v_abs_max, (double)lim->v_max);
    check(v_abs_max <= lim->v_max * 1.001f + 1e-6f, "  ton trong v_max", buf);

    snprintf(buf, sizeof buf, "a_max=%.6f > gioi han %.6f",
             (double)a_abs_max, (double)lim->a_max);
    check(a_abs_max <= lim->a_max * 1.001f + 1e-6f, "  ton trong a_max", buf);

    /* Jerk đo bằng sai phân số nên có sai số rời rạc hoá — nới 5%. */
    snprintf(buf, sizeof buf, "j_max=%.3f > gioi han %.3f",
             (double)j_abs_max, (double)lim->j_max);
    check(j_abs_max <= lim->j_max * 1.05f + 1e-3f, "  ton trong j_max", buf);

    /* Vị trí phải liên tục: không có bước nhảy lớn giữa hai mẫu liền kề. */
    const float bound = lim->v_max * dt * 1.5f + 1e-6f;
    snprintf(buf, sizeof buf, "buoc nhay lon nhat %.3e > nguong %.3e",
             (double)max_pos_jump, (double)bound);
    check(max_pos_jump <= bound, "  vi tri lien tuc", buf);
}

/* ------------------------------------------------------------------ */

static void test_traj_long_move(void)
{
    printf("\n[1] Di chuyen DAI — dat duoc v_max, co doan chay deu\n");

    const traj_limits_t lim = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };
    traj_profile_t pr;

    check(traj_plan(&pr, 0.0f, 2.0f, &lim), "lap duoc ho so", "traj_plan tra false");
    check(pr.Tv > 0.0f, "co doan chay deu (Tv > 0)", "Tv = 0");

    traj_state_t s0, s1;
    traj_eval(&pr, 0.0f, &s0);
    traj_eval(&pr, pr.T_total, &s1);

    check_near(s0.pos, 0.0f, 1e-5f, "xuat phat dung vi tri");
    check_near(s0.vel, 0.0f, 1e-6f, "xuat phat o trang thai nghi");
    check_near(s1.pos, 2.0f, 1e-3f, "den dung dich");
    check_near(s1.vel, 0.0f, 1e-6f, "ket thuc o trang thai nghi");
    check_near(pr.v_peak, 1.0f, 1e-4f, "v_peak = v_max");

    scan_profile(&pr, &lim, "dai");
}

static void test_traj_short_move(void)
{
    printf("\n[2] Di chuyen NGAN — khong dat v_max, phai ha van toc dinh\n");

    const traj_limits_t lim = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };
    traj_profile_t pr;

    check(traj_plan(&pr, 0.0f, 0.01f, &lim), "lap duoc ho so", "traj_plan tra false");
    check(pr.v_peak < lim.v_max, "v_peak da bi ha xuong", "v_peak khong giam");

    traj_state_t s1;
    traj_eval(&pr, pr.T_total, &s1);
    check_near(s1.pos, 0.01f, 1e-5f, "den dung dich (ngan)");
    check_near(s1.vel, 0.0f, 1e-6f, "ket thuc o trang thai nghi");

    scan_profile(&pr, &lim, "ngan");
}

static void test_traj_negative(void)
{
    printf("\n[3] Di chuyen AM — kiem tra xu ly dau\n");

    const traj_limits_t lim = { .v_max = 0.8f, .a_max = 1.5f, .j_max = 15.0f };
    traj_profile_t pr;

    check(traj_plan(&pr, 1.0f, -0.5f, &lim), "lap duoc ho so", "traj_plan tra false");

    traj_state_t s1;
    traj_eval(&pr, pr.T_total, &s1);
    check_near(s1.pos, -0.5f, 1e-3f, "den dung dich am");

    traj_state_t mid;
    traj_eval(&pr, pr.T_total * 0.5f, &mid);
    check(mid.vel < 0.0f, "van toc am o giua hanh trinh", "van toc khong am");

    scan_profile(&pr, &lim, "am");
}

static void test_traj_zero(void)
{
    printf("\n[4] Di chuyen KHONG — truong hop bien\n");

    const traj_limits_t lim = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };
    traj_profile_t pr;

    check(traj_plan(&pr, 0.5f, 0.5f, &lim), "lap duoc ho so", "traj_plan tra false");
    check_near(pr.T_total, 0.0f, 1e-6f, "tong thoi gian = 0");

    traj_state_t s;
    traj_eval(&pr, 0.0f, &s);
    check_near(s.pos, 0.5f, 1e-6f, "giu nguyen vi tri");
}

static void test_shaper(void)
{
    printf("\n[5] INPUT SHAPING — ZV va ZVD\n");

    shaper_t zv, zvd;
    shaper_init(&zv,  SHAPER_ZV,  1.2f, 0.02f);
    shaper_init(&zvd, SHAPER_ZVD, 1.2f, 0.02f);

    const float sum_zv  = zv.A[0] + zv.A[1];
    const float sum_zvd = zvd.A[0] + zvd.A[1] + zvd.A[2];

    check_near(sum_zv,  1.0f, 1e-6f, "ZV : tong bien do = 1");
    check_near(sum_zvd, 1.0f, 1e-6f, "ZVD: tong bien do = 1");

    /* Doi chieu voi so da kiem chung trong tai lieu thiet ke muc 5.3 */
    check_near(zv.A[0],  0.5157f, 1e-3f, "ZV  A1 = 0.5157");
    check_near(zv.A[1],  0.4843f, 1e-3f, "ZV  A2 = 0.4843");
    check_near(zvd.A[0], 0.2660f, 1e-3f, "ZVD A1 = 0.2660");
    check_near(zvd.A[1], 0.4995f, 1e-3f, "ZVD A2 = 0.4995");
    check_near(zvd.A[2], 0.2345f, 1e-3f, "ZVD A3 = 0.2345");

    const float Td = 1.0f / (1.2f * sqrtf(1.0f - 0.02f * 0.02f));
    check_near(zv.extra_time,  0.5f * Td, 1e-4f, "ZV  tre them = Td/2");
    check_near(zvd.extra_time, Td,        1e-4f, "ZVD tre them = Td");
    printf("  -- Td = %.4f s, ZV them %.4f s, ZVD them %.4f s\n",
           (double)Td, (double)zv.extra_time, (double)zvd.extra_time);

    /* Quy dao da tao dang van phai den dung dich */
    const traj_limits_t lim = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };
    traj_profile_t pr;
    traj_plan(&pr, 0.0f, 1.0f, &lim);

    traj_state_t s0, s1;
    shaper_eval(&zvd, &pr, 0.0f, &s0);
    shaper_eval(&zvd, &pr, pr.T_total + zvd.extra_time + 0.5f, &s1);

    check_near(s0.pos, 0.0f, 1e-5f, "tao dang: xuat phat dung cho");
    check_near(s1.pos, 1.0f, 1e-3f, "tao dang: van den dung dich");
    check_near(s1.vel, 0.0f, 1e-5f, "tao dang: ket thuc o trang thai nghi");
}

static void test_pid_antiwindup(void)
{
    printf("\n[6] PID — chong bao hoa tich phan\n");

    pid_t p;
    pid_init(&p, 50.0f, 20.0f, 0.0f, 0.001f, -1.0f, 1.0f);

    /* Ep sai so lon va keo dai -> dau ra phai bao hoa nhung KHONG duoc
     * tich luy vo han. */
    traj_state_t sp = { .pos = 100.0f, .vel = 0.0f, .acc = 0.0f };
    for (int i = 0; i < 5000; ++i) (void)pid_step(&p, &sp, 0.0f);

    check(p.u_fb <= 1.0f + 1e-6f, "u_fb bi kep tai gioi han tren",
          "u_fb vuot out_max");
    check(p.saturated, "co bao hieu bao hoa", "khong bao hieu");

    /* Doi chieu dau: sai so am lon -> phai thoat bao hoa NHANH.
     * Neu tich phan da tich luy vo han thi se mat rat lau moi thoat. */
    traj_state_t sp2 = { .pos = -100.0f, .vel = 0.0f, .acc = 0.0f };
    int steps = 0;
    while (steps < 5000) {
        const float u = pid_step(&p, &sp2, 0.0f);
        steps++;
        if (u <= -0.99f) break;
    }
    char buf[128];
    snprintf(buf, sizeof buf, "can %d buoc de dao chieu", steps);
    check(steps < 10, "thoat bao hoa nhanh (chong windup hieu qua)", buf);
    printf("  -- dao chieu sau %d buoc\n", steps);
}

static void test_feedforward(void)
{
    printf("\n[7] FEEDFORWARD — giam sai so bam\n");

    const traj_limits_t lim = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };
    traj_profile_t pr;
    traj_plan(&pr, 0.0f, 2.0f, &lim);

    const float ts = 0.001f;

    /* Mo phong don gian: drive nhan lenh van toc, tich phan thanh vi tri,
     * co tre mot chu ky. Du de thay tac dung cua feedforward. */
    for (int use_ff = 0; use_ff <= 1; ++use_ff) {
        pid_t p;
        pid_init(&p, 20.0f, 0.0f, 0.0f, ts, -5.0f, 5.0f);
        if (use_ff) p.k_vff = 1.0f;

        float pos = 0.0f, cmd = 0.0f, max_err = 0.0f;
        for (float t = 0.0f; t < pr.T_total; t += ts) {
            traj_state_t sp;
            traj_eval(&pr, t, &sp);
            pos += cmd * ts;                 /* tre mot chu ky */
            cmd  = pid_step(&p, &sp, pos);
            const float e = fabsf(sp.pos - pos);
            if (t > 0.05f && e > max_err) max_err = e;
        }
        printf("  -- %s feedforward: sai so bam lon nhat = %.2f mm\n",
               use_ff ? "CO   " : "KHONG", (double)(max_err * 1000.0f));

        if (use_ff) {
            check(max_err < 0.005f, "co FF: sai so bam < 5 mm",
                  "sai so van lon");
        } else {
            check(max_err > 0.01f, "khong FF: sai so bam > 10 mm "
                  "(xac nhan bai toan co that)", "sai so da nho san");
        }
    }
}

static void test_lockfree_slot(void)
{
    printf("\n[8] DEM DOI KHONG KHOA\n");

    static traj_slot_t slot;
    const traj_limits_t lim = { .v_max = 1.0f, .a_max = 2.0f, .j_max = 20.0f };

    traj_profile_t a, b;
    traj_plan(&a, 0.0f, 1.0f, &lim);
    traj_plan(&b, 0.0f, 5.0f, &lim);

    const uint32_t idx_init = slot.active;

    traj_slot_publish(&slot, &a, 10.0f);
    float t0 = 0.0f;
    const traj_profile_t *got = traj_slot_get(&slot, &t0);
    check_near(t0, 10.0f, 1e-6f, "doc dung moc thoi gian ho so 1");
    check(got->T_total == a.T_total, "doc dung ho so 1", "sai ho so");
    const uint32_t idx_after_1 = slot.active;
    check(idx_after_1 == (idx_init ^ 1u), "publish 1: chi so da lat",
          "chi so khong lat");

    traj_slot_publish(&slot, &b, 20.0f);
    got = traj_slot_get(&slot, &t0);
    check_near(t0, 20.0f, 1e-6f, "doc dung moc thoi gian ho so 2");
    check(got->T_total == b.T_total, "doc dung ho so 2 sau khi doi",
          "khong doi ho so");
    /* Lat lan hai dua chi so VE LAI gia tri ban dau — dung nhu thiet ke
     * dem doi. Ban test dau tien khang dinh nham la active == 1. */
    check(slot.active == (idx_after_1 ^ 1u), "publish 2: chi so lat lan nua",
          "chi so khong lat");
    check(slot.active == idx_init, "sau 2 lan lat thi quay ve dem ban dau",
          "khong quay ve");
}

static void test_safety_mirror(void)
{
    printf("\n[9] BAN SAO MEM TRANG THAI AN TOAN\n");

    safety_mirror_t s;
    safety_mirror_init(&s, 0.010f);          /* nguong sai so bam 10 mm */
    s.state = MACHINE_EXECUTE;

    check(safety_mirror_update(&s, 0.001f), "binh thuong -> cho phep chay",
          "bi chan khi khong co loi");

    s.estop_active = true;
    check(!safety_mirror_update(&s, 0.001f), "E-Stop -> chan chuyen dong",
          "khong chan khi E-Stop");
    check(s.state == MACHINE_ABORTED, "chuyen sang ABORTED", "sai trang thai");

    /* Bo E-Stop: KHONG duoc tu phuc hoi — day la yeu cau an toan that. */
    s.estop_active = false;
    check(!safety_mirror_update(&s, 0.001f),
          "bo E-Stop van KHONG tu phuc hoi", "da tu phuc hoi -- NGUY HIEM");

    safety_mirror_t s2;
    safety_mirror_init(&s2, 0.010f);
    s2.state = MACHINE_EXECUTE;
    check(!safety_mirror_update(&s2, 0.050f),
          "sai so bam vuot nguong -> chan", "khong phat hien sai so bam");
}

int main(void)
{
    printf("=====================================================\n");
    printf(" KIEM THU LOI DIEU KHIEN — chay tren host, khong RTOS\n");
    printf("=====================================================\n");

    test_traj_long_move();
    test_traj_short_move();
    test_traj_negative();
    test_traj_zero();
    test_shaper();
    test_pid_antiwindup();
    test_feedforward();
    test_lockfree_slot();
    test_safety_mirror();

    printf("\n=====================================================\n");
    printf(" KET QUA: %d dat, %d hong\n", g_pass, g_fail);
    printf("=====================================================\n");
    return g_fail == 0 ? 0 : 1;
}
