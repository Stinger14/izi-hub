defmodule Core.Accounts.Scope do
  @moduledoc """
  The signed-in caller, as `@current_scope` in LiveViews and conns.

  Context: built by `CoreWeb.UserAuth` from the session token; nil when
  signed out.

  ## Example

      Scope.for_user(user) |> Scope.admin?()
      #=> false
  """

  @enforce_keys [:user]
  defstruct [:user]

  @doc "Wraps a user in a scope; nil stays nil."
  def for_user(nil), do: nil
  def for_user(user), do: %__MODULE__{user: user}

  @doc "Whether the scope's user is an admin."
  def admin?(%__MODULE__{user: %{role: "admin"}}), do: true
  def admin?(_), do: false
end
