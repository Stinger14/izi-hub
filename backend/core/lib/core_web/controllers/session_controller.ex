defmodule CoreWeb.SessionController do
  use CoreWeb, :controller

  alias Core.Accounts

  def new(conn, _params) do
    redirect(conn, to: ~p"/hub?auth=login")
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_password(email, password) do
      nil ->
        conn
        |> put_flash(:error, "Invalid login or password")
        |> redirect(to: ~p"/hub?auth=login")

      user ->
        _ = Accounts.update_last_login(user)

        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back")
        |> redirect(to: after_login_path(user))
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid login payload")
    |> redirect(to: ~p"/hub?auth=login")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out")
    |> redirect(to: ~p"/hub")
  end

  defp after_login_path(%{role: "admin"}), do: ~p"/admin"
  defp after_login_path(_user), do: ~p"/hub"
end
