# server/tests/test_radio_gateway.py
"""
Tích hợp bộ đàm Hytera ↔ Alone Worker (routers/radio_gateway.py, radio_events.py).

Đặc tả hành vi:
1. Chuẩn hoá payload từ nhiều kiểu gateway (DMR / TETRA) về cùng loại sự kiện.
2. SOS / Man Down / Lone Worker từ bộ đàm đã gán → bật đúng cờ báo động của job
   Alone Worker đang chạy (alarm_triggered, phòng alone_timeout, safety log).
3. Gói phát lại (Tx Cycles) gộp vào cảnh báo đang mở; gateway retry cùng
   gateway_event_id không tạo cảnh báo mới.
4. Bộ đàm CHƯA gán vẫn tạo cảnh báo (không được nuốt SOS).
5. Huỷ khẩn cấp trên máy không tự đóng cảnh báo.
6. Endpoint gateway fail-closed khi chưa cấu hình secret, 401 khi sai token.

Chạy trên SQLite in-memory dựng từ chính migration 0011 — không đụng DB thật.
"""
import json
import os
import sqlite3
import unittest
from contextlib import contextmanager
from datetime import datetime, timezone
from unittest import mock

import radio_events as re_
from repository.sqlite_repo import SQLiteSyncRepository
from server_config import CONFIG

_MIGRATION = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "migrations", "versions", "0011_radio_gateway.sql",
)


def _make_db() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.executescript("""
        CREATE TABLE sync_mutations (
            id TEXT PRIMARY KEY, client_id TEXT, "table" TEXT, operation TEXT, data TEXT,
            server_received_at TEXT, origin_server_id TEXT, seq INTEGER,
            actor_user_id TEXT, actor_device_id TEXT, schema_version INTEGER DEFAULT 1
        );
        CREATE TABLE sync_sequence (name TEXT PRIMARY KEY, current INTEGER NOT NULL DEFAULT 0);
        INSERT INTO sync_sequence (name, current) VALUES ('mutation', 0);
    """)
    with open(_MIGRATION, encoding="utf-8") as f:
        conn.executescript(f.read())
    return conn


class TestNormalizeEvent(unittest.TestCase):
    def test_event_type_aliases(self):
        cases = {
            "EMERGENCY_ALARM": re_.SOS, "sos": re_.SOS, "Emergency Call": re_.SOS,
            "Man-Down": re_.MAN_DOWN, "FALL_DETECTED": re_.MAN_DOWN,
            "LONE_WORKER_TIMEOUT": re_.LONE_WORKER, "loneWorker": re_.LONE_WORKER,
            "EMERGENCY_CANCEL": re_.EMERGENCY_CANCEL,
            "LOCATION_REPORT": re_.LOCATION, "power_on": re_.PRESENCE,
            "something_else": re_.UNKNOWN,
        }
        for raw, expected in cases.items():
            self.assertEqual(re_.normalize_event_type(raw), expected, raw)

    def test_field_aliases_and_coordinates(self):
        ev = re_.normalize_event({
            "issi": 2001, "alarmType": "MAN_DOWN", "system": "TETRA",
            "gps": {"lat": -37.6, "lon": 145.1}, "timestamp": 1760000000000,
        })
        self.assertEqual(ev["radio_id"], "2001")
        self.assertEqual(ev["event_type"], re_.MAN_DOWN)
        self.assertTrue(ev["is_alarm"])
        self.assertEqual(ev["system"], "tetra")
        self.assertEqual((ev["latitude"], ev["longitude"]), (-37.6, 145.1))
        self.assertTrue(ev["occurred_at"].startswith("2025-10-09"))

    def test_no_fix_zero_coordinates_dropped(self):
        ev = re_.normalize_event({"radio_id": "1", "event_type": "SOS", "latitude": 0, "longitude": 0})
        self.assertIsNone(ev["latitude"])
        self.assertIsNone(ev["longitude"])

    def test_missing_fields_rejected(self):
        with self.assertRaises(re_.RadioEventError):
            re_.normalize_event({"event_type": "SOS"})
        with self.assertRaises(re_.RadioEventError):
            re_.normalize_event({"radio_id": "1"})

    def test_assignee_matching(self):
        self.assertTrue(re_.assignee_matches("Nguyen Van A (EMP001)", "EMP001", None))
        self.assertTrue(re_.assignee_matches("nguyen  van a", None, "Nguyen Van A"))
        self.assertTrue(re_.assignee_matches("EMP001", "emp001", None))
        self.assertFalse(re_.assignee_matches("Tran Van B (EMP002)", "EMP001", "Nguyen Van A"))
        self.assertFalse(re_.assignee_matches(None, "EMP001", "Nguyen Van A"))


class TestIngestFlow(unittest.TestCase):
    def setUp(self):
        self._patch = mock.patch.object(CONFIG, "db_backend", "sqlite")
        self._patch.start()
        from routers import radio_gateway
        self.rg = radio_gateway
        self.conn = _make_db()
        self.repo = SQLiteSyncRepository(self.conn)
        now = datetime.now(timezone.utc).isoformat()
        self.repo.push_mutations([
            {"id": "m1", "table": "grow_rooms", "operation": "insert",
             "data": {"id": "room-52a", "name": "Room 52A", "status": "active", "current_stage": "alone_worker"}},
            {"id": "m2", "table": "mushroom_jobs", "operation": "insert",
             "data": {"id": "job-1", "room_id": "room-52a", "job_type": "alone_worker",
                      "status": "in_progress", "assignee": "Nguyen Van A (EMP001)",
                      "is_solo_job": True, "started_at": now}},
        ], now)
        self.conn.execute(
            "INSERT INTO radio_devices (radio_id, system, model, employee_id, employee_name, active) "
            "VALUES ('1001', 'dmr', 'HP682', 'EMP001', 'Nguyen Van A', 1)"
        )
        self.conn.commit()

    def tearDown(self):
        self._patch.stop()
        self.conn.close()

    def _ingest(self, raw):
        return self.rg.ingest_event(self.conn, self.repo, re_.normalize_event(raw), raw)

    def _state(self, table):
        return re_.fold_records(self.repo.get_mutations_by_table(table))

    def _mutation_count(self):
        return self.conn.execute("SELECT COUNT(*) FROM sync_mutations").fetchone()[0]

    def test_sos_from_bound_radio_triggers_alone_worker_alarm(self):
        res = self._ingest({"radio_id": "1001", "event_type": "EMERGENCY_ALARM",
                            "latitude": -37.81, "longitude": 144.96})
        self.assertEqual(res["result"], "created")
        self.assertEqual(res["alarm"]["job_id"], "job-1")
        self.assertEqual(res["pushed_tables"], ["grow_rooms", "mushroom_jobs", "mushroom_safety_checkin_logs"])

        self.assertTrue(self._state("mushroom_jobs")["job-1"]["alarm_triggered"])
        room = self._state("grow_rooms")["room-52a"]
        self.assertEqual(room["current_stage"], "alone_timeout")
        self.assertEqual(room["name"], "Room 52A")
        logs = list(self._state("mushroom_safety_checkin_logs").values())
        self.assertEqual(len(logs), 1)
        self.assertEqual(logs[0]["event_type"], re_.SOS)
        self.assertEqual(logs[0]["gps_latitude"], -37.81)

    def test_tx_cycle_repeats_are_merged(self):
        self._ingest({"radio_id": "1001", "event_type": "MAN_DOWN"})
        before = self._mutation_count()
        res = self._ingest({"radio_id": "1001", "event_type": "MAN_DOWN", "latitude": -37.8, "longitude": 144.9})
        self.assertEqual(res["result"], "repeat")
        self.assertEqual(res["alarm"]["repeat_count"], 1)
        self.assertEqual(res["alarm"]["latitude"], -37.8)
        self.assertEqual(self._mutation_count(), before)
        n = self.conn.execute("SELECT COUNT(*) FROM radio_events").fetchone()[0]
        self.assertEqual(n, 1)

    def test_gateway_retry_is_idempotent(self):
        raw = {"radio_id": "1001", "event_type": "SOS", "gateway_event_id": "evt-77"}
        first = self._ingest(raw)
        # Hết cửa sổ gộp vẫn phải nhận ra đây là cùng một sự kiện.
        self.conn.execute("UPDATE radio_events SET status = 'acknowledged'")
        second = self._ingest(raw)
        self.assertEqual(second["result"], "duplicate")
        self.assertEqual(second["alarm"]["id"], first["alarm"]["id"])

    def test_unbound_radio_still_raises_alarm(self):
        res = self._ingest({"radio_id": "9999", "event_type": "SOS", "model": "PT580H", "system": "tetra"})
        self.assertEqual(res["result"], "created")
        self.assertIsNone(res["alarm"]["job_id"])
        self.assertTrue(res["alarm"]["unbound"])
        dev = self.conn.execute("SELECT * FROM radio_devices WHERE radio_id = '9999'").fetchone()
        self.assertIsNotNone(dev, "Bộ đàm lạ phải được tự thêm để quản lý gán người")
        self.assertEqual(dev["system"], "tetra")

    def test_no_active_job_still_raises_alarm(self):
        self.repo.push_mutations([{"id": "m3", "table": "mushroom_jobs", "operation": "update",
                                   "data": {"id": "job-1", "status": "completed"}}],
                                 datetime.now(timezone.utc).isoformat())
        res = self._ingest({"radio_id": "1001", "event_type": "LONE_WORKER_TIMEOUT"})
        self.assertEqual(res["result"], "created")
        self.assertIsNone(res["alarm"]["job_id"])
        self.assertEqual(res["pushed_tables"], [])

    def test_cancel_on_radio_does_not_close_alarm(self):
        created = self._ingest({"radio_id": "1001", "event_type": "SOS"})
        self._ingest({"radio_id": "1001", "event_type": "EMERGENCY_CANCEL"})
        row = self.conn.execute("SELECT status FROM radio_events WHERE id = ?",
                                (created["alarm"]["id"],)).fetchone()
        self.assertEqual(row["status"], "cancelled_on_radio")
        self.assertTrue(self._state("mushroom_jobs")["job-1"]["alarm_triggered"])

    def test_smartone_payload_lifecycle(self):
        """Payload mẫu SmartOne (plan/Hytera/HUONG_DAN_TICH_HOP_HYTERA.md mục 3)."""
        sample = {
            "eventId": "EVT-20261010-00123", "eventType": "LONE_WORKER_ALARM",
            "radioId": "10024", "radioAlias": "HP682-Guard-01", "timestamp": 1728522000,
            "gps": {"latitude": -37.8136, "longitude": 144.9631, "altitude": 35.0, "speed": 0.0},
            "status": "ACTIVE",
        }
        created = self._ingest(sample)
        self.assertEqual(created["result"], "created")
        self.assertEqual(created["alarm"]["event_type"], re_.LONE_WORKER)
        self.assertEqual(created["alarm"]["latitude"], -37.8136)
        dev = self.conn.execute("SELECT label FROM radio_devices WHERE radio_id = '10024'").fetchone()
        self.assertEqual(dev["label"], "HP682-Guard-01")

        # Điều phối gửi lại cùng eventId → trùng.
        self.assertEqual(self._ingest(sample)["result"], "duplicate")

        # Cùng eventId nhưng status CLEARED → phải xử lý như huỷ, không phải báo động mới.
        cleared = self._ingest({**sample, "status": "CLEARED"})
        self.assertEqual(cleared["result"], "logged")
        row = self.conn.execute("SELECT status FROM radio_events WHERE id = ?",
                                (created["alarm"]["id"],)).fetchone()
        self.assertEqual(row["status"], "cancelled_on_radio")
        n = self.conn.execute("SELECT COUNT(*) FROM radio_events WHERE is_alarm = 1").fetchone()[0]
        self.assertEqual(n, 1)

        # GPS_UPDATE chỉ cập nhật vị trí.
        self.assertEqual(self._ingest({**sample, "eventId": "EVT-2", "eventType": "GPS_UPDATE"})["result"],
                         "updated")

    def test_alarm_without_gps_uses_recent_location(self):
        res = self._ingest({"radio_id": "1001", "event_type": "GPS", "lat": -37.7, "lng": 145.0})
        self.assertEqual(res["result"], "updated")
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM radio_events").fetchone()[0], 0)
        alarm = self._ingest({"radio_id": "1001", "event_type": "SOS"})["alarm"]
        self.assertEqual((alarm["latitude"], alarm["longitude"]), (-37.7, 145.0))


class TestEndpointAuth(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from starlette.testclient import TestClient
        import app as app_module
        cls.client = TestClient(app_module.app)

    def setUp(self):
        from routers import radio_gateway
        self.rg = radio_gateway
        self.conn = _make_db()

        @contextmanager
        def fake_open(*_a, **_k):
            yield self.conn

        self._patches = [
            mock.patch.object(CONFIG, "db_backend", "sqlite"),
            mock.patch.object(radio_gateway, "open_connection", fake_open),
            mock.patch.object(radio_gateway, "make_sync_repo", SQLiteSyncRepository),
        ]
        for p in self._patches:
            p.start()

    def tearDown(self):
        for p in self._patches:
            p.stop()
        self.conn.close()

    def test_fail_closed_without_secret(self):
        with mock.patch.object(CONFIG, "radio_gateway_secret", ""):
            res = self.client.post("/api/v1/radio/events", json={"radio_id": "1", "event_type": "SOS"},
                                   headers={"X-iZii-Radio-Token": ""})
        self.assertEqual(res.status_code, 503)

    def test_wrong_token_rejected(self):
        with mock.patch.object(CONFIG, "radio_gateway_secret", "radio-secret"):
            res = self.client.post("/api/v1/radio/events", json={"radio_id": "1", "event_type": "SOS"},
                                   headers={"X-iZii-Radio-Token": "nope"})
        self.assertEqual(res.status_code, 401)

    def test_bearer_token_accepted(self):
        with mock.patch.object(CONFIG, "radio_gateway_secret", "radio-secret"):
            ok = self.client.post("/api/v1/radio/events", json={"radioId": "1", "eventType": "GPS_UPDATE"},
                                  headers={"Authorization": "Bearer radio-secret"})
            bad = self.client.post("/api/v1/radio/events", json={"radioId": "1", "eventType": "GPS_UPDATE"},
                                   headers={"Authorization": "Bearer nope"})
        self.assertEqual(ok.status_code, 200, ok.text)
        self.assertEqual(bad.status_code, 401)

    def test_admin_secret_is_not_a_radio_token(self):
        with mock.patch.object(CONFIG, "radio_gateway_secret", "radio-secret"), \
             mock.patch.object(CONFIG, "admin_secret", "admin-secret"):
            res = self.client.post("/api/v1/radio/events", json={"radio_id": "1", "event_type": "SOS"},
                                   headers={"X-iZii-Radio-Token": "admin-secret"})
        self.assertEqual(res.status_code, 401)

    def test_batch_ingest_and_ack(self):
        with mock.patch.object(CONFIG, "radio_gateway_secret", "radio-secret"), \
             mock.patch.object(CONFIG, "admin_secret", "admin-secret"):
            res = self.client.post(
                "/api/v1/radio/events",
                json={"events": [{"radio_id": "1001", "event_type": "SOS"}, {"event_type": "SOS"}]},
                headers={"X-iZii-Radio-Token": "radio-secret"},
            )
            self.assertEqual(res.status_code, 200, res.text)
            body = res.json()
            self.assertEqual(body["status"], "partial_success")
            self.assertEqual(body["alarms_created"], 1)
            self.assertEqual(len(body["rejected"]), 1)

            # Xem cảnh báo cần token thiết bị hoặc admin.
            self.assertEqual(self.client.get("/api/v1/radio/alarms").status_code, 401)
            admin = {"X-iZii-Admin-Token": "admin-secret"}
            alarms = self.client.get("/api/v1/radio/alarms", headers=admin).json()["alarms"]
            self.assertEqual(len(alarms), 1)

            ack = self.client.post(f"/api/v1/radio/alarms/{alarms[0]['id']}/ack",
                                   json={"note": "Đang tới Room 52A"}, headers=admin)
            self.assertEqual(ack.status_code, 200, ack.text)
            self.assertEqual(ack.json()["alarm"]["status"], "acknowledged")
            self.assertEqual(ack.json()["alarm"]["acked_by"], "admin")
            remaining = self.client.get("/api/v1/radio/alarms", headers=admin).json()["alarms"]
            self.assertEqual(remaining, [])

    def test_device_binding_requires_admin(self):
        with mock.patch.object(CONFIG, "admin_secret", "admin-secret"):
            payload = {"employee_id": "EMP001", "employee_name": "Nguyen Van A", "model": "HP682"}
            self.assertEqual(self.client.put("/api/v1/radio/devices/1001", json=payload).status_code, 401)
            res = self.client.put("/api/v1/radio/devices/1001", json=payload,
                                  headers={"X-iZii-Admin-Token": "admin-secret"})
            self.assertEqual(res.status_code, 200, res.text)
            self.assertEqual(res.json()["device"]["employee_id"], "EMP001")
            self.assertTrue(res.json()["device"]["active"])


if __name__ == "__main__":
    unittest.main()
