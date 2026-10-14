# server/tests/test_manager_batch_attendance.py
"""
Test Suite: Manager Batch Team Attendance Priority for Alone Worker (Airing).
Verifies:
1. get_active_session_for_person finds active session from mushroom_daily_timesheets (Manager batch).
2. get_active_session_for_person finds active session from mushroom_attendance_events.
3. Employee ID extraction handles 'Name (ID)', 'ID', and 'Name'.
4. Push sync validation accepts Alone Worker job when assignee is checked in via Manager Batch Attendance.
5. Push sync validation accepts Alone Worker job when attendance CHECK_IN event is present in the same push batch (in-flight).
6. Push sync validation rejects Alone Worker job when assignee is completely unknown/not checked in.
"""
import unittest
import uuid
from datetime import datetime, timezone, timedelta

from dependencies import open_connection, make_sync_repo
from routers.sessions import get_active_session_for_person
from routers.sync import _filter_valid_mutations, MutationModel


class TestManagerBatchAttendance(unittest.TestCase):
    def setUp(self):
        self.emp_id = f"emp_{uuid.uuid4().hex[:6]}"
        self.emp_name = f"Test Worker ({self.emp_id})"

    def tearDown(self):
        with open_connection() as conn:
            conn.execute("DELETE FROM mushroom_daily_timesheets WHERE employee_id = %s", (self.emp_id,))
            conn.execute("DELETE FROM mushroom_attendance_events WHERE employee_id = %s", (self.emp_id,))
            conn.commit()

    def test_get_active_session_from_daily_timesheet(self):
        """Ưu tiên 1A: Tìm thấy ca làm việc từ mushroom_daily_timesheets do Manager chấm công."""
        now = datetime.now(timezone.utc)
        check_in_str = (now - timedelta(hours=2)).isoformat()
        date_str = now.strftime("%Y-%m-%d")

        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO mushroom_daily_timesheets (
                    id, employee_id, plan_date, check_in_time, check_out_time,
                    gross_worked_minutes, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, NULL, 120, %s, %s)
                """,
                (f"ts_{self.emp_id}", self.emp_id, date_str, check_in_str, check_in_str, check_in_str),
            )
            conn.commit()

            # 1. Tra cứu bằng định dạng 'Tên (Mã)'
            session = get_active_session_for_person(conn, self.emp_name)
            self.assertIsNotNone(session, "Phải tìm thấy active session từ daily_timesheets")
            self.assertEqual(session["user_name"], self.emp_name)
            self.assertEqual(session["device_id"], "manager_batch_terminal")

            # 2. Tra cứu bằng mã nhân viên thuần
            session_by_id = get_active_session_for_person(conn, self.emp_id)
            self.assertIsNotNone(session_by_id)

    def test_get_active_session_from_attendance_events(self):
        """Ưu tiên 1B: Tìm thấy ca làm việc từ mushroom_attendance_events (CHECK_IN gần nhất)."""
        now = datetime.now(timezone.utc)
        event_time_str = (now - timedelta(minutes=45)).isoformat()

        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO mushroom_attendance_events (
                    id, employee_id, event_type, timestamp, source, created_at
                ) VALUES (%s, %s, 'CHECK_IN', %s, 'MANAGER_BATCH', %s)
                """,
                (f"evt_{self.emp_id}", self.emp_id, event_time_str, event_time_str),
            )
            conn.commit()

            session = get_active_session_for_person(conn, self.emp_id)
            self.assertIsNotNone(session, "Phải tìm thấy active session từ attendance_events CHECK_IN")
            self.assertEqual(session["device_id"], "manager_batch_terminal")

    def test_filter_valid_mutations_alone_worker_with_manager_checkin(self):
        """Alone Worker job được chấp nhận khi nhân viên đã được Manager checkin qua timesheet."""
        now = datetime.now(timezone.utc)
        check_in_str = (now - timedelta(hours=1)).isoformat()
        date_str = now.strftime("%Y-%m-%d")

        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO mushroom_daily_timesheets (
                    id, employee_id, plan_date, check_in_time, check_out_time,
                    gross_worked_minutes, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, NULL, 60, %s, %s)
                """,
                (f"ts_{self.emp_id}", self.emp_id, date_str, check_in_str, check_in_str, check_in_str),
            )
            conn.commit()

            job_mutations = [
                MutationModel(
                    id=f"m_{uuid.uuid4().hex[:8]}",
                    table="mushroom_jobs",
                    operation="insert",
                    data={
                        "id": f"job_{uuid.uuid4().hex[:8]}",
                        "name": "Airing Room 12",
                        "job_type": "alone_worker",
                        "assigned_to": self.emp_name,
                        "room_id": "room_12",
                    },
                )
            ]

            repo = make_sync_repo(conn)
            valid, rejected = _filter_valid_mutations(conn, repo, job_mutations, None)
            self.assertEqual(len(valid), 1, "Job Alone Worker phải được chấp thuận vì nhân viên đã được Manager check-in")
            self.assertEqual(len(rejected), 0)

    def test_filter_valid_mutations_inflight_batch_checkin_and_job(self):
        """Alone Worker job gửi cùng batch với sự kiện CHECK_IN của Manager (in-flight) được chấp nhận."""
        now = datetime.now(timezone.utc).isoformat()
        batch_mutations = [
            # 1. Mutation điểm danh CHECK_IN cho nhân viên
            MutationModel(
                id=f"m_att_{uuid.uuid4().hex[:8]}",
                table="mushroom_attendance_events",
                operation="insert",
                data={
                    "id": f"att_{uuid.uuid4().hex[:8]}",
                    "employee_id": self.emp_id,
                    "event_type": "CHECK_IN",
                    "timestamp": now,
                    "source": "MANAGER_BATCH",
                },
            ),
            # 2. Mutation tạo Job Alone Worker ngay trong cùng 1 request
            MutationModel(
                id=f"m_job_{uuid.uuid4().hex[:8]}",
                table="mushroom_jobs",
                operation="insert",
                data={
                    "id": f"job_{uuid.uuid4().hex[:8]}",
                    "name": "Airing Room 05",
                    "job_type": "alone_worker",
                    "assigned_to": self.emp_name,
                    "room_id": "room_05",
                },
            ),
        ]

        with open_connection() as conn:
            repo = make_sync_repo(conn)
            valid, rejected = _filter_valid_mutations(conn, repo, batch_mutations, None)
            self.assertEqual(len(valid), 2, "Cả 2 mutation (CHECK_IN và Job Alone Worker) phải hợp lệ")
            self.assertEqual(len(rejected), 0)

    def test_filter_valid_mutations_alone_worker_rejected_when_not_checked_in(self):
        """Alone Worker job bị từ chối nếu người được giao việc hoàn toàn chưa điểm danh."""
        unknown_worker = f"Unknown Worker (emp_ghost_{uuid.uuid4().hex[:4]})"
        job_mutations = [
            MutationModel(
                id=f"m_reject_{uuid.uuid4().hex[:8]}",
                table="mushroom_jobs",
                operation="insert",
                data={
                    "id": f"job_ghost_{uuid.uuid4().hex[:8]}",
                    "name": "Airing Room 99",
                    "job_type": "alone_worker",
                    "assigned_to": unknown_worker,
                    "room_id": "room_99",
                },
            )
        ]

        with open_connection() as conn:
            repo = make_sync_repo(conn)
            valid, rejected = _filter_valid_mutations(conn, repo, job_mutations, None)
            self.assertEqual(len(valid), 0)
            self.assertEqual(len(rejected), 1)
            self.assertEqual(rejected[0]["error"], "assignee_not_checked_in")

    def test_get_active_session_by_clean_name_without_id(self):
        """Khớp chính xác tên nhân viên thuần (không có mã trong ngoặc) qua employee_name."""
        clean_name = f"Vinh Worker {uuid.uuid4().hex[:4]}"
        now = datetime.now(timezone.utc)
        check_in_str = (now - timedelta(hours=1)).isoformat()
        date_str = now.strftime("%Y-%m-%d")

        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO mushroom_daily_timesheets (
                    id, employee_id, employee_name, plan_date, check_in_time, check_out_time,
                    gross_worked_minutes, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, NULL, 60, %s, %s)
                """,
                (f"ts_{self.emp_id}", self.emp_id, clean_name, date_str, check_in_str, check_in_str, check_in_str),
            )
            conn.commit()

            # Tra cứu bằng TÊN THUẦN — không kèm mã nhân viên
            session = get_active_session_for_person(conn, clean_name)
            self.assertIsNotNone(session, "Phải tìm thấy phiên qua trường employee_name")
            self.assertEqual(session["user_name"], clean_name)

    def test_filter_valid_mutations_alone_worker_with_clean_name(self):
        """Giao việc Alone Worker theo tên sạch (như dropdown UI) chấp thuận thành công."""
        clean_name = f"Vinh Worker {uuid.uuid4().hex[:4]}"
        now = datetime.now(timezone.utc)
        check_in_str = (now - timedelta(hours=1)).isoformat()
        date_str = now.strftime("%Y-%m-%d")

        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO mushroom_daily_timesheets (
                    id, employee_id, employee_name, plan_date, check_in_time, check_out_time,
                    gross_worked_minutes, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, NULL, 60, %s, %s)
                """,
                (f"ts_{self.emp_id}", self.emp_id, clean_name, date_str, check_in_str, check_in_str, check_in_str),
            )
            conn.commit()

            job_mutations = [
                MutationModel(
                    id=f"m_{uuid.uuid4().hex[:8]}",
                    table="mushroom_jobs",
                    operation="insert",
                    data={
                        "id": f"job_{uuid.uuid4().hex[:8]}",
                        "name": "Solo Picking Room 01",
                        "job_type": "alone_worker",
                        "assigned_to": clean_name,
                        "room_id": "room_01",
                    },
                )
            ]

            repo = make_sync_repo(conn)
            valid, rejected = _filter_valid_mutations(conn, repo, job_mutations, None)
            self.assertEqual(len(valid), 1, "Job Alone Worker phải được chấp thuận với tên nhân viên thuần")
            self.assertEqual(len(rejected), 0)


if __name__ == "__main__":
    unittest.main()

