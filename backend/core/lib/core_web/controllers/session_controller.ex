defmodule CoreWeb.SessionController do
  use CoreWeb, :controller

  alias Core.Accounts

  def new(conn, params) do
    case conn.assigns.current_scope do
      %{user: user} ->
        redirect(conn, to: after_login_path(user))

      nil ->
        error = if params["error"] == "auth", do: "Please sign in to continue", else: nil
        render(conn, :new, error: error, email: "")
    end
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_password(email, password) do
      nil ->
        render_login_error(conn, "Invalid login or password", email)

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
    render_login_error(conn, "Invalid login payload", "")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out")
    |> redirect(to: ~p"/hub")
  end

  defp after_login_path(%{role: "admin"}), do: ~p"/admin"
  defp after_login_path(_user), do: ~p"/hub"

  defp render_login_error(conn, error, email) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:new, error: error, email: email)
  end
end
