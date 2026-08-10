# server/db_postgres.py
"""
Kết nối PostgreSQL — dùng khi IZIIAPP_DB_BACKEND=postgres.

VÌ SAO CẦN: SQLite chỉ cho phép MỘT writer tại một thời điểm. Ở biên (một
server một zone) điều đó hoàn toàn ổn và còn là ưu điểm — không cần cài đặt gì.
Nhưng khi có nhiều adapter doanh nghiệp ghi song song (SAP, OPC UA, Historian)
cộng với hàng chục thiết bị push, writer đơn sẽ thành nút cổ chai và bắt đầu
xuất hiện `database is locked`.

THIẾT KẾ: psycopg được import LƯỜI (lazy) bên trong hàm, không import ở đầu
module. Nhờ vậy bản cài chỉ chạy SQLite không cần cài psycopg, và bản đóng gói
PyInstaller không bắt buộc phải bundle nó.

Cài đặt khi cần:
    pip install "psycopg[binary,pool]" --break-system-packages
"""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Optional

from server_config import CONFIG

_pool: Optional[Any] = None


def _require_psycopg():
    try:
        import psycopg  # noqa: F401
        from psycopg.rows import dict_row  # noqa: F401
        from psycopg_pool import ConnectionPool  # noqa: F401
    except ImportError as e:
        raise RuntimeError(
            "IZIIAPP_DB_BACKEND=postgres nhưng chưa cài psycopg. "
            'Chạy: pip install "psycopg[binary,pool]" --break-system-packages'
        ) from e
    import psycopg
    from psycopg.rows import dict_row
    from psycopg_pool import ConnectionPool
    return psycopg, dict_row, ConnectionPool


def get_pool():
    """
    Connection pool dùng chung cho cả tiến trình. Tạo lười ở lần gọi đầu.

    Pool là bắt buộc chứ không phải tối ưu hoá: mở connection mới tới Postgres
    tốn ~vài chục ms (bắt tay TCP + xác thực), trong khi SQLite thì gần như
    miễn phí. Giữ nguyên kiểu "mở/đóng mỗi request" như SQLite sẽ khiến độ trễ
    tăng vọt.
    """
    global _pool
    if _pool is None:
        _psycopg, dict_row, ConnectionPool = _require_psycopg()
        _pool = ConnectionPool(
            conninfo=CONFIG.pg_dsn,
            min_size=CONFIG.pg_pool_min,
            max_size=CONFIG.pg_pool_max,
            kwargs={"row_factory": dict_row, "autocommit": False},
            open=True,
        )
        print(
            f"🐘 [PG] Connection pool sẵn sàng "
            f"(min={CONFIG.pg_pool_min}, max={CONFIG.pg_pool_max})"
        )
    return _pool


@contextmanager
def pg_connection():
    """
    Mượn connection từ pool, tự trả lại khi xong.

    Lưu ý khác biệt với SQLite: connection ở đây được TRẢ VỀ POOL chứ không
    đóng hẳn. Không được gọi conn.close() thủ công.
    """
    pool = get_pool()
    with pool.connection() as conn:
        yield conn


def close_pool() -> None:
    """Đóng pool khi server shutdown."""
    global _pool
    if _pool is not None:
        try:
            _pool.close()
            print("🐘 [PG] Đã đóng connection pool.")
        except Exception as e:
            print(f"⚠️  [PG] Lỗi khi đóng pool: {e}")
        _pool = None


def healthcheck() -> dict:
    try:
        with pg_connection() as conn:
            row = conn.execute("SELECT version() AS v").fetchone()
        return {"status": "ok", "version": row["v"] if row else None}
    except Exception as e:
        return {"status": "error", "detail": str(e)}
