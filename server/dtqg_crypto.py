# server/dtqg_crypto.py
"""
Mã hóa mật khẩu liên thông của cơ sở / bác sĩ khi lưu trong DB (Fernet).

Fail-closed: chưa đặt IZIIAPP_DTQG_CRED_KEY (hoặc khóa sai định dạng) thì KHÔNG
lưu và KHÔNG đọc được mật khẩu — thà không gửi được đơn còn hơn lưu mật khẩu
dạng thô. Mật khẩu không bao giờ được ghi log hay trả về qua API.
"""
from __future__ import annotations

from typing import Optional

from server_config import CONFIG


class CredentialKeyError(RuntimeError):
    pass


def _fernet(key: Optional[str] = None):
    k = (key if key is not None else CONFIG.dtqg_cred_key).strip()
    if not k:
        raise CredentialKeyError(
            "Chưa cấu hình IZIIAPP_DTQG_CRED_KEY — không thể lưu/đọc mật khẩu liên thông."
        )
    try:
        from cryptography.fernet import Fernet
    except ImportError as e:  # pragma: no cover
        raise CredentialKeyError("Thiếu gói 'cryptography' (pip install cryptography).") from e
    try:
        return Fernet(k.encode())
    except Exception as e:
        raise CredentialKeyError(f"IZIIAPP_DTQG_CRED_KEY không hợp lệ: {e}") from e


def encrypt_password(plain: str, key: Optional[str] = None) -> str:
    return _fernet(key).encrypt(plain.encode("utf-8")).decode("ascii")


def decrypt_password(token: str, key: Optional[str] = None) -> str:
    from cryptography.fernet import InvalidToken

    try:
        return _fernet(key).decrypt(token.encode("ascii")).decode("utf-8")
    except InvalidToken as e:
        raise CredentialKeyError(
            "Không giải mã được mật khẩu liên thông (sai khóa IZIIAPP_DTQG_CRED_KEY?)."
        ) from e
