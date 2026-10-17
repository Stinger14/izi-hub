import secrets

from fastapi import Header, HTTPException

from app.core.config import settings


async def verify_api_key(authorization: str | None = Header(default=None)) -> None:
    expected = settings.POLO_STUDIO_API_KEY
    if not expected:
        raise HTTPException(status_code=500, detail="polo studio API key not configured")

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="unauthorized")

    token = authorization.removeprefix("Bearer ")
    if not secrets.compare_digest(token, expected):
        raise HTTPException(status_code=401, detail="unauthenticated")
