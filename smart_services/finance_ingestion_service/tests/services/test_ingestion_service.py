from datetime import datetime, timezone
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.modules.finance.exceptions import (
    DuplicateTransactionError,
    NoParserMatchedError,
)
from app.modules.finance.schemas import EmailIngestionRequest, ParsedBankAlert
from app.services.ingestion_service import EmailIngestionService


class StubParser:
    def __init__(self, parsed, can_parse=True):
        self.parsed = parsed
        self._can_parse = can_parse

    def can_parse(self, sender, subject, body):
        return self._can_parse

    def parse(self, sender, subject, body):
        return self.parsed


class StubNormalizationService:
    def __init__(self, normalized):
        self.normalized = normalized

    def normalize(self, parsed):
        return self.normalized


class StubDedupService:
    def __init__(self, dedup_hash):
        self.dedup_hash = dedup_hash

    def create_hash(self, parsed, sender, subject):
        return self.dedup_hash


class StubScoringService:
    def __init__(self, score):
        self._score = score

    def score(self, parsed):
        return self._score


class SpyRepo:
    def __init__(self, exists_result=False, transaction_id=123, create_error=None):
        self.exists_result = exists_result
        self.transaction_id = transaction_id
        self.create_error = create_error
        self.create_calls = []

    async def exists_by_hash(self, dedup_hash):
        return self.exists_result

    async def create(self, **kwargs):
        self.create_calls.append(kwargs)

        if self.create_error is not None:
            raise self.create_error

        return SimpleNamespace(id=self.transaction_id)


@pytest.mark.asyncio
async def test_ingest_persists_non_duplicate_email():
    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Sirena tarjeta 1234",
    )
    parsed = ParsedBankAlert(
        bank_name="Banco popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="Nacional",
        raw_text=payload.body,
    )
    normalized = parsed.model_copy(update={"merchant": "NACIONAL"})

    repo = SpyRepo(exists_result=False, transaction_id=123)
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(normalized),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    result = await service.ingest(payload)

    assert result.status == "ingested"
    assert result.duplicate is False
    assert result.score == 0.4
    assert result.transaction_id == 123

    assert len(repo.create_calls) == 1
    assert repo.create_calls[0]["sender"] == payload.sender
    assert repo.create_calls[0]["subject"] == payload.subject
    assert repo.create_calls[0]["parsed"] == normalized
    assert repo.create_calls[0]["dedup_hash"] == "hash-123"
    assert repo.create_calls[0]["score"] == 0.4


@pytest.mark.asyncio
async def test_ingest_returns_duplicate_without_creating_transaction():
    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
    )
    parsed = ParsedBankAlert(
        bank_name="Banco Popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text=payload.body,
    )

    repo = SpyRepo(exists_result=True)
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(parsed),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    result = await service.ingest(payload)

    assert result.status == "duplicate"
    assert result.duplicate is True
    assert result.score == 0
    assert result.transaction_id is None
    assert repo.create_calls == []


@pytest.mark.asyncio
async def test_ingest_raises_when_no_parser_matches():
    payload = EmailIngestionRequest(
        sender="unknown@example.com",
        subject="Hello",
        body="No transaction details here",
    )

    repo = SpyRepo()
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(None),
        scoring_service=StubScoringService(0.0),
    )
    service.parsers = [StubParser(parsed=None, can_parse=False)]

    with pytest.raises(
        NoParserMatchedError, match="No parser available for this email"
    ):
        await service.ingest(payload)


@pytest.mark.asyncio
async def test_ingest_uses_received_at_when_occurred_at_is_missing():
    received_at = datetime(2026, 7, 3, 12, 0, tzinfo=timezone.utc)
    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
        received_at=received_at,
    )
    parsed = ParsedBankAlert(
        bank_name="Banco Popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text=payload.body,
    )

    repo = SpyRepo(exists_result=False)
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(parsed),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    await service.ingest(payload)

    assert repo.create_calls[0]["parsed"].occurred_at == received_at


@pytest.mark.asyncio
async def test_ingest_forwards_to_izihub_when_token_present_and_not_duplicate(
    monkeypatch,
):
    forward_calls = []

    async def spy_forward(payload, settings):
        forward_calls.append((payload, settings))

    monkeypatch.setattr("app.services.ingestion_service.forward_to_izihub", spy_forward)

    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Sirena tarjeta 1234",
        ingestion_token="tok-123",
    )
    parsed = ParsedBankAlert(
        bank_name="Banco popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text=payload.body,
    )

    repo = SpyRepo(exists_result=False, transaction_id=123)
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(parsed),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    result = await service.ingest(payload)

    assert result.status == "ingested"
    assert len(forward_calls) == 1
    assert forward_calls[0][0] is payload


@pytest.mark.asyncio
async def test_ingest_skips_izihub_relay_when_token_absent(monkeypatch):
    forward_calls = []

    async def spy_forward(payload, settings):
        forward_calls.append((payload, settings))

    monkeypatch.setattr("app.services.ingestion_service.forward_to_izihub", spy_forward)

    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Sirena tarjeta 1234",
    )
    parsed = ParsedBankAlert(
        bank_name="Banco popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text=payload.body,
    )

    repo = SpyRepo(exists_result=False, transaction_id=123)
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(parsed),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    await service.ingest(payload)

    assert forward_calls == []


@pytest.mark.asyncio
async def test_ingest_skips_izihub_relay_on_hash_duplicate(monkeypatch):
    forward_calls = []

    async def spy_forward(payload, settings):
        forward_calls.append((payload, settings))

    monkeypatch.setattr("app.services.ingestion_service.forward_to_izihub", spy_forward)

    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
        ingestion_token="tok-123",
    )
    parsed = ParsedBankAlert(
        bank_name="Banco Popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text=payload.body,
    )

    repo = SpyRepo(exists_result=True)
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(parsed),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    result = await service.ingest(payload)

    assert result.status == "duplicate"
    assert forward_calls == []


@pytest.mark.asyncio
async def test_ingest_skips_izihub_relay_on_insert_race_duplicate(monkeypatch):
    forward_calls = []

    async def spy_forward(payload, settings):
        forward_calls.append((payload, settings))

    monkeypatch.setattr("app.services.ingestion_service.forward_to_izihub", spy_forward)

    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
        ingestion_token="tok-123",
    )
    parsed = ParsedBankAlert(
        bank_name="Banco Popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text=payload.body,
    )

    repo = SpyRepo(
        exists_result=False,
        create_error=DuplicateTransactionError(),
    )
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(parsed),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    result = await service.ingest(payload)

    assert result.status == "duplicate"
    assert forward_calls == []


@pytest.mark.asyncio
async def test_ingest_returns_duplicate_when_insert_hits_unique_constraint():
    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
    )
    parsed = ParsedBankAlert(
        bank_name="Banco Popular",
        account_hint="1234",
        transaction_type="purchase",
        amount=Decimal("1250.00"),
        currency="DOP",
        merchant="NACIONAL",
        raw_text=payload.body,
    )

    repo = SpyRepo(
        exists_result=False,
        create_error=DuplicateTransactionError(),
    )
    service = EmailIngestionService(
        repo=repo,
        dedup_service=StubDedupService("hash-123"),
        normalization_service=StubNormalizationService(parsed),
        scoring_service=StubScoringService(0.4),
    )
    service.parsers = [StubParser(parsed)]

    result = await service.ingest(payload)

    assert result.status == "duplicate"
    assert result.duplicate is True
    assert result.score == 0
    assert result.transaction_id is None
