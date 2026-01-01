defmodule Core.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :message, :text, null: false
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

    create table(:notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email_enabled, :boolean, default: true
      add :push_enabled, :boolean, default: true
      add :comment_notifications, :boolean, default: true
      add :reply_notifications, :boolean, default: true
      add :mention_notifications, :boolean, default: true
      add :system_notifications, :boolean, default: true
      add :marketing_emails, :boolean, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:notification_preferences, [:user_id])
  end
end
