defmodule CoreWeb.LivebookAccessController do
  use CoreWeb, :controller

  def create(conn, %{"token" => token}) do
    if token_matches?(token) do
      conn
      |> put_session(:livebook_admin, true)
      |> put_flash(:info, "Livebook access enabled for this session.")
      |> redirect(to: ~p"/notebooks")
    else
      conn
      |> put_flash(:error, "Invalid Livebook access token.")
      |> redirect(to: ~p"/notebooks")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Livebook access token is required.")
    |> redirect(to: ~p"/notebooks")
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:livebook_admin)
    |> put_flash(:info, "Livebook access removed.")
    |> redirect(to: ~p"/notebooks")
  end

  defp token_matches?(token) when is_binary(token) do
    case System.get_env("LIVEBOOK_ADMIN_TOKEN") do
      nil -> false
      "" -> false
      expected -> Plug.Crypto.secure_compare(token, expected)
    end
  end

  defp token_matches?(_), do: false
end
