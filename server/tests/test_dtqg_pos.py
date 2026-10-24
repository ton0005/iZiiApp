# server/tests/test_dtqg_pos.py
"""
Vai trò POS nhà thuốc (QĐ 808 mục VIII–IX) trên mock dựng theo PDF.

Luồng thật: phòng khám gửi đơn (HIS) → nhà thuốc tra theo mã → bán → cập nhật số lượng bán.
"""
import json
import os
import sys
import unittest
from datetime import datetime, timedelta, timezone
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dtqg_client import DtqgClient
from dtqg_pos import DtqgPos
from dtqg_service import DtqgGateway
from server_config import CONFIG
from tests.mock_dtqg_server import MockDtqg
from tests.test_dtqg_gateway import Base, DOC, FAC, KEY

MA = "01aaa1234567-c"
SUPPLIER = {
    "ma_dinh_danh_co_so_cung_ung_thuoc": "NT-00123",
    "ten_co_so_cung_ung_thuoc": "Nhà thuốc An Khang",
    "so_dien_thoai_co_so_cung_ung_thuoc": "0281234567",
    "dia_chi_co_so_cung_ung_thuoc": "1 Nguyễn Huệ",
}


class PosBase(Base):
    def setUp(self):
        super().setUp()
        self.mock.add_pos_app("izii", "izii-key")
        self.assertEqual(self.gw.send("rx1")["result"], "sent")   # đơn có mặt trên "hệ thống quốc gia"
        self.mock.calls.clear()
        self.now = datetime.now(timezone.utc)
        self.pos = DtqgPos(self.conn, self.client, "izii", "izii-key", now_fn=lambda: self.now)

    def line(self, qty, **over):
        d = {"ma_thuoc_da_ke_don": "VD-1234-20", "so_luong_ban": qty}
        d.update(over)
        return d

    def sell(self, qty, hd="HD001", **over):
        return self.pos.sell(MA, [self.line(qty, **over)], SUPPLIER, hd)


class TestLookup(PosBase):
    def test_lookup_returns_prescription_with_remaining(self):
        r = self.pos.lookup(MA)
        self.assertTrue(r["ok"], r)
        self.assertTrue(r["co_the_ban"])
        ln = r["prescription"]["thong_tin_don_thuoc"][0]
        self.assertEqual((ln["so_luong"], ln["da_ban"], ln["con_lai"]), (10.0, 0.0, 10.0))

    def test_not_found(self):
        r = self.pos.lookup("01aaa0000000-c")
        self.assertFalse(r["ok"])
        self.assertEqual(r["status"], 404)

    def test_bad_format_not_sent_to_network(self):
        r = self.pos.lookup("abc")
        self.assertFalse(r["ok"])
        self.assertEqual(self.mock.calls, [])

    def test_wrong_app_key(self):
        bad = DtqgPos(self.conn, self.client, "izii", "sai", now_fn=lambda: self.now)
        self.assertEqual(bad.lookup(MA)["status"], 401)

    def test_unconfigured(self):
        r = DtqgPos(self.conn, self.client, "", "").lookup(MA)
        self.assertEqual(r["status"], 503)

    def test_expired_after_5_days(self):
        self.now = datetime(2026, 10, 16, 2, 30, tzinfo=timezone.utc) + timedelta(days=5, minutes=1)
        r = self.pos.lookup(MA)
        self.assertTrue(r["het_han"])
        self.assertFalse(r["co_the_ban"])
        self.assertEqual(self.sell(1)["result"], "rejected")

    def test_valid_on_day_5(self):
        self.now = datetime(2026, 10, 16, 2, 30, tzinfo=timezone.utc) + timedelta(days=4, hours=23)
        self.assertTrue(self.pos.lookup(MA)["co_the_ban"])


class TestSell(PosBase):
    def test_full_sale_updates_national_system(self):
        r = self.sell(10)
        self.assertEqual(r["result"], "sent", r)
        self.assertEqual(self.mock.prescriptions[MA]["sold"], {"VD-1234-20": 10.0})
        self.assertEqual(self.mock.sales[0]["ma_hoa_don"], "HD001")
        look = self.pos.lookup(MA)
        self.assertTrue(look["da_ban_het"])
        self.assertFalse(look["co_the_ban"])
        self.assertEqual(self.sell(1, hd="HD002")["result"], "rejected")

    def test_partial_sales_accumulate(self):
        self.assertEqual(self.sell(4)["result"], "sent")
        self.assertEqual(self.pos.lookup(MA)["prescription"]["thong_tin_don_thuoc"][0]["con_lai"], 6.0)
        over = self.sell(7, hd="HD002")
        self.assertEqual(over["result"], "rejected")
        self.assertTrue(any("vượt" in e for e in over["errors"]))
        self.assertEqual(self.sell(6, hd="HD003")["result"], "sent")

    def test_substitution_keeps_original_code(self):
        r = self.sell(5, ma_thuoc="VD-9999-21", ten_thuoc="Efferalgan 500mg", biet_duoc="Paracetamol")
        self.assertEqual(r["result"], "sent", r)
        sent = self.mock.sales[0]["thong_tin_thuoc"][0]
        self.assertEqual(sent["ma_thuoc_da_ke_don"], "VD-1234-20")
        self.assertEqual(sent["ma_thuoc"], "VD-9999-21")
        self.assertEqual(sent["ten_thuoc"], "Efferalgan 500mg")

    def test_unknown_original_code(self):
        r = self.pos.sell(MA, [self.line(1, ma_thuoc_da_ke_don="KHAC")], SUPPLIER, "HD1")
        self.assertEqual(r["result"], "rejected")
        self.assertTrue(r["local"])

    def test_missing_supplier_and_invoice(self):
        r = self.pos.sell(MA, [self.line(1)], {"ten_co_so_cung_ung_thuoc": "X"}, "")
        self.assertEqual(r["result"], "rejected")
        self.assertTrue(any("ma_hoa_don" in e for e in r["errors"]))
        self.assertTrue(any("ma_dinh_danh" in e for e in r["errors"]))
        self.assertEqual(self.mock.count("cap-nhat-don-thuoc"), 0)

    def test_network_failure_keeps_sale_and_counts_it(self):
        orig = self.mock.handle
        calls = {"n": 0}

        def flaky(method, path, headers, body):
            if path.endswith("cap-nhat-don-thuoc") and calls["n"] == 0:
                calls["n"] += 1
                self.mock.calls.append((method, path))
                return 503, {"message": "down"}
            return orig(method, path, headers, body)

        self.mock.handle = flaky
        r = self.sell(3)
        self.assertEqual(r["result"], "retry")
        # thuốc đã giao → số đã bán vẫn tính để không bán vượt
        self.assertEqual(self.pos.lookup(MA)["prescription"]["thong_tin_don_thuoc"][0]["da_ban"], 3.0)
        out = self.pos.retry_pending()
        self.assertEqual(out[0]["result"], "sent")
        self.assertEqual(self.mock.prescriptions[MA]["sold"], {"VD-1234-20": 3.0})
        self.assertEqual(self.pos.retry_pending(), [])

    def test_rejected_sale_not_counted(self):
        orig = self.mock.handle
        self.mock.handle = lambda m, p, h, b: (
            (422, {"danh_sach_cac_loi": ["Lỗi từ hệ thống"]}) if p.endswith("cap-nhat-don-thuoc")
            else orig(m, p, h, b))
        r = self.sell(2)
        self.assertEqual(r["result"], "rejected")
        self.assertEqual(r["errors"], ["Lỗi từ hệ thống"])
        self.assertEqual(self.pos.lookup(MA)["prescription"]["thong_tin_don_thuoc"][0]["da_ban"], 0.0)


if __name__ == "__main__":
    unittest.main()
