defmodule Core.Fixtures do
  @moduledoc """
  Shared test fixtures, imported by `Core.DataCase` and `CoreWeb.ConnCase`.
  """

  alias Core.Accounts
  alias Core.Repo

  @password "Password123!"

  def valid_password, do: @password

  @doc "Registers a regular user; any attribute can be overridden."
  def user_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      %{
        email: "user_#{unique}@example.com",
        password: @password,
        username: "user_#{unique}",
        full_name: "Test User"
      }
      |> Map.merge(Map.new(attrs))
      |> Accounts.register_user()

    user
  end

  @doc "Registers an active admin user."
  def admin_fixture(attrs \\ %{}) do
    attrs
    |> user_fixture()
    |> Ecto.Changeset.change(%{role: "admin", is_active: true})
    |> Repo.update!()
  end
end
