"""
Chiều xuống: iZii (giả) xếp lệnh → bridge lấy lệnh → HP682 giả → phản hồi → bridge báo kết quả.
Kịch bản theo yêu cầu test: Andrew cầm Radio 507; hỏi Lone Worker đã bật chưa; bật; gửi tin time out.
"""
import asyncio
import time

import pytest

from radio_bridge.bridge import RadioBridge
from radio_bridge.config import BridgeConfig
from radio_bridge.mock_izii import MockIZii
from radio_bridge.simulator import SimHP682

TOKEN = "radio-secret"


@pytest.fixture
def mock():
    m = MockIZii(token=TOKEN).start()
    yield m
    m.stop()


def cfg_for(tmp_path, url) -> BridgeConfig:
    return BridgeConfig(
        izii_url=url, token=TOKEN, listen_host="127.0.0.1", ports=[0], spool_dir=str(tmp_path / "spool"),
        retry_initial_s=0.02, retry_max_s=0.1, stats_every_s=0, command_poll_s=0.05, command_timeout_s=0.6,
    )


async def wait_done(mock, cid, timeout=5.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        c = mock.command(cid)
        if c["status"] in ("done", "failed"):
            return c
        await asyncio.sleep(0.03)
    return mock.command(cid)


async def started(tmp_path, mock, **radio_kw):
    b = RadioBridge(cfg_for(tmp_path, mock.url))
    await b.start()
    r = SimHP682(507, ("127.0.0.1", b.bound_ports[0]), **radio_kw)
    assert await r.power_on()
    await asyncio.sleep(0.05)
    return b, r


def test_query_enable_disable_lone_worker_on_radio_507(tmp_path, mock):
    async def go():
        b, r = await started(tmp_path, mock, lone_worker_response_s=60)
        c1 = await wait_done(mock, mock.queue_command(507, "lone_worker_status"))
        assert c1["status"] == "done" and c1["result"] == {"lone_worker": "off"}

        c2 = await wait_done(mock, mock.queue_command(507, "lone_worker_enable"))
        assert c2["status"] == "done" and c2["result"]["lone_worker"] == "on"
        assert r.lone_worker_enabled, "bộ đàm giả phải thật sự bật Lone Worker"

        c3 = await wait_done(mock, mock.queue_command(507, "lone_worker_status"))
        assert c3["result"] == {"lone_worker": "on"}

        c4 = await wait_done(mock, mock.queue_command(507, "lone_worker_disable"))
        assert c4["result"]["lone_worker"] == "off" and not r.lone_worker_enabled
        await r.power_off()
        await b.stop()
        return b

    b = run(go())
    assert b.stats["undecoded"] == 0, "phản hồi Lone Worker phải được bridge hiểu, không bị coi là gói lạ"


def test_timeout_text_message_reaches_radio_and_is_confirmed(tmp_path, mock):
    text = "ALONE WORKER TIMEOUT - Room 6A. Check in now or contact supervisor."

    async def go():
        b, r = await started(tmp_path, mock)
        c = await wait_done(mock, mock.queue_command(507, "text_message", {"text": text}))
        await r.power_off()
        await b.stop()
        return c, r

    c, r = run(go())
    assert c["status"] == "done" and c["result"]["delivered"] is True
    assert [m["text"] for m in r.inbox] == [text]
    assert r.inbox[0]["from"] == 9000, "người gửi là dispatcher_id của bridge"
    assert r.beeping


def test_radio_never_seen_by_bridge_fails_fast(tmp_path, mock):
    async def go():
        b = RadioBridge(cfg_for(tmp_path, mock.url))
        await b.start()
        t0 = time.monotonic()
        c = await wait_done(mock, mock.queue_command(888, "lone_worker_status"))
        await b.stop()
        return c, time.monotonic() - t0

    c, elapsed = run(go())
    assert c["status"] == "failed" and "chưa liên lạc" in c["error"]
    assert elapsed < 0.5, "không chờ hết timeout khi biết chắc không gửi được"


def test_radio_not_answering_times_out(tmp_path, mock):
    async def go():
        b, r = await started(tmp_path, mock)
        r.answer_commands = False  # bộ đàm nhận được nhưng không trả lời (vd firmware không hỗ trợ)
        c = await wait_done(mock, mock.queue_command(507, "lone_worker_status"))
        await r.power_off()
        await b.stop()
        return c, r

    c, r = run(go())
    assert c["status"] == "failed" and "không trả lời" in c["error"]
    assert r.commands_received, "lệnh vẫn phải tới được bộ đàm"


def test_lone_worker_enabled_by_command_then_times_out_raises_alarm(tmp_path, mock):
    """Bật Lone Worker từ xa → không ai bấm phím → bộ đàm tự báo Emergency → bridge chuyển lên iZii."""
    async def go():
        b, r = await started(tmp_path, mock, lone_worker_response_s=0.3, lone_worker_reminder_s=0.15, tx_cycles=1)
        await wait_done(mock, mock.queue_command(507, "lone_worker_enable"))
        end = time.monotonic() + 3
        while time.monotonic() < end and not any(e["event_type"] == "EMERGENCY_ALARM" for e in mock.received):
            await asyncio.sleep(0.05)
        await r.power_off()
        await b.stop()

    run(go())
    alarms = [e for e in mock.received if e["event_type"] == "EMERGENCY_ALARM"]
    assert alarms and alarms[0]["radio_id"] == "507"


def run(coro):
    return asyncio.run(coro)
