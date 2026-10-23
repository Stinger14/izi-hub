from app.modules.studio.schemas import (
    CaptionRequest,
    CaptionResult,
    HooksRequest,
    HooksResult,
    RepurposeRequest,
    RepurposeResult,
    ScriptRequest,
    ScriptResult,
)
from app.prompts import writing
from app.services.claude_writer import ClaudeWriter


class StudioWriter:
    """The writing helpers: each one turns a request into a prompt and a result."""

    def __init__(self, writer: ClaudeWriter):
        self.writer = writer

    async def hooks(self, req: HooksRequest) -> HooksResult:
        prompt = writing.hooks(req.topic, req.language, req.kind)
        return await self.writer.generate(writing.SYSTEM, prompt, HooksResult)

    async def script(self, req: ScriptRequest) -> ScriptResult:
        prompt = writing.script(req.topic, req.language, req.kind, req.target_seconds)
        return await self.writer.generate(writing.SYSTEM, prompt, ScriptResult)

    async def caption(self, req: CaptionRequest) -> CaptionResult:
        prompt = writing.caption(req.source, req.language, req.tone)
        result = await self.writer.generate(writing.SYSTEM, prompt, CaptionResult)
        result.hashtags = normalize_hashtags(result.hashtags)
        return result

    async def repurpose(self, req: RepurposeRequest) -> RepurposeResult:
        prompt = writing.repurpose(req.transcript, req.srt, req.language)
        return await self.writer.generate(writing.SYSTEM, prompt, RepurposeResult)


def normalize_hashtags(tags: list[str]) -> list[str]:
    """Strip `#` and spaces and drop duplicates (case-insensitive), keeping order."""
    seen: set[str] = set()
    result = []
    for tag in tags:
        clean = "".join(tag.lstrip("#").split())
        if clean and clean.lower() not in seen:
            seen.add(clean.lower())
            result.append(clean)
    return result
