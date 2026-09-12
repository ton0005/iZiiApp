# Đánh Giá Log iZiiServer 12/09/2026 — Kiểm Chứng & Bổ Sung Cho `IZIISERVER_SYNC_LATENCY_ANALYSIS.md`

- **Nguồn:** `%LOCALAPPDATA%\iZiiApp\server\logs\server.log` (61.713 dòng, 4,03 MB, ghi tới 11:49 UTC = 21:19 ACST)
- **Phạm vi hôm nay:** dòng 38.268 → 61.713, tương ứng **02:02 → 11:47 UTC (11:32 → 21:17 ACST)**, gồm **5 phiên server** (5 lần restart)
- **Đối chiếu code:** `server/app.py`, `server/routers/devices.py`, `server/repository/postgres_repo.py`, `lib/core/sync/sync_service.dart`

---

## 1. Kết Luận Ngắn

Báo cáo phân tích hiện có **chẩn đoán đúng 2 nguyên nhân quan trọng nhất** (cờ `_isSyncing` bị chiếm dụng, và hạ tầng Dev Tunnels), nhưng:

- **Sai 1 điểm:** quy kết cho "SQLite file lock contention" — server hôm nay chạy **PostgreSQL**, không phải SQLite.
- **Bỏ sót 5 nguyên nhân phía server**, trong đó có **2 lỗi nghiêm trọng hơn cả hạ tầng mạng**: toàn bộ truy vấn DB là đồng bộ (blocking) nằm trong `async def`, và server đang chạy chế độ `reload=True`.
- **Bỏ sót 1 lỗi cấu hình** khiến 1 thiết bị **không thể kết nối WebSocket suốt phiên** → phải polling nặng nhất trong 4 máy.
- **Bỏ sót 1 rủi ro đúng-sai dữ liệu:** timestamp trộn lẫn naive-local (ACST) và UTC trong cùng luồng sync.

Ưu tiên sửa: **client retry queue → server blocking I/O → tắt reload → giảm polling → đổi tunnel**. Đổi tunnel (việc tốn công nhất) chỉ nên làm sau 4 bước trên, vì độ trễ đo được **không có hình dạng của độ trễ mạng**.

---

## 2. Số Liệu Đo Được Hôm Nay

### 2.1. Phân bố độ trễ PUSH (19 lô, toàn ngày)

Tính bằng `server_received_at (UTC+9:30)` − `timestamp sớm nhất trong payload`:

| Chỉ số | Giá trị |
| :--- | ---: |
| Số lô PUSH | 19 |
| Nhỏ nhất | **≈ 0 s** |
| Trung vị (median) | **24,2 s** |
| p90 | **59,5 s** |
| Lớn nhất | **495,6 s** (8 phút 16 giây) |

Chi tiết các lô đáng chú ý:

```
dòng    n  server_utc            acst      thay đổi sớm nhất   trễ
 927    3  2026-09-12 02:02:44   11:32:44  11:32:44            -0,4 s
1335    3  2026-09-12 02:05:13   11:35:13  11:35:12             0,3 s
3637    2  2026-09-12 02:20:01   11:50:01  11:49:19            42,7 s
4511   13  2026-09-12 02:26:58   11:56:58  11:56:58            -0,3 s
8271    4  2026-09-12 03:51:24   13:21:24  13:20:24            59,5 s
19445   1  2026-09-12 10:53:28   20:23:28  20:21:54            93,8 s
22862   2  2026-09-12 11:44:31   21:14:31  21:06:15           495,6 s  ← 8 phút
23375   6  2026-09-12 11:47:37   21:17:37  21:16:54            43,1 s  ← lô báo cáo cũ trích dẫn
```

> **Đây là bằng chứng quan trọng nhất.** Phân bố này là **lưỡng cực (bimodal)**: hoặc ~0 giây, hoặc 20–60 giây trở lên. **Không có giá trị nào ở khoảng 2–15 giây.**
>
> Nếu thủ phạm chính là RTT của Dev Tunnels (150–600 ms/request như báo cáo cũ nêu), độ trễ phải **phân bố đều và tăng dần** — mọi lô đều chậm một chút. Thực tế là hoặc tức thì, hoặc kẹt hẳn một chu kỳ polling. Đó chính xác là chữ ký của **một mutation bị `triggerSync()` trả `false` và nằm chờ chu kỳ kế tiếp**, không phải chữ ký của mạng chậm.
>
> ➔ **Sửa cơ chế retry queue phía client sẽ giải quyết được phần lớn độ trễ, kể cả khi vẫn giữ nguyên Dev Tunnels.**

Trường hợp 495,6 s ở dòng 22862 nằm ngoài mẫu hình trên — trùng thời điểm WebSocket đứt, thiết bị mất luôn `sync_trigger` và phải chờ chu kỳ ngầm 3 phút của `sync_service.dart`.

### 2.2. Tải request toàn ngày (sau khi lọc mã màu ANSI)

Tổng **7.896 request** hôm nay / **20 lần `/sync/push`** → **tỉ lệ 395 : 1**.

| Endpoint | Số lượng (cả ngày) |
| :--- | ---: |
| `GET /api/v1/devices/online` | **3.834** |
| `GET /api/v1/messages/pending` | **1.640** |
| `GET /sync/pull` | **1.555** |
| `POST /api/v1/devices/heartbeat` | **615** |
| `GET /sync/status` | 88 |
| `POST /sync/push` | **20** |
| 401 Unauthorized (`/devices/me`, `/sessions/current`, `/sessions/pin/status`) | **35** |

Riêng cửa sổ 25 phút cuối (dòng 14.627–23.093) có **2.962 request** — khớp chính xác con số trong báo cáo cũ, xác nhận hai bên đọc cùng một phiên.

**Hiệu suất polling:** trong 1.527 lần `/sync/pull` có log chi tiết, **1.477 lần trả về `Sending 0 records`** → **96,7 % request pull là vô ích**.

### 2.3. Tải theo từng thiết bị

| Thiết bị | IP | Số request |
| :--- | :--- | ---: |
| `izii-d-c4a94f0f` | — | 2.473 |
| `izii-d-2a129af8` | — | 1.437 |
| `izii-d-1093d407` | — | 1.025 |
| `izii-d-dd43cd39` | — | 516 |
| — | `120.20.173.93` | **4.075** |
| — | `120.20.130.114` | 2.873 |
| — | `10.198.151.213 / .200` (đường hầm nội bộ) | 717 |

### 2.4. Tình trạng WebSocket

| Sự kiện | Số lần |
| :--- | ---: |
| Client connected | 39 |
| Client disconnected | **37** |
| `Broadcast heartbeat` | **793** |
| `Broadcasted sync_trigger` | 20 |
| `presence_update` | 39 |
| **Từ chối kết nối — sai secret** | **19** |

---

## 3. Đối Chiếu Với `IZIISERVER_SYNC_LATENCY_ANALYSIS.md`

### 3.1. Những điểm báo cáo cũ nói ĐÚNG (log xác nhận)

| Luận điểm | Bằng chứng kiểm chứng |
| :--- | :--- |
| Độ trễ 43,07 s tại lô PUSH 21:17:37 | ✅ Tính lại được **43,1 s**. Chính xác. |
| 2.962 request trong 25 phút | ✅ Khớp tuyệt đối với phiên dòng 14.627–23.093. |
| `triggerSync()` drop khi `_isSyncing == true`, không có retry | ✅ `sync_service.dart:190-192` — `if (_isSyncing) return false;` đúng nguyên văn. |
| `addMutation` debounce 300 ms rồi gọi `triggerSync` | ✅ `sync_service.dart:1373-1375`. |
| `_uploadPendingAttachments()` quét toàn bảng | ✅ `sync_service.dart:401` — `_db.select(_db.chatMessages).get()`, không WHERE, nằm ngay trước bước PUSH (dòng 207). |
| WebSocket rớt liên tục | ✅ 37 lần disconnect / 39 lần connect trong 1 ngày. |
| Polling quá nhiều so với dữ liệu thật | ✅ Tỉ lệ 395 request : 1 push; 96,7 % pull trả về rỗng. |

### 3.2. Điểm báo cáo cũ nói SAI

**"Nguyên nhân 4: Áp lực đọc/ghi đồng thời trên SQLite của Server"** — không đúng với cấu hình hiện tại.

Log khởi động của cả 5 phiên hôm nay đều ghi:

```
🐘 [PG] Connection pool sẵn sàng (min=1, max=10)
🐘 [PG] Schema PostgreSQL và cấu hình Phase 1 + Phase 2 đã sẵn sàng.
✅ Production PRAGMAs applied: WAL, NORMAL sync, busy_timeout=5000, cache=64MB, mmap=256MB
🗄️  Database backend: postgres
```

`.env` xác nhận `IZIIAPP_DB_BACKEND=postgres`, `IZIIAPP_PG_DSN=postgresql://...@127.0.0.1:5432/iZiiApp`.

Dòng "Production PRAGMAs applied: WAL..." là **log thừa còn sót lại từ nhánh SQLite** — nó vẫn in ra dù backend là Postgres, và chính dòng này đã dẫn dắt báo cáo cũ tới kết luận sai. Bản thân nó cũng là một lỗi cần dọn (mục 5.6).

Hệ quả: **không có tranh chấp file lock**. Nghẽn DB nếu có thì đến từ nguyên nhân khác — xem mục 4.1.

### 3.3. Những gì báo cáo cũ BỎ SÓT

Đây là phần có giá trị bổ sung lớn nhất.

---

## 4. Nguyên Nhân Bổ Sung (xếp theo mức ảnh hưởng)

### 4.1. ⛔ Toàn bộ truy vấn DB là đồng bộ, chặn event loop — NGHIÊM TRỌNG

`routers/devices.py:111-118`:

```python
@router.get("/online")
async def devices_online(user_id: Optional[str] = None,
                         exclude_device_id: Optional[str] = None,
                         repo: IDeviceRepository = Depends(get_device_repo)):
    devices = repo.get_online(user_id, exclude_device_id)   # ← hàm ĐỒNG BỘ
    print(f"\n📡 [ONLINE] Queried online devices → {len(devices)} active")
    return {"devices": devices}
```

- `repository/postgres_repo.py:343` khai báo `def get_online(...)` — **không phải `async def`**.
- `db_postgres.py` dùng **`psycopg` + `psycopg_pool.ConnectionPool`** (driver đồng bộ), không phải `asyncpg`.
- Toàn bộ router có **47 endpoint `async def`** đang gọi các repo đồng bộ như vậy.

**Hậu quả:** trong FastAPI, một `async def` chạy thẳng trên event loop. Mỗi lời gọi DB đồng bộ **đóng băng toàn bộ server** cho tới khi query xong — kể cả WebSocket broadcast và `/sync/push` đang chờ.

Với **3.834 lần `/online` + 1.640 lần `/pending` + 1.555 lần `/pull`**, event loop bị chặn gần 7.000 lần/ngày. Pool `max=10` **hoàn toàn vô nghĩa** vì chỉ có đúng một luồng gọi vào nó — khả năng đồng thời thực tế là **1**.

Đây là lý do vì sao một `triggerSync()` qua tunnel kéo dài 1.500–3.500 ms như báo cáo cũ ghi nhận: phần lớn thời gian đó không phải RTT mạng, mà là **xếp hàng sau các query `/online` của 3 máy khác**.

### 4.2. ⛔ Server chạy chế độ `reload=True` — 5 lần restart trong 1 ngày

`app.py:636-644`:

```python
print("\n🚀 Starting iZiiApp Standalone Server v2.0 in Development Mode...")
uvicorn.run("app:app", host="0.0.0.0", port=target_port,
            reload=True,
            reload_dirs=["./"],
            reload_excludes=["build", ".dart_tool", ".git", "data", "__pycache__", "certs"],
            **ssl_kwargs)
```

Log cảnh báo ngay dòng kế tiếp:

```
WARNING:  --reload-include and --reload-exclude have no effect unless watchfiles is installed.
INFO:     Started reloader process [3488] using StatReload
```

Hai vấn đề cộng hưởng:

1. **`watchfiles` chưa cài** → `reload_excludes` **không có tác dụng**, `StatReload` fallback sang `os.stat()` **toàn bộ `./`**. Thư mục server hiện có **2.650 file** (riêng `dist/` 964 file). StatReload quét mỗi 0,25 s → **~10.600 lời gọi stat()/giây** trên ổ đĩa Windows, chạy song song với server.
2. **Mỗi lần reload là một lần mất toàn bộ WebSocket.** Hôm nay log ghi nhận 5 lần `Starting iZiiApp ... Development Mode` / `Application startup complete`. Mỗi lần như vậy tất cả client mất `sync_trigger`, và phải chờ retry — đủ để giải thích lô PUSH trễ 495 s.

Báo cáo cũ quy toàn bộ việc WS rớt cho idle timeout của Dev Tunnels. Một phần đáng kể thực ra là **server tự restart**.

### 4.3. ⚠️ Một thiết bị KHÔNG THỂ kết nối WebSocket — sai secret

Log ghi **19 lần** trong khoảng dòng 2.816–4.226:

```
🔌 [WS] Từ chối kết nối từ Address(host='120.20.173.93', port=0):
   Client gửi nhầm ADMIN SECRET (iZiiAd...) thay vì WS_SECRET/SERVER_SECRET.
   Cần cấu hình client dùng IZIIAPP_WS_SECRET.
```

IP `120.20.173.93` cũng chính là **client tạo nhiều request nhất trong ngày: 4.075 request** — đúng như dự đoán cho một máy mất realtime và phải polling bù.

Đây là **lỗi cấu hình một dòng**, sửa xong giảm ngay ~50 % tải server và đưa máy đó về realtime. Báo cáo cũ không hề nhắc tới.

### 4.4. ⚠️ Ghi log đồng bộ, flush từng dòng, ngay trong event loop

`app.py:44-52` — `DualLogger.flush()` gọi `log_file.flush()`; `app.py:89` mở file chế độ `"a"`. Mỗi `print()` trong handler (ví dụ `📡 [ONLINE] ...` ở `devices.py:117`) là **một lần ghi + flush xuống đĩa, đồng bộ, trên event loop**.

Hôm nay: **61.713 dòng / 4,03 MB** cho một ngày với 4 thiết bị. Riêng `[ONLINE]` là 3.744 dòng, mỗi khối `[PULL]` 4 dòng × 1.527 lần.

Ngoài chi phí I/O, cơ chế xoay vòng log ở `app.py:14-20` chỉ đổi tên khi vượt 10 MB và **chỉ giữ đúng 1 file `.old`** (hiện `server.log.old` = 14,8 MB) — không giới hạn được dung lượng lâu dài.

### 4.5. ⚠️ Hai tầng polling chồng lên nhau

Báo cáo cũ chỉ nêu timer 5 giây trong `chat_bloc.dart`. Nhưng `sync_service.dart:116` còn có timer riêng:

```dart
_periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) => triggerSync(isManual: false));
```

Nghĩa là có **hai nguồn độc lập cùng giành cờ `_isSyncing`**. Khi sửa retry queue phải xử lý cả hai, nếu không sẽ vẫn còn trường hợp mutation bị kẹt tới 3 phút (đúng như lô trễ 93,8 s và 495,6 s).

### 4.6. 🐞 Timestamp trộn naive-local (ACST) và UTC — rủi ro SAI DỮ LIỆU

Trong cùng một khối PUSH, log cho thấy hai hệ quy chiếu thời gian khác nhau:

```
📥 [PUSH] Received 6 changes at 2026-09-12T11:47:37.887324+00:00   ← UTC, có tzinfo
       - completed_at: 2026-09-12T21:16:54.813396                  ← naive, thực chất là ACST
```

Ở endpoint pull, hai client gửi hai định dạng khác nhau:

```
🕐 Filtered since: 2026-09-12T11:28:33.004293                      ← naive
🕐 Filtered since: 2026-09-12T01:58:38.015723+00:00                ← UTC
```

Hai giá trị này **lệch nhau 9 giờ 30 phút**. Bất kỳ so sánh `updated_at` nào dùng cho giải quyết xung đột (last-write-wins) hoặc lọc `since` đều có nguy cơ sai lệch 9,5 giờ — có thể **âm thầm ghi đè bản ghi mới bằng bản ghi cũ**. Đây là lỗi đúng-sai, không phải lỗi hiệu năng, và nên được xử lý sớm.

Tin tốt: server đã hỗ trợ `after_seq` và **1.405/1.527 lần pull đã dùng cơ chế này**. Chỉ còn **122 lần dùng `since` cũ** (server tự cảnh báo `che do cu — nen chuyen sang after_seq`). Dứt điểm được `since` là loại bỏ hẳn nhóm rủi ro này.

### 4.7. ℹ️ 35 request trả về 401

`GET /devices/me` (16), `GET /sessions/current` (14), `GET /sessions/pin/status` (4), `POST /sessions/start` (1). Không gây chậm, nhưng cho thấy luồng khôi phục phiên đang thử-và-lỗi mỗi lần khởi động app. Nên kiểm tra lại thứ tự nạp token.

---

## 5. Kế Hoạch Khắc Phục Theo Thứ Tự Ưu Tiên

### P0 — Làm ngay, chi phí thấp, hiệu quả cao nhất

**5.1. Cấu hình lại WS secret cho thiết bị `120.20.173.93`** *(5 phút)*

Client đang gửi `IZIIAPP_ADMIN_SECRET` vào `ws://<host>:8080/chat?token=...`. Đổi sang `IZIIAPP_WS_SECRET`. Riêng việc này cắt ~50 % request trong ngày.

**5.2. Tắt `reload` khi vận hành thật** *(10 phút)*

```python
dev_reload = os.environ.get("IZIIAPP_DEV_RELOAD", "0") == "1"
uvicorn.run("app:app" if dev_reload else app,
            host="0.0.0.0", port=target_port,
            reload=dev_reload,
            reload_dirs=["./routers", "./repository"],   # KHÔNG dùng "./"
            **ssl_kwargs)
```

Và nếu vẫn cần reload khi dev: `pip install watchfiles` — không có nó thì `reload_excludes` vô hiệu.

**5.3. Gỡ blocking DB khỏi event loop** *(1–2 giờ)*

Cách nhanh và an toàn nhất: **bỏ `async` ở những endpoint chỉ gọi repo đồng bộ**. FastAPI sẽ tự đẩy chúng sang threadpool:

```python
@router.get("/online")
def devices_online(user_id: Optional[str] = None,          # bỏ 'async'
                   exclude_device_id: Optional[str] = None,
                   repo: IDeviceRepository = Depends(get_device_repo)):
    return {"devices": repo.get_online(user_id, exclude_device_id)}
```

Với endpoint bắt buộc phải `async` (có `await` WS broadcast), bọc lời gọi DB lại:

```python
from starlette.concurrency import run_in_threadpool
devices = await run_in_threadpool(repo.get_online, user_id, exclude_device_id)
```

Sau khi chuyển, nâng `IZIIAPP_PG_POOL_MAX` lên ≥ 20 (hiện 10) để khớp với threadpool mặc định 40 luồng của Starlette, tránh đổi nghẽn từ event loop sang pool.

**5.4. Thêm hàng đợi retry cho `triggerSync()`** *(30 phút)*

Đúng như báo cáo cũ đề xuất, nhưng cần bổ sung để tránh vòng lặp vô tận:

```dart
bool _syncQueued = false;

Future<bool> triggerSync({bool isManual = false}) async {
  if (_isSyncing) {
    _syncQueued = true;          // ghi nhận, chạy bù ngay sau khi xong
    return false;
  }
  _isSyncing = true;
  try {
    // ... PUSH + PULL như cũ ...
  } finally {
    _isSyncing = false;
    if (_syncQueued) {
      _syncQueued = false;
      // scheduleMicrotask sẽ chạy trước cả I/O tiếp theo
      Future.delayed(const Duration(milliseconds: 50),
                     () => triggerSync(isManual: isManual));
    }
  }
}
```

**Bổ sung quan trọng (báo cáo cũ chưa nêu): tách đường PUSH ra khỏi đường PULL.** Thao tác của người dùng chỉ cần đẩy outbox lên — không cần chờ `_uploadPendingAttachments()` và `/sync/pull` của chu kỳ nền:

```dart
Future<bool> flushOutbox() async {          // dùng riêng cho addMutation
  if (_isPushing) { _pushQueued = true; return false; }
  _isPushing = true;
  try {
    final mutations = await _outbox.getPendingMutations();
    if (mutations.isEmpty) return true;
    return await _pushMutations(mutations);   // KHÔNG gọi attachment/pull
  } finally { ... }
}
```

rồi đổi `sync_service.dart:1374` gọi `flushOutbox()` thay vì `triggerSync()`. Với thay đổi này, độ trễ do thao tác người dùng **không còn phụ thuộc vào chu kỳ nền nữa**.

**5.5. Sửa `_uploadPendingAttachments()`** *(15 phút)*

`sync_service.dart:401` — thêm điều kiện lọc thay vì tải cả bảng:

```dart
final pending = await (_db.select(_db.chatMessages)
      ..where((t) => t.attachmentPath.isNotNull() & t.attachmentUrl.isNull())
      ..limit(20))
    .get();
```

**5.6. Giảm tải ghi log** *(30 phút)*

- Bỏ `flush()` mỗi dòng trong `DualLogger` — chỉ flush theo chu kỳ (ví dụ mỗi 2 giây bằng một task nền) hoặc khi log mức WARNING trở lên.
- Hạ `print()` của `[ONLINE]` và `[PULL]` xuống mức DEBUG, bật bằng biến môi trường `IZIIAPP_LOG_VERBOSE=1`. Riêng hai chỗ này chiếm ~60 % dung lượng log.
- Chuyển sang `logging.handlers.RotatingFileHandler(maxBytes=10MB, backupCount=5)` thay cho cơ chế đổi tên thủ công ở `app.py:14-20`.
- Xoá dòng `"✅ Production PRAGMAs applied: WAL..."` khi backend là postgres — chính nó gây hiểu nhầm trong phân tích trước.

### P1 — Sửa kiến trúc realtime (tuần này)

**5.7. Coi WebSocket là kênh chính, polling chỉ là lưới an toàn**

Server đã phát sẵn `presence_update`, `sync_trigger` (kèm danh sách bảng), `e2ee_message`, `msg_read`. Nghĩa là **cả ba endpoint polling nặng nhất đều đã có tương đương realtime**:

| Đang polling | Đã có sự kiện WS tương ứng | Hành động |
| :--- | :--- | :--- |
| `GET /devices/online` (3.834) | `presence_update` | Bỏ hẳn polling, dựng bảng presence từ WS |
| `GET /messages/pending` (1.640) | `e2ee_message` | Chỉ pull khi vừa reconnect |
| `GET /sync/pull` (1.555) | `sync_trigger` | Chỉ pull khi nhận trigger hoặc reconnect |

Sửa `chat_bloc.dart` theo hướng có trạng thái, chứ không chỉ giãn timer:

```dart
_pullTimer = Timer.periodic(const Duration(seconds: 30), (_) {
  if (_wsService.isConnected) return;     // WS khoẻ → không polling
  add(PullEncryptedMessagesEvent());
  add(RefreshPresenceEvent());
  SyncService().triggerSync();
});
_wsService.onReconnected = () {           // reconnect → đồng bộ bù đúng 1 lần
  add(PullEncryptedMessagesEvent());
  SyncService().triggerSync(isManual: true);
};
```

Ước tính giảm từ ~7.900 xuống **dưới 400 request/ngày**.

**5.8. Giữ WebSocket sống qua tunnel**

- Ping ở tầng ứng dụng mỗi **20 giây** (ngắn hơn idle timeout của hầu hết relay).
- Reconnect với backoff luỹ thừa + jitter: 1 s → 2 s → 4 s → 8 s → tối đa 30 s.
- **Kèm `seq` vào `sync_trigger`.** Khi reconnect, client so `last_seq` cục bộ với `seq` mới nhất; lệch thì pull bù đúng một lần. Như vậy WS rớt không còn dẫn tới mất dữ liệu realtime.
- Giảm broadcast thừa: hiện `heartbeat` được broadcast **793 lần cho mọi client**. Heartbeat của máy A không cần gửi cho máy B, C — chỉ phát `presence_update` khi trạng thái **thay đổi** (hôm nay chỉ 39 lần, tức 95 % lượng broadcast là thừa).

**5.9. Dứt điểm chế độ `since`, chuyển 100 % sang `after_seq`**

Còn 122 lần pull dùng `since`. Chuẩn hoá **mọi** timestamp sang UTC có tzinfo ở cả client lẫn server (`DateTime.now().toUtc()` phía Dart; `datetime.now(timezone.utc)` phía Python), và ép server từ chối tham số `since` thiếu tzinfo thay vì đoán. Đây là việc xử lý rủi ro dữ liệu ở mục 4.6.

**5.10. Long-poll cho `/sync/pull` khi không có WS**

Khi client buộc phải polling, cho server giữ request tối đa 25 giây và trả về ngay khi có mutation mới. Một request thay cho 8–10 request rỗng, và độ trễ vẫn dưới 1 giây.

### P2 — Hạ tầng (sau khi P0/P1 ổn định)

**5.11. Thay VS Code Port Forwarding**

Đồng ý với báo cáo cũ, nhưng với thứ tự ưu tiên khác:

| Phương án | Phù hợp khi | Lưu ý |
| :--- | :--- | :--- |
| **Tailscale** (khuyến nghị) | 4 thiết bị cố định của trang trại | WireGuard đi thẳng khi có thể, RTT thấp nhất, không giới hạn WS, miễn phí ở quy mô này |
| **Cloudflare Tunnel** | Cần cho người ngoài truy cập, có tên miền | WS ổn định, có edge ở Sydney; nhưng vẫn qua relay |
| VS Code Dev Tunnels | Chỉ để debug | Không dành cho vận hành nhiều thiết bị |

**Nhưng hãy đo lại sau khi xong P0.** Phân bố lưỡng cực ở mục 2.1 cho thấy tunnel **không phải** thủ phạm chính; đổi tunnel trước khi sửa client sẽ tốn công mà chỉ cải thiện được phần nhỏ.

**5.12. Không chạy nhiều worker**

Trạng thái WebSocket đang nằm trong tiến trình. Nếu sau này cần `--workers > 1`, bắt buộc phải có Redis Pub/Sub để broadcast xuyên worker. Ở quy mô 4 thiết bị, **1 worker + sửa blocking I/O (5.3) là đủ và đơn giản hơn nhiều**.

---

## 6. Chỉ Số Cần Theo Dõi Sau Khi Sửa

Chạy lại đúng phép đo ở mục 2.1 trên log của một ngày vận hành bình thường:

| Chỉ số | Hôm nay | Mục tiêu sau P0 | Mục tiêu sau P1 |
| :--- | ---: | ---: | ---: |
| Độ trễ PUSH — trung vị | 24,2 s | < 3 s | **< 1 s** |
| Độ trễ PUSH — p90 | 59,5 s | < 8 s | **< 2 s** |
| Độ trễ PUSH — lớn nhất | 495,6 s | < 30 s | **< 5 s** |
| Request/ngày (4 máy) | 7.896 | ~4.000 | **< 400** |
| Tỉ lệ `/sync/pull` trả về rỗng | 96,7 % | 95 % | **< 30 %** |
| Số lần WS disconnect/ngày | 37 | < 10 | **< 5** |
| Số lần server restart/ngày | 5 | **0** | 0 |
| Dung lượng log/ngày | 4,03 MB | **< 300 KB** | < 300 KB |

---

## 7. Thứ Tự Thực Hiện Gợi Ý

```
Ngày 1  →  5.1 (WS secret)  +  5.2 (tắt reload)  +  5.6 (log)
           Chi phí ~1 giờ. Dự kiến cắt ~50 % tải, hết restart giữa ngày.

Ngày 2  →  5.4 (retry queue + flushOutbox)  +  5.5 (attachment query)
           Chi phí ~2 giờ. Đây là bước xoá bỏ độ trễ 24–60 s.
           ĐO LẠI NGAY sau bước này trước khi làm tiếp.

Ngày 3  →  5.3 (gỡ blocking DB)  +  nâng PG_POOL_MAX
           Chi phí ~2 giờ. Ổn định độ trễ khi nhiều máy cùng hoạt động.

Tuần 2  →  5.7 → 5.10 (WS làm kênh chính, after_seq, long-poll)

Tuần 3  →  5.11 (đổi tunnel), chỉ nếu số đo sau P1 vẫn chưa đạt mục tiêu
```

---

*Báo cáo lập ngày 12/09/2026 dựa trên `server.log` (61.713 dòng) và mã nguồn `server/`, `lib/core/sync/`.*
