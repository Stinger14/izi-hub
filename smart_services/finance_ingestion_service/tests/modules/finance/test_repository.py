from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError

from app.modules.finance.exceptions import DuplicateTransactionError
from app.modules.finance.repository import FinanceTransactionRepo
from app.modules.finance.schemas import ParsedBankAlert


class FakeAsyncSession:
    def __init__(self, commit_error=None):
        self.commit_error = commit_error
        self.added = []
        self.rollback_called = False
        self.refresh_called = False

    def add(self, transaction):
        self.added.append(transaction)

    async def commit(self):
        if self.commit_error is not None:
            raise self.commit_error

    async def rollback(self):
        self.rollback_called = True

    async def refresh(self, transaction):
        self.refresh_called = True


class FakeAsyncpgUniqueViolation:
    sqlstate = "23505"
    constraint_name = "ix_finance_transactions_dedup_hash"


class FakePsycopgDiag:
    constraint_name = "finance_transactions_dedup_hash_key"


class FakePsycopgUniqueViolation:
    pgcode = "23505"
    diag = FakePsycopgDiag()


class FakeOtherIntegrityFailure:
    sqlstate = "23505"
    constraint_name = "some_other_constraint"


def build_parsed_alert() -> ParsedBankAlert:
    return ParsedBankAlert(
        bank_name="Banco Popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
    )


@pytest.mark.asyncio
async def test_create_translates_asyncpg_dedup_unique_violation():
    session = FakeAsyncSession(
        commit_error=IntegrityError("insert", {}, FakeAsyncpgUniqueViolation())
    )
    repo = FinanceTransactionRepo(session)

    with pytest.raises(DuplicateTransactionError):
        await repo.create(
            sender="alertas@popular.com",
            subject="Alerta de consumo",
            parsed=build_parsed_alert(),
            dedup_hash="hash-123",
            score=0.4,
        )

    assert session.rollback_called is True


@pytest.mark.asyncio
async def test_create_translates_psycopg_dedup_unique_violation():
    session = FakeAsyncSession(
        commit_error=IntegrityError("insert", {}, FakePsycopgUniqueViolation())
    )
    repo = FinanceTransactionRepo(session)

    with pytest.raises(DuplicateTransactionError):
        await repo.create(
            sender="alertas@popular.com",
            subject="Alerta de consumo",
            parsed=build_parsed_alert(),
            dedup_hash="hash-123",
            score=0.4,
        )

    assert session.rollback_called is True


@pytest.mark.asyncio
async def test_create_reraises_non_dedup_integrity_errors():
    error = IntegrityError("insert", {}, FakeOtherIntegrityFailure())
    session = FakeAsyncSession(commit_error=error)
    repo = FinanceTransactionRepo(session)

    with pytest.raises(IntegrityError):
        await repo.create(
            sender="alertas@popular.com",
            subject="Alerta de consumo",
            parsed=build_parsed_alert(),
            dedup_hash="hash-123",
            score=0.4,
        )

    assert session.rollback_called is True
