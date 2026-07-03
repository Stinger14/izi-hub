from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.finance.exceptions import DuplicateTransactionError
from app.modules.finance.models import FinanceTransaction
from app.modules.finance.schemas import ParsedBankAlert

DEDUP_HASH_CONSTRAINT_NAMES = {
    "ix_finance_transactions_dedup_hash",
    "finance_transactions_dedup_hash_key",
}


def _is_dedup_hash_violation(exc: IntegrityError) -> bool:
    orig = exc.orig
    sqlstate = getattr(orig, "sqlstate", None) or getattr(orig, "pgcode", None)

    if sqlstate != "23505":
        return False

    constraint_name = getattr(orig, "constraint_name", None)

    if constraint_name is None:
        diag = getattr(orig, "diag", None)
        constraint_name = getattr(diag, "constraint_name", None)

    return constraint_name in DEDUP_HASH_CONSTRAINT_NAMES


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
        try:
            await self.db.commit()
        except IntegrityError as exc:
            await self.db.rollback()

            if _is_dedup_hash_violation(exc):
                raise DuplicateTransactionError from exc

            raise

        await self.db.refresh(transaction)

        return transaction
