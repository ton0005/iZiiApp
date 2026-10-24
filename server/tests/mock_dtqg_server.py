# server/tests/mock_dtqg_server.py
"""
Mock Hệ thống Đơn thuốc quốc gia dựng THEO ĐẶC TẢ quyet-dinh-808.pdf (mục III–IX).

KHÔNG phải hệ thống thật: hành vi nào PDF không nêu (mã lỗi 401 khi token hết hạn,
nội dung câu báo lỗi, ràng buộc phụ) là GIẢ ĐỊNH và được đánh dấu "GIẢ ĐỊNH".
Mục đích: kiểm thử luồng gọi và xử lý lỗi của DtqgGateway trước khi có tài khoản
test thật; PHẢI chạy lại trên môi trường test thật của donthuocquocgia.vn.

Dùng:
  - test:        MockDtqg().transport()  → truyền vào DtqgClient(transport=...)
  - chạy tay:    python -m tests.mock_dtqg_server  (cổng 9099), rồi đặt
                 IZIIAPP_DTQG_API_BASE=IZIIAPP_DTQG_WEB_BASE=http://127.0.0.1:9099
"""
from __future__ import annotations

import json
import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

VN_TZ = timezone(timedelta(hours=7))
TOKEN_TTL = timedelta(days=7)

Resp = Tuple[int, Any]


def _errs(*msgs: str) -> Dict[str, Any]:
    return {"danh_sach_cac_loi": list(msgs)}


class MockDtqg:
    def __init__(self, strict_keys: bool = False):
        # cơ sở: mã liên thông → mật khẩu;  bác sĩ: mã liên thông → mật khẩu
        self.facilities: Dict[str, str] = {}
        self.doctors: Dict[str, str] = {}
        self.facility_doctors: Dict[str, set] = {}      # cơ sở → tập bác sĩ đã thêm
        self.tokens: Dict[str, Dict[str, Any]] = {}     # token → {type, subject, facility, expires}
        self.prescriptions: Dict[str, Dict[str, Any]] = {}
        self.sales: List[Dict[str, Any]] = []
        self.pos_apps: Dict[str, str] = {}              # app-name → app-key
        self.calls: List[Tuple[str, str]] = []          # (method, path) theo thứ tự — để assert luồng
        self.now = lambda: datetime.now(timezone.utc)
        # Mô phỏng sự cố
        self.fail_next: List[Tuple[int, Any]] = []      # trả lỗi cho các request tiếp theo
        self.drop_next: int = 0                         # số request tiếp theo bị "đứt mạng"
        self.strict_keys = strict_keys

    # ── cấu hình ────────────────────────────────────────────────────────────
    def add_facility(self, code: str, password: str) -> None:
        self.facilities[code] = password
        self.facility_doctors.setdefault(code, set())

    def add_doctor_account(self, code: str, password: str) -> None:
        self.doctors[code] = password

    def add_pos_app(self, name: str, key: str) -> None:
        self.pos_apps[name] = key

    def expire_all_tokens(self) -> None:
        self.tokens.clear()

    def count(self, path_suffix: str) -> int:
        return sum(1 for _, p in self.calls if p.endswith(path_suffix))

    # ── điều phối ───────────────────────────────────────────────────────────
    def transport(self) -> httpx.MockTransport:
        def handler(req: httpx.Request) -> httpx.Response:
            if self.drop_next > 0:
                self.drop_next -= 1
                raise httpx.ConnectError("mock: mất kết nối", request=req)
            body = None
            if req.content:
                try:
                    body = json.loads(req.content)
                except ValueError:
                    body = None
            status, data = self.handle(req.method, req.url.path, dict(req.headers), body)
            return httpx.Response(status, json=data)

        return httpx.MockTransport(handler)

    def handle(self, method: str, path: str, headers: Dict[str, str], body: Optional[Dict[str, Any]]) -> Resp:
        self.calls.append((method, path))
        if self.fail_next:
            return self.fail_next.pop(0)
        h = {k.lower(): v for k, v in headers.items()}
        body = body or {}
        routes = {
            ("POST", "/api/auth/dang-nhap-co-so-kham-chua-benh"): lambda: self._login_facility(body),
            ("POST", "/api/auth/dang-nhap-bac-si"): lambda: self._login_doctor(body),
            ("POST", "/api/v1/them-bac-si"): lambda: self._add_doctor(h, body),
            ("POST", "/api/v1/xoa-bac-si"): lambda: self._remove_doctor(h, body),
            ("POST", "/api/v1/gui-don-thuoc"): lambda: self._gui_don(h, body),
            ("POST", "/api/v1/cap-nhat-don-thuoc"): lambda: self._cap_nhat(h, body),
        }
        fn = routes.get((method, path))
        if fn:
            return fn()
        m = re.fullmatch(r"/api/v1/thong-tin-don-thuoc/([^/]+)", path)
        if method == "GET" and m:
            return self._lay_don(h, m.group(1))
        return 404, {"message": "Not Found"}

    # ── xác thực ────────────────────────────────────────────────────────────
    def _issue(self, kind: str, subject: str, facility: str) -> str:
        t = secrets.token_hex(16)
        self.tokens[t] = {"type": kind, "subject": subject, "facility": facility,
                          "expires": self.now() + TOKEN_TTL}
        return t

    def _auth(self, h: Dict[str, str], kind: str) -> Tuple[Optional[Dict[str, Any]], Optional[Resp]]:
        a = h.get("authorization", "")
        if not a.lower().startswith("bearer "):
            return None, (401, {"message": "Unauthenticated."})           # GIẢ ĐỊNH: 401
        t = self.tokens.get(a[7:].strip())
        if not t or t["expires"] <= self.now() or t["type"] != kind:
            return None, (401, {"message": "Unauthenticated."})           # GIẢ ĐỊNH: 401
        return t, None

    def _login_facility(self, b: Dict[str, Any]) -> Resp:
        code, pw = b.get("ma_lien_thong_co_so_kham_chua_benh"), b.get("password")
        if not code or not pw or self.facilities.get(code) != pw:
            return 422, _errs("Mã liên thông cơ sở khám chữa bệnh hoặc mật khẩu không đúng")
        return 200, {"token": self._issue("facility", code, code), "token_type": "bearer"}

    def _login_doctor(self, b: Dict[str, Any]) -> Resp:
        d, f, pw = (b.get("ma_lien_thong_bac_si"), b.get("ma_lien_thong_co_so_kham_chua_benh"), b.get("password"))
        if not d or not f or not pw:
            return 422, _errs("Thiếu thông tin đăng nhập")
        if d not in self.facility_doctors.get(f, set()):
            return 422, _errs("Bác sĩ chưa được thêm vào cơ sở khám chữa bệnh")
        if self.doctors.get(d) != pw:
            return 422, _errs("Mã liên thông hoặc mật khẩu không đúng")
        # Đúng như PDF: khóa là `tocken_type` (sai chính tả) ở mục VI.
        return 200, {"token": self._issue("doctor", d, f), "tocken_type": "bearer"}

    def _add_doctor(self, h: Dict[str, str], b: Dict[str, Any]) -> Resp:
        t, err = self._auth(h, "facility")
        if err:
            return err
        d = b.get("ma_lien_thong_bac_si")
        if not d:
            return 422, _errs("Thiếu ma_lien_thong_bac_si")
        if d not in self.doctors:
            return 422, _errs("Mã liên thông bác sĩ không tồn tại")
        s = self.facility_doctors.setdefault(t["facility"], set())
        if d in s:
            return 422, _errs("Bác sĩ đã tồn tại trong cơ sở khám chữa bệnh")
        s.add(d)
        return 200, {"success": "Bạn đã thêm bác sĩ thành công"}

    def _remove_doctor(self, h: Dict[str, str], b: Dict[str, Any]) -> Resp:
        t, err = self._auth(h, "facility")
        if err:
            return err
        s = self.facility_doctors.setdefault(t["facility"], set())
        d = b.get("ma_lien_thong_bac_si")
        if d not in s:
            return 422, _errs("Bác sĩ không thuộc cơ sở khám chữa bệnh")
        s.discard(d)
        return 200, {"success": "Bạn đã xóa bác sĩ khỏi cơ sở khám chữa bệnh thành công"}

    # ── gửi đơn (mục VII) ───────────────────────────────────────────────────
    def _validate_don(self, b: Dict[str, Any], facility: str) -> List[str]:
        e: List[str] = []

        def req(key: str, limit: Optional[int] = None) -> None:
            v = b.get(key)
            if v is None or str(v).strip() == "":
                e.append(f"Thiếu trường {key}")
            elif limit and len(str(v)) > limit:
                e.append(f"{key} tối đa {limit} ký tự")

        loai = str(b.get("loai_don_thuoc", "")).lower()
        if loai not in ("c", "h", "n", "y"):
            e.append("loai_don_thuoc phải là c, h, n hoặc y")
        ma = str(b.get("ma_don_thuoc", ""))
        if not re.fullmatch(r"[0-9a-zA-Z]{12}-[cChHnNyY]", ma):
            e.append("ma_don_thuoc phải gồm 14 ký tự xxxxxyyyyyyy-z")
        elif ma[:5].lower() != facility[2:].lower():
            e.append("ma_don_thuoc: 5 ký tự đầu phải là mã cơ sở khám chữa bệnh")   # GIẢ ĐỊNH
        elif ma[-1].lower() != loai:
            e.append("Hậu tố mã đơn không khớp loai_don_thuoc")
        elif ma in self.prescriptions:
            e.append("Mã đơn thuốc đã tồn tại")                                      # GIẢ ĐỊNH (mã phải duy nhất)
        req("ho_ten_benh_nhan", 500)
        dob = b.get("ngay_sinh_benh_nhan")
        try:
            dob_d = datetime.strptime(str(dob), "%d/%m/%Y")
        except ValueError:
            dob_d = None
            e.append("ngay_sinh_benh_nhan phải có dạng d/m/Y")
        if b.get("ma_dinh_danh_y_te") and len(str(b["ma_dinh_danh_y_te"])) > 10:
            e.append("ma_dinh_danh_y_te tối đa 10 ký tự")
        cccd = b.get("ma_dinh_danh_cong_dan")
        if cccd and not re.fullmatch(r"\d{12}", str(cccd)):
            e.append("ma_dinh_danh_cong_dan phải gồm 12 chữ số")
        if b.get("gioi_tinh") not in (1, 2, 3):
            e.append("gioi_tinh phải là 1, 2 hoặc 3")
        for k in ("ma_so_bao_hiem_y_te", "ma_so_the_bao_hiem_y_te"):
            if b.get(k) and len(str(b[k])) > 10:
                e.append(f"{k} tối đa 10 ký tự")
        req("dia_chi", 500)
        cd = b.get("chan_doan")
        if not isinstance(cd, list) or not cd:
            e.append("Thiếu chan_doan")
        elif self.strict_keys and any("ma_benh" not in d or "ten_benh" not in d for d in cd):
            e.append("chan_doan cần ma_benh và ten_benh")
        elif not self.strict_keys and any(
            not (d.get("ma_benh") or d.get("ma_chan_doan")) or not (d.get("ten_benh") or d.get("ten_chan_doan"))
            for d in cd
        ):
            e.append("chan_doan cần mã và tên bệnh")
        if loai == "c" and b.get("hinh_thuc_dieu_tri") in (None, ""):
            e.append("hinh_thuc_dieu_tri bắt buộc với đơn thuốc cơ bản")
        if loai in ("h", "n", "y") and not b.get("dot_dung_thuoc"):
            e.append("dot_dung_thuoc bắt buộc với đơn h, n, y")
        if b.get("luu_y") and len(str(b["luu_y"])) > 2000:
            e.append("luu_y tối đa 2000 ký tự")
        if b.get("loi_dan") and len(str(b["loi_dan"])) > 2000:
            e.append("loi_dan tối đa 2000 ký tự")
        phone = b.get("so_dien_thoai_nguoi_kham_benh")
        if phone and not re.fullmatch(r"\d{1,12}", str(phone)):
            e.append("so_dien_thoai_nguoi_kham_benh chỉ gồm chữ số, tối đa 12")
        if dob_d:
            months = (datetime.now().year - dob_d.year) * 12 + datetime.now().month - dob_d.month
            if months < 72 and not b.get("thong_tin_nguoi_giam_ho"):
                e.append("thong_tin_nguoi_giam_ho bắt buộc với trẻ dưới 72 tháng tuổi")
        try:
            datetime.strptime(str(b.get("ngay_gio_ke_don")), "%Y-%m-%d %H:%M:%S")
        except ValueError:
            e.append("ngay_gio_ke_don phải có dạng Y-m-d H:i:s")
        lines = b.get("thong_tin_don_thuoc")
        if not isinstance(lines, list) or not lines:
            e.append("Thiếu thong_tin_don_thuoc")
        else:
            for i, ln in enumerate(lines, 1):
                for k, lim in (("ma_thuoc", 20), ("biet_duoc", 500), ("ten_thuoc", 500),
                               ("don_vi_tinh", 500), ("cach_dung", 500)):
                    v = ln.get(k)
                    if v is None or str(v).strip() == "":
                        e.append(f"Thuốc #{i}: thiếu {k}")
                    elif len(str(v)) > lim:
                        e.append(f"Thuốc #{i}: {k} tối đa {lim} ký tự")
                if not isinstance(ln.get("so_luong"), (int, float)):
                    e.append(f"Thuốc #{i}: so_luong phải là số")
        return e

    def _gui_don(self, h: Dict[str, str], b: Dict[str, Any]) -> Resp:
        t, err = self._auth(h, "doctor")
        if err:
            return err
        if t["subject"] not in self.facility_doctors.get(t["facility"], set()):
            return 422, _errs("Bác sĩ không thuộc cơ sở khám chữa bệnh")
        errors = self._validate_don(b, t["facility"])
        if errors:
            return 422, _errs(*errors)
        self.prescriptions[b["ma_don_thuoc"]] = {
            "body": b, "doctor": t["subject"], "facility": t["facility"], "sold": {},
        }
        return 200, {"success": "Gửi đơn thuốc thành công"}

    # ── POS (mục VIII–IX) ───────────────────────────────────────────────────
    def _pos_auth(self, h: Dict[str, str]) -> Optional[Resp]:
        name, key = h.get("app-name"), h.get("app-key")
        if not name or self.pos_apps.get(name) != key:
            return 401, {"message": "Unauthenticated."}                   # GIẢ ĐỊNH
        return None

    def _lay_don(self, h: Dict[str, str], ma: str) -> Resp:
        err = self._pos_auth(h)
        if err:
            return err
        rec = self.prescriptions.get(ma)
        if not rec:
            return 404, _errs("Không tìm thấy đơn thuốc")
        b = rec["body"]
        return 200, {
            "ma_don_thuoc": ma,
            "ho_ten_benh_nhan": b["ho_ten_benh_nhan"],
            "ngay_sinh_benh_nhan": b["ngay_sinh_benh_nhan"],
            "ma_dinh_danh_y_te": b.get("ma_dinh_danh_y_te"),
            "loai_don_thuoc": b["loai_don_thuoc"],
            "hinh_thuc_dieu_tri": b.get("hinh_thuc_dieu_tri"),
            "dia_chi": b["dia_chi"],
            "gioi_tinh": b["gioi_tinh"],
            "can_nang": b.get("can_nang"),
            "ma_so_the_bao_hiem_y_te": b.get("ma_so_bao_hiem_y_te") or b.get("ma_so_the_bao_hiem_y_te"),
            "thong_tin_don_thuoc": b["thong_tin_don_thuoc"],
            "dot_dung_thuoc": b.get("dot_dung_thuoc"),
            "chan_doan": b["chan_doan"],
            "luu_y": b.get("luu_y"),
            "loi_dan": b.get("loi_dan"),
            "ten_bac_si": f"BS {rec['doctor']}",
            "ten_co_so_kham_chua_benh": f"Cơ sở {rec['facility']}",
            "so_dien_thoai_co_so_kham_chua_benh": "0280000000",
            "ngay_gio_ke_don": b["ngay_gio_ke_don"],
        }

    def _cap_nhat(self, h: Dict[str, str], b: Dict[str, Any]) -> Resp:
        err = self._pos_auth(h)
        if err:
            return err
        ma = b.get("ma_don_thuoc")
        rec = self.prescriptions.get(ma)
        if not rec:
            return 404, _errs("Không tìm thấy đơn thuốc")
        e: List[str] = []
        for k, lim in (("ma_dinh_danh_co_so_cung_ung_thuoc", 200), ("ten_co_so_cung_ung_thuoc", 2000),
                       ("dia_chi_co_so_cung_ung_thuoc", 2000), ("ma_hoa_don", 20)):
            v = b.get(k)
            if v is None or str(v).strip() == "":
                e.append(f"Thiếu trường {k}")
            elif len(str(v)) > lim:
                e.append(f"{k} tối đa {lim} ký tự")
        if not re.fullmatch(r"\d{1,12}", str(b.get("so_dien_thoai_co_so_cung_ung_thuoc") or "")):
            e.append("so_dien_thoai_co_so_cung_ung_thuoc phải là chuỗi số tối đa 12")
        lines = b.get("thong_tin_thuoc")
        prescribed = {ln["ma_thuoc"]: ln for ln in rec["body"]["thong_tin_don_thuoc"]}
        if not isinstance(lines, list) or not lines:
            e.append("Thiếu thong_tin_thuoc")
        else:
            for i, ln in enumerate(lines, 1):
                for k, lim in (("ma_thuoc_da_ke_don", 20), ("ma_thuoc", 20), ("biet_duoc", 200),
                               ("ten_thuoc", 200), ("don_vi_tinh", 200), ("cach_dung", 200)):
                    v = ln.get(k)
                    if v is None or str(v).strip() == "":
                        e.append(f"Thuốc #{i}: thiếu {k}")
                    elif len(str(v)) > lim:
                        e.append(f"Thuốc #{i}: {k} tối đa {lim} ký tự")
                for k in ("so_luong", "so_luong_ban"):
                    if not isinstance(ln.get(k), (int, float)):
                        e.append(f"Thuốc #{i}: {k} phải là số")
                orig = prescribed.get(ln.get("ma_thuoc_da_ke_don"))
                if orig is None:
                    e.append(f"Thuốc #{i}: ma_thuoc_da_ke_don không có trong đơn")
                elif isinstance(ln.get("so_luong_ban"), (int, float)):
                    already = rec["sold"].get(ln["ma_thuoc_da_ke_don"], 0)
                    if already + ln["so_luong_ban"] > orig["so_luong"]:                # GIẢ ĐỊNH: không bán quá số kê
                        e.append(f"Thuốc #{i}: số lượng bán vượt số lượng kê đơn")
        if e:
            return 422, _errs(*e)
        for ln in lines:
            k = ln["ma_thuoc_da_ke_don"]
            rec["sold"][k] = rec["sold"].get(k, 0) + ln["so_luong_ban"]
        self.sales.append(b)
        return 200, "Cập nhật đơn thuốc đã bán thành công"


def make_app(mock: Optional[MockDtqg] = None):
    """ASGI app để chạy tay bằng uvicorn (đặt cả API_BASE và WEB_BASE về cùng địa chỉ)."""
    mock = mock or MockDtqg()
    mock.add_facility("0101aaa", "co-so-pass")
    mock.add_doctor_account("0100123AG-CCHN", "bac-si-pass")
    mock.add_pos_app("izii", "izii-key")
    app = FastAPI(title="Mock Đơn thuốc quốc gia")

    @app.api_route("/{path:path}", methods=["GET", "POST"])
    async def any_route(path: str, request: Request):
        try:
            body = await request.json()
        except ValueError:
            body = None
        status, data = mock.handle(request.method, "/" + path, dict(request.headers), body)
        return JSONResponse(data, status_code=status)

    return app


if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    uvicorn.run(make_app(), host="127.0.0.1", port=9099)
