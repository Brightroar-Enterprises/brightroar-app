from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import datetime, timezone
from decimal import Decimal

from app.database import get_db
from app.models.user import User
from app.models.wallet import Wallet
from app.models.transaction import Transaction, TransactionType, TransactionStatus
from app.schemas.transaction import (
    TransferRequest, TransactionResponse, TransactionListResponse, TransactionFilter
)
from app.core.dependencies import get_current_active_user
from app.redis_client import cache_delete_pattern

router = APIRouter(prefix="/transactions", tags=["Transactions"])

FLAT_FEE_USDT = Decimal("2.40")


@router.get("/", response_model=TransactionListResponse)
async def list_transactions(
    tx_type: str | None = Query(None),
    status: str | None = Query(None),
    asset_symbol: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    conditions = [Transaction.user_id == current_user.id]
    if tx_type:
        conditions.append(Transaction.tx_type == tx_type)
    if status:
        conditions.append(Transaction.status == status)
    if asset_symbol:
        conditions.append(Transaction.asset_symbol == asset_symbol.upper())

    # Count
    count_q = await db.execute(
        select(func.count()).select_from(Transaction).where(and_(*conditions))
    )
    total = count_q.scalar()

    # Fetch
    result = await db.execute(
        select(Transaction)
        .where(and_(*conditions))
        .order_by(Transaction.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    txns = result.scalars().all()

    return TransactionListResponse(
        total=total,
        page=page,
        page_size=page_size,
        transactions=[TransactionResponse.model_validate(t) for t in txns],
    )


@router.get("/{tx_id}", response_model=TransactionResponse)
async def get_transaction(
    tx_id: str,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == tx_id, Transaction.user_id == current_user.id
        )
    )
    tx = result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return tx


@router.post("/transfer", response_model=TransactionResponse, status_code=201)
async def create_transfer(
    payload: TransferRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    # Validate source wallet
    from_result = await db.execute(
        select(Wallet).where(
            Wallet.id == payload.from_wallet_id,
            Wallet.user_id == current_user.id,
            Wallet.is_active == True,
        )
    )
    from_wallet = from_result.scalar_one_or_none()
    if not from_wallet:
        raise HTTPException(status_code=404, detail="Source wallet not found")

    if from_wallet.balance < payload.amount:
        raise HTTPException(status_code=400, detail="Insufficient balance")

    # Determine transfer type
    is_internal = payload.to_wallet_id is not None
    tx_type = TransactionType.INTERNAL_TRANSFER if is_internal else TransactionType.EXTERNAL_TRANSFER

    to_wallet = None
    if is_internal:
        to_result = await db.execute(
            select(Wallet).where(
                Wallet.id == payload.to_wallet_id,
                Wallet.user_id == current_user.id,
                Wallet.is_active == True,
            )
        )
        to_wallet = to_result.scalar_one_or_none()
        if not to_wallet:
            raise HTTPException(status_code=404, detail="Destination wallet not found")

    # Debit source
    from_wallet.balance -= payload.amount

    # Credit destination (internal only)
    if to_wallet:
        to_wallet.balance += payload.amount
        status = TransactionStatus.CONFIRMED
        confirmed_at = datetime.now(timezone.utc)
    else:
        status = TransactionStatus.PENDING
        confirmed_at = None

    tx = Transaction(
        user_id=current_user.id,
        from_wallet_id=from_wallet.id,
        to_wallet_id=to_wallet.id if to_wallet else None,
        to_external_address=payload.to_external_address,
        tx_type=tx_type,
        status=status,
        asset_symbol=payload.asset_symbol,
        amount=payload.amount,
        amount_usd=payload.amount,  # simplified 1:1 for USDT
        fee=FLAT_FEE_USDT,
        fee_usd=FLAT_FEE_USDT,
        description=payload.description,
        confirmed_at=confirmed_at,
    )
    db.add(tx)
    await db.flush()
    await db.refresh(tx)

    # Invalidate cache
    await cache_delete_pattern(f"user:{current_user.id}:wallets*")
    await cache_delete_pattern(f"user:{current_user.id}:analytics*")

    return tx
