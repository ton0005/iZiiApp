"""Chạy: python -m radio_bridge --izii-url http://server:8080 (token qua IZII_RADIO_TOKEN)."""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys

from .bridge import RadioBridge
from .config import BridgeConfig


def main(argv=None) -> int:
    cfg = BridgeConfig.from_env()
    ap = argparse.ArgumentParser(prog="radio_bridge", description=__doc__)
    ap.add_argument("--izii-url", default=cfg.izii_url)
    ap.add_argument("--listen-host", default=cfg.listen_host)
    ap.add_argument("--ports", default=",".join(map(str, cfg.ports)), help="cổng UDP, phân tách bằng dấu phẩy")
    ap.add_argument("--spool-dir", default=cfg.spool_dir)
    ap.add_argument("--capture", default=cfg.capture_file, help="ghi mọi datagram thô (hex, JSONL) để phân tích với ADK")
    ap.add_argument("--forward-lone-reminder", action="store_true", default=cfg.forward_lone_worker_reminder)
    ap.add_argument("--log-level", default="INFO")
    a = ap.parse_args(argv)

    cfg.izii_url, cfg.listen_host, cfg.spool_dir = a.izii_url, a.listen_host, a.spool_dir
    cfg.ports = [int(p) for p in a.ports.split(",") if p.strip()]
    cfg.capture_file, cfg.forward_lone_worker_reminder = a.capture, a.forward_lone_reminder
    logging.basicConfig(level=a.log_level.upper(), format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    if not cfg.token:
        print("Thiếu IZII_RADIO_TOKEN (= IZIIAPP_RADIO_GATEWAY_SECRET của server).", file=sys.stderr)
        return 2

    async def run() -> None:
        bridge = RadioBridge(cfg)
        await bridge.start()
        try:
            await asyncio.Event().wait()
        finally:
            await bridge.stop()

    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
