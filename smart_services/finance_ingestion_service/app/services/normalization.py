from app.modules.finance.schemas import ParsedBankAlert


class NormalizationService:
    def normalize(self, parsed: ParsedBankAlert) -> ParsedBankAlert:
        if parsed.merchant:
            parsed.merchant = parsed.merchant.strip().upper()

        parsed.currency = parsed.currency.upper()
        parsed.transaction_type = parsed.transaction_type.lower()

        return parsed
