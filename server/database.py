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

def get_stable_data_dir():
    if getattr(sys, 'frozen', False):
        return os.path.join(os.path.dirname(sys.executable), "data")
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

DB_PATH = os.path.join(get_stable_data_dir(), "iziiapp.db")


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
