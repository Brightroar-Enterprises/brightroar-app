from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from decimal import Decimal
from pydantic import BaseModel

from app.database import get_db
from app.models.user import User
from app.models.wallet import Wallet
from app.schemas.wallet import WalletCreate, WalletResponse, WalletSummary
from app.core.dependencies import get_current_active_user
from app.redis_client import cache_get, cache_set, cache_delete_pattern

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
