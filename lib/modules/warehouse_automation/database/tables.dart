import 'package:drift/drift.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Warehouse Automation — Drift tables
// ══════════════════════════════════════════════════════════════════════════════
//
//  Bốn bảng, theo đúng thứ tự phụ thuộc:
//
//    Locations        — cây vị trí kho. Nền tảng của mọi thứ còn lại.
//    IotDevices       — sổ đăng ký thiết bị LoRaWAN, gắn vào Locations.
//    SensorReadings   — dữ liệu đo. Bảng lớn nhất, thiết kế theo hướng ghi-thêm.
//    AutomationRules  — luật biến số đo thành hành động.
//    AutomationEvents — nhật ký luật đã kích hoạt (tuỳ chọn, xem ghi chú).
//
//  QUY ƯỚC bám theo codebase hiện tại:
//    - Khoá chính luôn là `id` kiểu TEXT chứa UUID v4 (giống Products,
//      StockQuants, MushroomJobs...).
//    - Khoá ngoại KHÔNG dùng `.references()` mà để TEXT thường, kiểm tra ở tầng
//      ứng dụng — giống cách `StockQuants.locationId` và `MushroomJobs.roomId`
//      đang làm. Lý do ở mục "Ghi chú thiết kế" cuối file.
//    - Trường mở rộng tự do dùng `customFields` JSON, mặc định '{}' — giống
//      Products.customFields và Leads.customFields.
//
// ══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
//  1. LOCATIONS — cây vị trí kho
// ─────────────────────────────────────────────────────────────────────────────
//
//  Thay thế cho `StockQuants.locationId` vốn là chuỗi text tự do.
//
//  Dùng ĐỒNG THỜI hai cách biểu diễn cây:
//    - `parentId`  : adjacency list — đúng về mặt cấu trúc, dễ đổi cha.
//    - `path`      : materialized path — cho phép truy vấn cả nhánh bằng một
//                    câu LIKE có index, không cần recursive CTE.
//
//  Ví dụ một nhánh:
//    id=uuid1  code='WH1'          type='warehouse'  parentId=null   path='/WH1'
//    id=uuid2  code='WH1-A'        type='zone'       parentId=uuid1  path='/WH1/A'
//    id=uuid3  code='WH1-A-03'     type='aisle'      parentId=uuid2  path='/WH1/A/03'
//    id=uuid4  code='WH1-A-03-B'   type='rack'       parentId=uuid3  path='/WH1/A/03/B'
//    id=uuid5  code='WH1-A-03-B-12' type='bin'       parentId=uuid4  path='/WH1/A/03/B/12'
//
//  Tồn kho toàn bộ zone A:
//    SELECT ... WHERE l.path LIKE '/WH1/A/%'
//
//  ĐÁNH ĐỔI: đổi cha một nút phải cập nhật `path` của toàn bộ nhánh con. Trong
//  nhà kho việc này hiếm (tái cấu trúc kệ), nên đổi lấy tốc độ đọc là hời.
//  Hàm `LocationRepository.reparent()` phải làm việc này trong một transaction.

@TableIndex(name: 'idx_locations_path', columns: {#path})
@TableIndex(name: 'idx_locations_parent', columns: {#parentId})
class Locations extends Table {
  TextColumn get id => text()(); // UUID

  /// Mã người đọc được, in trên nhãn/barcode dán tại vị trí. VD 'WH1-A-03-B-12'.
  /// Đây là thứ nhân viên gõ và máy quét đọc — phải duy nhất.
  TextColumn get code => text().unique()();

  TextColumn get name => text()();

  /// UUID của Locations cha. NULL = nút gốc (một nhà kho).
  /// Không dùng .references() vì Drift tự tham chiếu dễ gây vòng lặp codegen.
  TextColumn get parentId => text().nullable()();

  /// warehouse, zone, aisle, rack, level, bin, staging, dock, quarantine
  TextColumn get type => text()();

  /// Đường dẫn vật chất hoá, luôn bắt đầu và phân tách bằng '/'.
  /// Bất biến với `code`: sinh lại mỗi khi đổi cha.
  TextColumn get path => text()();

  /// Độ sâu trong cây, gốc = 0. Dư thừa so với `path` nhưng rẻ và tiện lọc.
  IntColumn get depth => integer().withDefault(const Constant(0))();

  // ── Toạ độ để AGV điều hướng (mét, gốc toạ độ do sơ đồ kho quy định) ───────
  // NULL khi chưa khảo sát. Chỉ nút lá mới thực sự cần.
  RealColumn get posX => real().nullable()();
  RealColumn get posY => real().nullable()();
  RealColumn get posZ => real().nullable()();

  // ── Sức chứa, để cảnh báo quá tải ─────────────────────────────────────────
  RealColumn get maxWeightKg => real().nullable()();
  RealColumn get maxVolumeM3 => real().nullable()();

  /// active, blocked (đang sửa/cấm vào), maintenance, archived
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Chỉ nút LÁ mới chứa được hàng. Nút trung gian (zone, aisle) đặt false.
  /// Ngăn lỗi kinh điển: ghi tồn kho vào 'Zone A' thay vì một ô cụ thể.
  BoolColumn get isStorable => boolean().withDefault(const Constant(true))();

  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
//  2. IOT DEVICES — sổ đăng ký thiết bị LoRaWAN
// ─────────────────────────────────────────────────────────────────────────────
//
//  ⚠️ BẢO MẬT: bảng này KHÔNG chứa AppKey / NwkKey / AppSKey.
//  Khoá mật mã của thiết bị nằm trong ChirpStack và không bao giờ rời khỏi đó.
//  Bảng này chỉ giữ định danh công khai (DevEUI) và siêu dữ liệu vận hành.
//  Nó được đồng bộ xuống điện thoại — coi như dữ liệu công khai trong nội bộ.

@TableIndex(name: 'idx_iot_devices_location', columns: {#locationId})
@TableIndex(name: 'idx_iot_devices_status', columns: {#status})
class IotDevices extends Table {
  TextColumn get id => text()(); // UUID

  /// Định danh LoRaWAN, 16 ký tự hex. Khoá đối chiếu với ChirpStack.
  TextColumn get devEui => text().unique()();

  TextColumn get name => text()();

  /// temperature, humidity, co2, loadcell, level, door, button,
  /// gps_tracker, ble_gateway, agv_telemetry
  TextColumn get deviceType => text()();

  TextColumn get vendor => text().nullable()();
  TextColumn get model => text().nullable()();

  /// Cho server biết dùng hàm decode nào cho payload của thiết bị này.
  /// Trỏ tới một codec Python đã đăng ký, VD 'dragino_lht65_v1'.
  /// Đây chính là chỗ thay cho ý tưởng "LLM đoán payload" — một chuỗi tra bảng.
  TextColumn get codecId => text()();

  /// Thiết bị đang gắn ở đâu. NULL = chưa lắp đặt (còn trong kho vật tư).
  TextColumn get locationId => text().nullable()();

  /// Nếu thiết bị đo tồn kho của đúng một sản phẩm (VD loadcell dưới một bồn),
  /// trỏ tới Products.id. NULL với cảm biến môi trường.
  TextColumn get trackedProductId => text().nullable()();

  /// active, inactive, faulty, decommissioned
  TextColumn get status => text().withDefault(const Constant('active'))();

  // ── Sức khoẻ thiết bị: cập nhật mỗi uplink ────────────────────────────────
  RealColumn get batteryLevel => real().nullable()(); // phần trăm 0–100
  IntColumn get lastRssi => integer().nullable()(); // dBm, càng gần 0 càng tốt
  RealColumn get lastSnr => real().nullable()(); // dB
  IntColumn get lastSpreadingFactor => integer().nullable()(); // 7–12

  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  /// Chu kỳ báo tin kỳ vọng (giây). Dùng để phát hiện thiết bị mất tín hiệu:
  /// `now - lastSeenAt > expectedIntervalSec * 3` → nghi ngờ chết pin/mất sóng.
  /// Không có trường này thì không phân biệt được "cảm biến im vì ổn định" với
  /// "cảm biến im vì hỏng" — và đó là một lỗ hổng nguy hiểm trong hệ giám sát.
  IntColumn get expectedIntervalSec => integer().nullable()();

  /// Frame counter của gói cuối. Nhảy cóc = có gói bị mất trên đường.
  /// Dùng để đo chất lượng phủ sóng thực tế theo từng vị trí.
  IntColumn get lastFrameCounter => integer().nullable()();

  TextColumn get customFields => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
//  3. SENSOR READINGS — dữ liệu đo
// ─────────────────────────────────────────────────────────────────────────────
//
//  Bảng lớn nhất hệ thống. Ba nguyên tắc bất di bất dịch:
//
//   (1) CHỈ GHI THÊM. Không bao giờ UPDATE một dòng đã ghi. Sửa số đo lịch sử
//       là cách nhanh nhất để mất niềm tin vào toàn bộ dữ liệu.
//   (2) Một dòng = một chỉ số (dạng dài). Cảm biến gửi nhiệt+ẩm+pin sinh 3 dòng.
//       Đổi lại nhiều dòng hơn, ta được schema không phải đổi khi thêm loại
//       cảm biến mới, và rollup viết được bằng một câu GROUP BY.
//   (3) KHÔNG đồng bộ toàn bộ bảng này xuống điện thoại. Client chỉ nhận giá
//       trị mới nhất và bản đã rollup — cấu hình qua UserSyncConfigs với
//       syncGranularity='selective'.

@TableIndex(
    name: 'idx_readings_device_time', columns: {#deviceId, #measuredAt})
@TableIndex(
    name: 'idx_readings_location_metric', columns: {#locationId, #metric})
@TableIndex(name: 'idx_readings_rollup', columns: {#rollupLevel, #measuredAt})
class SensorReadings extends Table {
  TextColumn get id => text()(); // UUID

  TextColumn get deviceId => text()(); // → IotDevices.id

  /// Vị trí TẠI THỜI ĐIỂM ĐO — cố ý sao chép lại, không join động.
  ///
  /// VÌ SAO: thiết bị có thể được tháo ra lắp chỗ khác. Nếu truy vấn lịch sử
  /// bằng cách join sang IotDevices.locationId (giá trị hiện tại), toàn bộ số
  /// đo cũ sẽ đột nhiên thuộc về vị trí mới — sai lặng lẽ và rất khó phát hiện.
  TextColumn get locationId => text().nullable()();

  /// temperature, humidity, co2, weight, level_pct, door_state,
  /// battery, button_press, rssi_beacon
  TextColumn get metric => text()();

  RealColumn get value => real()();

  /// C, %, ppm, kg, m, bool, count
  TextColumn get unit => text()();

  /// Thời điểm cảm biến ĐO. Lấy từ trường time của ChirpStack.
  DateTimeColumn get measuredAt => dateTime()();

  /// Thời điểm server NHẬN. Tách riêng vì LoRaWAN có thể trễ hoặc gửi dồn sau
  /// khi mất sóng. Chênh lệch hai mốc này chính là thước đo sức khoẻ mạng.
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();

  /// ok, suspect (ngoài dải hợp lý), stale (đến quá muộn), calibrating
  /// Đánh dấu thay vì xoá — dữ liệu xấu vẫn là bằng chứng về thiết bị hỏng.
  TextColumn get quality => text().withDefault(const Constant('ok'))();

  /// raw, minute, hour, day.
  /// Tiến trình rollup ghi dòng tổng hợp mới rồi xoá dòng `raw` cũ theo lô.
  TextColumn get rollupLevel => text().withDefault(const Constant('raw'))();

  /// Số mẫu gộp lại (chỉ có nghĩa khi rollupLevel != 'raw').
  IntColumn get sampleCount => integer().withDefault(const Constant(1))();

  /// Min/max trong khoảng gộp — giữ lại đỉnh, vì trung bình che mất sự cố.
  /// Một lần vọt nhiệt 40°C trong 5 phút sẽ biến mất khỏi trung bình giờ.
  RealColumn get minValue => real().nullable()();
  RealColumn get maxValue => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
//  4. AUTOMATION RULES — biến số đo thành hành động
// ─────────────────────────────────────────────────────────────────────────────
//
//  Chạy ở SERVER (server/routers/iot.py), không chạy ở client. Client chỉ đọc
//  và sửa cấu hình luật. Lý do: luật phải chạy 24/7 kể cả khi không ai mở app.
//
//  ⚠️ `operator` là từ khoá Dart — dùng `comparator`.

@TableIndex(name: 'idx_rules_enabled', columns: {#isEnabled})
class AutomationRules extends Table {
  TextColumn get id => text()(); // UUID

  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  // ── ÁP DỤNG CHO CÁI GÌ ────────────────────────────────────────────────────

  /// device (một thiết bị), location_subtree (cả nhánh cây), device_type (mọi
  /// thiết bị cùng loại), all
  TextColumn get scopeType => text()();

  /// Với location_subtree: chứa `path` tiền tố, VD '/WH1/A/'.
  /// Với device: chứa IotDevices.id. Với device_type: chứa tên loại.
  TextColumn get scopeValue => text().nullable()();

  /// Chỉ số cần theo dõi, khớp với SensorReadings.metric.
  TextColumn get metric => text()();

  // ── ĐIỀU KIỆN ─────────────────────────────────────────────────────────────

  /// gt, gte, lt, lte, eq, neq,
  /// delta_pct (đổi quá N% so với lần trước),
  /// delta_abs (đổi quá N đơn vị),
  /// no_data   (im lặng quá lâu — dùng với thresholdSeconds)
  TextColumn get comparator => text()();

  RealColumn get threshold => real().nullable()();

  /// Chỉ dùng cho comparator='no_data': im quá bao nhiêu giây thì báo.
  IntColumn get thresholdSeconds => integer().nullable()();

  // ── CHỐNG RUNG — phần quan trọng nhất của bảng này ─────────────────────────
  //
  //  Không có ba trường dưới đây, một cảm biến nhiễu sẽ bắn hàng trăm cảnh báo
  //  mỗi giờ và người dùng sẽ tắt toàn bộ hệ thống thông báo trong tuần đầu.

  /// Cần bao nhiêu lần đo LIÊN TIẾP thoả điều kiện thì mới kích hoạt.
  IntColumn get debounceCount => integer().withDefault(const Constant(2))();

  /// Các lần đo đó phải nằm trong cửa sổ bao nhiêu giây. NULL = không giới hạn.
  IntColumn get debounceWindowSec => integer().nullable()();

  /// Sau khi kích hoạt, im lặng bao lâu trước khi được bắn lại.
  IntColumn get cooldownSec => integer().withDefault(const Constant(300))();

  // ── HÀNH ĐỘNG ─────────────────────────────────────────────────────────────

  /// notify            — đẩy qua event_engine (WebSocket + push)
  /// create_stock_move — sinh StockMoves với status='draft'  ⚠ không bao giờ 'done'
  /// update_quant      — ghi đè StockQuants (CHỈ cho cảm biến đo trực tiếp)
  /// create_ticket     — sinh MushroomMaintenanceTickets
  /// webhook           — POST ra ngoài, dùng lại webhook_subscriptions
  TextColumn get actionType => text()();

  /// Tham số của hành động, JSON. VD với create_stock_move:
  /// {"destLocationCode":"PENDING_REVIEW","productId":"...","requireApproval":true}
  TextColumn get actionConfig => text().withDefault(const Constant('{}'))();

  /// info, warning, critical — quyết định kênh thông báo và độ ồn.
  TextColumn get severity => text().withDefault(const Constant('info'))();

  // ── TRẠNG THÁI CHẠY ───────────────────────────────────────────────────────
  DateTimeColumn get lastTriggeredAt => dateTime().nullable()();
  IntColumn get triggerCount => integer().withDefault(const Constant(0))();

  TextColumn get createdBy => text().nullable()(); // Users.id
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
//  5. AUTOMATION EVENTS — nhật ký luật đã kích hoạt
// ─────────────────────────────────────────────────────────────────────────────
//
//  Không nằm trong 4 bảng bạn yêu cầu, nhưng tôi đề xuất thêm.
//
//  VÌ SAO: khi ai đó hỏi "sao tự nhiên có lệnh xuất kho 20kg này?", bảng này là
//  thứ duy nhất trả lời được. Không có nó, luật tự động trở thành hộp đen và
//  người vận hành sẽ mất niềm tin vào toàn bộ tính năng.
//
//  Đây cũng là nơi tra cứu để tinh chỉnh ngưỡng trong tháng đầu vận hành.

@TableIndex(name: 'idx_auto_events_rule_time', columns: {#ruleId, #triggeredAt})
class AutomationEvents extends Table {
  TextColumn get id => text()(); // UUID

  TextColumn get ruleId => text()(); // → AutomationRules.id
  TextColumn get deviceId => text().nullable()(); // → IotDevices.id
  TextColumn get locationId => text().nullable()(); // → Locations.id

  /// Số đo đã làm luật nổ.
  TextColumn get triggeringReadingId => text().nullable()();
  RealColumn get triggeringValue => real().nullable()();

  DateTimeColumn get triggeredAt => dateTime().withDefault(currentDateAndTime)();

  /// pending, executed, failed, suppressed_cooldown, suppressed_debounce
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Bản ghi do hành động sinh ra, VD StockMoves.id — để lần ngược dấu vết.
  TextColumn get resultRecordType => text().nullable()();
  TextColumn get resultRecordId => text().nullable()();

  TextColumn get errorMessage => text().nullable()();

  /// Ai đã xác nhận (với hành động cần duyệt). NULL = chưa ai xử lý.
  TextColumn get acknowledgedBy => text().nullable()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
