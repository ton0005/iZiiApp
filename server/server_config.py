# server/server_config.py
"""
Cấu hình định danh server cho kiến trúc multi-server.

Mỗi PC/laptop chạy server sẽ có file .env riêng (hoặc biến môi trường hệ
thống) định nghĩa server_id, zone, và danh sách peer server khác — KHÔNG
hard-code trong code để cùng 1 bản build có thể deploy cho cả 3 server
(Server-M1, Server-M2, Server-CR) chỉ bằng cách đổi .env.

Ví dụ file .env trên máy chạy Server-M1:

    IZIIAPP_SERVER_ID=server-m1
    IZIIAPP_ZONE=M1
    IZIIAPP_PEERS=http://192.168.1.11:8080,http://192.168.1.12:8080
    IZIIAPP_SYNC_INTERVAL_SECONDS=45
"""
import os
import sys
import io
from dataclasses import dataclass, field

# Ensure UTF-8 output encoding on Windows consoles
if sys.platform.startswith('win'):
    try:
        if hasattr(sys.stdout, 'reconfigure'):
            sys.stdout.reconfigure(encoding='utf-8', errors='replace')
            sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass


def _load_env_file():
    """
    Lightweight .env file parser so server loads environment variables automatically
    without requiring external libraries or manual OS export.
    """
    candidate_paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"),
        os.path.join(os.getcwd(), ".env"),
    ]
    if getattr(sys, 'frozen', False):
        # Bản đóng gói PyInstaller: __file__ trỏ vào thư mục giải nén tạm
        # (_MEIxxxx) chứ không phải chỗ đặt .exe, nên hai đường dẫn trên đều
        # trượt. Đây là nguyên nhân bản Release chạy mà KHÔNG đọc được .env:
        # IZIIAPP_WS_SECRET rỗng → WebSocket /chat từ chối mọi kết nối (log
        # 11/08 có 1713 lần trả 403), chat vẫn chạy nhờ HTTP polling nên lỗi
        # rất khó nhận ra.
        exe_dir = os.path.dirname(sys.executable)
        candidate_paths[0:0] = [
            os.path.join(exe_dir, ".env"),
            os.path.join(exe_dir, "_internal", ".env"),
            os.path.join(exe_dir, "data", ".env"),
            # Bản one-folder có cấu trúc dist/izii_server/ — .env hay bị để ở
            # thư mục cha khi copy tay.
            os.path.join(os.path.dirname(exe_dir), ".env"),
        ]

    loaded_from = None
    for env_path in candidate_paths:
        if os.path.exists(env_path):
            try:
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#") or "=" not in line:
                            continue
                        k, v = line.split("=", 1)
                        k = k.strip()
                        v = v.strip().strip("'").strip('"')
                        if k and k not in os.environ:
                            os.environ[k] = v
                loaded_from = env_path
                break
            except Exception as e:
                print(f"⚠️  [CONFIG] Could not parse .env file at {env_path}: {e}")

    # Nói rõ đã đọc file nào — hoặc không đọc được file nào. Im lặng ở đây
    # nghĩa là người vận hành phải suy ra từ triệu chứng ở tận tầng WebSocket.
    if loaded_from:
        print(f"⚙️  [CONFIG] Đã nạp cấu hình từ {loaded_from}")
    else:
        print(
            "⚠️  [CONFIG] KHÔNG tìm thấy file .env. Đã tìm ở:\n"
            + "\n".join(f"      • {p}" for p in candidate_paths)
            + "\n      Server sẽ chạy bằng biến môi trường của hệ điều hành. "
            "Nếu chưa set gì thì WebSocket /chat sẽ từ chối mọi kết nối."
        )


# Load .env file automatically on module import
_load_env_file()


def _parse_peers(raw: str) -> list[str]:
    return [p.strip().rstrip("/") for p in raw.split(",") if p.strip()]


@dataclass
class ServerConfig:
    server_id: str
    zone: str
    peers: list[str] = field(default_factory=list)
    sync_interval_seconds: int = 45
    # ── Phân tách phạm vi bí mật (B1) ────────────────────────────────────────
    # server_secret : CHỈ dùng cho /peer-sync/* — server nói chuyện với server.
    # admin_secret  : CHỈ dùng cho /admin/*    — thao tác quản trị nguy hiểm.
    # ws_secret     : CHỈ dùng cho /chat       — WebSocket realtime.
    # device token  : cấp riêng cho TỪNG thiết bị, xem bảng device_tokens.
    #
    # Trước đây cả ba dùng chung một chuỗi, nghĩa là thiết bị nào biết token
    # đồng bộ cũng gọi được /admin/reset (xoá sạch DB) và /admin/config (ghi
    # đè .env). Tách ra để một máy công nhân bị mất không kéo theo toàn hệ thống.
    server_secret: str = ""
    admin_secret: str = ""
    ws_secret: str = ""

    # Bật thì /sync/* yêu cầu device token hợp lệ. Mặc định TẮT để bản app cũ
    # chưa enroll vẫn chạy; bật sau khi toàn bộ thiết bị đã đăng ký xong.
    require_device_token: bool = False
    # Thời gian sống của vé mời đăng ký thiết bị (giây).
    enrollment_token_ttl: int = 600

    # ── 6.3 — Backend cơ sở dữ liệu ──────────────────────────────────────────
    # 'sqlite' (mặc định, chạy biên) hoặc 'postgres' (nhiều writer, nhiều site).
    db_backend: str = "sqlite"
    pg_dsn: str = ""
    pg_pool_min: int = 1
    pg_pool_max: int = 10

    # ── 6.4 — TLS / mTLS ─────────────────────────────────────────────────────
    # Bật khi có đủ 3 đường dẫn. Không set thì server chạy HTTP như cũ.
    tls_cert_file: str = ""
    tls_key_file: str = ""
    tls_ca_file: str = ""
    # True = BẮT BUỘC client trình chứng chỉ hợp lệ (mTLS thực thụ).
    tls_require_client_cert: bool = False
    # Danh sách CN được phép peer-sync, phân tách bằng dấu phẩy. Để trống =
    # chấp nhận mọi chứng chỉ do CA của mình ký.
    tls_allowed_peer_cns: list[str] = field(default_factory=list)

    # ── 6.4 — OAuth2 client credentials cho outbound (SAP, ERP khác) ─────────
    oauth_token_url: str = ""
    oauth_client_id: str = ""
    oauth_client_secret: str = ""
    oauth_scope: str = ""


def load_server_config() -> ServerConfig:
    server_id = os.environ.get("IZIIAPP_SERVER_ID", "server-standalone")
    zone = os.environ.get("IZIIAPP_ZONE", "default")
    peers_raw = os.environ.get("IZIIAPP_PEERS", "")
    interval = int(os.environ.get("IZIIAPP_SYNC_INTERVAL_SECONDS", "45"))
    secret = os.environ.get("IZIIAPP_SERVER_SECRET", "")
    ws_secret = os.environ.get("IZIIAPP_WS_SECRET", "")

    # Tương thích ngược: chưa khai IZIIAPP_ADMIN_SECRET thì tạm dùng chung
    # server secret như trước, nhưng cảnh báo rõ để admin biết mà tách ra.
    admin_secret = os.environ.get("IZIIAPP_ADMIN_SECRET", "")
    if not admin_secret and secret:
        admin_secret = secret
        try:
            print(
                "⚠️  [CONFIG] Chưa set IZIIAPP_ADMIN_SECRET — tạm dùng chung "
                "IZIIAPP_SERVER_SECRET cho /admin/*. Nghĩa là THIẾT BỊ NÀO biết "
                "token đồng bộ cũng gọi được /admin/reset và /admin/config. "
                "Hãy đặt một secret RIÊNG cho admin."
            )
        except Exception:
            pass

    require_device_token = os.environ.get(
        "IZIIAPP_REQUIRE_DEVICE_TOKEN", ""
    ).strip().lower() in ("1", "true", "yes")
    if not ws_secret and not secret:
        try:
            print(
                "⛔ [CONFIG] Chưa set IZIIAPP_WS_SECRET lẫn IZIIAPP_SERVER_SECRET — "
                "WebSocket /chat sẽ TỪ CHỐI mọi kết nối. Set 1 trong 2 biến này "
                "rồi khởi động lại server."
            )
        except Exception:
            pass
    if not secret:
        try:
            print(
                "⚠️  [CONFIG] IZIIAPP_SERVER_SECRET chưa được set — "
                "/peer-sync/* endpoints đang hoạt động ở chế độ mở (không yêu cầu X-iZii-Server-Token)."
            )
        except Exception:
            pass

    if server_id == "server-standalone":
        print(
            "⚠️  [CONFIG] IZIIAPP_SERVER_ID chưa được set — server đang chạy ở "
            "chế độ standalone (không tham gia multi-server sync). "
            "Set biến môi trường IZIIAPP_SERVER_ID / IZIIAPP_ZONE / IZIIAPP_PEERS "
            "nếu muốn tham gia mesh nhiều server."
        )

    db_backend = os.environ.get("IZIIAPP_DB_BACKEND", "sqlite").strip().lower()
    if db_backend not in ("sqlite", "postgres"):
        print(f"⚠️  [CONFIG] IZIIAPP_DB_BACKEND='{db_backend}' không hợp lệ — dùng 'sqlite'.")
        db_backend = "sqlite"

    pg_dsn = os.environ.get("IZIIAPP_PG_DSN", "")
    if db_backend == "postgres" and not pg_dsn:
        print(
            "⛔ [CONFIG] IZIIAPP_DB_BACKEND=postgres nhưng thiếu IZIIAPP_PG_DSN — "
            "quay về sqlite để server vẫn khởi động được."
        )
        db_backend = "sqlite"

    def _int_env(key: str, default: int) -> int:
        try:
            return int(os.environ.get(key, str(default)))
        except ValueError:
            return default

    tls_cert = os.environ.get("IZIIAPP_TLS_CERT_FILE", "")
    tls_key = os.environ.get("IZIIAPP_TLS_KEY_FILE", "")
    tls_ca = os.environ.get("IZIIAPP_TLS_CA_FILE", "")
    require_client_cert = os.environ.get(
        "IZIIAPP_TLS_REQUIRE_CLIENT_CERT", ""
    ).strip().lower() in ("1", "true", "yes")

    if require_client_cert and not tls_ca:
        print(
            "⛔ [CONFIG] Bật IZIIAPP_TLS_REQUIRE_CLIENT_CERT nhưng thiếu "
            "IZIIAPP_TLS_CA_FILE — không có CA thì không xác thực được client. "
            "Tắt yêu cầu client cert."
        )
        require_client_cert = False

    allowed_cns = [
        c.strip() for c in os.environ.get("IZIIAPP_TLS_ALLOWED_PEER_CNS", "").split(",") if c.strip()
    ]

    return ServerConfig(
        server_id=server_id,
        zone=zone,
        peers=_parse_peers(peers_raw),
        sync_interval_seconds=interval,
        server_secret=secret,
        admin_secret=admin_secret,
        ws_secret=ws_secret,
        require_device_token=require_device_token,
        enrollment_token_ttl=_int_env("IZIIAPP_ENROLLMENT_TOKEN_TTL", 600),
        db_backend=db_backend,
        pg_dsn=pg_dsn,
        pg_pool_min=_int_env("IZIIAPP_PG_POOL_MIN", 1),
        pg_pool_max=_int_env("IZIIAPP_PG_POOL_MAX", 10),
        tls_cert_file=tls_cert,
        tls_key_file=tls_key,
        tls_ca_file=tls_ca,
        tls_require_client_cert=require_client_cert,
        tls_allowed_peer_cns=allowed_cns,
        oauth_token_url=os.environ.get("IZIIAPP_OAUTH_TOKEN_URL", ""),
        oauth_client_id=os.environ.get("IZIIAPP_OAUTH_CLIENT_ID", ""),
        oauth_client_secret=os.environ.get("IZIIAPP_OAUTH_CLIENT_SECRET", ""),
        oauth_scope=os.environ.get("IZIIAPP_OAUTH_SCOPE", ""),
    )


CONFIG = load_server_config()
