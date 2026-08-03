"""
Configure IMAP creds, ingestion URL, poll interval
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    IMAP_HOST: str
    IMAP_USERNAME: str
    IMAP_PASSWORD: str
    IMAP_PORT: int = 993
    IZIHUB_INGESTION_URL: str
    INGESTION_INBOUND_API_KEY: str
    INGESTION_TOKEN: str
    POLL_INTERVAL_SECONDS: int = 300
    WATERMARK_FILE_PATH: str
    MAX_BATCH_SIZE: int = 50

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
