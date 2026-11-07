"""
Giao hàng bền vững sang iZiiServer.

Báo động tính mạng không được mất vì mạng/server tạm lỗi hay bridge khởi động lại, nên MỖI sự kiện
được ghi ra đĩa (spool/<id>.json) TRƯỚC khi gửi và chỉ xoá sau khi server trả 200. Khởi động lại sẽ
nạp lại phần còn tồn đọng. gateway_event_id giữ nguyên qua mọi lần thử lại nên server bỏ qua bản trùng.

Phân loại phản hồi:
  200            → xong, xoá spool (nếu `rejected` không rỗng: gói sai định dạng, thử lại vô ích → dead/)
  401/403/503    → lỗi cấu hình (sai token, server chưa đặt secret): GIỮ và thử lại — sửa cấu hình là hết
  408/429/5xx    → tạm thời: thử lại
  4xx khác       → payload hỏng: chuyển dead/, không thử lại vĩnh viễn
  lỗi mạng       → thử lại
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import shutil
from typing import Any, Dict, Optional

import httpx

from .config import BridgeConfig

log = logging.getLogger("radio_bridge.delivery")

RETRY_STATUS = {401, 403, 408, 429, 503}


class Delivery:
    def __init__(self, cfg: BridgeConfig, transport: Optional[httpx.AsyncBaseTransport] = None):
        self.cfg = cfg
        self.url = cfg.izii_url.rstrip("/") + "/api/v1/radio/events"
        self.spool = os.path.abspath(cfg.spool_dir)
        self.dead = os.path.join(self.spool, "dead")
        os.makedirs(self.dead, exist_ok=True)
        self._client = httpx.AsyncClient(timeout=cfg.request_timeout_s, transport=transport)
        self._q: "asyncio.Queue[str]" = asyncio.Queue()
        self._task: Optional[asyncio.Task] = None
        self.stats = {"delivered": 0, "retries": 0, "dead": 0, "spooled": 0}

    def _path(self, event_id: str) -> str:
        return os.path.join(self.spool, f"{event_id}.json")

    def start(self) -> None:
        # nạp lại phần tồn đọng từ lần chạy trước (theo thời gian tạo)
        pending = sorted(
            (f for f in os.listdir(self.spool) if f.endswith(".json")),
            key=lambda f: os.path.getmtime(os.path.join(self.spool, f)),
        )
        for f in pending:
            self._q.put_nowait(f[:-5])
        if pending:
            log.warning("Nạp lại %d sự kiện chưa giao từ spool", len(pending))
        self._task = asyncio.get_running_loop().create_task(self._run())

    def submit(self, payload: Dict[str, Any]) -> None:
        event_id = payload["gateway_event_id"]
        tmp = self._path(event_id) + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, self._path(event_id))
        self.stats["spooled"] += 1
        self._q.put_nowait(event_id)

    async def drain(self, timeout: float = 5.0) -> bool:
        """Chờ hàng đợi rỗng (dùng khi tắt bridge và trong test)."""
        try:
            await asyncio.wait_for(self._q.join(), timeout)
            return True
        except asyncio.TimeoutError:
            return False

    async def close(self) -> None:
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        await self._client.aclose()

    async def _run(self) -> None:
        while True:
            event_id = await self._q.get()
            try:
                await self._deliver(event_id)
            except asyncio.CancelledError:
                raise
            except Exception:
                log.exception("Lỗi không mong đợi khi giao %s — giữ trong spool", event_id)
            finally:
                self._q.task_done()

    def _headers(self) -> Dict[str, str]:
        return {"Authorization": f"Bearer {self.cfg.token}", "Content-Type": "application/json"}

    async def _deliver(self, event_id: str) -> None:
        path = self._path(event_id)
        try:
            with open(path, encoding="utf-8") as fh:
                payload = json.load(fh)
        except FileNotFoundError:
            return
        backoff = self.cfg.retry_initial_s
        while True:
            try:
                resp = await self._client.post(self.url, json=payload, headers=self._headers())
            except httpx.HTTPError as e:
                log.warning("Giao %s lỗi mạng (%s) — thử lại sau %.1fs", event_id, type(e).__name__, backoff)
            else:
                code = resp.status_code
                if code == 200:
                    body: Dict[str, Any] = {}
                    try:
                        body = resp.json()
                    except Exception:
                        pass
                    if body.get("rejected"):
                        log.error("Server từ chối %s: %s", event_id, body["rejected"])
                        self._to_dead(path)
                    else:
                        os.remove(path)
                        self.stats["delivered"] += 1
                        log.info("Đã giao %s (%s radio=%s)", event_id, payload.get("event_type"), payload.get("radio_id"))
                    return
                if code in RETRY_STATUS or code >= 500:
                    log.error("Giao %s nhận HTTP %s — thử lại sau %.1fs", event_id, code, backoff)
                else:
                    log.error("Giao %s nhận HTTP %s (payload hỏng) — chuyển dead/: %s", event_id, code, resp.text[:200])
                    self._to_dead(path)
                    return
            self.stats["retries"] += 1
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, self.cfg.retry_max_s)

    def _to_dead(self, path: str) -> None:
        shutil.move(path, os.path.join(self.dead, os.path.basename(path)))
        self.stats["dead"] += 1
