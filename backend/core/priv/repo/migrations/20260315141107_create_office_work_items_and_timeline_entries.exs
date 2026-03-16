defmodule Core.Repo.Migrations.CreateOfficeWorkItemsAndTimelineEntries do
  use Ecto.Migration

  def change do
    create table(:office_work_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :string
      add :status, :string, null: false, default: "queue"
      add :priority, :string, null: false, default: "medium"
      add :scheduled_for, :date
      add :due_at, :naive_datetime
      add :sequence, :integer, null: false, default: 0
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:office_work_items, [:user_id, :status])
    create index(:office_work_items, [:user_id, :scheduled_for])
    create index(:office_work_items, [:user_id, :due_at])

    create table(:office_work_item_transitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_status, :string, null: false
      add :to_status, :string, null: false

      add :work_item_id, references(:office_work_items, type: :binary_id, on_delete: :delete_all),
        null: false

      add :moved_by_id, references(:users, type: :binary_id, on_delete: :nothing), null: false

      timestamps(updated_at: false)
    end

    create index(:office_work_item_transitions, [:work_item_id, :inserted_at])

    create table(:office_timeline_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :kind, :string, null: false, default: "milestone"
      add :starts_at, :naive_datetime, null: false
      add :ends_at, :naive_datetime
      add :work_item_id, references(:office_work_items, type: :binary_id, on_delete: :nilify_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:office_timeline_entries, [:user_id, :starts_at])
  end
end
