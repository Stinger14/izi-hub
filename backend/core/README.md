# Core

To start Phoenix server:

* 1) `mix setup` - install deps
* 2) `mix phx.server` or `iex -S mix phx.server` - starts server

## Docker setup (iziHub + Postgres)

Bring up all services:

```bash
docker compose up --build
```

The `docker-compose.yml` expects a `.env` file for local configuration.

The app is available at:

* [`http://localhost:4000`](http://localhost:4000)
* Live apps [`http://localhost:4000/liveapps`](http://localhost:4000/liveapps)

## Production environment

* `SECRET_KEY_BASE`
* `DATABASE_URL`
* `PHX_HOST`
* `PHX_SERVER=true`
* `PORT`
* `LIVE_VIEW_SIGNING_SALT`
* `GITHUB_TOKEN`
* `LIVEBOOK_APPS_BASE_URL`

Optional (mailer):

* `SMTP_HOST`
* `SMTP_USERNAME`
* `SMTP_PASSWORD`
* `SMTP_PORT` (default `587`)

## Gigalixir deployment notes

This repo includes the following files for Gigalixir deploys:

* `elixir_buildpack.config` (pins Elixir/Erlang)
* `phoenix_static_buildpack.config` (pins Node)
* `.buildpacks` (explicit buildpack order)

## Learn more

* Official website: https://www.phoenixframework.org/
* Docs: https://hexdocs.pm/phoenix
* Source: https://github.com/phoenixframework/phoenix
