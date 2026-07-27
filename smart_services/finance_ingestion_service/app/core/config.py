from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str = (
        "postgresql+asyncpg://postgres:postgres@localhost:5432/izihub_finance_ingestion"
    )
    DB_ECHO: bool = False
    IZIHUB_API_BASE_URL: str | None = None
    FINANCE_INGESTION_API_KEY: str | None = None
    INGESTION_INBOUND_API_KEY: str | None = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
