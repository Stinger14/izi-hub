import asyncio

import pytest

from app.modules.studio.schemas import Hook, HooksResult
from app.services.claude_writer import (
    FALLBACK_BETA,
    ClaudeWriter,
    GenerationFailedError,
    GenerationRefusedError,
)
from tests.fakes import FakeAnthropic

RESULT = HooksResult(hooks=[Hook(text="¿Sabías esto?", angle="question")])


def generate(client):
    writer = ClaudeWriter(client, model="claude-opus-5-5", effort="medium")
    return asyncio.run(writer.generate("system", "prompt", HooksResult))


def test_generate_returns_parsed_output_and_sends_structured_request():
    client = FakeAnthropic(parsed_output=RESULT)

    assert generate(client) == RESULT

    [call] = client.calls
    assert call["model"] == "claude-opus-5-5"
    assert call["system"] == "system"
    assert call["messages"] == [{"role": "user", "content": "prompt"}]
    assert call["output_format"] is HooksResult
    assert call["output_config"] == {"effort": "medium"}
    assert call["betas"] == [FALLBACK_BETA]
    assert call["fallbacks"] == "default"


def test_generate_raises_on_refusal():
    client = FakeAnthropic(parsed_output=None, stop_reason="refusal")

    with pytest.raises(GenerationRefusedError):
        generate(client)


@pytest.mark.parametrize(
    ("stop_reason", "parsed_output"),
    [("max_tokens", RESULT), ("end_turn", None)],
)
def test_generate_raises_when_output_is_unusable(stop_reason, parsed_output):
    client = FakeAnthropic(parsed_output=parsed_output, stop_reason=stop_reason)

    with pytest.raises(GenerationFailedError):
        generate(client)
