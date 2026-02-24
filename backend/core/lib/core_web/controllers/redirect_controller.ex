defmodule CoreWeb.RedirectController do
  use CoreWeb, :controller

  def to_welcome(conn, _params) do
    redirect(conn, to: ~p"/welcome")
  end
end
