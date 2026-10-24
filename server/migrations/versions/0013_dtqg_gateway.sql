-- Migration 0013: DtqgGateway — kết nối Đơn thuốc quốc gia (QĐ 808/QĐ-BYT)
-- Chạy được trên cả SQLite lẫn PostgreSQL (mọi mốc thời gian là TEXT ISO-8601 UTC).
--
-- Các bảng này CHỈ nằm ở server và KHÔNG đi qua sync_mutations, nên mật khẩu và
-- token liên thông không bao giờ xuống thiết bị nhân viên.

-- Mật khẩu liên thông của cơ sở và từng bác sĩ — mã hóa Fernet (IZIIAPP_DTQG_CRED_KEY).
CREATE TABLE IF NOT EXISTS dtqg_credentials (
    subject_type  TEXT NOT NULL,          -- 'facility' | 'doctor'
    subject_code  TEXT NOT NULL,          -- mã liên thông
    password_enc  TEXT NOT NULL,
    updated_at    TEXT NOT NULL,
    updated_by    TEXT,
    PRIMARY KEY (subject_type, subject_code)
);

-- Token đăng nhập (hiệu lực 7 ngày) — cache để không đăng nhập lại mỗi đơn.
CREATE TABLE IF NOT EXISTS dtqg_sessions (
    subject_type  TEXT NOT NULL,
    subject_code  TEXT NOT NULL,
    token         TEXT NOT NULL,
    expires_at    TEXT NOT NULL,
    created_at    TEXT NOT NULL,
    PRIMARY KEY (subject_type, subject_code)
);

-- Bác sĩ đã được thêm vào cơ sở (API thêm bác sĩ chỉ cần gọi một lần).
CREATE TABLE IF NOT EXISTS dtqg_doctor_links (
    facility_code TEXT NOT NULL,
    doctor_code   TEXT NOT NULL,
    added_at      TEXT NOT NULL,
    PRIMARY KEY (facility_code, doctor_code)
);

-- Nhật ký MỖI lần gửi đơn. Lưu nguyên văn danh_sach_cac_loi, không rút gọn/dịch.
CREATE TABLE IF NOT EXISTS dtqg_submissions (
    id              TEXT PRIMARY KEY,
    prescription_id TEXT NOT NULL,
    ma_don_thuoc    TEXT,
    kind            TEXT NOT NULL DEFAULT 'gui_don',   -- gui_don | pos_cap_nhat
    attempt         INTEGER NOT NULL DEFAULT 1,
    http_status     INTEGER,
    ok              INTEGER NOT NULL DEFAULT 0,
    errors          TEXT,                              -- JSON list
    payload_hash    TEXT,
    created_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_dtqg_submissions_rx ON dtqg_submissions(prescription_id, created_at);
CREATE INDEX IF NOT EXISTS idx_dtqg_submissions_ma ON dtqg_submissions(ma_don_thuoc, ok);

-- POS nhà thuốc: mỗi lần bán theo đơn (một đơn có thể bán nhiều lần cho tới khi hết).
CREATE TABLE IF NOT EXISTS dtqg_pos_sales (
    id               TEXT PRIMARY KEY,
    ma_don_thuoc     TEXT NOT NULL,
    ma_hoa_don       TEXT NOT NULL,
    lines            TEXT NOT NULL,                    -- JSON: thong_tin_thuoc đã gửi
    meta             TEXT NOT NULL DEFAULT '{}',       -- JSON: phần còn lại của body (cơ sở cung ứng, mã hóa đơn) để gửi lại
    sync_status      TEXT NOT NULL DEFAULT 'pending',  -- pending | sent | rejected
    last_error       TEXT,
    created_by       TEXT,
    created_at       TEXT NOT NULL,
    sent_at          TEXT
);
CREATE INDEX IF NOT EXISTS idx_dtqg_pos_sales_ma ON dtqg_pos_sales(ma_don_thuoc);
