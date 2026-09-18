# Kiểm Chứng Lần 2 · Sau Đợt Khắc Phục A1–A7 / B1–B4 · 17/09/2026

**Đối tượng:** `docs/iZiiServer-Upgrade-Plan.md` bản 11:15 hôm nay (127.536 byte, 1.680 dòng) — sửa đổi sau báo cáo kiểm chứng lúc 10:28.

**Phương pháp:** diff tài liệu so với bản 10:28, rồi đọc lại mã nguồn từng hạng mục A1–A7, B1–B4.

> ⚠️ Vẫn chưa chạy được test suite từ phiên này (Postgres trên máy Windows, môi trường thực thi không với tới). Đánh giá dựa trên đọc mã.

---

## 1. Kết Luận Ngắn

**Đợt khắc phục này là thật và làm tốt.** Bảy trong mười một hạng mục đã được triển khai đúng, trong đó ba cái là sửa chữa chuẩn xác vào đúng chỗ đau: savepoint cho từng mutation (A1), hook đọc lại dòng đã merge (A2), snapshot REPEATABLE READ + keyset pagination (A4). Tôi đã đọc kỹ và xác nhận — không phải làm cho có.

Nhưng bảng điểm mới ghi **~85%**, và đó lại là cùng một lỗi chấm điểm mà báo cáo trước đã chỉ ra, chỉ khác là lần này nghiêm trọng hơn ở ba chỗ:

- **Phase 3 nhảy 36% → 85%** trong khi ba trong tám hạng mục (P3.3, P3.6, P3.7) vẫn **hoàn toàn không tồn tại trong mã nguồn** — tôi đã grep lại, không một dòng nào.
- **Phase 2 tăng 45% → 55%** trong khi **không có một thay đổi nào** — cột "Điều gì đã đổi" chép nguyên văn dòng cũ ("4 module manifest, nạp tự động lúc startup").
- **B1 (`rebuild_read_model.py`) không phải là thành tựu — nó là rủi ro mất dữ liệu.** Xem §3.1.

Chấm lại theo DoD: **≈ 65%** (tăng thật 10 điểm so với 55% sáng nay — một buổi làm việc rất hiệu quả), không phải 85%.

---

## 2. Đã Sửa Đúng — Xác Nhận Từng Cái

| Hạng mục | Xác nhận | Đánh giá |
| :--- | :--- | :--- |
| **A1 · Savepoint cho từng mutation** | `postgres_repo.py:70` — `with self.conn.transaction():` bọc trọn `INSERT sync_mutations` + `project_mutation`. `except` ở ngoài chỉ rollback savepoint của mutation đó. `max_seq` chỉ lấy từ mutation thành công (dòng 126). `applied_ids` / `rejected` ghi nhận riêng. | ✅ **Đúng hoàn toàn.** F14 đã đóng. P0.2 được khôi phục thật, không còn chỉ là lọc validation. |
| **A1b · Trả kết quả cho client** | `sync.py:355-363` trả `status: partial_success`, `applied_ids`, `rejected_count`, `rejected`. | ✅ **Đúng** — nhưng vòng lặp chưa khép, xem §3.3 |
| **A2 · Hook nhận dòng đã merge** | `projector.py:264-267` — sau merge, `SELECT * FROM {table} WHERE id = %s` rồi truyền `dict(merged_row)`. Nhánh insert cũng đọc lại (dòng 144-147). Chỉ chạy khi `rows_affected > 0` (dòng 263). | ✅ **Đúng hoàn toàn.** F15 đã đóng — đây là bản sửa quan trọng nhất trong đợt. |
| **A2b · Lỗi hook ném ra ngoài** | `hooks.py:70-71` — `if event.startswith("after"): raise`. Lỗi hook `after_save` nay rơi vào savepoint của A1. | ✅ **Đúng** |
| **A3 · Reset `current_stage`** | `hooks.py:133-137` — `UPDATE grow_rooms SET current_stage = NULL, updated_at = %s WHERE id = %s`. | ✅ **Đúng.** P5.8 nay đạt DoD |
| **A4 · Snapshot isolation + phân trang** | `postgres_repo.py:365-410` — `with self.conn.transaction():` + `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ`; keyset `(id COLLATE "C") > (%s COLLATE "C")`, `ORDER BY (id COLLATE "C") ASC`, trả `has_more` + `next_cursor`. | ✅ **Đúng.** F16 đã đóng. Dùng `COLLATE "C"` là lựa chọn chuẩn xác — keyset ổn định bất kể locale |
| **A6 (một phần) · Bỏ nuốt lỗi** | `update_checkpoint` (`projector.py:269-279`) nay không còn `try/except`. `hooks.py:69` đổi `warning` → `error` + `raise`. `postgres_repo.py` đổi `warning` → `error`. | ✅ **Phần lớn đã làm** (còn sót, xem §4) |
| **B2 · RLS cho settings & record_rules** | `0006_settings_and_rules_rls.sql` — thêm `tenant_id` vào `settings`, `ENABLE ROW LEVEL SECURITY` + policy cho cả hai bảng. `get_db` lấy tenant từ header `x-tenant-id`, mặc định `'default'`. | ✅ **Đúng** (ghi chú nhỏ ở §4) |
| **B4 · Cron 22:00** | `app.py:254` `_daily_timesheet_cron_loop()`, khởi động ở dòng 398, huỷ đúng cách khi shutdown (dòng 404). | ✅ **Có thật** (một rủi ro ở §3.4) |

Đây là **bảy hạng mục sửa đúng trong chưa đầy một buổi**. Nhận xét thẳng: tốc độ và độ chính xác của đợt này tốt hơn hẳn đợt Phase 4 ban đầu — vì lần này sửa theo DoD, không theo "cho có file".

---

## 3. Bốn Vấn Đề Mới

### 3.1. 🔴 `rebuild_read_model.py` sẽ **xoá vĩnh viễn** dữ liệu — và không thể đạt DoD P4.8

Script làm đúng hai việc nó nói: `TRUNCATE TABLE {tbl} CASCADE` mười bảng read model, rồi replay `sync_mutations` theo `seq ASC`. Vấn đề nằm ở giả định ngầm: **mọi dòng trong read model đều có mutation tương ứng**. Giả định đó sai ở bốn chỗ:

1. **Dòng do hook sinh ra không phải là mutation.** `mushroom_job_safety_configs` nằm trong danh sách TRUNCATE, nhưng nó được sinh bởi `_hook_ensure_alone_worker_safety_config` — **không có mutation nào cho nó**. Replay chỉ tạo lại được những config mà job gốc còn mutation. Phần còn lại mất sạch. Đây chính là bảng của lỗi M1 mà cả dự án đã bỏ công khôi phục ở §9.2.
2. **Dòng do seed sinh ra không phải là mutation.** `seeds/seed_loader.py` và cờ `is_seed` (P1.3) ghi thẳng vào bảng. TRUNCATE xoá, replay không dựng lại.
3. **Dòng di trú từ SQLite không phải là mutation.** `migrate_to_postgres.py` (P1.12) ghi thẳng. Toàn bộ dữ liệu lịch sử trước khi có `sync_mutations` sẽ biến mất.
4. **`sync_mutations` chỉ giữ 60 ngày.** P1.5 quy định retention 60 ngày bằng `DROP PARTITION`. Mọi thứ cũ hơn **không còn mutation để replay**.

➔ **DoD P4.8 — "Xoá read model, replay toàn bộ mutation → kết quả giống hệt" — không thể đạt được về mặt thiết kế** chừng nào retention còn 60 ngày và còn đường ghi không qua mutation. Script hiện tại không phải là backfill; nó là một cái nút xoá dữ liệu.

**Thêm ba vấn đề kỹ thuật:**

- **Không có xác nhận, không backup, không `--tenant`.** Chạy nhầm một lần là mất. Chính kế hoạch đã ghi sự cố này ở §0e.2: *"script đã dọn nhầm database"*.
- **`TRUNCATE ... CASCADE` lan truyền.** CASCADE trên TRUNCATE xoá luôn mọi bảng có FK trỏ tới, kể cả bảng không nằm trong `READ_MODEL_TABLES`.
- **Fallback `DELETE FROM` không bao giờ chạy được.** Khi `TRUNCATE` lỗi, transaction đã abort → `DELETE` trong `except` cũng ném → bị nuốt bằng `logger.warning`. Bảng đó âm thầm không được dọn, rồi replay chồng lên dữ liệu cũ.
- **A5 phá vỡ chính replay.** Mutation `update` nào có `insert` đã bị prune sẽ bị A5 ném `ValueError` → bị từ chối trong lúc replay → bản ghi không bao giờ hình thành. **B1 và A5 xung khắc trực tiếp.**

**Đề nghị:** hạ B1 từ 100% xuống **30%**, và trước khi ai đó chạy nó:
```python
# Bắt buộc, theo thứ tự
1. pg_dump các bảng read model ra file trước khi TRUNCATE
2. Bỏ CASCADE; TRUNCATE từng bảng trong transaction riêng
3. Cờ --yes-i-mean-it + in ra số dòng sẽ mất trước khi hỏi
4. Bỏ qua guard A5 khi đang ở chế độ replay (truyền replay_mode=True)
5. Giữ lại (không TRUNCATE) các dòng có is_seed = TRUE
6. Ghi rõ trong docstring: KHÔNG dùng được nếu sync_mutations đã prune
```

---

### 3.2. 🟠 `domain_to_sql` — tên "an toàn" nhưng chưa an toàn, và **không thực thi tự động**

`routers/metadata.py:200-245`. Hai vấn đề tách biệt.

**(a) Định danh cột không được khử độc.**
```python
safe_field = f'"{field}"' if not field.startswith('"') else field
```
Chỉ bọc dấu nháy kép, **không escape dấu nháy kép bên trong**. Một `field` chứa `"` thoát ra khỏi định danh:

```
field = 'x" = 1 OR "1'   →   "x" = 1 OR "1" = %s
```

`domain` đến từ bảng `record_rules` (JSONB) chứ không trực tiếp từ người dùng, nên đây là **injection bậc hai**, không phải lỗ hổng tức thì. Nhưng `record_rules` sẽ có admin UI ghi vào (P3.4/P3.5), và hàm đang được đặt tên `safe_field` khiến người đọc sau tin là đã an toàn.

**Sửa:** whitelist theo `field_registry` của đúng model đó, và thêm chốt chặn cứng:
```python
import re
if not re.fullmatch(r"[a-z_][a-z0-9_]{0,62}", str(field)):
    continue          # bỏ rule sai định dạng, ghi log cảnh báo
safe_field = f'"{field}"'
```

**(b) Nó không "áp tự động vào mọi query".**
Endpoint `GET /api/v1/rules/{model}/filter` (`metadata.py:270`) **trả về chuỗi WHERE cho người gọi**. Nó không được áp vào `/sync/pull`, không áp vào bất kỳ endpoint nghiệp vụ nào. Client có thể đơn giản là không gọi, hoặc gọi rồi bỏ qua.

DoD của P3.5 là *"biểu thức JSON áp **tự động** vào **mọi** query"* với tiêu chí nghiệm thu *"Nhân viên chỉ thấy job của bộ phận mình"*. Trả một mảnh SQL qua HTTP là **ngược lại** với thực thi tự động — và bản thân việc gửi SQL thô ra ngoài cũng không nên.

➔ P3.5 nên là **40%**, không phải 100%. Muốn đạt DoD: gọi `domain_to_sql` **bên trong** `pull_mutations` và các repository read, dựa trên role lấy từ device token — không để client tự quyết.

Ghi chú nhỏ: truy vấn chọn rule (`metadata.py:283-292`) không lọc `tenant_id`, chỉ dựa vào RLS của 0006. Đúng được là nhờ `get_db` truyền tenant từ header — nhưng nếu header vắng thì tenant là `'default'` và rule của tenant `'default'` áp cho mọi người.

---

### 3.3. 🟠 A5 đã đổi "mất im lặng" thành "từ chối tường minh" — nhưng vòng lặp chưa khép

A5 (`projector.py:150-170`) nay ném `ValueError` khi update tới một `id` không có trong read model. Đúng hướng: tốt hơn hẳn việc âm thầm bỏ qua. Nhưng:

**(a) Client chưa xử lý phản hồi.** Tôi đã grep `sync_service.dart`: **không có** `applied_ids`, **không có** `rejected`, **không có** `partial_success`, **không có** retry/backoff/dead-letter. **P0.6 vẫn nguyên ⬜.**

➔ Server nay nói rõ "mutation này tôi từ chối", nhưng client không nghe. Kết quả cuối cùng với người dùng vẫn là mất thay đổi — chỉ khác là lần này có dòng log. **A5 chỉ thực sự có giá trị sau khi P0.6 xong.** Hai việc này phải đi cùng nhau, không tách rời được.

**(b) Vẫn còn cửa sau im lặng.** Nếu bản ghi không có trong read model **nhưng có lịch sử trong `sync_mutations`**, A5 cho đi tiếp (dòng 166) → `_apply_column_merge_update` khớp **0 dòng** → không ném, không hook, không log. Đây đúng là tình huống xảy ra khi read model tụt sau event log — tức là tình huống mà B1 sinh ra để sửa. Nên thêm nhánh: `rows_affected == 0` → `logger.error` + đưa vào `rejected`.

**(c) Chi phí truy vấn.** Mỗi update trượt read model chạy:
```sql
SELECT 1 FROM sync_mutations
WHERE "table" = %s AND ((data::jsonb->>'id') = %s OR id = %s)
```
`data::jsonb->>'id'` là biểu thức **không có index** trên bảng lớn nhất hệ thống (đã hơn 58.000 seq). Cần:
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_mutations_data_id
  ON sync_mutations ((data::jsonb->>'id'), "table");
```

---

### 3.4. 🟡 Cron 22:00 dùng giờ local của tiến trình

`app.py:264` — `now = datetime.now()`, không timezone. Trên máy Windows hiện tại, giờ local là ACST nên chạy đúng ý. Nhưng repo đã có `Dockerfile`, `docker-compose.yml` và `iziiserver.service` cho Ubuntu — **container và systemd mặc định chạy UTC**. Khi đó 22:00 "local" = 22:00 UTC = **07:30 sáng hôm sau giờ Adelaide**, và bảng chấm công sẽ tổng hợp sai ngày.

Đây cũng đi ngược nguyên tắc P0.3/P0.9/F12 của chính dự án (mọi `datetime` phải aware).

**Sửa:**
```python
from zoneinfo import ZoneInfo
TZ = ZoneInfo(os.environ.get("IZIIAPP_TZ", "Australia/Adelaide"))
now = datetime.now(TZ)
target = now.replace(hour=22, minute=0, second=0, microsecond=0)
```

Ngoài ra kiểm tra `compute_and_save_daily_timesheets` — nếu là hàm đồng bộ gọi DB thì phải bọc `await asyncio.to_thread(...)`, không thì mỗi 22:00 event loop sẽ đứng.

---

## 4. Ba Hạng Mục Tuyên Bố Xong Nhưng Chưa Làm

| Ghi trong §0h.1 | Thực tế |
| :--- | :--- |
| **A6** — bỏ `except: pass` ở 4 vị trí | Làm được 3/5. **Còn sót:** `projector.py` `get_table_columns` vẫn `except → return set()` (mutation bị bỏ qua im lặng, giá trị trả về `False` của `project_mutation` vẫn không ai kiểm tra); `postgres_repo.py` phần đọc `cols` trong snapshot vẫn `except: pass`; `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ` bọc `try/except: pass` — nếu lỗi thì **âm thầm tụt về READ COMMITTED**, đúng cái mà A4 sinh ra để tránh. Nên để nó ném. |
| **A7** — test dọn dữ liệu bằng rollback teardown | **Chưa làm.** `grep "tearDown\|rollback()" tests/test_phase4_projector.py` → **0**. Tệ hơn: nay có thêm `test_savepoint_isolation_partial_batch_failure` **cố tình gây lỗi trên DB thật**. Rác test tiếp tục tích tụ trong `mushroom_jobs`, `mushroom_job_safety_configs`, `record_rules`, `grow_rooms`. |
| **Phase 2 · 45% → 55%** | **Không có thay đổi nào.** `modules/` vẫn chỉ có 4 file `manifest.json` + `module_manager.py`; không có `migrations/`, `hooks/`, `models/` trong bất kỳ module nào. Cột "Điều gì đã đổi" chép nguyên văn dòng cũ. |

**Số test:** đếm lại được **52** method `def test_` (7 test mới: 6 ở `test_phase4_projector.py`, 1 ở `test_phase3_metadata_api.py`), tài liệu ghi **51/51**. Lệch 1 — nhỏ, nhưng cùng loại với việc chấm điểm: nên đếm lại bằng lệnh thay vì ước lượng.

**Ba việc mới nhất đều không có test:** `rebuild_read_model.py` (B1 — script nguy hiểm nhất), cron 22:00 (B4), RLS 0006 (B2).

---

## 5. Chấm Lại Điểm

| Phase | §0h.2 mới ghi | Chấm lại theo DoD | Ghi chú |
| :--- | ---: | ---: | :--- |
| **0** | 98% | **90%** | A1 khôi phục P0.2 ✅. Nhưng **P0.6 vẫn ⬜ và nay là hạng mục chặn quan trọng nhất** (§3.3a); P0.13 vẫn chưa đo |
| **1** | 95% | **90%** | 0006 RLS ✅. P1.5 partition + P1.8 text search `vi` chưa xác minh |
| **2** | 55% | **45%** | Không có thay đổi nào so với sáng nay |
| **3** | 85% | **42%** | P3.5 25→40% ✅. Nhưng **P3.3, P3.6, P3.7 vẫn 0%** (grep không ra một dòng nào), P3.2b vẫn ~10% |
| **4** | 92% | **69%** | P4.1 100 · P4.2 **70** · P4.3 85 · P4.4 **0** (`NOT VALID` vẫn 0 kết quả) · P4.5 90 · P4.6 85 · P4.7 90 · P4.8 **30** (§3.1) |
| **5** | 88% | **70%** | P5.2 85 ✅ · P5.8 90 ✅ · P5.10 **0** · P5.11 **0** |
| **6, 7** | 0% | 0% | — |
| **Tổng** | **~85%** | **≈ 65%** | **Tăng thật 10 điểm so với 55% sáng nay** |

Nhìn theo hướng tích cực: **+10 điểm trong một buổi làm việc** là nhịp độ rất tốt. Nếu giữ được nhịp này và chấm đúng, Phase 0–5 có thể đóng trong 2–3 tuần.

---

## 6. Việc Tiếp Theo — Xếp Lại Ưu Tiên

**Chặn ngay (làm trước mọi thứ khác):**

| # | Việc | Vì sao gấp |
| ---: | :--- | :--- |
| 1 | **Đặt cảnh báo lên đầu `rebuild_read_model.py`** và không chạy nó cho tới khi làm xong 6 bước ở §3.1 | Một lần chạy nhầm là mất `mushroom_job_safety_configs`, seed và dữ liệu di trú, không khôi phục được |
| 2 | **P0.6 — client xử lý `rejected` / `applied_ids`** + retry backoff + dead-letter + hiển thị cho người dùng | A5 chỉ có giá trị khi client nghe. Hiện server từ chối, client không biết → người dùng vẫn mất thay đổi |
| 3 | **Index `sync_mutations ((data::jsonb->>'id'), "table")`** | A5 đang quét toàn bảng mỗi lần update trượt read model |

**Tuần này:**

4. `domain_to_sql`: whitelist tên cột theo `field_registry` + regex chốt chặn (§3.2a)
5. Áp record rules **bên trong** `pull_mutations` và các repo read, bỏ endpoint trả SQL thô (§3.2b) — đây mới là P3.5
6. Cron 22:00 dùng `ZoneInfo`, kiểm tra `compute_and_save_daily_timesheets` có chặn event loop không (§3.4)
7. A5 nhánh cửa sau: `rows_affected == 0` → `logger.error` + đưa vào `rejected` (§3.3b)
8. A6 nốt 3 chỗ còn sót; đặc biệt để `SET TRANSACTION ISOLATION LEVEL` ném lỗi thay vì nuốt (§4)
9. A7 teardown rollback cho test — nay đã có test cố tình gây lỗi trên DB thật (§4)
10. P4.4 `FK NOT VALID` — vẫn 0 kết quả trong toàn bộ `migrations/`

**Sau đó mới tới:** P3.3 (`entity_attributes`), P3.6 (`translations`), P3.7 (metadata qua sync), P3.2b (renderer Flutter), P5.10, P5.11, và Phase 2 thực chất (đưa hook + migration vào trong module).

---

## 7. Về Cách Ghi Bảng Điểm

Báo cáo trước đề nghị một quy tắc: *"Một hạng mục chỉ được tính ✅ khi có một test tự động chạy đúng câu chữ trong cột DoD."* Đợt này đã áp dụng đúng cho A1–A4 — và kết quả thấy rõ: bốn hạng mục đó tôi kiểm tra không tìm ra lỗi nào.

Chỗ chưa áp dụng là chỗ vẫn lệch: B1 được ghi 100% mà không có test nào; B3 ghi 100% trong khi DoD nói "áp tự động vào mọi query" còn mã chỉ trả về một chuỗi; Phase 2 và Phase 3 được cộng điểm cho những hạng mục chưa hề tồn tại.

Đề nghị thêm một quy tắc thứ hai, nhẹ hơn:

> **Điểm của một Phase = trung bình điểm các hạng mục P*x* của nó, tính riêng từng cái.** Không gộp, không làm tròn lên. Hạng mục chưa có mã thì ghi 0 và **để lộ ra trong bảng** — một Phase 42% với ba mục 0% nói nhiều hơn một Phase 85% giấu chúng đi.

Áp quy tắc này thì Phase 3 không thể lên 85% khi `entity_attributes`, `translations` và đồng bộ metadata đều chưa viết dòng nào — và chính điều đó giữ cho bảng điểm còn dùng được để ra quyết định.

---

*Kiểm chứng lần 2 ngày 17/09/2026 · diff tài liệu + đọc mã nguồn trực tiếp · chưa chạy được test suite.*
