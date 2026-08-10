# server/oauth_client.py
"""
OAuth 2.0 Client Credentials — dùng khi iZiiServer GỌI RA hệ thống doanh nghiệp.

BỐI CẢNH: SAP S/4HANA gửi/nhận sự kiện qua Event Mesh trong SAP Integration
Suite, và cơ chế xác thực giữa hai bên là OAuth 2.0. Các API OData của SAP
Gateway cũng vậy. Không hệ thống ERP nghiêm túc nào chấp nhận một chuỗi bí mật
tĩnh trong header như `X-iZii-Server-Token`.

PHÂN BIỆT RÕ HAI CHIỀU — dễ nhầm:
  - VÀO  (peer server, thiết bị gọi iZii)  → mTLS + shared secret, xem
                                              security_tls.py
  - RA   (iZii gọi SAP/ERP)                → OAuth2 client credentials, file này

THIẾT KẾ: token được CACHE trong bộ nhớ và tự lấy mới trước khi hết hạn. Nếu
xin token mỗi lần gọi API thì vừa chậm vừa có khả năng bị SAP chặn vì lạm dụng
endpoint token.

Cấu hình trong .env:
    IZIIAPP_OAUTH_TOKEN_URL=https://<tenant>.authentication.<region>.hana.ondemand.com/oauth/token
    IZIIAPP_OAUTH_CLIENT_ID=sb-xxxx
    IZIIAPP_OAUTH_CLIENT_SECRET=...
    IZIIAPP_OAUTH_SCOPE=            # để trống nếu nhà cung cấp không yêu cầu
"""
from __future__ import annotations

import asyncio
import time
from typing import Optional

import httpx

from server_config import CONFIG

# Lấy token mới sớm hơn thời điểm hết hạn ngần này (giây), tránh trường hợp
# token hết hạn ngay giữa lúc request đang bay.
_EXPIRY_SKEW_SECONDS = 60


class OAuthTokenProvider:
    """
    Singleton giữ access token và tự làm mới.

    An toàn với concurrency: dùng asyncio.Lock để nhiều coroutine gọi cùng lúc
    chỉ phát sinh ĐÚNG MỘT request xin token, thay vì mỗi coroutine một cái.
    """

    _instance: Optional["OAuthTokenProvider"] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._token = None
            cls._instance._expires_at = 0.0
            cls._instance._lock = asyncio.Lock()
        return cls._instance

    @property
    def configured(self) -> bool:
        return bool(
            CONFIG.oauth_token_url
            and CONFIG.oauth_client_id
            and CONFIG.oauth_client_secret
        )

    def _is_valid(self) -> bool:
        return bool(self._token) and time.time() < (self._expires_at - _EXPIRY_SKEW_SECONDS)

    async def get_token(self, force_refresh: bool = False) -> Optional[str]:
        """
        Trả về access token còn hạn, hoặc None nếu chưa cấu hình OAuth.

        Trả None (thay vì ném lỗi) khi chưa cấu hình để phần tích hợp ERP là
        TÙY CHỌN — server vẫn chạy bình thường ở nhà máy chưa nối SAP.
        """
        if not self.configured:
            return None

        if not force_refresh and self._is_valid():
            return self._token

        async with self._lock:
            # Kiểm lại sau khi giành được lock: coroutine khác có thể vừa làm mới.
            if not force_refresh and self._is_valid():
                return self._token

            data = {
                "grant_type": "client_credentials",
                "client_id": CONFIG.oauth_client_id,
                "client_secret": CONFIG.oauth_client_secret,
            }
            if CONFIG.oauth_scope:
                data["scope"] = CONFIG.oauth_scope

            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    resp = await client.post(
                        CONFIG.oauth_token_url,
                        data=data,
                        headers={"Content-Type": "application/x-www-form-urlencoded"},
                    )
                resp.raise_for_status()
                body = resp.json()
            except Exception as e:
                print(f"⚠️  [OAUTH] Không lấy được access token: {e}")
                return None

            self._token = body.get("access_token")
            # expires_in là số giây; mặc định 3600 nếu nhà cung cấp không trả.
            try:
                expires_in = int(body.get("expires_in", 3600))
            except (TypeError, ValueError):
                expires_in = 3600
            self._expires_at = time.time() + expires_in

            print(f"🔑 [OAUTH] Đã lấy access token mới (hết hạn sau {expires_in}s).")
            return self._token

    async def auth_header(self) -> dict:
        """
        Header Authorization sẵn sàng gắn vào request. Trả dict rỗng nếu chưa
        cấu hình — chỗ gọi chỉ cần `headers={**await provider.auth_header()}`.
        """
        token = await self.get_token()
        return {"Authorization": f"Bearer {token}"} if token else {}

    def invalidate(self) -> None:
        """
        Vứt token đang giữ. Gọi khi nhận 401 từ ERP — token có thể đã bị thu
        hồi phía nhà cung cấp trước khi hết hạn.
        """
        self._token = None
        self._expires_at = 0.0


async def request_with_oauth(
    method: str,
    url: str,
    *,
    client: Optional[httpx.AsyncClient] = None,
    retry_on_401: bool = True,
    **kwargs,
) -> httpx.Response:
    """
    Gọi API doanh nghiệp có gắn Bearer token, tự làm mới đúng một lần khi gặp 401.

    Vì sao cần retry: token có thể bị thu hồi phía SAP trước hạn (đổi mật khẩu
    client, admin revoke). Không xử lý thì mọi request sau đó đều hỏng cho tới
    khi khởi động lại server.
    """
    provider = OAuthTokenProvider()
    own_client = client is None
    c = client or httpx.AsyncClient(timeout=30.0)
    try:
        headers = {**kwargs.pop("headers", {}), **await provider.auth_header()}
        resp = await c.request(method, url, headers=headers, **kwargs)

        if resp.status_code == 401 and retry_on_401 and provider.configured:
            print("🔁 [OAUTH] Nhận 401 — làm mới token và thử lại một lần.")
            provider.invalidate()
            headers = {**headers, **await provider.auth_header()}
            resp = await c.request(method, url, headers=headers, **kwargs)

        return resp
    finally:
        if own_client:
            await c.aclose()
