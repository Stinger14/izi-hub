defmodule Core.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :title, :string
    field :message, :string
    field :type, :string
    field :priority, :string, default: "normal"
    field :is_read, :boolean, default: false
    field :read_at, :naive_datetime
    field :action_url, :string
    field :metadata, :map, default: %{}

    belongs_to :user, Core.Accounts.User
    belongs_to :triggered_by, Core.Accounts.User

    timestamps()
  end

  @notification_types [
    "comment",
    "reply",
    "mention",
    "like",
    "follow",
    "system",
    "update",
    "warning",
    "error",
    "success"
  ]

  @priorities ["low", "normal", "high", "urgent"]

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :title,
      :message,
      :type,
      :priority,
      :is_read,
      :read_at,
      :action_ril,
      :metadata,
      :user_id,
      :triggered_by_id
    ])
    |> validate_required([:title, :message, :type, :user_id])
    |> validate_length(:title, min: 1, max: 250)
    |> validate_length(:message, min: 1, max: 1000)
    |> validate_inclusion(:type, @notification_types)
    |> validate_inclusion(:priority, @priorities)
    |> validate_url(:action_url)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:triggered_by_id)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      if value && !String.match?(value, ~r/^(\/|https?:\/\/)/) do
        [{field, "must be a valid URL or path"}]
      else
        []
      end
    end)
  end
end
