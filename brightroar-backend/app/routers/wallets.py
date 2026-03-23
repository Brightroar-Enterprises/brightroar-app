from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from decimal import Decimal
from pydantic import BaseModel
import logging

from app.database import get_db
from app.models.user import User
from app.models.wallet import Wallet
from app.schemas.wallet import WalletCreate, WalletResponse, WalletSummary
from app.core.dependencies import get_current_active_user
from app.redis_client import cache_get, cache_set, cache_delete_pattern
from app.services.etherscan_service import EtherscanService, EtherscanError, EtherscanConnectionError
from app.services.binance_service import BinanceService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/wallets", tags=["Wallets"])


class WalletUpdate(BaseModel):
    name: str | None = None
    address: str | None = None
    exchange_name: str | None = None


@router.get("/", response_model=WalletSummary)
async def list_wallets(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    cache_key = f"user:{current_user.id}:wallets"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    result = await db.execute(
        select(Wallet)
        .where(Wallet.user_id == current_user.id, Wallet.is_active == True)
        .order_by(Wallet.created_at)
    )
    wallets = result.scalars().all()
    total_usd = sum(w.balance_usd for w in wallets)

    allocation: dict[str, Decimal] = {}
    for w in wallets:
        sym = w.asset_symbol.value
        allocation[sym] = allocation.get(sym, Decimal(0)) + w.balance_usd
    if total_usd > 0:
        allocation = {k: round(v / total_usd * 100, 2) for k, v in allocation.items()}

    summary = WalletSummary(
        total_balance_usd=total_usd,
        wallets=[WalletResponse.model_validate(w) for w in wallets],
        allocation=allocation,
    )
    await cache_set(cache_key, summary.model_dump(mode="json"), ttl=60)
    return summary


@router.post("/", response_model=WalletResponse, status_code=201)
async def create_wallet(
    payload: WalletCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    wallet = Wallet(
        user_id=current_user.id,
        name=payload.name,
        wallet_type=payload.wallet_type,
        asset_symbol=payload.asset_symbol,
        address=payload.address,
        exchange_name=payload.exchange_name,
    )
    db.add(wallet)
    await db.flush()
    await db.refresh(wallet)
    await cache_delete_pattern(f"user:{current_user.id}:wallets*")
    return wallet


@router.get("/{wallet_id}", response_model=WalletResponse)
async def get_wallet(
    wallet_id: str,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Wallet).where(Wallet.id == wallet_id, Wallet.user_id == current_user.id)
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")
    return wallet


@router.put("/{wallet_id}", response_model=WalletResponse)
async def update_wallet(
    wallet_id: str,
    payload: WalletUpdate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Wallet).where(
            Wallet.id == wallet_id,
            Wallet.user_id == current_user.id,
            Wallet.is_active == True,
        )
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")

    if payload.name is not None:
        wallet.name = payload.name
    if payload.address is not None:
        wallet.address = payload.address.strip() if payload.address.strip() else None
    if payload.exchange_name is not None:
        wallet.exchange_name = payload.exchange_name

    await db.flush()
    await db.refresh(wallet)
    await cache_delete_pattern(f"user:{current_user.id}:wallets*")
    return wallet


@router.delete("/{wallet_id}", status_code=204)
async def delete_wallet(
    wallet_id: str,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Wallet).where(Wallet.id == wallet_id, Wallet.user_id == current_user.id)
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")

    wallet.is_active = False
    await cache_delete_pattern(f"user:{current_user.id}:wallets*")
    return None


@router.post("/{wallet_id}/sync-onchain")
async def sync_wallet_onchain(
    wallet_id: str,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Fetch real on-chain balance using Ankr free public RPC (no API key needed)
    and update the wallet balance in the database.
    Supported assets: ETH, USDT (ERC-20), USDC (ERC-20).
    """
    result = await db.execute(
        select(Wallet).where(
            Wallet.id == wallet_id,
            Wallet.user_id == current_user.id,
            Wallet.is_active == True,
        )
    )
    wallet = result.scalar_one_or_none()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")

    if not wallet.address:
        raise HTTPException(
            status_code=400,
            detail="This wallet has no blockchain address set. "
                   "Edit the wallet and add its on-chain address first.",
        )

    asset = wallet.asset_symbol.value

    supported = {"ETH", "USDT", "USDC"}
    if asset not in supported:
        raise HTTPException(
            status_code=400,
            detail=f"On-chain sync supports ETH, USDT, USDC only. This wallet holds {asset}.",
        )

    # No API key needed — uses Ankr free public RPC
    etherscan = EtherscanService()
    try:
        on_chain_balance = await etherscan.get_balance_for_asset(wallet.address, asset)
    except EtherscanError as e:
        raise HTTPException(status_code=400, detail=f"On-chain error: {e}")
    except EtherscanConnectionError as e:
        raise HTTPException(status_code=503, detail=f"Could not reach blockchain RPC: {e}")

    # Get USD price
    try:
        binance = BinanceService()
        symbol_map = {"ETH": "ETHUSDT", "USDT": None, "USDC": None}
        binance_sym = symbol_map.get(asset)
        if binance_sym:
            prices = await binance.get_prices([binance_sym])
            price_usd = prices.get(binance_sym, Decimal("0"))
        else:
            price_usd = Decimal("1")
    except Exception:
        price_usd = Decimal("1") if asset in ("USDT", "USDC") else Decimal("0")

    old_balance = wallet.balance
    wallet.balance = on_chain_balance
    wallet.balance_usd = on_chain_balance * price_usd

    await db.flush()
    await cache_delete_pattern(f"user:{current_user.id}:wallets*")
    await cache_delete_pattern(f"user:{current_user.id}:analytics*")

    logger.info(f"Synced {wallet_id} ({asset}): {old_balance} → {on_chain_balance}")

    return {
        "wallet_id": str(wallet.id),
        "wallet_name": wallet.name,
        "address": wallet.address,
        "asset": asset,
        "old_balance": str(old_balance),
        "new_balance": str(on_chain_balance),
        "balance_usd": str(round(wallet.balance_usd, 2)),
        "price_usd": str(round(price_usd, 4)),
    }