import re
from decimal import Decimal
from app.services.parsers.base import EmailParser
from app.modules.finance.schemas import ParsedBankAlert


class BankAlertParser(EmailParser):
    def can_parse(self, sender: str, subject: str, body: str) -> bool:
        text = f"{sender} {subject}{body}".lower()
        return any(
            word in text
            for word in ["consumo", "compra", "retiro", "transferencia", "tarjeta"]
        )

    def parse(self, sender: str, subject: str, body: str) -> ParsedBankAlert:
        amount = self._extract_amount(body)
        transaction_type = self._extract_type(body)
        merchant = self._extract_merchant(body)

        return ParsedBankAlert(
            bank_name=self._extract_bank(sender, subject, body),
            account_hint=self._extract_account_hint(body),
            transaction_type=transaction_type,
            amount=amount,
            currency="DOP",
            merchant=merchant,
            raw_text=body,
        )

    def _extract_amount(self, text: str) -> Decimal:
        match = re.search(
            r"(?:RD\$|DOP|\$)\s?([\d,]+(?:\.\d{2})?)", text, re.IGNORECASE
        )
        if not match:
            raise ValueError("Could not extract amount")

        value = match.group(1).replace(",", "")
        return Decimal(value)

    def _extract_type(self, text: str) -> str:
        lowered = text.lower()

        if "retiro" in lowered:
            return "withdrawal"
        if "transferencia" in lowered:
            return "transfer"
        if "consumo" in lowered or "compra" in lowered:
            return "purchase"

        return "unknown"

    def _extract_merchant(self, text: str) -> str | None:
        match = re.search(
            r"(?:en|comercio|establecimiento)\s+([A-Za-z0-9 .,&-]+)",
            text,
            re.IGNORECASE,
        )
        return match.group(1).strip() if match else None

    def _extract_account_hint(self, text: str) -> str | None:
        match = re.search(
            r"(?:terminada en|cuenta|tarjeta)\s?[*xX-]*(\d{4})", text, re.IGNORECASE
        )
        return match.group(1) if match else None

    def _extract_bank(self, sender: str, subject: str, body: str) -> str | None:
        text = f"{sender} {subject} {body}".lower()

        if "popular" in text:
            return "Banco Popular"
        if "bhd" in text:
            return "BHD"
        if "qik" in text:
            return "QiK"

        return None
