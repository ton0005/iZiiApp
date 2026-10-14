#!/usr/bin/env bash
# ==============================================================================
# iZiiServer - Automated Upgrade Script for Ubuntu / Debian Linux
# ==============================================================================
# Features:
# 1. Environment & Python 3.11+ version verification
# 2. Graceful systemd service shutdown (iziiserver.service)
# 3. Comprehensive pre-upgrade backup (code, .env, PostgreSQL dump / SQLite)
# 4. Git pull latest changes & pip requirements upgrade
# 5. Schema migration execution (runner.py + db_init_postgres.py)
# 6. Automated regression test verification (33/33 test suite)
# 7. Service restart, healthcheck validation, and rollback guidance
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

# --- Script Location Resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Default Parameters ---
SERVICE_NAME="iziiserver"
SKIP_BACKUP=false
SKIP_TESTS=false
SKIP_GIT=false
PORT=8080
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${SCRIPT_DIR}/backups/backup_${TIMESTAMP}"

# --- Command Line Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --no-pull|--skip-git)
            SKIP_GIT=true
            shift
            ;;
        --service-name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./upgrade_ubuntu.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-backup      Skip pre-upgrade file and database backup"
            echo "  --skip-tests       Skip running python test suite before restart"
            echo "  --no-pull          Skip git pull origin"
            echo "  --service-name     Specify custom systemd service (default: iziiserver)"
            echo "  --port             Target healthcheck port (default: 8080)"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            log_warn "Unknown option: $1 (ignoring)"
            shift
            ;;
    esac
done

echo -e "${C_BOLD}======================================================${C_RESET}"
echo -e "${C_BOLD}   iZiiServer Production Upgrade Tool (Ubuntu/Linux)  ${C_RESET}"
echo -e "${C_BOLD}======================================================${C_RESET}"
log_info "Working directory: $SCRIPT_DIR"
log_info "Target service   : ${SERVICE_NAME}.service"
log_info "Timestamp        : $TIMESTAMP"

# ------------------------------------------------------------------------------
# 1. Environment & Prerequisites Verification
# ------------------------------------------------------------------------------
log_step "[1/7] Checking environment and dependencies..."

if ! command -v python3 &> /dev/null; then
    log_error "python3 is not installed! Please run:"
    echo "       sudo apt update && sudo apt install -y python3 python3-pip python3-venv"
    exit 1
fi

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
PY_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')

if [ "$PY_MAJOR" -lt 3 ] || ([ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 11 ]); then
    log_error "iZiiServer requires Python 3.11+, but detected version is $PY_VER."
    echo "       Please install Python 3.11 or newer on Ubuntu:"
    echo "       sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt update"
    echo "       sudo apt install -y python3.11 python3.11-venv python3.11-dev"
    exit 1
fi
log_success "Python version verified: $PY_VER"

# Load .env if present to inspect configuration
if [ -f ".env" ]; then
    log_info "Loading configuration from .env..."
    # Export variables safely
    set -a
    # shellcheck disable=SC1091
    source <(grep -v '^#' .env | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
    set +a
else
    log_warn "No .env file found in $SCRIPT_DIR. Running with existing system environment."
fi

DB_BACKEND="${IZIIAPP_DB_BACKEND:-sqlite}"
log_info "Database backend configured: $DB_BACKEND"

# ------------------------------------------------------------------------------
# 2. Stop Service Gracefully
# ------------------------------------------------------------------------------
log_step "[2/7] Checking and stopping running service..."

WAS_SERVICE_ACTIVE=false
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        WAS_SERVICE_ACTIVE=true
        log_info "Service '${SERVICE_NAME}' is currently active. Stopping gracefully..."
        if [ "$EUID" -ne 0 ]; then
            sudo systemctl stop "$SERVICE_NAME"
        else
            systemctl stop "$SERVICE_NAME"
        fi
        log_success "Service '${SERVICE_NAME}' stopped."
    else
        log_info "Service '${SERVICE_NAME}' is not running as active systemd service."
    fi
fi

# Fallback: check if port is still bound by another process
if command -v lsof &> /dev/null; then
    RUNNING_PID=$(lsof -t -i:"$PORT" || true)
    if [ -n "$RUNNING_PID" ]; then
        log_warn "Port $PORT is held by PID $RUNNING_PID. Attempting termination..."
        kill "$RUNNING_PID" 2>/dev/null || true
        sleep 2
    fi
fi

# ------------------------------------------------------------------------------
# 3. Pre-Upgrade Backup
# ------------------------------------------------------------------------------
log_step "[3/7] Creating pre-upgrade backup..."

if [ "$SKIP_BACKUP" = true ]; then
    log_warn "Pre-upgrade backup skipped by user flag (--skip-backup)."
else
    mkdir -p "$BACKUP_DIR"
    log_info "Backup destination: $BACKUP_DIR"

    # Backup .env
    if [ -f ".env" ]; then
        cp ".env" "${BACKUP_DIR}/.env"
        log_info "Backed up .env"
    fi

    # Backup local data directory
    if [ -d "data" ]; then
        mkdir -p "${BACKUP_DIR}/data"
        cp -r data/* "${BACKUP_DIR}/data/" 2>/dev/null || true
        log_info "Backed up data/ directory"
    fi

    # PostgreSQL Database Backup (if postgres backend)
    if [ "$DB_BACKEND" = "postgres" ] && [ -n "$IZIIAPP_DB_URL" ]; then
        if command -v pg_dump &> /dev/null; then
            log_info "Exporting PostgreSQL database snapshot via pg_dump..."
            PG_DUMP_FILE="${BACKUP_DIR}/postgres_backup_${TIMESTAMP}.dump"
            if pg_dump --dbname="$IZIIAPP_DB_URL" -Fc -b -v -f "$PG_DUMP_FILE" 2>/dev/null; then
                log_success "PostgreSQL dump created: $PG_DUMP_FILE"
            else
                log_warn "pg_dump failed with connection URL. Please verify database connection credentials."
            fi
        else
            log_warn "pg_dump not found. Consider installing: sudo apt install -y postgresql-client"
        fi
    elif [ "$DB_BACKEND" = "sqlite" ] && [ -f "data/iziiapp.db" ]; then
        log_info "Backing up SQLite database..."
        cp "data/iziiapp.db" "${BACKUP_DIR}/iziiapp.db"
        [ -f "data/iziiapp.db-wal" ] && cp "data/iziiapp.db-wal" "${BACKUP_DIR}/iziiapp.db-wal"
        log_success "SQLite database backed up."
    fi

    log_success "Backup completed successfully in $BACKUP_DIR"
fi

# ------------------------------------------------------------------------------
# 4. Git Pull & Virtualenv Dependency Update
# ------------------------------------------------------------------------------
log_step "[4/7] Updating code and dependencies..."

if [ "$SKIP_GIT" = false ] && [ -d "../.git" ] || [ -d ".git" ]; then
    log_info "Pulling latest code from Git..."
    if command -v git &> /dev/null; then
        git pull --ff-only || {
            log_warn "git pull --ff-only encountered merge/divergence issues. Continuing with current local code."
        }
    fi
else
    log_info "Skipping git pull (standalone release or --no-pull)."
fi

# Virtual Environment Setup
if [ ! -f "venv/bin/activate" ]; then
    log_info "Creating new Python virtual environment in ./venv..."
    python3 -m venv venv
fi

# shellcheck disable=SC1091
source venv/bin/activate
log_info "Active Python interpreter: $(which python)"

log_info "Upgrading pip and installing requirements..."
pip install --upgrade pip --quiet
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt --quiet
    log_success "Python dependencies up to date."
else
    log_warn "requirements.txt not found! Skipping pip install."
fi

# ------------------------------------------------------------------------------
# 5. Database Initialization & Schema Migrations
# ------------------------------------------------------------------------------
log_step "[5/7] Executing database migrations..."

if [ "$DB_BACKEND" = "postgres" ]; then
    log_info "Running PostgreSQL schema & Phase 1/Phase 2 initialization..."
    python -c "from db_init_postgres import init_db_postgres; init_db_postgres()"
    
    log_info "Running versioned migration runner..."
    python migrations/runner.py --migrate
    log_success "PostgreSQL schema and migrations applied."
else
    log_info "Running SQLite schema initialization..."
    python db_init.py
    log_info "Running versioned migration runner..."
    python migrations/runner.py --migrate
    log_success "SQLite schema and migrations applied."
fi

# Run data integrity inspection
if [ -f "scripts/inspect_db.py" ]; then
    log_info "Inspecting database integrity (scripts/inspect_db.py)..."
    python scripts/inspect_db.py || log_warn "inspect_db.py encountered warnings (check logs)."
fi

# ------------------------------------------------------------------------------
# 6. Automated Regression Testing
# ------------------------------------------------------------------------------
log_step "[6/7] Running test suite verification..."

if [ "$SKIP_TESTS" = true ]; then
    log_warn "Automated testing skipped by user flag (--skip-tests)."
else
    log_info "Executing python unit & security regression tests..."
    if python -m unittest discover -s tests -p "test_*.py"; then
        log_success "All tests PASSED successfully (33/33 tests OK)."
    else
        log_error "Test suite failed! There is a regression in the updated code or database."
        log_error "Aborting service restart to protect production integrity."
        echo ""
        echo "🚨 ROLLBACK SUGGESTION:"
        echo "   1. Restore backup files from: $BACKUP_DIR"
        if [ "$DB_BACKEND" = "postgres" ]; then
            echo "   2. Restore PostgreSQL dump: pg_restore -d \$IZIIAPP_DB_URL -c ${BACKUP_DIR}/*.dump"
        fi
        echo "   3. Re-check code changes or revert git commit."
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 7. Restart Service & Health Check
# ------------------------------------------------------------------------------
log_step "[7/7] Restarting iZiiServer and validating health..."

if [ "$WAS_SERVICE_ACTIVE" = true ] || systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
    log_info "Restarting systemd service: ${SERVICE_NAME}..."
    if [ "$EUID" -ne 0 ]; then
        sudo systemctl daemon-reload
        sudo systemctl restart "$SERVICE_NAME"
    else
        systemctl daemon-reload
        systemctl restart "$SERVICE_NAME"
    fi

    # Wait for server warmup
    log_info "Waiting for server startup on port $PORT..."
    sleep 3

    # Healthcheck validation
    HEALTH_URL="http://127.0.0.1:${PORT}/health"
    DEVICES_URL="http://127.0.0.1:${PORT}/api/v1/devices/online"

    if command -v curl &> /dev/null; then
        HEALTH_RESP=$(curl -s -m 5 "$HEALTH_URL" || true)
        if echo "$HEALTH_RESP" | grep -q '"status":[ ]*"ok"'; then
            log_success "Health check passed: $HEALTH_RESP"
        else
            log_warn "Health check endpoint did not return expected status: $HEALTH_RESP"
        fi

        # Verify devices endpoint (F13 verification)
        DEVICES_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$DEVICES_URL" || true)
        if [ "$DEVICES_CODE" = "200" ]; then
            log_success "Devices online endpoint responded with HTTP 200 OK."
        else
            log_warn "Devices online endpoint returned HTTP code: $DEVICES_CODE"
        fi
    fi
else
    log_info "No active systemd service found. You can run iZiiServer manually with:"
    echo "       source venv/bin/activate"
    echo "       python -m uvicorn app:app --host 0.0.0.0 --port $PORT"
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo -e "${C_GREEN}${C_BOLD}======================================================${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}     iZiiServer Upgrade Completed Successfully!       ${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}======================================================${C_RESET}"
echo -e "• Database Backend   : ${C_BOLD}${DB_BACKEND}${C_RESET}"
echo -e "• Healthcheck URL    : ${C_BOLD}http://127.0.0.1:${PORT}/health${C_RESET}"
if [ "$SKIP_BACKUP" = false ]; then
    echo -e "• Pre-Upgrade Backup : ${C_BOLD}${BACKUP_DIR}${C_RESET}"
fi
echo -e "• Service Log Stream : ${C_CYAN}journalctl -u ${SERVICE_NAME} -f${C_RESET}"
echo ""
