import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    company_name: Mapped[str] = mapped_column(String(255), nullable=False)
    corporate_email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    contact_person: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    biometric_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    hardware_key_enabled: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    last_login: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    wallets: Mapped[list["Wallet"]] = relationship("Wallet", back_populates="owner", lazy="selectin")  # noqa
    transactions: Mapped[list["Transaction"]] = relationship("Transaction", back_populates="user", lazy="selectin")  # noqa

    def __repr__(self):
        return f"<User {self.corporate_email}>"
