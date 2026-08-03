"""
POST to finance_ingestion_service
"""

from dataclasses import dataclass
from typing import Literal

import requests

from app.core.config import settings
from app.mail.mapper import IngestionPayload


@dataclass
class ForwardOutcome:
    status: Literal["accepted", "rejected", "failed"]
    detail: str | None = None


def send_to_ingestion(ingestion_payload: IngestionPayload) -> ForwardOutcome:
    url = settings.IZIHUB_INGESTION_URL
    headers = {"Authorization": f"Bearer {settings.INGESTION_INBOUND_API_KEY}"}

    body = {
        "sender": ingestion_payload.sender,
        "subject": ingestion_payload.subject,
        "body": ingestion_payload.body,
        "received_at": ingestion_payload.received_at.isoformat(),
        "ingestion_token": ingestion_payload.ingestion_token,
    }

    try:
        resp = requests.post(url, json=body, headers=headers, timeout=7)
    except requests.exceptions.RequestException as exc:
        return ForwardOutcome(status="failed", detail=str(exc))

    if resp.status_code == 200:
        data = resp.json()
        detail = (
            f"status={data.get('status')} duplicate={data.get('duplicate')} "
            f"transaction_id={data.get('transaction_id')}"
        )
        return ForwardOutcome(status="accepted", detail=detail)

    if resp.status_code == 422:
        try:
            detail = resp.json().get("detail")
        except ValueError:
            detail = resp.text
        return ForwardOutcome(status="rejected", detail=detail)

    return ForwardOutcome(status="failed", detail=f"{resp.status_code}: {resp.text}")
