"""
Giải mã PDU Hytera (qua ok-dmrlib, AGPL-3.0) thành RadioEvent trung lập.

Đây là phần DUY NHẤT phụ thuộc ok-dmrlib. Khi có tài liệu ADK, thay file này (hoặc thêm codec mới
cùng giao diện `events_from_hdap`) mà không phải đụng spool/giao hàng/bridge.

NHỮNG GIẢ ĐỊNH CHƯA KIỂM CHỨNG VỚI THIẾT BỊ THẬT (đối chiếu khi có ADK):
  1. RCP RadioStatusReport: value != 0 nghĩa là "đang xảy ra", 0 là "kết thúc".
  2. Repeater báo động khẩn cấp bằng RepeaterBroadcastTransmitStatus với call_type EmergencyAlarm
     (0x05) / EmergencyAlarmCall (0x0C) / EmergencyGroupCall (0x03), sender_id là bộ đàm phát.
  3. Man Down / Lone Worker hết giờ ở dispatcher đều hiện thành emergency (theo Hytera) —
     nên qua đường repeater chúng đến dưới dạng SOS, không phân biệt được.
  7. (chiều xuống) Hỏi/bật Lone Worker bằng RCP FunctionStatusCheck (0x00ED/0x80ED) và
     FunctionEnableDisable (0x00EE/0x80EE). ok-dmrlib có tên opcode nhưng KHÔNG có bố cục payload, nên
     bố cục dưới đây (mã chức năng, thứ tự byte) là TỰ ĐẶT để simulator và bridge khớp nhau — phải thay
     theo ADK. Bộ đàm thật có thể không hỗ trợ các lệnh này qua mạng (Mobile API chỉ cho máy nối PC).
  8. (chiều xuống) Bridge gửi thẳng tới địa chỉ UDP mà bộ đàm đã dùng khi gửi lên. Qua repeater thật,
     cách định tuyến gói xuống một Radio ID có thể khác — xác nhận với ADK.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from okdmr.dmrlib.hytera.pdu.hdap import HDAP
from okdmr.dmrlib.hytera.pdu.location_protocol import (
    LocationProtocol,
    LocationProtocolResultCodes,
    LocationProtocolSpecificService,
)
from okdmr.dmrlib.hytera.pdu.radio_control_protocol import (
    RadioControlProtocol,
    RCPCallType,
    RCPOpcode,
    StatusChangeNotificationTargets as Target,
)
from okdmr.dmrlib.hytera.pdu.radio_ip import RadioIP
from okdmr.dmrlib.hytera.pdu.radio_registration_service import (
    RadioRegistrationService,
    RRSTypes,
)
from okdmr.dmrlib.hytera.pdu.text_message_protocol import TextMessageProtocol, TMPService

SOURCE_STATUS = "radio_status"
SOURCE_REPEATER = "repeater"
SOURCE_RRS = "rrs"
SOURCE_LP = "lp"

_EMERGENCY_CALL_TYPES = {
    RCPCallType.EmergencyAlarm,
    RCPCallType.EmergencyAlarmCall,
    RCPCallType.EmergencyGroupCall,
}

ALARM_EVENT_TYPES = frozenset({"EMERGENCY_ALARM", "EMERGENCY_CALL", "MAN_DOWN", "LONE_WORKER"})


@dataclass
class RadioEvent:
    radio_id: int
    event_type: str  # chuỗi mà server hiểu (xem server/radio_events.py)
    source: str
    extra: Dict[str, Any] = field(default_factory=dict)

    @property
    def is_alarm(self) -> bool:
        return self.event_type in ALARM_EVENT_TYPES


def radio_id_from_ip(ip: str) -> Optional[int]:
    try:
        return RadioIP.from_ip(ip).radio_id
    except Exception:
        return None


def _nmea_to_degrees(value: float, hemisphere: str) -> float:
    deg = int(value // 100)
    dec = deg + (value - deg * 100) / 60.0
    return -dec if hemisphere in ("S", "W") else dec


def events_from_hdap(
    hdap: Optional[HDAP], src_ip: str, *, id_from_ip: bool = True, forward_lone_reminder: bool = False
) -> List[RadioEvent]:
    """Một PDU HDAP → 0..n sự kiện. Không ném lỗi với PDU lạ (trả danh sách rỗng)."""
    if hdap is None:
        return []
    ip_id = radio_id_from_ip(src_ip) if id_from_ip else None
    out: List[RadioEvent] = []

    if isinstance(hdap, RadioControlProtocol):
        if hdap.opcode == RCPOpcode.RadioStatusReport and ip_id is not None:
            tgt, active = hdap.status_change_target, hdap.status_change_value != 0
            if tgt == Target.EMERGENCY:
                out.append(RadioEvent(ip_id, "EMERGENCY_ALARM" if active else "EMERGENCY_CANCEL", SOURCE_STATUS))
            elif tgt == Target.MAN_DOWN:
                out.append(RadioEvent(ip_id, "MAN_DOWN" if active else "EMERGENCY_CANCEL", SOURCE_STATUS))
            elif tgt == Target.LONE_WORKER_REMINDER and active and forward_lone_reminder:
                out.append(RadioEvent(ip_id, "LONE_WORKER", SOURCE_STATUS, {"note": "reminder only"}))
        elif hdap.opcode == RCPOpcode.RepeaterBroadcastTransmitStatus:
            if hdap.call_type in _EMERGENCY_CALL_TYPES and hdap.sender_id:
                kind = "EMERGENCY_CALL" if hdap.call_type == RCPCallType.EmergencyGroupCall else "EMERGENCY_ALARM"
                out.append(
                    RadioEvent(
                        hdap.sender_id, kind, SOURCE_REPEATER,
                        {"target_id": hdap.target_id, "call": hdap.call_type.name},
                    )
                )
    elif isinstance(hdap, RadioRegistrationService):
        if hdap.opcode == RRSTypes.RadioRegistrationRequest:
            out.append(RadioEvent(hdap.radio_ip.radio_id, "REGISTER", SOURCE_RRS))
        elif hdap.opcode == RRSTypes.RadioGoingOffline:
            out.append(RadioEvent(hdap.radio_ip.radio_id, "POWER_OFF", SOURCE_RRS))
    elif isinstance(hdap, LocationProtocol):
        if (
            hdap.specific_service == LocationProtocolSpecificService.StandardReport
            and hdap.result == LocationProtocolResultCodes.OK
            and hdap.gpsdata.data_valid == "A"
        ):
            g = hdap.gpsdata
            out.append(
                RadioEvent(
                    hdap.radio_ip.radio_id,
                    "GPS",
                    SOURCE_LP,
                    {
                        "latitude": round(_nmea_to_degrees(g.latitude, g.north_south), 6),
                        "longitude": round(_nmea_to_degrees(g.longitude, g.east_west), 6),
                    },
                )
            )
    return out


def service_name(hdap: Optional[HDAP]) -> str:
    try:
        return hdap.get_service_type().name if hdap else "none"
    except Exception:
        return "unknown"


# ── Chiều xuống: iZii → bộ đàm ──────────────────────────────────────────────

# GIẢ ĐỊNH 7 — xem docstring đầu file. Đổi theo ADK.
FUNCTION_LONE_WORKER = 0x01
OP_FUNC_STATUS_REQ, OP_FUNC_STATUS_REPLY = 0x00ED, 0x80ED
OP_FUNC_ENABLE_REQ, OP_FUNC_ENABLE_REPLY = 0x00EE, 0x80EE
RAW_RCP_REPLIES = (OP_FUNC_STATUS_REPLY, OP_FUNC_ENABLE_REPLY)
RAW_RCP_REQUESTS = (OP_FUNC_STATUS_REQ, OP_FUNC_ENABLE_REQ)
_HSTRP_OPTION_BIT = 0x20


def rcp_raw(opcode: int, payload: bytes) -> RadioControlProtocol:
    """RCP với opcode/payload tự đóng (ok-dmrlib chưa cài bố cục cho các opcode này)."""
    return RadioControlProtocol(
        opcode=RCPOpcode.UnknownService, raw_opcode=opcode.to_bytes(2, "little"), raw_payload=payload
    )


def parse_raw_rcp(datagram: bytes) -> Optional[tuple]:
    """
    Khung HSTRP chứa RCP mà ok-dmrlib không giải mã được → (sn, opcode, payload). None nếu không phải.
    RCP là little-endian; khung HSTRP có options thì bỏ qua (không gặp ở các lệnh này).
    """
    if len(datagram) < 13 or datagram[0:2] != b"2B" or datagram[3] & _HSTRP_OPTION_BIT:
        return None
    hdap = datagram[6:]
    if hdap[0] & 0x7F != 0x02 or hdap[-1] != 0x03:
        return None
    opcode = int.from_bytes(hdap[1:3], "little")
    length = int.from_bytes(hdap[3:5], "little")
    payload = hdap[5:5 + length]
    if len(payload) != length:
        return None
    return int.from_bytes(datagram[4:6], "big"), opcode, payload


def lone_worker_status_request() -> RadioControlProtocol:
    return rcp_raw(OP_FUNC_STATUS_REQ, bytes([FUNCTION_LONE_WORKER]))


def lone_worker_set_request(enable: bool) -> RadioControlProtocol:
    return rcp_raw(OP_FUNC_ENABLE_REQ, bytes([FUNCTION_LONE_WORKER, 1 if enable else 0]))


def parse_lone_worker_reply(opcode: int, payload: bytes) -> Dict[str, Any]:
    """0x80ED: [kết quả, chức năng, trạng thái]; 0x80EE: [kết quả]. Kết quả 0 = thành công."""
    if not payload:
        return {"ok": False, "error": "Phản hồi rỗng"}
    if payload[0] != 0:
        return {"ok": False, "error": f"Bộ đàm từ chối (mã {payload[0]})"}
    if opcode == OP_FUNC_STATUS_REPLY and len(payload) >= 3:
        return {"ok": True, "lone_worker": "on" if payload[2] else "off"}
    return {"ok": True}


def text_message(radio_id: int, request_id: int, text: str, dispatcher_id: int) -> TextMessageProtocol:
    """Tin nhắn riêng (TMP) có yêu cầu xác nhận — ok-dmrlib đóng/mở được cả tin và ACK."""
    return TextMessageProtocol(
        opcode=TMPService.SendPrivateMessage,
        source_ip=RadioIP(dispatcher_id),
        destination_ip=RadioIP(radio_id),
        request_id=request_id,
        text_data=text,
        is_confirmed=True,
    )
