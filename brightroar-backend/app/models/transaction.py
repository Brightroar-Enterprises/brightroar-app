import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, DateTime, Numeric, ForeignKey, Enum, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base
import enum


class TransactionType(str, enum.Enum):
    DEPOSIT = "deposit"
    WITHDRAWAL = "withdrawal"
    INTERNAL_TRANSFER = "internal_transfer"
    EXTERNAL_TRANSFER = "external_transfer"
    TRADE = "trade"
    EXCHANGE = "exchange"


class TransactionStatus(str, enum.Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    from_wallet_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("wallets.id"), nullable=True)
    to_wallet_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("wallets.id"), nullable=True)

    # External destination (for external transfers)
    to_external_address: Mapped[str | None] = mapped_column(String(255), nullable=True)

    tx_type: Mapped[TransactionType] = mapped_column(Enum(TransactionType), nullable=False, index=True)
    status: Mapped[TransactionStatus] = mapped_column(Enum(TransactionStatus), nullable=False, default=TransactionStatus.PENDING, index=True)

    asset_symbol: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(precision=28, scale=8), nullable=False)
    amount_usd: Mapped[Decimal] = mapped_column(Numeric(precision=28, scale=2), nullable=False, default=Decimal("0"))
    fee: Mapped[Decimal] = mapped_column(Numeric(precision=28, scale=8), nullable=False, default=Decimal("0"))
    fee_usd: Mapped[Decimal] = mapped_column(Numeric(precision=28, scale=2), nullable=False, default=Decimal("0"))

    tx_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="transactions")  # noqa
    from_wallet: Mapped["Wallet"] = relationship("Wallet", foreign_keys=[from_wallet_id], back_populates="sent_transactions")  # noqa
    to_wallet: Mapped["Wallet"] = relationship("Wallet", foreign_keys=[to_wallet_id], back_populates="received_transactions")  # noqa

    def __repr__(self):
        return f"<Transaction {self.tx_type} {self.amount} {self.asset_symbol} [{self.status}]>"
