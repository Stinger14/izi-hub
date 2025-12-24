defmodule Core.Notifications.NotificationPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_preferences" do
    field :email_enabled, :boolean, default: true
    field :push_enabled, :boolean, default: true
    field :comment_notifications, :boolean, default: true
    field :reply_notifications, :boolean, default: true
    field :mention_notifications, :boolean, default: true
    field :system_notifications, :boolean, default: true
    field :marketing_emails, :boolean, default: false

    belongs_to :user, Core.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :email_enabled,
      :push_enabled,
      :comment_notifications,
      :reply_notifications,
      :mention_notifications,
      :system_notifications,
      :marketing_emails,
      :user_id
    ])
    |> validate_required([:user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id)
  end
end
