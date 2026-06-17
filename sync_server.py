import json
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timedelta

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Track 1 — Sync Engine (existing)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
db = {
    'updates': []  # list of all mutations synced to the server
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Track 3 — Device Identity & E2EE Messaging
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# device_id -> {device_id, user_id, public_key, signing_public_key, device_name, platform, registered_at, last_seen_at}
device_registry = {}
# list of encrypted message envelopes
message_queue = []
# append-only trust events (for Phase 3)
trust_ledger = []


class SyncMockHandler(BaseHTTPRequestHandler):

    # ── helpers ──────────────────────────────────────────────────

    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def _read_json_body(self):
        content_length = int(self.headers.get('Content-Length', 0))
        raw = self.rfile.read(content_length)
        return json.loads(raw.decode('utf-8'))

    def _write_json(self, data, status=200):
        self._set_headers(status)
        self.wfile.write(json.dumps(data, default=str).encode('utf-8'))

    # suppress default access log (we provide our own pretty logs)
    def log_message(self, format, *args):
        pass

    # ── OPTIONS (CORS preflight) ─────────────────────────────────

    def do_OPTIONS(self):
        self._set_headers(200)

    # ══════════════════════════════════════════════════════════════
    #  POST routes
    # ══════════════════════════════════════════════════════════════

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip('/')

        # ── Track 1: Sync Push ───────────────────────────────────
        if path == '/sync/push':
            self._handle_sync_push()

        # ── Track 3: Device Register ─────────────────────────────
        elif path == '/api/v1/devices/register':
            self._handle_device_register()

        # ── Track 3: Device Heartbeat ────────────────────────────
        elif path == '/api/v1/devices/heartbeat':
            self._handle_device_heartbeat()

        # ── Track 3: Send E2EE Message ───────────────────────────
        elif path == '/api/v1/messages/send':
            self._handle_message_send()

        # ── Track 3: Acknowledge Messages ────────────────────────
        elif path == '/api/v1/messages/ack':
            self._handle_message_ack()

        else:
            self._write_json({'error': 'Not Found'}, 404)

    # ══════════════════════════════════════════════════════════════
    #  GET routes
    # ══════════════════════════════════════════════════════════════

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip('/')
        params = parse_qs(parsed.query)

        # ── Track 1: Sync Pull ───────────────────────────────────
        if path == '/sync/pull':
            self._handle_sync_pull(params)

        # ── Track 1: Sync Status ─────────────────────────────────
        elif path == '/sync/status':
            self._handle_sync_status()

        # ── Track 3: Online Devices ──────────────────────────────
        elif path == '/api/v1/devices/online':
            self._handle_devices_online(params)

        # ── Track 3: Pending Messages ────────────────────────────
        elif path == '/api/v1/messages/pending':
            self._handle_messages_pending(params)

        # ── Track 3: Device Key Lookup  (/api/v1/devices/{id}/key)
        elif path.startswith('/api/v1/devices/') and path.endswith('/key'):
            self._handle_device_key_lookup(path)

        else:
            self._write_json({'error': 'Not Found'}, 404)

    # ══════════════════════════════════════════════════════════════
    #  Track 1 — Sync handlers (original logic, untouched)
    # ══════════════════════════════════════════════════════════════

    def _handle_sync_push(self):
        payload = self._read_json_body()
        mutations = payload.get('mutations', [])
        now = datetime.now().isoformat()

        print(f"\n{'='*50}")
        print(f"📥 [PUSH] Nhận được {len(mutations)} thay đổi lúc {now}")
        print(f"{'='*50}")
        for i, m in enumerate(mutations):
            table = m.get('table', '?')
            op = m.get('operation', '?')
            data = m.get('data', {})
            # Add server receive timestamp for filtering
            m['server_received_at'] = now
            db['updates'].append(m)
            print(f"   [{i+1}] 🔹 Bảng: {table} | Thao tác: {op}")
            # Show key fields from data
            if isinstance(data, dict):
                for key, val in data.items():
                    val_str = str(val)[:80]
                    print(f"       - {key}: {val_str}")
        print(f"\n📊 Tổng số bản ghi trên Server: {len(db['updates'])}")

        self._write_json({
            'status': 'success',
            'message': f'Đã nhận {len(mutations)} mutations thành công!',
            'total_records': len(db['updates']),
        })

    def _handle_sync_pull(self, params):
        since = params.get('since', [None])[0]

        # Filter updates by 'since' timestamp if provided
        updates_to_send = db['updates']
        if since:
            try:
                since_dt = datetime.fromisoformat(since.replace('Z', '+00:00'))
                updates_to_send = [
                    u for u in db['updates']
                    if u.get('server_received_at', '') > since
                ]
            except Exception:
                pass  # If parsing fails, send all

        now = datetime.now().isoformat()
        print(f"\n📤 [PULL] Thiết bị đang tải về các cập nhật mới...")
        if since:
            print(f"   🕐 Lọc từ: {since}")
        print(f"   📦 Gửi {len(updates_to_send)}/{len(db['updates'])} bản ghi")

        self._write_json({
            'updates': updates_to_send,
            'timestamp': now,
            'total_on_server': len(db['updates']),
        })
        print(f"   ✅ Đã gửi {len(updates_to_send)} cập nhật cho thiết bị.")

    def _handle_sync_status(self):
        tables = {}
        for u in db['updates']:
            t = u.get('table', 'unknown')
            tables[t] = tables.get(t, 0) + 1
        self._write_json({
            'total_records': len(db['updates']),
            'tables': tables,
        })

    # ══════════════════════════════════════════════════════════════
    #  Track 3 — Device Identity handlers
    # ══════════════════════════════════════════════════════════════

    def _handle_device_register(self):
        body = self._read_json_body()
        now = datetime.now().isoformat()

        device_id = body.get('device_id')
        user_id = body.get('user_id')
        public_key = body.get('public_key') or body.get('public_key_base64')
        signing_public_key = body.get('signing_public_key') or body.get('signing_public_key_base64')
        device_name = body.get('device_name', 'Unknown Device')
        platform = body.get('platform', 'unknown')

        # Generate a short human-readable fingerprint from the public key
        import hashlib
        fingerprint = ''
        if public_key:
            fp_hash = hashlib.sha256(public_key.encode()).hexdigest()
            fingerprint = fp_hash[:8].upper()

        if not device_id or not user_id or not public_key:
            self._write_json({
                'status': 'error',
                'message': 'Missing required fields: device_id, user_id, public_key',
            }, 400)
            return

        device_info = {
            'device_id': device_id,
            'user_id': user_id,
            'public_key': public_key,
            'signing_public_key': signing_public_key,
            'device_name': device_name,
            'platform': platform,
            'fingerprint': fingerprint,
            'registered_at': now,
            'last_seen_at': now,
        }

        device_registry[device_id] = device_info

        print(f"\n🔐 [DEVICE] Registered: {device_name} ({platform}) DID: {device_id[:16]}...")
        print(f"   👤 User: {user_id}")
        print(f"   🔑 Public key: {public_key[:32]}...")
        print(f"   📋 Total registered devices: {len(device_registry)}")

        self._write_json({
            'status': 'success',
            'message': 'Device registered successfully',
            'device': device_info,
        })

    def _handle_device_heartbeat(self):
        body = self._read_json_body()
        device_id = body.get('device_id')

        if not device_id or device_id not in device_registry:
            self._write_json({
                'status': 'error',
                'message': 'Device not found in registry',
            }, 404)
            return

        device_registry[device_id]['last_seen_at'] = datetime.now().isoformat()

        # No verbose logging — heartbeats are frequent
        self._write_json({
            'status': 'success',
            'message': 'Heartbeat received',
        })

    def _handle_devices_online(self, params):
        user_id_filter = params.get('user_id', [None])[0]
        exclude_device_id = params.get('exclude_device_id', [None])[0]
        now = datetime.now()
        online_threshold = timedelta(seconds=45)
        idle_threshold = timedelta(minutes=2)

        devices = []
        for dev in device_registry.values():
            # optional user_id filter
            if user_id_filter and dev.get('user_id') != user_id_filter:
                continue

            # self-exclusion
            if exclude_device_id and dev.get('device_id') == exclude_device_id:
                continue

            try:
                last_seen = datetime.fromisoformat(dev['last_seen_at'])
            except (ValueError, KeyError):
                continue

            elapsed = now - last_seen
            if elapsed <= online_threshold:
                status = 'online'
            elif elapsed <= idle_threshold:
                status = 'idle'
            else:
                # skip devices that are fully offline (beyond 2 min)
                continue

            devices.append({
                'device_id': dev['device_id'],
                'user_id': dev['user_id'],
                'device_name': dev['device_name'],
                'platform': dev['platform'],
                'public_key_base64': dev.get('public_key', ''),
                'signing_public_key_base64': dev.get('signing_public_key', ''),
                'registered_at': dev.get('registered_at', ''),
                'fingerprint': dev.get('fingerprint', ''),
                'last_seen_at': dev['last_seen_at'],
                'status': status,
            })

        print(f"\n📡 [ONLINE] Queried online devices → {len(devices)} active")

        self._write_json({'devices': devices})

    def _handle_device_key_lookup(self, path):
        # Extract device_id from /api/v1/devices/{device_id}/key
        parts = path.split('/')
        # ['', 'api', 'v1', 'devices', '{device_id}', 'key']
        if len(parts) < 6:
            self._write_json({'error': 'Invalid path'}, 400)
            return

        device_id = parts[4]
        dev = device_registry.get(device_id)

        if not dev:
            self._write_json({'error': 'Device not found'}, 404)
            return

        print(f"\n🔑 [KEY] Key lookup for device: {dev['device_name']} DID: {device_id[:16]}...")

        self._write_json({
            'device_id': dev['device_id'],
            'public_key': dev['public_key'],
            'signing_public_key': dev.get('signing_public_key'),
            'device_name': dev['device_name'],
            'platform': dev['platform'],
        })

    # ══════════════════════════════════════════════════════════════
    #  Track 3 — E2EE Messaging handlers
    # ══════════════════════════════════════════════════════════════

    def _handle_message_send(self):
        body = self._read_json_body()

        conversation_id = body.get('conversation_id')
        sender_device_id = body.get('sender_device_id')
        payloads = body.get('payloads', {})

        if not conversation_id or not sender_device_id or not payloads:
            self._write_json({
                'status': 'error',
                'message': 'Missing required fields: conversation_id, sender_device_id, payloads',
            }, 400)
            return

        now = datetime.now().isoformat()
        created_ids = []

        for recipient_device_id, encrypted_payload in payloads.items():
            msg_id = str(uuid.uuid4())
            envelope = {
                'id': msg_id,
                'conversation_id': conversation_id,
                'sender_device_id': sender_device_id,
                'recipient_device_id': recipient_device_id,
                'ciphertext': encrypted_payload.get('ciphertext'),
                'nonce': encrypted_payload.get('nonce'),
                'signature': encrypted_payload.get('signature'),
                'sent_at': now,
                'delivered_at': None,
            }
            message_queue.append(envelope)
            created_ids.append(msg_id)

        sender_short = sender_device_id[:16] if sender_device_id else '???'
        print(f"\n📨 [E2EE] Message from {sender_short} → {len(payloads)} devices (encrypted, server CANNOT read)")
        print(f"   💬 Conversation: {conversation_id}")
        print(f"   📬 Envelopes created: {len(created_ids)}")
        print(f"   📦 Total messages in queue: {len(message_queue)}")

        self._write_json({
            'status': 'success',
            'message': f'Sent to {len(payloads)} device(s)',
            'message_ids': created_ids,
        })

    def _handle_messages_pending(self, params):
        device_id = params.get('device_id', [None])[0]

        if not device_id:
            self._write_json({
                'status': 'error',
                'message': 'Missing required query parameter: device_id',
            }, 400)
            return

        pending = [
            msg for msg in message_queue
            if msg['recipient_device_id'] == device_id and msg['delivered_at'] is None
        ]

        if pending:
            print(f"\n📬 [PENDING] {len(pending)} message(s) waiting for device {device_id[:16]}...")

        self._write_json({'messages': pending})

    def _handle_message_ack(self):
        body = self._read_json_body()
        message_ids = body.get('message_ids', [])

        if not message_ids:
            self._write_json({
                'status': 'error',
                'message': 'Missing required field: message_ids',
            }, 400)
            return

        now = datetime.now().isoformat()
        acked_count = 0
        ids_set = set(message_ids)

        for msg in message_queue:
            if msg['id'] in ids_set and msg['delivered_at'] is None:
                msg['delivered_at'] = now
                acked_count += 1

        print(f"\n✅ [ACK] Acknowledged {acked_count}/{len(message_ids)} message(s)")

        self._write_json({
            'status': 'success',
            'message': f'Acknowledged {acked_count} message(s)',
            'acknowledged': acked_count,
        })


# ══════════════════════════════════════════════════════════════════
#  Server startup
# ══════════════════════════════════════════════════════════════════

def run(server_class=HTTPServer, handler_class=SyncMockHandler, port=8080):
    server_address = ('0.0.0.0', port)
    httpd = server_class(server_address, handler_class)

    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║      🚀 iZiiApp Sync + E2EE Server — Track 1 & 3          ║")
    print("╠══════════════════════════════════════════════════════════════╣")
    print(f"║  🌐 Local:   http://127.0.0.1:{port:<26}║")
    print(f"║  📡 WiFi:    http://<IP_máy_tính>:{port:<21}║")
    print("╠══════════════════════════════════════════════════════════════╣")
    print("║  📂 Track 1 — Sync Engine                                  ║")
    print("║     POST /sync/push          Push mutations                ║")
    print("║     GET  /sync/pull          Pull updates (?since=)        ║")
    print("║     GET  /sync/status        Server status                 ║")
    print("╠══════════════════════════════════════════════════════════════╣")
    print("║  🔐 Track 3 — Device Identity                              ║")
    print("║     POST /api/v1/devices/register     Register device      ║")
    print("║     POST /api/v1/devices/heartbeat    Heartbeat            ║")
    print("║     GET  /api/v1/devices/online       Online devices       ║")
    print("║     GET  /api/v1/devices/{id}/key     Public key lookup    ║")
    print("╠══════════════════════════════════════════════════════════════╣")
    print("║  📨 Track 3 — E2EE Messaging (relay only)                  ║")
    print("║     POST /api/v1/messages/send        Send encrypted msg   ║")
    print("║     GET  /api/v1/messages/pending     Fetch pending msgs   ║")
    print("║     POST /api/v1/messages/ack         Acknowledge delivery ║")
    print("╠══════════════════════════════════════════════════════════════╣")
    print("║  ⚠️  Server is a RELAY ONLY — it CANNOT decrypt messages    ║")
    print("║  🛑 Press Ctrl + C to stop the server                      ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    print("\n🛑 Đang dừng server...")


if __name__ == '__main__':
    run()
