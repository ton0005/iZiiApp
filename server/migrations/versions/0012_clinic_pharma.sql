-- Migration 0012: Clinic & Pharmacy read models (module clinic_pharma)
-- Mutation tables doctors / patients / appointments / medical_visits / prescriptions /
-- prescription_items / clinic_facility are mapped to clinic_* via TABLE_ALIASES (projector.py).
-- Đơn thuốc quốc gia (QĐ 808): mật khẩu liên thông KHÔNG nằm ở đây; token/mật khẩu sẽ
-- nằm ở bảng riêng của DtqgGateway (giai đoạn D), không đồng bộ xuống thiết bị.

CREATE TABLE IF NOT EXISTS clinic_doctors (
    id               TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    specialty TEXT DEFAULT '',
    phone TEXT,
    email TEXT,
    so_cchn TEXT,
    ma_lien_thong_dtqg TEXT,
    duoc_ke_don BOOLEAN NOT NULL DEFAULT TRUE,
    dtqg_status TEXT NOT NULL DEFAULT 'pending',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    custom_fields TEXT DEFAULT '{}',
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_clinic_doctors_tenant ON clinic_doctors(tenant_id, id);

CREATE TABLE IF NOT EXISTS clinic_patients (
    id               TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    dob TEXT,
    gender TEXT,
    phone TEXT,
    address TEXT,
    id_number TEXT,
    ma_dinh_danh_y_te TEXT,
    so_cccd TEXT,
    ma_the_bhyt TEXT,
    guardian_name TEXT,
    guardian_phone TEXT,
    guardian_address TEXT,
    custom_fields TEXT DEFAULT '{}',
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_clinic_patients_tenant ON clinic_patients(tenant_id, id);

CREATE TABLE IF NOT EXISTS clinic_appointments (
    id               TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    doctor_id TEXT,
    scheduled_at TEXT NOT NULL,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'scheduled',
    notes TEXT,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_clinic_appointments_tenant ON clinic_appointments(tenant_id, id);

CREATE TABLE IF NOT EXISTS clinic_medical_visits (
    id               TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    doctor_id TEXT,
    appointment_id TEXT,
    visit_date TEXT,
    chief_complaint TEXT,
    diagnosis TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_clinic_medical_visits_tenant ON clinic_medical_visits(tenant_id, id);

CREATE TABLE IF NOT EXISTS clinic_prescriptions (
    id               TEXT PRIMARY KEY,
    visit_id TEXT NOT NULL,
    patient_id TEXT NOT NULL,
    doctor_id TEXT,
    prescription_date TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    ma_don_thuoc TEXT,
    loai_don TEXT NOT NULL DEFAULT 'c',
    chan_doan_json TEXT NOT NULL DEFAULT '[]',
    can_nang DOUBLE PRECISION,
    hinh_thuc_dieu_tri INT,
    nguoi_giam_ho TEXT,
    loi_dan TEXT,
    ngay_tai_kham INT,
    dtqg_status TEXT NOT NULL DEFAULT 'draft',
    dtqg_sent_at TEXT,
    dtqg_last_error TEXT,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_clinic_prescriptions_tenant ON clinic_prescriptions(tenant_id, id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_clinic_prescriptions_ma_don ON clinic_prescriptions(ma_don_thuoc) WHERE ma_don_thuoc IS NOT NULL;

CREATE TABLE IF NOT EXISTS clinic_prescription_items (
    id               TEXT PRIMARY KEY,
    prescription_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    medicine_name TEXT NOT NULL,
    dosage_instructions TEXT,
    ma_thuoc_cuc_qldd TEXT,
    biet_duoc TEXT,
    don_vi_tinh TEXT,
    so_luong_ban DOUBLE PRECISION,
    quantity DOUBLE PRECISION NOT NULL DEFAULT 1,
    unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_clinic_prescription_items_tenant ON clinic_prescription_items(tenant_id, id);

CREATE TABLE IF NOT EXISTS clinic_facility (
    id               TEXT PRIMARY KEY,
    ma_cskcb TEXT NOT NULL DEFAULT '',
    name TEXT NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    ma_lien_thong_dtqg TEXT,
    ma_dinh_danh_cung_ung TEXT,
    tenant_id        TEXT NOT NULL DEFAULT 'default',
    created_by       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_mutation_id TEXT,
    last_seq         BIGINT NOT NULL DEFAULT 0,
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_clinic_facility_tenant ON clinic_facility(tenant_id, id);
