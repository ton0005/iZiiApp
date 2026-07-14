# server/dependencies.py
"""
FastAPI Dependency Injection configuration.

Architecture Plan Reference: Section 6 — Data Access Layer

This module provides FastAPI dependency functions that inject
repository instances into endpoint handlers. To switch from SQLite
to PostgreSQL, only this file needs to change — endpoint code stays the same.

Usage in routers:
    @router.get("/sync/pull")
    async def sync_pull(repo: ISyncRepository = Depends(get_sync_repo)):
        return repo.pull_mutations(since=since)
"""
from fastapi import Depends
from database import get_db_connection
from repository.sqlite_repo import (
    SQLiteSyncRepository,
    SQLiteDeviceRepository,
    SQLiteMessageRepository,
    SQLiteNotificationRepository,
)


def get_db():
    """
    FastAPI dependency that provides a database connection.
    Connection is automatically closed after the request completes.
    """
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()


def get_sync_repo(conn=Depends(get_db)):
    """Inject SQLiteSyncRepository for Track 1 — Sync Engine."""
    return SQLiteSyncRepository(conn)


def get_device_repo(conn=Depends(get_db)):
    """Inject SQLiteDeviceRepository for Track 2 — Device Identity."""
    return SQLiteDeviceRepository(conn)


def get_message_repo(conn=Depends(get_db)):
    """Inject SQLiteMessageRepository for Track 3 — E2EE Messaging."""
    return SQLiteMessageRepository(conn)


def get_notification_repo(conn=Depends(get_db)):
    """Inject SQLiteNotificationRepository for Track 4+5 — Notifications."""
    return SQLiteNotificationRepository(conn)
