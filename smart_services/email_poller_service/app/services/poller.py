"""
Orchestrates one poll cycle
"""

import logging
from pathlib import Path

from app.core.config import settings
from app.mail.client import fetch_new_messages
from app.mail.mapper import to_ingestion_payload
from app.services.forwarder import send_to_ingestion
from app.services.watermark import read_watermark, write_watermark

logger = logging.getLogger(__name__)


def run_poll_cycle() -> None:
    watermark_path = Path(settings.WATERMARK_FILE_PATH)
    batch_size = settings.MAX_BATCH_SIZE
    since_uid = read_watermark(watermark_path)
    emails = fetch_new_messages(since_uid=since_uid, max_results=batch_size)
    if len(emails) == batch_size:
        logger.warning("hit the batch cap, more pending")

    for email in emails:
        payload = to_ingestion_payload(email, settings.INGESTION_TOKEN)
        ingestion_check = send_to_ingestion(payload)

        if ingestion_check.status == "failed":
            logger.warning(f"email ingestion failed: {ingestion_check.detail}")
            break

        if ingestion_check.status == "rejected":
            logger.warning(f"email payload rejected: {ingestion_check.detail}")

        if ingestion_check.status == "accepted":
            logger.info("payload ingestion successful")

        write_watermark(watermark_path, email.uid)
