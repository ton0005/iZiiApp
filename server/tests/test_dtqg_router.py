# server/tests/test_dtqg_router.py
"""
Router /api/v1/dtqg/* — phân quyền, fail-closed, và đường đi HIS + POS qua HTTP nội bộ.
Dùng FastAPI TestClient + mock Đơn thuốc quốc gia (dựng theo quyet-dinh-808.pdf).
"""
import os
import sys
import unittest
from contextlib import contextmanager
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI
from fastapi.testclient import TestClient

from dtqg_client import DtqgClient
from routers import dtqg as router_mod
from server_config import CONFIG
from tests.test_dtqg_gateway import Base, DOC, FAC, KEY

ADMIN = {"X-iZii-Admin-Token": "admin-secret"}
MA = "01aaa1234567-c"


class RouterBase(Base):
    def setUp(self):
        super().setUp()
        self.mock.add_pos_app("izii", "izii-key")
        patches = [
            mock.patch.object(CONFIG, "admin_secret", "admin-secret"),
            mock.patch.object(CONFIG, "dtqg_enabled", True),
            mock.patch.object(CONFIG, "dtqg_cred_key", KEY),
            mock.patch.object(CONFIG, "dtqg_pos_app_name", "izii"),
            mock.patch.object(CONFIG, "dtqg_pos_app_key", "izii-key"),
            mock.patch.object(router_mod, "open_connection", self._open),
            mock.patch.object(router_mod, "_make_client",
                              lambda: DtqgClient("http://dtqg.test", transport=self.mock.transport())),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        app = FastAPI()
        app.include_router(router_mod.router)
        self.http = TestClient(app)

    @contextmanager
    def _open(self, tenant_id="*"):
        yield self.conn


class TestAuth(RouterBase):
    def test_status_requires_credentials(self):
        self.assertEqual(self.http.get("/api/v1/dtqg/status").status_code, 401)

    def test_credentials_admin_only(self):
        body = {"subject_type": "doctor", "subject_code": DOC, "password": "x"}
        self.assertEqual(self.http.put("/api/v1/dtqg/credentials", json=body).status_code, 401)
        self.assertEqual(self.http.put("/api/v1/dtqg/credentials", json=body, headers={"X-iZii-Device-Token": "bogus"}).status_code, 401)

    def test_credentials_roundtrip_never_leaks_password(self):
        body = {"subject_type": "doctor", "subject_code": DOC, "password": "bi-mat-123"}
        r = self.http.put("/api/v1/dtqg/credentials", json=body, headers=ADMIN)
        self.assertEqual(r.status_code, 200)
        self.assertNotIn("bi-mat-123", r.text)
        st = self.http.get("/api/v1/dtqg/status", headers=ADMIN)
        self.assertEqual(st.status_code, 200)
        self.assertNotIn("bi-mat-123", st.text)
        self.assertNotIn("password", st.text.lower().replace("credentials", ""))

    def test_credentials_rejected_without_key(self):
        with mock.patch.object(CONFIG, "dtqg_cred_key", ""):
            r = self.http.put("/api/v1/dtqg/credentials", headers=ADMIN,
                              json={"subject_type": "facility", "subject_code": "x", "password": "y"})
        self.assertEqual(r.status_code, 503)

    def test_invalid_subject_type(self):
        r = self.http.put("/api/v1/dtqg/credentials", headers=ADMIN,
                          json={"subject_type": "hacker", "subject_code": "x", "password": "y"})
        self.assertEqual(r.status_code, 422)

    def test_disabled_blocks_actions_but_not_status(self):
        with mock.patch.object(CONFIG, "dtqg_enabled", False):
            self.assertEqual(self.http.post("/api/v1/dtqg/prescriptions/rx1/send", headers=ADMIN).status_code, 503)
            self.assertEqual(self.http.post("/api/v1/dtqg/pos/lookup", headers=ADMIN, json={"ma_don_thuoc": MA}).status_code, 503)
            self.assertEqual(self.http.get("/api/v1/dtqg/status", headers=ADMIN).status_code, 200)
        self.assertEqual(self.mock.calls, [])

    def test_queue_process_admin_only(self):
        self.assertEqual(self.http.post("/api/v1/dtqg/queue/process").status_code, 401)


class TestHisViaApi(RouterBase):
    def test_send_and_submissions(self):
        r = self.http.post("/api/v1/dtqg/prescriptions/rx1/send", headers=ADMIN)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["result"], "sent", r.text)
        subs = self.http.get("/api/v1/dtqg/submissions?prescription_id=rx1", headers=ADMIN).json()["submissions"]
        self.assertEqual(len(subs), 1)
        self.assertEqual(subs[0]["errors"], [])
        st = self.http.get("/api/v1/dtqg/status", headers=ADMIN).json()
        self.assertEqual(st["prescriptions"], {"sent": 1})
        self.assertEqual(st["facility_code"], FAC)

    def test_list_prescriptions_with_status_filter(self):
        self.add_rx("rx2", "01aaa7654321-c", status="draft", prescription_date="2026-10-17T01:00:00+00:00")
        self.http.post("/api/v1/dtqg/prescriptions/rx1/send", headers=ADMIN)
        allr = self.http.get("/api/v1/dtqg/prescriptions", headers=ADMIN).json()["prescriptions"]
        self.assertEqual([r["id"] for r in allr], ["rx2", "rx1"])          # mới nhất trước
        sent = self.http.get("/api/v1/dtqg/prescriptions?status=sent", headers=ADMIN).json()["prescriptions"]
        self.assertEqual([r["id"] for r in sent], ["rx1"])
        self.assertEqual(sent[0]["patient_name"], "Nguyễn Văn An")
        self.assertEqual(sent[0]["item_count"], 1)
        self.assertEqual(self.http.get("/api/v1/dtqg/prescriptions?status=bogus", headers=ADMIN).status_code, 422)
        self.assertEqual(self.http.get("/api/v1/dtqg/prescriptions").status_code, 401)

    def test_queue_process(self):
        self.add_rx("rx2", "01aaa7654321-c")
        out = self.http.post("/api/v1/dtqg/queue/process", headers=ADMIN).json()["results"]
        self.assertEqual(sorted(o["result"] for o in out), ["sent", "sent"])

    def test_add_and_remove_doctor(self):
        self.assertEqual(self.http.post("/api/v1/dtqg/doctors/add", headers=ADMIN,
                                        json={"ma_lien_thong_bac_si": DOC}).json()["result"], "ok")
        self.assertIn(DOC, self.mock.facility_doctors[FAC])
        self.assertEqual(self.http.post("/api/v1/dtqg/doctors/remove", headers=ADMIN,
                                        json={"ma_lien_thong_bac_si": DOC}).json()["result"], "ok")
        self.assertNotIn(DOC, self.mock.facility_doctors[FAC])
        # bác sĩ bị xóa → gửi đơn lại phải thêm lại bác sĩ rồi mới đăng nhập được
        self.assertEqual(self.http.post("/api/v1/dtqg/prescriptions/rx1/send", headers=ADMIN).json()["result"], "sent")

    def test_remove_unknown_doctor_reports_verbatim_error(self):
        r = self.http.post("/api/v1/dtqg/doctors/remove", headers=ADMIN,
                           json={"ma_lien_thong_bac_si": "01khong-co"}).json()
        self.assertEqual(r["result"], "rejected")
        self.assertIn("không thuộc", r["errors"][0])


class TestPosViaApi(RouterBase):
    def setUp(self):
        super().setUp()
        self.http.post("/api/v1/dtqg/prescriptions/rx1/send", headers=ADMIN)
        self._push("clinic_facility", "update", {
            "id": "default", "name": "Nhà thuốc An Khang", "address": "1 Nguyễn Huệ",
            "phone": "028 1234 567", "ma_dinh_danh_cung_ung": "NT-00123",
        })

    def test_lookup_and_sell_uses_facility_defaults(self):
        look = self.http.post("/api/v1/dtqg/pos/lookup", headers=ADMIN, json={"ma_don_thuoc": MA}).json()
        self.assertTrue(look["co_the_ban"], look)
        r = self.http.post("/api/v1/dtqg/pos/sell", headers=ADMIN, json={
            "ma_don_thuoc": MA, "ma_hoa_don": "HD01",
            "lines": [{"ma_thuoc_da_ke_don": "VD-1234-20", "so_luong_ban": 4}],
        }).json()
        self.assertEqual(r["result"], "sent", r)
        sent = self.mock.sales[0]
        self.assertEqual(sent["ma_dinh_danh_co_so_cung_ung_thuoc"], "NT-00123")
        self.assertEqual(sent["so_dien_thoai_co_so_cung_ung_thuoc"], "0281234567")

    def test_sell_over_remaining_rejected(self):
        r = self.http.post("/api/v1/dtqg/pos/sell", headers=ADMIN, json={
            "ma_don_thuoc": MA, "ma_hoa_don": "HD01",
            "lines": [{"ma_thuoc_da_ke_don": "VD-1234-20", "so_luong_ban": 11}],
        }).json()
        self.assertEqual(r["result"], "rejected")
        self.assertEqual(self.mock.sales, [])

    def test_pos_requires_auth(self):
        self.assertEqual(self.http.post("/api/v1/dtqg/pos/lookup", json={"ma_don_thuoc": MA}).status_code, 401)


if __name__ == "__main__":
    unittest.main()
