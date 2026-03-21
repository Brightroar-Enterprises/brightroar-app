"""
AES-256-GCM encryption for sensitive fields (Binance API secret).
Uses the app SECRET_KEY to derive an encryption key via PBKDF2.
"""
import base64
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from app.config import get_settings

settings = get_settings()

# Derive a 256-bit key from the app SECRET_KEY
_SALT = b"brightroar_binance_key_salt_v1"


def _derive_key() -> bytes:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=_SALT,
        iterations=100_000,
    )
    return kdf.derive(settings.secret_key.encode())


_KEY = _derive_key()


def encrypt(plaintext: str) -> str:
    """Encrypt a string → base64-encoded 'nonce:ciphertext'."""
    aesgcm = AESGCM(_KEY)
    nonce = os.urandom(12)  # 96-bit nonce for GCM
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode(), None)
    combined = nonce + ciphertext
    return base64.urlsafe_b64encode(combined).decode()


def decrypt(token: str) -> str:
    """Decrypt a base64 token back to the original string."""
    combined = base64.urlsafe_b64decode(token.encode())
    nonce = combined[:12]
    ciphertext = combined[12:]
    aesgcm = AESGCM(_KEY)
    return aesgcm.decrypt(nonce, ciphertext, None).decode()
