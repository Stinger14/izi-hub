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

    ingested = 0
    rejected = 0
    failed = 0

    for email in emails:
        payload = to_ingestion_payload(email, settings.INGESTION_TOKEN)
        ingestion_check = send_to_ingestion(payload)

        if ingestion_check.status == "failed":
            failed += 1
            logger.warning("email ingestion failed: %s", ingestion_check.detail)
            break

        if ingestion_check.status == "rejected":
            rejected += 1
            logger.debug("email payload rejected: %s", ingestion_check.detail)

        if ingestion_check.status == "accepted":
            ingested += 1

        write_watermark(watermark_path, email.uid)

    logger.info(
        "poll cycle complete: fetched=%d ingested=%d rejected=%d failed=%d",
        len(emails),
        ingested,
        rejected,
        failed,
    )
