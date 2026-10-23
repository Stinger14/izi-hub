from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    ANTHROPIC_API_KEY: str | None = None
    CLAUDE_MODEL: str = "claude-opus-5-5"
    CLAUDE_EFFORT: str = "medium"
    POLO_STUDIO_API_KEY: str | None = None
    WHISPER_MODEL: str = "small"
    LOG_LEVEL: str = "INFO"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
