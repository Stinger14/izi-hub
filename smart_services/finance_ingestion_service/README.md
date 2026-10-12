# Finance Ingestion Service

FastAPI service for ingesting bank alert emails, parsing transaction data, deduplicating records, scoring risk, and storing transactions in PostgreSQL.

## Prerequisites

- Python 3.12+
- PostgreSQL
- uv

## Setup

Install dependencies:

```bash
uv sync
```

Create a `.env` file:

```env
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/izihub_finance_ingestion
DB_ECHO=false
IZIHUB_API_BASE_URL=http://localhost:4000
FINANCE_INGESTION_API_KEY=<shared secret, same value as izi-hub's FINANCE_INGESTION_API_KEY>
INGESTION_INBOUND_API_KEY=<separate secret, required by callers of this service's own /email endpoint>
```

Create the database:

```sql
CREATE DATABASE izihub_finance_ingestion;
```

Run migrations:

```bash
alembic upgrade head
```

## Run

```bash
uv run uvicorn app.main:app --reload
```

API docs:
- `http://127.0.0.1:8000/docs`

## Endpoint

`POST /api/v1/finance/ingestion/email`

Requires an `Authorization: Bearer <INGESTION_INBOUND_API_KEY>` header — requests
without it, or with the wrong key, get a `401`.

Example request:

```json
{
  "sender": "alertas@popular.com",
  "subject": "Alerta de consumo",
  "body": "Consumo por RD$ 1,250.00 en Supermercado Nacional tarjeta 1234"
}
```

`ingestion_token` (optional): when present and the transaction isn't a
duplicate, the service also relays the email to izi-hub's
`/api/service/finance/email-ingestion` endpoint so it shows up as a
pending-review transaction for the token's owning user. Omit it to use this
service standalone, with no relay.
