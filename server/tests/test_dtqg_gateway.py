# server/tests/test_dtqg_gateway.py
"""
DtqgGateway ↔ mock Đơn thuốc quốc gia (dựng theo quyet-dinh-808.pdf).

Chạy trên SQLite in-memory dựng từ migration 0013. Mọi cuộc gọi HTTP đi qua
httpx.MockTransport của MockDtqg — không có mạng thật.

Hành vi cần giữ:
1. Chuỗi gọi: đăng nhập cơ sở → thêm bác sĩ → đăng nhập bác sĩ → gửi đơn; token được cache.
2. Token hết hạn (401) → đăng nhập lại đúng một lần rồi gửi lại.
3. 422 → đơn 'rejected' với lỗi NGUYÊN VĂN; lỗi mạng → vẫn 'queued', thử lại sau.
4. Đơn thiếu dữ liệu bị chặn TRƯỚC khi gọi mạng.
5. Gửi 200 mà chưa kịp ghi trạng thái → lần sau KHÔNG gửi lại.
6. Mật khẩu liên thông luôn mã hóa; thiếu khóa/thiếu mật khẩu thì fail-closed.
"""
import json
import os
import sqlite3
import sys
import unittest
from datetime import datetime, timedelta, timezone
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cryptography.fernet import Fernet

import dtqg_payload as payload
from dtqg_client import DtqgClient
from dtqg_crypto import CredentialKeyError
from dtqg_service import DtqgGateway
from radio_events import fold_records
from repository.sqlite_repo import SQLiteSyncRepository
from server_config import CONFIG
from tests.mock_dtqg_server import MockDtqg

_MIG = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "migrations", "versions", "0013_dtqg_gateway.sql")

FAC = "0101aaa"
DOC = "0100123AG-CCHN"
KEY = Fernet.generate_key().decode()


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
    with open(_MIG, encoding="utf-8") as f:
        conn.executescript(f.read())
    return conn


class Base(unittest.TestCase):
    def setUp(self):
        self._p = mock.patch.object(CONFIG, "db_backend", "sqlite")
        self._p.start()
        self.conn = _make_db()
        self.repo = SQLiteSyncRepository(self.conn)
        self.mock = MockDtqg()
        self.mock.add_facility(FAC, "fac-pass")
        self.mock.add_doctor_account(DOC, "doc-pass")
        self.client = DtqgClient("http://dtqg.test", transport=self.mock.transport())
        self.gw = DtqgGateway(self.conn, self.repo, self.client, cred_key=KEY)
        self.gw.set_password("facility", FAC, "fac-pass")
        self.gw.set_password("doctor", DOC, "doc-pass")
        self._seq = 0
        self._seed()

    def tearDown(self):
        self.client.close()
        self.conn.close()
        self._p.stop()

    # -- dữ liệu mẫu ---------------------------------------------------------
    def _push(self, table, op, data):
        self._seq += 1
        self.repo.push_mutations(
            [{"id": f"t{self._seq}", "table": table, "operation": op, "data": data}],
            datetime.now(timezone.utc).isoformat(),
        )

    def _seed(self):
        self._push("clinic_facility", "update", {"id": "default", "ma_cskcb": "01aaa", "name": "PK Test"})
        self._push("doctors", "insert", {
            "id": "d1", "name": "BS A", "so_cchn": "00123/AG-CCHN", "ma_lien_thong_dtqg": DOC,
            "dtqg_status": "active", "duoc_ke_don": True,
        })
        self._push("patients", "insert", {
            "id": "p1", "full_name": "Nguyễn Văn An", "dob": "1990-05-01T00:00:00.000",
            "gender": "male", "phone": "0901234567", "address": "12 Trần Hưng Đạo",
            "so_cccd": "012345678901",
        })
        self.add_rx("rx1", "01aaa1234567-c")

    def add_rx(self, rx_id, ma_don, status="queued", **over):
        rx = {
            "id": rx_id, "visit_id": "v1", "patient_id": "p1", "doctor_id": "d1",
            "status": "pending", "ma_don_thuoc": ma_don, "loai_don": "c",
            "chan_doan_json": json.dumps([{"ma_benh": "J00", "ten_benh": "Viêm mũi họng cấp", "ket_luan": ""}]),
            "hinh_thuc_dieu_tri": 2, "dtqg_status": status,
            "prescription_date": "2026-10-16T02:30:00+00:00",
        }
        rx.update(over)
        self._push("prescriptions", "insert", rx)
        self._push("prescription_items", "insert", {
            "id": f"i-{rx_id}", "prescription_id": rx_id, "product_id": "m1",
            "medicine_name": "Paracetamol 500mg", "ma_thuoc_cuc_qldd": "VD-1234-20",
            "biet_duoc": "Paracetamol", "don_vi_tinh": "viên", "quantity": 10.0,
            "dosage_instructions": "Uống 1 viên x 3 lần/ngày",
        })

    def rx(self, rx_id="rx1"):
        return fold_records(self.repo.get_mutations_by_table("prescriptions"))[rx_id]

    def paths(self):
        return [p for _, p in self.mock.calls]


class TestHappyPath(Base):
    def test_call_chain_and_locking(self):
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "sent", res)
        self.assertEqual(self.paths(), [
            "/api/auth/dang-nhap-co-so-kham-chua-benh",
            "/api/v1/them-bac-si",
            "/api/auth/dang-nhap-bac-si",
            "/api/v1/gui-don-thuoc",
        ])
        rx = self.rx()
        self.assertEqual(rx["dtqg_status"], "sent")
        self.assertIsNone(rx["dtqg_last_error"])
        self.assertTrue(rx["dtqg_sent_at"])
        self.assertIn("01aaa1234567-c", self.mock.prescriptions)
        sub = self.conn.execute("SELECT * FROM dtqg_submissions").fetchall()
        self.assertEqual(len(sub), 1)
        self.assertEqual((sub[0]["ok"], sub[0]["http_status"]), (1, 200))

    def test_sent_prescription_not_resent(self):
        self.gw.send("rx1")
        n = len(self.mock.calls)
        self.assertEqual(self.gw.send("rx1")["result"], "skipped")
        self.assertEqual(len(self.mock.calls), n)

    def test_tokens_cached_across_prescriptions(self):
        self.gw.send("rx1")
        self.add_rx("rx2", "01aaa7654321-c")
        self.mock.calls.clear()
        self.assertEqual(self.gw.send("rx2")["result"], "sent")
        self.assertEqual(self.paths(), ["/api/v1/gui-don-thuoc"])

    def test_payload_sent_matches_spec(self):
        self.gw.send("rx1")
        body = self.mock.prescriptions["01aaa1234567-c"]["body"]
        self.assertEqual(body["loai_don_thuoc"], "c")
        self.assertEqual(body["ngay_sinh_benh_nhan"], "01/05/1990")
        self.assertEqual(body["gioi_tinh"], 2)
        self.assertEqual(body["ngay_gio_ke_don"], "2026-10-16 09:30:00")   # 02:30 UTC = 09:30 giờ VN
        self.assertEqual(body["ma_dinh_danh_cong_dan"], "012345678901")
        line = body["thong_tin_don_thuoc"][0]
        self.assertEqual((line["ma_thuoc"], line["so_luong"]), ("VD-1234-20", 10.0))
        self.assertEqual(body["chan_doan"][0]["ma_benh"], "J00")
        self.assertIsNone(body["signature"])

    def test_process_queue_only_sends_queued(self):
        self.add_rx("rx2", "01aaa7654321-c", status="draft")
        out = self.gw.process_queue()
        self.assertEqual([o["prescription_id"] for o in out], ["rx1"])
        self.assertEqual(self.rx("rx2")["dtqg_status"], "draft")


class TestAuthRecovery(Base):
    def test_expired_token_relogin_once(self):
        self.gw.send("rx1")
        self.add_rx("rx2", "01aaa7654321-c")
        self.mock.expire_all_tokens()      # phía hệ thống hết hạn token, cache của ta vẫn tưởng còn
        self.mock.calls.clear()
        res = self.gw.send("rx2")
        self.assertEqual(res["result"], "sent", res)
        self.assertEqual(self.paths(), [
            "/api/v1/gui-don-thuoc",                      # 401
            "/api/auth/dang-nhap-bac-si",
            "/api/v1/gui-don-thuoc",
        ])

    def test_local_token_expiry_triggers_relogin(self):
        self.gw.send("rx1")
        self.add_rx("rx2", "01aaa7654321-c")
        later = datetime.now(timezone.utc) + timedelta(days=7)
        self.gw._now = lambda: later
        self.mock.now = lambda: later - timedelta(days=7)   # hệ thống vẫn coi token còn hạn
        self.mock.calls.clear()
        self.assertEqual(self.gw.send("rx2")["result"], "sent")
        self.assertIn("/api/auth/dang-nhap-bac-si", self.paths())

    def test_doctor_already_added_remotely(self):
        self.mock.facility_doctors[FAC].add(DOC)           # 422 "đã tồn tại" khi thêm lại
        self.assertEqual(self.gw.send("rx1")["result"], "sent")
        row = self.conn.execute("SELECT * FROM dtqg_doctor_links").fetchall()
        self.assertEqual(len(row), 1)

    def test_stale_local_link_readds_doctor(self):
        self.conn.execute("INSERT INTO dtqg_doctor_links VALUES (?, ?, ?)", (FAC, DOC, "2026-01-01T00:00:00+00:00"))
        self.conn.commit()                                  # ta tưởng đã thêm, hệ thống thì chưa
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "sent", res)
        self.assertEqual(self.paths().count("/api/v1/them-bac-si"), 1)
        self.assertEqual(self.paths().count("/api/auth/dang-nhap-bac-si"), 2)

    def test_wrong_facility_password_rejected_verbatim(self):
        self.gw.set_password("facility", FAC, "sai-mat-khau")
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "rejected")
        self.assertIn("mật khẩu không đúng", res["errors"][0])
        self.assertIn("mật khẩu không đúng", self.rx()["dtqg_last_error"])


class TestFailureModes(Base):
    def test_server_422_is_stored_verbatim(self):
        self.gw.send("rx1")                                 # làm nóng token
        self.add_rx("rx2", "01aaa7654321-c")
        self.mock.fail_next = [(422, {"danh_sach_cac_loi": ["Mã bệnh J00 không hợp lệ", "Lỗi khác"]})]
        res = self.gw.send("rx2")
        self.assertEqual(res["result"], "rejected")
        self.assertEqual(res["errors"], ["Mã bệnh J00 không hợp lệ", "Lỗi khác"])
        rx = self.rx("rx2")
        self.assertEqual(rx["dtqg_status"], "rejected")
        self.assertEqual(rx["dtqg_last_error"], "Mã bệnh J00 không hợp lệ; Lỗi khác")
        sub = self.conn.execute("SELECT * FROM dtqg_submissions WHERE prescription_id='rx2'").fetchone()
        self.assertEqual(json.loads(sub["errors"]), ["Mã bệnh J00 không hợp lệ", "Lỗi khác"])
        self.assertEqual(sub["ok"], 0)

    def test_network_error_keeps_queued_and_retries(self):
        self.mock.drop_next = 1
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "retry")
        self.assertEqual(self.rx()["dtqg_status"], "queued")
        out = self.gw.process_queue()
        self.assertEqual(out[0]["result"], "sent")
        self.assertEqual(self.rx()["dtqg_status"], "sent")

    def test_http_500_keeps_queued(self):
        self.mock.fail_next = [(500, {"message": "Server Error"})]
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "retry")
        self.assertEqual(self.rx()["dtqg_status"], "queued")

    def test_local_validation_blocks_before_network(self):
        self._push("patients", "update", {"id": "p1", "phone": ""})
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "rejected")
        self.assertTrue(res["local"])
        self.assertTrue(any("điện thoại" in e for e in res["errors"]))
        self.assertEqual(self.mock.calls, [])
        self.assertEqual(self.rx()["dtqg_status"], "rejected")

    def test_child_under_72_months_needs_weight_and_guardian(self):
        child_dob = (datetime.now() - timedelta(days=365 * 3)).strftime("%Y-%m-%dT00:00:00.000")
        self._push("patients", "update", {"id": "p1", "dob": child_dob})
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "rejected")
        self.assertTrue(any("cân nặng" in e for e in res["errors"]))
        self.assertTrue(any("người giám hộ" in e for e in res["errors"]))
        self.assertEqual(self.mock.calls, [])

    def test_doctor_not_approved_blocked_locally(self):
        self._push("doctors", "update", {"id": "d1", "dtqg_status": "pending"})
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "rejected")
        self.assertEqual(self.mock.calls, [])

    def test_prefix_must_match_facility(self):
        self.add_rx("rx3", "99zzz1234567-c")
        res = self.gw.send("rx3")
        self.assertEqual(res["result"], "rejected")
        self.assertTrue(any("mã cơ sở" in e for e in res["errors"]))

    def test_non_c_type_unsupported(self):
        self.add_rx("rx4", "01aaa1111111-n", loai_don="n")
        self.assertEqual(self.gw.send("rx4")["result"], "rejected")

    def test_200_without_status_write_is_not_resent(self):
        # Mô phỏng sập máy sau khi gửi 200 nhưng trước khi ghi trạng thái.
        self.conn.execute(
            "INSERT INTO dtqg_submissions (id, prescription_id, ma_don_thuoc, kind, attempt, http_status, ok, "
            "errors, created_at) VALUES ('s0', 'rx1', '01aaa1234567-c', 'gui_don', 1, 200, 1, '[]', '2026-10-16')"
        )
        self.conn.commit()
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "skipped")
        self.assertEqual(self.mock.calls, [])
        self.assertEqual(self.rx()["dtqg_status"], "sent")

    def test_cancelled_prescription_skipped(self):
        self._push("prescriptions", "update", {"id": "rx1", "status": "cancelled"})
        self.assertEqual(self.gw.send("rx1")["result"], "skipped")
        self.assertEqual(self.mock.calls, [])

    def test_unknown_prescription(self):
        self.assertEqual(self.gw.send("nope")["result"], "not_found")


class TestCredentials(Base):
    def test_password_stored_encrypted(self):
        row = self.conn.execute("SELECT password_enc FROM dtqg_credentials WHERE subject_code=?", (FAC,)).fetchone()
        self.assertNotIn("fac-pass", row["password_enc"])
        self.assertEqual(self.gw._get_password("facility", FAC), "fac-pass")

    def test_status_never_exposes_secret(self):
        for r in self.gw.credential_status():
            self.assertNotIn("password_enc", r)
            self.assertNotIn("password", r)

    def test_set_password_fails_closed_without_key(self):
        gw = DtqgGateway(self.conn, self.repo, self.client, cred_key="")
        with mock.patch.object(CONFIG, "dtqg_cred_key", ""):
            with self.assertRaises(CredentialKeyError):
                gw.set_password("facility", "x", "y")

    def test_missing_password_blocks_without_rejecting(self):
        self.conn.execute("DELETE FROM dtqg_credentials WHERE subject_type='doctor'")
        self.conn.commit()
        res = self.gw.send("rx1")
        self.assertEqual(res["result"], "blocked")
        self.assertEqual(self.rx()["dtqg_status"], "queued")

    def test_wrong_key_blocks(self):
        gw = DtqgGateway(self.conn, self.repo, self.client, cred_key=Fernet.generate_key().decode())
        self.assertEqual(gw.send("rx1")["result"], "blocked")

    def test_changing_password_drops_cached_token(self):
        self.gw.send("rx1")
        self.gw.set_password("doctor", DOC, "doc-pass")
        left = self.conn.execute("SELECT COUNT(*) FROM dtqg_sessions WHERE subject_type='doctor'").fetchone()[0]
        self.assertEqual(left, 0)


class TestPayloadHelpers(unittest.TestCase):
    def test_dates_and_gender(self):
        self.assertEqual(payload.format_date("1990-05-01T00:00:00.000"), "01/05/1990")
        self.assertEqual(payload.format_datetime("2026-10-16T02:30:00+00:00"), "2026-10-16 09:30:00")
        self.assertEqual([payload.map_gender(g) for g in ("male", "female", "other", None)], [2, 3, 1, 1])

    def test_ma_don(self):
        self.assertTrue(payload.is_valid_ma_don("01aaa1234567-c"))
        for bad in ("01aaa1234567-x", "01aaa123456-c", "01AAA1234567-c", None, ""):
            self.assertFalse(payload.is_valid_ma_don(bad), bad)


if __name__ == "__main__":
    unittest.main()
