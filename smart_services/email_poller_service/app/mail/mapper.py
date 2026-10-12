"""
Shapes IMAP message to fit ingestion payload
"""

from dataclasses import dataclass
from datetime import datetime

from app.mail.client import RawEmail


@dataclass
class IngestionPayload:
    sender: str
    subject: str
    body: str
    received_at: datetime
    ingestion_token: str


def to_ingestion_payload(email: RawEmail, ingestion_token: str) -> IngestionPayload:
    return IngestionPayload(
        sender=email.from_,
        subject=email.subject,
        body=email.text,
        received_at=email.received_at,
        ingestion_token=ingestion_token,
    )
