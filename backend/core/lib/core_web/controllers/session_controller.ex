defmodule CoreWeb.SessionController do
  @moduledoc """
  `/login` and `/logout`: password sign-in and sign-out.

  Context: inactive users get the same error as a wrong password. Logout
  revokes this browser's session and lands on `/welcome`.
  """

  use CoreWeb, :controller

  alias Core.Accounts
  alias CoreWeb.UserAuth

  @doc "Shows the sign-in form."
  def new(conn, params) do
    case conn.assigns.current_scope do
      %{user: user} ->
        redirect(conn, to: after_login_path(user))

      nil ->
        error = if params["error"] == "auth", do: "Please sign in to continue", else: nil
        render(conn, :new, error: error, email: "")
    end
  end

  @doc "Signs in with email and password and continues where the user was going."
  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_password(email, password) do
      nil ->
        render_login_error(conn, "Invalid login or password", email)

      user ->
        _ = Accounts.update_last_login(user)
        {conn, path} = UserAuth.after_sign_in_path(conn, after_login_path(user))

        conn
        |> UserAuth.log_in_user(user)
        |> put_flash(:info, "Welcome back")
        |> redirect(to: path)
    end
  end

  def create(conn, _params) do
    render_login_error(conn, "Invalid login payload", "")
  end

  @doc "Signs out this browser."
  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> put_flash(:info, "Logged out")
    |> redirect(to: ~p"/welcome")
  end

  defp after_login_path(%{role: "admin"}), do: ~p"/admin"
  defp after_login_path(_user), do: ~p"/hub"

  defp render_login_error(conn, error, email) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:new, error: error, email: email)
  end
end
