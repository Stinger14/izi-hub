defmodule Core.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :amount, :decimal
      add :type, :string
      add :description, :string
      add :transaction_date, :date

      timestamps(type: :utc_datetime)
    end
  end
end
