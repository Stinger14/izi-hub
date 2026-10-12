import httpx
import logging

from app.modules.finance.schemas import EmailIngestionRequest

logger = logging.getLogger(__name__)


async def forward_to_izihub(payload: EmailIngestionRequest, settings) -> None:
    body = {
        "email": {
            "from": str(payload.sender),
            "subject": payload.subject,
            "text_body": payload.body,
            "received_at": payload.received_at.isoformat()
            if payload.received_at
            else None,
        },
        "ingestion_token": payload.ingestion_token,
    }

    headers = {"Authorization": f"Bearer {settings.FINANCE_INGESTION_API_KEY}"}

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            await client.post(
                f"{settings.IZIHUB_API_BASE_URL}/api/service/finance/email-ingestion",
                json=body,
                headers=headers,
            )
    except httpx.HTTPError:
        # log and digest, this must not break the caller's response
        logger.warning("izihub relay failed", exc_info=True)
