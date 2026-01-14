defmodule Core.Repo.Migrations.CreateUserTokens do
  use Ecto.Migration

  def change do
    create table(:user_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string
      add :token_type, :string
      add :expires_at, :naive_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      timestamps()
    end

    create index(:user_tokens, [:user_id])
  end
end
