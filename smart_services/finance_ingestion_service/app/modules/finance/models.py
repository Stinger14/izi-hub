from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Integer, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class FinanceTransaction(Base):
    __tablename__ = "finance_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    sender: Mapped[str] = mapped_column(String(255), index=True)
    subject: Mapped[str] = mapped_column(String(255))
    bank_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    account_hint: Mapped[str | None] = mapped_column(String(50), nullable=True)
    transaction_type: Mapped[str] = mapped_column(String(50))
    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(10), default="DOP")
    merchant: Mapped[str | None] = mapped_column(String(255), nullable=True)
    occurred_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    raw_text: Mapped[str] = mapped_column(Text)
    dedup_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    score: Mapped[float] = mapped_column(Numeric(4, 2), default=0)
    is_suspicious: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.now(timezone.utc)
    )
