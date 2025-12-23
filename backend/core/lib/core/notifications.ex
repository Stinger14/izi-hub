defmodule Core.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Notifications.{Notification, NotificationPreference}

  @doc """
  Returns a list of notifications for a user
  """
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

  @doc """
  Returns unread notifications count for a user
  """
  def count_unread_notifications(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and n.is_read == false)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets a single notification
  """
  def get_notification!(id) do
    Notification
    |> preload([:user, :triggered_by])
    |> Repo.get!(id)
  end

  @doc """
  Creates a notification
  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> broadcast_notification()
  end

  @doc """
  Creates a notification and send it to multiple users
  """
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

  @doc """
  Marks notification as read
  """
  def mark_as_read(%Notification{} = notification) do
    notification
    |> Ecto.Changeset.change(%{
      is_read: true,
      read_at: NaiveDateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Marks all notifications as read for a user
  """
  def mark_all_read(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.is_read == false
    )
    |> Repo.update_all(set: [is_read: true, read_at: NaiveDateTime.utc_now()])
  end

  @doc """
  Deletes a notification
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Deletes old read notifications (clean up)
  """
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

  @doc """
  Gets user notification preferences
  """
  def get_user_preferences(user_id) do
    case Repo.get_by(NotificationPreference, user_id: user_id) do
      nil -> create_default_preferences(user_id)
      preferences -> {:ok, preferences}
    end
  end

  @doc """
  Creates default notification preferences for user
  """
  def create_default_preferences(user_id) do
    %NotificationPreference{}
    |> NotificationPreference.changeset(%{user_id: user_id})
    |> Repo.insert()
  end

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
