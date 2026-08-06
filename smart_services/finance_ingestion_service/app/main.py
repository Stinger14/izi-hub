from fastapi import FastAPI

from app.api.router import api_router
from app.core.logging import configure_logging


def create_app() -> FastAPI:
    configure_logging()

    app = FastAPI(
        title="Izihub Finance Intelligence",
        version="0.1.0",
        description="Transaction intelligence service for finance ingestion",
    )
    app.include_router(api_router)
    return app


app = create_app()
