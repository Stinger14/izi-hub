defmodule Core.Repo.Migrations.CreateHouseholdsAndHouseholdMembers do
  use Ecto.Migration

  def change do
    create table(:households, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string
      add :status, :string, null: false, default: "active"

      timestamps()
    end

    create unique_index(:households, [:slug])

    create table(:household_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :status, :string, null: false, default: "active"

      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:household_members, [:household_id, :user_id])
    create index(:household_members, [:user_id])
    create index(:household_members, [:household_id, :status])
  end
end
