defmodule Core.Accounts.Scope do
  @enforce_keys [:user]
  defstruct [:user]

  def for_user(nil), do: nil
  def for_user(user), do: %__MODULE__{user: user}

  def admin?(%__MODULE__{user: %{role: "admin"}}), do: true
  def admin?(_), do: false
end
