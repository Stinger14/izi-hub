defmodule Core.Config do
  use Skogsra

  # Repo config (defaults :dev)
  @envdoc "DB username"
  app_env(:db_username, :core, [Core.Repo, :username],
    os_env: "POSTGRES_USER",
    default: "postgres"
  )

  @envdoc "DB password"
  app_env(:db_password, :core, [Core.Repo, :password],
    os_env: "POSTGRES_PASSWORD",
    default: ""
  )

  @envdoc "DB hostname"
  app_env(:db_hostname, :core, [Core.Repo, :hostname],
    os_env: "POSTGRES_HOST",
    default: "localhost"
  )

  @envdoc "DB port"
  app_env(:db_port, :core, [Core.Repo, :port],
    os_env: "POSTGRES_PORT",
    default: 5432
  )

  @envdoc "DB name"
  app_env(:db_name, :core, [Core.Repo, :database],
    os_env: "POSTGRES_DB",
    default: "izihub-db"
  )

  @envdoc "Secret key base"
  app_env(:secret_key_base, :core, [Core.Repo, :secret],
    os_env: "SECRET_KEY_BASE",
    default: ""
  )

  @envdoc "DB URL (prod)"
  app_env(:db_url, :core, [Core.Repo, :url],
    os_env: "DATABASE_URL",
    env_overrides: [
      prod: [required: true]
    ]
  )
end
