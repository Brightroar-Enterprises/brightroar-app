import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class BinanceCredential(Base):
    """
    Stores a user's Binance API key + secret.
    The secret is stored encrypted (see core/encryption.py).
    One user can have one active credential at a time.
    """
    __tablename__ = "binance_credentials"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,   # one credential set per user
        index=True,
    )

    api_key: Mapped[str] = mapped_column(String(255), nullable=False)
    # Secret is stored AES-256 encrypted — never returned in API responses
    encrypted_secret: Mapped[str] = mapped_column(String(512), nullable=False)

    label: Mapped[str] = mapped_column(String(100), nullable=False, default="Main")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Permissions snapshot (read from Binance on save)
    can_read: Mapped[bool] = mapped_column(Boolean, default=True)
    can_trade: Mapped[bool] = mapped_column(Boolean, default=False)
    can_withdraw: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationship
    owner: Mapped["User"] = relationship("User", backref="binance_credential")  # noqa
