# server/security_tls.py
"""
TLS / mTLS cho iZiiServer — 6.4.

VÌ SAO CẦN: xác thực hiện tại của /peer-sync/* là một chuỗi bí mật dùng chung
(`X-iZii-Server-Token`) nằm trong .env. Đội bảo mật của công ty lớn sẽ bác ngay,
vì:
  - Cùng một secret cho mọi server: lộ ở một máy là lộ cả mesh.
  - Không xoay vòng được nếu không sửa .env và khởi động lại tất cả.
  - Truyền qua HTTP thuần thì ai bắt gói tin trong LAN cũng đọc được.

mTLS giải quyết cả ba: mỗi server có chứng chỉ riêng do CA nội bộ ký, thu hồi
được từng cái một, và toàn bộ lưu lượng được mã hoá.

THIẾT KẾ: hoàn toàn TÙY CHỌN. Không set biến môi trường thì server chạy HTTP
như cũ, không có gì thay đổi. Bật dần từng bước:

  Bước 1 — chỉ TLS (mã hoá, chưa xác thực client):
      IZIIAPP_TLS_CERT_FILE=certs/server-m1.crt
      IZIIAPP_TLS_KEY_FILE=certs/server-m1.key

  Bước 2 — thêm mTLS (bắt buộc client trình chứng chỉ):
      IZIIAPP_TLS_CA_FILE=certs/izii-ca.crt
      IZIIAPP_TLS_REQUIRE_CLIENT_CERT=true

  Bước 3 — chỉ cho phép các CN cụ thể:
      IZIIAPP_TLS_ALLOWED_PEER_CNS=server-m1,server-m2,server-cr
"""
from __future__ import annotations

import os
import ssl
from typing import Any, Optional

from server_config import CONFIG


def tls_enabled() -> bool:
    """TLS chỉ bật khi có ĐỦ cả cert lẫn key và file thực sự tồn tại."""
    if not (CONFIG.tls_cert_file and CONFIG.tls_key_file):
        return False
    for path, label in ((CONFIG.tls_cert_file, "cert"), (CONFIG.tls_key_file, "key")):
        if not os.path.exists(path):
            print(f"⛔ [TLS] Không tìm thấy file {label}: {path} — chạy HTTP thuần.")
            return False
    return True


def mtls_enabled() -> bool:
    return tls_enabled() and CONFIG.tls_require_client_cert and bool(CONFIG.tls_ca_file)


def uvicorn_ssl_kwargs() -> dict:
    """
    Tham số SSL truyền thẳng vào uvicorn.run(). Trả về dict rỗng khi tắt TLS,
    nhờ vậy chỗ gọi chỉ cần `**uvicorn_ssl_kwargs()` mà không phải rẽ nhánh.
    """
    if not tls_enabled():
        return {}

    kwargs: dict[str, Any] = {
        "ssl_certfile": CONFIG.tls_cert_file,
        "ssl_keyfile": CONFIG.tls_key_file,
    }
    if CONFIG.tls_ca_file and os.path.exists(CONFIG.tls_ca_file):
        kwargs["ssl_ca_certs"] = CONFIG.tls_ca_file
        # CERT_REQUIRED = từ chối bắt tay nếu client không trình chứng chỉ hợp
        # lệ. Việc chặn diễn ra ở TẦNG TLS, trước cả khi request tới FastAPI —
        # đây là lớp phòng thủ mạnh hơn nhiều so với kiểm tra header.
        kwargs["ssl_cert_reqs"] = (
            ssl.CERT_REQUIRED if CONFIG.tls_require_client_cert else ssl.CERT_OPTIONAL
        )
    return kwargs


def httpx_client_kwargs() -> dict:
    """
    Tham số cho httpx.AsyncClient khi server này ĐI GỌI peer khác.

    Đối xứng với phía nhận: mỗi server vừa là client vừa là server trong mesh,
    nên phải trình đúng chứng chỉ của mình khi gọi sang.
    """
    if not tls_enabled():
        return {}

    kwargs: dict[str, Any] = {}
    # verify = đường dẫn CA để KIỂM TRA chứng chỉ của peer. Không đặt thì httpx
    # dùng CA hệ thống và sẽ từ chối chứng chỉ do CA nội bộ ký.
    if CONFIG.tls_ca_file and os.path.exists(CONFIG.tls_ca_file):
        kwargs["verify"] = CONFIG.tls_ca_file
    # cert = chứng chỉ CỦA MÌNH để peer xác thực ngược lại.
    kwargs["cert"] = (CONFIG.tls_cert_file, CONFIG.tls_key_file)
    return kwargs


def peer_base_url(host: str, port: int) -> str:
    return f"{'https' if tls_enabled() else 'http'}://{host}:{port}"


# ── Trích xuất danh tính từ chứng chỉ client ────────────────────────────────

def extract_client_cn(request) -> Optional[str]:
    """
    Lấy Common Name từ chứng chỉ mà client đã trình.

    Uvicorn đặt thông tin TLS vào scope["extensions"]["tls"] khi chạy HTTPS.
    Trả về None nếu không có mTLS hoặc không đọc được — bên gọi phải tự quyết
    định coi đó là lỗi hay không.
    """
    try:
        tls_info = request.scope.get("extensions", {}).get("tls") or {}
        peer_cert = tls_info.get("client_cert_chain") or tls_info.get("peercert")
        if not peer_cert:
            return None
        # peercert dạng dict của ssl: {'subject': ((('commonName', 'x'),),), ...}
        if isinstance(peer_cert, dict):
            for rdn in peer_cert.get("subject", ()):
                for key, value in rdn:
                    if key == "commonName":
                        return value
        return None
    except Exception:
        return None


def verify_peer_cn(request) -> Optional[str]:
    """
    Kiểm tra CN của peer có nằm trong danh sách cho phép không.

    Trả về thông báo lỗi (str) nếu KHÔNG hợp lệ, None nếu hợp lệ hoặc nếu
    không bật kiểm tra CN.

    Lưu ý: khi mTLS đã bật, TLS handshake đã đảm bảo chứng chỉ do CA của mình
    ký. Danh sách CN là lớp SIẾT THÊM — dùng khi CA của bạn còn ký chứng chỉ
    cho mục đích khác và bạn chỉ muốn cho một số server tham gia mesh.
    """
    if not CONFIG.tls_allowed_peer_cns:
        return None
    if not mtls_enabled():
        return None

    cn = extract_client_cn(request)
    if cn is None:
        return "Không đọc được Common Name từ chứng chỉ client."
    if cn not in CONFIG.tls_allowed_peer_cns:
        return f"CN '{cn}' không nằm trong IZIIAPP_TLS_ALLOWED_PEER_CNS."
    return None


def describe() -> str:
    """Một dòng mô tả tình trạng TLS, in lúc khởi động."""
    if not tls_enabled():
        return "🔓 [TLS] Tắt — server chạy HTTP thuần (chấp nhận được trong LAN cô lập)."
    if mtls_enabled():
        cns = ", ".join(CONFIG.tls_allowed_peer_cns) if CONFIG.tls_allowed_peer_cns else "(mọi CN do CA ký)"
        return f"🔐 [TLS] mTLS BẬT — bắt buộc chứng chỉ client. CN cho phép: {cns}"
    return "🔒 [TLS] Bật (chỉ mã hoá, CHƯA bắt buộc chứng chỉ client)."
