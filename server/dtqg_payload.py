# server/dtqg_payload.py
"""
Dựng và kiểm tra body `POST /api/v1/gui-don-thuoc` (QĐ 808/QĐ-BYT, mục VII)
từ dữ liệu đã đồng bộ (mutation log). Phản chiếu DtqgRules (Dart) — hai nơi
phải cho cùng kết quả; tên khóa còn mâu thuẫn trong tài liệu nằm ở KEYS bên dưới.

Chỉ hỗ trợ đơn loại 'c' (thông thường) ở giai đoạn hiện tại; các loại khác bị
từ chối trước khi gọi mạng.
"""
from __future__ import annotations

import json
import re
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

# Múi giờ Việt Nam (không phụ thuộc tzdata của hệ điều hành).
VN_TZ = timezone(timedelta(hours=7))

# Các điểm tài liệu còn mâu thuẫn (plan 03, mục 9) — đổi ở đây khi xác nhận xong.
KEYS = {
    "chan_doan_ma": "ma_benh",       # bảng: ma_benh/ten_benh — ví dụ: ma_chan_doan/ten_chan_doan
    "chan_doan_ten": "ten_benh",
    "bhyt": "ma_so_bao_hiem_y_te",   # bảng — ví dụ: ma_so_the_bao_hiem_y_te
}
# Tài liệu ghi 'Y-m-d H:m:s' (m = tháng trong PHP) → dùng phút.
DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S"

_MA_DON_RE = re.compile(r"^[0-9a-z]{12}-[chny]$")


def is_valid_ma_don(s: Optional[str]) -> bool:
    return bool(s) and bool(_MA_DON_RE.match(s))


def map_gender(g: Optional[str]) -> int:
    """1 chưa có thông tin, 2 Nam, 3 Nữ."""
    return {"male": 2, "female": 3}.get(g or "", 1)


def _parse_dt(v: Any) -> Optional[datetime]:
    try:
        d = datetime.fromisoformat(str(v))
    except (TypeError, ValueError):
        return None
    return d if d.tzinfo else d.replace(tzinfo=VN_TZ)


def format_date(v: Any) -> Optional[str]:
    """`d/m/Y`. Ngày sinh lấy phần ngày theo giờ ghi trên máy, không đổi múi giờ."""
    d = _parse_dt(v)
    return None if d is None else f"{d.day:02d}/{d.month:02d}/{d.year}"


def format_datetime(v: Any) -> Optional[str]:
    d = _parse_dt(v)
    return None if d is None else d.astimezone(VN_TZ).strftime(DATETIME_FORMAT)


def age_months(dob: Optional[datetime], now: Optional[datetime] = None) -> Optional[int]:
    if dob is None:
        return None
    n = now or datetime.now(VN_TZ)
    m = (n.year - dob.year) * 12 + n.month - dob.month
    if n.day < dob.day:
        m -= 1
    return max(m, 0)


def _s(v: Any) -> str:
    return "" if v is None else str(v).strip()


def _nz(v: Any) -> Optional[str]:
    t = _s(v)
    return t or None


def _json_list(raw: Any) -> List[Dict[str, Any]]:
    if isinstance(raw, list):
        return raw
    try:
        v = json.loads(raw or "[]")
        return v if isinstance(v, list) else []
    except (TypeError, ValueError):
        return []


def build_body(rx: Dict[str, Any], items: List[Dict[str, Any]], patient: Dict[str, Any]) -> Dict[str, Any]:
    diagnoses = _json_list(rx.get("chan_doan_json") if "chan_doan_json" in rx else rx.get("chan_doan"))
    return {
        "loai_don_thuoc": _s(rx.get("loai_don") or "c").lower(),
        "ma_don_thuoc": _s(rx.get("ma_don_thuoc")),
        "ho_ten_benh_nhan": _s(patient.get("full_name")),
        "ngay_sinh_benh_nhan": format_date(patient.get("dob")),
        "ma_dinh_danh_y_te": _nz(patient.get("ma_dinh_danh_y_te")),
        "ma_dinh_danh_cong_dan": _nz(patient.get("so_cccd")),
        "can_nang": rx.get("can_nang"),
        "gioi_tinh": map_gender(patient.get("gender")),
        KEYS["bhyt"]: _nz(patient.get("ma_the_bhyt")),
        "thong_tin_nguoi_giam_ho": _nz(rx.get("nguoi_giam_ho")),
        "dia_chi": _s(patient.get("address")),
        "chan_doan": [
            {
                KEYS["chan_doan_ma"]: _s(d.get("ma_benh")),
                KEYS["chan_doan_ten"]: _s(d.get("ten_benh")),
                "ket_luan": _s(d.get("ket_luan")),
            }
            for d in diagnoses
        ],
        "luu_y": _nz(rx.get("notes")),
        "hinh_thuc_dieu_tri": rx.get("hinh_thuc_dieu_tri"),
        "thong_tin_don_thuoc": [
            {
                "ma_thuoc": _s(it.get("ma_thuoc_cuc_qldd")),
                "biet_duoc": _s(it.get("biet_duoc")),
                "ten_thuoc": _s(it.get("medicine_name")),
                "don_vi_tinh": _s(it.get("don_vi_tinh")),
                "so_luong": it.get("quantity"),
                "cach_dung": _s(it.get("dosage_instructions")),
            }
            for it in items
        ],
        "loi_dan": _nz(rx.get("loi_dan")),
        "so_dien_thoai_nguoi_kham_benh": _nz(patient.get("phone")),
        "ngay_tai_kham": rx.get("ngay_tai_kham"),
        "ngay_gio_ke_don": format_datetime(rx.get("prescription_date") or rx.get("created_at")),
        "signature": None,  # chưa triển khai (FAQ 1.6, 1.22)
    }


def _dmy(v: Optional[str]) -> Optional[datetime]:
    try:
        return datetime.strptime(v or "", "%d/%m/%Y").replace(tzinfo=VN_TZ)
    except ValueError:
        return None


def validate_body(body: Dict[str, Any], now: Optional[datetime] = None) -> List[str]:
    """Kiểm tra theo bảng dữ liệu đầu vào mục VII. Trả danh sách lỗi (rỗng = hợp lệ)."""
    e: List[str] = []
    if body.get("loai_don_thuoc") != "c":
        e.append("Chỉ hỗ trợ đơn thuốc loại 'c' (thông thường)")
    if not is_valid_ma_don(body.get("ma_don_thuoc")):
        e.append("Mã đơn thuốc không đúng định dạng xxxxxyyyyyyy-c (14 ký tự)")
    elif not str(body["ma_don_thuoc"]).endswith("-" + str(body["loai_don_thuoc"])):
        e.append("Hậu tố mã đơn thuốc không khớp loại đơn")
    name = _s(body.get("ho_ten_benh_nhan"))
    if not name:
        e.append("Thiếu họ tên bệnh nhân")
    elif len(name) > 500:
        e.append("Họ tên bệnh nhân tối đa 500 ký tự")
    if not body.get("ngay_sinh_benh_nhan"):
        e.append("Thiếu ngày sinh bệnh nhân")
    if not _s(body.get("dia_chi")):
        e.append("Thiếu địa chỉ bệnh nhân")
    elif len(_s(body["dia_chi"])) > 500:
        e.append("Địa chỉ tối đa 500 ký tự")
    cccd = _s(body.get("ma_dinh_danh_cong_dan"))
    if cccd and not re.fullmatch(r"\d{12}", cccd):
        e.append("Mã định danh công dân phải đủ 12 chữ số")
    if len(_s(body.get("ma_dinh_danh_y_te"))) > 10:
        e.append("Mã định danh y tế tối đa 10 ký tự")
    phone = _s(body.get("so_dien_thoai_nguoi_kham_benh"))
    if not phone:
        e.append("Thiếu số điện thoại người khám bệnh")
    elif not re.fullmatch(r"\d{1,12}", phone):
        e.append("Số điện thoại chỉ gồm chữ số, tối đa 12")
    if not body.get("chan_doan") or any(
        not _s(d.get(KEYS["chan_doan_ma"])) or not _s(d.get(KEYS["chan_doan_ten"])) for d in body["chan_doan"]
    ):
        e.append("Cần ít nhất một chẩn đoán có mã và tên bệnh")
    if body.get("hinh_thuc_dieu_tri") is None:
        e.append("Đơn thông thường cần hình thức điều trị")
    if not body.get("ngay_gio_ke_don"):
        e.append("Thiếu ngày giờ kê đơn")
    for key, limit in (("luu_y", 2000), ("loi_dan", 2000), ("thong_tin_nguoi_giam_ho", 500)):
        if len(_s(body.get(key))) > limit:
            e.append(f"{key} tối đa {limit} ký tự")

    months = age_months(_dmy(body.get("ngay_sinh_benh_nhan")), now)
    if months is not None and months < 72:
        if not body.get("can_nang"):
            e.append("Trẻ dưới 72 tháng tuổi: bắt buộc cân nặng")
        if not _s(body.get("thong_tin_nguoi_giam_ho")):
            e.append("Trẻ dưới 72 tháng tuổi: bắt buộc thông tin người giám hộ")

    lines = body.get("thong_tin_don_thuoc") or []
    if not lines:
        e.append("Đơn thuốc chưa có thuốc nào")
    for i, ln in enumerate(lines, 1):
        label = f"Thuốc #{i} ({_s(ln.get('ten_thuoc')) or '?'})"
        for key, limit in (("ma_thuoc", 20), ("biet_duoc", 500), ("ten_thuoc", 500),
                           ("don_vi_tinh", 500), ("cach_dung", 500)):
            v = _s(ln.get(key))
            if not v:
                e.append(f"{label}: thiếu {key}")
            elif len(v) > limit:
                e.append(f"{label}: {key} tối đa {limit} ký tự")
        q = ln.get("so_luong")
        if not isinstance(q, (int, float)) or q <= 0:
            e.append(f"{label}: so_luong phải là số lớn hơn 0")
    return e
