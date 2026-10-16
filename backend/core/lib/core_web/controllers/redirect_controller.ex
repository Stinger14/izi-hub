defmodule CoreWeb.RedirectController do
  @moduledoc "`/`: sends signed-in users to `/hub` and everyone else to `/welcome`."

  use CoreWeb, :controller

  @doc "Redirects to `/hub` or `/welcome`."
  def root(%{assigns: %{current_scope: %{user: _}}} = conn, _params),
    do: redirect(conn, to: ~p"/hub")

  def root(conn, _params), do: redirect(conn, to: ~p"/welcome")
end
