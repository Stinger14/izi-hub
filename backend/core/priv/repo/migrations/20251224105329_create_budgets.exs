defmodule Core.Repo.Migrations.CreateBudgets do
  use Ecto.Migration

  def change do
    create table(:budgets) do
      add :name, :string
      add :amount, :decimal
      add :period, :string
      add :start_date, :date
      add :end_date, :date

      timestamps(type: :utc_datetime)
    end
  end
end
