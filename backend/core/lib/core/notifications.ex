defmodule Core.Notifications do
  @moduledoc """
  In-app notifications for users and their notification preferences.

  Context: Not used by any page yet. New notifications are broadcast over PubSub to
  the
  recipient.

  ## Example

      Notifications.create_notification(%{user_id: id, title: "Hi", type: "info"})
      Notifications.count_unread_notifications(id)
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Notifications.{Notification, NotificationPreference}

  @doc "A user's notifications, newest first (`:limit` default 50, `:unread_only`)."
  def list_user_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    unread_only = Keyword.get(opts, :unread_only, false)

    query =
      Notification
      |> where([n], n.user_id == ^user_id)
      |> order_by([n], desc: n.inserted_at)
      |> limit(^limit)
      |> preload(:triggered_by)

    query =
      if unread_only do
        where(query, [n], n.is_read == false)
      end

    Repo.all(query)
  end

  @doc "How many unread notifications a user has."
  def count_unread_notifications(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and n.is_read == false)
    |> Repo.aggregate(:count)
  end

  @doc "A notification by id; raises if missing."
  def get_notification!(id) do
    Notification
    |> preload([:user, :triggered_by])
    |> Repo.get!(id)
  end

  @doc "Creates a notification and broadcasts it to the user."
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> broadcast_notification()
  end

  @doc "Sends the same notification to many users in one insert."
  def create_bulk_notification(user_ids, attrs) when is_list(user_ids) do
    notifications =
      Enum.map(user_ids, fn user_id ->
        attrs_with_user = Map.put(attrs, :user_id, user_id)

        %Notification{}
        |> Notification.changeset(attrs_with_user)
        |> Ecto.Changeset.apply_changes()
        |> Map.from_struct()
        |> Map.drop([:__meta__])
        |> Map.put(:inserted_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
        |> Map.put(:updated_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
      end)

    {count, _} = Repo.insert_all(Notification, notifications)
    {:ok, count}
  end

  @doc "Marks a notification read."
  def mark_as_read(%Notification{} = notification) do
    notification
    |> Ecto.Changeset.change(%{
      is_read: true,
      read_at: NaiveDateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc "Marks all of a user's notifications read."
  def mark_all_read(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.is_read == false
    )
    |> Repo.update_all(set: [is_read: true, read_at: NaiveDateTime.utc_now()])
  end

  @doc "Deletes a notification."
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc "Deletes read notifications older than `days_old` days (default 30)."
  def delete_old_notifications(days_old \\ 30) do
    due_date =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-days_old * 24 * 3600)

    from(n in Notification,
      where: n.is_read == true and n.read_at < ^due_date
    )
    |> Repo.delete_all()
  end

  ## Notification Preferences

  @doc "A user's notification preferences, or nil."
  def get_user_preferences(user_id) do
    case Repo.get_by(NotificationPreference, user_id: user_id) do
      nil -> create_default_preferences(user_id)
      preferences -> {:ok, preferences}
    end
  end

  @doc "Creates default preferences for a user."
  def create_default_preferences(user_id) do
    %NotificationPreference{}
    |> NotificationPreference.changeset(%{user_id: user_id})
    |> Repo.insert()
  end

  @doc "Updates a user's notification preferences."
  def update_preferences(%NotificationPreference{} = preferences, attrs) do
    preferences
    |> NotificationPreference.changeset(attrs)
    |> Repo.update()
  end

  # Private helper to broadcast notifications (Phoenix PubSub)
  defp broadcast_notification({:ok, notification} = result) do
    Phoenix.PubSub.broadcast(
      Core.PubSub,
      "notifications:#{notification.user_id}",
      {:new_notification, notification}
    )

    result
  end

  defp broadcast_notification(error), do: error
end
