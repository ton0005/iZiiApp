from datetime import date, time

from okdmr.dmrlib.hytera.pdu.location_protocol import GPSData, LocationProtocol, LocationProtocolSpecificService
from okdmr.dmrlib.hytera.pdu.radio_control_protocol import (
    RadioControlProtocol,
    RCPCallType,
    RCPOpcode,
    RepeaterMode,
    RepeaterServiceType,
    RepeaterStatus,
    StatusChangeNotificationTargets as T,
)
from okdmr.dmrlib.hytera.pdu.radio_registration_service import RadioRegistrationService, RRSTypes

from radio_bridge.codec import events_from_hdap, radio_id_from_ip
from radio_bridge.simulator import radio_ip


def _status(target, value):
    return RadioControlProtocol(opcode=RCPOpcode.RadioStatusReport, status_change_target=target, status_change_value=value)


def _bcast(call, sender, target=0):
    return RadioControlProtocol(
        opcode=RCPOpcode.RepeaterBroadcastTransmitStatus,
        repeater_mode=RepeaterMode.NormalSingleConnection,
        repeater_status=RepeaterStatus.IPRepeating,
        repeater_service_type=RepeaterServiceType.VOICE,
        call_type=call, sender_id=sender, target_id=target,
    )


def test_radio_id_roundtrip_through_simulated_ip():
    for rid in (1, 1001, 70000, 0xFFFFFF):
        assert radio_id_from_ip(radio_ip(rid)) == rid


def test_status_report_alarms_and_cancel():
    ip = radio_ip(1001)
    assert [(e.event_type, e.radio_id) for e in events_from_hdap(_status(T.MAN_DOWN, 1), ip)] == [("MAN_DOWN", 1001)]
    assert [e.event_type for e in events_from_hdap(_status(T.EMERGENCY, 1), ip)] == ["EMERGENCY_ALARM"]
    assert [e.event_type for e in events_from_hdap(_status(T.EMERGENCY, 0), ip)] == ["EMERGENCY_CANCEL"]
    assert [e.event_type for e in events_from_hdap(_status(T.MAN_DOWN, 0), ip)] == ["EMERGENCY_CANCEL"]


def test_unrelated_status_is_ignored():
    ip = radio_ip(1001)
    for tgt in (T.RSSI, T.BATTERY_SAVE, T.CHANNEL, T.VOLUME):
        assert events_from_hdap(_status(tgt, 3), ip) == []


def test_lone_worker_reminder_not_an_alarm_by_default():
    ip = radio_ip(1001)
    assert events_from_hdap(_status(T.LONE_WORKER_REMINDER, 1), ip) == []
    ev = events_from_hdap(_status(T.LONE_WORKER_REMINDER, 1), ip, forward_lone_reminder=True)
    assert [e.event_type for e in ev] == ["LONE_WORKER"]


def test_repeater_emergency_uses_sender_not_source_ip():
    for call in (RCPCallType.EmergencyAlarm, RCPCallType.EmergencyAlarmCall):
        ev = events_from_hdap(_bcast(call, 1001, 9), "10.9.9.9")
        assert [(e.event_type, e.radio_id, e.source) for e in ev] == [("EMERGENCY_ALARM", 1001, "repeater")]
    ev = events_from_hdap(_bcast(RCPCallType.EmergencyGroupCall, 1001, 9), "10.9.9.9")
    assert [e.event_type for e in ev] == ["EMERGENCY_CALL"]


def test_ordinary_calls_and_idle_are_not_alarms():
    assert events_from_hdap(_bcast(RCPCallType.GroupCall, 1001, 9), "10.9.9.9") == []
    assert events_from_hdap(_bcast(RCPCallType.PrivateCall, 0, 0), "10.9.9.9") == []


def test_registration_presence():
    reg = RadioRegistrationService(opcode=RRSTypes.RadioRegistrationRequest, radio_ip=bytes([10, 0, 3, 233]))
    off = RadioRegistrationService(opcode=RRSTypes.RadioGoingOffline, radio_ip=bytes([10, 0, 3, 233]))
    assert [(e.event_type, e.radio_id) for e in events_from_hdap(reg, "x")] == [("REGISTER", 1001)]
    assert [e.event_type for e in events_from_hdap(off, "x")] == [("POWER_OFF")]


def test_gps_nmea_to_decimal_degrees():
    gps = GPSData(
        data_valid="A", greenwich_time=time(1, 2, 3), greenwich_date=date(2026, 10, 24),
        north_south="S", latitude=3750.0, east_west="E", longitude=14450.0, speed_knots=0.0, direction=0,
    )
    lp = LocationProtocol(
        opcode=LocationProtocolSpecificService.StandardReport, request_id=1, radio_ip=bytes([10, 0, 3, 233]), gpsdata=gps
    )
    (ev,) = events_from_hdap(lp, "x")
    assert ev.event_type == "GPS" and ev.radio_id == 1001
    assert abs(ev.extra["latitude"] - (-37.833333)) < 1e-5  # 37°50' S
    assert abs(ev.extra["longitude"] - 144.833333) < 1e-5  # 144°50' E


def test_invalid_gps_fix_is_dropped():
    gps = GPSData.zero()  # data_valid = "V"
    lp = LocationProtocol(
        opcode=LocationProtocolSpecificService.StandardReport, request_id=1, radio_ip=bytes([10, 0, 3, 233]), gpsdata=gps
    )
    assert events_from_hdap(lp, "x") == []
