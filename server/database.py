# server/database.py
"""
Centralized SQLite connection factory with production-grade PRAGMA configuration.
All database connections in the application MUST go through this module.

Architecture Plan Reference: Section 5 — SQLite Production Configuration
"""
import sqlite3
import os
import sys
from contextlib import contextmanager

def get_legacy_data_dir():
    """Chỗ CŨ: ngay cạnh file thực thi. Chỉ dùng để di cư dữ liệu sang chỗ mới."""
    if getattr(sys, 'frozen', False):
        return os.path.join(os.path.dirname(sys.executable), "data")
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")


def get_stable_data_dir():
    """
    Thư mục dữ liệu ỔN ĐỊNH — nằm NGOÀI thư mục cài đặt.

    VÌ SAO ĐỔI: bản cũ trả về `dirname(sys.executable)/data`, tức là database
    nằm bên trong thư mục release. Mỗi bản build mới là một thư mục mới, nên
    log ngày 13/08 ghi nhận bốn đường dẫn database khác nhau:

        …\\izii_app\\server\\webhook_server\\data\\iziiapp.db
        …\\build\\windows\\x64\\runner\\Release\\…\\data\\iziiapp.db
        …\\Downloads\\iZiiApp Release V1.0.20\\…\\data\\iziiapp.db
        C:\\Project\\iZiiApp Release V1.0.30\\…\\data\\iziiapp.db

    Mỗi lần nâng cấp là toàn bộ thiết bị đã đăng ký, vé mời, hàng đợi tin nhắn
    và phiên làm việc biến mất. Triệu chứng quan sát được: `heartbeat` trả 404
    "Device not found", và `Queried online devices → 0` lặp lại 20.647 lần —
    server không thấy thiết bị nào dù máy vẫn đang chạy.

    Đặt `IZIIAPP_DATA_DIR` để ghi đè (ví dụ muốn để dữ liệu trên ổ khác).
    """
    explicit = os.environ.get("IZIIAPP_DATA_DIR", "").strip()
    if explicit:
        return explicit

    if sys.platform.startswith("win"):
        base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
        return os.path.join(base, "iZiiApp", "server")
    if sys.platform == "darwin":
        return os.path.expanduser("~/Library/Application Support/iZiiApp/server")
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(xdg, "iziiapp", "server")


def _migrate_legacy_data_once(target_dir: str) -> None:
    """
    Chuyển database cũ (nằm cạnh .exe) sang thư mục ổn định, một lần duy nhất.

    Chỉ chạy khi chỗ mới CHƯA có database — không bao giờ ghi đè dữ liệu đang
    dùng. Copy chứ không move, để bản cũ vẫn còn nếu cần đối chiếu.
    """
    import shutil

    target_db = os.path.join(target_dir, "iziiapp.db")
    if os.path.exists(target_db):
        return

    legacy_db = os.path.join(get_legacy_data_dir(), "iziiapp.db")
    if not os.path.exists(legacy_db):
        return

    try:
        os.makedirs(target_dir, exist_ok=True)
        # Chép cả -wal và -shm, nếu không sẽ mất các giao dịch chưa checkpoint.
        for suffix in ("", "-wal", "-shm"):
            src = legacy_db + suffix
            if os.path.exists(src):
                shutil.copy2(src, target_db + suffix)
        print(f"📦 [DB] Đã chuyển dữ liệu cũ từ {legacy_db} sang {target_db}")
    except Exception as e:
        print(f"⚠️  [DB] Không chuyển được dữ liệu cũ: {e}")


_DATA_DIR = get_stable_data_dir()
try:
    os.makedirs(_DATA_DIR, exist_ok=True)
    _migrate_legacy_data_once(_DATA_DIR)
except Exception as _e:
    print(f"⚠️  [DB] Không tạo được thư mục dữ liệu {_DATA_DIR}: {_e}")

DB_PATH = os.environ.get("IZIIAPP_SERVER_DB_PATH", os.path.join(_DATA_DIR, "iziiapp.db"))


def get_db_connection():
    """
    Create a new SQLite connection with all production PRAGMAs applied.
    
    This function ensures every connection has:
    - WAL mode: Write-Ahead Logging for concurrent read/write
    - NORMAL sync: Balance between speed and data safety
    - busy_timeout=5000: Wait up to 5s for write lock release (CRITICAL for multi-worker Uvicorn)
    - cache_size=64MB: Boost read performance
    - temp_store=MEMORY: Keep temp tables in RAM
    - mmap_size=256MB: Memory-mapped I/O for large file access
    """
    # Ensure data directory exists
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(DB_PATH, timeout=10.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    
    # Production PRAGMAs (Architecture Plan — Section 5)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA busy_timeout=5000;")        # CRITICAL for multi-worker Uvicorn
    conn.execute("PRAGMA cache_size=-64000;")         # 64MB Cache
    conn.execute("PRAGMA temp_store=MEMORY;")
    conn.execute("PRAGMA mmap_size=268435456;")       # 256MB MMAP
    
    return conn


def sql(query: str) -> str:
    """
    Đổi placeholder `?` (kiểu SQLite) sang `%s` (kiểu psycopg) khi đang chạy
    PostgreSQL.

    Nhờ vậy những truy vấn đơn giản dùng chung cho cả hai backend (webhook,
    admin reset) chỉ cần viết MỘT lần với cú pháp `?`. Các truy vấn phức tạp
    thì vẫn nên viết riêng trong sqlite_repo.py / postgres_repo.py cho rõ ràng.

    Chỉ thay thế thô — không dùng cho query có chứa dấu `?` bên trong chuỗi
    literal.
    """
    from server_config import CONFIG
    if CONFIG.db_backend == "postgres":
        return query.replace("?", "%s")
    return query


@contextmanager
def db_session():
    """
    Context manager for database sessions with automatic commit/rollback.
    
    Usage:
        with db_session() as conn:
            cursor = conn.cursor()
            cursor.execute("INSERT INTO ...")
            # Auto-commit on success, auto-rollback on exception
    """
    conn = get_db_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
