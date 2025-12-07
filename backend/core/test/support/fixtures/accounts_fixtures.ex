defmodule Core.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Core.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        avatar_url: "some avatar_url",
        email: "some email",
        hashed_password: "some hashed_password",
        password: "some password",
        username: "some username"
      })
      |> Core.Accounts.create_user()

    user
  end
end
