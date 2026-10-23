from functools import lru_cache

from anthropic import AsyncAnthropic

from app.core.config import settings
from app.services.claude_writer import ClaudeWriter
from app.services.studio_writer import StudioWriter


@lru_cache
def get_studio_writer() -> StudioWriter:
    # One client for the process, so its connection pool is reused.
    client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
    return StudioWriter(ClaudeWriter(client, settings.CLAUDE_MODEL, settings.CLAUDE_EFFORT))
