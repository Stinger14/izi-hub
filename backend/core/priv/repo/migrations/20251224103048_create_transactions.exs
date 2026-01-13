defmodule Core.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :decimal
      add :type, :string
      add :description, :string
      add :transaction_date, :date
      add :payment_method, :string
      add :tags, {:array, :string}, default: []
      add :receipt_url, :string
      add :notes, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      timestamps()
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:transaction_date])
    create index(:transactions, [:type])
  end
end
