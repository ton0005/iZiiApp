# server/repository/__init__.py
"""
Repository Pattern — Data Access Layer Abstraction.

Architecture Plan Reference: Section 6 — Data Access Layer

This package provides interface-based repository abstractions to:
1. Decouple business logic from SQLite-specific SQL
2. Enable future migration from SQLite → PostgreSQL without touching endpoint code
3. Support unit testing with mock repositories
"""
from repository.interface import (
    ISyncRepository,
    IDeviceRepository,
    IMessageRepository,
    INotificationRepository,
)
from repository.sqlite_repo import (
    SQLiteSyncRepository,
    SQLiteDeviceRepository,
    SQLiteMessageRepository,
    SQLiteNotificationRepository,
)

__all__ = [
    "ISyncRepository",
    "IDeviceRepository",
    "IMessageRepository",
    "INotificationRepository",
    "SQLiteSyncRepository",
    "SQLiteDeviceRepository",
    "SQLiteMessageRepository",
    "SQLiteNotificationRepository",
]
