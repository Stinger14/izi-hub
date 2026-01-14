defmodule Core.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :message, :string, null: false
      add :type, :string, null: false
      add :priority, :string, default: "normal"
      add :is_read, :boolean, default: false
      add :read_at, :naive_datetime
      add :action_url, :string
      add :metadata, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :triggered_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:triggered_by_id])
    create index(:notifications, [:type])
    create index(:notifications, [:is_read])
    create index(:notifications, [:inserted_at])
  end
end
