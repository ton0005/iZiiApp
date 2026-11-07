"""
iZiiServer giả (chỉ endpoint /api/v1/radio/events) để test bridge không cần dựng server thật.

Kiểm token giống server thật (X-iZii-Radio-Token hoặc Bearer), có thể chèn lỗi (`fail_next`), và nếu tìm
thấy server/radio_events.py thì dùng chính hàm chuẩn hoá của server để đảm bảo bridge gửi đúng hợp đồng.
Chạy tay:  python -m radio_bridge.mock_izii --port 8080 --token secret
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict, List, Optional


def load_server_normalizer():
    """Nạp server/radio_events.py (module thuần, không phụ thuộc server). None nếu không thấy."""
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(os.path.dirname(here), "server", "radio_events.py")
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location("server_radio_events", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class MockIZii:
    def __init__(self, token: str = "secret", port: int = 0):
        self.token = token
        self.received: List[Dict[str, Any]] = []  # chỉ các request ĐƯỢC CHẤP NHẬN (200)
        self.attempts = 0
        self.normalized: List[Dict[str, Any]] = []
        self._fail: List[int] = []
        # Chiều xuống: lệnh xếp sẵn cho bridge và kết quả bridge báo về
        self.commands: Dict[str, Dict[str, Any]] = {}
        self._lock = threading.Lock()
        self._norm = load_server_normalizer()
        mock = self

        class H(BaseHTTPRequestHandler):
            def log_message(self, *a):  # im lặng
                pass

            def _reply(self, code: int, body: Dict[str, Any]) -> None:
                raw = json.dumps(body).encode()
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def _token_ok(self) -> bool:
                tok = self.headers.get("X-iZii-Radio-Token") or ""
                auth = self.headers.get("Authorization") or ""
                if not tok and auth.lower().startswith("bearer "):
                    tok = auth[7:].strip()
                return tok == mock.token

            def do_GET(self):
                if not self.path.startswith("/api/v1/radio/bridge/commands"):
                    return self._reply(404, {"detail": "not found"})
                if not self._token_ok():
                    return self._reply(401, {"detail": "bad token"})
                with mock._lock:
                    out = [dict(c) for c in mock.commands.values() if c["status"] == "pending"]
                    for c in out:
                        mock.commands[c["id"]]["status"] = "sent"
                return self._reply(200, {"commands": out})

            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                raw = self.rfile.read(length)
                if self.path.startswith("/api/v1/radio/bridge/commands/") and self.path.endswith("/result"):
                    if not self._token_ok():
                        return self._reply(401, {"detail": "bad token"})
                    cid = self.path.split("/")[-2]
                    body = json.loads(raw or b"{}")
                    with mock._lock:
                        if cid not in mock.commands:
                            return self._reply(404, {"detail": "unknown command"})
                        mock.commands[cid].update(
                            status="done" if body.get("ok") else "failed",
                            result=body.get("result"), error=body.get("error"),
                        )
                    return self._reply(200, {"status": "success"})
                with mock._lock:
                    mock.attempts += 1
                    if mock._fail:
                        return self._reply(mock._fail.pop(0), {"detail": "injected failure"})
                if self.path != "/api/v1/radio/events":
                    return self._reply(404, {"detail": "not found"})
                if not self._token_ok():
                    return self._reply(401, {"detail": "Invalid or missing X-iZii-Radio-Token"})
                try:
                    body = json.loads(raw)
                except Exception:
                    return self._reply(400, {"detail": "Body phải là JSON."})
                items = body.get("events") if isinstance(body, dict) and "events" in body else body
                items = [items] if isinstance(items, dict) else items
                rejected = []
                with mock._lock:
                    for i, it in enumerate(items):
                        if mock._norm:
                            try:
                                mock.normalized.append(mock._norm.normalize_event(it))
                            except Exception as e:  # RadioEventError
                                rejected.append({"index": i, "error": str(e)})
                                continue
                        mock.received.append(it)
                return self._reply(200, {"status": "success", "accepted": len(items) - len(rejected), "rejected": rejected})

        self.httpd = ThreadingHTTPServer(("127.0.0.1", port), H)
        self.port = self.httpd.server_address[1]
        self._thread: Optional[threading.Thread] = None

    @property
    def url(self) -> str:
        return f"http://127.0.0.1:{self.port}"

    def queue_command(self, radio_id, command: str, params: Optional[Dict[str, Any]] = None) -> str:
        with self._lock:
            cid = f"cmd{len(self.commands) + 1}"
            self.commands[cid] = {"id": cid, "radio_id": str(radio_id), "command": command,
                                  "params": params or {}, "status": "pending"}
            return cid

    def command(self, cid: str) -> Dict[str, Any]:
        with self._lock:
            return dict(self.commands[cid])

    def fail_next(self, n: int, code: int = 503) -> None:
        with self._lock:
            self._fail = [code] * n

    def start(self) -> "MockIZii":
        self._thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self._thread.start()
        return self

    def stop(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--token", default="secret")
    a = ap.parse_args()
    m = MockIZii(a.token, a.port).start()
    print(f"Mock iZiiServer tại {m.url} (token '{a.token}'). Ctrl+C để dừng.")
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
