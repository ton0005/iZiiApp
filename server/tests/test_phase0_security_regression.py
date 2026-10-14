# server/tests/test_phase0_security_regression.py
"""
Test Suite hồi quy cho Phase 0:
- F12: Đảm bảo get_online() không bị sập TypeError naive/aware datetime
- F11: Kiểm tra phân tách WebSocket token và Admin token (F10/F11)
- P0.1c: Kiểm tra cơ chế get_record() tái hiện trạng thái dirty-field
- P0.3: Kiểm tra timestamp UTC của các endpoints
"""
import sys
import os
import unittest
import sqlite3
import json
import hmac
from datetime import datetime, timezone, timedelta

# Thêm thư mục server vào sys.path để import modules
server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if server_dir not in sys.path:
    sys.path.insert(0, server_dir)

from repository.sqlite_repo import SQLiteDeviceRepository, SQLiteSyncRepository
from server_config import ServerConfig, CONFIG
import app as app_module


def setup_in_memory_db():
    conn = sqlite3.connect(":memory:", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS devices (
            device_id TEXT PRIMARY KEY,
            user_id TEXT,
            public_key TEXT,
            signing_public_key TEXT,
            device_name TEXT,
            platform TEXT,
            push_token TEXT,
            fingerprint TEXT,
            registered_at TEXT,
            last_seen_at TEXT
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sync_mutations (
            id TEXT PRIMARY KEY,
            client_id TEXT,
            "table" TEXT,
            operation TEXT,
            data TEXT,
            server_received_at TEXT,
            origin_server_id TEXT,
            seq INTEGER,
            actor_user_id TEXT,
            actor_device_id TEXT,
            schema_version INTEGER DEFAULT 1
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sync_sequence (
            name TEXT PRIMARY KEY,
            current INTEGER NOT NULL DEFAULT 0
        )
    """)
    cursor.execute("INSERT OR IGNORE INTO sync_sequence (name, current) VALUES ('mutation', 0)")
    conn.commit()
    return conn


class TestPhase0SecurityRegression(unittest.TestCase):
    """Test Suite hồi quy cho Phase 0 & F13."""

    def test_f12_get_online_handles_all_datetime_formats(self):
        """F12 Fix: Test get_online with naive, ISO+Z, ISO+offset, and empty last_seen_at."""
        conn = setup_in_memory_db()
        repo = SQLiteDeviceRepository(conn)
        cursor = conn.cursor()

        now_utc = datetime.now(timezone.utc)
        recent_aware_iso = (now_utc - timedelta(seconds=10)).isoformat()
        recent_aware_z = recent_aware_iso.replace("+00:00", "Z")
        recent_naive = (now_utc - timedelta(seconds=20)).strftime("%Y-%m-%dT%H:%M:%S.%f")

        # Insert 4 test devices
        cursor.execute("""
            INSERT INTO devices (device_id, user_id, device_name, platform, last_seen_at)
            VALUES 
            ('dev-1', 'user-1', 'Device Aware ISO', 'iOS', ?),
            ('dev-2', 'user-1', 'Device Aware Z', 'Android', ?),
            ('dev-3', 'user-2', 'Device Naive Local', 'Windows', ?),
            ('dev-4', 'user-3', 'Device Null Seen', 'Linux', NULL)
        """, (recent_aware_iso, recent_aware_z, recent_naive))
        conn.commit()

        # Must NOT raise TypeError: can't subtract offset-naive and offset-aware datetimes
        online_devices = repo.get_online()
        self.assertEqual(len(online_devices), 3)
        device_ids = {d["device_id"] for d in online_devices}
        self.assertIn("dev-1", device_ids)
        self.assertIn("dev-2", device_ids)
        self.assertIn("dev-3", device_ids)
        self.assertNotIn("dev-4", device_ids)

    def test_f13_postgres_get_online_handles_datetime_objects(self):
        """F13 Fix: Postgres TIMESTAMPTZ returns datetime.datetime objects, NOT strings."""
        from repository.postgres_repo import PostgresDeviceRepository

        # Mock connection returning psycopg dict_row with actual datetime objects
        now_utc = datetime.now(timezone.utc)
        recent_dt = now_utc - timedelta(seconds=15)
        old_dt = now_utc - timedelta(minutes=10)

        mock_rows = [
            {
                "device_id": "pg-dev-1",
                "user_id": "pg-user-1",
                "device_name": "Postgres Online Device",
                "platform": "Linux",
                "public_key": "pk1",
                "signing_public_key": "spk1",
                "registered_at": recent_dt,
                "fingerprint": "fp1",
                "last_seen_at": recent_dt,  # datetime object!
            },
            {
                "device_id": "pg-dev-2",
                "user_id": "pg-user-1",
                "device_name": "Postgres Offline Device",
                "platform": "Windows",
                "public_key": "pk2",
                "signing_public_key": "spk2",
                "registered_at": old_dt,
                "fingerprint": "fp2",
                "last_seen_at": old_dt,
            }
        ]

        class MockCursor:
            def fetchall(self):
                return mock_rows

        class MockConn:
            def execute(self, query, params=None):
                return MockCursor()

        repo = PostgresDeviceRepository(MockConn())
        online_devices = repo.get_online()

        self.assertEqual(len(online_devices), 1)
        self.assertEqual(online_devices[0]["device_id"], "pg-dev-1")
        self.assertEqual(online_devices[0]["status"], "online")
        # Ensure returned timestamps are serialized strings, not raw datetimes
        self.assertIsInstance(online_devices[0]["last_seen_at"], str)
        self.assertIsInstance(online_devices[0]["registered_at"], str)

    def test_f11_websocket_auth_rejects_admin_secret(self):
        """F11 Test: WebSocket must accept WS_SECRET or SERVER_SECRET, but strictly reject ADMIN_SECRET."""
        orig_ws = CONFIG.ws_secret
        orig_server = CONFIG.server_secret
        orig_admin = CONFIG.admin_secret

        try:
            CONFIG.ws_secret = "ws-secret-123"
            CONFIG.server_secret = "server-secret-456"
            CONFIG.admin_secret = "admin-secret-789"

            # Valid secrets
            self.assertTrue(app_module._ws_token_is_valid("ws-secret-123"))
            self.assertTrue(app_module._ws_token_is_valid("server-secret-456"))

            # Admin secret MUST be rejected
            self.assertFalse(app_module._ws_token_is_valid("admin-secret-789"))

            # Random or empty secret must be rejected
            self.assertFalse(app_module._ws_token_is_valid("wrong-token"))
            self.assertFalse(app_module._ws_token_is_valid(None))
            self.assertFalse(app_module._ws_token_is_valid(""))
        finally:
            CONFIG.ws_secret = orig_ws
            CONFIG.server_secret = orig_server
            CONFIG.admin_secret = orig_admin

    def test_p0_1c_get_record_dirty_field_replay(self):
        """P0.1c Test: get_record merges dirty fields correctly and respects nulls and tombstones."""
        conn = setup_in_memory_db()
        sync_repo = SQLiteSyncRepository(conn)
        record_id = "job-abc-123"
        table_name = "jobs"
        now_str = datetime.now(timezone.utc).isoformat()

        # 1. Insert mutation: name="Harvest Room 1", status="in_progress", assignee_id="worker-9"
        sync_repo.push_mutations([
            {
                "id": "mut-1",
                "table": table_name,
                "operation": "insert",
                "data": {
                    "id": record_id,
                    "name": "Harvest Room 1",
                    "status": "in_progress",
                    "assignee_id": "worker-9",
                    "room_id": "room-1",
                },
            }
        ], now_str)

        # Verify initial get_record
        rec = sync_repo.get_record(table_name, record_id)
        self.assertIsNotNone(rec)
        self.assertEqual(rec["data"]["name"], "Harvest Room 1")
        self.assertEqual(rec["data"]["status"], "in_progress")
        self.assertEqual(rec["data"]["assignee_id"], "worker-9")

        # 2. Update mutation (dirty-field): status="completed", assignee_id=None (explicit null)
        # Notice: 'name' and 'room_id' are absent in data -> must be preserved!
        sync_repo.push_mutations([
            {
                "id": "mut-2",
                "table": table_name,
                "operation": "update",
                "data": {
                    "id": record_id,
                    "status": "completed",
                    "assignee_id": None,
                },
            }
        ], now_str)

        # Verify dirty-field merge
        rec2 = sync_repo.get_record(table_name, record_id)
        self.assertIsNotNone(rec2)
        self.assertEqual(rec2["data"]["name"], "Harvest Room 1")        # Preserved!
        self.assertEqual(rec2["data"]["room_id"], "room-1")              # Preserved!
        self.assertEqual(rec2["data"]["status"], "completed")           # Updated!
        self.assertIsNone(rec2["data"]["assignee_id"])                  # Explicitly nulled!
        self.assertEqual(rec2["last_seq"], 2)

        # 3. Non-existent record returns None
        self.assertIsNone(sync_repo.get_record(table_name, "non-existent-id"))

        # 4. Delete mutation marks record as deleted
        sync_repo.push_mutations([
            {
                "id": "mut-3",
                "table": table_name,
                "operation": "delete",
                "data": {"id": record_id},
            }
        ], now_str)
        self.assertIsNone(sync_repo.get_record(table_name, record_id))

    def test_sync_record_router_endpoint(self):
        """Test HTTP GET /sync/record/{table}/{record_id} via FastAPI TestClient."""
        from starlette.testclient import TestClient
        from dependencies import get_sync_repo

        conn = setup_in_memory_db()
        sync_repo = SQLiteSyncRepository(conn)
        now_str = datetime.now(timezone.utc).isoformat()

        sync_repo.push_mutations([
            {
                "id": "mut-http-1",
                "table": "grow_rooms",
                "operation": "insert",
                "data": {
                    "id": "room-101",
                    "name": "Room 101",
                    "status": "active",
                    "current_stage": "spawn",
                }
            }
        ], now_str)

        # Override get_sync_repo dependency
        app_module.app.dependency_overrides[get_sync_repo] = lambda: sync_repo

        client = TestClient(app_module.app)
        try:
            # 1. Existing record
            resp = client.get("/sync/record/grow_rooms/room-101")
            self.assertEqual(resp.status_code, 200)
            body = resp.json()
            self.assertEqual(body["table"], "grow_rooms")
            self.assertEqual(body["id"], "room-101")
            self.assertEqual(body["data"]["name"], "Room 101")
            self.assertEqual(body["data"]["current_stage"], "spawn")

            # 2. Non-existent record
            resp_404 = client.get("/sync/record/grow_rooms/room-999")
            self.assertEqual(resp_404.status_code, 404)
            self.assertIn("not found", resp_404.json()["detail"].lower())
        finally:
            app_module.app.dependency_overrides.clear()


if __name__ == "__main__":
    unittest.main()

