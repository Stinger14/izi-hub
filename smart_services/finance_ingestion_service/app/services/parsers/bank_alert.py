import re
from decimal import Decimal
from app.services.parsers.base import EmailParser
from app.modules.finance.schemas import ParsedBankAlert

_SUPPORTED_SENDER_FRAGMENTS = ["bank.com", "popular.com", "bhd.com", "qik.com.do"]

_WITHDRAWAL_WORDS = ["retiro", "withdrawal"]
_TRANSFER_WORDS = ["transferencia", "transfer received"]
_PURCHASE_WORDS = ["consumo", "compra", "purchase", "card purchase", "debit"]
_DEPOSIT_WORDS = ["deposit", "payment received", "credit"]
_SCOPE_ONLY_WORDS = ["tarjeta"]
_SPANISH_WORDS = ["retiro", "transferencia", "consumo", "compra", "tarjeta"]

_KNOWN_BANKS = {
    "popular": "Banco Popular",
    "bhd": "BHD",
    "qik": "QiK",
}


class BankAlertParser(EmailParser):
    def can_parse(self, sender: str, subject: str, body: str) -> bool:
        if not self._supported_sender(sender):
            return False

        text = f"{subject} {body}".lower()
        keywords = (
            _WITHDRAWAL_WORDS + _TRANSFER_WORDS + _PURCHASE_WORDS + _DEPOSIT_WORDS + _SCOPE_ONLY_WORDS
        )
        return any(word in text for word in keywords)

    def parse(self, sender: str, subject: str, body: str) -> ParsedBankAlert:
        amount = self._extract_amount(body)
        transaction_type = self._extract_type(body)
        merchant = self._extract_merchant(body)

        return ParsedBankAlert(
            bank_name=self._extract_bank(sender, subject, body),
            account_hint=self._extract_account_hint(body),
            transaction_type=transaction_type,
            amount=amount,
            currency=self._extract_currency(body),
            merchant=merchant,
            raw_text=body,
        )

    def _supported_sender(self, sender: str) -> bool:
        lowered = sender.lower()
        return any(fragment in lowered for fragment in _SUPPORTED_SENDER_FRAGMENTS)

    def _extract_amount(self, text: str) -> Decimal:
        match = re.search(
            r"(?:RD\$|DOP|USD|US\$|\$)\s?([\d,]+(?:\.\d{2})?)", text, re.IGNORECASE
        )
        if not match:
            raise ValueError("Could not extract amount")

        value = match.group(1).replace(",", "")
        return Decimal(value)

    def _extract_currency(self, text: str) -> str:
        upper = text.upper()

        if "RD$" in upper or "DOP" in upper:
            return "DOP"
        if "USD" in upper or "US$" in upper:
            return "USD"

        lowered = text.lower()
        if any(word in lowered for word in _SPANISH_WORDS):
            return "DOP"

        return "USD"

    def _extract_type(self, text: str) -> str:
        lowered = text.lower()

        if any(word in lowered for word in _WITHDRAWAL_WORDS):
            return "withdrawal"
        if any(word in lowered for word in _TRANSFER_WORDS):
            return "transfer"
        if any(word in lowered for word in _PURCHASE_WORDS):
            return "purchase"
        if any(word in lowered for word in _DEPOSIT_WORDS):
            return "deposit"

        return "unknown"

    def _extract_merchant(self, text: str) -> str | None:
        match = re.search(
            r"(?:en|comercio|establecimiento|at|from)\s+([A-Za-z0-9 .,&-]+)",
            text,
            re.IGNORECASE,
        )
        return match.group(1).strip() if match else None

    def _extract_account_hint(self, text: str) -> str | None:
        match = re.search(
            r"(?:terminada en|cuenta|tarjeta|ending in|account|card)\s?[*xX-]*(\d{4})",
            text,
            re.IGNORECASE,
        )
        return match.group(1) if match else None

    def _extract_bank(self, sender: str, subject: str, body: str) -> str | None:
        text = f"{sender} {subject} {body}".lower()

        for keyword, name in _KNOWN_BANKS.items():
            if keyword in text:
                return name

        match = re.search(r"@([\w.-]+)", sender)
        if not match:
            return None

        domain = match.group(1).split(".")[0]
        return domain.replace("-", " ").title() or None
