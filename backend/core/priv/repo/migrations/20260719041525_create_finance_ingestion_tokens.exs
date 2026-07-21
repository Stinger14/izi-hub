defmodule Core.Repo.Migrations.CreateFinanceIngestionTokens do
  use Ecto.Migration

  def change do
    create table(:finance_ingestion_tokens, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:token, :string, null: false)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:revoked_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:finance_ingestion_tokens, [:token]))
    create(index(:finance_ingestion_tokens, [:user_id]))
  end
end
