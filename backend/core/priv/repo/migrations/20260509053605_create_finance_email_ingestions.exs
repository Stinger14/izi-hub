defmodule Core.Repo.Migrations.CreateFinanceEmailIngestions do
  use Ecto.Migration

  def change do
    create table(:finance_email_ingestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string
      add :message_id, :string
      add :sender, :string
      add :subject, :string
      add :received_at, :utc_datetime
      add :parser_name, :string
      add :status, :string, null: false
      add :error_reason, :string
      add :body_snippet, :string

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :transaction_id, references(:transactions, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:finance_email_ingestions, [:user_id])
    create index(:finance_email_ingestions, [:user_id, :status])
    create index(:finance_email_ingestions, [:user_id, :message_id])
    create index(:finance_email_ingestions, [:transaction_id])
  end
end
