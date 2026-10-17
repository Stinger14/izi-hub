from fastapi import FastAPI

from app.api.router import api_router
from app.core.logging import configure_logging


def create_app() -> FastAPI:
    configure_logging()

    app = FastAPI(
        title="Polo Studio",
        version="0.1.0",
        description="AI writing and media helpers for IziHub's creator studio",
    )
    app.include_router(api_router)

    @app.get("/health", tags=["Health"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
