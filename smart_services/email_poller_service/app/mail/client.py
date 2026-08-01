"""
IMAP wrapper
"""

import logging
from dataclasses import dataclass
from datetime import datetime

from imap_tools import AND, MailBox

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass
class RawEmail:
    subject: str
    received_at: datetime
    from_: str
    text: str
    uid: int


def fetch_new_messages(since_uid: int) -> list[RawEmail]:
    raw_emails = []
    with MailBox(settings.IMAP_HOST, settings.IMAP_PORT).login(
        settings.IMAP_USERNAME, settings.IMAP_PASSWORD
    ) as mailbox:
        for msg in mailbox.fetch(AND(uid=f"{since_uid + 1}:*"), mark_seen=False):
            if msg.uid is None:
                logger.warning(f"message with no UID fetched (subject={msg.subject!r})")
                continue

            raw_emails.append(
                RawEmail(msg.subject, msg.date, msg.from_, msg.text, int(msg.uid))
            )

    return raw_emails
