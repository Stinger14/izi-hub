# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository context

This directory is one Python service inside the `izi-hub` monorepo (git root is `izi-hub/`, an Elixir/Phoenix app with a `smart_services/` directory of polyglot microservices — e.g. `finance_dispatcher_service` next to this one is written in Go). All `git` commands run from here still operate on the monorepo; paths in `git status`/`diff` output are relative to `izi-hub/`, not this directory.

This service (`finance_ingestion_service`) is a FastAPI service that ingests bank alert emails, parses transaction data out of them, deduplicates records, scores risk, and stores transactions in PostgreSQL.

## Commands

All commands run from this directory (`smart_services/finance_ingestion_service`) using `uv`.

```bash
uv sync                                   # install dependencies
uv run uvicorn app.main:app --reload      # run the dev server (docs at /docs)
uv run pytest                             # run the full test suite
uv run pytest tests/services/test_ingestion_service.py   # run a single test file
uv run pytest tests/services/test_ingestion_service.py::test_ingest_persists_non_duplicate_email  # single test
uv run ruff check .                       # lint
uv run ruff format .                      # format
alembic upgrade head                      # apply DB migrations
alembic revision --autogenerate -m "..."  # create a new migration after model changes
```

The test suite is fully hermetic — no live Postgres is needed to run it. DB-touching code (`FinanceTransactionRepo`) is tested against a hand-rolled `FakeAsyncSession`, not a real engine or SQLite. `tests/conftest.py` only exists to put the project root on `sys.path` so `app` imports resolve.

Config is loaded via `pydantic-settings` from a `.env` file (`DATABASE_URL`, `DB_ECHO`) — see README.md for the expected values.

## Architecture

Request flow for the single endpoint (`POST /api/v1/finance/ingestion/email`):

```
app/main.py (FastAPI app)
  -> app/api/router.py (mounts /api/v1)
    -> app/api/v1/finance_ingestion.py (route handler)
      -> app/modules/finance/dependencies.py (wires up EmailIngestionService via DI)
        -> app/services/ingestion_service.py: EmailIngestionService.ingest()
             1. select a parser from self.parsers that can_parse() the email
             2. parser.parse() -> ParsedBankAlert
             3. NormalizationService.normalize() (uppercase merchant/currency, lowercase type)
             4. fall back occurred_at to the request's received_at if the parser found none
             5. DedupService.create_hash() -> sha256 over sender/subject/amount/etc.
             6. FinanceTransactionRepo.exists_by_hash() -> short-circuit "duplicate" response
             7. ScoringService.score() -> float 0..1 (is_suspicious = score >= 0.7)
             8. FinanceTransactionRepo.create() -> persist, catching a race on the unique
                dedup_hash constraint (translated to DuplicateTransactionError) and
                returning a "duplicate" result instead of raising
```

Key layering conventions:

- **`app/api/`** — HTTP layer only. Route handlers catch `ValueError` from the service layer and turn it into a `422`; no other error translation happens here.
- **`app/modules/finance/`** — the domain: SQLAlchemy models (`models.py`), Pydantic schemas (`schemas.py`), the repository (`repository.py`), domain exceptions (`exceptions.py`), and the FastAPI dependency wiring (`dependencies.py`). Everything here is finance-specific persistence/data-shape concerns.
- **`app/services/`** — stateless business logic units (`DedupService`, `NormalizationService`, `ScoringService`, `EmailIngestionService`) plus the parser strategy pattern under `app/services/parsers/`.
- **Parsers** implement the `EmailParser` ABC (`can_parse` / `parse`) in `app/services/parsers/base.py`. `BankAlertParser` is the only implementation today, matched by Spanish-language keywords (`consumo`, `compra`, `retiro`, `transferencia`, `tarjeta`) and RD$ amount patterns. `EmailIngestionService._select_parser` picks the first parser whose `can_parse` returns true; no match raises `ValueError("No parser available for this email")`, which the API layer turns into a `422`. Adding a new bank format means adding a new parser to `EmailIngestionService.parsers`, not branching inside the existing one.
- **Dedup** hashes are computed from normalized fields (sender, subject, amount, currency, transaction_type, account_hint, merchant, first 300 chars of raw_text) — collisions are treated as duplicates in two places: a pre-check (`exists_by_hash`) and a post-insert unique-constraint catch in `FinanceTransactionRepo.create` (races between concurrent ingests of the same email are expected and handled, not just optimistically ignored).
- **Scoring** is a simple additive heuristic in `ScoringService` (large amount, withdrawal/transfer type, missing merchant, unknown bank each add weight, capped at 1.0) — `is_suspicious` in the DB is derived as `score >= 0.7` at write time in the repository, not recomputed elsewhere.

All request/response contracts (including the `422` cases for invalid payload / no matching parser, and rejection of unknown request fields) are documented in README.md — keep it in sync with `app/modules/finance/schemas.py` when changing the API surface.

## Commit workflow

Only group changes into commits and draft commit messages when the user types `gg`. Do not do this proactively just because a feature or fix looks finished.

When triggered: group the changes into logical commits and draft commit messages matching this repo's history — but **never run `git commit` (or `git push`) without the user reviewing and explicitly approving the message first.** Before presenting the commit(s) for review, run `uv run ruff check .` and `uv run pytest` and surface the results alongside the proposed message(s) — this is informational for the review, not a gate that blocks proposing the commit.

Message style, derived from `git log`:

```
<Type>[(scope)]: <Capitalized imperative summary>[. <optional second clause for a compound change>]
```

- `Type` is one of `Feat`, `Fix`, `Chore`, `Test`, `Refactor` (occasionally `Docs`), always capitalized.
- `(scope)` is optional, lowercase-kebab, and names the affected service/module — e.g. `(finance-ingestion)`, `(smart-services)`, `(web)`, `(core)`. Omit it for changes scoped to the whole repo/root.
- The summary is imperative mood ("add", "handle", "redesign" — not "added"/"adds"), starts capitalized, and has no required trailing period. A second clause (e.g. `. Update tests`) is used for a closely related follow-on change, not for unrelated changes — those get their own commit.

Examples from this service's history: `Feat(finance-ingestion): implement parsing, scoring, dedup, and persistence flow`, `Fix(finance-ingestion): handle duplicate races & normalize parser behavior`, `Test(finance-ingestion): create core ingestion flow coverage`.

## Migration discipline

Any change to `app/modules/finance/models.py` must ship a matching Alembic migration (`alembic revision --autogenerate -m "..."`) in the same commit — never let the model and migration drift apart. Check the generated migration into `alembic/versions/` and review its `upgrade()`/`downgrade()` before proposing the commit for review, since autogenerate can miss things (e.g. column-level `Numeric` precision changes, renames it sees as drop+add).
