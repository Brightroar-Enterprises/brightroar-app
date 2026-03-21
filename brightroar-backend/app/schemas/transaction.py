from pydantic import BaseModel, Field
from decimal import Decimal
import uuid
from datetime import datetime
from app.models.transaction import TransactionType, TransactionStatus


class TransferRequest(BaseModel):
    from_wallet_id: uuid.UUID
    to_wallet_id: uuid.UUID | None = None          # internal transfer
    to_external_address: str | None = None          # external transfer
    asset_symbol: str
    amount: Decimal = Field(..., gt=0)
    description: str | None = None

    def model_post_init(self, __context):
        if not self.to_wallet_id and not self.to_external_address:
            raise ValueError("Either to_wallet_id or to_external_address must be provided")


class TransactionResponse(BaseModel):
    id: uuid.UUID
    tx_type: TransactionType
    status: TransactionStatus
    asset_symbol: str
    amount: Decimal
    amount_usd: Decimal
    fee: Decimal
    fee_usd: Decimal
    from_wallet_id: uuid.UUID | None
    to_wallet_id: uuid.UUID | None
    to_external_address: str | None
    tx_hash: str | None
    description: str | None
    created_at: datetime
    confirmed_at: datetime | None

    model_config = {"from_attributes": True}


class TransactionListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    transactions: list[TransactionResponse]


class TransactionFilter(BaseModel):
    tx_type: TransactionType | None = None
    status: TransactionStatus | None = None
    asset_symbol: str | None = None
    date_from: datetime | None = None
    date_to: datetime | None = None
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)
