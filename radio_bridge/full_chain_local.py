"""
Chạy thử TOÀN CHUỖI trên một máy, KHÔNG cần phần cứng:

    HP682 giả --UDP--> radio_bridge --HTTP--> iZiiServer THẬT (SQLite tạm) --> /api/v1/radio/*

Cần hai môi trường Python: máy này chạy bridge+simulator (có ok-dmrlib, httpx); server thật chạy bằng
Python có sẵn phụ thuộc của server/ (đặt SERVER_PYTHON, mặc định cùng interpreter).

    SERVER_PYTHON=C:/Python311/python.exe  python -m radio_bridge.full_chain_local [--scenario andrew|sos|all]

Kịch bản:
  andrew : Andrew điểm danh, đăng ký Radio 507 cho ca, hỏi Lone Worker trên radio (TẮT) → bật → hỏi lại
           (BẬT); giao job Alone Worker; đồng hồ trong app hết giờ → server xếp tin nhắn → bridge gửi xuống
           Radio 507 → bộ đàm giả nhận tin và xác nhận.
  sos    : điểm danh + giao job Alone Worker cho EMP001, gán bộ đàm 1001, bấm SOS trên bộ đàm giả →
           cảnh báo gắn đúng job/phòng, phòng 'alone_timeout', job bật alarm_triggered.
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from typing import Callable, Dict

import httpx

from .bridge import RadioBridge
from .config import BridgeConfig
from .simulator import SimHP682

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 18080
RADIO_SECRET, ADMIN_SECRET = "demo-radio-secret", "demo-admin-secret"


def start_server(tmp: str) -> subprocess.Popen:
    env = dict(os.environ)
    env.update(
        IZIIAPP_DB_BACKEND="sqlite",
        IZIIAPP_SERVER_DB_PATH=os.path.join(tmp, "iziiapp.db"),
        IZIIAPP_RADIO_GATEWAY_SECRET=RADIO_SECRET,
        IZIIAPP_ADMIN_SECRET=ADMIN_SECRET,
        IZIIAPP_SERVER_SECRET="demo-server-secret",
        IZIIAPP_WS_SECRET="demo-ws-secret",
        PYTHONIOENCODING="utf-8",
    )
    py = os.environ.get("SERVER_PYTHON", sys.executable)
    log = open(os.path.join(tmp, "server.log"), "wb")
    return subprocess.Popen(
        [py, "-m", "uvicorn", "app:app", "--host", "127.0.0.1", "--port", str(PORT), "--log-level", "warning"],
        cwd=os.path.join(REPO, "server"), env=env, stdout=log, stderr=subprocess.STDOUT,
    )


def bridge_cfg(base: str, tmp: str, name: str) -> BridgeConfig:
    return BridgeConfig(izii_url=base, token=RADIO_SECRET, listen_host="127.0.0.1", ports=[0],
                        spool_dir=os.path.join(tmp, f"spool-{name}"), stats_every_s=0, retry_initial_s=0.2,
                        command_poll_s=0.2)


async def wait_command(http, base: str, admin: Dict[str, str], radio_id: str,
                       match: Callable[[dict], bool], timeout: float = 15.0) -> dict:
    end = time.monotonic() + timeout
    found: dict = {}
    while time.monotonic() < end:
        cmds = (await http.get(f"{base}/api/v1/radio/commands", headers=admin, params={"radio_id": radio_id})).json()["commands"]
        found = next((c for c in cmds if match(c)), {})
        if found.get("status") in ("done", "failed", "expired"):
            return found
        await asyncio.sleep(0.25)
    return found


async def run_command(http, base: str, admin: Dict[str, str], radio_id: str, command: str) -> dict:
    resp = await http.post(f"{base}/api/v1/radio/devices/{radio_id}/commands", headers=admin, json={"command": command})
    cid = resp.json()["command"]["id"]
    return await wait_command(http, base, admin, radio_id, lambda c: c["id"] == cid)


async def scenario_andrew(http, base: str, admin: Dict[str, str], tmp: str) -> bool:
    print("\n=== Kịch bản Andrew / Radio 507 ===")
    now = datetime.now(timezone.utc).isoformat()
    checkin = {"id": "m-att-andrew", "table": "mushroom_attendance_events", "operation": "insert",
               "data": {"id": "att-andrew", "employee_id": "EMP507", "employee_name": "Andrew",
                        "event_type": "CHECK_IN", "timestamp": now, "source": "MANAGER_BATCH"}}
    room = {"id": "m-room-6a", "table": "grow_rooms", "operation": "insert",
            "data": {"id": "room_6a", "name": "Room 6A", "status": "active"}}
    r = await http.post(base + "/sync/push", json={"mutations": [checkin, room]})
    print("1. Andrew điểm danh:", r.status_code)
    r = await http.put(base + "/api/v1/radio/devices/507", headers=admin,
                       json={"employee_id": "EMP507", "employee_name": "Andrew", "model": "HP682"})
    print("2. Đăng ký Radio 507 cho Andrew:", r.status_code)

    bridge = RadioBridge(bridge_cfg(base, tmp, "andrew"))
    await bridge.start()
    # Response Time dài để đồng hồ trên bộ đàm không tự báo động trong lúc test chiều xuống.
    radio = SimHP682(507, ("127.0.0.1", bridge.bound_ports[0]), lone_worker_response_s=600)
    await radio.power_on()
    c1 = c3 = c4 = dev = {}
    try:
        c1 = await run_command(http, base, admin, "507", "lone_worker_status")
        print("3. Hỏi Lone Worker trên Radio 507:", c1.get("status"), c1.get("result"), c1.get("error") or "")
        c2 = await run_command(http, base, admin, "507", "lone_worker_enable")
        print("   Bật Lone Worker:", c2.get("status"), c2.get("result"))
        c3 = await run_command(http, base, admin, "507", "lone_worker_status")
        print("   Hỏi lại:", c3.get("status"), c3.get("result"))
        devices = (await http.get(base + "/api/v1/radio/devices", headers=admin)).json()["devices"]
        dev = next(d for d in devices if d["radio_id"] == "507")
        print("   Server ghi nhận lone_worker_state =", dev.get("lone_worker_state"))

        # Server SQLite không chiếu bảng điểm danh, nên gửi lại sự kiện CHECK_IN (cùng id, idempotent)
        # cùng lô với job để bước kiểm "đã điểm danh" đi theo nhánh in-flight.
        job = {"id": "m-job-andrew", "table": "mushroom_jobs", "operation": "insert",
               "data": {"id": "job-andrew", "room_id": "room_6a", "name": "Radio test - Alone Worker",
                        "job_type": "alone_worker", "status": "in_progress", "assignee": "Andrew",
                        "is_solo_job": True, "time_limit_minutes": 1, "started_at": now, "alarm_triggered": False}}
        r = await http.post(base + "/sync/push", json={"mutations": [checkin, job]})
        print("4. Giao job Alone Worker cho Andrew:", r.status_code, "rejected =", r.json().get("rejected_count"))
        # App phát hiện hết giờ (checkSoloJobsAlarms) và đẩy alarm_triggered = true.
        r = await http.post(base + "/sync/push", json={"mutations": [
            {"id": "m-job-andrew-timeout", "table": "mushroom_jobs", "operation": "update",
             "data": {"id": "job-andrew", "alarm_triggered": True}}]})
        print("5. Đồng hồ Alone Worker hết giờ (app đẩy alarm_triggered):", r.status_code)

        c4 = await wait_command(http, base, admin, "507", lambda c: c.get("reason") == "alone_worker_timeout")
        print("6. Tin gửi xuống Radio 507:", c4.get("status"), (c4.get("params") or {}).get("text"))
        await asyncio.sleep(0.3)
        print("   Hộp thư bộ đàm giả:", [m["text"] for m in radio.inbox])
    finally:
        await radio.power_off()
        await bridge.stop()

    ok = (c1.get("result") == {"lone_worker": "off"} and c3.get("result") == {"lone_worker": "on"}
          and dev.get("lone_worker_state") == "on" and c4.get("status") == "done"
          and any("ALONE WORKER TIMEOUT" in m["text"] and "Room 6A" in m["text"] for m in radio.inbox))
    print("KẾT QUẢ Andrew:", "ĐẠT" if ok else "KHÔNG ĐẠT")
    return ok


async def scenario_sos(http, base: str, admin: Dict[str, str], tmp: str) -> bool:
    print("\n=== Kịch bản SOS ===")
    now = datetime.now(timezone.utc).isoformat()
    push = await http.post(base + "/sync/push", json={"mutations": [
        {"id": "m-att", "table": "mushroom_attendance_events", "operation": "insert",
         "data": {"id": "att-1", "employee_id": "EMP001", "event_type": "CHECK_IN", "timestamp": now, "source": "MANAGER_BATCH"}},
        {"id": "m-room", "table": "grow_rooms", "operation": "insert",
         "data": {"id": "room_52a", "name": "Room 52A", "status": "active", "current_stage": "alone_worker"}},
        {"id": "m-job", "table": "mushroom_jobs", "operation": "insert",
         "data": {"id": "job-1", "room_id": "room_52a", "job_type": "alone_worker", "status": "in_progress",
                  "assignee": "Nguyen Van A (EMP001)", "is_solo_job": True, "started_at": now}},
    ]})
    assert push.status_code == 200 and push.json()["rejected_count"] == 0, push.text
    bind = await http.put(base + "/api/v1/radio/devices/1001", headers=admin,
                          json={"employee_id": "EMP001", "employee_name": "Nguyen Van A", "model": "HP682"})
    assert bind.status_code == 200, bind.text

    bridge = RadioBridge(bridge_cfg(base, tmp, "sos"))
    await bridge.start()
    radio = SimHP682(1001, ("127.0.0.1", bridge.bound_ports[0]), tx_cycles=3)
    await radio.power_on()
    print("Bộ đàm 1001 bật, bấm nút khẩn cấp…")
    await radio.press_emergency()

    alarm = None
    for _ in range(60):
        alarms = (await http.get(base + "/api/v1/radio/alarms", headers=admin)).json()["alarms"]
        alarm = next((a for a in alarms if a["radio_id"] == "1001"), None)
        if alarm:
            break
        await asyncio.sleep(0.25)
    await radio.power_off()
    await bridge.stop()
    if not alarm:
        print("KHÔNG có cảnh báo trên server")
        return False
    print("Cảnh báo:", {k: alarm[k] for k in ("event_type", "radio_id", "employee_name", "job_id", "room_id", "status", "repeat_count")})

    pull = (await http.get(base + "/sync/pull", params={"after_seq": 0, "limit": 500})).json()
    rows = pull.get("updates", pull if isinstance(pull, list) else [])
    job_alarm = any(u["table"] == "mushroom_jobs" and u["data"].get("id") == "job-1" and u["data"].get("alarm_triggered") for u in rows)
    room_timeout = any(u["table"] == "grow_rooms" and u["data"].get("current_stage") == "alone_timeout" for u in rows)
    print(f"job.alarm_triggered={job_alarm}  room.alone_timeout={room_timeout}")
    ok = (alarm["event_type"] == "sos" and alarm["job_id"] == "job-1" and alarm["room_id"] == "room_52a"
          and alarm["employee_id"] == "EMP001" and job_alarm and room_timeout)
    print("KẾT QUẢ SOS:", "ĐẠT" if ok else "KHÔNG ĐẠT")
    return ok


async def main(scenario: str = "all") -> int:
    tmp = tempfile.mkdtemp(prefix="izii_fullchain_")
    srv = start_server(tmp)
    base = f"http://127.0.0.1:{PORT}"
    admin = {"X-iZii-Admin-Token": ADMIN_SECRET}
    try:
        async with httpx.AsyncClient(timeout=10) as http:
            for _ in range(120):
                try:
                    if (await http.get(base + "/health")).status_code == 200:
                        break
                except httpx.HTTPError:
                    pass
                if srv.poll() is not None:
                    print("Server thoát sớm, xem", os.path.join(tmp, "server.log"))
                    return 1
                await asyncio.sleep(0.5)
            else:
                print("Server không khởi động kịp")
                return 1

            results = []
            if scenario in ("andrew", "all"):
                results.append(await scenario_andrew(http, base, admin, tmp))
            if scenario in ("sos", "all"):
                results.append(await scenario_sos(http, base, admin, tmp))
            return 0 if results and all(results) else 1
    finally:
        srv.terminate()
        try:
            srv.wait(10)
        except subprocess.TimeoutExpired:
            srv.kill()


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(prog="radio_bridge.full_chain_local")
    ap.add_argument("--scenario", choices=("andrew", "sos", "all"), default="all")
    logging.basicConfig(level=logging.WARNING, format="%(name)s: %(message)s")
    sys.exit(asyncio.run(main(ap.parse_args().scenario)))
