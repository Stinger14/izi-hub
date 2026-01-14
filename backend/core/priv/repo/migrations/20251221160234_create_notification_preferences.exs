defmodule Core.Repo.Migrations.CreateNotificationPreferences do
  use Ecto.Migration

  def change do
    create table(:notification_preferences) do
      add :email_enabled, :boolean, default: true
      add :push_enabled, :boolean, default: true
      add :comment_notifications, :boolean, default: true
      add :reply_notifications, :boolean, default: true
      add :mention_notifications, :boolean, default: true
      add :system_notifications, :boolean, default: true
      add :marketing_emails, :boolean, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      timestamps()
    end

    create unique_index(:notification_preferences, [:user_id])
  end
end
