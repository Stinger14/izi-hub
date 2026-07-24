import re
from decimal import Decimal
from app.services.parsers.base import EmailParser
from app.modules.finance.schemas import ParsedBankAlert


class BankAlertParserUsd(EmailParser):
    def can_parse(self, sender: str, subject: str, body: str) -> bool:
        text = f"{sender} {subject}{body}".lower()
        return any(
            word in text
            for word in [
                "purchase",
                "debit",
                "withdrawal",
                "card purchase",
                "deposit",
                "payment received",
                "credit",
                "transfer received",
            ]
        )

    def parse(self, sender: str, subject: str, body: str) -> ParsedBankAlert:
        amount = self._extract_amount(body)
        transaction_type = self._extract_type(body)
        merchant = self._extract_merchant(body)

        return ParsedBankAlert(
            bank_name=self._extract_bank(sender),
            account_hint=self._extract_account_hint(body),
            transaction_type=transaction_type,
            amount=amount,
            currency="USD",
            merchant=merchant,
            raw_text=body,
        )

    def _extract_amount(self, text: str) -> Decimal:
        match = re.search(
            r"(?:USD|US\$|\$)\s?([\d,]+(?:\.\d{2})?)", text, re.IGNORECASE
        )
        if not match:
            raise ValueError("Could not extract amount")

        value = match.group(1).replace(",", "")
        return Decimal(value)

    def _extract_type(self, text: str) -> str:
        lowered = text.lower()

        if "withdrawal" in lowered:
            return "withdrawal"
        if "transfer received" in lowered:
            return "transfer"
        if any(w in lowered for w in ("purchase", "card purchase", "debit")):
            return "purchase"
        if any(w in lowered for w in ("deposit", "payment received", "credit")):
            return "deposit"

        return "unknown"

    def _extract_merchant(self, text: str) -> str | None:
        match = re.search(r"(?:at|from)\s+([A-Za-z0-9 &'.,-]+)", text, re.IGNORECASE)
        return match.group(1).strip() if match else None

    def _extract_account_hint(self, text: str) -> str | None:
        match = re.search(
            r"(?:ending in|account|card)\s?[*xX-]*(\d{4})", text, re.IGNORECASE
        )
        return match.group(1) if match else None

    def _extract_bank(self, sender: str) -> str | None:
        match = re.search(r"@([\w.-]+)", sender)
        if not match:
            return None

        domain = match.group(1).split(".")[0]
        return domain.replace("-", " ").title() or None
