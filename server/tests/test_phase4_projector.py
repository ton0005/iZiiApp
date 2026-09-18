# server/tests/test_phase4_projector.py
"""
Test Suite Phase 4: CQRS Read-Model Projector, Checkpoint, Hooks & Snapshot API.
Verifies NT-3 and Q1 (Dirty-Field Column-Merge), Replay Protection, Checkpoint and History API.
"""
import json
import unittest
import uuid
from starlette.testclient import TestClient

import app as app_module
from dependencies import open_connection
from projector import ReadModelProjector
from hooks import HookEngine, HookContext


class TestPhase4Projector(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app_module.app)
        cls.projector = ReadModelProjector()

    def setUp(self):
        # Dọn sạch các task sinh ra bởi các test để không gây nhiễu keyset pagination
        with open_connection() as conn:
            conn.execute("DELETE FROM tasks WHERE id LIKE '~page_%'")
            conn.commit()

    def test_projector_insert_and_audit_fields(self):
        """Kiểm tra Projector insert bản ghi mới và tự điền audit columns."""
        test_id = f"test_proj_{uuid.uuid4().hex[:8]}"
        with open_connection() as conn:
            success = self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="insert",
                data={
                    "id": test_id,
                    "name": "Initial Job Name",
                    "status": "planned",
                    "priority": "normal",
                    "room_id": "room_01",
                },
                seq=101,
                mutation_id=f"mut_{test_id}",
                tenant_id="test_tenant",
                actor="test_user",
            )
            conn.commit()
            self.assertTrue(success)

            cur = conn.execute(
                "SELECT id, name, status, priority, room_id, last_seq, last_mutation_id, created_by, updated_by "
                "FROM mushroom_jobs WHERE id = %s",
                (test_id,),
            )
            row = cur.fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row["name"], "Initial Job Name")
            self.assertEqual(row["status"], "planned")
            self.assertEqual(row["priority"], "normal")
            self.assertEqual(row["room_id"], "room_01")
            self.assertEqual(row["last_seq"], 101)
            self.assertEqual(row["last_mutation_id"], f"mut_{test_id}")
            self.assertEqual(row["created_by"], "test_user")

    def test_projector_dirty_field_update_preserves_untouched_columns(self):
        """
        Q1 / NT-3: Mutation update kiểu dirty-field chỉ cập nhật các trường có trong payload,
        KHÔNG làm mất hoặc reset các trường cũ về NULL.
        """
        test_id = f"test_proj_dirty_{uuid.uuid4().hex[:8]}"
        with open_connection() as conn:
            # 1. Insert ban đầu với đầy đủ các trường
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="insert",
                data={
                    "id": test_id,
                    "name": "Crucial Job Name",
                    "status": "planned",
                    "priority": "high",
                    "room_id": "room_99",
                },
                seq=201,
                mutation_id=f"mut_{test_id}_1",
                tenant_id="test_tenant",
                actor="creator_user",
            )
            conn.commit()

            # 2. Update chỉ gửi dirty fields: { "id": test_id, "status": "in_progress" }
            # Chú ý: 'name', 'priority', 'room_id' hoàn toàn vắng mặt
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="update",
                data={
                    "id": test_id,
                    "status": "in_progress",
                },
                seq=202,
                mutation_id=f"mut_{test_id}_2",
                tenant_id="test_tenant",
                actor="updater_user",
            )
            conn.commit()

            # 3. Kiểm tra: status đổi, nhưng name, priority, room_id vẫn được bảo toàn
            cur = conn.execute(
                "SELECT name, status, priority, room_id, last_seq, updated_by "
                "FROM mushroom_jobs WHERE id = %s",
                (test_id,),
            )
            row = cur.fetchone()
            self.assertEqual(row["status"], "in_progress")
            self.assertEqual(row["name"], "Crucial Job Name")
            self.assertEqual(row["priority"], "high")
            self.assertEqual(row["room_id"], "room_99")
            self.assertEqual(row["last_seq"], 202)
            self.assertEqual(row["updated_by"], "updater_user")

    def test_projector_dirty_field_update_with_updated_at_in_payload(self):
        """
        Kiểm tra khi client gửi kèm trường 'updated_at' trong payload của mutation UPDATE,
        projector không sinh ra câu lệnh SQL có 2 mệnh đề 'updated_at = %s' gây lỗi:
        'multiple assignments to same column "updated_at"'.
        """
        test_id = f"test_proj_updated_at_{uuid.uuid4().hex[:8]}"
        with open_connection() as conn:
            # 1. Insert ban đầu
            self.projector.project_mutation(
                conn=conn,
                table="grow_rooms",
                operation="insert",
                data={
                    "id": test_id,
                    "name": "Room A1",
                    "status": "active",
                },
                seq=210,
                mutation_id=f"mut_{test_id}_1",
                tenant_id="test_tenant",
                actor="creator_user",
            )
            conn.commit()

            # 2. Client gửi UPDATE có kèm updated_at (thường gặp khi Flutter client push thay đổi)
            client_time = "2026-09-17T14:36:55.000000+00:00"
            success = self.projector.project_mutation(
                conn=conn,
                table="grow_rooms",
                operation="update",
                data={
                    "id": test_id,
                    "status": "idle",
                    "updated_at": client_time,
                },
                seq=211,
                mutation_id=f"mut_{test_id}_2",
                tenant_id="test_tenant",
                actor="updater_user",
            )
            conn.commit()
            self.assertTrue(success)

            cur = conn.execute(
                "SELECT status, last_seq, updated_by FROM grow_rooms WHERE id = %s",
                (test_id,),
            )
            row = cur.fetchone()
            self.assertEqual(row["status"], "idle")
            self.assertEqual(row["last_seq"], 211)
            self.assertEqual(row["updated_by"], "updater_user")

    def test_projector_explicit_null_clears_field(self):
        """
        Q1.2: Phân biệt trường vắng mặt (giữ nguyên) với trường null tường minh (xoá giá trị).
        """
        test_id = f"test_proj_null_{uuid.uuid4().hex[:8]}"
        with open_connection() as conn:
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="insert",
                data={
                    "id": test_id,
                    "name": "Assigned Task",
                    "assignee": "worker_01",
                    "status": "assigned",
                },
                seq=301,
                mutation_id=f"mut_{test_id}_1",
                tenant_id="test_tenant",
            )
            conn.commit()

            # Gửi update với assignee: None (tường minh)
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="update",
                data={
                    "id": test_id,
                    "assignee": None,
                    "status": "planned",
                },
                seq=302,
                mutation_id=f"mut_{test_id}_2",
                tenant_id="test_tenant",
            )
            conn.commit()

            cur = conn.execute("SELECT assignee, status, name FROM mushroom_jobs WHERE id = %s", (test_id,))
            row = cur.fetchone()
            self.assertIsNone(row["assignee"])
            self.assertEqual(row["status"], "planned")
            self.assertEqual(row["name"], "Assigned Task")

    def test_projector_replay_protection_seq(self):
        """
        NT-4 / Q1: Mutation có seq nhỏ hơn hoặc bằng last_seq bị bỏ qua, không ghi đè dữ liệu mới hơn.
        """
        test_id = f"test_proj_replay_{uuid.uuid4().hex[:8]}"
        with open_connection() as conn:
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="insert",
                data={"id": test_id, "name": "Version 500", "status": "completed"},
                seq=500,
                mutation_id="mut_500",
            )
            conn.commit()

            # Gửi mutation cũ hơn với seq=450 (ví dụ mạng chập chờn gửi lại)
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="update",
                data={"id": test_id, "name": "Out of order Version 450", "status": "planned"},
                seq=450,
                mutation_id="mut_450",
            )
            conn.commit()

            cur = conn.execute("SELECT name, status, last_seq FROM mushroom_jobs WHERE id = %s", (test_id,))
            row = cur.fetchone()
            self.assertEqual(row["name"], "Version 500")
            self.assertEqual(row["status"], "completed")
            self.assertEqual(row["last_seq"], 500)

    def test_hook_alone_worker_auto_generates_safety_config(self):
        """
        P4.6 & M1: Hook tự động tạo mushroom_job_safety_configs khi job là Alone Worker.
        """
        job_id = f"solo_job_{uuid.uuid4().hex[:8]}"
        with open_connection() as conn:
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="insert",
                data={
                    "id": job_id,
                    "name": "Check Alone Room 12",
                    "is_solo_job": 1,
                    "job_type": "alone_worker",
                    "status": "in_progress",
                },
                seq=601,
                mutation_id=f"mut_{job_id}",
                tenant_id="tenant_safety",
            )
            conn.commit()

            # Kiểm tra xem hook có tạo safety config không
            cur = conn.execute(
                "SELECT id, job_id, check_in_interval_minutes, escalation_target "
                "FROM mushroom_job_safety_configs WHERE job_id = %s",
                (job_id,),
            )
            cfg = cur.fetchone()
            self.assertIsNotNone(cfg)
            self.assertEqual(cfg["job_id"], job_id)
            self.assertEqual(cfg["check_in_interval_minutes"], 30)
            self.assertEqual(cfg["escalation_target"], "supervisor")

    def test_snapshot_and_history_api(self):
        """
        P4.5 Snapshot API & P4.7 Record History API endpoints.
        """
        entity_id = f"ent_{uuid.uuid4().hex[:8]}"
        # Đẩy mutation qua push API
        push_payload = {
            "device_id": "test_dev_01",
            "mutations": [
                {
                    "id": f"m_hist_1_{entity_id}",
                    "table": "tasks",
                    "operation": "insert",
                    "data": {"id": entity_id, "title": "History Task Title", "status": "todo"},
                },
                {
                    "id": f"m_hist_2_{entity_id}",
                    "table": "tasks",
                    "operation": "update",
                    "data": {"id": entity_id, "status": "done"},
                },
            ],
        }
        res_push = self.client.post("/sync/push", json=push_payload)
        self.assertEqual(res_push.status_code, 200)

        # 1. Test Snapshot API
        res_snap = self.client.get("/sync/snapshot/tasks?limit=100")
        self.assertEqual(res_snap.status_code, 200)
        snap_data = res_snap.json()
        self.assertIn("snapshot_seq", snap_data)
        self.assertGreater(snap_data["snapshot_seq"], 0)
        self.assertIsInstance(snap_data["rows"], list)

        # 2. Test Record History API
        res_hist = self.client.get(f"/sync/records/tasks/{entity_id}/history")
        self.assertEqual(res_hist.status_code, 200)
        hist_data = res_hist.json()
        self.assertEqual(hist_data["table"], "tasks")
        self.assertEqual(hist_data["record_id"], entity_id)
        self.assertGreaterEqual(hist_data["count"], 2)
        operations = [item["operation"] for item in hist_data["history"]]
        self.assertIn("insert", operations)
        self.assertIn("update", operations)


    def test_snapshot_keyset_pagination(self):
        """
        P4.5 / A4: Keyset pagination với after_id, next_cursor, và has_more.
        """
        # Tạo 5 tasks có ID được sắp xếp thứ tự (tiền tố ~page_ để đứng tuyệt đối sau tất cả các task đã có trong DB theo mã ASCII)
        prefix = f"~page_{uuid.uuid4().hex[:6]}"
        muts = []
        for i in range(1, 6):
            task_id = f"{prefix}_{i}"
            muts.append({
                "id": f"mut_{task_id}",
                "table": "tasks",
                "operation": "insert",
                "data": {"id": task_id, "title": f"Page Task {i}", "status": "todo"},
            })
        res = self.client.post("/sync/push", json={"device_id": "test_page_dev", "mutations": muts})
        self.assertEqual(res.status_code, 200)

        # Trang 1: limit=2, sau đó dùng next_cursor
        res1 = self.client.get(f"/sync/snapshot/tasks?limit=2&after_id={prefix}_0")
        self.assertEqual(res1.status_code, 200)
        d1 = res1.json()
        self.assertEqual(len(d1["rows"]), 2)
        self.assertTrue(d1["has_more"])
        self.assertIsNotNone(d1["next_cursor"])
        next_id = d1["next_cursor"]
        self.assertEqual(next_id, f"{prefix}_2")

        # Trang 2: sau next_id
        res2 = self.client.get(f"/sync/snapshot/tasks?limit=2&after_id={next_id}")
        self.assertEqual(res2.status_code, 200)
        d2 = res2.json()
        self.assertEqual(len(d2["rows"]), 2)
        self.assertEqual(d2["rows"][0]["id"], f"{prefix}_3")
        self.assertEqual(d2["rows"][1]["id"], f"{prefix}_4")
        self.assertTrue(d2["has_more"])

        # Trang 3: sau record 4, limit=2 -> chỉ còn đúng 1 record (record 5) vì không còn record nào khác sau ~page...
        res3 = self.client.get(f"/sync/snapshot/tasks?limit=2&after_id={prefix}_4")
        self.assertEqual(res3.status_code, 200)
        d3 = res3.json()
        self.assertEqual(len(d3["rows"]), 1)
        self.assertEqual(d3["rows"][0]["id"], f"{prefix}_5")
        self.assertFalse(d3["has_more"])

    def test_savepoint_isolation_partial_batch_failure(self):
        """
        A1: Khi một mutation trong batch bị lỗi, savepoint chỉ rollback mutation đó.
        Các mutation hợp lệ khác vẫn được commit thành công, và danh sách rejected phản ánh đúng lỗi.
        """
        valid_id_1 = f"valid_1_{uuid.uuid4().hex[:6]}"
        bad_id = f"bad_{uuid.uuid4().hex[:6]}"
        valid_id_2 = f"valid_2_{uuid.uuid4().hex[:6]}"

        push_payload = {
            "device_id": "test_savepoint_dev",
            "mutations": [
                {
                    "id": f"m_valid_1_{valid_id_1}",
                    "table": "tasks",
                    "operation": "insert",
                    "data": {"id": valid_id_1, "title": "First Valid Task", "status": "todo"},
                },
                {
                    "id": f"m_bad_{bad_id}",
                    "table": "tasks",
                    "operation": "update",
                    # Update một record hoàn toàn không tồn tại -> Projector raise ValueError
                    "data": {"id": bad_id, "title": "Should Fail"},
                },
                {
                    "id": f"m_valid_2_{valid_id_2}",
                    "table": "tasks",
                    "operation": "insert",
                    "data": {"id": valid_id_2, "title": "Second Valid Task", "status": "todo"},
                },
            ],
        }

        res = self.client.post("/sync/push", json=push_payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()

        # 2 mutations thành công, 1 mutation bị rejected
        self.assertEqual(data.get("applied"), 2)
        self.assertIn(f"m_valid_1_{valid_id_1}", data.get("applied_ids", []))
        self.assertIn(f"m_valid_2_{valid_id_2}", data.get("applied_ids", []))

        rejected = data.get("rejected", [])
        self.assertEqual(len(rejected), 1)
        self.assertEqual(rejected[0]["id"], f"m_bad_{bad_id}")

        # Kiểm tra read model: 2 task hợp lệ tồn tại trong DB, task lỗi không có
        with open_connection() as conn:
            cur1 = conn.execute("SELECT id, title FROM tasks WHERE id = %s", (valid_id_1,))
            self.assertIsNotNone(cur1.fetchone())
            cur2 = conn.execute("SELECT id, title FROM tasks WHERE id = %s", (valid_id_2,))
            self.assertIsNotNone(cur2.fetchone())
            cur3 = conn.execute("SELECT id FROM tasks WHERE id = %s", (bad_id,))
            self.assertIsNone(cur3.fetchone())

    def test_hook_after_save_gets_full_merged_row(self):
        """
        A2: Khi dirty-field delta update xảy ra, HookEngine nhận được toàn bộ merged_row
        thay vì chỉ payload chứa 1 trường thay đổi.
        Kiểm tra: Job tạo ban đầu là alone_worker với status='planned'.
        Sau đó gửi mutation update CHỈ THAY ĐỔI duy nhất status='in_progress' (dirty-field delta không có is_solo_job hay job_type).
        Hook after_save nhận được merged_row đầy đủ từ DB và tự động tạo mushroom_job_safety_configs.
        """
        job_id = f"job_hook_{uuid.uuid4().hex[:8]}"

        with open_connection() as conn:
            # 1. Insert job ban đầu với job_type = alone_worker, status = planned
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="insert",
                data={
                    "id": job_id,
                    "name": "Hook Test Job",
                    "status": "planned",
                    "job_type": "alone_worker",
                    "is_solo_job": 1,
                },
                seq=701,
                mutation_id=f"mut_init_{job_id}",
                tenant_id="default",
            )
            conn.commit()

            # Xóa safety config tạo lúc insert (nếu có) để kiểm chứng việc delta update kích hoạt lại
            conn.execute("DELETE FROM mushroom_job_safety_configs WHERE job_id = %s", (job_id,))
            conn.commit()

            # 2. Gửi mutation update CHỈ CÓ status = 'in_progress' (dirty-field delta)
            # Hoàn toàn không mang trường job_type hay is_solo_job
            self.projector.project_mutation(
                conn=conn,
                table="mushroom_jobs",
                operation="update",
                data={
                    "id": job_id,
                    "status": "in_progress",
                },
                seq=702,
                mutation_id=f"mut_upd_{job_id}",
                tenant_id="default",
            )
            conn.commit()

            # 3. Hook _hook_ensure_alone_worker_safety_config nhận merged_row đọc từ DB
            # Nhìn thấy job_type = 'alone_worker' và tự động sinh bản ghi safety config
            cur = conn.execute(
                "SELECT id, job_id, check_in_interval_minutes, escalation_target "
                "FROM mushroom_job_safety_configs WHERE job_id = %s",
                (job_id,),
            )
            cfg = cur.fetchone()
            self.assertIsNotNone(cfg)
            self.assertEqual(cfg["job_id"], job_id)
            self.assertEqual(cfg["check_in_interval_minutes"], 30)

    def test_hook_job_completed_resets_room_current_stage(self):
        """
        A3 / P5.8 DoD: Khi job chuyển sang completed, room.current_stage phải được reset về NULL.
        """
        job_id = f"job_comp_{uuid.uuid4().hex[:8]}"
        room_id = f"room_comp_{uuid.uuid4().hex[:8]}"

        with open_connection() as conn:
            conn.execute(
                "INSERT INTO grow_rooms (id, name, status, current_stage) VALUES (%s, %s, %s, %s)",
                (room_id, "Room Completed A3", "active", "harvesting"),
            )
            conn.commit()

        # Insert job in_progress
        self.client.post("/sync/push", json={
            "device_id": "test_hook_dev",
            "mutations": [{
                "id": f"m_start_{job_id}",
                "table": "mushroom_jobs",
                "operation": "insert",
                "data": {
                    "id": job_id,
                    "name": "Completed Hook Test",
                    "room_id": room_id,
                    "status": "in_progress",
                    "job_type": "harvest",
                },
            }]
        })

        # Cập nhật job status sang completed
        res_comp = self.client.post("/sync/push", json={
            "device_id": "test_hook_dev",
            "mutations": [{
                "id": f"m_done_{job_id}",
                "table": "mushroom_jobs",
                "operation": "update",
                "data": {
                    "id": job_id,
                    "status": "completed",
                },
            }]
        })
        self.assertEqual(res_comp.status_code, 200)

        # Kiểm tra room current_stage đã được reset về NULL
        with open_connection() as conn:
            cur = conn.execute("SELECT current_stage FROM grow_rooms WHERE id = %s", (room_id,))
            room = cur.fetchone()
            self.assertIsNotNone(room)
            self.assertIsNone(room["current_stage"])

    def test_projector_rejects_update_on_unknown_record(self):
        """
        A5 / P4.2 DoD: Projector từ chối mutation update/patch trên bản ghi chưa từng tồn tại
        và không tạo stub rỗng trong read model.
        """
        ghost_id = f"ghost_{uuid.uuid4().hex[:8]}"
        with open_connection() as conn:
            with self.assertRaises(ValueError) as ctx:
                self.projector.project_mutation(
                    conn=conn,
                    table="tasks",
                    operation="update",
                    data={"id": ghost_id, "title": "Ghost Task"},
                    seq=9999,
                    mutation_id=f"mut_{ghost_id}",
                )
            self.assertIn("does not exist", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

