from decimal import Decimal

from app.modules.finance.schemas import ParsedBankAlert

_LARGE_AMOUNT_THRESHOLDS = {
    "DOP": Decimal("10000"),
    "USD": Decimal("200"),
}
_DEFAULT_LARGE_AMOUNT_THRESHOLD = Decimal("10000")


class ScoringService:
    def score(self, parsed: ParsedBankAlert) -> float:
        score = 0.0
        threshold = _LARGE_AMOUNT_THRESHOLDS.get(
            parsed.currency, _DEFAULT_LARGE_AMOUNT_THRESHOLD
        )

        if parsed.amount >= threshold:
            score += 0.4

        if parsed.transaction_type in {"withdrawal", "transfer"}:
            score += 0.3

        if not parsed.merchant:
            score += 0.2

        if not parsed.bank_name:
            score += 0.1

        return min(score, 1.0)
