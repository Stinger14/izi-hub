import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/core start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :core, CoreWeb.Endpoint, server: true
end

config :core, Core.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: System.get_env("SSL") == "true"

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST:5432/DB_NAME
      """

  host = System.get_env("PHX_HOST") || "example.com"
  scheme = System.get_env("PHX_SCHEME") || "https"
  port = String.to_integer(System.get_env("PORT") || "4000")
  signing_salt = System.get_env("LIVE_VIEW_SIGNING_SALT") || "GI71qW3j29IIGwNi"

  config :core, Core.Repo, url: database_url

  config :core, CoreWeb.Endpoint,
    url: [host: host, scheme: scheme, port: port],
    http: [ip: {0, 0, 0, 0}, port: port],
    check_origin: ["http://#{host}", "https://#{host}"],
    live_view: [signing_salt: signing_salt]
end

if System.get_env("SMTP_HOST") do
  config :core, Core.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("SMTP_HOST"),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
    tls: :always,
    auth: :always
end
