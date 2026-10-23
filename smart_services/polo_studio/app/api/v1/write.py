from collections.abc import Awaitable
from typing import Annotated

import anthropic
from fastapi import APIRouter, Depends, HTTPException

from app.core.security import verify_api_key
from app.modules.studio.dependencies import get_studio_writer
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
from app.services.claude_writer import GenerationFailedError, GenerationRefusedError
from app.services.studio_writer import StudioWriter

router = APIRouter(
    prefix="/write",
    tags=["Writing helpers"],
    dependencies=[Depends(verify_api_key)],
)

Writer = Annotated[StudioWriter, Depends(get_studio_writer)]


async def run[T](call: Awaitable[T]) -> T:
    """Translate generation and Anthropic API errors into HTTP errors."""
    try:
        return await call
    except GenerationRefusedError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except GenerationFailedError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except anthropic.RateLimitError as exc:
        raise HTTPException(
            status_code=429, detail="The AI is busy. Try again in a minute."
        ) from exc
    except (anthropic.APIStatusError, anthropic.APIConnectionError) as exc:
        raise HTTPException(
            status_code=502, detail="The AI service is unavailable. Try again."
        ) from exc


@router.post("/hooks", response_model=HooksResult)
async def hooks(payload: HooksRequest, writer: Writer):
    return await run(writer.hooks(payload))


@router.post("/script", response_model=ScriptResult)
async def script(payload: ScriptRequest, writer: Writer):
    return await run(writer.script(payload))


@router.post("/caption", response_model=CaptionResult)
async def caption(payload: CaptionRequest, writer: Writer):
    return await run(writer.caption(payload))


@router.post("/repurpose", response_model=RepurposeResult)
async def repurpose(payload: RepurposeRequest, writer: Writer):
    return await run(writer.repurpose(payload))
