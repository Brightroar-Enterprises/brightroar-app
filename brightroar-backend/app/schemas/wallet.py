from pydantic import BaseModel, Field
from decimal import Decimal
import uuid
from datetime import datetime
from app.models.wallet import WalletType, AssetSymbol


class WalletCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    wallet_type: WalletType
    asset_symbol: AssetSymbol = AssetSymbol.USDT
    address: str | None = None
    exchange_name: str | None = None


class WalletResponse(BaseModel):
    id: uuid.UUID
    name: str
    wallet_type: WalletType
    asset_symbol: AssetSymbol
    address: str | None
    balance: Decimal
    balance_usd: Decimal
    is_active: bool
    exchange_name: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class WalletSummary(BaseModel):
    total_balance_usd: Decimal
    wallets: list[WalletResponse]
    allocation: dict[str, Decimal]  # {"BTC": 42.0, "ETH": 28.0, ...}
