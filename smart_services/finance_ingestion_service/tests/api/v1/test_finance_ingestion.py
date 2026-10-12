from fastapi.testclient import TestClient

from app.core.security import verify_ingestion_api_key
from app.main import create_app
from app.modules.finance.dependencies import get_email_ingestion_service
from app.modules.finance.exceptions import NoParserMatchedError


class StubService:
    def __init__(self, result=None, error=None):
        self.result = result
        self.error = error

    async def ingest(self, payload):
        if self.error:
            raise self.error
        return self.result


def test_ingest_email_returns_success_response():
    app = create_app()

    app.dependency_overrides[get_email_ingestion_service] = lambda: StubService(
        result={
            "status": "ingested",
            "duplicate": False,
            "score": 0.4,
            "transaction_id": 123,
        }
    )
    app.dependency_overrides[verify_ingestion_api_key] = lambda: None

    client = TestClient(app)

    response = client.post(
        "/api/v1/finance/ingestion/email",
        json={
            "sender": "alertas@popular.com",
            "subject": "Alerta de consumo",
            "body": "Consumo por RD$ 1,250.00 en Nacional tarjeta 1234",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "status": "ingested",
        "duplicate": False,
        "score": 0.4,
        "transaction_id": 123,
    }

    app.dependency_overrides.clear()


def test_ingest_email_returns_422_for_domain_errors():
    app = create_app()

    app.dependency_overrides[get_email_ingestion_service] = lambda: StubService(
        error=NoParserMatchedError("No parser available for this email")
    )
    app.dependency_overrides[verify_ingestion_api_key] = lambda: None

    client = TestClient(app)

    response = client.post(
        "/api/v1/finance/ingestion/email",
        json={
            "sender": "alertas@popular.com",
            "subject": "Unknown alert",
            "body": "Some body",
        },
    )

    assert response.status_code == 422
    assert response.json() == {"detail": "No parser available for this email"}

    app.dependency_overrides.clear()
