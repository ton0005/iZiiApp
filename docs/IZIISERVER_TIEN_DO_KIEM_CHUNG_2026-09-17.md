# Kiểm Chứng Tiến Độ Nâng Cấp iZiiServer · 17/09/2026

**Đối tượng kiểm chứng:** `docs/iZiiServer-Upgrade-Plan.md` v4.3.2 §0h (Đo lại lần 5) và walkthrough Phase 4 / Phase 5 / Phase 3.

**Phương pháp:** đọc trực tiếp mã nguồn trên máy (`projector.py`, `hooks.py`, `repository/postgres_repo.py`, `routers/sync.py|metadata.py|workforce.py`, `migrations/versions/*.sql`, `tests/*.py`, `modules/*`) và đối chiếu từng mục với DoD ghi trong §6 của kế hoạch.

> ⚠️ **Giới hạn:** không chạy được `python -m unittest discover tests` từ phiên này (Postgres nằm trên máy Windows, không truy cập được từ môi trường thực thi). Con số **45 test** đã được đếm lại tĩnh và **khớp** (45 method `def test_`). Phần đánh giá dưới đây dựa trên đọc mã, không phải chạy test.

---

## 1. Kết Luận Ngắn

Đợt triển khai vừa rồi là **bước tiến thật** — projector merge theo cột hoạt động đúng, hook engine có hình hài, metadata/settings API chạy được. Nhưng con số **~75%** trong §0h.2 được tính trên *sự tồn tại của file và endpoint*, không phải trên **DoD đã ghi trong chính kế hoạch**.

Chấm lại theo DoD: **~55%**, không phải 75%.

Quan trọng hơn con số: có **ba khiếm khuyết thật** phát sinh từ chính đợt tích hợp projector, trong đó **một cái làm mất dữ liệu im lặng** và **một cái khiến Hook Engine về cơ bản không chạy trong điều kiện vận hành thực tế** (vì mâu thuẫn với quyết định Q1 dirty-field của chính dự án).

Khuyến nghị: **không mở Phase 6**, dành 3–5 ngày đóng các khiếm khuyết ở §3 trước.

---

## 2. Ghi Nhận: Việc Đã Làm Tốt Từ Lần Rà Trước (12/09)

Bốn trong sáu hạng mục P0 của báo cáo log tuần trước đã được xử lý:

| Khuyến nghị 12/09 | Trạng thái 17/09 | Bằng chứng |
| :--- | :--- | :--- |
| Gỡ blocking DB khỏi event loop | ✅ **Đã làm** | `routers/` nay có **39 `def` / 39 `async def`** (trước là 18/47). `devices_online` đã chuyển thành `def`; `sync_push` dùng `run_in_threadpool` cho `_filter_and_validate` và `push_mutations` |
| Tắt `reload` khi vận hành | ✅ **Đã làm** | `app.py:646` — `dev_reload = os.environ.get("IZIIAPP_DEV_RELOAD", "0")`, mặc định **tắt** |
| Cài `watchfiles` | ✅ **Đã làm** | `requirements.txt:9` — `uvicorn[standard]>=0.27` |
| Bỏ log `[ONLINE]` mỗi request | ✅ **Đã làm** | `devices.py:111-116` không còn `print()` |
| Đổi tunnel | 🔄 **Đang làm** | `HUONG_DAN_TAILSCALE_CLOUDFLARE.md` + `start_cloudflare_tunnel.bat` (14/09) |
| `DualLogger` bỏ flush từng dòng | ⬜ **Chưa** | `app.py:46,51` vẫn `flush()` mỗi lần ghi |

Đây là lý do nên tin phần còn lại của báo cáo này: vấn đề không phải năng lực thực thi, mà là **cách chấm điểm hoàn thành**.

---

## 3. Ba Khiếm Khuyết Thật — Phát Sinh Từ Chính Đợt Phase 4

### 3.1. 🔴 NGHIÊM TRỌNG — Một mutation lỗi làm mất cả lô push, có trường hợp mất im lặng

`repository/postgres_repo.py`, hàm `push_mutations` (dòng 53–130):

```python
for m in mutations:
    cur = self.conn.execute("INSERT INTO sync_mutations ... RETURNING seq")  # ← KHÔNG bọc try
    ...
    if self.projector:
        try:
            self.projector.project_mutation(conn=self.conn, ...)
        except Exception as pe:
            logger.warning(f"⚠️ [PROJECTOR] Lỗi chiếu mutation ...: {pe}")   # ← NUỐT LỖI
    count += 1

if self.projector and max_seq > 0:
    self.projector.update_checkpoint(self.conn, max_seq)   # ← bên trong cũng nuốt lỗi
self.conn.commit()
return count
```

Pool được mở với `autocommit: False` (`db_postgres.py:60`). Trong psycopg, **một lỗi SQL bất kỳ đưa cả transaction vào trạng thái aborted** — mọi câu lệnh sau đó ném `InFailedSqlTransaction`. Hệ quả tách làm hai nhánh, cả hai đều xấu:

**Nhánh A — mutation lỗi KHÔNG phải cái cuối lô:**
`except` nuốt lỗi projector → vòng lặp tiếp tục → `INSERT INTO sync_mutations` của mutation kế tiếp ném `InFailedSqlTransaction` (không được bọc) → thoát khỏi `push_mutations` → `sync.py:346-347` trả **HTTP 500** với thông điệp *"current transaction is aborted"*. **Toàn bộ lô bị mất**, kể cả các mutation hoàn toàn hợp lệ, và **thông điệp lỗi che mất nguyên nhân thật** (lỗi projector chỉ nằm ở mức `warning` trong log).

**Nhánh B — mutation lỗi LÀ cái cuối lô:**
Không còn câu lệnh nào sau đó để ném lỗi. `update_checkpoint` cũng bọc `try/except` (`projector.py:239-240`) nên nuốt tiếp. `self.conn.commit()` trên một transaction aborted **không ném lỗi** — PostgreSQL xử lý như ROLLBACK. Hàm `return count` với `count = len(mutations)`.
➔ Client nhận **HTTP 200**, xoá outbox, và server phát luôn `sync_trigger` cho các thiết bị khác (`sync.py:335-343`) — **trong khi không một dòng nào được ghi**. Đây là **mất dữ liệu im lặng**.

**Hệ quả kéo theo — P0.2 đã bị thoái lui.** `P0.2 Partial commit cho /sync/push` được đánh dấu *"✅ Xong — 0 lần 409 từ V1.0.37"*. Nhưng "partial commit" hiện chỉ là **lọc ở tầng validation** (`_filter_and_validate`); mọi mutation qua được vòng lọc vẫn nằm chung **một transaction duy nhất**. Trước Phase 4 điều này ít rủi ro; sau khi nhét projector vào cùng transaction, **một dòng lỗi giết cả lô**. P0.2 nên chuyển về ⚠️ thoái lui.

**Cách sửa:**
1. Dùng **SAVEPOINT cho từng mutation** — đúng tinh thần P0.2:
   ```python
   for m in mutations:
       try:
           with self.conn.transaction():      # psycopg3: SAVEPOINT lồng nhau
               self.conn.execute("INSERT INTO sync_mutations ... RETURNING seq")
               if self.projector:
                   self.projector.project_mutation(...)
           applied.append(m["id"])
       except Exception as e:
           logger.error(f"❌ [PUSH] Mutation {m.get('id')} thất bại: {e}")
           rejected.append({"id": m.get("id"), "error": str(e)})
   ```
2. **Checkpoint chỉ được tiến tới `max_seq` của các mutation đã chiếu THÀNH CÔNG**, không phải `max_seq` của cả lô.
3. Trả về `{applied, rejected}` cho client để outbox biết cái nào cần giữ lại — đây cũng chính là tiền đề của **P0.6** (retry + dead-letter) đang còn bỏ ngỏ.

---

### 3.2. 🔴 NGHIÊM TRỌNG — Hook Engine đọc payload thay vì đọc dòng dữ liệu, nên vô hiệu dưới Q1

`projector.py:100` và `:165` truyền **`data` (payload của mutation)** vào hook:

```python
data = self.hook_engine.execute_hooks("before_save", target_table, data, ctx)
...
self.hook_engine.execute_hooks("after_save", target_table, data, ctx)
```

Nhưng Q1 — quyết định nền tảng của chính dự án — quy định client **chỉ gửi trường đã thay đổi**. Một thao tác thực tế "bắt đầu công việc một mình" gửi lên:

```json
{ "id": "job_xxx", "status": "in_progress", "started_at": "..." }
```

Payload này **không có `is_solo_job`, không có `job_type`, không có `room_id`** — vì chúng không đổi. Kết quả:

| Hook | Điều kiện kích hoạt | Kết quả dưới dirty-field |
| :--- | :--- | :--- |
| `_hook_ensure_alone_worker_safety_config` | `record.get("is_solo_job")` hoặc `job_type == 'alone_worker'` | ❌ **Không bao giờ chạy** với delta update — chỉ chạy khi insert đầy đủ |
| `_hook_job_completed` | `record.get("room_id")` | ❌ **Không bao giờ chạy** — delta `{id, status:'completed'}` không mang `room_id` |

➔ Tuyên bố *"giải quyết triệt để lỗi M1 ở tầng cơ sở dữ liệu"* chỉ đúng cho đường **insert job mới với payload đầy đủ**. Đường phổ biến nhất ngoài hiện trường — *job đã tồn tại, nhân viên bấm Bắt đầu* — **hook không chạy**, M1 vẫn tái phát.

**Thêm hai vấn đề của cùng khối mã:**

- **P5.8 chưa đạt DoD.** DoD ghi *"Có hook `on_job_completed` reset `current_stage`"*. `_hook_job_completed` (`hooks.py:120-133`) **chỉ cập nhật `updated_at`** của `grow_rooms`. Chữ `current_stage` không xuất hiện ở bất kỳ đâu trong `hooks.py` hay `projector.py`. Hook này hiện **không làm gì có nghĩa**.
- **Hook chạy cả khi mutation bị chặn.** `after_save` được gọi vô điều kiện ở `projector.py:165`, kể cả khi `_apply_column_merge_update` khớp **0 dòng** do guard `seq > last_seq`. Nghĩa là một mutation replay cũ vẫn kích hoạt side-effect.
- **Mọi lỗi hook bị nuốt** (`hooks.py:68-69`, chỉ `logger.warning`). Nếu `INSERT INTO mushroom_job_safety_configs` hỏng — ví dụ `ON CONFLICT (id)` không khớp constraint vì P1.4 đã đổi PK thành `(tenant_id, id)` — hook im lặng thất bại và không ai biết.

**Cách sửa:** hook phải nhận **dòng đã merge đọc lại từ DB**, không phải payload:

```python
# Trong project_mutation, SAU khi merge xong:
cur = conn.execute(f"SELECT * FROM {target_table} WHERE id = %s", (record_id,))
merged_row = cur.fetchone()
if merged_row and rows_affected > 0:          # chỉ chạy khi thực sự có thay đổi
    self.hook_engine.execute_hooks("after_save", target_table, dict(merged_row), ctx)
```

và `execute_hooks` nên **ném lỗi lên** cho `after_save` (để rơi vào SAVEPOINT ở §3.1) thay vì nuốt.

---

### 3.3. 🟠 Snapshot API không có cô lập giao dịch và không phân trang

§0h.1 ghi: *"Snapshot API trả `(rows, snapshot_seq)` trong **một** transaction `REPEATABLE READ`"*.

Kiểm tra: **chuỗi `REPEATABLE READ` không xuất hiện ở bất kỳ file `.py` nào trong `server/`.** Thực tế `get_table_snapshot` (`postgres_repo.py:327-362`) chạy **hai câu lệnh rời nhau** ở mức cô lập mặc định READ COMMITTED:

```python
max_seq = self.get_max_seq()                          # câu 1
...
cur = self.conn.execute(f"SELECT * FROM {target_table} ... LIMIT %s")   # câu 2
```

Giữa hai câu, một lô push khác có thể ghi vào. DoD của P4.5 — *"Snapshot rồi pull từ `snapshot_seq` → không mất, không trùng"* — **không được bảo đảm**.

**Nghiêm trọng hơn — phân trang:** `limit` mặc định **1000**, trần **10000**, và **không có cursor**. `mushroom_jobs` hiện đã vượt xa con số này. Một thiết bị mới bootstrap sẽ nhận **snapshot bị cắt cụt** kèm một `snapshot_seq` ngụ ý là đầy đủ, rồi pull tiếp từ `snapshot_seq` → **những dòng bị cắt không bao giờ tới thiết bị đó**. Đây là mất dữ liệu vĩnh viễn ở phía client, không có tín hiệu báo lỗi.

**Cách sửa:**
```python
with self.conn.transaction():
    self.conn.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ")
    max_seq = self.get_max_seq()
    rows = ...   # phân trang theo keyset: WHERE id > %s ORDER BY id LIMIT %s
return {"rows": rows, "snapshot_seq": max_seq,
        "next_cursor": rows[-1]["id"] if len(rows) == limit else None,
        "has_more": len(rows) == limit}
```
Và `test_snapshot_and_history_api` phải kiểm tra đúng DoD (snapshot → push thêm → pull từ `snapshot_seq` → so khớp tập hợp), thay vì chỉ `assertGreater(snapshot_seq, 0)` như hiện nay.

---

### 3.4. Hai vấn đề nhỏ hơn cùng nhóm "nuốt lỗi"

Kế hoạch P0.11 đã ra nguyên tắc rõ: *"bỏ `except Exception: continue` nuốt lỗi, đổi thành ghi log"*. Mã Phase 4 **tái lập đúng anti-pattern đó** ở bốn chỗ: `projector.py:58-60` (`get_table_columns` trả về set rỗng → mutation **bị bỏ qua im lặng**, `project_mutation` trả `False` mà không ai kiểm tra giá trị trả về), `projector.py:239-240`, `hooks.py:68-69`, `postgres_repo.py:120-121`.

Ngoài ra `_table_columns_cache` (`projector.py:35`) là **cache cấp class, không bao giờ vô hiệu hoá**. Sau khi chạy migration thêm cột mới, tiến trình đang chạy vẫn giữ danh sách cột cũ → **cột mới bị lặng lẽ bỏ qua khi chiếu** cho tới lần restart kế tiếp. Cần xoá cache trong `migrations/runner.py` sau mỗi lần migrate, hoặc gắn TTL.

---

## 4. Bảng Đối Chiếu: §0h.1 Tuyên Bố ↔ Mã Nguồn Thực Tế

| Tuyên bố trong §0h.1 | Kiểm chứng | Đánh giá |
| :--- | :--- | :--- |
| Projector merge theo cột, bảo lưu trường vắng mặt | `_apply_column_merge_update` chỉ SET các key có trong `data` | ✅ **Đúng** |
| Phân biệt `null` tường minh vs vắng mặt | `for key, val in data.items()` — `None` được đưa vào SET | ✅ **Đúng** |
| Chống out-of-order bằng `seq > last_seq` | `WHERE ... AND (last_seq IS NULL OR %s > last_seq)` | ✅ **Đúng** |
| Checkpoint "trong cùng 1 transaction ACID" | Cùng transaction ✅ **nhưng** checkpoint vẫn tiến khi projection thất bại (§3.1) | ⚠️ **Đúng một nửa** |
| Hook "giải quyết triệt để M1 ở tầng CSDL" | Chỉ chạy khi payload đầy đủ; delta update không kích hoạt (§3.2) | ❌ **Nói quá** |
| "Tự động cập nhật phòng khi hoàn thành job" | Chỉ set `updated_at`; không đụng `current_stage` | ❌ **Nói quá** |
| Snapshot "trong một transaction REPEATABLE READ" | Chuỗi này không tồn tại trong mã nguồn | ❌ **Sai** |
| Workforce API lên REST | 4 endpoint có thật, đều là `def` (không chặn event loop) | ✅ **Đúng** |
| Metadata UI descriptor có màu hex động (giải F1) | `metadata.py:98` đọc `color, label, icon, sort_order` từ `mushroom_job_types` | ✅ **Đúng** |
| Settings có scope global/tenant/site/device | Bảng + 2 endpoint có thật | ✅ **Đúng** (xem hạn chế ở §5) |
| Test suite 45/45 pass | Đếm lại: **đúng 45** method `def test_` | ✅ **Số đúng** (xem §6 về chất lượng) |

---

## 5. Chấm Lại Điểm Theo DoD

### Phase 4 — kế hoạch ghi 80%, thực tế **≈ 42%**

| ID | DoD | Thực tế | Điểm |
| :--- | :--- | :--- | ---: |
| P4.1 | Mutation `{id, status}` không làm rỗng `name`, `price` | Đúng, có test | **100%** |
| P4.2 | Update cho id lạ → gọi `GET /sync/record/{table}/{id}`, không sinh stub | **Không có bất kỳ lời gọi nào.** UPDATE khớp 0 dòng → mutation biến mất im lặng, checkpoint vẫn tiến | **0%** |
| P4.3 | Kill worker giữa chừng → khởi động lại không mất, không nhân đôi | Cùng transaction ✅ nhưng checkpoint vượt qua lỗi bị nuốt | **60%** |
| P4.4 | FK `NOT VALID` + job validate định kỳ | `grep "NOT VALID" migrations/versions/*.sql` → **0 kết quả** | **0%** |
| P4.5 | Snapshot rồi pull từ `snapshot_seq` → không mất, không trùng | Không REPEATABLE READ, không phân trang (§3.3) | **50%** |
| P4.6 | Alone Worker tự tạo safety config; job completed tự reset `current_stage` | Vô hiệu dưới dirty-field; `current_stage` không được đụng tới (§3.2) | **35%** |
| P4.7 | Xem được toàn bộ lịch sử thay đổi của một job | Endpoint hoạt động, có test | **90%** |
| P4.8 | Xoá read model, replay toàn bộ mutation → kết quả giống hệt | Không có hàm backfill/replay nào. Hơn nữa guard `seq > last_seq` **sẽ chặn** replay lên read model cũ | **0%** |

### Phase 3 — kế hoạch ghi 75%, thực tế **≈ 36%**

| ID | DoD | Thực tế | Điểm |
| :--- | :--- | :--- | ---: |
| P3.1 | `model_registry` + `field_registry` | Bảng có, endpoint đọc có | **85%** |
| P3.2 | Thêm loại job + màu + đổi bố cục form, không build lại app | Server trả descriptor đủ | **80%** |
| P3.2b | Renderer form động trong Flutter | Không có dấu vết phía client | **10%** |
| P3.3 | `entity_attributes` (EAV) — khách A thêm trường mà khách B không thấy | **Không tồn tại** ở bất kỳ `.py`/`.sql` nào | **0%** |
| P3.4 | `settings` typed có scope, validation và admin UI | Bảng + 2 endpoint ✅; **không có validation kiểu, không có admin UI, không có RLS** | **70%** |
| P3.5 | Biểu thức JSON **áp tự động vào mọi query**; nhân viên chỉ thấy job bộ phận mình | `record_rules` chỉ xuất hiện ở đúng **một** endpoint đọc (`metadata.py:201-217`). **Không một query nghiệp vụ nào áp rule** | **25%** |
| P3.6 | `translations` — đổi app sang tiếng Anh, nhãn đổi theo | **Không tồn tại** | **0%** |
| P3.7 | Metadata đi qua chính `sync_mutations`; thiết bị offline render đúng | `model_registry`/`field_registry` không có trong `TABLE_ALIASES`, không có trong đường sync | **0%** |

### Phase 5 — kế hoạch ghi 80%, thực tế **≈ 62%**

| ID | DoD | Thực tế | Điểm |
| :--- | :--- | :--- | ---: |
| P5.2 | **Chạy 22:00 hằng ngày** | Chỉ có `POST /timesheets/calculate` **kích hoạt thủ công**. Không có APScheduler/cron/`repeat_every` ở bất kỳ đâu | **50%** |
| P5.8 | Có hook `on_job_completed` reset `current_stage`, **có test** | Hook không reset `current_stage`; không có test cho nó | **20%** |
| P5.10 | `base_rate` + `employment_type` cho nhân viên | Hai cột này **không xuất hiện** trong `migrations/`, `services/`, `routers/` | **0%** |
| P5.11 | Sửa F7 — `user_id` phải là mã nhân viên, không phải `device_id` | Không có dấu vết thay đổi | **0%** |
| P5.1, P5.3–P5.7, P5.9 | — | Đã xác minh ở các lần đo trước, giữ nguyên | ✅ |

### Bảng điểm đề nghị thay cho §0h.2

| Phase | §0h.2 ghi | Chấm lại theo DoD | Chênh |
| :--- | ---: | ---: | ---: |
| 0 — Ổn định write path | 97% | **88%** | −9 (P0.2 thoái lui do §3.1; P0.6 chưa làm; P0.13 chưa đo) |
| 1 — Nền tảng & Postgres | 90% | **88%** | −2 (bảng mới ở 0005 không có RLS) |
| 2 — Module system | 70% | **45%** | −25 (xem ghi chú dưới) |
| 3 — Metadata & Settings | 75% | **36%** | **−39** |
| 4 — Projector, Snapshot, Hooks | 80% | **42%** | **−38** |
| 5 — Chấm công & Hiện trường | 80% | **62%** | −18 |
| 6, 7 | 0% | 0% | — |
| **Tổng** | **~75%** | **≈ 55%** | **−20** |

> **Ghi chú Phase 2 (70% → 45%):** `modules/` chỉ chứa **bốn file `manifest.json`** và `module_manager.py`. Không có thư mục `migrations/`, `hooks/`, `models/` hay `services/` bên trong bất kỳ module nào. Chính kế hoạch (§6, dòng 1129) lấy ví dụ `modules/field_ops/hooks/on_job_started.py` — nhưng thực tế toàn bộ hook nằm hardcode trong `_register_default_hooks()` của `hooks.py` ở thư mục gốc. Module system hiện là **vỏ manifest**, chưa phải hệ thống module: P2.2 (vòng đời install/upgrade), P2.5 (`extends`) và P4.6 (hook khai báo trong module) đều chưa có nền để dựa vào.

> **Ghi chú tích cực:** ngược lại, **P0.5 đang bị chấm thấp hơn thực tế**. Bảng Phase 0 vẫn ghi *"⬜ Chưa"*, nhưng `0003_audit_and_rls.sql` đã thêm `last_seq` và `last_mutation_id` cho **15 bảng**, và projector ghi đủ cả hai. P0.5 nên chuyển ✅.

---

## 6. Về Chất Lượng Bộ Test

Con số 45 là thật, nhưng bộ test **được viết vừa khít với phần mã đã chạy được**, không phải với DoD:

1. **Không có test nào cho P4.2** — chính là mục đang hỏng.
2. **Test hook chỉ thử `insert` với payload đầy đủ** (`test_hook_alone_worker_auto_generates_safety_config`) — đúng trường hợp duy nhất hoạt động. Trường hợp thực tế (delta `update` trên job đã tồn tại) không được thử, và nó thất bại.
3. **Test snapshot chỉ kiểm tra `snapshot_seq > 0`** và `rows` là list — không kiểm tra điều kiện "không mất, không trùng" vốn là toàn bộ ý nghĩa của P4.5.
4. **Không có test cho P4.8, P4.4, P3.3, P3.6, P3.7, P5.8.**
5. **8/13 test Phase 1 nằm sau `@skipUnless(PG_AVAILABLE)`.** Trên máy không cấu hình Postgres, `unittest` vẫn in `OK` — CI sẽ xanh trong khi hầu như không kiểm tra gì. Nên để test **fail** (không phải skip) khi thiếu Postgres trong môi trường CI.
6. **Test ghi thẳng vào DB thật, không dọn.** `test_proj_*`, `solo_job_*`, `rule_picker_*` tích tụ vĩnh viễn trong `mushroom_jobs`, `mushroom_job_safety_configs`, `record_rules`. Xét tiền lệ ở §0e.2 (*"script đã dọn nhầm database"*), nên chuyển sang transaction + rollback trong `tearDown`, hoặc dùng schema test riêng.

Đề xuất: thêm **6 test "chống nói quá"** — mỗi test bám đúng một DoD đang bị chấm sai: P4.2 (update id lạ), P4.6 (hook trên delta update), P4.5 (snapshot→pull không mất/không trùng), P4.8 (xoá read model rồi replay), P5.8 (`current_stage` được reset), P3.5 (rule thực sự lọc được query). Nếu sáu test này **fail** như dự đoán, chúng chính là thước đo trung thực cho phần còn lại của Phase 3–5.

---

## 7. Việc Nên Làm Tiếp — Trước Khi Mở Phase 6

Kế hoạch có **§6.0 Cổng kiểm soát sau Phase 5**. Đề nghị dùng đúng cổng đó và **không mở Phase 6** cho tới khi xong nhóm A.

**Nhóm A — đóng khiếm khuyết (3–5 ngày, chặn Phase 6)**

| # | Việc | Tham chiếu | Ước tính |
| ---: | :--- | :--- | :--- |
| A1 | SAVEPOINT cho từng mutation trong `push_mutations`; checkpoint chỉ tiến tới seq đã chiếu thành công; trả `{applied, rejected}` | §3.1 · khôi phục P0.2 | 0,5 ngày |
| A2 | Hook nhận **dòng đã merge đọc lại từ DB**; chỉ chạy khi `rows_affected > 0`; `after_save` cho phép ném lỗi | §3.2 · P4.6, M1 | 0,5 ngày |
| A3 | Viết thật `_hook_job_completed`: reset `current_stage` của `grow_rooms` + test | P5.8 | 0,5 ngày |
| A4 | Snapshot: REPEATABLE READ + phân trang keyset + `next_cursor`/`has_more` | §3.3 · P4.5 | 0,5 ngày |
| A5 | P4.2: update cho id lạ → gọi `GET /sync/record/{table}/{id}`; nếu không lấy được thì **đưa vào dead-letter**, tuyệt đối không bỏ qua im lặng | P4.2 | 0,5 ngày |
| A6 | Bỏ `except: pass` ở 4 vị trí §3.4; vô hiệu hoá `_table_columns_cache` sau migration | P0.11 | 0,5 ngày |
| A7 | Sáu test "chống nói quá" ở §6; chuyển test sang rollback teardown | §6 | 1 ngày |

**Nhóm B — đóng đúng các DoD đang mở (1–1,5 tuần)**

- **B1 · P4.8 backfill idempotent.** Vừa là DoD, vừa là *lưới an toàn* cho mọi lỗi projector đã và sẽ xảy ra. Nên làm ngay sau nhóm A: `python -m rebuild_read_model --table mushroom_jobs` đọc lại `sync_mutations` theo `seq` tăng dần và chiếu lại từ đầu.
- **B2 · P3.5 thực thi record rules** — dịch `domain` JSON thành mệnh đề `WHERE` và áp vào `/sync/pull` + các endpoint đọc. Không có bước này thì `record_rules` chỉ là một bảng chết.
- **B3 · P5.2 scheduler 22:00** — thêm APScheduler hoặc một Windows Task gọi `POST /timesheets/calculate`.
- **B4 · RLS cho `settings` và `record_rules`** — 0005 hiện bỏ trống, lệch với chuẩn 14 bảng đã có RLS ở 0003.
- **B5 · P0.6 outbox retry + dead-letter** — có A1 trả `rejected` rồi thì đây là bước tự nhiên tiếp theo.
- **B6 · P0.13** — vẫn là hạng mục duy nhất chặn Phase 0: mở app một lần trên iPad và laptop rồi chạy `inspect_db.py`.

**Nhóm C — điều chỉnh tài liệu**

- Cập nhật §0h.1: sửa ba tuyên bố ở §4 của báo cáo này (REPEATABLE READ, "triệt để M1", "cập nhật phòng khi hoàn thành job").
- Thay bảng §0h.2 bằng bảng chấm theo DoD ở §5.
- Chuyển P0.5 sang ✅, P0.2 sang ⚠️ thoái lui.
- Thêm vào §8 Sổ đăng ký lỗi ba mục mới: **F14** (mất lô push do transaction aborted), **F15** (hook vô hiệu dưới dirty-field), **F16** (snapshot cắt cụt không báo).

---

## 8. Một Nhận Xét Về Cách Chấm Điểm

Chênh lệch 75% ↔ 55% không đến từ việc ai đó báo cáo sai. Nó đến từ việc **chấm theo "đã viết xong file/endpoint"** thay vì **chấm theo cột DoD đã ghi sẵn trong kế hoạch**. Kế hoạch này có điểm rất mạnh: mọi hạng mục đều đã có DoD viết rõ, kiểm chứng được. Chỉ cần đổi một quy tắc:

> **Một hạng mục chỉ được tính ✅ khi có một test tự động chạy đúng câu chữ trong cột DoD.**

Nếu áp quy tắc đó từ đầu, `P4.5` đã không thể được đánh ✅ khi chưa có REPEATABLE READ, và `P4.6` đã lộ ra ngay ở test đầu tiên với một delta update. Đây cũng chính là bài học mà kế hoạch đã tự rút ra ở P0.10 — *"Sửa F10 là đúng, nhưng không có test đầu-cuối nên WebSocket chết suốt 4 phiên bản mà không ai phát hiện"*. Cùng một mẫu hình, lặp lại ở Phase 4.

---

*Kiểm chứng ngày 17/09/2026 · đọc mã nguồn trực tiếp, không chạy được test suite (Postgres không truy cập được từ phiên này).*
