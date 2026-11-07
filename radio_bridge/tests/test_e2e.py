"""
End-to-end: HP682/HR1062 giả --UDP/HSTRP--> RadioBridge --HTTP--> iZiiServer giả.
Thời gian bộ đàm được thu nhỏ (vài trăm ms) nên cả bộ test chạy vài giây.
"""
import asyncio
import json
import os
import time

import pytest

from radio_bridge.bridge import RadioBridge
from radio_bridge.config import BridgeConfig
from radio_bridge.mock_izii import MockIZii
from radio_bridge.simulator import SimHP682, SimHR1062

TOKEN = "radio-secret"


@pytest.fixture
def mock():
    m = MockIZii(token=TOKEN).start()
    yield m
    m.stop()


def make_cfg(tmp_path, url, **kw) -> BridgeConfig:
    cfg = BridgeConfig(
        izii_url=url, token=TOKEN, listen_host="127.0.0.1", ports=[0], spool_dir=str(tmp_path / "spool"),
        retry_initial_s=0.02, retry_max_s=0.1, stats_every_s=0,
    )
    for k, v in kw.items():
        setattr(cfg, k, v)
    return cfg


async def wait_for(cond, timeout=5.0, interval=0.02):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if cond():
            return True
        await asyncio.sleep(interval)
    return cond()


def alarms(mock):
    return [e for e in mock.received if e["event_type"] not in ("REGISTER", "POWER_OFF", "GPS")]


def run(coro):
    return asyncio.run(coro)


def spool_files(tmp_path):
    d = tmp_path / "spool"
    return [f for f in os.listdir(d) if f.endswith(".json")]


# ── kịch bản hành vi bộ đàm ─────────────────────────────────────────────────

def test_register_then_emergency_key_tx_cycles(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=3)
        assert await r.power_on()
        await r.press_emergency()
        assert await wait_for(lambda: len(alarms(mock)) == 3)
        await r.power_off()
        await b.stop()
        return b

    b = run(go())
    a = alarms(mock)
    assert {e["event_type"] for e in a} == {"EMERGENCY_ALARM"} and {e["radio_id"] for e in a} == {"1001"}
    assert len({e["gateway_event_id"] for e in a}) == 3
    assert [e["event_type"] for e in mock.received if e["event_type"] in ("REGISTER", "POWER_OFF")] == ["REGISTER", "POWER_OFF"]
    # hợp đồng: server thật hiểu mọi gói bridge gửi
    assert len(mock.normalized) == len(mock.received)
    assert {n["event_type"] for n in mock.normalized if n["is_alarm"]} == {"sos"}
    assert spool_files(tmp_path) == []
    assert b.stats["undecoded"] == 0


def test_man_down_not_recovered_raises_alarm(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1002, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        r.set_tilt(90)  # nằm ngang
        assert await wait_for(lambda: len(alarms(mock)) == 1)
        await r.power_off()
        await b.stop()

    run(go())
    (e,) = alarms(mock)
    assert (e["event_type"], e["radio_id"]) == ("MAN_DOWN", "1002")
    assert [n["event_type"] for n in mock.normalized if n["is_alarm"]] == ["man_down"]


def test_man_down_recovered_during_prealert_cancels(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1002, ("127.0.0.1", b.bound_ports[0]), man_down_duration_s=0.1, man_down_prealert_s=0.4)
        await r.power_on()
        r.set_tilt(90)
        await asyncio.sleep(0.25)  # đang Pre-Alert
        assert r.state == "md_prealert" and r.beeping
        r.set_tilt(0)  # dựng đứng máy
        await asyncio.sleep(0.6)  # quá hạn Pre-Alert nếu không huỷ
        assert r.state == "idle"
        await r.power_off()
        await b.stop()

    run(go())
    assert alarms(mock) == []


def test_small_tilt_below_trigger_angle_is_ignored(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1002, ("127.0.0.1", b.bound_ports[0]))
        await r.power_on()
        r.set_tilt(40)  # cúi người nhặt đồ
        await asyncio.sleep(0.5)
        await r.power_off()
        await b.stop()

    run(go())
    assert alarms(mock) == []


def test_lone_worker_timeout_reminder_not_forwarded_emergency_is(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1003, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        r.enable_lone_worker()
        assert await wait_for(lambda: len(alarms(mock)) == 1)
        await r.power_off()
        await b.stop()

    run(go())
    (e,) = alarms(mock)
    assert (e["event_type"], e["radio_id"]) == ("EMERGENCY_ALARM", "1003")


def test_lone_worker_reminder_forwarded_only_when_configured(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url, forward_lone_worker_reminder=True))
        await b.start()
        r = SimHP682(1003, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1, lone_worker_response_s=0.1, lone_worker_reminder_s=0.3)
        await r.power_on()
        r.enable_lone_worker()
        assert await wait_for(lambda: any(e["event_type"] == "LONE_WORKER" for e in mock.received))
        await r.power_off()
        await b.stop()

    run(go())


def test_lone_worker_key_presses_keep_resetting_timer(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1003, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1, lone_worker_response_s=0.3, lone_worker_reminder_s=0.3)
        await r.power_on()
        r.enable_lone_worker()
        for _ in range(8):  # 0.8 s tổng, dài hơn 0.3 s response, nhưng bấm phím đều
            await asyncio.sleep(0.1)
            r.key_press()
        assert alarms(mock) == []
        # bấm phím ngay trong lúc nhắc nhở cũng huỷ được
        await asyncio.sleep(0.35)
        assert r.state == "lw_reminder"
        r.key_press()
        await asyncio.sleep(0.5)
        assert alarms(mock) == []
        await r.power_off()
        await b.stop()

    run(go())


def test_cancel_emergency_on_radio(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        await r.press_emergency()
        await r.cancel_emergency()
        assert await wait_for(lambda: any(e["event_type"] == "EMERGENCY_CANCEL" for e in mock.received))
        await r.power_off()
        await b.stop()

    run(go())
    assert [n["event_type"] for n in mock.normalized if n["event_type"].startswith("emergency")] == ["emergency_cancel"]


# ── đường repeater (giả thuyết B) ───────────────────────────────────────────

def test_repeater_path_merges_rebroadcasts_and_ignores_normal_calls(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        target = ("127.0.0.1", b.bound_ports[0])
        rpt = SimHR1062(target)
        await rpt.open()
        await rpt.group_call(sender=2002, target=9)  # cuộc gọi thường: không phải báo động
        r = SimHP682(1001, target, via="repeater", repeater=rpt, tx_cycles=3)
        await r.power_on()
        await r.press_emergency()
        assert await wait_for(lambda: len(alarms(mock)) >= 1)
        await asyncio.sleep(0.2)
        await r.power_off()
        rpt.close()
        await b.stop()
        return b

    b = run(go())
    a = alarms(mock)
    assert len(a) == 1, "3 lần phát lại + broadcast lặp của repeater chỉ thành 1 sự kiện"
    assert (a[0]["event_type"], a[0]["radio_id"], a[0]["bridge_source"]) == ("EMERGENCY_ALARM", "1001", "repeater")
    assert b.stats["suppressed"] >= 2


# ── độ bền ──────────────────────────────────────────────────────────────────

def test_lost_ack_resend_is_not_double_counted(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        r.link.drop_next_acks = 1  # bridge ACK nhưng "bộ đàm" không nhận → gửi lại cùng sn
        await r.press_emergency()
        assert await wait_for(lambda: len(alarms(mock)) >= 1)
        await asyncio.sleep(0.3)
        await r.power_off()
        await b.stop()
        return b

    b = run(go())
    assert len(alarms(mock)) == 1
    assert b.stats["duplicates"] == 1


def test_server_outage_is_retried_with_same_event_id(tmp_path, mock):
    mock.fail_next(3, 503)

    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        await r.press_emergency()
        assert await wait_for(lambda: len(alarms(mock)) == 1)
        await r.power_off()
        await b.stop()
        return b

    b = run(go())
    assert len(alarms(mock)) == 1
    assert b.delivery.stats["retries"] >= 3 and mock.attempts >= 4


def test_event_survives_bridge_restart_via_spool(tmp_path):
    cfg_dead = make_cfg(tmp_path, "http://127.0.0.1:9")  # không ai nghe

    async def first():
        b = RadioBridge(cfg_dead)
        await b.start()
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        await r.press_emergency()
        await asyncio.sleep(0.2)
        await r.power_off()
        await b.stop(drain_timeout=0.2)  # server vẫn chết → thoát với sự kiện chưa giao

    run(first())
    pending = spool_files(tmp_path)
    assert len(pending) >= 2, "báo động (và đăng ký) phải còn trên đĩa"
    saved = [json.load(open(tmp_path / "spool" / f)) for f in pending]
    assert any(s["event_type"] == "EMERGENCY_ALARM" for s in saved)

    m = MockIZii(token=TOKEN).start()
    try:
        async def second():
            b = RadioBridge(make_cfg(tmp_path, m.url))
            await b.start()
            assert await wait_for(lambda: len(m.received) == len(pending))
            await b.stop()

        run(second())
    finally:
        m.stop()
    assert {e["gateway_event_id"] for e in m.received} == {s["gateway_event_id"] for s in saved}
    assert spool_files(tmp_path) == []


def test_wrong_token_keeps_event_until_fixed(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url, token="sai-token"))
        await b.start()
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        await r.press_emergency()
        await asyncio.sleep(0.4)
        assert alarms(mock) == [] and b.delivery.stats["dead"] == 0, "401 là lỗi cấu hình — không được bỏ báo động"
        b.delivery.cfg.token = TOKEN  # quản trị sửa cấu hình
        assert await wait_for(lambda: len(alarms(mock)) == 1)
        await r.power_off()
        await b.stop()

    run(go())


def test_malformed_payload_goes_to_dead_letter(tmp_path, mock):
    mock.fail_next(1, 400)

    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        await r.press_emergency()
        assert await wait_for(lambda: b.delivery.stats["dead"] == 1)
        await r.power_off()
        await b.stop()

    run(go())
    assert len(os.listdir(tmp_path / "spool" / "dead")) == 1


def test_garbage_datagram_is_counted_and_does_not_break_bridge(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url, capture_file=str(tmp_path / "cap.jsonl")))
        await b.start()
        loop = asyncio.get_running_loop()
        t, _ = await loop.create_datagram_endpoint(asyncio.DatagramProtocol, local_addr=("127.0.0.1", 0))
        t.sendto(b"\x00\x01garbage-not-hstrp", ("127.0.0.1", b.bound_ports[0]))
        t.sendto(b"2B\x00\x00\x00\x07\x02\xff\xff\x00\x00\x00\x03", ("127.0.0.1", b.bound_ports[0]))  # HSTRP + HDAP hỏng
        t.close()
        assert await wait_for(lambda: b.stats["undecoded"] >= 1)
        r = SimHP682(1001, ("127.0.0.1", b.bound_ports[0]), tx_cycles=1)
        await r.power_on()
        await r.press_emergency()
        assert await wait_for(lambda: len(alarms(mock)) == 1)
        await r.power_off()
        await b.stop()
        return b

    b = run(go())
    assert b.stats["undecoded"] >= 1
    lines = [json.loads(l) for l in open(tmp_path / "cap.jsonl")]
    assert any(l["hex"].startswith("0001") for l in lines), "gói lạ phải được ghi vào file capture để phân tích"


def test_many_radios_concurrently(tmp_path, mock):
    async def go():
        b = RadioBridge(make_cfg(tmp_path, mock.url))
        await b.start()
        target = ("127.0.0.1", b.bound_ports[0])
        radios = [SimHP682(2000 + i, target, tx_cycles=1) for i in range(20)]
        await asyncio.gather(*(r.power_on() for r in radios))
        await asyncio.gather(*(r.press_emergency() for r in radios))
        assert await wait_for(lambda: len(alarms(mock)) == 20, timeout=10)
        await asyncio.gather(*(r.power_off() for r in radios))
        await b.stop()

    run(go())
    assert {e["radio_id"] for e in alarms(mock)} == {str(2000 + i) for i in range(20)}
