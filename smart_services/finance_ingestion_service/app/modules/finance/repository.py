from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.finance.models import FinanceTransaction
from app.modules.finance.schemas import ParsedBankAlert


class FinanceTransactionRepo:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def exists_by_hash(self, dedup_hash: str) -> bool:
        stmt = select(FinanceTransaction.id).where(
            FinanceTransaction.dedup_hash == dedup_hash
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def create(
        self,
        *,
        sender: str,
        subject: str,
        parsed: ParsedBankAlert,
        dedup_hash: str,
        score: float,
    ) -> FinanceTransaction:
        transaction = FinanceTransaction(
            sender=sender,
            subject=subject,
            bank_name=parsed.bank_name,
            account_hint=parsed.account_hint,
            transaction_type=parsed.transaction_type,
            amount=parsed.amount,
            currency=parsed.currency,
            merchant=parsed.merchant,
            occurred_at=parsed.occurred_at,
            raw_text=parsed.raw_text,
            dedup_hash=dedup_hash,
            score=score,
            is_suspicious=score >= 0.7,
        )

        self.db.add(transaction)
        await self.db.commit()
        await self.db.refresh(transaction)

        return transaction
