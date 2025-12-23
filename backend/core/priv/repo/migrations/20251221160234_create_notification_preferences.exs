defmodule Core.Repo.Migrations.CreateNotificationPreferences do
  use Ecto.Migration

  def change do
    create table(:notification_preferences) do
      add :email_enabled, :boolean, default: false, null: false
      add :push_enabled, :boolean, default: false, null: false
      add :comment_notifications, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
