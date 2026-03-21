from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
from pydantic import BaseModel

from app.database import get_db
from app.models.user import User
from app.models.binance_credential import BinanceCredential
from app.core.dependencies import get_current_active_user
from app.core.encryption import encrypt, decrypt
from app.services.binance_service import BinanceService, BinanceAPIError, BinanceConnectionError
from app.redis_client import cache_get, cache_set, cache_delete_pattern

router = APIRouter(prefix="/binance", tags=["Binance Account"])


class SaveCredentialsRequest(BaseModel):
    api_key: str
    api_secret: str
    label: str = "Main"


class CredentialsResponse(BaseModel):
    id: str
    label: str
    api_key_preview: str
    is_active: bool
    can_read: bool
    can_trade: bool
    can_withdraw: bool
    created_at: datetime


def _mask_key(api_key: str) -> str:
    if len(api_key) < 10:
        return "***"
    return api_key[:6] + "..." + api_key[-4:]


async def _get_credential(user_id, db: AsyncSession) -> BinanceCredential:
    result = await db.execute(
        select(BinanceCredential).where(
            BinanceCredential.user_id == user_id,
            BinanceCredential.is_active == True,
        )
    )
    cred = result.scalar_one_or_none()
    if not cred:
        raise HTTPException(
            status_code=404,
            detail="No Binance API credentials found. Add them via POST /binance/credentials",
        )
    return cred


@router.post("/credentials", response_model=CredentialsResponse, status_code=201)
async def save_credentials(
    payload: SaveCredentialsRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    binance = BinanceService()
    try:
        await binance.get_spot_balances(payload.api_key, payload.api_secret)
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance rejected the API key: {e.message} (code={e.code})")
    except BinanceConnectionError:
        raise HTTPException(status_code=503, detail="Could not reach Binance API")

    result = await db.execute(select(BinanceCredential).where(BinanceCredential.user_id == current_user.id))
    cred = result.scalar_one_or_none()

    if cred:
        cred.api_key = payload.api_key
        cred.encrypted_secret = encrypt(payload.api_secret)
        cred.label = payload.label
        cred.is_active = True
    else:
        cred = BinanceCredential(
            user_id=current_user.id,
            api_key=payload.api_key,
            encrypted_secret=encrypt(payload.api_secret),
            label=payload.label,
        )
        db.add(cred)

    await db.flush()
    await db.refresh(cred)
    await cache_delete_pattern(f"user:{current_user.id}:binance*")

    return CredentialsResponse(
        id=str(cred.id), label=cred.label,
        api_key_preview=_mask_key(cred.api_key),
        is_active=cred.is_active, can_read=cred.can_read,
        can_trade=cred.can_trade, can_withdraw=cred.can_withdraw,
        created_at=cred.created_at,
    )


@router.get("/credentials", response_model=CredentialsResponse)
async def get_credentials(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    cred = await _get_credential(current_user.id, db)
    return CredentialsResponse(
        id=str(cred.id), label=cred.label,
        api_key_preview=_mask_key(cred.api_key),
        is_active=cred.is_active, can_read=cred.can_read,
        can_trade=cred.can_trade, can_withdraw=cred.can_withdraw,
        created_at=cred.created_at,
    )


@router.delete("/credentials", status_code=204)
async def delete_credentials(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    cred = await _get_credential(current_user.id, db)
    await db.delete(cred)
    await cache_delete_pattern(f"user:{current_user.id}:binance*")


@router.get("/account")
async def get_full_account(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Full Binance account snapshot across ALL wallet types:
    Spot + Funding + USD-M Futures + COIN-M Futures + Cross Margin + Isolated Margin
    Cached 30 seconds.
    """
    cache_key = f"user:{current_user.id}:binance:account"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)

    binance = BinanceService()
    try:
        snapshot = await binance.get_full_account_snapshot(cred.api_key, api_secret)
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")
    except BinanceConnectionError:
        raise HTTPException(status_code=503, detail="Could not reach Binance API")

    cred.last_used_at = datetime.now(timezone.utc)
    await cache_set(cache_key, snapshot, ttl=30)
    return snapshot


@router.get("/account/spot")
async def get_spot_account(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Spot wallet only."""
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        balances = await binance.get_spot_balances(cred.api_key, api_secret)
        return {"wallet_type": "spot", "assets": balances}
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")


@router.get("/account/funding")
async def get_funding_account(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Funding wallet."""
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        balances = await binance.get_funding_balances(cred.api_key, api_secret)
        return {"wallet_type": "funding", "assets": balances}
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")


@router.get("/account/futures")
async def get_futures_account(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """USD-M + COIN-M Futures wallets."""
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        usdm  = await binance.get_futures_usdm_balances(cred.api_key, api_secret)
        coinm = await binance.get_futures_coinm_balances(cred.api_key, api_secret)
        return {"usdm": usdm, "coinm": coinm}
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")


@router.get("/account/margin")
async def get_margin_account(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Cross + Isolated Margin wallets."""
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        cross    = await binance.get_cross_margin_balances(cred.api_key, api_secret)
        isolated = await binance.get_isolated_margin_balances(cred.api_key, api_secret)
        return {"cross_margin": cross, "isolated_margin": isolated}
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")


@router.get("/trades/{symbol}")
async def get_trade_history(
    symbol: str,
    limit: int = Query(50, ge=1, le=500),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    cache_key = f"user:{current_user.id}:binance:trades:{symbol}:{limit}"
    cached = await cache_get(cache_key)
    if cached:
        return cached
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        trades = await binance.get_trade_history(symbol.upper(), cred.api_key, api_secret, limit)
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")
    await cache_set(cache_key, trades, ttl=60)
    return trades


@router.get("/orders/open")
async def get_open_orders(
    symbol: str | None = Query(None),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        return await binance.get_open_orders(cred.api_key, api_secret, symbol)
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")


@router.get("/deposits")
async def get_deposits(
    asset: str | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        return await binance.get_deposit_history(cred.api_key, api_secret, asset, limit)
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")


@router.get("/withdrawals")
async def get_withdrawals(
    asset: str | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()
    try:
        return await binance.get_withdrawal_history(cred.api_key, api_secret, asset, limit)
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")


@router.get("/pnl")
async def get_pnl_summary(
    period: str = Query("all", pattern="^(1d|1w|1m|3m|ytd|all)$"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Overall Binance PnL for a given time period.
    period: 1d | 1w | 1m | 3m | ytd | all  (default: all)

    Returns:
    - total_pnl: spot + futures_unrealized + futures_realized
    - spot: cost-basis vs current value PnL (filtered to period)
    - futures_unrealized: open positions (always current)
    - futures_realized: closed trade income (filtered to period)

    Cached 60s per period.
    """
    cache_key = f"user:{current_user.id}:binance:pnl:{period}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    binance = BinanceService()

    try:
        summary = await binance.get_full_pnl_summary(cred.api_key, api_secret, period=period)
    except BinanceAPIError as e:
        raise HTTPException(status_code=400, detail=f"Binance error: {e.message}")
    except BinanceConnectionError:
        raise HTTPException(status_code=503, detail="Could not reach Binance API")

    await cache_set(cache_key, summary, ttl=60)
    return summary