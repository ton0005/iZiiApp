# server/tests/test_p0_10_security_e2e.py
"""
P0.10: End-to-end Security Regression Test Suite.

Requirement DoD:
- Đổi bất kỳ secret nào -> CI chạy được trọn vẹn kịch bản:
  1. Đăng ký thiết bị (POST /api/v1/devices/register)
  2. Kết nối WebSocket /chat (query param token)
  3. Đẩy mutation (POST /sync/push)
  4. Kéo mutation (GET /sync/pull)
- Kiểm tra chặt chẽ:
  - WebSocket chấp nhận WS_SECRET hoặc SERVER_SECRET
  - WebSocket từ chối ADMIN_SECRET với mã 1008 (chống hồi quy F10/F11)
  - Thay đổi secret tức thời trong runtime không gây lỗi hệ thống
"""
import os
import sys
import json
import sqlite3
import unittest

server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if server_dir not in sys.path:
    sys.path.insert(0, server_dir)

from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect
from server_config import CONFIG
from repository.sqlite_repo import SQLiteDeviceRepository, SQLiteSyncRepository
from dependencies import get_device_repo, get_sync_repo
import app as app_module


def create_in_memory_security_db():
    conn = sqlite3.connect(":memory:", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("""
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
    )""")

    cur.execute("""
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
    )""")

    cur.execute("""
    CREATE TABLE IF NOT EXISTS webhook_subscriptions (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        event_filter TEXT,
        secret_token TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
    )""")
    cur.execute("""
    CREATE TABLE IF NOT EXISTS sync_sequence (
        name TEXT PRIMARY KEY,
        current INTEGER NOT NULL DEFAULT 0
    )""")
    cur.execute("INSERT OR IGNORE INTO sync_sequence (name, current) VALUES ('mutation', 0)")
    conn.commit()
    return conn


class TestP010SecurityLifecycleE2E(unittest.TestCase):

    def setUp(self):
        self.conn = create_in_memory_security_db()
        self.device_repo = SQLiteDeviceRepository(self.conn)
        self.sync_repo = SQLiteSyncRepository(self.conn)

        # Override dependencies
        app_module.app.dependency_overrides[get_device_repo] = lambda: self.device_repo
        app_module.app.dependency_overrides[get_sync_repo] = lambda: self.sync_repo

        self.client = TestClient(app_module.app)

        # Backup original configs
        self.orig_admin = CONFIG.admin_secret
        self.orig_ws = CONFIG.ws_secret
        self.orig_server = CONFIG.server_secret

    def tearDown(self):
        app_module.app.dependency_overrides.clear()
        self.conn.close()
        CONFIG.admin_secret = self.orig_admin
        CONFIG.ws_secret = self.orig_ws
        CONFIG.server_secret = self.orig_server

    def run_full_lifecycle(self, ws_secret: str, server_secret: str, cycle_tag: str):
        """Runs the full lifecycle: register -> WS connect -> push -> pull."""
        dev_id = f"dev-e2e-{cycle_tag}"
        user_id = f"user-e2e-{cycle_tag}"

        # 1. Register device
        reg_payload = {
            "device_id": dev_id,
            "user_id": user_id,
            "device_name": f"Device {cycle_tag}",
            "platform": "windows",
            "public_key": f"pubkey-{cycle_tag}-dummy",
        }
        res_reg = self.client.post("/api/v1/devices/register", json=reg_payload)
        self.assertEqual(res_reg.status_code, 200, f"Register failed: {res_reg.text}")
        self.assertEqual(res_reg.json()["status"], "success")

        # 2. WebSocket /chat Connect with ws_secret
        with self.client.websocket_connect(f"/chat?token={ws_secret}") as ws:
            ws.send_text(json.dumps({"type": "ping", "tag": cycle_tag}))

        # 3. Push mutation with server_secret
        mut_id = f"mut-{cycle_tag}-001"
        push_payload = {
            "device_id": dev_id,
            "mutations": [
                {
                    "id": mut_id,
                    "table": "mushroom_jobs",
                    "operation": "insert",
                    "data": {
                        "id": f"job-{cycle_tag}",
                        "name": f"Job {cycle_tag}",
                        "status": "in_progress",
                    },
                }
            ],
        }
        headers = {"X-Server-Secret": server_secret} if server_secret else {}
        res_push = self.client.post("/sync/push", json=push_payload, headers=headers)
        self.assertEqual(res_push.status_code, 200, f"Push failed: {res_push.text}")
        push_resp = res_push.json()
        self.assertEqual(push_resp["status"], "success")
        self.assertEqual(push_resp["accepted_count"], 1)
        self.assertEqual(push_resp["rejected_count"], 0)

        # 4. Pull mutation
        res_pull = self.client.get("/sync/pull?after_seq=0", headers=headers)
        self.assertEqual(res_pull.status_code, 200, f"Pull failed: {res_pull.text}")
        pull_resp = res_pull.json()
        updates = pull_resp.get("updates", [])
        self.assertTrue(any(m["id"] == mut_id for m in updates))

    def test_security_lifecycle_and_secret_rotation(self):
        """Test complete lifecycle and verify that rotation immediately updates authentication."""
        # Initial secrets
        CONFIG.admin_secret = "initial_admin_secret_987"
        CONFIG.ws_secret = "initial_ws_secret_123"
        CONFIG.server_secret = "initial_server_secret_456"

        # Phase A: Initial secret cycle
        self.run_full_lifecycle(
            ws_secret="initial_ws_secret_123",
            server_secret="initial_server_secret_456",
            cycle_tag="cycle_initial",
        )

        # Verify WebSocket strictly rejects admin secret (F10/F11 protection)
        with self.assertRaises(WebSocketDisconnect) as cm:
            with self.client.websocket_connect("/chat?token=initial_admin_secret_987"):
                pass
        self.assertEqual(cm.exception.code, 1008)

        # Verify WebSocket rejects wrong token
        with self.assertRaises(WebSocketDisconnect) as cm:
            with self.client.websocket_connect("/chat?token=wrong_token"):
                pass
        self.assertEqual(cm.exception.code, 1008)

        # Phase B: Rotate secrets in runtime
        CONFIG.admin_secret = "rotated_admin_secret_999"
        CONFIG.ws_secret = "rotated_ws_secret_888"
        CONFIG.server_secret = "rotated_server_secret_777"

        # Old secrets MUST now be rejected
        with self.assertRaises(WebSocketDisconnect) as cm:
            with self.client.websocket_connect("/chat?token=initial_ws_secret_123"):
                pass
        self.assertEqual(cm.exception.code, 1008)

        # New secrets MUST now succeed for all steps
        self.run_full_lifecycle(
            ws_secret="rotated_ws_secret_888",
            server_secret="rotated_server_secret_777",
            cycle_tag="cycle_rotated",
        )

        # Rotated admin secret is still rejected for WebSocket
        with self.assertRaises(WebSocketDisconnect) as cm:
            with self.client.websocket_connect("/chat?token=rotated_admin_secret_999"):
                pass
        self.assertEqual(cm.exception.code, 1008)


if __name__ == "__main__":
    unittest.main()
