# server/dtqg_client.py
"""
Client HTTP mỏng cho Hệ thống Đơn thuốc quốc gia (QĐ 808/QĐ-BYT, mục III–IX).

Chỉ làm đúng một việc: gọi API và chuẩn hoá kết quả thành DtqgResult. KHÔNG giữ
trạng thái (token, mật khẩu) — việc đó thuộc dtqg_service.py. Không ghi log
mật khẩu/token.

Hai máy chủ khác nhau theo đặc tả:
  api_base : đăng nhập, thêm/xóa bác sĩ, gửi đơn      (api.donthuocquocgia.vn)
  web_base : nhà thuốc lấy đơn / cập nhật số lượng bán (www.donthuocquocgia.vn)
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

import httpx


@dataclass
class DtqgResult:
    ok: bool
    status: int = 0                       # 0 = lỗi mạng/timeout (chưa có phản hồi)
    data: Any = None
    errors: List[str] = field(default_factory=list)   # danh_sach_cac_loi nguyên văn

    @property
    def network_error(self) -> bool:
        return self.status == 0

    @property
    def unauthorized(self) -> bool:
        return self.status == 401


def _flatten_errors(data: Any) -> List[str]:
    """danh_sach_cac_loi có thể là list chuỗi, dict {trường: [lỗi]} hoặc chuỗi."""
    if not isinstance(data, dict):
        return [str(data)] if data else []
    raw = data.get("danh_sach_cac_loi", data.get("errors", data.get("message")))
    out: List[str] = []

    def walk(v: Any) -> None:
        if v is None:
            return
        if isinstance(v, str):
            out.append(v)
        elif isinstance(v, dict):
            for k, x in v.items():
                walk(x)
        elif isinstance(v, (list, tuple)):
            for x in v:
                walk(x)
        else:
            out.append(str(v))

    walk(raw)
    return out


class DtqgClient:
    def __init__(
        self,
        api_base: str,
        web_base: Optional[str] = None,
        timeout: float = 20.0,
        transport: Optional[httpx.BaseTransport] = None,
    ):
        self.api_base = api_base.rstrip("/")
        self.web_base = (web_base or api_base).rstrip("/")
        self._http = httpx.Client(timeout=timeout, transport=transport)

    def close(self) -> None:
        self._http.close()

    # ── nền tảng ────────────────────────────────────────────────────────────

    def _call(
        self,
        method: str,
        url: str,
        json_body: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
    ) -> DtqgResult:
        h = {"Accept": "application/json", "Content-Type": "application/json"}
        h.update(headers or {})
        try:
            r = self._http.request(method, url, json=json_body, headers=h)
        except (httpx.TimeoutException, httpx.TransportError) as e:
            return DtqgResult(False, 0, None, [f"Lỗi kết nối: {type(e).__name__}"])
        try:
            data = r.json()
        except ValueError:
            data = r.text or None
        if 200 <= r.status_code < 300:
            return DtqgResult(True, r.status_code, data, [])
        errors = _flatten_errors(data)
        if not errors:
            errors = [f"HTTP {r.status_code}"]
        return DtqgResult(False, r.status_code, data, errors)

    @staticmethod
    def _bearer(token: str) -> Dict[str, str]:
        return {"Authorization": f"bearer {token}"}

    # ── HIS: phòng khám kê đơn ──────────────────────────────────────────────

    def login_facility(self, ma_lien_thong_co_so: str, password: str) -> DtqgResult:
        """Mục III. Token hiệu lực 7 ngày."""
        return self._call(
            "POST", f"{self.api_base}/api/auth/dang-nhap-co-so-kham-chua-benh",
            {"ma_lien_thong_co_so_kham_chua_benh": ma_lien_thong_co_so, "password": password},
        )

    def add_doctor(self, facility_token: str, ma_lien_thong_bac_si: str) -> DtqgResult:
        """Mục IV."""
        return self._call(
            "POST", f"{self.api_base}/api/v1/them-bac-si",
            {"ma_lien_thong_bac_si": ma_lien_thong_bac_si}, self._bearer(facility_token),
        )

    def remove_doctor(self, facility_token: str, ma_lien_thong_bac_si: str) -> DtqgResult:
        """Mục V."""
        return self._call(
            "POST", f"{self.api_base}/api/v1/xoa-bac-si",
            {"ma_lien_thong_bac_si": ma_lien_thong_bac_si}, self._bearer(facility_token),
        )

    def login_doctor(self, ma_lien_thong_bac_si: str, ma_lien_thong_co_so: str, password: str) -> DtqgResult:
        """Mục VI. Bác sĩ phải đã được thêm vào cơ sở, nếu không trả 422."""
        return self._call(
            "POST", f"{self.api_base}/api/auth/dang-nhap-bac-si",
            {
                "ma_lien_thong_bac_si": ma_lien_thong_bac_si,
                "ma_lien_thong_co_so_kham_chua_benh": ma_lien_thong_co_so,
                "password": password,
            },
        )

    def send_prescription(self, doctor_token: str, body: Dict[str, Any]) -> DtqgResult:
        """Mục VII."""
        return self._call(
            "POST", f"{self.api_base}/api/v1/gui-don-thuoc", body, self._bearer(doctor_token),
        )

    # ── POS: nhà thuốc bán theo đơn ─────────────────────────────────────────

    @staticmethod
    def _app_headers(app_name: str, app_key: str) -> Dict[str, str]:
        return {"app-name": app_name, "app-key": app_key}

    def pos_get_prescription(self, app_name: str, app_key: str, ma_don_thuoc: str) -> DtqgResult:
        """Mục VIII. 404 = không tìm thấy đơn."""
        return self._call(
            "GET", f"{self.web_base}/api/v1/thong-tin-don-thuoc/{ma_don_thuoc}",
            None, self._app_headers(app_name, app_key),
        )

    def pos_update_sold(self, app_name: str, app_key: str, body: Dict[str, Any]) -> DtqgResult:
        """Mục IX."""
        return self._call(
            "POST", f"{self.web_base}/api/v1/cap-nhat-don-thuoc",
            body, self._app_headers(app_name, app_key),
        )
