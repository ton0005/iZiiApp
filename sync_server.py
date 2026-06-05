import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime

# In-memory database of synced mutations
db = {
    'updates': []  # list of all mutations synced to the server
}

class SyncMockHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_POST(self):
        if self.path == '/sync/push':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))

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

            self._set_headers(200)
            self.wfile.write(json.dumps({
                'status': 'success',
                'message': f'Đã nhận {len(mutations)} mutations thành công!',
                'total_records': len(db['updates']),
            }).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({'error': 'Not Found'}).encode('utf-8'))

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/sync/pull':
            params = parse_qs(parsed.query)
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

            self._set_headers(200)
            self.wfile.write(json.dumps({
                'updates': updates_to_send,
                'timestamp': now,
                'total_on_server': len(db['updates']),
            }).encode('utf-8'))
            print(f"   ✅ Đã gửi {len(updates_to_send)} cập nhật cho thiết bị.")
        elif parsed.path == '/sync/status':
            self._set_headers(200)
            tables = {}
            for u in db['updates']:
                t = u.get('table', 'unknown')
                tables[t] = tables.get(t, 0) + 1
            self.wfile.write(json.dumps({
                'total_records': len(db['updates']),
                'tables': tables,
            }).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({'error': 'Not Found'}).encode('utf-8'))

def run(server_class=HTTPServer, handler_class=SyncMockHandler, port=8080):
    server_address = ('0.0.0.0', port)
    httpd = server_class(server_address, handler_class)
    print("=" * 60)
    print(f"🚀 MOCK SYNC SERVER ĐANG CHẠY TẠI CỔNG: {port}")
    print(f"  -> Truy cập local:  http://127.0.0.1:{port}")
    print(f"  -> Truy cập WiFi:   http://<IP_máy_tính>:{port}")
    print(f"  -> Kiểm tra trạng thái: http://127.0.0.1:{port}/sync/status")
    print("  -> Nhấn Ctrl + C để dừng server.")
    print("=" * 60)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    print("\n🛑 Đang dừng server...")

if __name__ == '__main__':
    run()

