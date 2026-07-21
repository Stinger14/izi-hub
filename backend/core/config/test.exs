import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "core_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
# config :core, CoreWeb.Endpoint,
#   http: [ip: {127, 0, 0, 1}, port: 4002],
#   secret_key_base: "bvt4UNyGIifF5/518CfY2YuTULJkzoGRZ8nrxDu7DIxTX+YgjBreV+XJtCkz77IY",
#   server: false
config :core, CoreWeb.Endpoint,
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "testsigningsalt"]

# In test we don't send emails
config :core, Core.Mailer, adapter: Swoosh.Adapters.Test

# Fixed shared secret for the service-to-service finance ingestion path
config :core, :finance_ingestion_api_key, "test_finance_ingestion_api_key"

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
