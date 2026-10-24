#!/usr/bin/env python3
# server/scripts/dtqg_smoke.py
"""
Thử nhanh kết nối Đơn thuốc quốc gia (môi trường TEST) và xác minh các điểm
tài liệu còn mâu thuẫn (plan 03, mục 9). Không đụng DB của iZii: tự dựng một đơn
mẫu, gửi bằng từng biến thể và in kết quả NGUYÊN VĂN của hệ thống.

Mật khẩu đọc từ biến môi trường (không nhận qua tham số để khỏi lọt vào lịch sử shell):
    DTQG_FACILITY_CODE   mã liên thông cơ sở      (vd 0101aaa)
    DTQG_FACILITY_PASS   mật khẩu cơ sở
    DTQG_DOCTOR_CODE     mã liên thông bác sĩ     (vd 0100123AG-CCHN)
    DTQG_DOCTOR_PASS     mật khẩu bác sĩ
    DTQG_API_BASE        (mặc định: IZIIAPP_DTQG_API_BASE hoặc https://api.donthuocquocgia.vn)
    DTQG_WEB_BASE        (mặc định: IZIIAPP_DTQG_WEB_BASE hoặc https://www.donthuocquocgia.vn)
    DTQG_APP_NAME / DTQG_APP_KEY   (tuỳ chọn) để thử tra đơn kiểu nhà thuốc

Ví dụ:
    python scripts/dtqg_smoke.py login                     # chỉ kiểm tra đăng nhập
    python scripts/dtqg_smoke.py send --variants           # thử các biến thể tên khóa / định dạng giờ
    python scripts/dtqg_smoke.py send --yes                # gửi 1 đơn thử (bệnh nhân GIẢ)

CẢNH BÁO: lệnh `send` TẠO ĐƠN THẬT trên hệ thống mà DTQG_API_BASE trỏ tới. Đơn đã gửi
không sửa/xóa được — CHỈ chạy trên môi trường test, bệnh nhân là dữ liệu giả.
"""
from __future__ import annotations

import argparse
import copy
import os
import random
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import dtqg_payload as payload
from dtqg_client import DtqgClient
from dtqg_service import DtqgGateway  # noqa: F401  (đảm bảo import cùng bản với server)


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def need(*names: str) -> dict:
    vals = {n: env(n) for n in names}
    missing = [n for n, v in vals.items() if not v]
    if missing:
        sys.exit("Thiếu biến môi trường: " + ", ".join(missing))
    return vals


def sample_rx(facility_code: str) -> tuple[dict, list, dict]:
    ma = facility_code[2:].lower() + "".join(random.choice("0123456789abcdefghijklmnopqrstuvwxyz") for _ in range(7)) + "-c"
    rx = {
        "ma_don_thuoc": ma, "loai_don": "c", "hinh_thuc_dieu_tri": 2,
        "chan_doan_json": '[{"ma_benh": "J00", "ten_benh": "Viêm mũi họng cấp (TEST)", "ket_luan": "Đơn thử nghiệm"}]',
        "prescription_date": datetime.now().astimezone().isoformat(),
        "loi_dan": "Đơn thử nghiệm kết nối - không dùng để điều trị",
    }
    items = [{
        "medicine_name": "Paracetamol 500mg (TEST)", "ma_thuoc_cuc_qldd": env("DTQG_TEST_MA_THUOC", "TEST0001"),
        "biet_duoc": "Paracetamol", "don_vi_tinh": "viên", "quantity": 10.0,
        "dosage_instructions": "Uống 1 viên x 3 lần/ngày (TEST)",
    }]
    patient = {
        "full_name": "NGUYEN VAN TEST", "dob": "1990-05-01T00:00:00", "gender": "male",
        "phone": "0900000000", "address": "Địa chỉ thử nghiệm",
    }
    return rx, items, patient


def show(label: str, res) -> None:
    print(f"\n── {label}: HTTP {res.status or 'KHÔNG KẾT NỐI'} {'OK' if res.ok else 'LỖI'}")
    for e in res.errors:
        print("   •", e)
    if res.ok and res.data is not None:
        keys = list(res.data) if isinstance(res.data, dict) else res.data
        print("   phản hồi:", keys)


def cmd_login(a, client: DtqgClient) -> int:
    e = need("DTQG_FACILITY_CODE", "DTQG_FACILITY_PASS", "DTQG_DOCTOR_CODE", "DTQG_DOCTOR_PASS")
    fac = client.login_facility(e["DTQG_FACILITY_CODE"], e["DTQG_FACILITY_PASS"])
    show("Đăng nhập cơ sở (mục III)", fac)
    if not fac.ok:
        return 1
    print("   khóa trong phản hồi:", sorted(fac.data) if isinstance(fac.data, dict) else fac.data)
    tok = fac.data.get("token")
    add = client.add_doctor(tok, e["DTQG_DOCTOR_CODE"])
    show("Thêm bác sĩ (mục IV) — 422 'đã tồn tại' là bình thường", add)
    doc = client.login_doctor(e["DTQG_DOCTOR_CODE"], e["DTQG_FACILITY_CODE"], e["DTQG_DOCTOR_PASS"])
    show("Đăng nhập bác sĩ (mục VI)", doc)
    if doc.ok:
        print("   khóa trong phản hồi:", sorted(doc.data) if isinstance(doc.data, dict) else doc.data,
              "(PDF ghi 'tocken_type' ở mục VI)")
    return 0 if doc.ok else 1


def variants(body: dict) -> list[tuple[str, dict]]:
    """Các cách ghi khác nhau cho những điểm tài liệu mâu thuẫn."""
    out = [("mặc định (ma_benh/ten_benh, ma_so_bao_hiem_y_te)", body)]
    b = copy.deepcopy(body)
    b["chan_doan"] = [{"ma_chan_doan": d["ma_benh"], "ten_chan_doan": d["ten_benh"], "ket_luan": d["ket_luan"]}
                      for d in body["chan_doan"]]
    out.append(("chẩn đoán kiểu ví dụ (ma_chan_doan/ten_chan_doan)", b))
    b = copy.deepcopy(body)
    if "ma_so_bao_hiem_y_te" in b:
        b["ma_so_the_bao_hiem_y_te"] = b.pop("ma_so_bao_hiem_y_te")
    out.append(("khóa BHYT kiểu ví dụ (ma_so_the_bao_hiem_y_te)", b))
    return out


def cmd_send(a, client: DtqgClient) -> int:
    e = need("DTQG_FACILITY_CODE", "DTQG_FACILITY_PASS", "DTQG_DOCTOR_CODE", "DTQG_DOCTOR_PASS")
    if not a.yes:
        sys.exit("Lệnh này TẠO ĐƠN THẬT trên " + client.api_base + ". Thêm --yes nếu đây là môi trường test.")
    fac = client.login_facility(e["DTQG_FACILITY_CODE"], e["DTQG_FACILITY_PASS"])
    show("Đăng nhập cơ sở", fac)
    if not fac.ok:
        return 1
    show("Thêm bác sĩ (422 đã tồn tại là bình thường)", client.add_doctor(fac.data["token"], e["DTQG_DOCTOR_CODE"]))
    doc = client.login_doctor(e["DTQG_DOCTOR_CODE"], e["DTQG_FACILITY_CODE"], e["DTQG_DOCTOR_PASS"])
    show("Đăng nhập bác sĩ", doc)
    if not doc.ok:
        return 1
    token = doc.data["token"]

    n_variants = len(variants({"chan_doan": [], "ma_so_bao_hiem_y_te": None})) if a.variants else 1
    code = 0
    for i in range(n_variants):
        rx, items, patient = sample_rx(e["DTQG_FACILITY_CODE"])  # mỗi lần một mã đơn mới
        body = payload.build_body(rx, items, patient)
        errs = payload.validate_body(body)   # kiểm tra bản mặc định trước khi đổi tên khóa
        if errs:
            print("Dữ liệu mẫu không qua kiểm tra nội bộ:", errs)
            return 2
        label, body = variants(body)[i]
        res = client.send_prescription(token, body)
        show(f"Gửi đơn [{label}] mã {body['ma_don_thuoc']}", res)
        if res.ok:
            print("   → biến thể này ĐƯỢC CHẤP NHẬN. Ghi lại để chốt KEYS trong dtqg_payload.py.")
            if env("DTQG_APP_NAME") and env("DTQG_APP_KEY"):
                got = client.pos_get_prescription(env("DTQG_APP_NAME"), env("DTQG_APP_KEY"), body["ma_don_thuoc"])
                show("Tra lại đơn vừa gửi (mục VIII)", got)
                if got.ok and isinstance(got.data, dict):
                    print("   chẩn đoán trả về:", got.data.get("chan_doan"))
                    print("   ngày giờ kê đơn trả về:", got.data.get("ngay_gio_ke_don"), "(đã gửi:", body["ngay_gio_ke_don"] + ")")
        else:
            code = 1
    return code


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["login", "send"])
    ap.add_argument("--variants", action="store_true", help="thử nhiều biến thể tên khóa (tạo nhiều đơn test)")
    ap.add_argument("--yes", action="store_true", help="xác nhận đang trỏ vào môi trường TEST")
    a = ap.parse_args()
    client = DtqgClient(
        env("DTQG_API_BASE", env("IZIIAPP_DTQG_API_BASE", "https://api.donthuocquocgia.vn")),
        env("DTQG_WEB_BASE", env("IZIIAPP_DTQG_WEB_BASE", "https://www.donthuocquocgia.vn")),
    )
    try:
        return cmd_login(a, client) if a.command == "login" else cmd_send(a, client)
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
