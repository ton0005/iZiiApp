# server/tests/test_phase5_workforce_api.py
"""
Test Suite Phase 5: Workforce, Timesheet Calculation & Attendance Events API.
Verifies timesheet calculation logic, break policies, and daily timesheet endpoints.
"""
import unittest
import uuid
from datetime import datetime, timezone
from starlette.testclient import TestClient

import app as app_module
from dependencies import open_connection


class TestPhase5WorkforceApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app_module.app)

    def test_calculate_and_retrieve_timesheets(self):
        """
        P5.2: Kiểm tra endpoint POST /api/v1/workforce/timesheets/calculate
        và GET /api/v1/workforce/timesheets/daily.
        """
        emp_id = f"emp_ts_{uuid.uuid4().hex[:6]}"
        test_date = "2026-09-17"

        # 1. Tạo các attendance events mẫu cho nhân viên
        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO mushroom_attendance_events (id, employee_id, event_type, timestamp, source, location)
                VALUES
                    (%s, %s, 'CHECK_IN',    '2026-09-17T08:00:00Z', 'device', 'Shed 1'),
                    (%s, %s, 'BREAK_START', '2026-09-17T12:00:00Z', 'device', 'Canteen'),
                    (%s, %s, 'BREAK_END',   '2026-09-17T12:35:00Z', 'device', 'Canteen'),
                    (%s, %s, 'CHECK_OUT',   '2026-09-17T16:35:00Z', 'device', 'Shed 1')
                """,
                (
                    f"ev_{emp_id}_1", emp_id,
                    f"ev_{emp_id}_2", emp_id,
                    f"ev_{emp_id}_3", emp_id,
                    f"ev_{emp_id}_4", emp_id,
                ),
            )
            conn.commit()

        # 2. Gọi API tính toán chấm công
        calc_res = self.client.post("/api/v1/workforce/timesheets/calculate", json={"plan_date": test_date})
        self.assertEqual(calc_res.status_code, 200)
        calc_json = calc_res.json()
        self.assertEqual(calc_json["status"], "success")
        self.assertEqual(calc_json["plan_date"], test_date)
        self.assertGreaterEqual(calc_json["processed_count"], 1)

        # 3. Tra cứu bảng chấm công theo ngày và nhân viên
        get_res = self.client.get(f"/api/v1/workforce/timesheets/daily?plan_date={test_date}&employee_id={emp_id}")
        self.assertEqual(get_res.status_code, 200)
        ts_json = get_res.json()
        self.assertGreaterEqual(ts_json["count"], 1)
        record = ts_json["timesheets"][0]
        self.assertEqual(record["employee_id"], emp_id)
        self.assertEqual(record["plan_date"], test_date)
        # Gross = 8:00 đến 16:35 = 8h 35m = 515m
        # Break = 35m (Chuẩn 30m + ân hạn 5m = 35m, không tính extra break)
        # Paid = 515 - 35 = 480m (8 giờ chuẩn)
        self.assertEqual(record["total_break_taken_minutes"], 35)
        self.assertEqual(record["gross_worked_minutes"], 515)
        self.assertEqual(record["paid_minutes"], 480)

    def test_attendance_events_and_break_policies_endpoints(self):
        """
        P5.3: Kiểm tra tra cứu attendance events và break policies.
        """
        # Attendance events
        res_ev = self.client.get("/api/v1/workforce/attendance/events?date=2026-09-17")
        self.assertEqual(res_ev.status_code, 200)
        self.assertIn("events", res_ev.json())

        # Break policies
        res_bp = self.client.get("/api/v1/workforce/break-policies")
        self.assertEqual(res_bp.status_code, 200)
        self.assertIn("policies", res_bp.json())


if __name__ == "__main__":
    unittest.main()
