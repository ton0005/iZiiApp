"""
Bộ giả lập bộ đàm HP682 và repeater HR1062 để test bridge khi chưa có phần cứng.

Giả lập ở mức GÓI (HSTRP/HDAP qua UDP) và mức HÀNH VI (đếm giờ Lone Worker, góc nghiêng Man Down,
Tx Cycles của Emergency) theo mô tả cấu hình CPS trong plan/Hytera/Integrate Hytera.

GIỚI HẠN — đọc trước khi tin kết quả test:
  * Khuôn dạng gói dựng bằng ok-dmrlib, nên simulator + bridge cùng dùng một thư viện: test chứng
    minh bridge nhất quán với thư viện, KHÔNG chứng minh khớp với repeater thật. Việc đó cần gói bắt
    thật từ HR1062 / tài liệu ADK (chạy bridge với --capture).
  * Bộ đàm thật có thể báo Man Down / Lone Worker bằng loại gói khác simulator. Hai chế độ
    `via="status"` và `via="repeater"` bao phủ hai giả thuyết trong codec.py.
  * Địa chỉ nguồn UDP mô phỏng Radio IP bằng 127.<b1>.<b2>.<b3> (ID 1001 → 127.0.3.233).
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from typing import Dict, Optional, Tuple

from okdmr.dmrlib.hytera.pdu.hdap import HDAP
from okdmr.dmrlib.hytera.pdu.hstrp import HSTRP, HSTRPPacketType
from okdmr.dmrlib.hytera.pdu.radio_control_protocol import (
    RadioControlProtocol,
    RCPCallType,
    RCPOpcode,
    RepeaterMode,
    RepeaterServiceType,
    RepeaterStatus,
    StatusChangeNotificationTargets as Target,
)
from okdmr.dmrlib.hytera.pdu.radio_ip import RadioIP
from okdmr.dmrlib.hytera.pdu.radio_registration_service import RadioRegistrationService, RRSTypes
from okdmr.dmrlib.hytera.pdu.text_message_protocol import TextMessageProtocol, TMPResultCodes, TMPService

from .codec import (
    FUNCTION_LONE_WORKER,
    OP_FUNC_ENABLE_REPLY,
    OP_FUNC_ENABLE_REQ,
    OP_FUNC_STATUS_REPLY,
    OP_FUNC_STATUS_REQ,
    parse_raw_rcp,
    rcp_raw,
)

log = logging.getLogger("radio_bridge.sim")


def radio_ip(radio_id: int) -> str:
    """ID → '127.b1.b2.b3' (3 byte cuối), khớp RadioIP/codec.radio_id_from_ip."""
    b = radio_id.to_bytes(3, "big")
    return f"127.{b[0]}.{b[1]}.{b[2]}"


class SimLink:
    """Một đầu UDP phát khung HSTRP có ACK + gửi lại như thiết bị thật (T_NUMRETRY=3)."""

    ACK_TIMEOUT_S = 0.15
    RETRIES = 3

    def __init__(self, target: Tuple[str, int], src_ip: str):
        self.target, self.src_ip = target, src_ip
        self.sn = 0
        self.sent_packets = 0
        self._transport: Optional[asyncio.DatagramTransport] = None
        self._acks: Dict[int, asyncio.Event] = {}
        self.drop_next_acks = 0  # giả lập mất ACK: bridge đã ACK nhưng "bộ đàm" coi như không nhận
        # Gói dữ liệu từ bridge (chiều xuống): on_message(kind, obj) với kind 'hdap' hoặc 'rcp_raw'.
        self.on_message = None

    async def open(self) -> None:
        loop = asyncio.get_running_loop()
        link = self

        class _P(asyncio.DatagramProtocol):
            def datagram_received(self, data, addr):
                try:
                    p = HSTRP.from_bytes(data)
                except Exception:
                    p = None
                if p is None:
                    raw = parse_raw_rcp(data)  # RCP ok-dmrlib không giải mã được (lệnh Lone Worker)
                    if raw:
                        link._ack(raw[0], addr)
                        if link.on_message:
                            link.on_message("rcp_raw", (raw[1], raw[2]))
                    return
                if p.pkt_type.is_ack:
                    if link.drop_next_acks > 0:
                        link.drop_next_acks -= 1
                        return
                    ev = link._acks.get(p.sn)
                    if ev:
                        ev.set()
                elif p.payload is not None:
                    link._ack(p.sn, addr)
                    if link.on_message:
                        link.on_message("hdap", p.payload)

        self._transport, _ = await loop.create_datagram_endpoint(_P, local_addr=(self.src_ip, 0))

    def close(self) -> None:
        if self._transport:
            self._transport.close()

    def _ack(self, sn: int, addr) -> None:
        if self._transport:
            self._transport.sendto(HSTRP(pkt_type=HSTRPPacketType(is_ack=True), sn=sn).as_bytes(), addr)

    async def _send_reliable(self, pkt: HSTRP) -> int:
        """Gửi + chờ ACK, tối đa 1+RETRIES lần. Trả số lần gửi; 0 nếu hết lượt mà không có ACK."""
        ev = self._acks.setdefault(pkt.sn, asyncio.Event())
        raw = pkt.as_bytes()
        for attempt in range(1, self.RETRIES + 2):
            self._transport.sendto(raw, self.target)
            self.sent_packets += 1
            try:
                await asyncio.wait_for(ev.wait(), self.ACK_TIMEOUT_S)
                self._acks.pop(pkt.sn, None)
                return attempt
            except asyncio.TimeoutError:
                continue
        self._acks.pop(pkt.sn, None)
        return 0

    async def connect(self) -> bool:
        return await self._send_reliable(HSTRP(pkt_type=HSTRPPacketType(is_connect=True), sn=0)) > 0

    async def send(self, hdap: HDAP) -> int:
        self.sn = (self.sn % 0xFFFE) + 1
        return await self._send_reliable(HSTRP(pkt_type=HSTRPPacketType(), payload=hdap, sn=self.sn))

    def send_raw_duplicate(self, hdap: HDAP, sn: int) -> None:
        """Gửi đúng một khung HSTRP có sn cho trước, không chờ ACK (mô phỏng gói gửi lại)."""
        self._transport.sendto(HSTRP(pkt_type=HSTRPPacketType(), payload=hdap, sn=sn).as_bytes(), self.target)


class SimHR1062:
    """Repeater giả: phát RepeaterBroadcastTransmitStatus theo vòng đời cuộc gọi."""

    def __init__(self, target: Tuple[str, int], repeater_ip: str = "127.255.0.1"):
        self.link = SimLink(target, repeater_ip)

    async def open(self) -> None:
        await self.link.open()
        await self.link.connect()

    def close(self) -> None:
        self.link.close()

    async def _status(self, status: RepeaterStatus, svc: RepeaterServiceType, call: RCPCallType, sender: int, target: int) -> int:
        return await self.link.send(
            RadioControlProtocol(
                opcode=RCPOpcode.RepeaterBroadcastTransmitStatus,
                repeater_mode=RepeaterMode.NormalSingleConnection,
                repeater_status=status,
                repeater_service_type=svc,
                call_type=call,
                sender_id=sender,
                target_id=target,
            )
        )

    async def emergency_alarm(self, sender: int, target: int = 0, hang_updates: int = 2) -> None:
        await self._status(RepeaterStatus.IPRepeating, RepeaterServiceType.VOICE, RCPCallType.EmergencyAlarm, sender, target)
        for _ in range(hang_updates):  # repeater lặp lại trạng thái trong lúc cuộc gọi còn mở
            await self._status(RepeaterStatus.IPCallHangTime, RepeaterServiceType.VOICE, RCPCallType.EmergencyAlarm, sender, target)
        await self.idle()

    async def group_call(self, sender: int, target: int) -> None:
        await self._status(RepeaterStatus.IPRepeating, RepeaterServiceType.VOICE, RCPCallType.GroupCall, sender, target)
        await self.idle()

    async def idle(self) -> None:
        await self._status(RepeaterStatus.Sleep, RepeaterServiceType.NO_SERVICE, RCPCallType.PrivateCall, 0, 0)


class SimHP682:
    """
    Bộ đàm giả. Tham số thời gian theo CPS (đơn vị giây, thu nhỏ khi test):
      lone_worker_response_s : không thao tác trong khoảng này → bắt đầu nhắc nhở
      lone_worker_reminder_s : nhắc nhở (bíp) trước khi kích hoạt Emergency
      man_down_duration_s    : nằm nghiêng liên tục trong khoảng này → Pre-Alert
      man_down_prealert_s    : Pre-Alert; dựng đứng máy trong lúc này sẽ huỷ
      tx_cycles              : số lần phát lại gói Emergency
    via="status"   → máy tự báo bằng RCP RadioStatusReport (giả thuyết A trong codec.py)
    via="repeater" → máy phát Emergency, repeater giả (HR1062) broadcast sender (giả thuyết B)
    """

    def __init__(
        self,
        radio_id: int,
        target: Tuple[str, int],
        *,
        via: str = "status",
        repeater: Optional[SimHR1062] = None,
        lone_worker_response_s: float = 0.3,
        lone_worker_reminder_s: float = 0.15,
        man_down_trigger_deg: int = 55,
        man_down_duration_s: float = 0.15,
        man_down_prealert_s: float = 0.15,
        tx_cycles: int = 3,
        tx_cycle_interval_s: float = 0.03,
    ):
        assert via in ("status", "repeater")
        assert via == "status" or repeater is not None, "via='repeater' cần SimHR1062"
        self.radio_id, self.via, self.repeater = radio_id, via, repeater
        self.link = SimLink(target, radio_ip(radio_id))
        self.cfg = dict(
            lw_response=lone_worker_response_s, lw_reminder=lone_worker_reminder_s,
            md_angle=man_down_trigger_deg, md_duration=man_down_duration_s, md_prealert=man_down_prealert_s,
            tx_cycles=tx_cycles, tx_interval=tx_cycle_interval_s,
        )
        self.lone_worker_enabled = False
        self.state = "idle"  # idle | lw_reminder | md_prealert | emergency
        self.inbox: list = []  # tin nhắn nhận từ iZii (hiện trên màn hình bộ đàm)
        self.commands_received: list = []
        self.answer_commands = True  # False = giả lập bộ đàm không trả lời lệnh
        self.link.on_message = self._on_message
        self.beeping = False
        self._lw_task: Optional[asyncio.Task] = None
        self._md_task: Optional[asyncio.Task] = None
        self._tx_task: Optional[asyncio.Task] = None
        self.tilt_deg = 0

    async def power_on(self) -> bool:
        await self.link.open()
        ok = await self.link.connect()
        await self.link.send(RadioRegistrationService(opcode=RRSTypes.RadioRegistrationRequest, radio_ip=_ip_bytes(self.radio_id)))
        return ok

    async def power_off(self) -> None:
        self._cancel_timers()
        await self.link.send(RadioRegistrationService(opcode=RRSTypes.RadioGoingOffline, radio_ip=_ip_bytes(self.radio_id)))
        self.link.close()

    def _cancel_timers(self) -> None:
        for t in (self._lw_task, self._md_task):
            if t and not t.done():
                t.cancel()
        self._lw_task = self._md_task = None

    # ── Lone Worker ─────────────────────────────────────────────────────────
    def enable_lone_worker(self) -> None:
        self.lone_worker_enabled = True
        self._restart_lw()

    def disable_lone_worker(self) -> None:
        self.lone_worker_enabled = False
        if self._lw_task and not self._lw_task.done():
            self._lw_task.cancel()
        if self.state == "lw_reminder":
            self.state, self.beeping = "idle", False

    def key_press(self) -> None:
        """Bấm phím / PTT / xoay núm: xoá nhắc nhở và đếm lại từ đầu."""
        if self.state == "lw_reminder":
            self.state, self.beeping = "idle", False
        if self.lone_worker_enabled and self.state in ("idle", "lw_reminder"):
            self._restart_lw()

    def _restart_lw(self) -> None:
        if self._lw_task and not self._lw_task.done():
            self._lw_task.cancel()
        self._lw_task = asyncio.get_running_loop().create_task(self._lw_run())

    async def _lw_run(self) -> None:
        await asyncio.sleep(self.cfg["lw_response"])
        self.state, self.beeping = "lw_reminder", True
        await self.link.send(_status(Target.LONE_WORKER_REMINDER, 1))
        await asyncio.sleep(self.cfg["lw_reminder"])
        self.beeping = False
        await self._emergency("lone_worker")

    # ── Man Down ────────────────────────────────────────────────────────────
    def set_tilt(self, degrees: int) -> None:
        self.tilt_deg = degrees
        tilted = degrees >= self.cfg["md_angle"]
        if tilted and self.state == "idle" and not (self._md_task and not self._md_task.done()):
            self._md_task = asyncio.get_running_loop().create_task(self._md_run())
        elif not tilted:
            if self._md_task and not self._md_task.done():
                self._md_task.cancel()
            if self.state == "md_prealert":
                self.state, self.beeping = "idle", False

    async def _md_run(self) -> None:
        await asyncio.sleep(self.cfg["md_duration"])
        self.state, self.beeping = "md_prealert", True
        await asyncio.sleep(self.cfg["md_prealert"])
        self.beeping = False
        await self._emergency("man_down")

    # ── Emergency ───────────────────────────────────────────────────────────
    async def press_emergency(self) -> None:
        await self._emergency("key")

    async def _emergency(self, cause: str) -> None:
        """Phát Emergency theo Tx Cycles. `cause` chỉ dùng để chọn loại gói ở via='status'."""
        self._cancel_timers_except_current()
        self.state = "emergency"
        for i in range(self.cfg["tx_cycles"]):
            if self.via == "status":
                # Giả thuyết A: Man Down có cờ riêng; còn lại (nút bấm, Lone Worker hết giờ) là EMERGENCY.
                await self.link.send(_status(Target.MAN_DOWN if cause == "man_down" else Target.EMERGENCY, 1))
            else:
                await self.repeater.emergency_alarm(sender=self.radio_id, hang_updates=0)
            if i + 1 < self.cfg["tx_cycles"]:
                await asyncio.sleep(self.cfg["tx_interval"])

    def _cancel_timers_except_current(self) -> None:
        cur = asyncio.current_task()
        for t in (self._lw_task, self._md_task):
            if t and t is not cur and not t.done():
                t.cancel()

    async def cancel_emergency(self) -> None:
        """Người dùng thoát chế độ khẩn cấp trên máy."""
        if self.via == "status":
            await self.link.send(_status(Target.EMERGENCY, 0))
        self.state = "idle"
        if self.lone_worker_enabled:
            self._restart_lw()


    # ── Chiều xuống: lệnh từ iZii qua bridge ────────────────────────────────
    def _on_message(self, kind: str, obj) -> None:
        if kind == "rcp_raw":
            opcode, payload = obj
            self.commands_received.append(("rcp", opcode, bytes(payload)))
            if not self.answer_commands:
                return
            if opcode == OP_FUNC_STATUS_REQ and payload[:1] == bytes([FUNCTION_LONE_WORKER]):
                reply = rcp_raw(OP_FUNC_STATUS_REPLY, bytes([0, FUNCTION_LONE_WORKER, 1 if self.lone_worker_enabled else 0]))
            elif opcode == OP_FUNC_ENABLE_REQ and len(payload) >= 2 and payload[0] == FUNCTION_LONE_WORKER:
                (self.enable_lone_worker if payload[1] else self.disable_lone_worker)()
                reply = rcp_raw(OP_FUNC_ENABLE_REPLY, bytes([0]))
            else:
                return
            asyncio.get_running_loop().create_task(self.link.send(reply))
        elif isinstance(obj, TextMessageProtocol) and obj.opcode == TMPService.SendPrivateMessage:
            text = obj.text_data.decode("utf-16-le", errors="replace")
            self.commands_received.append(("tmp", obj.request_id, text))
            self.inbox.append({"text": text, "from": obj.source_ip.radio_id, "request_id": obj.request_id})
            self.beeping = True  # bộ đàm kêu báo có tin
            log.warning("📟 Bộ đàm %s nhận tin: %s", self.radio_id, text)
            if not self.answer_commands:
                return
            ack = TextMessageProtocol(
                opcode=TMPService.SendPrivateMessageAck,
                source_ip=RadioIP(self.radio_id),
                destination_ip=obj.source_ip,
                request_id=obj.request_id,
                result_code=TMPResultCodes.OK,
            )
            asyncio.get_running_loop().create_task(self.link.send(ack))


def _ip_bytes(radio_id: int) -> bytes:
    return bytes([0x0A]) + radio_id.to_bytes(3, "big")


def _status(target: Target, value: int) -> RadioControlProtocol:
    return RadioControlProtocol(
        opcode=RCPOpcode.RadioStatusReport, status_change_target=target, status_change_value=value
    )


# ── CLI: chạy thủ công với bridge thật ──────────────────────────────────────
SERVE_HELP = """Lệnh (gõ rồi Enter):
  k      bấm phím (reset đồng hồ Lone Worker / tắt nhắc nhở)
  sos    bấm nút khẩn cấp
  down   đặt máy nằm ngang (Man Down)     up   dựng máy dậy
  lw on | lw off   bật/tắt Lone Worker trên máy
  s      xem trạng thái          q    tắt máy và thoát"""


def _print_status(radio: "SimHP682") -> None:
    print(
        f"[{radio.radio_id}] Lone Worker={'BẬT' if radio.lone_worker_enabled else 'TẮT'} trạng thái={radio.state}"
        f" bíp={'có' if radio.beeping else 'không'} tin nhắn={len(radio.inbox)}"
    )
    for m in radio.inbox[-3:]:
        print(f"    ✉ từ {m['from']}: {m['text']}")


async def _serve(radio: "SimHP682") -> None:
    """Bộ đàm bật liên tục, trả lời lệnh từ iZii, nhận lệnh gõ tay. Đăng ký lại mỗi 30 s."""
    loop = asyncio.get_running_loop()
    print(SERVE_HELP)

    async def keepalive():
        while True:
            await asyncio.sleep(30)
            await radio.link.send(RadioRegistrationService(opcode=RRSTypes.RadioRegistrationRequest,
                                                           radio_ip=_ip_bytes(radio.radio_id)))

    ka = loop.create_task(keepalive())
    seen = 0
    try:
        while True:
            line = (await loop.run_in_executor(None, sys.stdin.readline))
            if line == "":  # stdin đóng (chạy nền): chỉ giữ máy bật
                await asyncio.Event().wait()
            cmd = line.strip().lower()
            if cmd == "q":
                break
            elif cmd == "k":
                radio.key_press()
            elif cmd == "sos":
                await radio.press_emergency()
            elif cmd == "down":
                radio.set_tilt(90)
            elif cmd == "up":
                radio.set_tilt(0)
            elif cmd == "lw on":
                radio.enable_lone_worker()
            elif cmd == "lw off":
                radio.disable_lone_worker()
            elif cmd not in ("s", ""):
                print(SERVE_HELP)
            for m in radio.inbox[seen:]:
                print(f"    ✉ TIN MỚI từ {m['from']}: {m['text']}")
            seen = len(radio.inbox)
            _print_status(radio)
    finally:
        ka.cancel()


async def _run_cli(a: argparse.Namespace) -> None:
    host, port = a.target.rsplit(":", 1)
    target = (host, int(port))
    rpt = None
    if a.via == "repeater":
        rpt = SimHR1062(target)
        await rpt.open()
    radio = SimHP682(
        a.radio, target, via=a.via, repeater=rpt,
        lone_worker_response_s=a.lw_response, lone_worker_reminder_s=a.lw_reminder,
    )
    ok = await radio.power_on()
    print(f"Bộ đàm {a.radio} bật, kết nối bridge: {'OK' if ok else 'KHÔNG CÓ ACK'}")
    if a.lone_worker == "on":
        radio.enable_lone_worker()
    if a.scenario == "serve":
        await _serve(radio)
    elif a.scenario == "sos":
        await radio.press_emergency()
    elif a.scenario == "man_down":
        radio.set_tilt(90)
        await asyncio.sleep(radio.cfg["md_duration"] + radio.cfg["md_prealert"] + 0.5)
    elif a.scenario == "lone_worker":
        radio.enable_lone_worker()
        await asyncio.sleep(radio.cfg["lw_response"] + radio.cfg["lw_reminder"] + 0.5)
    elif a.scenario == "presence":
        await asyncio.sleep(0.2)
    await radio.power_off()
    if rpt:
        rpt.close()
    print(f"Xong kịch bản '{a.scenario}'.")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="radio_bridge.simulator", description="Bộ đàm HP682 giả gửi báo động tới bridge")
    ap.add_argument("--target", default="127.0.0.1:3005", help="host:port UDP của bridge")
    ap.add_argument("--radio", type=int, default=1001, help="Radio ID")
    ap.add_argument("--via", choices=("status", "repeater"), default="status")
    ap.add_argument("--scenario", choices=("serve", "sos", "man_down", "lone_worker", "presence"), default="serve",
                    help="serve = bật máy liên tục, trả lời lệnh từ iZii, gõ lệnh tay")
    ap.add_argument("--lone-worker", choices=("on", "off"), default="off", help="trạng thái Lone Worker lúc bật máy")
    ap.add_argument("--lw-response", type=float, default=120.0, help="Lone Worker Response Time (giây)")
    ap.add_argument("--lw-reminder", type=float, default=30.0, help="Lone Worker Reminder Time (giây)")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    asyncio.run(_run_cli(a))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
