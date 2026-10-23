"""Request and result shapes for the writing helpers.

Result models double as Claude's structured-output schemas, so keep them to
plain types (no length/range constraints); counts are asked for in the prompt.
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Language = Literal["es", "en"]
Kind = Literal["video", "reel", "post", "live"]
Tone = Literal["casual", "funny", "inspiring", "informative"]


class StrictRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")


# --- Requests ---------------------------------------------------------------


class HooksRequest(StrictRequest):
    topic: str = Field(min_length=1, max_length=4000)
    language: Language = "es"
    kind: Kind = "reel"


class ScriptRequest(StrictRequest):
    topic: str = Field(min_length=1, max_length=8000)
    language: Language = "es"
    kind: Kind = "reel"
    target_seconds: int = Field(default=60, ge=15, le=600)


class CaptionRequest(StrictRequest):
    source: str = Field(min_length=1, max_length=60000)
    language: Language = "es"
    tone: Tone = "casual"


class RepurposeRequest(StrictRequest):
    transcript: str = Field(min_length=1, max_length=200000)
    srt: str | None = Field(default=None, max_length=400000)
    language: Language = "es"


# --- Results ----------------------------------------------------------------


class Hook(BaseModel):
    text: str
    angle: str


class HooksResult(BaseModel):
    hooks: list[Hook]


class ScriptBeat(BaseModel):
    label: str
    says: str
    shows: str


class ScriptResult(BaseModel):
    title: str
    hook: str
    beats: list[ScriptBeat]
    cta: str
    estimated_seconds: int


class CaptionVariant(BaseModel):
    caption: str
    cta: str


class CaptionResult(BaseModel):
    variants: list[CaptionVariant]
    hashtags: list[str]


class Chapter(BaseModel):
    start: str
    title: str


class Clip(BaseModel):
    start: str
    end: str
    hook: str
    reason: str


class RepurposeResult(BaseModel):
    title: str
    summary: str
    chapters: list[Chapter]
    clips: list[Clip]
