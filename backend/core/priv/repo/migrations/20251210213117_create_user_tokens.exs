defmodule Core.Repo.Migrations.CreateUserTokens do
  use Ecto.Migration

  def change do
    create table(:user_tokens) do
      add :token, :string
      add :token_type, :string
      add :expires_at, :naive_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
