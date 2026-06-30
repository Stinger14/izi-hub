from app.modules.finance.schemas import ParsedBankAlert


class ScoringService:
    def score(self, parsed: ParsedBankAlert) -> float:
        score = 0.0

        if parsed.amount >= 10_000:
            score += 0.4

        if parsed.transaction_type in {"withdrawal", "transfer"}:
            score += 0.3

        if not parsed.merchant:
            score += 0.2

        if not parsed.bank_name:
            score += 0.1

        return min(score, 1.0)
