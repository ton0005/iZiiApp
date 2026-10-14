-- Migration 0010: Industrial WMS Foundation & Multi-Warehouse, Pharma Architecture
-- Tables: products, locations, product_uoms, product_packagings, stock_lots,
--         stock_lpns, stock_lpn_contents, stock_quants, stock_moves,
--         stock_pickings, stock_picking_lines, stock_serial_numbers,
--         pharma_controlled_approvals, pharma_dispensing_logs,
--         iot_devices, sensor_readings, automation_rules, automation_events

-- 1. PRODUCTS
CREATE TABLE IF NOT EXISTS products (
    id               TEXT PRIMARY KEY,
    sku              TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    price            REAL NOT NULL DEFAULT 0.0,
    cost             REAL NOT NULL DEFAULT 0.0,
    type             TEXT NOT NULL DEFAULT 'product', -- product, service, consumable, medicine
    barcode          TEXT,
    custom_fields    TEXT DEFAULT '{}',
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON products(tenant_id, id);

-- 2. LOCATIONS (Cây vị trí phân cấp hỗ trợ Multi-Warehouse & 3D AGV)
CREATE TABLE IF NOT EXISTS locations (
    id               TEXT PRIMARY KEY,
    code             TEXT NOT NULL UNIQUE, -- e.g. 'WH1-COLD-A01-L1'
    name             TEXT NOT NULL,
    parent_id        TEXT,
    type             TEXT NOT NULL, -- warehouse, zone, aisle, rack, level, bin, staging, dock, quarantine, transit
    path             TEXT NOT NULL, -- e.g. '/WH1/COLD/A01/L1'
    depth            INT NOT NULL DEFAULT 0,
    pos_x            REAL,
    pos_y            REAL,
    pos_z            REAL,
    max_weight_kg    REAL,
    max_volume_m3    REAL,
    status           TEXT NOT NULL DEFAULT 'active', -- active, blocked, maintenance, archived
    is_storable      BOOLEAN NOT NULL DEFAULT TRUE,
    custom_fields    TEXT DEFAULT '{}',
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_locations_path ON locations(path);
CREATE INDEX IF NOT EXISTS idx_locations_parent ON locations(parent_id);
CREATE INDEX IF NOT EXISTS idx_locations_tenant_id ON locations(tenant_id, id);

-- 3. PRODUCT UOMS (Đơn vị tính đa cấp & Tỷ lệ quy đổi)
CREATE TABLE IF NOT EXISTS product_uoms (
    id               TEXT PRIMARY KEY,
    product_id       TEXT NOT NULL REFERENCES products(id),
    name             TEXT NOT NULL, -- kg, punnet, box, layer, pallet
    uom_type         TEXT NOT NULL DEFAULT 'reference', -- reference, smaller, bigger
    ratio_to_base    REAL NOT NULL DEFAULT 1.0, -- e.g. 1 pallet = 72 boxes
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_product_uoms_prod ON product_uoms(product_id);

-- 4. PRODUCT PACKAGINGS (Quy cách đóng gói hình học)
CREATE TABLE IF NOT EXISTS product_packagings (
    id               TEXT PRIMARY KEY,
    product_id       TEXT NOT NULL REFERENCES products(id),
    name             TEXT NOT NULL, -- e.g. "Box 400x300", "Pallet AS 4068"
    qty_per_package  REAL NOT NULL DEFAULT 1.0,
    uom_id           TEXT NOT NULL REFERENCES product_uoms(id),
    length_mm        REAL,
    width_mm         REAL,
    height_mm        REAL,
    tare_weight_kg   REAL DEFAULT 0.0,
    barcode          TEXT,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_packagings_prod ON product_packagings(product_id);

-- 5. STOCK LOTS (Quản lý Lô & Hạn sử dụng - FEFO Engine)
CREATE TABLE IF NOT EXISTS stock_lots (
    id               TEXT PRIMARY KEY,
    lot_number       TEXT NOT NULL,
    product_id       TEXT NOT NULL REFERENCES products(id),
    production_date  TIMESTAMPTZ,
    best_before_date TIMESTAMPTZ,
    expiry_date      TIMESTAMPTZ NOT NULL,
    status           TEXT NOT NULL DEFAULT 'quarantine', -- quarantine, approved, blocked, expired
    notes            TEXT,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_stock_lots_expiry ON stock_lots(expiry_date, status);
CREATE INDEX IF NOT EXISTS idx_stock_lots_prod ON stock_lots(product_id, lot_number);

-- 6. STOCK LPNS (Biển số Pallet / Thùng chứa LPN)
CREATE TABLE IF NOT EXISTS stock_lpns (
    id               TEXT PRIMARY KEY,
    lpn_code         TEXT NOT NULL UNIQUE, -- e.g. 'LPN-2026-M1-001248'
    location_id      TEXT NOT NULL REFERENCES locations(id),
    status           TEXT NOT NULL DEFAULT 'staged', -- staged, stored, in_transit, shipped, empty
    gross_weight_kg  REAL DEFAULT 0.0,
    tare_weight_kg   REAL DEFAULT 0.0,
    net_weight_kg    REAL DEFAULT 0.0,
    packaging_id     TEXT REFERENCES product_packagings(id),
    custom_fields    TEXT DEFAULT '{}',
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_stock_lpns_code ON stock_lpns(lpn_code);
CREATE INDEX IF NOT EXISTS idx_stock_lpns_loc ON stock_lpns(location_id, status);

-- 7. STOCK LPN CONTENTS
CREATE TABLE IF NOT EXISTS stock_lpn_contents (
    id               TEXT PRIMARY KEY,
    lpn_id           TEXT NOT NULL REFERENCES stock_lpns(id),
    product_id       TEXT NOT NULL REFERENCES products(id),
    lot_id           TEXT REFERENCES stock_lots(id),
    quantity         REAL NOT NULL DEFAULT 0.0,
    uom_id           TEXT NOT NULL REFERENCES product_uoms(id),
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_lpn_contents_lpn ON stock_lpn_contents(lpn_id);

-- 8. STOCK QUANTS (Tồn kho định vị chi tiết)
CREATE TABLE IF NOT EXISTS stock_quants (
    id               TEXT PRIMARY KEY,
    product_id       TEXT NOT NULL REFERENCES products(id),
    location_id      TEXT NOT NULL REFERENCES locations(id),
    lot_id           TEXT REFERENCES stock_lots(id),
    lpn_id           TEXT REFERENCES stock_lpns(id),
    quantity         REAL NOT NULL DEFAULT 0.0,
    reserved_qty     REAL NOT NULL DEFAULT 0.0,
    available_qty    REAL NOT NULL DEFAULT 0.0,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_quant UNIQUE (product_id, location_id, lot_id, lpn_id)
);
CREATE INDEX IF NOT EXISTS idx_quants_lookup ON stock_quants(product_id, location_id);
CREATE INDEX IF NOT EXISTS idx_quants_available ON stock_quants(product_id, available_qty);

-- 9. STOCK PICKINGS (Phiếu Nhập/Xuất/Chuyển kho)
CREATE TABLE IF NOT EXISTS stock_pickings (
    id               TEXT PRIMARY KEY,
    code             TEXT NOT NULL UNIQUE, -- e.g. 'IN-2026-0001', 'OUT-2026-0001'
    picking_type     TEXT NOT NULL, -- incoming_supplier, incoming_harvest, internal_transfer, outbound_sales, scrap
    origin_document  TEXT, -- PO-xxx, SO-xxx, HARVEST-xxx
    source_location_id TEXT REFERENCES locations(id),
    dest_location_id   TEXT REFERENCES locations(id),
    scheduled_date   TIMESTAMPTZ,
    completed_date   TIMESTAMPTZ,
    status           TEXT NOT NULL DEFAULT 'draft', -- draft, waiting, confirmed, assigned, done, cancelled
    wave_id          TEXT,
    priority         TEXT DEFAULT 'normal',
    notes            TEXT,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_pickings_status ON stock_pickings(status, picking_type);

-- 10. STOCK PICKING LINES
CREATE TABLE IF NOT EXISTS stock_picking_lines (
    id               TEXT PRIMARY KEY,
    picking_id       TEXT NOT NULL REFERENCES stock_pickings(id),
    product_id       TEXT NOT NULL REFERENCES products(id),
    lot_id           TEXT REFERENCES stock_lots(id),
    lpn_id           TEXT REFERENCES stock_lpns(id),
    source_location_id TEXT NOT NULL REFERENCES locations(id),
    dest_location_id   TEXT NOT NULL REFERENCES locations(id),
    demand_qty       REAL NOT NULL DEFAULT 0.0,
    reserved_qty     REAL NOT NULL DEFAULT 0.0,
    done_qty         REAL NOT NULL DEFAULT 0.0,
    uom_id           TEXT NOT NULL REFERENCES product_uoms(id),
    status           TEXT NOT NULL DEFAULT 'draft', -- draft, reserved, done, cancelled
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_picking_lines_pick ON stock_picking_lines(picking_id);

-- 11. STOCK MOVES
CREATE TABLE IF NOT EXISTS stock_moves (
    id               TEXT PRIMARY KEY,
    picking_id       TEXT REFERENCES stock_pickings(id),
    picking_line_id  TEXT REFERENCES stock_picking_lines(id),
    product_id       TEXT NOT NULL REFERENCES products(id),
    lot_id           TEXT REFERENCES stock_lots(id),
    lpn_id           TEXT REFERENCES stock_lpns(id),
    source_location_id TEXT NOT NULL REFERENCES locations(id),
    dest_location_id   TEXT NOT NULL REFERENCES locations(id),
    quantity         REAL NOT NULL,
    status           TEXT NOT NULL DEFAULT 'draft', -- draft, done, cancelled
    transport_type   TEXT DEFAULT 'forklift', -- forklift, agv, conveyor, manual
    date             TIMESTAMPTZ NOT NULL DEFAULT now(),
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_moves_date ON stock_moves(date);
CREATE INDEX IF NOT EXISTS idx_moves_prod ON stock_moves(product_id);

-- 12. PHARMA SERIAL NUMBERS (Serialization chống giả)
CREATE TABLE IF NOT EXISTS stock_serial_numbers (
    id               TEXT PRIMARY KEY,
    product_id       TEXT NOT NULL REFERENCES products(id),
    lot_id           TEXT NOT NULL REFERENCES stock_lots(id),
    serial_number    TEXT NOT NULL UNIQUE,
    location_id      TEXT NOT NULL REFERENCES locations(id),
    status           TEXT NOT NULL DEFAULT 'available', -- available, reserved, dispensed, destroyed, recalled
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_serials_lot ON stock_serial_numbers(lot_id);
CREATE INDEX IF NOT EXISTS idx_serials_sn ON stock_serial_numbers(serial_number);

-- 13. PHARMA CONTROLLED APPROVALS (Ký duyệt kép thuốc gây nghiện / hướng thần)
CREATE TABLE IF NOT EXISTS pharma_controlled_approvals (
    id                 TEXT PRIMARY KEY,
    picking_line_id    TEXT NOT NULL REFERENCES stock_picking_lines(id),
    product_id         TEXT NOT NULL REFERENCES products(id),
    authorized_by_1    TEXT NOT NULL, -- Dược sĩ trưởng
    signature_1        TEXT NOT NULL,
    timestamp_1        TIMESTAMPTZ NOT NULL,
    authorized_by_2    TEXT NOT NULL, -- Bác sĩ điều trị / Trưởng khoa
    signature_2        TEXT NOT NULL,
    timestamp_2        TIMESTAMPTZ NOT NULL,
    reason_notes       TEXT,
    tenant_id          TEXT NOT NULL DEFAULT 'default',
    created_by         TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by         TEXT,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id   TEXT,
    last_seq           BIGINT NOT NULL DEFAULT 0,
    deleted_at         TIMESTAMPTZ,
    is_seed            BOOLEAN NOT NULL DEFAULT FALSE
);

-- 14. PHARMA DISPENSING LOGS (Cấp phát thuốc đầu giường theo bệnh án)
CREATE TABLE IF NOT EXISTS pharma_dispensing_logs (
    id                 TEXT PRIMARY KEY,
    prescription_id    TEXT NOT NULL,
    patient_id         TEXT NOT NULL,
    patient_barcode    TEXT NOT NULL,
    product_id         TEXT NOT NULL REFERENCES products(id),
    lot_id             TEXT NOT NULL REFERENCES stock_lots(id),
    serial_number_id   TEXT REFERENCES stock_serial_numbers(id),
    dispensed_qty      REAL NOT NULL DEFAULT 1.0,
    dispensed_by       TEXT NOT NULL, -- Điều dưỡng cấp phát
    verified_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    tenant_id          TEXT NOT NULL DEFAULT 'default',
    created_by         TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by         TEXT,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id   TEXT,
    last_seq           BIGINT NOT NULL DEFAULT 0,
    deleted_at         TIMESTAMPTZ,
    is_seed            BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_dispensing_patient ON pharma_dispensing_logs(patient_id, prescription_id);

-- 15. IOT DEVICES (Sổ đăng ký thiết bị cảm biến LoRaWAN / BLE)
CREATE TABLE IF NOT EXISTS iot_devices (
    id                    TEXT PRIMARY KEY,
    dev_eui               TEXT NOT NULL UNIQUE,
    name                  TEXT NOT NULL,
    device_type           TEXT NOT NULL, -- temperature, humidity, co2, scale, metal_detector, vision_camera, door
    vendor                TEXT,
    model                 TEXT,
    codec_id              TEXT NOT NULL,
    location_id           TEXT REFERENCES locations(id),
    tracked_product_id    TEXT REFERENCES products(id),
    status                TEXT NOT NULL DEFAULT 'active',
    battery_level         REAL,
    last_rssi             INT,
    last_snr              REAL,
    last_seen_at          TIMESTAMPTZ,
    expected_interval_sec INT,
    last_frame_counter    INT,
    custom_fields         TEXT DEFAULT '{}',
    tenant_id             TEXT NOT NULL DEFAULT 'default',
    created_by            TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by            TEXT,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id      TEXT,
    last_seq              BIGINT NOT NULL DEFAULT 0,
    deleted_at            TIMESTAMPTZ,
    is_seed               BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_iot_dev_loc ON iot_devices(location_id);

-- 16. SENSOR READINGS (Dữ liệu đo chuỗi thời gian Append-Only)
CREATE TABLE IF NOT EXISTS sensor_readings (
    id               TEXT PRIMARY KEY,
    device_id        TEXT NOT NULL REFERENCES iot_devices(id),
    location_id      TEXT REFERENCES locations(id),
    metric           TEXT NOT NULL, -- temperature, humidity, co2, weight_kg, metal_detect, vision_defect
    value            REAL NOT NULL,
    unit             TEXT NOT NULL,
    measured_at      TIMESTAMPTZ NOT NULL,
    received_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    quality          TEXT NOT NULL DEFAULT 'ok', -- ok, suspect, stale, calibrating
    rollup_level     TEXT NOT NULL DEFAULT 'raw', -- raw, minute, hour, day
    sample_count     INT NOT NULL DEFAULT 1,
    min_value        REAL,
    max_value        REAL,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ,
    is_seed          BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_readings_device_time ON sensor_readings(device_id, measured_at);
CREATE INDEX IF NOT EXISTS idx_readings_loc_metric ON sensor_readings(location_id, metric);

-- 17. AUTOMATION RULES (Luật phản ứng chống rung)
CREATE TABLE IF NOT EXISTS automation_rules (
    id                   TEXT PRIMARY KEY,
    name                 TEXT NOT NULL,
    description          TEXT,
    is_enabled           BOOLEAN NOT NULL DEFAULT TRUE,
    scope_type           TEXT NOT NULL, -- device, location_subtree, device_type, all
    scope_value          TEXT,
    metric               TEXT NOT NULL,
    comparator           TEXT NOT NULL, -- gt, gte, lt, lte, eq, neq, delta_pct, no_data
    threshold            REAL,
    threshold_seconds    INT,
    debounce_count       INT NOT NULL DEFAULT 2,
    debounce_window_sec  INT,
    cooldown_sec         INT NOT NULL DEFAULT 300,
    action_type          TEXT NOT NULL, -- notify, auto_quarantine, create_stock_move, trigger_door, webhook
    action_config        TEXT DEFAULT '{}',
    severity             TEXT NOT NULL DEFAULT 'info',
    last_triggered_at    TIMESTAMPTZ,
    trigger_count        INT NOT NULL DEFAULT 0,
    tenant_id            TEXT NOT NULL DEFAULT 'default',
    created_by           TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by           TEXT,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id     TEXT,
    last_seq             BIGINT NOT NULL DEFAULT 0,
    deleted_at           TIMESTAMPTZ,
    is_seed              BOOLEAN NOT NULL DEFAULT FALSE
);

-- 18. AUTOMATION EVENTS (Nhật ký kích hoạt luật)
CREATE TABLE IF NOT EXISTS automation_events (
    id                    TEXT PRIMARY KEY,
    rule_id               TEXT NOT NULL REFERENCES automation_rules(id),
    device_id             TEXT REFERENCES iot_devices(id),
    location_id           TEXT REFERENCES locations(id),
    triggering_reading_id TEXT REFERENCES sensor_readings(id),
    triggering_value      REAL,
    triggered_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    status                TEXT NOT NULL DEFAULT 'pending', -- pending, executed, failed, suppressed_cooldown, suppressed_debounce
    result_record_type    TEXT,
    result_record_id      TEXT,
    error_message         TEXT,
    acknowledged_by       TEXT,
    acknowledged_at       TIMESTAMPTZ,
    tenant_id             TEXT NOT NULL DEFAULT 'default',
    created_by            TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by            TEXT,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id      TEXT,
    last_seq              BIGINT NOT NULL DEFAULT 0,
    deleted_at            TIMESTAMPTZ,
    is_seed               BOOLEAN NOT NULL DEFAULT FALSE
);
