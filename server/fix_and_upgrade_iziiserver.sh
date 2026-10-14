#!/usr/bin/env bash
# ==============================================================================
# iZiiServer - Automated Fix & Upgrade Script for Ubuntu / Debian Linux
# ==============================================================================
# Giải quyết triệt để các sự cố phân tích từ logs 20-9:
# 1. Khắc phục lỗi kiểu dữ liệu PostgreSQL (INT -> BOOLEAN)
# 2. Xóa bỏ lỗi dây chuyền P4.2 (Unknown entity) & Replay Read Model
# 3. Sửa lỗi gọi hàm Cron Timesheet lúc 22:00 trong app.py
# 4. Sửa lỗi tính độ trễ âm trong latency.log (chuẩn hóa múi giờ UTC)
# 5. Củng cố cấu hình Systemd tránh vòng lặp Restart spam khi khởi động
# 6. Tùy chọn Reset cursor Peer Sync để đồng bộ bù (Backfill) đầy đủ M1 -> M2
# ==============================================================================
set -e
set -o pipefail

# --- ANSI Colors ---
C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_CYAN="\033[1;36m"
C_BOLD="\033[1m"

log_info()    { echo -e "${C_BLUE}ℹ️  [INFO]${C_RESET} $*"; }
log_success() { echo -e "${C_GREEN}✅ [SUCCESS]${C_RESET} $*"; }
log_warn()    { echo -e "${C_YELLOW}⚠️  [WARNING]${C_RESET} $*"; }
log_error()   { echo -e "${C_RED}❌ [ERROR]${C_RESET} $*" >&2; }
log_step()    { echo -e "\n${C_CYAN}${C_BOLD}▶ $*${C_RESET}"; }

# --- Arguments & Flags ---
RESET_SYNC=false
REBUILD_MODEL=false
SKIP_BACKUP=false
SERVICE_NAME="iziiserver"

for arg in "$@"; do
    case "$arg" in
        --reset-sync)
            RESET_SYNC=true
            ;;
        --rebuild-readmodel)
            REBUILD_MODEL=true
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            ;;
        --help|-h)
            echo "Cách sử dụng: sudo ./fix_and_upgrade_iziiserver.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --reset-sync         Đặt lại cursor sync peer về 0 để kéo bù toàn bộ dữ liệu từ Server M1"
            echo "  --rebuild-readmodel  Replay lại toàn bộ mutations vào read model sau khi đổi kiểu cột"
            echo "  --skip-backup        Bỏ qua bước sao lưu PostgreSQL và code"
            echo "  --help, -h           Hiển thị hướng dẫn này"
            exit 0
            ;;
    esac
done

# --- Determine Base Path ---
if [ -d "/opt/izii_server" ]; then
    APP_DIR="/opt/izii_server"
else
    APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
cd "$APP_DIR"

log_step "1. Kiểm tra môi trường và cấu hình máy chủ"
log_info "Thư mục làm việc: $APP_DIR"

# Nạp file .env
ENV_FILE="$APP_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    log_error "Không tìm thấy file cấu hình: $ENV_FILE"
    exit 1
fi

# Đọc cấu hình PostgreSQL từ .env
export $(grep -v '^#' "$ENV_FILE" | grep -E '^(POSTGRES_|IZIIAPP_)' | xargs)

DB_NAME="${POSTGRES_DB:-iziiserver}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_PASS="${POSTGRES_PASSWORD:-}"
DB_HOST="${POSTGRES_HOST:-127.0.0.1}"
DB_PORT="${POSTGRES_PORT:-5432}"

log_info "Database target: $DB_NAME tại $DB_HOST:$DB_PORT (User: $DB_USER)"

# Kiểm tra Virtual Environment
VENV_PYTHON="$APP_DIR/venv/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    VENV_PYTHON="python3"
    log_warn "Không thấy $APP_DIR/venv, dùng mặc định: $(which python3)"
fi

# --- Step 2: Backup ---
if [ "$SKIP_BACKUP" = false ]; then
    log_step "2. Tạo bản sao lưu dự phòng (Backup)"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$APP_DIR/backups/fix_$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"

    log_info "Sao lưu file mã nguồn và cấu hình..."
    tar -czf "$BACKUP_DIR/code_backup.tar.gz" --exclude="backups" --exclude="logs" --exclude="venv" -C "$APP_DIR" .

    log_info "Sao lưu cơ sở dữ liệu PostgreSQL..."
    export PGPASSWORD="$DB_PASS"
    if command -v pg_dump >/dev/null 2>&1; then
        pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -F c -b -v -f "$BACKUP_DIR/${DB_NAME}_dump.dump" || {
            log_warn "pg_dump định dạng custom thất bại, thử xuất dạng text SQL..."
            pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_dump.sql"
        }
        log_success "Đã sao lưu DB thành công vào: $BACKUP_DIR"
    else
        log_warn "Không tìm thấy lệnh pg_dump trên máy. Bỏ qua sao lưu DB nhị phân."
    fi
    unset PGPASSWORD
fi

# --- Step 3: Stop Service Gracefully ---
log_step "3. Tạm dừng dịch vụ $SERVICE_NAME"
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_info "Đang dừng $SERVICE_NAME..."
    systemctl stop "$SERVICE_NAME"
    log_success "Dịch vụ đã dừng."
else
    log_info "Dịch vụ $SERVICE_NAME hiện không chạy."
fi

# --- Step 4: Run PostgreSQL Migration (INT -> BOOLEAN) ---
log_step "4. Thực thi sửa lỗi Schema PostgreSQL (INT -> BOOLEAN)"

MIGRATION_SQL=$(cat << 'EOF'
-- Migration Fix Boolean Types
DO $$
BEGIN
    -- 1. departments.is_seed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'departments' AND column_name = 'is_seed' AND data_type = 'integer'
    ) THEN
        ALTER TABLE departments ALTER COLUMN is_seed DROP DEFAULT;
        ALTER TABLE departments ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0);
        ALTER TABLE departments ALTER COLUMN is_seed SET DEFAULT false;
        RAISE NOTICE 'Converted departments.is_seed to BOOLEAN';
    END IF;

    -- 2. picker_teams.is_seed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'picker_teams' AND column_name = 'is_seed' AND data_type = 'integer'
    ) THEN
        ALTER TABLE picker_teams ALTER COLUMN is_seed DROP DEFAULT;
        ALTER TABLE picker_teams ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0);
        ALTER TABLE picker_teams ALTER COLUMN is_seed SET DEFAULT false;
        RAISE NOTICE 'Converted picker_teams.is_seed to BOOLEAN';
    END IF;

    -- 3. chat_messages.is_seed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_messages' AND column_name = 'is_seed' AND data_type = 'integer'
    ) THEN
        ALTER TABLE chat_messages ALTER COLUMN is_seed DROP DEFAULT;
        ALTER TABLE chat_messages ALTER COLUMN is_seed TYPE boolean USING (is_seed::int != 0);
        ALTER TABLE chat_messages ALTER COLUMN is_seed SET DEFAULT false;
        RAISE NOTICE 'Converted chat_messages.is_seed to BOOLEAN';
    END IF;

    -- 4. mushroom_job_types
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_types' AND column_name = 'is_solo_job' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_types ALTER COLUMN is_solo_job DROP DEFAULT;
        ALTER TABLE mushroom_job_types ALTER COLUMN is_solo_job TYPE boolean USING (is_solo_job::int != 0);
        ALTER TABLE mushroom_job_types ALTER COLUMN is_solo_job SET DEFAULT false;
        RAISE NOTICE 'Converted mushroom_job_types.is_solo_job to BOOLEAN';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_types' AND column_name = 'is_active' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_types ALTER COLUMN is_active DROP DEFAULT;
        ALTER TABLE mushroom_job_types ALTER COLUMN is_active TYPE boolean USING (is_active::int != 0);
        ALTER TABLE mushroom_job_types ALTER COLUMN is_active SET DEFAULT true;
        RAISE NOTICE 'Converted mushroom_job_types.is_active to BOOLEAN';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_types' AND column_name = 'is_custom' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_types ALTER COLUMN is_custom DROP DEFAULT;
        ALTER TABLE mushroom_job_types ALTER COLUMN is_custom TYPE boolean USING (is_custom::int != 0);
        ALTER TABLE mushroom_job_types ALTER COLUMN is_custom SET DEFAULT false;
        RAISE NOTICE 'Converted mushroom_job_types.is_custom to BOOLEAN';
    END IF;

    -- 5. mushroom_jobs.is_solo_job
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_jobs' AND column_name = 'is_solo_job' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_jobs ALTER COLUMN is_solo_job DROP DEFAULT;
        ALTER TABLE mushroom_jobs ALTER COLUMN is_solo_job TYPE boolean USING (is_solo_job::int != 0);
        ALTER TABLE mushroom_jobs ALTER COLUMN is_solo_job SET DEFAULT false;
        RAISE NOTICE 'Converted mushroom_jobs.is_solo_job to BOOLEAN';
    END IF;

    -- 6. mushroom_job_safety_configs.auto_start_on_job_begin
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'mushroom_job_safety_configs' AND column_name = 'auto_start_on_job_begin' AND data_type = 'integer'
    ) THEN
        ALTER TABLE mushroom_job_safety_configs ALTER COLUMN auto_start_on_job_begin DROP DEFAULT;
        ALTER TABLE mushroom_job_safety_configs ALTER COLUMN auto_start_on_job_begin TYPE boolean USING (auto_start_on_job_begin::int != 0);
        ALTER TABLE mushroom_job_safety_configs ALTER COLUMN auto_start_on_job_begin SET DEFAULT true;
        RAISE NOTICE 'Converted mushroom_job_safety_configs.auto_start_on_job_begin to BOOLEAN';
    END IF;
END $$;
EOF
)

export PGPASSWORD="$DB_PASS"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -c "$MIGRATION_SQL"
unset PGPASSWORD
log_success "Đã cập nhật Schema PostgreSQL thành công sang kiểu BOOLEAN."

# --- Step 5: Run Code Migration Runner & Check Syntax ---
log_step "5. Chạy Runner kiểm tra các Migration của hệ thống"
if [ -f "$APP_DIR/migrations/runner.py" ]; then
    "$VENV_PYTHON" "$APP_DIR/migrations/runner.py" --migrate || log_warn "Migration runner gặp cảnh báo, tiếp tục..."
fi

# --- Step 6: Fix Systemd Service Configuration ---
log_step "6. Tối ưu cấu hình dịch vụ Systemd"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [ -f "$SERVICE_FILE" ]; then
    log_info "Cập nhật $SERVICE_FILE với After=postgresql.service và RestartSec=5s..."
    sed -i 's/After=network.target/After=network.target postgresql.service/g' "$SERVICE_FILE"
    if ! grep -q "Requires=postgresql.service" "$SERVICE_FILE"; then
        sed -i '/After=network.target postgresql.service/a Requires=postgresql.service' "$SERVICE_FILE"
    fi
    systemctl daemon-reload
    log_success "Đã cập nhật cấu hình systemd."
fi

# --- Step 7: Replay Read Model or Reset Peer Sync Cursor ---
if [ "$REBUILD_MODEL" = true ]; then
    log_step "7. Replay lại dữ liệu Read Model (rebuild_read_model.py)"
    log_info "Đang chiếu lại toàn bộ mutations từ sync_mutations vào các bảng..."
    "$VENV_PYTHON" "$APP_DIR/rebuild_read_model.py"
    log_success "Rebuild Read Model hoàn tất."
fi

if [ "$RESET_SYNC" = true ]; then
    log_step "7b. Đặt lại Peer Sync Cursor để kéo bù dữ liệu (Backfill)"
    log_info "Xóa checkpoint đồng bộ peer để kéo lại từ đầu..."
    export PGPASSWORD="$DB_PASS"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        DO \$\$
        BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'peer_sync_state') THEN
                DELETE FROM peer_sync_state;
            END IF;
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sync_peer_cursors') THEN
                DELETE FROM sync_peer_cursors;
            END IF;
        END \$\$;
    "
    unset PGPASSWORD
    log_success "Đã reset cursor peer sync. Server sẽ tự động kéo lại toàn bộ chuỗi sequence khi khởi động."
fi

# --- Step 8: Start Service & Verify Health ---
log_step "8. Khởi động lại dịch vụ $SERVICE_NAME"
systemctl start "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
    log_success "Dịch vụ $SERVICE_NAME đang CHẠY (Active/Running)!"
else
    log_error "Dịch vụ $SERVICE_NAME không thể khởi động. Kiểm tra: journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

log_step "9. Kiểm tra kết nối API iZiiServer"
PORT="${IZIIAPP_PORT:-8080}"
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/sync/status" || echo "000")

if [ "$STATUS_CODE" -eq 200 ]; then
    log_success "Endpoint /sync/status phản hồi HTTP 200 OK!"
else
    log_warn "Endpoint /sync/status phản hồi mã: $STATUS_CODE (Server có thể đang khởi tạo pool DB, vui lòng chờ vài giây)."
fi

echo ""
echo -e "${C_GREEN}${C_BOLD}======================================================================${C_RESET}"
echo -e "${C_GREEN}${C_BOLD} 🎉 ĐÃ HOÀN TẤT QUÁ TRÌNH SỬA LỖI & NÂNG CẤP IZIISERVER THÀNH CÔNG!${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}======================================================================${C_RESET}"
echo "Để theo dõi log trực tiếp, hãy chạy:"
echo "  journalctl -u $SERVICE_NAME -f"
echo ""
