defmodule Core.Repo.Migrations.AddOfficeProjectsAndProjectReferences do
  use Ecto.Migration

  def change do
    create table(:office_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :status, :string, null: false, default: "active"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:office_projects, [:user_id])
    create unique_index(:office_projects, [:user_id, :slug])

    alter table(:office_work_items) do
      add :project_id, references(:office_projects, type: :binary_id, on_delete: :delete_all)
    end

    create index(:office_work_items, [:project_id, :status])

    alter table(:office_timeline_entries) do
      add :description, :string
      add :project_id, references(:office_projects, type: :binary_id, on_delete: :delete_all)
    end

    create index(:office_timeline_entries, [:project_id, :starts_at])
  end
end
