# Polo Studio

AI writing and media helpers for IziHub's creator studio. A stateless FastAPI service: IziHub (`backend/core`) stores the creator's content and calls this service to generate text with Claude.

## Run

```bash
uv sync
uv run uvicorn app.main:app --reload --port 8100   # docs at http://localhost:8100/docs
uv run pytest
uv run ruff check . && uv run ruff format .
```

## Configuration (`.env`)

| Variable | Default | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | none | Claude API key |
| `POLO_STUDIO_API_KEY` | none (required) | Bearer token IziHub sends; requests get `500` until it's set |
| `CLAUDE_MODEL` | `claude-opus-5-5` | Model for the writing helpers |
| `CLAUDE_EFFORT` | `medium` | `output_config.effort` (`low`…`max`) |
| `LOG_LEVEL` | `INFO` | |

## API

Every `/api/v1/*` route needs `Authorization: Bearer <POLO_STUDIO_API_KEY>`. Unknown request fields are rejected with `422`. `language` is `es` (Dominican Spanish, default) or `en`.

| Route | Body | Returns |
|---|---|---|
| `POST /api/v1/write/hooks` | `topic`, `language`, `kind` (`video`/`reel`/`post`/`live`) | 5 `hooks` (`text`, `angle`) |
| `POST /api/v1/write/script` | `topic`, `language`, `kind`, `target_seconds` (15–600) | `title`, `hook`, `beats` (`label`, `says`, `shows`), `cta`, `estimated_seconds` |
| `POST /api/v1/write/caption` | `source` (notes or transcript), `language`, `tone` (`casual`/`funny`/`inspiring`/`informative`) | 3 `variants` (`caption`, `cta`), `hashtags` (no `#`) |
| `POST /api/v1/write/repurpose` | `transcript`, optional `srt`, `language` | `title`, `summary`, `chapters` (`start`, `title`), `clips` (`start`, `end`, `hook`, `reason`) |
| `GET /health` | | `{"status": "ok"}` (no auth) |

Errors: `401` (bad token), `422` (invalid body, or the AI declined the request), `429` (Claude rate limit), `502` (incomplete AI response or Claude unavailable).

```bash
curl -s localhost:8100/api/v1/write/caption \
  -H "Authorization: Bearer $POLO_STUDIO_API_KEY" -H 'Content-Type: application/json' \
  -d '{"source": "Receta rápida de mangú con los tres golpes", "tone": "funny"}'
```
