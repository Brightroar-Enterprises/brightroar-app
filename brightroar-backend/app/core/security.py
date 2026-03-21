from datetime import datetime, timedelta, timezone
from typing import Any
import uuid
import bcrypt
from jose import jwt
from app.config import get_settings

settings = get_settings()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def create_access_token(subject: str, extra: dict[str, Any] | None = None) -> tuple[str, str]:
    jti = str(uuid.uuid4())
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {
        "sub": subject, "jti": jti, "exp": expire,
        "iat": datetime.now(timezone.utc), "type": "access",
        **(extra or {}),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm), jti


def create_refresh_token(subject: str) -> tuple[str, str]:
    jti = str(uuid.uuid4())
    expire = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    payload = {
        "sub": subject, "jti": jti, "exp": expire,
        "iat": datetime.now(timezone.utc), "type": "refresh",
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm), jti


def decode_token(token: str) -> dict[str, Any]:
    return jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])


def get_token_expiry_seconds(token_type: str) -> int:
    return settings.access_token_expire_minutes * 60 if token_type == "access" else settings.refresh_token_expire_days * 86400
