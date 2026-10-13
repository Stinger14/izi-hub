defmodule CoreWeb.RedirectController do
  use CoreWeb, :controller

  @doc "The site root: the hub when signed in, the public landing page otherwise."
  def root(%{assigns: %{current_scope: %{user: _}}} = conn, _params),
    do: redirect(conn, to: ~p"/hub")

  def root(conn, _params), do: redirect(conn, to: ~p"/welcome")
end
