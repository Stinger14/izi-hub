from datetime import datetime, timezone
from types import SimpleNamespace

import httpx
import pytest

from app.modules.finance.izihub_client import forward_to_izihub
from app.modules.finance.schemas import EmailIngestionRequest


class FakeAsyncClient:
    def __init__(self, calls, error=None):
        self.calls = calls
        self.error = error

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def post(self, url, json, headers):
        self.calls.append({"url": url, "json": json, "headers": headers})
        if self.error:
            raise self.error


def build_settings():
    return SimpleNamespace(
        IZIHUB_API_BASE_URL="http://localhost:4000",
        FINANCE_INGESTION_API_KEY="test-api-key",
    )


@pytest.mark.asyncio
async def test_forward_to_izihub_posts_expected_payload_and_headers(monkeypatch):
    # Contract guard: this body shape (ingestion_token as a top-level sibling
    # of "email", not nested inside it) must match the pattern match in
    # backend/core/lib/core_web/controllers/api/finance/service_email_ingestion_controller.ex:6
    # (`def create(conn, %{"ingestion_token" => token} = params)`). If this
    # test needs to change, check that controller first.
    calls = []
    monkeypatch.setattr(
        "app.modules.finance.izihub_client.httpx.AsyncClient",
        lambda timeout: FakeAsyncClient(calls),
    )

    received_at = datetime(2026, 7, 3, 12, 0, tzinfo=timezone.utc)
    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
        received_at=received_at,
        ingestion_token="tok-123",
    )

    await forward_to_izihub(payload, build_settings())

    assert len(calls) == 1
    call = calls[0]
    assert call["url"] == "http://localhost:4000/api/service/finance/email-ingestion"
    assert call["headers"] == {"Authorization": "Bearer test-api-key"}
    assert call["json"] == {
        "email": {
            "from": "alertas@popular.com",
            "subject": "Alerta de consumo",
            "text_body": "Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
            "received_at": received_at.isoformat(),
        },
        "ingestion_token": "tok-123",
    }


@pytest.mark.asyncio
async def test_forward_to_izihub_serializes_missing_received_at_as_none(monkeypatch):
    calls = []
    monkeypatch.setattr(
        "app.modules.finance.izihub_client.httpx.AsyncClient",
        lambda timeout: FakeAsyncClient(calls),
    )

    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
        ingestion_token="tok-123",
    )

    await forward_to_izihub(payload, build_settings())

    assert calls[0]["json"]["email"]["received_at"] is None


@pytest.mark.asyncio
async def test_forward_to_izihub_swallows_http_errors(monkeypatch):
    calls = []
    monkeypatch.setattr(
        "app.modules.finance.izihub_client.httpx.AsyncClient",
        lambda timeout: FakeAsyncClient(calls, error=httpx.ConnectError("boom")),
    )

    payload = EmailIngestionRequest(
        sender="alertas@popular.com",
        subject="Alerta de consumo",
        body="Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
        ingestion_token="tok-123",
    )

    await forward_to_izihub(payload, build_settings())
