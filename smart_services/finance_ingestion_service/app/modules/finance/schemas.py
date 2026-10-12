from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, EmailStr


class EmailIngestionRequest(BaseModel):
    sender: EmailStr
    subject: str
    body: str
    received_at: Optional[datetime] = None
    ingestion_token: Optional[str] = None


class ParsedBankAlert(BaseModel):
    bank_name: Optional[str] = None
    account_hint: Optional[str] = None
    transaction_type: str
    amount: Decimal
    currency: str = "DOP"
    merchant: Optional[str] = None
    occurred_at: Optional[datetime] = None
    raw_text: str


class IngestionResult(BaseModel):
    status: str
    duplicate: bool
    score: float
    transaction_id: Optional[int] = None
