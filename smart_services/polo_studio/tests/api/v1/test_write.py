import httpx
import pytest
from anthropic import RateLimitError
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app
from app.modules.studio.dependencies import get_studio_writer
from app.modules.studio.schemas import Hook, HooksResult
from app.services.claude_writer import ClaudeWriter
from app.services.studio_writer import StudioWriter
from tests.fakes import FakeAnthropic

API_KEY = "test-key"
AUTH = {"Authorization": f"Bearer {API_KEY}"}
HOOKS = HooksResult(hooks=[Hook(text="¿Sabías esto?", angle="question")])


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(settings, "POLO_STUDIO_API_KEY", API_KEY)
    yield TestClient(app)
    app.dependency_overrides.clear()


def use_fake(**kwargs) -> FakeAnthropic:
    fake = FakeAnthropic(**kwargs)
    writer = StudioWriter(ClaudeWriter(fake, "claude-opus-5-5", "medium"))
    app.dependency_overrides[get_studio_writer] = lambda: writer
    return fake


def test_health_needs_no_auth(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_hooks_returns_result(client):
    use_fake(parsed_output=HOOKS)

    response = client.post("/api/v1/write/hooks", json={"topic": "mangú"}, headers=AUTH)

    assert response.status_code == 200
    assert response.json() == {"hooks": [{"text": "¿Sabías esto?", "angle": "question"}]}


@pytest.mark.parametrize("headers", [{}, {"Authorization": "Bearer wrong"}])
def test_rejects_missing_or_wrong_token(client, headers):
    fake = use_fake(parsed_output=HOOKS)

    response = client.post("/api/v1/write/hooks", json={"topic": "x"}, headers=headers)

    assert response.status_code == 401
    assert fake.calls == []


def test_500_when_api_key_not_configured(client, monkeypatch):
    monkeypatch.setattr(settings, "POLO_STUDIO_API_KEY", None)
    use_fake(parsed_output=HOOKS)

    response = client.post("/api/v1/write/hooks", json={"topic": "x"}, headers=AUTH)

    assert response.status_code == 500


def test_rejects_unknown_fields_and_empty_topic(client):
    fake = use_fake(parsed_output=HOOKS)

    extra = client.post("/api/v1/write/hooks", json={"topic": "x", "model": "other"}, headers=AUTH)
    empty = client.post("/api/v1/write/hooks", json={"topic": ""}, headers=AUTH)

    assert extra.status_code == 422
    assert empty.status_code == 422
    assert fake.calls == []


def test_refusal_is_422(client):
    use_fake(parsed_output=None, stop_reason="refusal")

    response = client.post("/api/v1/write/caption", json={"source": "x"}, headers=AUTH)

    assert response.status_code == 422
    assert "declined" in response.json()["detail"]


def test_rate_limit_is_429(client):
    request = httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    error = RateLimitError("rate limited", response=httpx.Response(429, request=request), body=None)
    use_fake(error=error)

    response = client.post("/api/v1/write/script", json={"topic": "x"}, headers=AUTH)

    assert response.status_code == 429
