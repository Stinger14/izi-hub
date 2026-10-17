from typing import TypeVar

from anthropic import AsyncAnthropic
from pydantic import BaseModel

T = TypeVar("T", bound=BaseModel)

# `fallbacks="default"` lets the API re-run a request that a safety classifier
# declines on Anthropic's recommended fallback model, inside the same call.
FALLBACK_BETA = "server-side-fallback-2026-07-01"


class GenerationRefusedError(Exception):
    """Claude (and its fallback) declined the request."""


class GenerationFailedError(Exception):
    """Claude answered, but not with a usable structured result."""


class ClaudeWriter:
    """One structured-output call to Claude: a prompt in, a validated model out."""

    def __init__(self, client: AsyncAnthropic, model: str, effort: str):
        self.client = client
        self.model = model
        self.effort = effort

    async def generate(self, system: str, prompt: str, output: type[T]) -> T:
        response = await self.client.beta.messages.parse(
            model=self.model,
            max_tokens=16000,
            system=system,
            messages=[{"role": "user", "content": prompt}],
            output_format=output,
            output_config={"effort": self.effort},
            betas=[FALLBACK_BETA],
            fallbacks="default",
        )

        if response.stop_reason == "refusal":
            raise GenerationRefusedError("The AI declined to write this. Try rephrasing it.")

        if response.stop_reason == "max_tokens" or response.parsed_output is None:
            raise GenerationFailedError("The AI response was incomplete. Try again.")

        return response.parsed_output
