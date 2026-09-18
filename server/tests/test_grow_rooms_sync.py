import os
import sys
import unittest
from starlette.testclient import TestClient

server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if server_dir not in sys.path:
    sys.path.insert(0, server_dir)

from app import app
from dependencies import open_connection, make_sync_repo

class TestGrowRoomsSync(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self._ctx = open_connection()
        self.conn = self._ctx.__enter__()
        self.repo = make_sync_repo(self.conn)

    def tearDown(self):
        self._ctx.__exit__(None, None, None)

    def test_room_34_seeded_in_postgres(self):
        record = self.repo.get_record("grow_rooms", "room_34")
        self.assertIsNotNone(record, "room_34 must exist in grow_rooms table")
        data = record.get("data", {})
        self.assertEqual(data.get("id"), "room_34")
        self.assertEqual(data.get("name"), "Room 34")

    def test_sync_record_endpoint_for_room_34(self):
        response = self.client.get("/sync/record/grow_rooms/room_34")
        self.assertEqual(response.status_code, 200)
        json_data = response.json()
        self.assertIn("data", json_data)
        self.assertEqual(json_data["data"]["id"], "room_34")
        self.assertEqual(json_data["data"]["name"], "Room 34")

    def test_all_66_rooms_seeded(self):
        standard_rooms = [f"room_{i}" for i in range(1, 33)] + [f"room_{i}" for i in range(33, 67)]
        for r_id in standard_rooms:
            rec = self.repo.get_record("grow_rooms", r_id)
            self.assertIsNotNone(rec, f"{r_id} must exist in grow_rooms")
            self.assertTrue(rec["data"]["name"].startswith("Room "), f"Name for {r_id} must start with 'Room '")

if __name__ == "__main__":
    unittest.main()
