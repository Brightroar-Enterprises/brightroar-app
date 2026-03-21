import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, Boolean, DateTime, Numeric, ForeignKey, Enum, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base
import enum


class WalletType(str, enum.Enum):
    TREASURY = "treasury"
    INTERNAL = "internal"
    EXCHANGE = "exchange"
    COLD_STORAGE = "cold_storage"


class AssetSymbol(str, enum.Enum):
    BTC = "BTC"
    ETH = "ETH"
    USDT = "USDT"
    SOL = "SOL"
    DOT = "DOT"
    USD = "USD"


class Wallet(Base):
    __tablename__ = "wallets"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    wallet_type: Mapped[WalletType] = mapped_column(Enum(WalletType), nullable=False)
    asset_symbol: Mapped[AssetSymbol] = mapped_column(Enum(AssetSymbol), nullable=False, default=AssetSymbol.USDT)
    address: Mapped[str | None] = mapped_column(String(255), nullable=True)

    balance: Mapped[Decimal] = mapped_column(Numeric(precision=28, scale=8), nullable=False, default=Decimal("0"))
    balance_usd: Mapped[Decimal] = mapped_column(Numeric(precision=28, scale=2), nullable=False, default=Decimal("0"))

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    exchange_name: Mapped[str | None] = mapped_column(String(100), nullable=True)  # e.g. "Binance"

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    owner: Mapped["User"] = relationship("User", back_populates="wallets")  # noqa
    sent_transactions: Mapped[list["Transaction"]] = relationship(  # noqa
        "Transaction", foreign_keys="Transaction.from_wallet_id", back_populates="from_wallet"
    )
    received_transactions: Mapped[list["Transaction"]] = relationship(  # noqa
        "Transaction", foreign_keys="Transaction.to_wallet_id", back_populates="to_wallet"
    )

    def __repr__(self):
        return f"<Wallet {self.name} ({self.asset_symbol})>"
