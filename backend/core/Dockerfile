FROM elixir:1.15 AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git nodejs npm && \
    rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm ci --prefix ./assets

COPY lib lib
COPY priv priv
COPY assets assets

RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM debian:bookworm-slim AS runner

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl libncurses6 libstdc++6 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN useradd --system --create-home --shell /bin/bash app

COPY --from=builder --chown=app:app /app/_build/prod/rel/core ./

USER app
ENV HOME=/home/app

EXPOSE 4000

CMD ["sh", "-c", "bin/core eval \"Core.Release.migrate\" && bin/core start"]
