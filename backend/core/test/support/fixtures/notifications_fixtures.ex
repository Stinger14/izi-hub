defmodule Core.NotificationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Core.Notifications` context.
  """

  @doc """
  Generate a notification.
  """
  def notification_fixture(attrs \\ %{}) do
    {:ok, notification} =
      attrs
      |> Enum.into(%{
        message: "some message",
        title: "some title",
        type: "some type"
      })
      |> Core.Notifications.create_notification()

    notification
  end
end
