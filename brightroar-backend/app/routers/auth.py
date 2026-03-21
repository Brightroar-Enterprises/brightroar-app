from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
from jose import JWTError

from app.database import get_db
from app.models.user import User
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse,
    RefreshRequest, UserResponse, ChangePasswordRequest
)
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token,
    decode_token, get_token_expiry_seconds
)
from app.core.dependencies import get_current_active_user
from app.redis_client import (
    set_refresh_token, get_refresh_token,
    delete_refresh_token, blacklist_token
)
from app.config import get_settings

router = APIRouter(prefix="/auth", tags=["Authentication"])
settings = get_settings()


@router.post("/register", response_model=UserResponse, status_code=201)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check duplicate email
    result = await db.execute(select(User).where(User.corporate_email == payload.corporate_email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        company_name=payload.company_name,
        corporate_email=payload.corporate_email,
        contact_person=payload.contact_person,
        hashed_password=hash_password(payload.password),
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.corporate_email == payload.email))
    user: User | None = result.scalar_one_or_none()

    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account deactivated")

    # Update last login
    user.last_login = datetime.now(timezone.utc)

    # Issue tokens
    access_token, _ = create_access_token(str(user.id))
    refresh_token, _ = create_refresh_token(str(user.id))

    # Store refresh token in Redis
    await set_refresh_token(
        str(user.id),
        refresh_token,
        ttl=settings.refresh_token_expire_days * 86400,
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(payload: RefreshRequest, db: AsyncSession = Depends(get_db)):
    credentials_exception = HTTPException(status_code=401, detail="Invalid refresh token")
    try:
        data = decode_token(payload.refresh_token)
        if data.get("type") != "refresh":
            raise credentials_exception
        user_id = data["sub"]
    except JWTError:
        raise credentials_exception

    # Validate against Redis
    stored = await get_refresh_token(user_id)
    if stored != payload.refresh_token:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise credentials_exception

    # Rotate tokens
    access_token, _ = create_access_token(str(user.id))
    new_refresh, _ = create_refresh_token(str(user.id))
    await set_refresh_token(str(user.id), new_refresh, ttl=settings.refresh_token_expire_days * 86400)

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh,
        expires_in=settings.access_token_expire_minutes * 60,
    )


@router.post("/logout", status_code=204)
async def logout(
    current_user: User = Depends(get_current_active_user),
    # We need the raw token to blacklist its jti
    # Pass it via header — handled in dependency
):
    await delete_refresh_token(str(current_user.id))
    return None


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_active_user)):
    return current_user


@router.put("/change-password", status_code=204)
async def change_password(
    payload: ChangePasswordRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    current_user.hashed_password = hash_password(payload.new_password)
    await delete_refresh_token(str(current_user.id))  # Force re-login
    return None
