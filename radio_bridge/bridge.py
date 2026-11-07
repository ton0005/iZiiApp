"""
Dịch vụ UDP của bridge: nhận khung HSTRP (ACK/heartbeat do ok-dmrlib lo), giải mã HDAP, đổi thành
sự kiện và đưa vào Delivery.

Bridge CHỈ LẮNG NGHE (passive). Nếu repeater thật yêu cầu bridge chủ động kết nối tới nó, tài liệu ADK
sẽ nói rõ — chưa kiểm chứng.
"""
from __future__ import annotations

import asyncio
import json
import logging
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from okdmr.dmrlib.hytera.pdu.hstrp import HSTRP, HSTRPPacketType
from okdmr.dmrlib.hytera.pdu.radio_registration_service import RadioRegistrationService
from okdmr.dmrlib.hytera.pdu.text_message_protocol import TextMessageProtocol, TMPService
from okdmr.dmrlib.protocols.hytera.hstrp_datagram_protocol import HSTRPDatagramProtocol

from .codec import (
    RAW_RCP_REPLIES,
    SOURCE_REPEATER,
    RadioEvent,
    events_from_hdap,
    parse_raw_rcp,
    radio_id_from_ip,
    service_name,
)
from .config import BridgeConfig
from .delivery import Delivery

log = logging.getLogger("radio_bridge")

DUP_WINDOW_S = 10.0


class BridgeProtocol(HSTRPDatagramProtocol):
    def __init__(self, bridge: "RadioBridge", port: int):
        super().__init__(port=port)
        self.bridge = bridge

    def datagram_received(self, data: bytes, addr: Tuple[Any, int]):
        return self.bridge.on_datagram(self, data, addr)


class RadioBridge:
    def __init__(self, cfg: BridgeConfig, delivery: Optional[Delivery] = None):
        self.cfg = cfg
        self.delivery = delivery or Delivery(cfg)
        self._transports: List[asyncio.DatagramTransport] = []
        self._stats_task: Optional[asyncio.Task] = None
        self._seen_pkts: Dict[Tuple[str, int, bytes], float] = {}
        self._repeater_last: Dict[Tuple[int, str], float] = {}
        self._capture = open(cfg.capture_file, "a", encoding="utf-8") if cfg.capture_file else None
        self.stats = {"datagrams": 0, "undecoded": 0, "duplicates": 0, "events": 0, "suppressed": 0, "alarms": 0}
        self.bound_ports: List[int] = []
        # Chiều xuống: bộ đàm nào đang ở địa chỉ nào (học từ gói nó gửi lên), và các phản hồi đang chờ.
        self.radio_addr: Dict[int, Tuple[BridgeProtocol, Tuple[Any, int]]] = {}
        self._pending: Dict[tuple, asyncio.Future] = {}
        self._down_sn = 0
        self.commands = None  # CommandWorker, gắn khi start()

    # ── vòng đời ────────────────────────────────────────────────────────────
    async def start(self) -> None:
        self.delivery.start()
        loop = asyncio.get_running_loop()
        for port in self.cfg.ports:
            proto = BridgeProtocol(self, port)
            transport, _ = await loop.create_datagram_endpoint(
                lambda p=proto: p, local_addr=(self.cfg.listen_host, port)
            )
            self._transports.append(transport)
            self.bound_ports.append(transport.get_extra_info("sockname")[1])
        log.info("Bridge lắng nghe UDP %s:%s → %s", self.cfg.listen_host, self.bound_ports, self.delivery.url)
        if self.cfg.stats_every_s > 0:
            self._stats_task = loop.create_task(self._log_stats())
        if self.cfg.commands_enabled:
            from .commands import CommandWorker

            self.commands = CommandWorker(self)
            self.commands.start()

    async def stop(self, drain_timeout: float = 5.0) -> None:
        if self._stats_task:
            self._stats_task.cancel()
        if self.commands:
            await self.commands.stop()
        for t in self._transports:
            t.close()
        # Sự kiện chưa giao vẫn nằm trong spool và được nạp lại ở lần chạy sau.
        await self.delivery.drain(timeout=drain_timeout)
        await self.delivery.close()
        if self._capture:
            self._capture.close()

    async def _log_stats(self) -> None:
        while True:
            await asyncio.sleep(self.cfg.stats_every_s)
            log.info("stats bridge=%s delivery=%s", self.stats, self.delivery.stats)

    # ── xử lý gói ───────────────────────────────────────────────────────────
    def on_datagram(self, proto: BridgeProtocol, data: bytes, addr: Tuple[Any, int]):
        self.stats["datagrams"] += 1
        if self._capture:
            self._capture.write(json.dumps({"ts": time.time(), "src": f"{addr[0]}:{addr[1]}", "port": proto.port, "hex": data.hex()}) + "\n")
            self._capture.flush()

        # Phản hồi lệnh Lone Worker: ok-dmrlib không giải mã được opcode này, xử lý trước để thư viện
        # khỏi log lỗi giả.
        if self._handle_raw_reply(proto, data, addr):
            return True, None

        # Gói dữ liệu gửi lại do mất ACK (cùng nguồn, sn, nội dung): vẫn ACK nhưng không xử lý lại.
        dup = self._is_duplicate(addr, data)
        handled, pdu = HSTRPDatagramProtocol.datagram_received(proto, data, addr)

        if pdu is None:
            if not handled:
                # Không giải mã được (opcode chưa cài, hỏng, hoặc không phải HSTRP). Không nuốt im lặng:
                # đây có thể là bản tin báo động mà thư viện chưa hỗ trợ.
                self.stats["undecoded"] += 1
                log.warning("KHÔNG GIẢI MÃ ĐƯỢC từ %s:%s (%d byte): %s", addr[0], addr[1], len(data), data.hex())
            return handled, pdu
        if dup:
            self.stats["duplicates"] += 1
            log.debug("Bỏ gói trùng sn=%s từ %s", pdu.sn, addr[0])
            return handled, pdu

        self._learn_address(proto, addr, pdu.payload)
        if isinstance(pdu.payload, TextMessageProtocol) and pdu.payload.opcode == TMPService.SendPrivateMessageAck:
            self._resolve(("tmp", pdu.payload.request_id), pdu.payload.result_code)
            return handled, pdu

        events = events_from_hdap(
            pdu.payload, addr[0],
            id_from_ip=self.cfg.id_from_ip,
            forward_lone_reminder=self.cfg.forward_lone_worker_reminder,
        )
        if not events:
            log.debug("Bỏ qua %s từ %s (không phải sự kiện cần chuyển): %r", service_name(pdu.payload), addr[0], pdu.payload)
        for ev in events:
            self.emit(ev)
        return handled, pdu

    def _is_duplicate(self, addr: Tuple[Any, int], data: bytes) -> bool:
        now = time.monotonic()
        for k in [k for k, t in self._seen_pkts.items() if now - t > DUP_WINDOW_S]:
            del self._seen_pkts[k]
        if len(data) < 8:  # connect/heartbeat/ack — không phải dữ liệu
            return False
        key = (str(addr[0]), int.from_bytes(data[4:6], "big"), data[6:])
        seen = key in self._seen_pkts
        self._seen_pkts[key] = now
        return seen

    def emit(self, ev: RadioEvent) -> None:
        if ev.source == SOURCE_REPEATER:
            now = time.monotonic()
            key = (ev.radio_id, ev.event_type)
            last = self._repeater_last.get(key)
            if last is not None and now - last < self.cfg.repeater_suppress_s:
                self.stats["suppressed"] += 1
                return
            self._repeater_last[key] = now
        payload: Dict[str, Any] = {
            # Sinh MỘT LẦN ở đây; mọi lần thử lại HTTP dùng lại id này nên server bỏ qua bản trùng.
            "gateway_event_id": uuid.uuid4().hex,
            "radio_id": str(ev.radio_id),
            "event_type": ev.event_type,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "system": "dmr",
            "bridge_source": ev.source,
        }
        payload.update({k: v for k, v in ev.extra.items() if k in ("latitude", "longitude")})
        if ev.extra:
            payload["detail"] = ev.extra
        self.stats["events"] += 1
        if ev.is_alarm:
            self.stats["alarms"] += 1
            log.warning("BÁO ĐỘNG %s radio=%s nguồn=%s", ev.event_type, ev.radio_id, ev.source)
        self.delivery.submit(payload)

    # ── chiều xuống ─────────────────────────────────────────────────────────
    def _learn_address(self, proto: BridgeProtocol, addr: Tuple[Any, int], payload: Any) -> None:
        rid = payload.radio_ip.radio_id if isinstance(payload, RadioRegistrationService) else None
        if rid is None and self.cfg.id_from_ip:
            rid = radio_id_from_ip(addr[0])
        if rid:
            self.radio_addr[rid] = (proto, addr)

    def _handle_raw_reply(self, proto: BridgeProtocol, data: bytes, addr: Tuple[Any, int]) -> bool:
        """Phản hồi RCP mà ok-dmrlib không giải mã (Lone Worker status/enable): tự ACK và khớp lệnh."""
        parsed = parse_raw_rcp(data)
        if not parsed or parsed[1] not in RAW_RCP_REPLIES:
            return False
        sn, opcode, payload = parsed
        proto.transport.sendto(HSTRP(pkt_type=HSTRPPacketType(is_ack=True), sn=sn).as_bytes(), addr)
        rid = radio_id_from_ip(addr[0]) if self.cfg.id_from_ip else None
        if rid:
            self.radio_addr[rid] = (proto, addr)
            self._resolve(("rcp", rid, opcode), payload)
        return True

    def _resolve(self, key: tuple, value: Any) -> None:
        fut = self._pending.pop(key, None)
        if fut and not fut.done():
            fut.set_result(value)

    def expect(self, key: tuple) -> "asyncio.Future":
        fut = asyncio.get_running_loop().create_future()
        self._pending[key] = fut
        return fut

    def forget(self, key: tuple) -> None:
        self._pending.pop(key, None)

    def send_to_radio(self, radio_id: int, hdap: Any) -> bool:
        """Gửi một PDU xuống bộ đàm qua địa chỉ đã học. False nếu bộ đàm chưa từng liên lạc."""
        target = self.radio_addr.get(radio_id)
        if not target or target[0].transport is None or target[0].transport.is_closing():
            return False
        proto, addr = target
        self._down_sn = (self._down_sn % 0xFFFE) + 1
        proto.transport.sendto(HSTRP(pkt_type=HSTRPPacketType(), payload=hdap, sn=self._down_sn).as_bytes(), addr)
        return True
