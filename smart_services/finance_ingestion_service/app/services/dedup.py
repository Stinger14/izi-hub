import hashlib
from app.modules.finance.schemas import ParsedBankAlert


class DedupService:
    def create_hash(self, parsed: ParsedBankAlert, sender: str, subject: str) -> str:
        key = "|".join(
            [
                sender.lower(),
                subject.lower(),
                str(parsed.amount),
                parsed.currency,
                parsed.transaction_type,
                parsed.account_hint or "",
                parsed.merchant or "",
                parsed.raw_text[:300],
            ]
        )

        return hashlib.sha256(key.encode("utf-8")).hexdigest()
