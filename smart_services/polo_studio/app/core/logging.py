import logging.config as lc

from app.core.config import settings


def configure_logging() -> None:
    lc.dictConfig(
        {
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "default": {
                    "format": "%(asctime)s - %(levelname)s - %(name)s - %(message)s",
                },
            },
            "handlers": {
                "console": {
                    "class": "logging.StreamHandler",
                    "formatter": "default",
                    "stream": "ext://sys.stderr",
                },
            },
            "root": {
                "level": settings.LOG_LEVEL,
                "handlers": ["console"],
            },
        }
    )
