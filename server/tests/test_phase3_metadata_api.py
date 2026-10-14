# server/tests/test_phase3_metadata_api.py
"""
Test Suite Phase 3: Metadata, Model Registry, UI Descriptors, Settings & Record Rules.
Verifies model list, dynamic UI descriptor (colors, enum, job types), and scoped settings.
"""
import unittest
import uuid
from starlette.testclient import TestClient

import app as app_module
from dependencies import open_connection


class TestPhase3MetadataApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app_module.app)

    def test_list_models_and_get_ui_descriptor(self):
        """
        P3.1 & P3.2: Kiểm tra GET /api/v1/meta/models và GET /api/v1/meta/ui/{model}.
        Đặc biệt xác nhận UI descriptor trả về danh sách job types kèm color mã hex động (giải F1).
        """
        # 1. Models list
        res_models = self.client.get("/api/v1/meta/models")
        self.assertEqual(res_models.status_code, 200)
        models_data = res_models.json()
        self.assertIn("models", models_data)

        # 2. UI descriptor cho model 'job'
        res_ui = self.client.get("/api/v1/meta/ui/job")
        self.assertEqual(res_ui.status_code, 200)
        ui_data = res_ui.json()
        self.assertEqual(ui_data["model"], "job")
        self.assertIn("fields", ui_data)

        # Tìm trường job_type trong descriptor
        jt_field = next((f for f in ui_data["fields"] if f.get("field_name") == "job_type"), None)
        self.assertIsNotNone(jt_field)
        self.assertEqual(jt_field["data_type"], "enum")
        enums = jt_field.get("enum_values") or []
        self.assertGreater(len(enums), 0)

        # Mỗi item enum phải có color mã hex và label
        for item in enums:
            self.assertIn("value", item)
            self.assertIn("color", item)
            self.assertTrue(item["color"].startswith("#") or item["color"].startswith("0x"))

    def test_settings_get_and_post_scoped(self):
        """
        P3.4: Kiểm tra lưu và đọc settings phân phạm vi (global / tenant / site / device).
        """
        test_key = f"safety.co_threshold_{uuid.uuid4().hex[:6]}"
        test_val = {"threshold_ppm": 45, "alarm": True}

        # Lưu setting
        post_res = self.client.post(
            "/api/v1/settings",
            json={
                "scope": "site",
                "scope_id": "site_s1",
                "key": test_key,
                "value": test_val,
                "data_type": "json",
            },
        )
        self.assertEqual(post_res.status_code, 200)
        self.assertEqual(post_res.json()["status"], "success")

        # Đọc setting theo scope và key
        get_res = self.client.get(f"/api/v1/settings?scope=site&scope_id=site_s1&key={test_key}")
        self.assertEqual(get_res.status_code, 200)
        data = get_res.json()
        self.assertEqual(data["count"], 1)
        st = data["settings"][0]
        self.assertEqual(st["key"], test_key)
        self.assertEqual(st["scope"], "site")
        self.assertEqual(st["scope_id"], "site_s1")

    def test_record_rules_endpoint(self):
        """
        P3.5: Kiểm tra tra cứu record rules cho model.
        """
        rule_name = f"rule_picker_{uuid.uuid4().hex[:6]}"
        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO record_rules (tenant_id, rule_name, model_name, role_key, domain, perm_read, perm_write, enabled)
                VALUES ('default', %s, 'job', 'picker', '[["department_id","=","harvest"]]', TRUE, FALSE, TRUE)
                """,
                (rule_name,),
            )
            conn.commit()

        res = self.client.get("/api/v1/rules/job")
        self.assertEqual(res.status_code, 200)
        rules_data = res.json()
        self.assertEqual(rules_data["model"], "job")
        self.assertGreater(rules_data["count"], 0)
        found = any(r["rule_name"] == rule_name for r in rules_data["rules"])
        self.assertTrue(found)


    def test_record_rules_evaluation_domain_filter(self):
        """
        P3.5 & B3: Kiểm tra biên dịch Odoo-style domain sang SQL WHERE clause cho role picker.
        """
        rule_name = f"rule_filter_{uuid.uuid4().hex[:6]}"
        with open_connection() as conn:
            conn.execute(
                """
                INSERT INTO record_rules (tenant_id, rule_name, model_name, role_key, domain, perm_read, perm_write, enabled)
                VALUES ('default', %s, 'mushroom_jobs', 'picker', '[["department_id","=","harvest"],["priority","in",["high","urgent"]]]', TRUE, FALSE, TRUE)
                """,
                (rule_name,),
            )
            conn.commit()

        res = self.client.get("/api/v1/rules/mushroom_jobs/filter?role=picker&perm=read")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["model"], "mushroom_jobs")
        self.assertEqual(data["role"], "picker")
        self.assertGreater(data["rule_count"], 0)
        self.assertIn('"department_id" = %s', data["where_sql"])
        self.assertIn('"priority" IN (%s, %s)', data["where_sql"])
        self.assertIn("harvest", data["params"])
        self.assertIn("high", data["params"])
        self.assertIn("urgent", data["params"])


if __name__ == "__main__":
    unittest.main()
