from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
from decimal import Decimal
from pydantic import BaseModel
import logging

from app.database import get_db
from app.models.user import User
from app.models.wallet import Wallet, WalletType, AssetSymbol
from app.models.binance_credential import BinanceCredential
from app.core.dependencies import get_current_active_user
from app.core.encryption import encrypt, decrypt
from app.services.binance_service import BinanceService, BinanceAPIError, BinanceConnectionError
from app.redis_client import cache_get, cache_set, cache_delete_pattern

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/binance", tags=["Binance Account"])

# Major currencies we auto-create wallets for when Binance is connected
BINANCE_WALLET_ASSETS = [
    AssetSymbol.BTC,
    AssetSymbol.ETH,
    AssetSymbol.USDT,
    AssetSymbol.SOL,
    AssetSymbol.DOT,
]


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


async def _sync_binance_wallets(
    user_id,
    api_key: str,
    api_secret: str,
    db: AsyncSession,
) -> list[dict]:
    """
    Auto-create or update exchange wallets for each major crypto from Binance spot balances.
    - Creates wallet if it doesn't exist yet (wallet_type=exchange, exchange_name=Binance)
    - Updates balance if wallet already exists
    - Returns list of created/updated wallet summaries
    """
    binance = BinanceService()

    # Fetch live spot balances and prices in parallel
    try:
        spot_balances, price_map = await __import__("asyncio").gather(
            binance.get_spot_balances(api_key, api_secret),
            binance._build_price_map(),
            return_exceptions=False,
        )
    except Exception as e:
        logger.warning(f"Could not fetch Binance balances for wallet sync: {e}")
        spot_balances = []
        price_map = {}

    # Build a lookup: asset -> balance from Binance
    binance_balance: dict[str, Decimal] = {}
    for b in spot_balances:
        binance_balance[b["asset"]] = Decimal(b.get("total", "0"))

    synced = []
    for asset in BINANCE_WALLET_ASSETS:
        asset_str = asset.value  # e.g. "BTC"

        # Check if a Binance exchange wallet already exists for this asset
        result = await db.execute(
            select(Wallet).where(
                Wallet.user_id == user_id,
                Wallet.asset_symbol == asset,
                Wallet.wallet_type == WalletType.EXCHANGE,
                Wallet.exchange_name == "Binance",
                Wallet.is_active == True,
            )
        )
        wallet = result.scalar_one_or_none()

        # Get balance from Binance (0 if not held)
        balance = binance_balance.get(asset_str, Decimal("0"))
        price = price_map.get(asset_str, Decimal("1") if asset_str in ("USDT", "USD") else Decimal("0"))
        balance_usd = balance * price

        if wallet:
            # Update existing wallet balance
            wallet.balance = balance
            wallet.balance_usd = balance_usd
            action = "updated"
        else:
            # Create new Binance exchange wallet
            wallet = Wallet(
                user_id=user_id,
                name=f"Binance {asset_str}",
                wallet_type=WalletType.EXCHANGE,
                asset_symbol=asset,
                exchange_name="Binance",
                balance=balance,
                balance_usd=balance_usd,
            )
            db.add(wallet)
            action = "created"

        synced.append({
            "asset": asset_str,
            "action": action,
            "balance": str(balance),
            "balance_usd": str(round(balance_usd, 2)),
        })

    await db.flush()
    await cache_delete_pattern(f"user:{user_id}:wallets*")
    await cache_delete_pattern(f"user:{user_id}:analytics*")
    logger.info(f"Binance wallet sync complete for user {user_id}: {synced}")
    return synced


@router.post("/sync-wallets")
async def sync_binance_wallets(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Manually re-sync Binance exchange wallet balances from live Binance spot account.
    Call this anytime to refresh balances without re-entering API keys.
    """
    cred = await _get_credential(current_user.id, db)
    api_secret = decrypt(cred.encrypted_secret)
    synced = await _sync_binance_wallets(current_user.id, cred.api_key, api_secret, db)
    return {"synced": synced, "count": len(synced)}
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

    # ── Auto-create / sync Binance exchange wallets ───────────────────────────
    await _sync_binance_wallets(current_user.id, payload.api_key, payload.api_secret, db)

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