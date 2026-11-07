"""
Chiều xuống: lấy lệnh từ iZiiServer, gửi xuống bộ đàm, báo kết quả lại.

    GET  /api/v1/radio/bridge/commands               → các lệnh cần gửi (server "cho thuê" 30 s)
    POST /api/v1/radio/bridge/commands/{id}/result   → {ok, result, error}

Lệnh hỗ trợ: lone_worker_status | lone_worker_enable | lone_worker_disable | text_message.
Không báo được kết quả (mạng rớt) thì server cấp lại lệnh khi hết hạn thuê — nghĩa là một tin nhắn có thể
tới bộ đàm hai lần; chấp nhận được, vì mất tin "time out" tệ hơn nhiều so với nhận trùng.
"""
from __future__ import annotations

import asyncio
import logging
from typing import Any, Dict, Optional

import httpx

from .codec import (
    OP_FUNC_ENABLE_REPLY,
    OP_FUNC_STATUS_REPLY,
    lone_worker_set_request,
    lone_worker_status_request,
    parse_lone_worker_reply,
    text_message,
)

log = logging.getLogger("radio_bridge.commands")


class CommandWorker:
    def __init__(self, bridge, transport: Optional[httpx.AsyncBaseTransport] = None):
        self.bridge = bridge
        self.cfg = bridge.cfg
        base = self.cfg.izii_url.rstrip("/") + "/api/v1/radio/bridge/commands"
        self.claim_url = base
        self.result_url = base + "/{id}/result"
        self._client = httpx.AsyncClient(timeout=self.cfg.request_timeout_s, transport=transport)
        self._task: Optional[asyncio.Task] = None
        self._running: set = set()
        self._req_id = 0
        self.stats = {"received": 0, "ok": 0, "failed": 0, "poll_errors": 0}

    def _headers(self) -> Dict[str, str]:
        return {"Authorization": f"Bearer {self.cfg.token}"}

    def start(self) -> None:
        self._task = asyncio.get_running_loop().create_task(self._poll_loop())

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        for t in list(self._running):
            t.cancel()
        await self._client.aclose()

    async def _poll_loop(self) -> None:
        while True:
            try:
                resp = await self._client.get(self.claim_url, headers=self._headers())
                if resp.status_code == 200:
                    for cmd in resp.json().get("commands", []):
                        self.stats["received"] += 1
                        t = asyncio.get_running_loop().create_task(self._run(cmd))
                        self._running.add(t)
                        t.add_done_callback(self._running.discard)
                else:
                    self.stats["poll_errors"] += 1
                    log.warning("Lấy lệnh: HTTP %s %s", resp.status_code, resp.text[:120])
            except httpx.HTTPError as e:
                self.stats["poll_errors"] += 1
                log.debug("Lấy lệnh lỗi mạng: %s", type(e).__name__)
            await asyncio.sleep(self.cfg.command_poll_s)

    async def _run(self, cmd: Dict[str, Any]) -> None:
        try:
            outcome = await self.execute(cmd)
        except Exception as e:  # không để một lệnh hỏng làm chết worker
            log.exception("Lệnh %s lỗi", cmd.get("id"))
            outcome = {"ok": False, "error": f"Lỗi bridge: {e}"}
        self.stats["ok" if outcome.get("ok") else "failed"] += 1
        log.info("Lệnh %s %s → radio %s: %s", cmd.get("id"), cmd.get("command"), cmd.get("radio_id"), outcome)
        body = {"ok": bool(outcome.get("ok")), "result": {k: v for k, v in outcome.items() if k not in ("ok", "error")} or None,
                "error": outcome.get("error")}
        for attempt in range(3):
            try:
                r = await self._client.post(self.result_url.format(id=cmd["id"]), json=body, headers=self._headers())
                if r.status_code == 200:
                    return
                log.warning("Báo kết quả lệnh %s: HTTP %s", cmd["id"], r.status_code)
            except httpx.HTTPError:
                pass
            await asyncio.sleep(0.5 * (attempt + 1))
        log.error("Không báo được kết quả lệnh %s — server sẽ cấp lại khi hết hạn thuê", cmd["id"])

    async def execute(self, cmd: Dict[str, Any]) -> Dict[str, Any]:
        try:
            radio_id = int(str(cmd["radio_id"]))
        except ValueError:
            return {"ok": False, "error": f"Radio ID không hợp lệ: {cmd.get('radio_id')}"}
        name = cmd.get("command")
        if radio_id not in self.bridge.radio_addr:
            return {"ok": False, "error": "Bộ đàm chưa liên lạc với bridge (chưa bật máy hoặc chưa đăng ký)"}

        if name == "text_message":
            text = str((cmd.get("params") or {}).get("text") or "")
            self._req_id = (self._req_id % 0xFFFFFFF0) + 1
            key = ("tmp", self._req_id)
            reply = await self._send_and_wait(radio_id, text_message(radio_id, self._req_id, text, self.cfg.dispatcher_id), key)
            if reply is None:
                return {"ok": False, "error": f"Bộ đàm không xác nhận tin nhắn trong {self.cfg.command_timeout_s:g}s"}
            code = getattr(reply, "name", str(reply))
            return {"ok": True, "delivered": True, "text": text} if code == "OK" else {"ok": False, "error": f"Bộ đàm báo {code}"}

        if name == "lone_worker_status":
            pdu, reply_op = lone_worker_status_request(), OP_FUNC_STATUS_REPLY
        elif name in ("lone_worker_enable", "lone_worker_disable"):
            pdu, reply_op = lone_worker_set_request(name == "lone_worker_enable"), OP_FUNC_ENABLE_REPLY
        else:
            return {"ok": False, "error": f"Bridge không hỗ trợ lệnh {name}"}
        payload = await self._send_and_wait(radio_id, pdu, ("rcp", radio_id, reply_op))
        if payload is None:
            return {"ok": False, "error": f"Bộ đàm không trả lời trong {self.cfg.command_timeout_s:g}s"}
        out = parse_lone_worker_reply(reply_op, payload)
        if out.get("ok") and name != "lone_worker_status":
            out["lone_worker"] = "on" if name == "lone_worker_enable" else "off"
        return out

    async def _send_and_wait(self, radio_id: int, pdu: Any, key: tuple) -> Any:
        fut = self.bridge.expect(key)
        try:
            if not self.bridge.send_to_radio(radio_id, pdu):
                return None
            return await asyncio.wait_for(fut, self.cfg.command_timeout_s)
        except asyncio.TimeoutError:
            return None
        finally:
            self.bridge.forget(key)
