# Hướng dẫn DEV — Hytera Radio Bridge

Dành cho dev nhận tiếp `radio_bridge/`. Đọc hết mục 1–4 trước khi sửa code; mục 9 là việc phải làm khi có tài liệu ADK.
Tóm tắt nhanh để chạy: xem [README.md](README.md). Bối cảnh nghiệp vụ: `plan/Hytera/HUONG_DAN_TICH_HOP_HYTERA.md`,
`plan/Hytera/NGHIEN_CUU_OK_DMRLIB.md`.

---

## 1. Bridge làm gì và vì sao tồn tại

Công nhân Costa mang bộ đàm Hytera HP682. Bộ đàm tự phát hiện **Lone Worker hết giờ**, **Man Down** (cảm biến nghiêng) và
**nút SOS**, rồi gửi báo động qua sóng DMR tới repeater **HR1062**. iZiiApp đã có luồng *Alone Worker* (đồng hồ trong app,
phòng chuyển đỏ, đồng bộ mọi máy). Bridge nối hai thế giới: lấy báo động từ hệ thống Hytera đưa vào luồng đó.

```
HP682 ──RF──▶ HR1062 ──IP/UDP (HSTRP + HDAP)──▶ [Radio Bridge] ──HTTPS──▶ iZiiServer ──sync/WebSocket──▶ iZiiApp
                                                    │ radio_bridge/          POST /api/v1/radio/events
                                                    └ spool/ (đĩa)           server/routers/radio_gateway.py
```

* **Bridge** = tiến trình Python riêng, chạy gần repeater. Việc của nó: nhận gói UDP → giải mã → sinh sự kiện → giao bền
  vững cho server. **Không** quyết định nghiệp vụ.
* **Server** (`server/routers/radio_gateway.py`, đã xong, có test) mới là nơi: tra Radio ID → nhân viên → job Alone Worker,
  bật `alarm_triggered`, đưa phòng về `alone_timeout`, gộp báo động lặp, lưu nhật ký kiểm toán.
* **Không đổi** hợp đồng HTTP giữa hai bên nếu không có lý do mạnh: server, app và tài liệu triển khai đều dựa vào nó.

**Ngoài phạm vi** (đừng làm trong bridge): đếm giờ Lone Worker (bộ đàm tự làm), logic nhân viên/job (server), giao diện (app),
gửi lệnh ngược xuống bộ đàm (giai đoạn 2, mục 10).

## 2. Mức độ tin cậy hiện tại — ĐỌC KỸ

| Hạng mục | Trạng thái |
|---|---|
| Bridge ↔ server (HTTP, spool, retry, auth, hợp đồng) | **Đã kiểm chứng** bằng test + chạy với server thật (SQLite) |
| Bridge ↔ thư viện ok-dmrlib (giải mã, ACK, dedup gói) | **Đã kiểm chứng** với gói do simulator dựng |
| Bridge ↔ **HR1062 / HP682 thật** | **CHƯA kiểm chứng. Chưa có gói thật nào được giải mã.** |

Hệ quả: test xanh chỉ nói bridge *nhất quán với ok-dmrlib*. Simulator dựng gói bằng cùng thư viện nên **không thể** phát
hiện ta hiểu sai ý nghĩa bản tin. Đừng coi bridge là sẵn sàng cho môi trường thật khi chưa làm mục 9.

Các **giả định** đang nằm trong code (đầu `codec.py`), mỗi cái phải được ADK/gói thật xác nhận hoặc bác bỏ:

| # | Giả định | Nếu sai thì |
|---|---|---|
| A1 | `RadioStatusReport.value != 0` = đang xảy ra, `0` = kết thúc | Báo động bị coi là huỷ (hoặc ngược lại) |
| A2 | Repeater báo khẩn cấp bằng `RepeaterBroadcastTransmitStatus`, `call_type` ∈ {EmergencyAlarm 0x05, EmergencyAlarmCall 0x0C, EmergencyGroupCall 0x03}, `sender_id` = bộ đàm phát | Không nhận được báo động nào qua repeater |
| A3 | HP682 ở xa **báo được qua RCP status** (`MAN_DOWN`, `EMERGENCY`) | Đường "radio_status" vô dụng; chỉ còn đường repeater |
| A4 | Radio ID = 3 byte cuối của IP nguồn (`subnet.b1.b2.b3`) cho gói radio_status | Sai ID → báo động gắn nhầm người (**nghiêm trọng**) |
| A5 | Cổng UDP 3002/3003/3005, bridge chỉ lắng nghe (passive) | Không nhận được gì; hoặc bridge phải chủ động kết nối |
| A6 | Qua repeater, Man Down / Lone Worker hết giờ đều đến như "emergency" (Hytera nói vậy) → không phân biệt được | Nếu phân biệt được, nên tách loại sự kiện |
| A7 | (chiều xuống) Hỏi/bật Lone Worker bằng RCP 0x00ED/0x00EE với bố cục payload **tự đặt** (`FUNCTION_LONE_WORKER = 0x01`; trả lời `[kết quả, chức năng, trạng thái]`) | Bộ đàm thật không hiểu → lệnh "không trả lời". Có thể HP682 không hỗ trợ đổi Lone Worker qua mạng (chỉ qua CPS) |
| A8 | (chiều xuống) Gửi thẳng tới địa chỉ UDP bộ đàm đã dùng khi gửi lên | Qua repeater thật, gói xuống một Radio ID có thể phải đi đường khác |

> A4 đáng sợ nhất: gắn báo động nhầm công nhân nghĩa là cứu nhầm người. Khi có gói thật, xác nhận A4 **đầu tiên**, bằng
> cách bấm SOS trên một bộ đàm đã biết ID và đối chiếu.

## 3. Môi trường phát triển (Windows)

Cần **hai** môi trường Python vì server và bridge có phụ thuộc khác nhau:

| Việc | Python | Cài |
|---|---|---|
| Chạy bridge, simulator, test của bridge | venv riêng cho bridge | `pip install -r radio_bridge/requirements.txt pytest` |
| Chạy iZiiServer thật (cho `full_chain_local`) | Python đang chạy server của dự án | `pip install -r server/requirements.txt` |

```bash
python -m venv C:\venvs\okv                # ĐỪNG đặt venv trong thư mục dự án/OneDrive (xem mục 14)
C:\venvs\okv\Scripts\pip install -r radio_bridge/requirements.txt pytest
C:\venvs\okv\Scripts\python -m pytest radio_bridge/tests -q          # 30 test, ~45 s
```

Chạy từ **thư mục gốc repo** (không phải trong `radio_bridge/`): `conftest.py` thêm thư mục gốc vào `sys.path`.

Test server liên quan (từ `server/`): `python -m unittest tests.test_radio_gateway` (20 test, SQLite trong bộ nhớ).

## 4. Cấu trúc code

```
radio_bridge/
  __main__.py        CLI: python -m radio_bridge ...            (argparse, dựng cấu hình, chạy asyncio)
  config.py          BridgeConfig (dataclass) + from_env()
  bridge.py          RadioBridge: UDP, dedup gói, gộp broadcast repeater, tạo payload, capture, thống kê
  codec.py           ★ duy nhất dùng ok-dmrlib: HDAP → RadioEvent         (thay khi có ADK)
  delivery.py        Delivery: spool đĩa + hàng đợi + HTTP retry
  simulator.py       SimLink / SimHR1062 / SimHP682 + CLI
  mock_izii.py       iZiiServer giả (kiểm token, chèn lỗi, kiểm hợp đồng bằng server/radio_events.py)
  full_chain_local.py  bridge + simulator + iZiiServer THẬT
  tests/             test_codec.py (9, thuần), test_e2e.py (16, UDP+HTTP thật trên loopback)
```

### 4.1 Đường đi của MỘT gói (đọc `bridge.on_datagram`)

1. UDP đến `BridgeProtocol` (kế thừa `HSTRPDatagramProtocol` của ok-dmrlib) → chuyển `RadioBridge.on_datagram`.
2. Ghi gói thô vào `--capture` nếu bật (JSONL: `ts, src, port, hex`).
3. `_is_duplicate`: cùng `(IP nguồn, sn, nội dung)` trong 10 s → đánh dấu trùng (bộ đàm gửi lại vì mất ACK).
4. Gọi `HSTRPDatagramProtocol.datagram_received` của thư viện: xử lý connect/heartbeat/close, **tự ACK**, giải mã HDAP.
   (Gọi trực tiếp lớp cha để tránh vòng lặp với override.)
5. `pdu is None` và `not handled` → **không giải mã được**: tăng `undecoded`, log WARNING kèm hex. Không nuốt im lặng.
6. Gói trùng → vẫn đã ACK ở bước 4 nhưng **không** sinh sự kiện (tăng `duplicates`).
7. `codec.events_from_hdap(pdu.payload, ip_nguồn)` → 0..n `RadioEvent` (có thể rỗng: RSSI, cuộc gọi thường...).
8. `RadioBridge.emit`: nếu nguồn là repeater, gộp cùng `(radio, loại)` trong `repeater_suppress_s` (5 s); dựng payload HTTP;
   `gateway_event_id = uuid4().hex` (**sinh đúng một lần ở đây**); `Delivery.submit`.
9. `Delivery.submit`: ghi `spool/<id>.json` (fsync + rename nguyên tử) **rồi** đưa vào hàng đợi.
10. Worker `_deliver`: POST → 200 thì xoá file; lỗi thì chờ (backoff 1→30 s) và thử lại (bảng ở mục 5.2).

### 4.2 Hợp đồng nội bộ `codec` — ranh giới thay thế

```python
events_from_hdap(hdap, src_ip: str, *, id_from_ip: bool, forward_lone_reminder: bool) -> list[RadioEvent]
@dataclass RadioEvent: radio_id: int, event_type: str, source: str, extra: dict
```

* `event_type` là **chuỗi mà server hiểu** (alias trong `server/radio_events.py`): `EMERGENCY_ALARM`, `EMERGENCY_CALL`,
  `MAN_DOWN`, `LONE_WORKER`, `EMERGENCY_CANCEL`, `GPS`, `REGISTER`, `POWER_OFF`. Thêm loại mới = thêm alias bên server trước.
* Hàm **không được ném lỗi** với PDU lạ — trả `[]`. Mọi thứ ngoài `codec.py` không import ok-dmrlib (trừ lớp giao vận
  `HSTRPDatagramProtocol` trong `bridge.py` và các PDU trong `simulator.py`).
* Muốn viết codec riêng theo ADK (không dùng ok-dmrlib — xem mục 12): giữ nguyên chữ ký này là bridge/test không phải đổi.

## 5. Hợp đồng với server

### 5.1 Request

`POST {IZII_URL}/api/v1/radio/events` — `Authorization: Bearer <IZII_RADIO_TOKEN>` (hoặc `X-iZii-Radio-Token`).
Token = `IZIIAPP_RADIO_GATEWAY_SECRET` của server (secret **riêng**, không dùng lại admin/server secret).

```json
{ "gateway_event_id": "9c1f…32 hex", "radio_id": "1001", "event_type": "EMERGENCY_ALARM",
  "timestamp": "2026-10-25T01:02:03+00:00", "system": "dmr", "bridge_source": "radio_status|repeater|rrs|lp",
  "latitude": -37.8, "longitude": 144.9, "detail": {…} }
```

Bắt buộc: `radio_id`, `event_type`. `latitude/longitude` chỉ khi có GPS hợp lệ. Server bỏ qua trường lạ (lưu nguyên văn vào
`radio_events.payload`).

### 5.2 Bridge xử lý phản hồi thế nào (`delivery.py`)

| Phản hồi | Hành động | Lý do |
|---|---|---|
| 200, không `rejected` | xoá spool, `delivered++` | xong |
| 200 kèm `rejected` | chuyển `spool/dead/` | gói sai định dạng, thử lại vô ích |
| 401 / 403 / 503 | **giữ, thử lại mãi** | sai/thiếu secret = lỗi cấu hình; sửa xong là giao được. Bỏ đi nghĩa là mất báo động |
| 408 / 429 / 5xx / lỗi mạng | thử lại, backoff gấp đôi tới 30 s | tạm thời |
| 4xx khác (400, 404, 413…) | chuyển `spool/dead/`, log ERROR | payload hỏng |

Server **idempotent** theo `gateway_event_id` + loại sự kiện: thử lại cùng id không tạo thêm cảnh báo.

### 5.3 Server làm gì với sự kiện (biết để không lặp việc ở bridge)

* Báo động cùng bộ đàm + cùng loại trong `IZIIAPP_RADIO_ALARM_DEDUP_SECONDS` (120 s) bị **gộp** (`repeat_count++`).
* `EMERGENCY_CANCEL` chuyển cảnh báo đang mở sang `cancelled_on_radio` — **không tự đóng**; giám sát phải xác nhận.
* Bộ đàm chưa gán người vẫn tạo cảnh báo (`unbound`); bộ đàm lạ tự được thêm vào `radio_devices`.
* `GPS`/`REGISTER`/`POWER_OFF` chỉ cập nhật `radio_devices` (vị trí cuối, lần cuối thấy), không tạo cảnh báo.
* Vì key chống trùng gồm cả loại sự kiện, gói "huỷ" dùng lại event id của báo động vẫn được xử lý.

## 6. Quyết định thiết kế — đừng đảo ngược khi chưa hiểu lý do

1. **Ghi đĩa trước, gửi sau.** Mất điện/crash bridge hoặc server tạm chết không được làm mất báo động tính mạng.
2. **`gateway_event_id` sinh MỘT lần theo từng sự kiện giải mã được**, không theo bucket thời gian. Server chống trùng
   *vĩnh viễn* theo id: dùng id kiểu `radio+phút` sẽ khiến báo động thật thứ hai trong cùng phút bị coi là trùng và **mất**.
   Gói phát lại của bộ đàm là các sự kiện *khác nhau* → server tự gộp.
3. **Lỗi cấu hình (401/503) không bỏ sự kiện.** Chỉ payload hỏng mới vào `dead/`.
4. **Gói lạ không giải mã được → log + đếm + capture**, không nuốt. Đó có thể chính là báo động thật mà thư viện chưa hỗ trợ.
5. **`LONE_WORKER_REMINDER` không phải báo động** (bấm phím là huỷ). Mặc định không chuyển; hết giờ thật đến thành Emergency.
   Bật bằng `--forward-lone-reminder` chỉ để debug.
6. **Gộp broadcast repeater (5 s) chỉ áp cho nguồn `repeater`**: repeater lặp trạng thái suốt cuộc gọi. Nguồn `radio_status`
   *không* gộp vì mỗi lần phát lại là tín hiệu thật (server gộp ở tầng của nó).
7. **Bỏ gói trùng do mất ACK nhưng vẫn ACK**: nếu không ACK, bộ đàm gửi lại tiếp.
8. **Bridge passive.** Thêm kết nối chủ động chỉ khi ADK yêu cầu (thư viện có `periodic_maintenance` nhưng cứng IP
   `192.168.22.18` — **đừng dùng nguyên**).
9. **Tách khỏi `server/` và `izii_server.exe`** vì giấy phép AGPL của ok-dmrlib và NDA của Hytera (mục 12).

## 7. Simulator

`simulator.py` mô phỏng ở mức gói **và** hành vi. Giả lập thời gian bằng giây thực, thu nhỏ khi test (vài trăm ms).

```python
rpt   = SimHR1062(("127.0.0.1", port));  await rpt.open()                      # repeater giả
radio = SimHP682(1001, target, via="status"|"repeater", repeater=rpt,
                 lone_worker_response_s=0.3, lone_worker_reminder_s=0.15,
                 man_down_trigger_deg=55, man_down_duration_s=0.15, man_down_prealert_s=0.15,
                 tx_cycles=3, tx_cycle_interval_s=0.03)
await radio.power_on()            # connect HSTRP + RRS đăng ký
radio.enable_lone_worker();  radio.key_press()          # đếm giờ / reset
radio.set_tilt(90); radio.set_tilt(0)                   # nằm ngang / dựng đứng
await radio.press_emergency();  await radio.cancel_emergency()
radio.link.drop_next_acks = 1     # giả lập mất ACK (bộ đàm gửi lại cùng sn)
```

* `via="status"`: bộ đàm tự báo bằng `RadioStatusReport` (giả thuyết A3). Man Down → `MAN_DOWN`; nút SOS và Lone Worker hết
  giờ → `EMERGENCY`.
* `via="repeater"`: bộ đàm "phát", `SimHR1062` broadcast `EmergencyAlarm` kèm `sender_id` (giả thuyết A2).
* **Radio ID ↔ IP:** simulator gán IP nguồn `127.<b1>.<b2>.<b3>` (ID 1001 → `127.0.3.233`). Windows chấp nhận bind dải
  `127.0.0.0/8`; Linux cũng được. Nếu môi trường CI không cho, đổi sang gán ID qua RRS thay vì IP.
* `SimLink` mô phỏng độ tin cậy của HSTRP: chờ ACK 0.15 s, gửi lại tối đa 3 lần.
* CLI thủ công: `python -m radio_bridge.simulator --target 127.0.0.1:3005 --radio 1001 --via repeater --scenario sos`.
* **Khi ADK/gói thật làm thay đổi hiểu biết, sửa simulator trước** (cho nó phát đúng như thật), thấy test đỏ, rồi mới sửa codec.

## 8. Kiểm thử

| Tầng | Ở đâu | Chứng minh gì |
|---|---|---|
| Codec thuần | `tests/test_codec.py` | PDU nào thành sự kiện nào; PDU nào bị bỏ (RSSI, cuộc gọi thường, reminder) |
| End-to-end giả | `tests/test_e2e.py` | UDP thật + HTTP thật trên loopback: hành vi bộ đàm, độ bền (server chết, restart, sai token, payload hỏng, mất ACK, gói rác, 20 bộ đàm đồng thời) |
| Hợp đồng | `mock_izii.py` dùng `server/radio_events.normalize_event` | Mọi gói bridge gửi, server thật chuẩn hoá được và ra đúng loại |
| Toàn chuỗi | `full_chain_local.py` | Bridge → server THẬT → job/phòng bật báo động |
| Server | `server/tests/test_radio_gateway.py` | Logic gộp/huỷ/gán job/auth phía server |

**Quy tắc khi thêm tính năng:**
1. Viết test e2e trước, xem nó đỏ vì đúng lý do.
2. Test về thời gian dùng `wait_for(cond)` (poll), không `sleep` cố định rồi assert.
3. Sau khi xanh, **thử phá**: tắt chức năng vừa làm (vd đặt `repeater_suppress_s=0`, đổi `_is_duplicate` thành `False`) và
   xác nhận test đỏ. Test không bao giờ đỏ là test vô dụng. Đã làm cho gộp broadcast và bỏ gói trùng.
4. Không để test phụ thuộc cổng cố định: bridge dùng `ports=[0]` và đọc `bridge.bound_ports`.

Chạy toàn chuỗi: `SERVER_PYTHON=<python của server> python -m radio_bridge.full_chain_local` (cổng 18080; thoát mã 0 = đạt).

## 9. Quy trình khi có ADK / HR1062 thật

Mục tiêu: biến các giả định A1–A6 thành sự thật đã kiểm chứng. Thứ tự quan trọng.

1. **Điều kiện:** NDA đã ký; có *Hytera DMR ADK Overview (H Series) V00*; HR1062 + ≥2 HP682 đã cấu hình Emergency, Lone
   Worker, Man Down theo `plan/Hytera/Integrate Hytera`; địa chỉ IP/cổng "data" của repeater từ CPS.
2. **Bắt gói thô, chưa tin giải mã.** Chạy bridge `--capture capture.jsonl --log-level DEBUG` (và/hoặc Wireshark cùng lúc).
   Bấm lần lượt: bật máy, nút SOS, để Man Down, để Lone Worker hết giờ, huỷ khẩn cấp, cuộc gọi thường. **Ghi lại thời điểm
   từng thao tác** để khớp với gói.
3. **Điền bảng đối chiếu** (mỗi dòng một bản tin; ghi vào tài liệu nội bộ ngoài repo công khai nếu trích ADK):

   | Thao tác | Gói thô (hex) | Giải mã bằng `dmrlib-hytera-*` | ADK nói bản tin này là | Khớp A? |
   |---|---|---|---|---|

4. **Xác nhận từng giả định**, theo thứ tự: A4 (ID đúng người) → A5 (cổng, hướng kết nối) → A2/A3 (bản tin báo động) →
   A1 (ý nghĩa value) → A6 (phân biệt loại).
5. **Cập nhật simulator** cho phát đúng như thật; chạy test, mong đợi vài test đỏ.
6. **Sửa `codec.py`** (và `bridge.py` nếu hướng kết nối khác) cho đến khi xanh. Cập nhật bảng A1–A6 ở mục 2 và
   docstring đầu `codec.py`: đổi "giả định" thành "đã xác nhận ngày…, nguồn…".
7. **Bản tin ok-dmrlib chưa cài** (`from_bytes` ném `not yet implemented`): `EmergencyReport` (LP 0xB003),
   `CancelEmergencyAlarmWithSender` (RCP 0x0853), có thể cả bản tin Emergency/Man Down mà ADK mô tả. Tự cài theo ADK (đừng
   chép từ ADK vào repo công khai). Nhớ bản tin undecoded hiện chỉ được log + capture.
8. **Nghiệm thu thật** theo bảng mục 6 của `HUONG_DAN_TICH_HOP_HYTERA.md` (bấm thật trên HP682, server thật, app thật).
   Thêm các gói thật đã ẩn danh hoá làm fixture hex trong `test_codec.py` — đây là test quý nhất của dự án.
9. Chỉ khi 1–8 xong mới nói bridge "đã kiểm chứng với Hytera thật".

**Câu hỏi còn mở gửi Hytera/Radlink** (đối chiếu với ADK):
* Báo động Lone Worker hết giờ / Man Down có khác SOS ở dispatcher không (loại, cờ, mã)? Cần để phân loại đúng.
* Thông điệp "huỷ khẩn cấp" là gì, ai gửi (bộ đàm hay repeater)?
* Repeater chủ động gửi tới địa chỉ ứng dụng hay ứng dụng phải đăng ký/kết nối? Cổng nào, cần cấu hình CPS gì ("Data Master"…)?
* Một bộ đàm có phải đăng ký (RRS) trước khi báo động được không? Chu kỳ gia hạn?
* Bộ đàm có chờ ACK cho Emergency (Alarm Ack)? Bridge phải gửi gì để nó ngừng phát lại?
* ADK chạy được trên cùng máy Windows với bridge, hay phải máy riêng? Hytera đã nói **không khuyến nghị** chạy cùng
  SmartDispatch/SmartOne, nên bridge không được song song với hệ dispatch.

## 10. Mở rộng sau này

| Hạng mục | Gợi ý |
|---|---|
| HP782GBT (có GPS, Bluetooth) | LP `StandardReport` đã giải mã (`GPS`); cần cài `EmergencyReport` để báo động kèm toạ độ. Server đã dùng toạ độ, app đã hiện bản đồ |
| iZii → bộ đàm | **Đã có** hàng đợi lệnh (mục 15): nhắn tin (TMP, ok-dmrlib làm được 2 chiều), hỏi/bật/tắt Lone Worker (RCP tự đóng gói — giả định A7). Còn thiếu: alert call (RCP 0x0835, chưa có bố cục) |
| Health-check / giám sát bridge | HTTP nhỏ `/health` trả `stats` + tuổi sự kiện cũ nhất trong spool + thời điểm nhận gói cuối. Server cảnh báo nếu bridge im lặng quá N phút (bộ đàm đăng ký định kỳ — im lặng bất thường là dấu hiệu) |
| Chạy như dịch vụ | NSSM hoặc Task Scheduler "at startup" + tự khởi động lại khi lỗi; log ra file xoay vòng |
| Cấu hình | `retry_*`, `repeater_suppress_s`, `id_from_ip` chưa có cờ CLI/env; thêm khi cần |

## 11. Hạn chế đã biết (backlog, theo mức nghiêm trọng)

1. **Chặn đầu hàng đợi (head-of-line blocking).** `Delivery` giao tuần tự. Một sự kiện bị server từ chối kiểu *tạm thời mãi mãi*
   (vd 500 do lỗi server với payload đó) sẽ chặn mọi báo động phía sau. Đề xuất: ưu tiên báo động trước `REGISTER/GPS`;
   giới hạn số lần thử cho sự kiện không phải báo động; hoặc nhiều worker. Chưa làm.
2. **Chưa có health-check/giám sát** — bridge chết là câm lặng.
3. **Spool không giới hạn** khi server chết lâu; chưa có cảnh báo dung lượng/tuổi.
4. **`dead/` chưa có công cụ phát lại** (hiện xử lý tay: sửa rồi chép lại vào `spool/`).
5. **Dedup gói theo bộ nhớ**, mất khi restart (an toàn: tệ nhất là server gộp thêm một báo động lặp).
6. Bridge nghe `0.0.0.0` theo mặc định; nên bind đúng NIC nối mạng repeater và chặn bằng firewall.
7. Chưa có TLS client-cert tới server (dùng HTTPS thường + Bearer). Nếu server bật mTLS, cần thêm vào `httpx`.

## 12. Giấy phép và NDA — quy tắc cho dev

* **ok-dmrlib là AGPL-3.0.** Mọi thứ liên kết/nhúng nó chịu ràng buộc AGPL. Vì vậy: `radio_bridge/` là tiến trình riêng, **không**
  import từ `server/` (trừ `mock_izii` đọc `server/radio_events.py` theo đường dẫn, chỉ cho test) và **không** đóng gói vào
  `izii_server.exe`. Đừng thêm `radio_bridge` vào `izii_server.spec`.
* **Chưa phân phối bridge cho khách** khi chưa có ý kiến pháp lý về AGPL. Chạy nội bộ tại Costa thì rủi ro thấp.
* **Phương án thay thế:** viết codec theo ADK (không liên kết ok-dmrlib) và dùng ok-dmrlib chỉ trong simulator/test. Chữ ký
  `events_from_hdap` ở mục 4.2 giữ nguyên để thay không đau.
* **Tài liệu ADK dưới NDA:** không commit PDF/trích đoạn dài vào repo, không dán vào issue/PR công khai, không đưa vào prompt
  của công cụ AI ngoài danh sách được phép. Lưu ở nơi chia sẻ nội bộ và chỉ ghi tham chiếu (tên tài liệu, mục) trong code.
* Gói bắt thật cũng có thể chứa Radio ID/vị trí nhân viên: ẩn danh hoá trước khi làm fixture.

## 13. Vận hành (runbook ngắn)

Cấu hình: `IZII_URL`, `IZII_RADIO_TOKEN`, `BRIDGE_LISTEN_HOST`, `BRIDGE_PORTS`, `BRIDGE_SPOOL_DIR`, `BRIDGE_CAPTURE_FILE`,
`BRIDGE_FORWARD_LONE_REMINDER` (hoặc cờ CLI tương ứng).

| Triệu chứng | Nguyên nhân thường gặp | Xử lý |
|---|---|---|
| Log lặp `HTTP 401` | Sai `IZII_RADIO_TOKEN` | Sửa token, khởi động lại — sự kiện trong spool tự giao |
| Log lặp `HTTP 503` | Server chưa đặt `IZIIAPP_RADIO_GATEWAY_SECRET` | Đặt secret cho server, restart server |
| `undecoded` tăng | Opcode chưa cài / gói không phải HSTRP | Lấy hex trong log/capture, đối chiếu ADK (mục 9) |
| Không có gói nào, `datagrams=0` | Sai cổng/NIC, firewall, repeater chưa trỏ tới bridge | Wireshark xem gói có tới máy không |
| `spool/` phình | Server chết lâu | Khôi phục server; theo dõi `delivery.stats` |
| `spool/dead/` có file | Server từ chối payload | Đọc file + log ERROR, sửa codec hoặc server |
| Báo động gắn sai người | Gán bộ đàm sai ở app, hoặc A4 sai | Kiểm tra Safety → Hytera Radios và Radio ID thật |

Log: `INFO` ghi mỗi sự kiện đã giao; `WARNING` ghi mỗi báo động (`BÁO ĐỘNG …`) và gói không giải mã; thống kê mỗi 60 s
(`bridge=… delivery=…`).

## 14. Gotcha đã gặp (tiết kiệm thời gian cho bạn)

* **`WinError 206 filename too long` khi `pip install`** trong venv đặt dưới thư mục dự án/OneDrive/scratchpad dài. Đặt venv ở
  đường dẫn ngắn (`C:\venvs\okv`).
* **`python -m radio_bridge...` phải chạy từ gốc repo**, nếu không `import radio_bridge` hỏng.
* **In tiếng Việt ra pipe trên Windows** gây `UnicodeEncodeError`/mất output: `full_chain_local` đã `reconfigure(utf-8)`;
  khi viết script mới, đặt `PYTHONIOENCODING=utf-8`.
* **Tiến trình uvicorn mồ côi chiếm cổng 18080** nếu kill script giữa chừng → lần chạy sau nhận nhầm server cũ. Kiểm tra
  `netstat -ano | findstr 18080` và kill.
* **`ok-dmrlib` logging:** log ERROR `Could not decode HSTRP …` từ thư viện là bình thường với gói rác; bridge đếm riêng.
* **`test_phase1_foundation…test_coverage_assertions` của server có thể đỏ** nếu Postgres dùng chung có bảng từ nhánh khác
  (vd `clinic_*`) chưa khai báo trong `server/migrate_to_postgres.py`. Không phải lỗi của bridge.
* Mọi thay đổi bảng phía server cho radio phải thêm vào cả `db_init.py` (SQLite), migration (`0011_radio_gateway.sql` trở
  đi) và `migrate_to_postgres.TABLES`.
* Mọi UDP trong code dùng `loop.create_datagram_endpoint` (đã chạy ổn trên Windows). Đừng chuyển sang API socket thô của
  event loop mà chưa thử trên Windows.

## 15. Chiều xuống: lệnh iZii → bộ đàm

```
App (Test Alone Worker / Hytera Radios) ─POST /api/v1/radio/devices/{id}/commands─▶ server: radio_commands (pending)
App hết giờ Alone Worker ─/sync/push alarm_triggered─▶ server tự xếp text_message "ALONE WORKER TIMEOUT - <phòng>"
bridge/commands.py ─GET /api/v1/radio/bridge/commands (thuê 30 s)─▶ gửi xuống bộ đàm ─▶ chờ phản hồi ≤ 5 s
                   ─POST /api/v1/radio/bridge/commands/{id}/result {ok, result, error}─▶ server: done | failed
```

* **Server** (`server/routers/radio_gateway.py`, cuối file): `create_command`, `enqueue_timeout_alerts` (gọi từ
  `routers/sync.py` sau khi lưu mutation). Tin time out gửi cho bộ đàm có `employee_id/name` khớp `assignee` của job;
  khoá chống trùng gồm `job_id + started_at + radio_id`, nên đồng bộ lại không nhắn lại, nhưng lần hết giờ sau khi check-in thì có.
  Lệnh `pending` quá 10 phút → `expired`; `sent` mà bridge không báo kết quả sau 3 lần thuê → `failed`.
  Kết quả lệnh Lone Worker cập nhật `radio_devices.lone_worker_state` (`on`/`off`).
* **Bridge** học địa chỉ bộ đàm từ gói nó gửi lên (`radio_addr`), nên bộ đàm phải bật và đăng ký trước khi nhận được
  lệnh; chưa thấy bao giờ thì lệnh `failed` ngay ("chưa liên lạc với bridge"). Phản hồi RCP Lone Worker được bridge tự
  giải mã (`parse_raw_rcp`) trước khi đưa cho ok-dmrlib.
* **Nhận trùng chấp nhận được:** bridge mất mạng lúc báo kết quả → server cấp lại lệnh → bộ đàm có thể nhận tin hai lần.
* **Server SQLite:** bước "đã điểm danh chưa" khi tạo job Alone Worker đọc bảng điểm danh — backend SQLite không chiếu
  bảng này từ mutation, nên `full_chain_local` gửi lại sự kiện CHECK_IN cùng lô với job. Trên Postgres (Costa) không cần.
* Test: `server/tests/test_radio_gateway.py` (`TestTimeoutAlertsToRadio`, `TestRadioCommandEndpoints`),
  `radio_bridge/tests/test_commands.py`, kịch bản `full_chain_local --scenario andrew`, màn hình app
  `radio_alone_worker_test_screen.dart`.

## 16. Định nghĩa "xong" cho một thay đổi

- [ ] Có test e2e/codec cho hành vi mới và đã thử phá (mục 8.3).
- [ ] `python -m pytest radio_bridge/tests` xanh; `python -m unittest tests.test_radio_gateway` (trong `server/`) xanh nếu đụng server.
- [ ] `full_chain_local` vẫn đạt nếu đụng hợp đồng/payload.
- [ ] Giả định mới (nếu có) ghi vào mục 2 và docstring `codec.py`; không viết "đã kiểm chứng" khi chỉ mới test với simulator.
- [ ] Không có tài liệu NDA/gói thật chưa ẩn danh trong diff.
- [ ] Không import ok-dmrlib ngoài `codec.py`/`bridge.py` (giao vận)/`simulator.py`/test.
- [ ] README/guide cập nhật nếu đổi cấu hình hoặc cách chạy.
