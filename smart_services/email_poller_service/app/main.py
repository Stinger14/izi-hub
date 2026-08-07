from app.core.logging import configure_logging
from app.services.poller import run_poll_cycle


def main():
    configure_logging()
    run_poll_cycle()


if __name__ == "__main__":
    main()
