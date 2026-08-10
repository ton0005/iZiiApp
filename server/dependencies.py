# server/dependencies.py
"""
FastAPI Dependency Injection configuration.

Architecture Plan Reference: Section 6 — Data Access Layer

Đây là NƠI DUY NHẤT quyết định dùng backend nào. Chuyển từ SQLite sang
PostgreSQL chỉ cần đổi IZIIAPP_DB_BACKEND trong .env — không dòng endpoint nào
phải sửa. Đó chính là lợi ích đã trả trước khi áp dụng Repository Pattern.

Usage in routers:
    @router.get("/sync/pull")
    async def sync_pull(repo: ISyncRepository = Depends(get_sync_repo)):
        page = repo.pull_mutations(after_seq=after_seq, limit=limit)
        return {"updates": page["updates"], "next_cursor": page["next_cursor"]}
"""
from fastapi import Depends

from server_config import CONFIG
from database import get_db_connection
from repository.sqlite_repo import (
    SQLiteSyncRepository,
    SQLiteDeviceRepository,
    SQLiteMessageRepository,
    SQLiteNotificationRepository,
)


def _is_postgres() -> bool:
    return CONFIG.db_backend == "postgres"


def get_db():
    """
    Dependency cấp connection cho 1 request.

    - SQLite  : mở connection mới, ĐÓNG hẳn khi request xong.
    - Postgres: MƯỢN từ pool, TRẢ VỀ POOL khi request xong (không đóng thật).

    Khác biệt này quan trọng: mở connection Postgres tốn vài chục ms do bắt tay
    TCP + xác thực, nên tuyệt đối không được mở/đóng theo từng request.
    """
    if _is_postgres():
        from db_postgres import pg_connection
        with pg_connection() as conn:
            yield conn
    else:
        conn = get_db_connection()
        try:
            yield conn
        finally:
            conn.close()


def get_sync_repo(conn=Depends(get_db)):
    """Inject repository cho Track 1 — Sync Engine."""
    if _is_postgres():
        from repository.postgres_repo import PostgresSyncRepository
        return PostgresSyncRepository(conn)
    return SQLiteSyncRepository(conn)


def get_device_repo(conn=Depends(get_db)):
    """Inject repository cho Track 2 — Device Identity."""
    if _is_postgres():
        from repository.postgres_repo import PostgresDeviceRepository
        return PostgresDeviceRepository(conn)
    return SQLiteDeviceRepository(conn)


def get_message_repo(conn=Depends(get_db)):
    """Inject repository cho Track 3 — E2EE Messaging."""
    if _is_postgres():
        from repository.postgres_repo import PostgresMessageRepository
        return PostgresMessageRepository(conn)
    return SQLiteMessageRepository(conn)


def get_notification_repo(conn=Depends(get_db)):
    """Inject repository cho Track 4+5 — Notifications."""
    if _is_postgres():
        from repository.postgres_repo import PostgresNotificationRepository
        return PostgresNotificationRepository(conn)
    return SQLiteNotificationRepository(conn)


# ── Dùng ngoài phạm vi request (vòng lặp peer-sync, event engine, admin) ─────

def open_connection():
    """
    Context manager cấp connection ngoài luồng FastAPI dependency.

        with open_connection() as conn:
            repo = make_sync_repo(conn)
    """
    if _is_postgres():
        from db_postgres import pg_connection
        return pg_connection()

    from contextlib import contextmanager

    @contextmanager
    def _sqlite_ctx():
        conn = get_db_connection()
        try:
            yield conn
        finally:
            conn.close()

    return _sqlite_ctx()


def make_sync_repo(conn):
    """Tạo ISyncRepository đúng backend từ một connection đã có sẵn."""
    if _is_postgres():
        from repository.postgres_repo import PostgresSyncRepository
        return PostgresSyncRepository(conn)
    return SQLiteSyncRepository(conn)
