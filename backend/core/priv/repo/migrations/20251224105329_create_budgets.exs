defmodule Core.Repo.Migrations.CreateBudgets do
  use Ecto.Migration

  def change do
    create table(:budgets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :period, :string, null: false
      add :start_date, :date, null: false
      add :end_date, :date
      add :alert_threshold, :integer, default: 80
      add :is_active, :boolean, default: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :category_id, references(:categories, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create index(:budgets, [:user_id])
    create index(:budgets, [:category_id])
    create index(:budgets, [:is_active])
  end
end
