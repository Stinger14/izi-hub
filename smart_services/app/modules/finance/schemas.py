from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, EmailStr
from typing import Optional


class EmailIngestionRequest(BaseModel):
    sender: EmailStr
    subject: str
    body: str
    received_at: Optional[datetime] = None


class ParsedBankAlert(BaseModel):
    bank_name: Optional[str] = None
    account_hint: Optional[str] = None
    transaction_type: str
    amount: Decimal
    currency: str = "DOP"
    merchant: Optional[str] = None
    accurred_at: Optional[datetime] = None
    raw_text: str


class IngestionResult(BaseModel):
    status: str
    duplicate: bool
    score: float
    transaction_id: Optional[int] = None
