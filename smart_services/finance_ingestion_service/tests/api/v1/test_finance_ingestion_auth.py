from fastapi.testclient import TestClient

from app.main import create_app
from app.core.config import settings
from app.modules.finance.dependencies import get_email_ingestion_service


class StubService:
    async def ingest(self, payload):
        return {
            "status": "ingested",
            "duplicate": False,
            "score": 0.0,
            "transaction_id": 1,
        }


def _client_with_stub_service():
    app = create_app()
    app.dependency_overrides[get_email_ingestion_service] = lambda: StubService()
    return app, TestClient(app)


def test_rejects_missing_authorization_header(monkeypatch):
    monkeypatch.setattr(settings, "INGESTION_INBOUND_API_KEY", "test-key")
    app, client = _client_with_stub_service()

    response = client.post(
        "/api/v1/finance/ingestion/email",
        json={"sender": "alertas@popular.com", "subject": "s", "body": "b"},
    )

    assert response.status_code == 401
    app.dependency_overrides.clear()


def test_rejects_wrong_bearer_token(monkeypatch):
    monkeypatch.setattr(settings, "INGESTION_INBOUND_API_KEY", "test-key")
    app, client = _client_with_stub_service()

    response = client.post(
        "/api/v1/finance/ingestion/email",
        json={"sender": "alertas@popular.com", "subject": "s", "body": "b"},
        headers={"Authorization": "Bearer wrong-key"},
    )

    assert response.status_code == 401
    app.dependency_overrides.clear()


def test_accepts_correct_bearer_token(monkeypatch):
    monkeypatch.setattr(settings, "INGESTION_INBOUND_API_KEY", "test-key")
    app, client = _client_with_stub_service()

    response = client.post(
        "/api/v1/finance/ingestion/email",
        json={"sender": "alertas@popular.com", "subject": "s", "body": "b"},
        headers={"Authorization": "Bearer test-key"},
    )

    assert response.status_code == 200
    app.dependency_overrides.clear()


def test_returns_500_when_key_not_configured(monkeypatch):
    monkeypatch.setattr(settings, "INGESTION_INBOUND_API_KEY", None)
    app, client = _client_with_stub_service()

    response = client.post(
        "/api/v1/finance/ingestion/email",
        json={"sender": "alertas@popular.com", "subject": "s", "body": "b"},
        headers={"Authorization": "Bearer anything"},
    )

    assert response.status_code == 500
    app.dependency_overrides.clear()
