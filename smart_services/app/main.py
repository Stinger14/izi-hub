from fastapi import FastAPI


def create_app() -> FastAPI:
    app = FastAPI(
        title="Izihub Smart Services",
        version="0.1.0",
        description="Transaction intelligence service for finance ingestion",
    )
    return app


app = create_app()
