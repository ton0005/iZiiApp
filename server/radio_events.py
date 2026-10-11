# server/radio_events.py
"""
Chuẩn hoá sự kiện bộ đàm (Hytera DMR / TETRA) về một định dạng duy nhất.

VÌ SAO TÁCH RIÊNG MODULE NÀY: bộ đàm KHÔNG gọi thẳng được iZiiServer. Sự kiện
đi qua repeater (RD98X / HR1062) rồi tới một phần mềm điều phối hoặc gateway
(Hytera SmartDispatch, TRBOnet, gateway tự viết trên Hytera SDK, hoặc SwMI của
mạng TETRA cho PT580H). Mỗi gateway đặt tên trường và tên sự kiện một kiểu:
`radio_id` / `src_id` / `issi`, `EMERGENCY_ALARM` / `SOS` / `Alarm`... Gom toàn
bộ phần "phiên dịch" vào đây để router chỉ làm việc với một dạng chuẩn, và để
khi đổi gateway chỉ cần thêm alias chứ không phải sửa luồng cảnh báo.

Module này THUẦN (không đụng DB, không đụng FastAPI) để test được trực tiếp.
"""
from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional

# ── Loại sự kiện chuẩn ──────────────────────────────────────────────────────
SOS = "sos"                    # Nút Emergency trên thân máy
MAN_DOWN = "man_down"          # Cảm biến ngã / nghiêng / bất động
LONE_WORKER = "lone_worker"    # Hết Lone Worker Response Time + Reminder mà không bấm phím
EMERGENCY_CANCEL = "emergency_cancel"
LOCATION = "location"          # Báo vị trí GPS định kỳ
PRESENCE = "presence"          # Bật/tắt máy, đăng ký vào hệ thống
UNKNOWN = "unknown"

# Ba loại này là báo động tính mạng: phải bật cảnh báo trên iZiiApp.
ALARM_TYPES = frozenset({SOS, MAN_DOWN, LONE_WORKER})

# Khoá so khớp đã bỏ ký tự không phải chữ/số và viết hoa, nên "Man-Down",
# "man_down", "MAN DOWN" đều về "MANDOWN".
_EVENT_ALIASES: Dict[str, str] = {}
for _canonical, _aliases in {
    SOS: (
        "SOS", "EMERGENCY", "EMERGENCYALARM", "EMERGENCYCALL", "EMERGENCYALARMCALL",
        "ALARM", "PANIC", "PANICBUTTON", "EMERGENCYKEY",
    ),
    MAN_DOWN: (
        "MANDOWN", "MANDOWNALARM", "FALL", "FALLDETECTED", "FALLALARM", "TILT",
        "TILTALARM", "NOMOVEMENT", "NOMOTION", "STATIONARY", "MOTIONLESS",
    ),
    LONE_WORKER: (
        "LONEWORKER", "LONEWORKERTIMEOUT", "LONEWORKERALARM", "LONEWORKEREMERGENCY",
        "LWTIMEOUT", "ALONEWORKER", "ALONEWORKERTIMEOUT", "WORKALONE",
    ),
    EMERGENCY_CANCEL: (
        "EMERGENCYCANCEL", "EMERGENCYCANCELLED", "ALARMCANCEL", "CANCEL", "SOSCANCEL",
        "EMERGENCYEXIT", "EMERGENCYCLEAR", "EMERGENCYCLEARED", "ALARMCLEARED",
    ),
    LOCATION: (
        "GPS", "LOCATION", "LOCATIONREPORT", "POSITION", "GPSREPORT", "LIP",
        "GPSUPDATE", "LOCATIONUPDATE", "POSITIONUPDATE",
    ),
    PRESENCE: (
        "REGISTER", "REGISTRATION", "ONLINE", "POWERON", "DEREGISTER", "OFFLINE",
        "POWEROFF", "PRESENCE",
    ),
}.items():
    for _alias in _aliases:
        _EVENT_ALIASES[_alias] = _canonical

# Tên trường mà các gateway hay dùng, theo thứ tự ưu tiên.
_RADIO_ID_KEYS = ("radio_id", "radioId", "src_id", "source_id", "sourceId", "issi",
                  "subscriber_id", "unit_id", "unitId", "device_id")
_EVENT_KEYS = ("event_type", "eventType", "event", "alarm_type", "alarmType", "type")
_EVENT_ID_KEYS = ("gateway_event_id", "event_id", "eventId", "message_id", "id")
_TIME_KEYS = ("timestamp", "occurred_at", "time", "datetime", "event_time")
_STATUS_KEYS = ("status", "state", "alarm_status", "alarmStatus")
_ALIAS_KEYS = ("radio_alias", "radioAlias", "alias")
_LAT_KEYS = ("latitude", "lat")

# Phần mềm điều phối (vd SmartOne) gửi CÙNG eventType cho cả vòng đời báo
# động, chỉ đổi `status`. Các trạng thái này nghĩa là báo động đã kết thúc
# phía bộ đàm/điều phối — xử lý như huỷ khẩn cấp, không phải báo động mới.
_ENDED_STATUSES = frozenset({
    "CLEARED", "CLEAR", "CANCELLED", "CANCELED", "CANCEL", "ENDED", "END",
    "CLOSED", "RESOLVED", "INACTIVE", "RESET", "STOPPED",
})
_LNG_KEYS = ("longitude", "lng", "lon", "long")


class RadioEventError(ValueError):
    """Payload không đủ thông tin để xử lý (thiếu radio_id / event_type)."""


def _first(data: Dict[str, Any], keys: Iterable[str]) -> Any:
    for k in keys:
        v = data.get(k)
        if v is not None and v != "":
            return v
    return None


def _to_float(v: Any) -> Optional[float]:
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    return f


def normalize_event_type(raw: Any) -> str:
    key = re.sub(r"[^A-Z0-9]", "", str(raw or "").upper())
    return _EVENT_ALIASES.get(key, UNKNOWN)


def _parse_time(raw: Any) -> Optional[str]:
    """ISO-8601 hoặc epoch (giây / mili-giây) → ISO UTC. Không parse được → None."""
    if raw is None or raw == "":
        return None
    if isinstance(raw, (int, float)) or (isinstance(raw, str) and raw.strip().isdigit()):
        ts = float(raw)
        if ts > 1e12:  # mili-giây
            ts /= 1000.0
        try:
            return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()
        except (OverflowError, OSError, ValueError):
            return None
    try:
        dt = datetime.fromisoformat(str(raw).strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


def _extract_coords(data: Dict[str, Any]) -> tuple[Optional[float], Optional[float]]:
    lat = _to_float(_first(data, _LAT_KEYS))
    lng = _to_float(_first(data, _LNG_KEYS))
    if lat is None or lng is None:
        for nested_key in ("coordinates", "gps", "location", "position"):
            nested = data.get(nested_key)
            if isinstance(nested, dict):
                lat = _to_float(_first(nested, _LAT_KEYS))
                lng = _to_float(_first(nested, _LNG_KEYS))
            elif isinstance(nested, (list, tuple)) and len(nested) == 2:
                lat, lng = _to_float(nested[0]), _to_float(nested[1])
            if lat is not None and lng is not None:
                break
    # Bộ đàm chưa bắt được vệ tinh thường gửi 0,0 — coi như không có vị trí,
    # nếu không bản đồ sẽ chỉ đội cứu hộ ra giữa Đại Tây Dương.
    if lat is None or lng is None or (lat == 0.0 and lng == 0.0):
        return None, None
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0):
        return None, None
    return lat, lng


def normalize_event(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Một payload thô từ gateway → dict chuẩn:
        radio_id, event_type, raw_event_type, gateway_event_id, occurred_at,
        latitude, longitude, system, model, battery, is_alarm
    """
    if not isinstance(data, dict):
        raise RadioEventError("Mỗi sự kiện phải là một JSON object.")

    radio_id = _first(data, _RADIO_ID_KEYS)
    if radio_id is None or not str(radio_id).strip():
        raise RadioEventError("Thiếu radio_id (hoặc src_id / issi).")
    raw_type = _first(data, _EVENT_KEYS)
    if raw_type is None:
        raise RadioEventError("Thiếu event_type.")

    event_type = normalize_event_type(raw_type)
    status = re.sub(r"[^A-Z]", "", str(_first(data, _STATUS_KEYS) or "").upper())
    if event_type in ALARM_TYPES and status in _ENDED_STATUSES:
        event_type = EMERGENCY_CANCEL
    lat, lng = _extract_coords(data)
    gateway_event_id = _first(data, _EVENT_ID_KEYS)
    system = str(data.get("system") or data.get("network") or "").strip().lower() or None

    return {
        "radio_id": str(radio_id).strip(),
        "event_type": event_type,
        "raw_event_type": str(raw_type),
        "gateway_event_id": str(gateway_event_id) if gateway_event_id is not None else None,
        "occurred_at": _parse_time(_first(data, _TIME_KEYS)),
        "latitude": lat,
        "longitude": lng,
        "system": system,  # 'dmr' | 'tetra' | None
        "model": (str(data["model"]).strip() or None) if data.get("model") else None,
        "alias": (str(_first(data, _ALIAS_KEYS)).strip() or None) if _first(data, _ALIAS_KEYS) else None,
        "battery": _to_float(data.get("battery")),
        "is_alarm": event_type in ALARM_TYPES,
    }


# ── So khớp người cầm máy ↔ công việc Alone Worker ──────────────────────────

def _split_identity(text: str) -> tuple[str, str]:
    """'Nguyễn Văn A (EMP001)' → ('nguyễn văn a', 'emp001')."""
    s = (text or "").strip()
    m = re.search(r"\(([^)]+)\)", s)
    code = m.group(1).strip().casefold() if m else ""
    name = re.sub(r"\(.*?\)", "", s).strip().casefold()
    name = re.sub(r"\s+", " ", name)
    return name, code


def assignee_matches(assignee: Any, employee_id: Optional[str], employee_name: Optional[str]) -> bool:
    """
    Trường `assignee` của mushroom_jobs lưu TÊN (đôi khi dạng 'Tên (Mã)'), còn
    gán bộ đàm lưu cả mã lẫn tên. Khớp nếu trùng mã hoặc trùng tên (không phân
    biệt hoa thường, bỏ khoảng trắng thừa) — cùng quy tắc với
    routers.sessions.get_active_session_for_person.
    """
    if not assignee:
        return False
    a_name, a_code = _split_identity(str(assignee))
    emp_id = (employee_id or "").strip().casefold()
    e_name, e_code = _split_identity(employee_name or "")
    codes = {c for c in (emp_id, e_code) if c}
    if a_code and a_code in codes:
        return True
    if a_name and (a_name in codes or (e_name and a_name == e_name)):
        return True
    return False


def fold_records(mutations: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    """
    Dựng trạng thái hiện tại của một bảng từ mutation log (đã sắp theo thời
    gian). Cần vì backend SQLite không có read-model projection — bảng domain
    có thể rỗng, chỉ mutation log là nguồn sự thật trên cả hai backend.
    """
    state: Dict[str, Dict[str, Any]] = {}
    for m in mutations:
        data = m.get("data") or {}
        rid = data.get("id")
        if not rid:
            continue
        if str(m.get("operation", "")).lower() == "delete":
            state.pop(rid, None)
            continue
        state.setdefault(rid, {}).update(data)
    return state


def _truthy(v: Any) -> bool:
    return v in (True, 1, "1", "true", "True")


def find_active_solo_job(
    jobs: Dict[str, Dict[str, Any]],
    employee_id: Optional[str],
    employee_name: Optional[str],
) -> Optional[Dict[str, Any]]:
    """Công việc Alone Worker đang chạy của người này; nhiều job → lấy job bắt đầu muộn nhất."""
    candidates = [
        j for j in jobs.values()
        if str(j.get("status", "")).lower() in ("in_progress", "inprog")
        and (_truthy(j.get("is_solo_job")) or str(j.get("job_type", "")).lower() == "alone_worker")
        and assignee_matches(j.get("assignee"), employee_id, employee_name)
    ]
    if not candidates:
        return None
    candidates.sort(key=lambda j: str(j.get("started_at") or j.get("scheduled_at") or ""), reverse=True)
    return candidates[0]
