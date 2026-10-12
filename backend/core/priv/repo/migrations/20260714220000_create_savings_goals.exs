defmodule Core.Repo.Migrations.CreateSavingsGoals do
  use Ecto.Migration

  def change do
    create table(:savings_goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :target_amount, :decimal, precision: 15, scale: 2, null: false
      add :saved_amount, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :currency, :string, null: false, default: "DOP"
      add :target_date, :date
      add :status, :string, null: false, default: "active"
      add :notes, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:savings_goals, [:user_id])
    create index(:savings_goals, [:household_id])
    create index(:savings_goals, [:status])

    create constraint(:savings_goals, :savings_goals_exactly_one_owner_scope,
             check: "(user_id IS NOT NULL) <> (household_id IS NOT NULL)"
           )
  end
end
